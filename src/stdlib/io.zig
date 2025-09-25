const std = @import("std");
const io = std.Io;

const conv = @import("../conv.zig");
const type_check = conv.type_check;
const GlobalAlloc = @import("../main.zig").GlobalAlloc;
const stdlib_error = @import("../stdlib.zig").stdlib_error;
const Value = @import("../value.zig").Value;

pub fn input(argc: i32, args: [*]Value) Value {
    if (argc > 1) return stdlib_error("Expects at least 1 argument for input()!", .{ .argn = argc });
    if (argc == 1) {
        const message = args[0].as_zstring();
        std.debug.print("{s}\n", .{message});
    }
    var buffer: [4096]u8 = undefined;
    var stdin_reader = std.fs.File.stdin().reader(&buffer);
    var input_buffer: [256]u8 = undefined;
    const end = stdin_reader.read(&input_buffer) catch return Value.init_nil();
    const trimmed = std.mem.trim(u8, input_buffer[0..end], "\t\r\n");
    return Value.init_string(@constCast(trimmed));

    // var buffer = std.ArrayList(u8).init(GlobalAlloc);
    // defer buffer.deinit();
    // stdin.streamUntilDelimiter(buffer.writer(), '\n', null) catch return Value.init_nil();
    // return Value.init_string(buffer.items[0 .. buffer.items.len - 1]);
}
