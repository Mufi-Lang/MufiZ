const std = @import("std");

const enable_curl = @import("features").enable_curl;
const enable_fs = @import("features").enable_fs;
const enable_net = @import("features").enable_net;

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
const Value = @import("value.zig").Value;
const vm = @import("vm.zig");

// Import all stdlib modules
// Builtin function definition
pub const BuiltinDef = struct {
    name: []const u8,
    func: NativeFn,
    params: []const u8,
    description: []const u8,
    module: []const u8,
};

// Registry of all builtin functions organized by module
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
    .{ .name = "len", .func = collections.len, .params = "list", .description = "Gets length of list", .module = "collections" },
    .{ .name = "get", .func = collections.get, .params = "list, index", .description = "Gets element at index", .module = "collections" },
    .{ .name = "put", .func = collections.put, .params = "hash_table, key, value", .description = "Puts element into hash table", .module = "collections" },
    .{ .name = "remove", .func = collections.remove, .params = "collection, key", .description = "Removes element from collection", .module = "collections" },
    .{ .name = "nth", .func = collections.nth, .params = "list, index", .description = "Gets nth element", .module = "collections" },
    .{ .name = "insert", .func = collections.insert, .params = "list, index, value", .description = "Inserts element at index", .module = "collections" },
    .{ .name = "contains", .func = collections.contains, .params = "list, value", .description = "Checks if list contains value", .module = "collections" },
    .{ .name = "sort", .func = collections.sort, .params = "list", .description = "Sorts list in place", .module = "collections" },
    .{ .name = "reverse", .func = collections.reverse, .params = "list", .description = "Reverses list in place", .module = "collections" },
    .{ .name = "slice", .func = collections.slice_fn, .params = "list, start, end", .description = "Creates slice of list", .module = "collections" },
    .{ .name = "splice", .func = collections.splice, .params = "list, start, end", .description = "Removes and returns elements", .module = "collections" },
    .{ .name = "merge", .func = collections.merge, .params = "list1, list2", .description = "Merges two lists or vectors", .module = "collections" },
    .{ .name = "clone", .func = collections.clone, .params = "list", .description = "Creates copy of list", .module = "collections" },
    .{ .name = "clear", .func = collections.clear, .params = "list", .description = "Clears all elements", .module = "collections" },
    .{ .name = "is_empty", .func = collections.is_empty, .params = "list", .description = "Checks if list is empty", .module = "collections" },
    .{ .name = "next", .func = collections.next, .params = "iterator", .description = "Gets next element from iterator", .module = "collections" },
    .{ .name = "has_next", .func = collections.has_next, .params = "iterator", .description = "Checks if iterator has next", .module = "collections" },
    .{ .name = "reset", .func = collections.reset, .params = "iterator", .description = "Resets iterator position", .module = "collections" },
    .{ .name = "skip", .func = collections.skip, .params = "iterator, count", .description = "Skips elements in iterator", .module = "collections" },
    .{ .name = "linspace", .func = collections.linspace, .params = "start, end, count", .description = "Creates vector with evenly spaced values", .module = "collections" },
    .{ .name = "search", .func = collections.search, .params = "vector, value", .description = "Searches for value in vector", .module = "collections" },
    .{ .name = "sum", .func = collections.sum, .params = "vector", .description = "Sum of all elements", .module = "collections" },
    .{ .name = "mean", .func = collections.mean, .params = "vector", .description = "Mean of all elements", .module = "collections" },
    .{ .name = "std", .func = collections.std_dev, .params = "vector", .description = "Standard deviation", .module = "collections" },
    .{ .name = "vari", .func = collections.variance, .params = "vector", .description = "Variance of elements", .module = "collections" },
    .{ .name = "maxl", .func = collections.maxl, .params = "vector", .description = "Maximum element in list", .module = "collections" },
    .{ .name = "minl", .func = collections.minl, .params = "vector", .description = "Minimum element in list", .module = "collections" },
    .{ .name = "dot", .func = collections.dot, .params = "vector1, vector2", .description = "Dot product of vectors", .module = "collections" },
    .{ .name = "norm", .func = collections.norm, .params = "vector", .description = "Euclidean norm of vector", .module = "collections" },
};

pub const FILESYSTEM_FUNCTIONS = [_]BuiltinDef{
    .{ .name = "create_file", .func = fs.create_file, .params = "path", .description = "Creates new file", .module = "fs" },
    .{ .name = "read_file", .func = fs.read_file, .params = "path", .description = "Reads file content", .module = "fs" },
    .{ .name = "write_file", .func = fs.write_file, .params = "path, content", .description = "Writes to file", .module = "fs" },
    .{ .name = "delete_file", .func = fs.delete_file, .params = "path", .description = "Deletes file", .module = "fs" },
    .{ .name = "create_dir", .func = fs.create_dir, .params = "path", .description = "Creates directory", .module = "fs" },
    .{ .name = "delete_dir", .func = fs.delete_dir, .params = "path", .description = "Deletes directory", .module = "fs" },
};

pub const TIME_FUNCTIONS = [_]BuiltinDef{
    .{ .name = "now", .func = time.now, .params = "", .description = "Current timestamp", .module = "time" },
    .{ .name = "now_ns", .func = time.now_ns, .params = "", .description = "Current timestamp in nanoseconds", .module = "time" },
    .{ .name = "now_ms", .func = time.now_ms, .params = "", .description = "Current timestamp in milliseconds", .module = "time" },
};

