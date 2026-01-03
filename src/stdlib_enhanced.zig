const std = @import("std");
const enable_curl = @import("features.zig").enable_curl;
const enable_fs = @import("features.zig").enable_fs;
const enable_net = @import("features.zig").enable_net;

const NativeFn = @import("object.zig").NativeFn;
const object_h = @import("object.zig");
pub const collections = @import("stdlib/collections.zig");
pub const fs = @import("stdlib/fs.zig");
pub const io = @import("stdlib/io.zig");
pub const math = @import("stdlib/math.zig");
pub const network = @import("stdlib/network.zig");
pub const time = @import("stdlib/time.zig");
pub const types = @import("stdlib/types.zig");
pub const utils = @import("stdlib/utils.zig");
pub const matrix = @import("stdlib/matrix.zig");

// V2 stdlib integration
const stdlib_v2 = @import("stdlib_v2.zig");
const stdlib_v2_main = @import("stdlib_v2_main.zig");

const Value = @import("value.zig").Value;
const vm = @import("vm.zig");

// Legacy builtin definition for backwards compatibility
pub const BuiltinDef = struct {
    name: []const u8,
    func: NativeFn,
    params: []const u8,
    description: []const u8,
    module: []const u8,
    version: enum { v1, v2 } = .v1,
};

// Legacy function arrays (kept for compatibility)
pub const CORE_FUNCTIONS = [_]BuiltinDef{
    .{ .name = "what_is", .func = what_is, .params = "value", .description = "Shows the type of a value", .module = "core" },
    .{ .name = "input", .func = io.input, .params = "", .description = "Reads input from stdin", .module = "core" },
    .{ .name = "double", .func = types.double, .params = "value", .description = "Converts value to double", .module = "core" },
    .{ .name = "int", .func = types.int, .params = "value", .description = "Converts value to int", .module = "core" },
    .{ .name = "str", .func = types.str, .params = "value", .description = "Converts value to string", .module = "core" },
};

pub const MATH_FUNCTIONS = [_]BuiltinDef{
    .{ .name = "ln", .func = math.ln, .params = "number", .description = "Natural logarithm", .module = "math" },
    .{ .name = "log2", .func = math.log2, .params = "number", .description = "Base-2 logarithm", .module = "math" },
    .{ .name = "log10", .func = math.log10, .params = "number", .description = "Base-10 logarithm", .module = "math" },
    .{ .name = "pi", .func = math.pi, .params = "", .description = "Pi constant", .module = "math" },
    .{ .name = "sin", .func = math.sin, .params = "number", .description = "Sine function", .module = "math" },
    .{ .name = "cos", .func = math.cos, .params = "number", .description = "Cosine function", .module = "math" },
    .{ .name = "tan", .func = math.tan, .params = "number", .description = "Tangent function", .module = "math" },
    .{ .name = "asin", .func = math.asin, .params = "number", .description = "Arcsine function", .module = "math" },
    .{ .name = "acos", .func = math.acos, .params = "number", .description = "Arccosine function", .module = "math" },
    .{ .name = "atan", .func = math.atan, .params = "number", .description = "Arctangent function", .module = "math" },
    .{ .name = "complex", .func = math.complex, .params = "real, imag", .description = "Creates complex number", .module = "math" },
    .{ .name = "abs", .func = math.abs, .params = "number", .description = "Absolute value", .module = "math" },
    .{ .name = "phase", .func = math.phase, .params = "complex", .description = "Phase of complex number", .module = "math" },
    .{ .name = "rand", .func = math.rand, .params = "", .description = "Random float [0,1)", .module = "math" },
    .{ .name = "randn", .func = math.randn, .params = "", .description = "Random normal distribution", .module = "math" },
    .{ .name = "pow", .func = math.pow, .params = "base, exp", .description = "Power function", .module = "math" },
    .{ .name = "sqrt", .func = math.sqrt, .params = "number", .description = "Square root", .module = "math" },
    .{ .name = "ceil", .func = math.ceil, .params = "number", .description = "Ceiling function", .module = "math" },
    .{ .name = "floor", .func = math.floor, .params = "number", .description = "Floor function", .module = "math" },
    .{ .name = "round", .func = math.round, .params = "number", .description = "Round to nearest integer", .module = "math" },
    .{ .name = "max", .func = math.max, .params = "a, b", .description = "Maximum of two numbers", .module = "math" },
    .{ .name = "min", .func = math.min, .params = "a, b", .description = "Minimum of two numbers", .module = "math" },
};

