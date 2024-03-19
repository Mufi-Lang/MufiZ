const std = @import("std");
const conv = @import("../conv.zig");
const Value = @cImport(@cInclude("value.h")).Value;
const stdlib_error = @import("../stdlib.zig").stdlib_error;
const type_check = conv.type_check;
const GlobalAlloc = @import("../main.zig").GlobalAlloc;
const io = std.io;

pub fn input(argc: c_int, args: [*c]Value) callconv(.C) Value {
    if (argc > 1) return stdlib_error("Expects at least 1 argument for input()!", .{ .argn = argc });
    if (argc == 1) {
        const message = conv.as_zstring(args[0]);
        std.debug.print("{s}\n", .{message});
    }
    const stdin = io.getStdIn().reader();
    var buffer = std.ArrayList(u8).init(GlobalAlloc);
    defer buffer.deinit();
    stdin.streamUntilDelimiter(buffer.writer(), '\n', null) catch return conv.nil_val();
    return conv.string_val(buffer.items[0 .. buffer.items.len - 1]);
}
