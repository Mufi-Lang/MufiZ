const std = @import("std");

const conv = @import("../conv.zig");
const object_h = @import("../object.zig");
const value_h = @import("../value.zig");
const Value = value_h.Value;
const valuesEqual = value_h.valuesEqual;
const vm = @import("../vm.zig");

// Helper functions for argument validation
pub fn expectArgs(name: []const u8, expected: i32, actual: i32) bool {
    if (actual != expected) {
        vm.runtimeError("{s}() expects {d} arguments, got {d}", .{ name, expected, actual });
        return false;
    }
    return true;
}

pub fn expectMinArgs(name: []const u8, min: i32, actual: i32) bool {
    if (actual < min) {
        vm.runtimeError("{s}() expects at least {d} arguments, got {d}", .{ name, min, actual });
        return false;
    }
    return true;
}

pub fn expectMaxArgs(name: []const u8, max: i32, actual: i32) bool {
    if (actual > max) {
        vm.runtimeError("{s}() expects at most {d} arguments, got {d}", .{ name, max, actual });
        return false;
    }
    return true;
}

pub fn expectNumber(name: []const u8, arg: Value, pos: i32) bool {
    if (arg.type != .VAL_INT and arg.type != .VAL_DOUBLE) {
        vm.runtimeError("{s}() argument {d} must be a number", .{ name, pos });
        return false;
    }
    return true;
}

pub fn expectInt(name: []const u8, arg: Value, pos: i32) bool {
    if (arg.type != .VAL_INT) {
        vm.runtimeError("{s}() argument {d} must be an integer", .{ name, pos });
        return false;
    }
    return true;
}

pub fn expectDouble(name: []const u8, arg: Value, pos: i32) bool {
    if (arg.type != .VAL_DOUBLE) {
        vm.runtimeError("{s}() argument {d} must be a double", .{ name, pos });
        return false;
    }
    return true;
}

pub fn expectString(name: []const u8, arg: Value, pos: i32) bool {
    if (arg.type != .VAL_OBJ or arg.as.obj == null) {
        vm.runtimeError("{s}() argument {d} must be a string", .{ name, pos });
        return false;
    }
    return true;
}

pub fn expectBool(name: []const u8, arg: Value, pos: i32) bool {
    if (arg.type != .VAL_BOOL) {
        vm.runtimeError("{s}() argument {d} must be a boolean", .{ name, pos });
        return false;
    }
    return true;
}

pub fn expectObject(name: []const u8, arg: Value, pos: i32) bool {
    if (arg.type != .VAL_OBJ or arg.as.obj == null) {
        vm.runtimeError("{s}() argument {d} must be an object", .{ name, pos });
        return false;
    }
    return true;
}

pub fn expectComplex(name: []const u8, arg: Value, pos: i32) bool {
    if (arg.type != .VAL_COMPLEX) {
        vm.runtimeError("{s}() argument {d} must be a complex number", .{ name, pos });
        return false;
    }
    return true;
}

// Utility functions
pub fn assert(argc: i32, args: [*]Value) Value {
    if (argc < 1 or argc > 2) {
        vm.runtimeError("assert() expects 1 or 2 arguments, got {}", .{argc});
        return Value.init_nil();
    }

    if (argc == 2) {
        // Compare values directly when two arguments are provided
        if (!valuesEqual(args[0], args[1])) {
            const value_type = conv.what_is(args[0]);
            const expected_type = conv.what_is(args[1]);
            const actual_str = value_h.valueToString(args[0]);
            const expected_str = value_h.valueToString(args[1]);
            vm.runtimeError("Assertion failed: Expected value '{s}' ({s}), got '{s}' ({s})", .{ expected_str, expected_type, actual_str, value_type });
            return Value.init_nil();
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
            vm.runtimeError("Assertion failed: Expected truthy value, got {s}", .{value_type});
            return Value.init_nil();
        }
    }

    return Value.init_nil();
}

pub fn exit(argc: i32, args: [*]Value) Value {
    var exit_code: i32 = 0;

    if (argc == 1) {
        if (!expectInt("exit", args[0], 1)) return Value.init_nil();
        exit_code = args[0].as_num_int();
    } else if (argc > 1) {
        vm.runtimeError("exit() expects 0 or 1 arguments, got {d}", .{argc});
        return Value.init_nil();
    }

    std.process.exit(@intCast(exit_code));
}

pub fn sleep(argc: i32, args: [*]Value) Value {
    if (!expectArgs("sleep", 1, argc)) return Value.init_nil();
    if (!expectNumber("sleep", args[0], 1)) return Value.init_nil();

    const seconds = args[0].as_num_double();
    const nanoseconds = @as(u64, @intFromFloat(seconds * 1_000_000_000));

    std.time.sleep(nanoseconds);
    return Value.init_nil();
}

pub fn panic_fn(argc: i32, args: [*]Value) Value {
    var message: []const u8 = "panic called";

    if (argc == 1) {
        if (!expectString("panic", args[0], 1)) return Value.init_nil();
        message = args[0].as_zstring();
    } else if (argc > 1) {
        vm.runtimeError("panic() expects 0 or 1 arguments, got {d}", .{argc});
        return Value.init_nil();
    }

    std.debug.panic("{s}", .{message});
}

// Format string with interpolation
pub fn format_str(argc: i32, args: [*]Value) Value {
    if (argc < 1) {
        vm.runtimeError("format() expects at least 1 argument", .{});
        return Value.init_nil();
    }

    // First argument should be the template string
    if (!expectString("format", args[0], 1)) return Value.init_nil();
    const template = args[0].as_zstring();

    // If no other arguments, return the template string as is
    if (argc == 1) {
        return args[0];
    }

    // Parse the template string for placeholders {} and replace with arguments
    var result = std.ArrayList(u8).init(std.heap.page_allocator);
    defer result.deinit();

    var i: usize = 0;
    var arg_index: i32 = 1; // Start with the second argument

    while (i < template.len) {
        if (template[i] == '{' and i + 1 < template.len and template[i + 1] == '}') {
            // Found a placeholder
            if (arg_index < argc) {
                // Convert the argument to string and append
                const arg_str = switch (args[@intCast(arg_index)].type) {
                    .VAL_OBJ => if (args[@intCast(arg_index)].is_string())
                        args[@intCast(arg_index)].as_zstring()
                    else
                        value_h.valueToString(args[@intCast(arg_index)]),
                    else => value_h.valueToString(args[@intCast(arg_index)]),
                };

                result.appendSlice(arg_str) catch {
                    vm.runtimeError("Failed to format string", .{});
                    return Value.init_nil();
                };

                arg_index += 1;
            } else {
                // Not enough arguments for placeholders
                result.appendSlice("{}") catch {};
            }

            i += 2; // Skip the {}
        } else if (template[i] == '{' and i + 1 < template.len and template[i + 1] == '{') {
            // Escaped { character
            result.append('{') catch {};
            i += 2;
        } else if (template[i] == '}' and i + 1 < template.len and template[i + 1] == '}') {
            // Escaped } character
            result.append('}') catch {};
            i += 2;
        } else {
            // Regular character
            result.append(template[i]) catch {};
            i += 1;
        }
    }

    // Create a string object from the result
    const str_obj = object_h.copyString(result.items.ptr, result.items.len);
    return Value.init_obj(@ptrCast(str_obj));
}