pub const COLLECTION_FUNCTIONS = [_]BuiltinDef{
    .{ .name = "linked_list", .func = collections.linked_list, .params = "", .description = "Creates new linked list", .module = "collections" },
    .{ .name = "hash_table", .func = collections.hash_table, .params = "", .description = "Creates new hash table", .module = "collections" },
    .{ .name = "fvec", .func = collections.fvec, .params = "capacity", .description = "Creates new float vector", .module = "collections" },
    .{ .name = "push", .func = collections.push, .params = "list, value", .description = "Adds element to list", .module = "collections" },
    .{ .name = "pop", .func = collections.pop, .params = "list", .description = "Removes last element", .module = "collections" },
    .{ .name = "push_front", .func = collections.push_front, .params = "list, value", .description = "Adds element to front", .module = "collections" },
    .{ .name = "pop_front", .func = collections.pop_front, .params = "list", .description = "Removes first element", .module = "collections" },
    .{ .name = "len", .func = collections.len, .params = "collection", .description = "Gets length of collection", .module = "collections" },
    .{ .name = "get", .func = collections.get, .params = "collection, index", .description = "Gets element at index", .module = "collections" },
    // .{ .name = "set", .func = collections.set, .params = "collection, index, value", .description = "Sets element at index", .module = "collections" },
    .{ .name = "contains", .func = collections.contains, .params = "collection, value", .description = "Checks if value exists", .module = "collections" },
    .{ .name = "clear", .func = collections.clear, .params = "collection", .description = "Removes all elements", .module = "collections" },
    // .{ .name = "keys", .func = collections.keys, .params = "hash_table", .description = "Gets all keys from table", .module = "collections" },
    // .{ .name = "values", .func = collections.values, .params = "hash_table", .description = "Gets all values from table", .module = "collections" },
    // .{ .name = "entries", .func = collections.entries, .params = "hash_table", .description = "Gets key-value pairs", .module = "collections" },
    // .{ .name = "range", .func = collections.range, .params = "start, end, step?", .description = "Creates range object", .module = "collections" },
    .{ .name = "slice", .func = collections.slice_fn, .params = "collection, start, end?", .description = "Creates slice of collection", .module = "collections" },
    .{ .name = "reverse", .func = collections.reverse, .params = "list", .description = "Reverses list in place", .module = "collections" },
    .{ .name = "sort", .func = collections.sort, .params = "list", .description = "Sorts list in place", .module = "collections" },
    // .{ .name = "find", .func = collections.find, .params = "collection, value", .description = "Finds index of value", .module = "collections" },
    // .{ .name = "filter", .func = collections.filter, .params = "list, predicate", .description = "Filters list by predicate", .module = "collections" },
    // .{ .name = "map", .func = collections.map, .params = "list, function", .description = "Maps function over list", .module = "collections" },
    // .{ .name = "reduce", .func = collections.reduce, .params = "list, function, initial?", .description = "Reduces list to single value", .module = "collections" },
    // .{ .name = "sum", .func = collections.sum, .params = "numeric_list", .description = "Sums all numbers in list", .module = "collections" },
    // .{ .name = "mean", .func = collections.mean, .params = "numeric_list", .description = "Calculates mean of numbers", .module = "collections" },
    // .{ .name = "median", .func = collections.median, .params = "numeric_list", .description = "Calculates median of numbers", .module = "collections" },
    // .{ .name = "mode", .func = collections.mode, .params = "list", .description = "Finds most common value", .module = "collections" },
    // .{ .name = "unique", .func = collections.unique, .params = "list", .description = "Gets unique values from list", .module = "collections" },
    // .{ .name = "concat", .func = collections.concat, .params = "list1, list2", .description = "Concatenates two lists", .module = "collections" },
    // .{ .name = "flatten", .func = collections.flatten, .params = "nested_list", .description = "Flattens nested list", .module = "collections" },
    // .{ .name = "zip", .func = collections.zip, .params = "list1, list2", .description = "Zips two lists together", .module = "collections" },
    // .{ .name = "enumerate", .func = collections.enumerate, .params = "list", .description = "Returns indexed pairs", .module = "collections" },
    // .{ .name = "shuffle", .func = collections.shuffle, .params = "list", .description = "Shuffles list randomly", .module = "collections" },
    // .{ .name = "sample", .func = collections.sample, .params = "list, n", .description = "Gets random sample of n elements", .module = "collections" },
    // .{ .name = "partition", .func = collections.partition, .params = "list, predicate", .description = "Partitions list by predicate", .module = "collections" },
    // .{ .name = "group_by", .func = collections.group_by, .params = "list, key_func", .description = "Groups elements by key function", .module = "collections" },
    // .{ .name = "count", .func = collections.count, .params = "collection, value", .description = "Counts occurrences of value", .module = "collections" },
    // .{ .name = "first", .func = collections.first, .params = "collection", .description = "Gets first element", .module = "collections" },
    // .{ .name = "last", .func = collections.last, .params = "collection", .description = "Gets last element", .module = "collections" },
    .{ .name = "nth", .func = collections.nth, .params = "collection, n", .description = "Gets nth element", .module = "collections" },
    // .{ .name = "take", .func = collections.take, .params = "collection, n", .description = "Takes first n elements", .module = "collections" },
    // .{ .name = "drop", .func = collections.drop, .params = "collection, n", .description = "Drops first n elements", .module = "collections" },
    // .{ .name = "take_while", .func = collections.take_while, .params = "list, predicate", .description = "Takes while predicate is true", .module = "collections" },
    // .{ .name = "drop_while", .func = collections.drop_while, .params = "list, predicate", .description = "Drops while predicate is true", .module = "collections" },
    // .{ .name = "any", .func = collections.any, .params = "list, predicate?", .description = "Checks if any element matches", .module = "collections" },
    // .{ .name = "all", .func = collections.all, .params = "list, predicate?", .description = "Checks if all elements match", .module = "collections" },
    .{ .name = "is_empty", .func = collections.is_empty, .params = "collection", .description = "Checks if collection is empty", .module = "collections" },
    // .{ .name = "to_list", .func = collections.to_list, .params = "iterable", .description = "Converts iterable to list", .module = "collections" },
    // .{ .name = "to_set", .func = collections.to_set, .params = "list", .description = "Converts list to set (unique values)", .module = "collections" },
    // .{ .name = "union", .func = collections.union, .params = "set1, set2", .description = "Union of two sets", .module = "collections" },
    // .{ .name = "intersection", .func = collections.intersection, .params = "set1, set2", .description = "Intersection of two sets", .module = "collections" },
    // .{ .name = "difference", .func = collections.difference, .params = "set1, set2", .description = "Difference between sets", .module = "collections" },
    // .{ .name = "symmetric_difference", .func = collections.symmetric_difference, .params = "set1, set2", .description = "Symmetric difference of sets", .module = "collections" },
};

