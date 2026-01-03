const std = @import("std");
const stdlib_v2 = @import("stdlib_v2.zig");
const Value = @import("value.zig").Value;

// Import all migrated modules
const math = @import("stdlib_v2/math.zig");
const io = @import("stdlib_v2/io.zig");
const types = @import("stdlib_v2/types.zig");
const time = @import("stdlib_v2/time.zig");
const utils = @import("stdlib_v2/utils.zig");
const collections = @import("stdlib_v2/collections.zig");
const fs = @import("stdlib_v2/fs.zig");
const network = @import("stdlib_v2/network.zig");
const matrix = @import("stdlib_v2/matrix.zig");

// Feature flags (can be set at compile time)
const enable_fs = @import("features.zig").enable_fs;
const enable_net = @import("features.zig").enable_net;
const enable_curl = @import("features.zig").enable_curl;

// Core function implementation for what_is
fn what_is_impl(argc: i32, args: [*]Value) Value {
    _ = argc;
    const conv = @import("conv.zig");
    const type_str = conv.what_is(args[0]);
    const allocator = @import("mem_utils.zig").getAllocator();
    const result = allocator.dupe(u8, type_str) catch return Value.init_nil();
    return Value.init_string(result);
}

// Core functions wrapper
pub const what_is = stdlib_v2.DefineFunction(
    "what_is",
    "core",
    "Shows the type of a value",
    stdlib_v2.OneAny,
    .string,
    &[_][]const u8{
        "what_is(42) -> \"int\"",
        "what_is(\"hello\") -> \"string\"",
        "what_is(true) -> \"bool\"",
    },
    what_is_impl,
);

// Auto-registration modules
const MathModule = stdlib_v2.AutoRegisterModule(math);
const IoModule = stdlib_v2.AutoRegisterModule(io);
const TypesModule = stdlib_v2.AutoRegisterModule(types);
const TimeModule = stdlib_v2.AutoRegisterModule(time);
const UtilsModule = stdlib_v2.AutoRegisterModule(utils);
const CollectionsModule = stdlib_v2.AutoRegisterModule(collections);
const FsModule = stdlib_v2.AutoRegisterModule(fs);
const NetworkModule = stdlib_v2.AutoRegisterModule(network);
const MatrixModule = stdlib_v2.AutoRegisterModule(matrix);

// Main initialization function
pub fn initializeStdlib() !void {
    // Set feature flags
    stdlib_v2.setFeatureFlags(.{
        .enable_fs = enable_fs,
        .enable_net = enable_net,
        .enable_curl = enable_curl,
    });

    const registry = stdlib_v2.getGlobalRegistry();

    // Register core functions
    try registry.register(what_is);

    // Register all modules
    try MathModule.register();
    try IoModule.register();
    try TypesModule.register();
    try TimeModule.register();
    try UtilsModule.register();
    try CollectionsModule.register();

    // Conditionally register optional modules
    if (enable_fs) {
        std.log.info("File system functions enabled", .{});
        try FsModule.register();
    }

    if (enable_net) {
        std.log.info("Network functions enabled", .{});
        try NetworkModule.register();
    }

    // Always register matrix module (no feature flag needed)
    try MatrixModule.register();

    std.log.info("Standard library initialized with {} functions", .{registry.getFunctionCount()});
}

// Register all functions with the VM
pub fn registerWithVM() void {
    const registry = stdlib_v2.getGlobalRegistry();
    registry.registerAll();
}

// Register only core functions (minimal stdlib)
pub fn registerCoreOnly() !void {
    const registry = stdlib_v2.getGlobalRegistry();

    // Register only essential functions
    try registry.register(what_is);
    try IoModule.register();
    try TypesModule.register();

    registry.registerAll();
    std.log.info("Core standard library initialized with {} functions", .{registry.getFunctionCount()});
}

