const std = @import("std");
const conv = @import("../conv.zig");
const stdlib = @import("../stdlib.zig");
const Value = @import("../core.zig").value_h.Value;

pub fn now(argc: i32, args: [*]Value) Value {
    _ = args;
    if (argc != 0) return stdlib.stdlib_error("now() expects no arguments!", .{ .argn = argc });

    const time = std.time.timestamp();
    return Value.init_int(@intCast(time));
}

pub fn now_ns(argc: i32, args: [*]Value) Value {
    _ = args;
    if (argc != 0) return stdlib.stdlib_error("now_ns() expects no arguments!", .{ .argn = argc });

    const time = std.time.nanoTimestamp();
    return Value.init_double(@floatFromInt(time));
}

pub fn now_ms(argc: i32, args: [*]Value) Value {
    _ = args;
    if (argc != 0) return stdlib.stdlib_error("now_ms() expects no arguments!", .{ .argn = argc });

    const time = std.time.milliTimestamp();
    return Value.init_double(@floatFromInt(time));
}
