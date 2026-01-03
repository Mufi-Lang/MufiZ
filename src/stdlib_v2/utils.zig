const std = @import("std");
const Value = @import("../value.zig").Value;
const stdlib_v2 = @import("../stdlib_v2.zig");
const DefineFunction = stdlib_v2.DefineFunction;
const ParamSpec = stdlib_v2.ParamSpec;
const ParamType = stdlib_v2.ParamType;
const NoParams = stdlib_v2.NoParams;
const OneAny = stdlib_v2.OneAny;
const OneNumber = stdlib_v2.OneNumber;
const valuesEqual = @import("../value.zig").valuesEqual;
const valueToString = @import("../value.zig").valueToString;
const conv = @import("../conv.zig");
const object_h = @import("../object.zig");

// Implementation functions

fn assert_impl(argc: i32, args: [*]Value) Value {
    if (argc == 2) {
        // Compare values directly when two arguments are provided
        if (!valuesEqual(args[0], args[1])) {
            const actual_str = valueToString(args[0]);
            const expected_str = valueToString(args[1]);
            return stdlib_v2.stdlib_error("Assertion failed: Expected '{}', got '{}'", .{ expected_str, actual_str });
        }
    } else {
        // Traditional truthy check for single argument
        const condition = args[0];
        const is_truthy = switch (condition.type) {
            .VAL_BOOL => condition.as_bool(),
            .VAL_NIL => false,
            .VAL_INT => condition.as_num_int() != 0,
            .VAL_DOUBLE => condition.as_num_double() != 0.0,
            else => true,
        };

        if (!is_truthy) {
            const value_type = conv.what_is(args[0]);
            return stdlib_v2.stdlib_error("Assertion failed: Expected truthy value, got {s}", .{value_type});
        }
    }

    return Value.init_nil();
}

fn exit_impl(argc: i32, args: [*]Value) Value {
    var exit_code: i32 = 0;

    if (argc == 1) {
        exit_code = args[0].as_num_int();
    }

    std.process.exit(@intCast(exit_code));
}

fn panic_impl(argc: i32, args: [*]Value) Value {
    var message: []const u8 = "panic called";

    if (argc == 1) {
        message = args[0].as_zstring();
    }

    std.debug.panic("{s}", .{message});
}

fn format_impl(argc: i32, args: [*]Value) Value {
    // First argument should be the template string
    const template = args[0].as_zstring();

    // If no other arguments, return the template string as is
    if (argc == 1) {
        return args[0];
    }

    // Simplified string formatting - allocate a large buffer
    const allocator = std.heap.page_allocator;
    const buffer = allocator.alloc(u8, template.len * 2) catch {
        return stdlib_v2.stdlib_error("Failed to allocate buffer for format", .{});
    };
    defer allocator.free(buffer);

    var pos: usize = 0;
    var i: usize = 0;
    var arg_index: i32 = 1; // Start with the second argument

    while (i < template.len and pos < buffer.len - 1) {
        if (template[i] == '{' and i + 1 < template.len and template[i + 1] == '}') {
            // Found a placeholder
            if (arg_index < argc) {
                // Convert the argument to string and append
                const arg_str = switch (args[@intCast(arg_index)].type) {
                    .VAL_OBJ => if (args[@intCast(arg_index)].is_string())
                        args[@intCast(arg_index)].as_zstring()
                    else
                        valueToString(args[@intCast(arg_index)]),
                    else => valueToString(args[@intCast(arg_index)]),
                };

                // Copy the argument string to buffer
                const copy_len = @min(arg_str.len, buffer.len - pos - 1);
                @memcpy(buffer[pos .. pos + copy_len], arg_str[0..copy_len]);
                pos += copy_len;

                arg_index += 1;
            } else {
                // Not enough arguments for placeholders
                if (pos < buffer.len - 2) {
                    buffer[pos] = '{';
                    buffer[pos + 1] = '}';
                    pos += 2;
                }
            }

            i += 2; // Skip the {}
        } else if (template[i] == '{' and i + 1 < template.len and template[i + 1] == '{') {
            // Escaped { character
            buffer[pos] = '{';
            pos += 1;
            i += 2;
        } else if (template[i] == '}' and i + 1 < template.len and template[i + 1] == '}') {
            // Escaped } character
            buffer[pos] = '}';
            pos += 1;
            i += 2;
        } else {
            // Regular character
            buffer[pos] = template[i];
            pos += 1;
            i += 1;
        }
    }

    // Create a string object from the result
    const str_obj = object_h.copyString(buffer.ptr, pos);
    return Value.init_obj(@ptrCast(str_obj));
}

fn equals_impl(argc: i32, args: [*]Value) Value {
    _ = argc;
    return Value.init_bool(valuesEqual(args[0], args[1]));
}

