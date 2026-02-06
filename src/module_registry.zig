/// Module Registry System for MufiZ
/// Manages lazy-loading of standard library modules and file imports

const std = @import("std");
const Value = @import("value.zig").Value;
const stdlib_main = @import("stdlib_main.zig");
const vm = @import("vm.zig");
const compiler = @import("compiler.zig");
const mem_utils = @import("mem_utils.zig");

/// Information about a module that can be loaded
pub const ModuleInfo = struct {
    name: []const u8,
    register_fn: *const fn () anyerror!void,
};

/// Registry of available standard library modules
pub const MODULE_REGISTRY = [_]ModuleInfo{
    .{
        .name = "math",
        .register_fn = stdlib_main.MathModule.register,
    },
    .{
        .name = "collections",
        .register_fn = stdlib_main.CollectionsModule.register,
    },
    .{
        .name = "matrix",
        .register_fn = stdlib_main.MatrixModule.register,
    },
    .{
        .name = "io",
        .register_fn = stdlib_main.IoModule.register,
    },
    .{
        .name = "types",
        .register_fn = stdlib_main.TypesModule.register,
    },
    .{
        .name = "utils",
        .register_fn = stdlib_main.UtilsModule.register,
    },
    .{
        .name = "json",
        .register_fn = stdlib_main.JsonModule.register,
    },
    .{
        .name = "serde",
        .register_fn = stdlib_main.SerdeModule.register,
    },
};

var loaded_modules: std.StringHashMap(bool) = undefined;
var allocator: std.mem.Allocator = undefined;
var initialized: bool = false;

/// Initialize the module registry
pub fn init(alloc: std.mem.Allocator) void {
    allocator = alloc;
    loaded_modules = std.StringHashMap(bool).init(alloc);
    initialized = true;
}

/// Deinitialize the module registry
pub fn deinit() void {
    if (!initialized) return;
    loaded_modules.deinit();
    initialized = false;
}

/// Load a module by name (lazy loading)
pub fn loadModule(name: []const u8) !void {
    if (!initialized) {
        std.debug.print("Error: Module registry not initialized!\n", .{});
        return error.RegistryNotInitialized;
    }

    // Check if already loaded
    if (loaded_modules.get(name)) |loaded| {
        if (loaded) return; // Already loaded
    }

    // Find module in registry
    for (MODULE_REGISTRY) |module| {
        if (std.mem.eql(u8, module.name, name)) {
            // Call the module's registration function
            try module.register_fn();
            try loaded_modules.put(name, true);
            return;
        }
    }

    std.debug.print("Error: Module '{s}' not found!\n", .{name});
    return error.ModuleNotFound;
}

/// Load a specific function from a module
/// This loads the entire module and makes the specific function available
pub fn loadSpecificFunction(module_name: []const u8, func_name: []const u8) !void {
    _ = func_name; // For now, we just load the entire module
    // In the future, we could implement per-function loading
    try loadModule(module_name);
}

/// Load and execute a MufiZ file
pub fn loadFile(path: []const u8) !void {
    if (!initialized) {
        std.debug.print("Error: Module registry not initialized!\n", .{});
        return error.RegistryNotInitialized;
    }

    // Read the file
    const file = std.fs.cwd().openFile(path, .{}) catch |err| {
        std.debug.print("Error: Failed to open file '{s}': {any}\n", .{ path, err });
        return error.FileNotFound;
    };
    defer file.close();

    const source = file.readToEndAlloc(allocator, 1_048_576) catch |err| {
        std.debug.print("Error: Failed to read file '{s}': {any}\n", .{ path, err });
        return error.FileReadError;
    };
    defer allocator.free(source);

    // Add null terminator for compatibility with C-style string functions
    const source_with_null = allocator.allocSentinel(u8, source.len, 0) catch |err| {
        std.debug.print("Error: Failed to allocate memory: {any}\n", .{err});
        return error.OutOfMemory;
    };
    defer allocator.free(source_with_null);
    @memcpy(source_with_null[0..source.len], source);

    // Compile and interpret the file
    const result = vm.interpret(@ptrCast(source_with_null.ptr));
    
    if (result != .INTERPRET_OK) {
        std.debug.print("Error: Failed to execute file '{s}'\n", .{path});
        return error.InterpretError;
    }
}

/// Check if a module is loaded
pub fn isModuleLoaded(name: []const u8) bool {
    if (!initialized) return false;
    return loaded_modules.get(name) orelse false;
}