pub const FILESYSTEM_FUNCTIONS = [_]BuiltinDef{
    .{ .name = "read_file", .func = fs.read_file, .params = "path", .description = "Read file contents as string", .module = "fs" },
    .{ .name = "write_file", .func = fs.write_file, .params = "path, content", .description = "Write string to file", .module = "fs" },
};

pub const TIME_FUNCTIONS = [_]BuiltinDef{
    .{ .name = "now", .func = time.now, .params = "", .description = "Current Unix timestamp", .module = "time" },
    .{ .name = "now_ms", .func = time.now_ms, .params = "", .description = "Current timestamp in milliseconds", .module = "time" },
    .{ .name = "now_ns", .func = time.now_ns, .params = "", .description = "Current timestamp in nanoseconds", .module = "time" },
};

pub const UTIL_FUNCTIONS = [_]BuiltinDef{
    .{ .name = "assert", .func = utils.assert, .params = "condition, expected?", .description = "Assert condition or equality", .module = "utils" },
    .{ .name = "exit", .func = utils.exit, .params = "code?", .description = "Exit program with code", .module = "utils" },
    .{ .name = "sleep", .func = utils.sleep, .params = "seconds", .description = "Sleep for specified time", .module = "utils" },
    .{ .name = "panic", .func = utils.panic_fn, .params = "message?", .description = "Panic with message", .module = "utils" },
    .{ .name = "format", .func = utils.format_str, .params = "template, args...", .description = "Format string with placeholders", .module = "utils" },
};

pub const NETWORK_FUNCTIONS = [_]BuiltinDef{
    .{ .name = "http_get", .func = network.http_get, .params = "url", .description = "HTTP GET request", .module = "network" },
    .{ .name = "http_post", .func = network.http_post, .params = "url, data", .description = "HTTP POST request", .module = "network" },
    .{ .name = "tcp_connect", .func = network.tcp_connect, .params = "host, port", .description = "TCP connection", .module = "network" },
    .{ .name = "tcp_send", .func = network.tcp_send, .params = "socket, data", .description = "Send data over TCP", .module = "network" },
    .{ .name = "tcp_recv", .func = network.tcp_recv, .params = "socket, size", .description = "Receive data from TCP", .module = "network" },
    .{ .name = "tcp_close", .func = network.tcp_close, .params = "socket", .description = "Close TCP connection", .module = "network" },
};

