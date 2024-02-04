const std = @import("std");
const conv = @import("../conv.zig");
const stdlib = @import("../stdlib.zig");
const Value = @cImport(@cInclude("value.h")).Value;

pub fn now(argc: c_int, args: [*c]Value) callconv(.C) Value {
    _ = args;
    if (argc != 0) return stdlib.stdlib_error("now() expects no arguments!", .{ .argn = argc });

    const time = std.time.timestamp();
    return conv.int_val(@intCast(time));
}

pub fn now_ns(argc: c_int, args: [*c]Value) callconv(.C) Value {
    _ = args;
    if (argc != 0) return stdlib.stdlib_error("now_ns() expects no arguments!", .{ .argn = argc });

    const time = std.time.nanoTimestamp();
    return conv.int_val(@intCast(time));
}

pub fn now_ms(argc: c_int, args: [*c]Value) callconv(.C) Value {
    _ = args;
    if (argc != 0) return stdlib.stdlib_error("now_ms() expects no arguments!", .{ .argn = argc });

    const time = std.time.milliTimestamp();
    return conv.int_val(@intCast(time));
}
