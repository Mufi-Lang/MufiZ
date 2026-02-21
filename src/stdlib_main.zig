const std = @import("std");
const stdlib_core = @import("stdlib_core.zig");
const Value = @import("value.zig").Value;
const vm_h = @import("vm.zig");
const table_h = @import("table.zig");

// Import all migrated modules
const math = @import("stdlib/math.zig");
const io = @import("stdlib/io.zig");
const types = @import("stdlib/types.zig");
// const time = @import("stdlib/time.zig");
const utils = @import("stdlib/utils.zig");
const collections = @import("stdlib/collections.zig");
// const fs = @import("stdlib/fs.zig");
// const network = @import("stdlib/network.zig");
const matrix = @import("stdlib/matrix.zig");
const json = @import("stdlib/json.zig");
const serde = @import("stdlib/serde.zig");

// Feature flags (can be set at compile time)
const enable_fs = @import("features.zig").enable_fs;
const enable_net = @import("features.zig").enable_net;

// Core function implementation for what_is
fn what_is_impl(argc: i32, args: [*]Value) Value {
    _ = argc;
    const conv = @import("conv.zig");
    const object_h = @import("object.zig");
    const type_str = conv.what_is(args[0]);
    // Use copyString which handles memory management properly through the object system
    const str_obj = object_h.copyString(type_str.ptr, type_str.len);
    return Value.init_obj(@ptrCast(str_obj));
}

fn whos_impl(argc: i32, args: [*]Value) Value {
    _ = argc;
    _ = args;

    std.debug.print("\n{s: <20} {s: <15} {s: <20}\n", .{ "Name", "Type", "Value" });
    std.debug.print("------------------------------------------------------------\n", .{});

    const globals = &vm_h.vm.globals;
    if (globals.entries) |entries| {
        for (0..globals.capacity) |i| {
            const entry = &entries[i];
            if (entry.isActive()) {
                const name = entry.key.?;
                if (entry.protected) continue;
                if (table_h.isInternalName(name)) continue;

                const type_name = @import("conv.zig").what_is(entry.value);
                const val_str = @import("value.zig").valueToString(entry.value);

                std.debug.print("{s: <20} {s: <15} {s: <20}\n", .{
                    name.chars[0..name.length],
                    type_name,
                    val_str,
                });
            }
        }
    }
    std.debug.print("------------------------------------------------------------\n", .{});

    return Value.init_nil();
}

fn clear_impl(argc: i32, args: [*]Value) Value {
    const globals = &vm_h.vm.globals;
    const mem_utils = @import("mem_utils.zig");
    const allocator = mem_utils.getAllocator();
    const object_h = @import("object.zig");

    if (argc == 0) {
        // Clear all non-protected, non-internal variables
        if (globals.entries) |entries| {
            // First pass: collect keys to delete
            const ObjString = object_h.ObjString;
            var keys_to_delete = std.ArrayListUnmanaged(?*ObjString){};
            defer keys_to_delete.deinit(allocator);

            for (0..globals.capacity) |i| {
                const entry = &entries[i];
                if (entry.isActive()) {
                    if (entry.protected) continue;
                    if (table_h.isInternalName(entry.key)) continue;
                    keys_to_delete.append(allocator, entry.key) catch continue;
                }
            }

            // Second pass: delete collected keys
            for (keys_to_delete.items) |key| {
                _ = table_h.tableDelete(globals, key);
            }
        }
    } else {
        // Clear specific named variables
        var i: i32 = 0;
        while (i < argc) : (i += 1) {
            const arg = args[@intCast(i)];
            if (arg.is_string()) {
                const name = arg.as_string();
                // Look up the interned string in the VM's string table
                const interned = table_h.tableFindString(&vm_h.vm.strings, name.chars.ptr, name.length, object_h.hashString(name.chars.ptr, name.length));
                if (interned) |key| {
                    _ = table_h.tableDelete(globals, key);
                }
            }
        }
    }

    return Value.init_nil();
}

