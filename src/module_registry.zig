const std = @import("std");
const Value = @import("value.zig").Value;
const vm = @import("vm.zig");
const stdlib = @import("stdlib.zig");

pub const ModuleInfo = struct {
    name: []const u8,
    functions: []const stdlib.BuiltinDef,
    init_fn: *const fn () void,
};

pub const MODULE_REGISTRY = [_]ModuleInfo{
    .{
        .name = "math",
        .functions = &stdlib.MATH_FUNCTIONS,
        .init_fn = stdlib.addMath,
    },
    .{
        .name = "collections",
        .functions = &stdlib.COLLECTION_FUNCTIONS,
        .init_fn = stdlib.addCollections,
    },
    .{
        .name = "fs",
        .functions = &stdlib.FILESYSTEM_FUNCTIONS,
        .init_fn = stdlib.addFs,
    },
    .{
        .name = "time",
        .functions = &stdlib.TIME_FUNCTIONS,
        .init_fn = stdlib.addTime,
    },
    .{
        .name = "utils",
        .functions = &stdlib.UTIL_FUNCTIONS,
        .init_fn = stdlib.addUtils,
    },
    .{
        .name = "network",
        .functions = &stdlib.NETWORK_FUNCTIONS,
        .init_fn = stdlib.addNet,
    },
    .{
        .name = "matrix",
        .functions = &stdlib.MATRIX_FUNCTIONS,
        .init_fn = stdlib.addMatrix,
    },
};

var loaded_modules: std.StringHashMap(bool) = undefined;
var module_allocator: std.mem.Allocator = undefined;
var initialized: bool = false;

pub fn init(allocator: std.mem.Allocator) void {
    if (initialized) return;
    module_allocator = allocator;
    loaded_modules = std.StringHashMap(bool).init(allocator);
    initialized = true;
}

pub fn deinit() void {
    if (!initialized) return;
    loaded_modules.deinit();
    initialized = false;
}

pub fn isModuleLoaded(name: []const u8) bool {
    if (!initialized) return false;
    return loaded_modules.get(name) orelse false;
}

pub fn loadModule(name: []const u8) !void {
    if (!initialized) return error.NotInitialized;

    // Check if already loaded
    if (isModuleLoaded(name)) return;

    // Find module in registry
    for (MODULE_REGISTRY) |module| {
        if (std.mem.eql(u8, module.name, name)) {
            // Load the module
            module.init_fn();
            try loaded_modules.put(name, true);
            return;
        }
    }

    return error.ModuleNotFound;
}

pub fn loadSpecificFunction(module_name: []const u8, func_name: []const u8) !void {
    if (!initialized) return error.NotInitialized;

    // Find module
    for (MODULE_REGISTRY) |module| {
        if (std.mem.eql(u8, module.name, module_name)) {
            // Find specific function
            for (module.functions) |func| {
                if (std.mem.eql(u8, func.name, func_name)) {
                    // Define just this one function
                    vm.defineNative(@ptrCast(@constCast(func.name)), @ptrCast(func.func));
                    return;
                }
            }
            return error.FunctionNotFound;
        }
    }
    return error.ModuleNotFound;
}

pub fn getModuleNames(allocator: std.mem.Allocator) ![]const []const u8 {
    var names = try allocator.alloc([]const u8, MODULE_REGISTRY.len);
    for (MODULE_REGISTRY, 0..) |module, i| {
        names[i] = module.name;
    }
    return names;
}
