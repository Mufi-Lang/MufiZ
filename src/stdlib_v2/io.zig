const std = @import("std");
const Value = @import("../value.zig").Value;
const stdlib_v2 = @import("../stdlib_v2.zig");
const DefineFunction = stdlib_v2.DefineFunction;
const ParamSpec = stdlib_v2.ParamSpec;
const ParamType = stdlib_v2.ParamType;
const NoParams = stdlib_v2.NoParams;
const mem_utils = @import("../mem_utils.zig");

// Implementation functions

fn input_impl(argc: i32, args: [*]Value) Value {
    // Optional prompt message
    if (argc == 1) {
        const message = args[0].as_zstring();
        std.debug.print("{s}", .{message});
    }

    // Use stdin for Zig 0.15 like simple_line.zig does
    const stdin = std.fs.File.stdin();
    var input_buffer: [256]u8 = undefined;
    var pos: usize = 0;

    // Read characters until newline or buffer full
    while (pos < input_buffer.len - 1) {
        var byte_buffer: [1]u8 = undefined;
        const amt = stdin.read(byte_buffer[0..]) catch return Value.init_nil();

        if (amt == 0) break; // EOF

        const byte = byte_buffer[0];
        if (byte == '\n' or byte == '\r') {
            break;
        } else {
            input_buffer[pos] = byte;
            pos += 1;
        }
    }

    // Null terminate and trim
    input_buffer[pos] = 0;
    const trimmed = std.mem.trim(u8, input_buffer[0..pos], " \t\r\n");

    // Allocate and copy the string
    const result = mem_utils.getAllocator().dupe(u8, trimmed) catch return Value.init_nil();
    return Value.init_string(result);
}

fn print_impl(argc: i32, args: [*]Value) Value {
    var i: usize = 0;
    while (i < @as(usize, @intCast(argc))) {
        if (i > 0) std.debug.print(" ");

        switch (args[i].type) {
            .VAL_INT => std.debug.print("{d}", .{args[i].as_int()}),
            .VAL_DOUBLE => std.debug.print("{}", .{args[i].as_double()}),
            .VAL_BOOL => std.debug.print("{}", .{args[i].as_bool()}),
            .VAL_NIL => std.debug.print("nil"),
            .VAL_COMPLEX => {
                const c = args[i].as_complex();
                std.debug.print("{}+{}i", .{ c.r, c.i });
            },
            .VAL_OBJ => {
                if (args[i].is_string()) {
                    std.debug.print("{s}", .{args[i].as_zstring()});
                } else {
                    std.debug.print("[object]");
                }
            },
        }
        i += 1;
    }
    return Value.init_nil();
}

fn println_impl(argc: i32, args: [*]Value) Value {
    _ = print_impl(argc, args);
    std.debug.print("\n");
    return Value.init_nil();
}

fn printf_impl(argc: i32, args: [*]Value) Value {
    const format_str = args[0].as_zstring();

    // Simple printf implementation - just replace {} with arguments
    var arg_index: usize = 1;
    var i: usize = 0;

    while (i < std.mem.len(format_str)) {
        if (i < std.mem.len(format_str) - 1 and format_str[i] == '{' and format_str[i + 1] == '}') {
            // Found placeholder
            if (arg_index < @as(usize, @intCast(argc))) {
                switch (args[arg_index].type) {
                    .VAL_INT => std.debug.print("{d}", .{args[arg_index].as_int()}),
                    .VAL_DOUBLE => std.debug.print("{}", .{args[arg_index].as_double()}),
                    .VAL_BOOL => std.debug.print("{}", .{args[arg_index].as_bool()}),
                    .VAL_NIL => std.debug.print("nil"),
                    .VAL_COMPLEX => {
                        const c = args[arg_index].as_complex();
                        std.debug.print("{}+{}i", .{ c.r, c.i });
                    },
                    .VAL_OBJ => {
                        if (args[arg_index].is_string()) {
                            std.debug.print("{s}", .{args[arg_index].as_zstring()});
                        } else {
                            std.debug.print("[object]");
                        }
                    },
                }
                arg_index += 1;
            }
            i += 2;
        } else {
            std.debug.print("{c}", .{format_str[i]});
            i += 1;
        }
    }
    return Value.init_nil();
}

// Public function wrappers with metadata

pub const input = DefineFunction(
    "input",
    "io",
    "Read input from stdin with optional prompt",
    &[_]ParamSpec{
        .{ .name = "prompt", .type = .string, .optional = true },
    },
    .string,
    &[_][]const u8{
        "input() -> \"user typed this\"",
        "input(\"Enter name: \") -> \"John\"",
    },
    input_impl,
);

pub const print = DefineFunction(
    "print",
    "io",
    "Print values separated by spaces",
    &[_]ParamSpec{
        .{ .name = "values", .type = .any }, // Variadic - accepts any number of any type
    },
    .nil,
    &[_][]const u8{
        "print(\"Hello\", \"World\") -> Hello World",
        "print(42, 3.14, true) -> 42 3.14 true",
    },
    print_impl,
);

pub const println = DefineFunction(
    "println",
    "io",
    "Print values separated by spaces followed by newline",
    &[_]ParamSpec{
        .{ .name = "values", .type = .any }, // Variadic
    },
    .nil,
    &[_][]const u8{
        "println(\"Hello World\") -> Hello World\\n",
        "println(1, 2, 3) -> 1 2 3\\n",
    },
    println_impl,
);

pub const printf = DefineFunction(
    "printf",
    "io",
    "Print formatted string with {} placeholders",
    &[_]ParamSpec{
        .{ .name = "format", .type = .string },
        .{ .name = "args", .type = .any, .optional = true }, // Variadic optional args
    },
    .nil,
    &[_][]const u8{
        "printf(\"Hello {}\", \"World\") -> Hello World",
        "printf(\"x={}, y={}\", 10, 20) -> x=10, y=20",
    },
    printf_impl,
);