// Core functions wrapper
pub const what_is = stdlib_core.DefineFunction(
    "what_is",
    "core",
    "Shows the type of a value",
    stdlib_core.OneAny,
    .string,
    &[_][]const u8{
        "what_is(42) -> \"int\"",
        "what_is(\"hello\") -> \"string\"",
        "what_is(true) -> \"bool\"",
    },
    what_is_impl,
);

pub const whos = stdlib_core.DefineFunction(
    "whos",
    "core",
    "List all global variables",
    stdlib_core.NoParams,
    .nil,
    &[_][]const u8{
        "whos()",
    },
    whos_impl,
);

pub const clear = stdlib_core.DefineFunction(
    "clear",
    "core",
    "Clear global variables",
    &[_]stdlib_core.ParamSpec{
        .{ .name = "name1", .type = .string, .optional = true },
        .{ .name = "name2", .type = .string, .optional = true },
        .{ .name = "name3", .type = .string, .optional = true },
    },
    .nil,
    &[_][]const u8{
        "clear()",
        "clear(\"x\")",
        "clear(\"x\", \"y\")",
    },
    clear_impl,
);

// Manual registration functions since AutoRegisterModule is disabled
pub const MathModule = struct {
    pub fn register() !void {
        const registry = stdlib_core.getGlobalRegistry();
        try registry.register(math.ln);
        try registry.register(math.log2);
        try registry.register(math.log10);
        try registry.register(math.pi);
        try registry.register(math.exp);
        try registry.register(math.sin);
        try registry.register(math.cos);
        try registry.register(math.tan);
        try registry.register(math.asin);
        try registry.register(math.acos);
        try registry.register(math.atan);
        try registry.register(math.complex);
        try registry.register(math.abs);
        try registry.register(math.phase);
        try registry.register(math.rand);
        try registry.register(math.randn);
        try registry.register(math.pow);
        try registry.register(math.sqrt);
        try registry.register(math.ceil);
        try registry.register(math.floor);
        try registry.register(math.round);
        try registry.register(math.max);
        try registry.register(math.min);
    }
};

pub const IoModule = struct {
    pub fn register() !void {
        const registry = stdlib_core.getGlobalRegistry();
        try registry.register(io.print);
        try registry.register(io.printf);
        try registry.register(io.println);
        try registry.register(io.input);
    }
};

pub const TypesModule = struct {
    pub fn register() !void {
        const registry = stdlib_core.getGlobalRegistry();
        try registry.register(types.str);
        try registry.register(types.int);
        try registry.register(types.double);
        try registry.register(types.bool_fn);
        try registry.register(types.type_of);
        try registry.register(types.is_nil);
        try registry.register(types.is_string);
        try registry.register(types.is_number);
        try registry.register(types.is_bool);
    }
};

pub const TimeModule = struct {
    pub fn register() !void {
        // Time module registration would go here - temporarily disabled
    }
};

pub const UtilsModule = struct {
    pub fn register() !void {
        const registry = stdlib_core.getGlobalRegistry();
        try registry.register(utils.assert);
        try registry.register(utils.exit);
        try registry.register(utils.panic);
        try registry.register(utils.format);
        try registry.register(utils.equals);
        try registry.register(utils.hash);
        try registry.register(utils.clone);
        try registry.register(utils.identity);
    }
};

pub const CollectionsModule = struct {
    pub fn register() !void {
        const registry = stdlib_core.getGlobalRegistry();
        try registry.register(collections.linked_list);
        try registry.register(collections.hash_table);
        try registry.register(collections.fvec);
        try registry.register(collections.push);
        try registry.register(collections.pop);
        try registry.register(collections.push_front);
        try registry.register(collections.pop_front);
        try registry.register(collections.len);
        try registry.register(collections.get);
        try registry.register(collections.set);
        try registry.register(collections.contains);
        try registry.register(collections.clear);
        try registry.register(collections.range);
        try registry.register(collections.range_to_array);
        try registry.register(collections.put);
        try registry.register(collections.pairs);
        try registry.register(collections.is_empty);
        try registry.register(collections.nth);
        try registry.register(collections.linspace);
        try registry.register(collections.insert);
        try registry.register(collections.remove);
        try registry.register(collections.slice);
        try registry.register(collections.merge);
        try registry.register(collections.search);
        try registry.register(collections.sort);
        try registry.register(collections.splice);
        try registry.register(collections.sum);
        try registry.register(collections.mean);
        try registry.register(collections.vari);
        try registry.register(collections.stddev);
        try registry.register(collections.std_alias);
        try registry.register(collections.minl);
        try registry.register(collections.maxl);
        try registry.register(collections.reverse);
    }
};