pub const UTIL_FUNCTIONS = [_]BuiltinDef{
    .{ .name = "assert", .func = utils.assert, .params = "condition", .description = "Asserts condition is true", .module = "utils" },
    .{ .name = "exit", .func = utils.exit, .params = "code?", .description = "Exits program with code", .module = "utils" },
    .{ .name = "sleep", .func = utils.sleep, .params = "seconds", .description = "Sleeps for given seconds", .module = "utils" },
    .{ .name = "panic", .func = utils.panic_fn, .params = "message?", .description = "Panics with message", .module = "utils" },
    .{ .name = "format", .func = utils.format_str, .params = "template, values...", .description = "Formats string with placeholders {}", .module = "utils" },
    .{ .name = "f", .func = utils.format_str, .params = "template, values...", .description = "Alias for format: f-string syntax", .module = "utils" },
};

pub const NETWORK_FUNCTIONS = [_]BuiltinDef{
    .{ .name = "http_get", .func = network.http_get, .params = "url", .description = "Performs HTTP GET request", .module = "network" },
    .{ .name = "http_post", .func = network.http_post, .params = "url, data", .description = "Performs HTTP POST request", .module = "network" },
    .{ .name = "http_put", .func = network.http_put, .params = "url, data", .description = "Performs HTTP PUT request", .module = "network" },
    .{ .name = "http_delete", .func = network.http_delete, .params = "url", .description = "Performs HTTP DELETE request", .module = "network" },
    .{ .name = "set_content_type", .func = network.set_content_type, .params = "type", .description = "Sets content type for requests", .module = "network" },
    .{ .name = "set_auth", .func = network.set_auth, .params = "token", .description = "Sets authorization token", .module = "network" },
    .{ .name = "parse_url", .func = network.parse_url, .params = "url", .description = "Parses URL into components", .module = "network" },
    .{ .name = "url_encode", .func = network.url_encode, .params = "string", .description = "URL encodes a string", .module = "network" },
    .{ .name = "url_decode", .func = network.url_decode, .params = "string", .description = "Decodes a URL encoded string", .module = "network" },
    .{ .name = "open_url", .func = network.open_url, .params = "url", .description = "Opens URL in default browser", .module = "network" },
};

// Helper function to register functions
fn defineNative(name: []const u8, func: NativeFn) void {
    vm.defineNative(@ptrCast(@constCast(name)), @ptrCast(func));
}

fn registerFunctions(functions: []const BuiltinDef) void {
    for (functions) |func| {
        defineNative(func.name, func.func);
    }
}

// Public API functions
pub fn prelude() void {
    registerFunctions(&CORE_FUNCTIONS);
}

pub fn addMath() void {
    registerFunctions(&MATH_FUNCTIONS);
}

pub fn addCollections() void {
    registerFunctions(&COLLECTION_FUNCTIONS);
}

pub fn addFs() void {
    if (enable_fs) {
        registerFunctions(&FILESYSTEM_FUNCTIONS);
    } else {
        std.log.warn("Filesystem functions are disabled!", .{});
    }
}

pub fn addTime() void {
    registerFunctions(&TIME_FUNCTIONS);
}

pub fn addUtils() void {
    registerFunctions(&UTIL_FUNCTIONS);
}

pub fn addNet() void {
    if (enable_net) {
        registerFunctions(&NETWORK_FUNCTIONS);
    } else {
        std.log.warn("Network functions are disabled!", .{});
    }
}

// Documentation functions
pub fn printDocs() void {
    printModuleDocs("Core", &CORE_FUNCTIONS);
    printModuleDocs("Math", &MATH_FUNCTIONS);
    printModuleDocs("Collections", &COLLECTION_FUNCTIONS);
    if (enable_fs) printModuleDocs("Filesystem", &FILESYSTEM_FUNCTIONS);
    if (enable_net) printModuleDocs("Network", &NETWORK_FUNCTIONS);
    printModuleDocs("Time", &TIME_FUNCTIONS);
    printModuleDocs("Utils", &UTIL_FUNCTIONS);
}

fn printModuleDocs(module_name: []const u8, functions: []const BuiltinDef) void {
    std.debug.print("\n=== {s} Functions ({d}) ===\n", .{ module_name, functions.len });
    for (functions) |func| {
        if (func.params.len > 0) {
            std.debug.print("{s}({s}) - {s}\n", .{ func.name, func.params, func.description });
        } else {
            std.debug.print("{s}() - {s}\n", .{ func.name, func.description });
        }
    }
}

pub fn getTotalFunctionCount() usize {
    var count: usize = CORE_FUNCTIONS.len + MATH_FUNCTIONS.len + COLLECTION_FUNCTIONS.len + TIME_FUNCTIONS.len + UTIL_FUNCTIONS.len;
    if (enable_fs) count += FILESYSTEM_FUNCTIONS.len;
    if (enable_net) count += NETWORK_FUNCTIONS.len;
    return count;
}

// Legacy compatibility
pub fn what_is(argc: i32, args: [*]Value) Value {
    if (argc != 1) return stdlib_error("what_is() expects 1 argument!", .{ .argn = argc });

    const conv = @import("conv.zig");
    const str = conv.what_is(args[0]);
    std.debug.print("Type: {s}\n", .{str});
    return Value.init_nil();
}

const Got = union(enum) {
    value_type: []const u8,
    argn: i32,
};

pub fn stdlib_error(message: []const u8, got: Got) Value {
    switch (got) {
        .value_type => |v| {
            vm.runtimeError("{s} Got {s} type...", .{ message, v });
        },
        .argn => |n| {
            vm.runtimeError("{s} Got {d} arguments...", .{ message, n });
        },
    }
    return Value.init_nil();
}
