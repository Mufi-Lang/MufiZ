const std = @import("std");
const core = @import("../core.zig");
const conv = @import("../conv.zig");
const stdlib_error = @import("../stdlib.zig").stdlib_error;
const value_h = core.value_h;
const Value = value_h.Value;
const GlobalAlloc = @import("../main.zig").GlobalAlloc;

/// Convert a value to an integer.
pub fn int(argc: c_int, args: [*c]Value) callconv(.C) Value {
    if (argc != 1) return stdlib_error("int() expects one argument!", .{ .argn = argc });

    switch (args[0].type) {
        .VAL_DOUBLE => {
            const d = @ceil(args[0].as_double());
            const i: i32 = @intFromFloat(d);
            return Value.init_int(i);
        },
        .VAL_OBJ => {
            if (Value.is_obj_type(args[0], .OBJ_STRING)) {
                const s = args[0].as_zstring();
                const i = std.fmt.parseInt(i32, s, 10) catch 0;
                return Value.init_int(i);
            } else {
                return Value.init_nil();
            }
        },
        else => return Value.init_nil(),
    }
}

/// Convert a value to a double.
pub fn double(argc: c_int, args: [*c]Value) callconv(.C) Value {
    if (argc != 1) return stdlib_error("double() expects one argument!", .{ .argn = argc });

    switch (args[0].type) {
        .VAL_INT => {
            const i = args[0].as_int();
            const d: f64 = @floatFromInt(i);
            return Value.init_double(d);
        },
        .VAL_OBJ => {
            if (Value.is_obj_type(args[0], .OBJ_STRING)) {
                const s = args[0].as_zstring();
                const d = std.fmt.parseFloat(f64, s) catch 0.0;
                return Value.init_double(d);
            } else {
                return Value.init_nil();
            }
        },
        else => return Value.init_nil(),
    }
}

/// Convert a value to a string.
pub fn str(argc: c_int, args: [*c]Value) callconv(.C) Value {
    if (argc != 1) return stdlib_error("str() expects one argument!", .{ .argn = argc });
    const value = args[0];
    var s: []u8 = undefined;
    switch (value.type) {
        .VAL_INT => {
            const i = value.as_int();
            s = std.fmt.allocPrint(GlobalAlloc, "{d}", .{i}) catch return Value.init_nil();
        },
        .VAL_DOUBLE => {
            const d = value.as_double();
            s = std.fmt.allocPrint(GlobalAlloc, "{}", .{d}) catch return Value.init_nil();
        },
        .VAL_COMPLEX => {
            const c = value.as_complex();
            s = std.fmt.allocPrint(GlobalAlloc, "{}+{}i", .{ c.r, c.i }) catch return Value.init_nil();
        },
        else => return Value.init_nil(),
    }
    const val = Value.init_string(s);
    GlobalAlloc.free(s);
    return val;
}