pub const FsModule = struct {
    pub fn register() !void {
        // FS module registration would go here - temporarily disabled
    }
};

pub const NetworkModule = struct {
    pub fn register() !void {
        // Network module registration would go here - temporarily disabled
    }
};

pub const MatrixModule = struct {
    pub fn register() !void {
        const registry = stdlib_core.getGlobalRegistry();
        try registry.register(matrix.eye);
        try registry.register(matrix.ones);
        try registry.register(matrix.zeros);
        try registry.register(matrix.rand);
        try registry.register(matrix.randn);
        try registry.register(matrix.transpose);
        try registry.register(matrix.det);
        try registry.register(matrix.inv);
        try registry.register(matrix.trace);
        try registry.register(matrix.size);
        try registry.register(matrix.norm);
        try registry.register(matrix.matrix_get);
        try registry.register(matrix.matrix_set);
        try registry.register(matrix.flatten);
        try registry.register(matrix.horzcat);
        try registry.register(matrix.vertcat);
        try registry.register(matrix.matrix_create);
        try registry.register(matrix.reshape);
        try registry.register(matrix.rref);
        try registry.register(matrix.rank);
        try registry.register(matrix.lu);
        try registry.register(matrix.solve);
    }
};

pub const JsonModule = struct {
    pub fn register() !void {
        const registry = stdlib_core.getGlobalRegistry();
        try registry.register(json.json_parse);
        try registry.register(json.json_stringify);
        try registry.register(json.json_is_valid);
        try registry.register(json.json_pretty);
        try registry.register(json.json_get);
        try registry.register(json.json_set);
    }
};

pub const SerdeModule = struct {
    pub fn register() !void {
        const registry = stdlib_core.getGlobalRegistry();
        try registry.register(serde.serde_serialize);
        try registry.register(serde.serde_deserialize);
        try registry.register(serde.serde_to_json);
        try registry.register(serde.serde_from_json);
        try registry.register(serde.serde_to_toml);
        try registry.register(serde.serde_from_toml);
        try registry.register(serde.serde_to_yaml);
        try registry.register(serde.serde_from_yaml);
        try registry.register(serde.serde_detect_format);
        try registry.register(serde.serde_validate);
    }
};

// Main initialization function
pub fn initializeStdlib() !void {
    // Set feature flags
    stdlib_core.setFeatureFlags(.{
        .enable_fs = enable_fs,
        .enable_net = enable_net,
    });

    const registry = stdlib_core.getGlobalRegistry();

    // Register core functions (except clear and whos which need to override collections)
    try registry.register(what_is);

    // Register all modules by default for backward compatibility
    // Users can explicitly use imports to load modules on-demand, but all modules
    // are available without imports to maintain backward compatibility
    try MathModule.register();
    try IoModule.register();
    try TypesModule.register();
    try UtilsModule.register();
    try CollectionsModule.register();

    // Register core functions that need to override module functions
    // These must come after module registration to take precedence
    try registry.register(whos);
    try registry.register(clear);

    // Conditionally register optional modules
    if (enable_fs) {
        try FsModule.register();
    }

    if (enable_net) {
        try NetworkModule.register();
    }

    // Always register matrix, json, and serde modules
    try MatrixModule.register();
    try JsonModule.register();
    try SerdeModule.register();

    // std.log.info("Standard library initialized with all modules", .{});
}