pub const MATRIX_FUNCTIONS = [_]BuiltinDef{
    // Matrix functions temporarily commented out - migrated to stdlib_v2
    // .{ .name = "matrix", .func = matrix.matrix, .params = "rows, cols", .description = "Create matrix", .module = "matrix" },
    // .{ .name = "matrix_get", .func = matrix.matrix_get, .params = "matrix, row, col", .description = "Get matrix element", .module = "matrix" },
    // .{ .name = "matrix_set", .func = matrix.matrix_set, .params = "matrix, row, col, value", .description = "Set matrix element", .module = "matrix" },
    // .{ .name = "matrix_mul", .func = matrix.matrix_mul, .params = "a, b", .description = "Matrix multiplication", .module = "matrix" },
    // .{ .name = "matrix_add", .func = matrix.matrix_add, .params = "a, b", .description = "Matrix addition", .module = "matrix" },
    // .{ .name = "matrix_sub", .func = matrix.matrix_sub, .params = "a, b", .description = "Matrix subtraction", .module = "matrix" },
    // .{ .name = "matrix_transpose", .func = matrix.matrix_transpose, .params = "matrix", .description = "Matrix transpose", .module = "matrix" },
    // .{ .name = "matrix_det", .func = matrix.matrix_det, .params = "matrix", .description = "Matrix determinant", .module = "matrix" },
    // .{ .name = "matrix_inv", .func = matrix.matrix_inv, .params = "matrix", .description = "Matrix inverse", .module = "matrix" },
    // .{ .name = "identity_matrix", .func = matrix.identity_matrix, .params = "size", .description = "Create identity matrix", .module = "matrix" },
    // .{ .name = "zero_matrix", .func = matrix.zero_matrix, .params = "rows, cols", .description = "Create zero matrix", .module = "matrix" },
    // .{ .name = "ones_matrix", .func = matrix.ones_matrix, .params = "rows, cols", .description = "Create ones matrix", .module = "matrix" },
    // .{ .name = "random_matrix", .func = matrix.random_matrix, .params = "rows, cols", .description = "Create random matrix", .module = "matrix" },
    // .{ .name = "matrix_rows", .func = matrix.matrix_rows, .params = "matrix", .description = "Get number of rows", .module = "matrix" },
    // .{ .name = "matrix_cols", .func = matrix.matrix_cols, .params = "matrix", .description = "Get number of columns", .module = "matrix" },
    // .{ .name = "matrix_trace", .func = matrix.matrix_trace, .params = "matrix", .description = "Matrix trace (sum of diagonal)", .module = "matrix" },
    // .{ .name = "matrix_norm", .func = matrix.matrix_norm, .params = "matrix", .description = "Frobenius norm", .module = "matrix" },
};

// Configuration for stdlib version
pub const StdlibVersion = enum {
    v1_legacy, // Use old system only
    v2_new, // Use new system only
    hybrid, // Use both (migration mode)
};

var current_version: StdlibVersion = .v1_legacy;

// Set which stdlib version to use
pub fn setVersion(version: StdlibVersion) void {
    current_version = version;
}

pub fn getVersion() StdlibVersion {
    return current_version;
}

// Enhanced initialization
fn defineNative(name: []const u8, func: NativeFn) void {
    vm.defineNative(@ptrCast(@constCast(name)), @ptrCast(func));
}

fn registerFunctions(functions: []const BuiltinDef) void {
    for (functions) |func| {
        defineNative(func.name, func.func);
    }
}

// Public API functions with version support
pub fn prelude() void {
    switch (current_version) {
        .v1_legacy => {
            registerFunctions(&CORE_FUNCTIONS);
        },
        .v2_new => {
            stdlib_v2_main.registerCoreOnly() catch |err| {
                std.log.err("Failed to initialize v2 core: {}", .{err});
                registerFunctions(&CORE_FUNCTIONS); // fallback
            };
        },
        .hybrid => {
            registerFunctions(&CORE_FUNCTIONS);
            stdlib_v2_main.registerCoreOnly() catch {
                std.log.warn("V2 core registration failed, using v1 only", .{});
            };
        },
    }
}

