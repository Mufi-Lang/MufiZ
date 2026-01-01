const std = @import("std");

const conv = @import("../conv.zig");
const type_check = conv.type_check;
const mem_utils = @import("../mem_utils.zig");
const stdlib_error = @import("../stdlib.zig").stdlib_error;
const Value = @import("../value.zig").Value;

pub fn input(argc: i32, args: [*]Value) Value {
    if (argc > 1) return stdlib_error("Expects at least 1 argument for input()!", .{ .argn = argc });
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
