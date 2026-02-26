/// Module Registry System for MufiZ
/// Manages lazy-loading of standard library modules and file imports
const std = @import("std");
const stdlib_main = @import("stdlib_main.zig");
const stdlib_core = @import("stdlib_core.zig");

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
var dependency_map: std.StringHashMap([]const u8) = undefined;
var allocator: std.mem.Allocator = undefined;
var initialized: bool = false;

/// Initialize the module registry
pub fn init(alloc: std.mem.Allocator) void {
    allocator = alloc;
    loaded_modules = std.StringHashMap(bool).init(alloc);
    dependency_map = std.StringHashMap([]const u8).init(alloc);
    initialized = true;
}

/// Deinitialize the module registry
pub fn deinit() void {
    if (!initialized) return;
    loaded_modules.deinit();
    
    var iter = dependency_map.iterator();
    while (iter.next()) |entry| {
        allocator.free(entry.key_ptr.*);
        allocator.free(entry.value_ptr.*);
    }
    dependency_map.deinit();
    
    initialized = false;
}

/// Register a dependency mapping
pub fn registerDependency(name: []const u8, path: []const u8) !void {
    if (!initialized) return error.RegistryNotInitialized;
    
    const key = try allocator.dupe(u8, name);
    const value = try allocator.dupe(u8, path);
    
    if (dependency_map.get(name)) |old_path| {
        allocator.free(old_path);
    }
    
    try dependency_map.put(key, value);
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

    // 1. Check built-in modules in registry
    for (MODULE_REGISTRY) |module| {
        if (std.mem.eql(u8, module.name, name)) {
            // Call the module's registration function to add functions to registry
            try module.register_fn();

            // Actually register the module's functions with the VM
            const registry = stdlib_core.getGlobalRegistry();
            registry.registerModule(name);

            try loaded_modules.put(name, true);
            return;
        }
    }

    // 2. Check registered dependencies from package manager
    if (dependency_map.get(name)) |dep_path| {
        try loadFile(dep_path);
        try loaded_modules.put(name, true);
        return;
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

/// Resolve a file path, checking dependencies if not found locally
fn resolvePath(path: []const u8, base_file: ?[]const u8) ![]const u8 {
    // 1. Check if it's a built-in module name (don't resolve as file)
    for (MODULE_REGISTRY) |module| {
        if (std.mem.eql(u8, module.name, path)) {
            return error.IsBuiltInModule;
        }
    }

    // 2. Try relative to the current file if it's a relative-looking path or if base_file is provided
    if (base_file) |bf| {
        if (std.fs.path.dirname(bf)) |dir| {
            const joined = try std.fs.path.join(allocator, &[_][]const u8{ dir, path });
            std.fs.cwd().access(joined, .{}) catch {
                allocator.free(joined);
                return resolvePathNoBase(path);
            };
            return joined;
        }
    }

    return resolvePathNoBase(path);
}

fn resolvePathNoBase(path: []const u8) ![]const u8 {
    // Try current working directory
    std.fs.cwd().access(path, .{}) catch {
        // Check dependency map
        if (dependency_map.get(path)) |dep_path| {
            return try allocator.dupe(u8, dep_path);
        }
        
        return try allocator.dupe(u8, path);
    };
    
    return try allocator.dupe(u8, path);
}

/// Load and execute a MufiZ file
pub fn loadFile(path: []const u8) !void {
    try loadFileWithBase(path, null);
}

/// Load and execute a MufiZ file with a base path for relative resolution
pub fn loadFileWithBase(path: []const u8, base_file: ?[]const u8) !void {
    if (!initialized) {
        std.debug.print("Error: Module registry not initialized!\n", .{});
        return error.RegistryNotInitialized;
    }

    const resolved_path = resolvePath(path, base_file) catch |err| {
        if (err == error.IsBuiltInModule) return; // Handled by loadModule
        return err;
    };
    defer allocator.free(resolved_path);

    // Read the file
    const file = std.fs.cwd().openFile(resolved_path, .{}) catch |err| {
        std.debug.print("Error: Failed to open file '{s}': {any}\n", .{ resolved_path, err });
        return error.FileNotFound;
    };
    defer file.close();

    const source = file.readToEndAlloc(allocator, 1_048_576) catch |err| {
        std.debug.print("Error: Failed to read file '{s}': {any}\n", .{ resolved_path, err });
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

    // Compile the file
    const compiler_h = @import("compiler.zig");
    const object_h = @import("object.zig");
    const Value = @import("value.zig").Value;
    const vm_module = @import("vm.zig");

    const function = compiler_h.compile(@ptrCast(source_with_null.ptr), resolved_path) orelse {
        std.debug.print("Error: Failed to compile file '{s}'\n", .{resolved_path});
        return error.CompileError;
    };

    // Create closure and call it in the current VM context
    // Push the function first (will be popped when creating closure)
    vm_module.push(Value{
        .type = .VAL_OBJ,
        .as = .{ .obj = @ptrCast(@alignCast(function)) },
    });
    const closure = object_h.newClosure(@ptrCast(function));
    _ = vm_module.pop();

    // Push the closure on the stack for the call
    vm_module.push(Value{
        .type = .VAL_OBJ,
        .as = .{ .obj = @ptrCast(@alignCast(closure)) },
    });

    const vm_ptr = vm_module.getVM();
    const prev_depth = vm_ptr.frameCount;

    // Call the closure with 0 arguments (pushes a new frame)
    if (!vm_module.call(closure, 0)) {
        std.debug.print("Error: Failed to execute file '{s}'\n", .{resolved_path});
        return error.InterpretError;
    }

    // Run until the frame count returns to the previous level
    const result = vm_module.runUntil(prev_depth);
    if (result != .INTERPRET_OK) {
        std.debug.print("Error: Failed to execute file '{s}': {any}\n", .{resolved_path, result});
        return error.InterpretError;
    }
}

/// Check if a module is loaded
pub fn isModuleLoaded(name: []const u8) bool {
    if (!initialized) return false;
    return loaded_modules.get(name) orelse false;
}

/// Populate a module object with its members (constants and functions)
pub fn populateModuleMembers(module: *@import("object.zig").ObjModule, module_name: []const u8) !void {
    const vm_module = @import("vm.zig");
    const Value = @import("value.zig").Value;

    // Check if it's a built-in module
    var is_builtin = false;
    for (MODULE_REGISTRY) |m| {
        if (std.mem.eql(u8, m.name, module_name)) {
            is_builtin = true;
            break;
        }
    }

    // Get all globals from the VM that belong to this module
    const iterator = vm_module.vm.globals.entries;
    var i: usize = 0;

    // For math module, also add constants
    if (std.mem.eql(u8, module_name, "math")) {
        // Add PI constant
        const pi_value = Value{
            .type = .VAL_DOUBLE,
            .as = .{ .num_double = 3.141592653589793 },
        };
        try module.setMember("PI", pi_value);

        // Add E constant
        const e_value = Value{
            .type = .VAL_DOUBLE,
            .as = .{ .num_double = 2.718281828459045 },
        };
        try module.setMember("E", e_value);
    }

    // Add all functions from the module to the module object
    if (iterator) |entries| {
        while (i < vm_module.vm.globals.capacity) : (i += 1) {
                if (entries[i].key) |objString| {
                    if (entries[i].deleted) continue;
                    
                    const varName = objString.chars[0..@intCast(objString.length)];
                    const value = entries[i].value;

                    if (is_builtin) {
                    // For builtins, we only add native functions
                    if (value.type == .VAL_OBJ and value.as.obj != null) {
                        if (value.as.obj.?.type == .OBJ_NATIVE) {
                            try module.setMember(varName, value);
                        }
                    }
                } else {
                    // For user modules (dependencies), add everything that is PUB
                    if (vm_module.isPublicGlobal(objString)) {
                        try module.setMember(varName, value);
                    }
                }
            }
        }
    }
}