pub fn addMath() void {
    switch (current_version) {
        .v1_legacy => {
            registerFunctions(&MATH_FUNCTIONS);
        },
        .v2_new => {
            stdlib_v2_main.registerMath() catch |err| {
                std.log.err("Failed to initialize v2 math: {}", .{err});
                registerFunctions(&MATH_FUNCTIONS); // fallback
            };
        },
        .hybrid => {
            registerFunctions(&MATH_FUNCTIONS);
            stdlib_v2_main.registerMath() catch {
                std.log.warn("V2 math registration failed, using v1 only", .{});
            };
        },
    }
}

pub fn addCollections() void {
    switch (current_version) {
        .v1_legacy => {
            registerFunctions(&COLLECTION_FUNCTIONS);
        },
        .v2_new => {
            stdlib_v2_main.registerCollections() catch |err| {
                std.log.err("Failed to initialize v2 collections: {}", .{err});
                registerFunctions(&COLLECTION_FUNCTIONS); // fallback
            };
        },
        .hybrid => {
            registerFunctions(&COLLECTION_FUNCTIONS);
            stdlib_v2_main.registerCollections() catch {
                std.log.warn("V2 collections registration failed, using v1 only", .{});
            };
        },
    }
}

pub fn addFs() void {
    if (enable_fs) {
        switch (current_version) {
            .v1_legacy, .hybrid => {
                registerFunctions(&FILESYSTEM_FUNCTIONS);
            },
            .v2_new => {
                std.log.warn("Filesystem functions not yet migrated to v2, using v1", .{});
                registerFunctions(&FILESYSTEM_FUNCTIONS);
            },
        }
    } else {
        std.log.warn("Filesystem functions are disabled!", .{});
    }
}

pub fn addTime() void {
    switch (current_version) {
        .v1_legacy => {
            registerFunctions(&TIME_FUNCTIONS);
        },
        .v2_new => {
            stdlib_v2_main.registerTime() catch |err| {
                std.log.err("Failed to initialize v2 time: {}", .{err});
                registerFunctions(&TIME_FUNCTIONS); // fallback
            };
        },
        .hybrid => {
            registerFunctions(&TIME_FUNCTIONS);
            stdlib_v2_main.registerTime() catch {
                std.log.warn("V2 time registration failed, using v1 only", .{});
            };
        },
    }
}

pub fn addUtils() void {
    switch (current_version) {
        .v1_legacy => {
            registerFunctions(&UTIL_FUNCTIONS);
        },
        .v2_new => {
            stdlib_v2_main.registerUtils() catch |err| {
                std.log.err("Failed to initialize v2 utils: {}", .{err});
                registerFunctions(&UTIL_FUNCTIONS); // fallback
            };
        },
        .hybrid => {
            registerFunctions(&UTIL_FUNCTIONS);
            stdlib_v2_main.registerUtils() catch {
                std.log.warn("V2 utils registration failed, using v1 only", .{});
            };
        },
    }
}

pub fn addNet() void {
    if (enable_net) {
        switch (current_version) {
            .v1_legacy, .hybrid => {
                registerFunctions(&NETWORK_FUNCTIONS);
            },
            .v2_new => {
                std.log.warn("Network functions not yet migrated to v2, using v1", .{});
                registerFunctions(&NETWORK_FUNCTIONS);
            },
        }
    } else {
        std.debug.print("Network module is disabled. Enable with -Denable_net\n", .{});
    }
}

pub fn addMatrix() void {
    switch (current_version) {
        .v1_legacy, .hybrid => {
            registerFunctions(&MATRIX_FUNCTIONS);
        },
        .v2_new => {
            std.log.warn("Matrix functions not yet migrated to v2, using v1", .{});
            registerFunctions(&MATRIX_FUNCTIONS);
        },
    }
}

// Enhanced documentation functions
pub fn printDocs() void {
    switch (current_version) {
        .v1_legacy => {
            printLegacyDocs();
        },
        .v2_new => {
            stdlib_v2_main.printDocs();
        },
        .hybrid => {
            printHybridDocs();
        },
    }
}