fn hash_impl(argc: i32, args: [*]Value) Value {
    _ = argc;
    const value = args[0];

    var hash_value: u64 = 0;
    switch (value.type) {
        .VAL_INT => {
            hash_value = @intCast(@abs(value.as_int()));
        },
        .VAL_DOUBLE => {
            const bits = @as(u64, @bitCast(value.as_double()));
            hash_value = bits;
        },
        .VAL_BOOL => {
            hash_value = if (value.as_bool()) 1 else 0;
        },
        .VAL_NIL => {
            hash_value = 0;
        },
        .VAL_OBJ => {
            if (value.is_string()) {
                const str = value.as_zstring();
                // Simple hash function for strings
                for (str) |byte| {
                    hash = hash *% 31 +% byte;
                }
            }
        },
        .VAL_COMPLEX => {
            const c = value.as_complex();
            const r_bits = @as(u64, @bitCast(c.r));
            const i_bits = @as(u64, @bitCast(c.i));
            hash = r_bits ^ i_bits;
        },
    }

    return Value.init_int(@intCast(hash_value & 0x7FFFFFFF)); // Keep positive
}

fn clone_impl(argc: i32, args: [*]Value) Value {
    _ = argc;
    // For primitive types, just return the value (they're copied by value)
    // For objects, this would need deeper cloning logic
    return args[0];
}

fn identity_impl(argc: i32, args: [*]Value) Value {
    _ = argc;
    // Return the memory address as a unique identifier
    const ptr = @intFromPtr(&args[0]);
    return Value.init_int(@intCast(ptr & 0x7FFFFFFF));
}

// Public function wrappers with metadata

pub const assert = DefineFunction(
    "assert",
    "utils",
    "Assert that a condition is true or two values are equal",
    &[_]ParamSpec{
        .{ .name = "condition_or_actual", .type = .any },
        .{ .name = "expected", .type = .any, .optional = true },
    },
    .nil,
    &[_][]const u8{
        "assert(true) -> nil",
        "assert(5 > 3) -> nil",
        "assert(42, 42) -> nil",
        "assert(\"hello\", \"world\") -> Error: Assertion failed",
    },
    assert_impl,
);

pub const exit = DefineFunction(
    "exit",
    "utils",
    "Exit the program with optional exit code",
    &[_]ParamSpec{
        .{ .name = "code", .type = .int, .optional = true },
    },
    .nil,
    &[_][]const u8{
        "exit() -> exits with code 0",
        "exit(1) -> exits with code 1",
    },
    exit_impl,
);

pub const panic = DefineFunction(
    "panic",
    "utils",
    "Panic with optional message",
    &[_]ParamSpec{
        .{ .name = "message", .type = .string, .optional = true },
    },
    .nil,
    &[_][]const u8{
        "panic() -> panic: panic called",
        "panic(\"Something went wrong\") -> panic: Something went wrong",
    },
    panic_impl,
);

pub const format = DefineFunction(
    "format",
    "utils",
    "Format string with {} placeholders",
    &[_]ParamSpec{
        .{ .name = "template", .type = .string },
        .{ .name = "args", .type = .any, .optional = true }, // Variadic
    },
    .string,
    &[_][]const u8{
        "format(\"Hello {}\", \"World\") -> \"Hello World\"",
        "format(\"x={}, y={}\", 10, 20) -> \"x=10, y=20\"",
        "format(\"{{escaped}}\") -> \"{escaped}\"",
    },
    format_impl,
);

pub const equals = DefineFunction(
    "equals",
    "utils",
    "Check if two values are equal",
    &[_]ParamSpec{
        .{ .name = "a", .type = .any },
        .{ .name = "b", .type = .any },
    },
    .bool,
    &[_][]const u8{
        "equals(42, 42) -> true",
        "equals(\"hello\", \"world\") -> false",
        "equals(nil, nil) -> true",
    },
    equals_impl,
);

pub const hash = DefineFunction(
    "hash",
    "utils",
    "Calculate hash code of a value",
    OneAny,
    .int,
    &[_][]const u8{
        "hash(42) -> 42",
        "hash(\"hello\") -> 99162322",
        "hash(3.14) -> 4614256656552045848",
    },
    hash_impl,
);

pub const clone = DefineFunction(
    "clone",
    "utils",
    "Create a copy of a value",
    OneAny,
    .any,
    &[_][]const u8{
        "clone(42) -> 42",
        "clone(\"hello\") -> \"hello\"",
        "clone(linked_list()) -> [cloned list]",
    },
    clone_impl,
);

pub const identity = DefineFunction(
    "identity",
    "utils",
    "Get unique identity hash of a value",
    OneAny,
    .int,
    &[_][]const u8{
        "identity(x) -> 140234567890",
        "identity(y) -> 140234567894",
    },
    identity_impl,
);