// Register all functions with the VM
pub fn registerWithVM() void {
    const registry = stdlib_core.getGlobalRegistry();
    registry.registerAll();
}

// Register only core functions (minimal stdlib)
pub fn registerCoreOnly() !void {
    const registry = stdlib_core.getGlobalRegistry();

    // Register only essential functions
    try registry.register(what_is);
    try registry.register(whos);
    try registry.register(clear);
    try IoModule.register();
    try TypesModule.register();

    registry.registerAll();
    std.log.info("Core standard library initialized with {d} functions", .{registry.getFunctionCount()});
}

// Register specific modules
pub fn registerMath() !void {
    try MathModule.register();
    const registry = stdlib_core.getGlobalRegistry();
    registry.registerModule("math");
}

pub fn registerCollections() !void {
    try CollectionsModule.register();
    const registry = stdlib_core.getGlobalRegistry();
    registry.registerModule("collections");
}

pub fn registerUtils() !void {
    try UtilsModule.register();
    const registry = stdlib_core.getGlobalRegistry();
    registry.registerModule("utils");
}

pub fn registerTime() !void {
    try TimeModule.register();
    const registry = stdlib_core.getGlobalRegistry();
    registry.registerModule("time");
}

pub fn registerFs() !void {
    if (enable_fs) {
        try FsModule.register();
        const registry = stdlib_core.getGlobalRegistry();
        registry.registerModule("filesystem");
    }
}

pub fn registerNetwork() !void {
    if (enable_net) {
        try NetworkModule.register();
        const registry = stdlib_core.getGlobalRegistry();
        registry.registerModule("network");
    }
}

pub fn registerMatrix() !void {
    try MatrixModule.register();
    const registry = stdlib_core.getGlobalRegistry();
    registry.registerModule("matrix");
}

pub fn registerJson() !void {
    try JsonModule.register();
    const registry = stdlib_core.getGlobalRegistry();
    registry.registerModule("json");
}

pub fn registerSerde() !void {
    try SerdeModule.register();
    const registry = stdlib_core.getGlobalRegistry();
    registry.registerModule("serde");
}

// Print documentation for all registered functions
pub fn printDocs() void {
    const registry = stdlib_core.getGlobalRegistry();
    registry.printDocs();
}

// Print documentation for a specific module
pub fn printModuleDocs(module_name: []const u8) void {
    const registry = stdlib_core.getGlobalRegistry();

    std.debug.print("=== {s} Module Documentation ===\n", .{module_name});

    var found = false;
    for (registry.functions.items) |func| {
        if (std.mem.eql(u8, func.module, module_name)) {
            found = true;

            std.debug.print("\n{s}(", .{func.name});
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
    json_functions: usize,
    serde_functions: usize,
} {
    const registry = stdlib_core.getGlobalRegistry();

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
        .json_functions = registry.getModuleFunctionCount("json"),
        .serde_functions = registry.getModuleFunctionCount("serde"),
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
    std.debug.print("  JSON:        {}\n", .{stats.json_functions});
    std.debug.print("  Serde:       {}\n", .{stats.serde_functions});

    std.debug.print("\nFeature Flags:\n", .{});
    std.debug.print("  File System: {}\n", .{enable_fs});
    std.debug.print("  Network:     {}\n", .{enable_net});
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
    std.debug.print("  json (6 functions)\n", .{});
    std.debug.print("  serde (10 functions)\n", .{});
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
        std.debug.print("\nAvailable modules: core, math, io, types, time, utils, collections, filesystem, network, matrix, json\n", .{});
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
        const registry = stdlib_core.getGlobalRegistry();
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

pub fn addFs() !void {
    try registerFs();
}

pub fn addNet() !void {
    try registerNetwork();
}

pub fn addMatrix() !void {
    try registerMatrix();
}

pub fn addJson() !void {
    try registerJson();
}

pub fn addSerde() !void {
    try registerSerde();
}

// Get total function count (for compatibility)
pub fn getTotalFunctionCount() usize {
    const registry = stdlib_core.getGlobalRegistry();
    return registry.getFunctionCount();
}