fn printLegacyDocs() void {
    std.debug.print("\n=== MufiZ Standard Library (Legacy) ===\n", .{});
    printModuleDocs("Core", &CORE_FUNCTIONS);
    printModuleDocs("Math", &MATH_FUNCTIONS);
    printModuleDocs("Collections", &COLLECTION_FUNCTIONS);
    if (enable_fs) printModuleDocs("Filesystem", &FILESYSTEM_FUNCTIONS);
    if (enable_net) printModuleDocs("Network", &NETWORK_FUNCTIONS);
    printModuleDocs("Time", &TIME_FUNCTIONS);
    printModuleDocs("Utils", &UTIL_FUNCTIONS);
    printModuleDocs("Matrix", &MATRIX_FUNCTIONS);

    std.debug.print("\nTotal functions: {}\n", .{getTotalFunctionCount()});
}

fn printHybridDocs() void {
    std.debug.print("\n=== MufiZ Standard Library (Hybrid Mode) ===\n", .{});
    std.debug.print("Running both legacy (v1) and new (v2) systems\n\n", .{});

    // V2 functions
    std.debug.print("V2 Functions:\n", .{});
    stdlib_v2_main.printDocs();

    // V1 functions not yet migrated
    std.debug.print("\nV1 Legacy Functions (not yet migrated):\n", .{});
    if (enable_fs) printModuleDocs("Filesystem", &FILESYSTEM_FUNCTIONS);
    if (enable_net) printModuleDocs("Network", &NETWORK_FUNCTIONS);
    printModuleDocs("Matrix", &MATRIX_FUNCTIONS);

    const v1_count = getTotalFunctionCount();
    const v2_count = stdlib_v2_main.getTotalFunctionCount();
    std.debug.print("\nTotal functions: {} (V1: {}, V2: {})\n", .{ v1_count + v2_count, v1_count, v2_count });
}

pub fn printModuleDocs(module_name: []const u8, functions: []const BuiltinDef) void {
    std.debug.print("\n=== {s} Module ({d} functions) ===\n", .{ module_name, functions.len });
    for (functions) |func| {
        if (func.params.len > 0) {
            std.debug.print("  {s}({s}) - {s}\n", .{ func.name, func.params, func.description });
        } else {
            std.debug.print("  {s}() - {s}\n", .{ func.name, func.description });
        }
    }
}

// Enhanced help system
pub fn help(command: ?[]const u8) void {
    if (command == null) {
        std.debug.print("\n=== MufiZ Standard Library Help ===\n", .{});
        std.debug.print("Current version: {}\n\n", .{current_version});

        std.debug.print("Commands:\n", .{});
        std.debug.print("  help              - Show this help\n", .{});
        std.debug.print("  help docs         - Show all function documentation\n", .{});
        std.debug.print("  help stats        - Show function statistics\n", .{});
        std.debug.print("  help modules      - List available modules\n", .{});
        std.debug.print("  help <module>     - Show documentation for specific module\n", .{});
        std.debug.print("  help version      - Show version information\n", .{});
        std.debug.print("  help migrate      - Show migration guide to v2\n", .{});

        std.debug.print("\nAvailable modules:\n", .{});
        std.debug.print("  core, math, collections, time, utils", .{});
        if (enable_fs) std.debug.print(", fs", .{});
        if (enable_net) std.debug.print(", network", .{});
        std.debug.print(", matrix\n", .{});

        return;
    }

    const cmd = command.?;

    if (std.mem.eql(u8, cmd, "docs")) {
        printDocs();
    } else if (std.mem.eql(u8, cmd, "stats")) {
        printStats();
    } else if (std.mem.eql(u8, cmd, "modules")) {
        listModules();
    } else if (std.mem.eql(u8, cmd, "version")) {
        printVersionInfo();
    } else if (std.mem.eql(u8, cmd, "migrate")) {
        printMigrationGuide();
    } else {
        // Try as module name
        switch (current_version) {
            .v2_new, .hybrid => {
                stdlib_v2_main.help(cmd);
            },
            .v1_legacy => {
                if (std.mem.eql(u8, cmd, "core")) {
                    printModuleDocs("Core", &CORE_FUNCTIONS);
                } else if (std.mem.eql(u8, cmd, "math")) {
                    printModuleDocs("Math", &MATH_FUNCTIONS);
                } else if (std.mem.eql(u8, cmd, "collections")) {
                    printModuleDocs("Collections", &COLLECTION_FUNCTIONS);
                } else if (std.mem.eql(u8, cmd, "time")) {
                    printModuleDocs("Time", &TIME_FUNCTIONS);
                } else if (std.mem.eql(u8, cmd, "utils")) {
                    printModuleDocs("Utils", &UTIL_FUNCTIONS);
                } else if (std.mem.eql(u8, cmd, "matrix")) {
                    printModuleDocs("Matrix", &MATRIX_FUNCTIONS);
                } else if (std.mem.eql(u8, cmd, "fs") and enable_fs) {
                    printModuleDocs("Filesystem", &FILESYSTEM_FUNCTIONS);
                } else if (std.mem.eql(u8, cmd, "network") and enable_net) {
                    printModuleDocs("Network", &NETWORK_FUNCTIONS);
                } else {
                    std.debug.print("Unknown module: {s}\n", .{cmd});
                }
            },
        }
    }
}