// Register specific modules
pub fn registerMath() !void {
    try MathModule.register();
    const registry = stdlib_v2.getGlobalRegistry();
    registry.registerModule("math");
}

pub fn registerCollections() !void {
    try CollectionsModule.register();
    const registry = stdlib_v2.getGlobalRegistry();
    registry.registerModule("collections");
}

pub fn registerUtils() !void {
    try UtilsModule.register();
    const registry = stdlib_v2.getGlobalRegistry();
    registry.registerModule("utils");
}

pub fn registerTime() !void {
    try TimeModule.register();
    const registry = stdlib_v2.getGlobalRegistry();
    registry.registerModule("time");
}

pub fn registerFs() !void {
    if (enable_fs) {
        try FsModule.register();
        const registry = stdlib_v2.getGlobalRegistry();
        registry.registerModule("filesystem");
    }
}

pub fn registerNetwork() !void {
    if (enable_net) {
        try NetworkModule.register();
        const registry = stdlib_v2.getGlobalRegistry();
        registry.registerModule("network");
    }
}

pub fn registerMatrix() !void {
    try MatrixModule.register();
    const registry = stdlib_v2.getGlobalRegistry();
    registry.registerModule("matrix");
}

// Print documentation for all registered functions
pub fn printDocs() void {
    const registry = stdlib_v2.getGlobalRegistry();
    registry.printDocs();
}

// Print documentation for a specific module
pub fn printModuleDocs(module_name: []const u8) void {
    const registry = stdlib_v2.getGlobalRegistry();

    std.debug.print("=== {} Module Documentation ===\n", .{module_name});

    var found = false;
    for (registry.functions.items) |func| {
        if (std.mem.eql(u8, func.module, module_name)) {
            found = true;

            std.debug.print("\n{}(", .{func.name});
            for (func.params, 0..) |param, i| {
                if (i > 0) std.debug.print(", ", .{});
                std.debug.print("{s}: {s}", .{ param.name, param.type.toString() });
                if (param.optional) std.debug.print("?", .{});
            }
            std.debug.print(") -> {s}\n", .{func.return_type.toString()});
            std.debug.print("  {s}\n", .{func.description});

            if (func.examples.len > 0) {
                std.debug.print("  Examples:\n", .{});
                for (func.examples) |example| {
                    std.debug.print("    {s}\n", .{example});
                }
            }
        }
    }

    if (!found) {
        std.debug.print("No functions found in module '{s}'\n", .{module_name});
    }
}

// Get statistics about registered functions
pub fn getStats() struct {
    total_functions: usize,
    core_functions: usize,
    math_functions: usize,
    io_functions: usize,
    types_functions: usize,
    time_functions: usize,
    utils_functions: usize,
    collections_functions: usize,
    fs_functions: usize,
    network_functions: usize,
    matrix_functions: usize,
} {
    const registry = stdlib_v2.getGlobalRegistry();

    return .{
        .total_functions = registry.getFunctionCount(),
        .core_functions = registry.getModuleFunctionCount("core"),
        .math_functions = registry.getModuleFunctionCount("math"),
        .io_functions = registry.getModuleFunctionCount("io"),
        .types_functions = registry.getModuleFunctionCount("types"),
        .time_functions = registry.getModuleFunctionCount("time"),
        .utils_functions = registry.getModuleFunctionCount("utils"),
        .collections_functions = registry.getModuleFunctionCount("collections"),
        .fs_functions = registry.getModuleFunctionCount("filesystem"),
        .network_functions = registry.getModuleFunctionCount("network"),
        .matrix_functions = registry.getModuleFunctionCount("matrix"),
    };
}