fn printStats() void {
    std.debug.print("\n=== Function Statistics ===\n", .{});
    std.debug.print("Version: {}\n\n", .{current_version});

    switch (current_version) {
        .v1_legacy => {
            std.debug.print("V1 Legacy Functions:\n", .{});
            std.debug.print("  Core:        {}\n", .{CORE_FUNCTIONS.len});
            std.debug.print("  Math:        {}\n", .{MATH_FUNCTIONS.len});
            std.debug.print("  Collections: {}\n", .{COLLECTION_FUNCTIONS.len});
            std.debug.print("  Time:        {}\n", .{TIME_FUNCTIONS.len});
            std.debug.print("  Utils:       {}\n", .{UTIL_FUNCTIONS.len});
            if (enable_fs) std.debug.print("  Filesystem:  {}\n", .{FILESYSTEM_FUNCTIONS.len});
            if (enable_net) std.debug.print("  Network:     {}\n", .{NETWORK_FUNCTIONS.len});
            std.debug.print("  Matrix:      {}\n", .{MATRIX_FUNCTIONS.len});
            std.debug.print("\nTotal: {}\n", .{getTotalFunctionCount()});
        },
        .v2_new => {
            stdlib_v2_main.printStats();
        },
        .hybrid => {
            const v1_count = getTotalFunctionCount();
            const v2_count = stdlib_v2_main.getTotalFunctionCount();
            std.debug.print("Hybrid Mode - Total: {} (V1: {}, V2: {})\n", .{ v1_count + v2_count, v1_count, v2_count });

            std.debug.print("\nV2 Functions:\n", .{});
            const stats = stdlib_v2_main.getStats();
            std.debug.print("  Core:        {}\n", .{stats.core_functions});
            std.debug.print("  Math:        {}\n", .{stats.math_functions});
            std.debug.print("  Collections: {}\n", .{stats.collections_functions});
            std.debug.print("  Time:        {}\n", .{stats.time_functions});
            std.debug.print("  Utils:       {}\n", .{stats.utils_functions});
            std.debug.print("  I/O:         {}\n", .{stats.io_functions});
            std.debug.print("  Types:       {}\n", .{stats.types_functions});

            std.debug.print("\nV1 Legacy (not migrated):\n", .{});
            if (enable_fs) std.debug.print("  Filesystem:  {}\n", .{FILESYSTEM_FUNCTIONS.len});
            if (enable_net) std.debug.print("  Network:     {}\n", .{NETWORK_FUNCTIONS.len});
            std.debug.print("  Matrix:      {}\n", .{MATRIX_FUNCTIONS.len});
        },
    }

    std.debug.print("\nFeature Flags:\n", .{});
    std.debug.print("  File System: {}\n", .{enable_fs});
    std.debug.print("  Network:     {}\n", .{enable_net});
    std.debug.print("  cURL:        {}\n", .{enable_curl});
}

fn listModules() void {
    std.debug.print("\n=== Available Modules ===\n", .{});

    switch (current_version) {
        .v1_legacy => {
            std.debug.print("V1 Legacy Modules:\n", .{});
            std.debug.print("  core ({} functions)\n", .{CORE_FUNCTIONS.len});
            std.debug.print("  math ({} functions)\n", .{MATH_FUNCTIONS.len});
            std.debug.print("  collections ({} functions)\n", .{COLLECTION_FUNCTIONS.len});
            std.debug.print("  time ({} functions)\n", .{TIME_FUNCTIONS.len});
            std.debug.print("  utils ({} functions)\n", .{UTIL_FUNCTIONS.len});
            if (enable_fs) std.debug.print("  fs ({} functions)\n", .{FILESYSTEM_FUNCTIONS.len});
            if (enable_net) std.debug.print("  network ({} functions)\n", .{NETWORK_FUNCTIONS.len});
            std.debug.print("  matrix ({} functions)\n", .{MATRIX_FUNCTIONS.len});
        },
        .v2_new => {
            stdlib_v2_main.listModules();
        },
        .hybrid => {
            std.debug.print("V2 Modules:\n", .{});
            stdlib_v2_main.listModules();

            std.debug.print("\nV1 Legacy Modules (not migrated):\n", .{});
            if (enable_fs) std.debug.print("  fs ({} functions)\n", .{FILESYSTEM_FUNCTIONS.len});
            if (enable_net) std.debug.print("  network ({} functions)\n", .{NETWORK_FUNCTIONS.len});
            std.debug.print("  matrix ({} functions)\n", .{MATRIX_FUNCTIONS.len});
        },
    }
}