// Print statistics
pub fn printStats() void {
    const stats = getStats();

    std.debug.print("\n=== MufiZ Standard Library Statistics ===\n", .{});
    std.debug.print("Total Functions: {}\n", .{stats.total_functions});
    std.debug.print("\nBy Module:\n", .{});
    std.debug.print("  Core:        {}\n", .{stats.core_functions});
    std.debug.print("  Math:        {}\n", .{stats.math_functions});
    std.debug.print("  I/O:         {}\n", .{stats.io_functions});
    std.debug.print("  Types:       {}\n", .{stats.types_functions});
    std.debug.print("  Time:        {}\n", .{stats.time_functions});
    std.debug.print("  Utils:       {}\n", .{stats.utils_functions});
    std.debug.print("  Collections: {}\n", .{stats.collections_functions});
    std.debug.print("  Filesystem:  {}\n", .{stats.fs_functions});
    std.debug.print("  Network:     {}\n", .{stats.network_functions});
    std.debug.print("  Matrix:      {}\n", .{stats.matrix_functions});

    std.debug.print("\nFeature Flags:\n", .{});
    std.debug.print("  File System: {}\n", .{enable_fs});
    std.debug.print("  Network:     {}\n", .{enable_net});
    std.debug.print("  cURL:        {}\n", .{enable_curl});
}

// List all available modules
pub fn listModules() void {
    std.debug.print("\n=== Available Modules ===\n", .{});
    std.debug.print("  core (1 function)\n", .{});
    std.debug.print("  math (22 functions)\n", .{});
    std.debug.print("  io (4 functions)\n", .{});
    std.debug.print("  types (10 functions)\n", .{});
    std.debug.print("  time (7 functions)\n", .{});
    std.debug.print("  utils (8 functions)\n", .{});
    std.debug.print("  collections (10 functions)\n", .{});
    std.debug.print("  filesystem (10 functions)\n", .{});
    std.debug.print("  network (10 functions)\n", .{});
    std.debug.print("  matrix (20 functions)\n", .{});
}

// Help command implementation
pub fn help(command: ?[]const u8) void {
    if (command == null) {
        std.debug.print("\n=== MufiZ Standard Library Help ===\n", .{});
        std.debug.print("Usage: help [command|module]\n\n", .{});
        std.debug.print("Available commands:\n", .{});
        std.debug.print("  help          - Show this help\n", .{});
        std.debug.print("  help stats    - Show function statistics\n", .{});
        std.debug.print("  help modules  - List all modules\n", .{});
        std.debug.print("  help docs     - Show all function documentation\n", .{});
        std.debug.print("  help <module> - Show documentation for specific module\n", .{});
        std.debug.print("\nAvailable modules: core, math, io, types, time, utils, collections, filesystem, network, matrix\n", .{});
        return;
    }

    const cmd = command.?;

    if (std.mem.eql(u8, cmd, "stats")) {
        printStats();
    } else if (std.mem.eql(u8, cmd, "modules")) {
        listModules();
    } else if (std.mem.eql(u8, cmd, "docs")) {
        printDocs();
    } else {
        // Try as module name
        const registry = stdlib_v2.getGlobalRegistry();
        if (registry.getModuleFunctionCount(cmd) > 0) {
            printModuleDocs(cmd);
        } else {
            std.debug.print("Unknown command or module: {s}\n", .{cmd});
            std.debug.print("Use 'help' to see available options.\n", .{});
        }
    }
}

// Compatibility functions for existing code
pub fn prelude() !void {
    try registerCoreOnly();
}

pub fn addMath() !void {
    try registerMath();
}

pub fn addCollections() !void {
    try registerCollections();
}

pub fn addUtils() !void {
    try registerUtils();
}

pub fn addTime() !void {
    try registerTime();
}

// TODO: Add these when filesystem and network modules are migrated
pub fn addFs() !void {
    try registerFs();
}

pub fn addNet() !void {
    try registerNetwork();
}

pub fn addMatrix() !void {
    try registerMatrix();
}

// Get total function count (for compatibility)
pub fn getTotalFunctionCount() usize {
    const registry = stdlib_v2.getGlobalRegistry();
    return registry.getFunctionCount();
}