fn printVersionInfo() void {
    std.debug.print("\n=== Version Information ===\n", .{});
    std.debug.print("Current stdlib version: {}\n", .{current_version});

    std.debug.print("\nAvailable versions:\n", .{});
    std.debug.print("  v1_legacy - Original stdlib system\n", .{});
    std.debug.print("  v2_new    - New enhanced stdlib system\n", .{});
    std.debug.print("  hybrid    - Both systems (for migration)\n", .{});

    std.debug.print("\nV2 Migration Status:\n", .{});
    std.debug.print("  ✓ Core functions\n", .{});
    std.debug.print("  ✓ Math functions\n", .{});
    std.debug.print("  ✓ I/O functions\n", .{});
    std.debug.print("  ✓ Type functions\n", .{});
    std.debug.print("  ✓ Time functions\n", .{});
    std.debug.print("  ✓ Utility functions\n", .{});
    std.debug.print("  ✓ Collections functions\n", .{});
    std.debug.print("  ◯ Filesystem functions (pending)\n", .{});
    std.debug.print("  ◯ Network functions (pending)\n", .{});
    std.debug.print("  ◯ Matrix functions (pending)\n", .{});
}

fn printMigrationGuide() void {
    std.debug.print("\n=== Migration Guide to V2 ===\n", .{});
    std.debug.print("To start using the new stdlib system:\n\n", .{});

    std.debug.print("1. Set stdlib version to hybrid mode:\n", .{});
    std.debug.print("   setVersion(.hybrid);\n\n", .{});

    std.debug.print("2. Test your code with hybrid mode\n", .{});
    std.debug.print("   (both v1 and v2 functions available)\n\n", .{});

    std.debug.print("3. When ready, switch to v2 only:\n", .{});
    std.debug.print("   setVersion(.v2_new);\n\n", .{});

    std.debug.print("Benefits of V2:\n", .{});
    std.debug.print("  • Better error messages with parameter names\n", .{});
    std.debug.print("  • Automatic parameter validation\n", .{});
    std.debug.print("  • Rich documentation with examples\n", .{});
    std.debug.print("  • Consistent function signatures\n", .{});
    std.debug.print("  • Type-safe parameter system\n\n", .{});

    std.debug.print("For detailed migration instructions:\n", .{});
    std.debug.print("  See src/stdlib_v2/MIGRATION_GUIDE.md\n", .{});
}

pub fn getTotalFunctionCount() usize {
    var count: usize = CORE_FUNCTIONS.len + MATH_FUNCTIONS.len + COLLECTION_FUNCTIONS.len + TIME_FUNCTIONS.len + UTIL_FUNCTIONS.len + MATRIX_FUNCTIONS.len;
    if (enable_fs) count += FILESYSTEM_FUNCTIONS.len;
    if (enable_net) count += NETWORK_FUNCTIONS.len;
    return count;
}

// Legacy what_is function
pub fn what_is(argc: i32, args: [*]Value) Value {
    if (argc != 1) return stdlib_error("what_is() expects 1 argument, got {any}!", .{ .argn = argc });

    const conv = @import("conv.zig");
    const str = conv.what_is(args[0]);
    std.debug.print("Type: {s}\n", .{str});
    return Value.init_nil();
}

// Error handling
const Got = union(enum) {
    value_type: []const u8,
    argn: i32,
};

pub fn stdlib_error(comptime fmt: []const u8, args: Got) Value {
    switch (args) {
        .value_type => |vt| {
            const msg = std.fmt.allocPrint(std.heap.page_allocator, fmt, .{vt}) catch "Error formatting error message";
            std.debug.print("Error: {s}\n", .{msg});
        },
        .argn => |n| {
            const msg = std.fmt.allocPrint(std.heap.page_allocator, fmt, .{n}) catch "Error formatting error message";
            std.debug.print("Error: {s}\n", .{msg});
        },
    }
    return Value.init_nil();
}
