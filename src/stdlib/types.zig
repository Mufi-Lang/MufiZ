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
            const d = @ceil(conv.as_double(args[0]));
            const i: i32 = @intFromFloat(d);
            return conv.int_val(i);
        },
        .VAL_OBJ => {
            if (conv.is_obj_type(args[0], .OBJ_STRING)) {
                const s = conv.as_zstring(args[0]);
                const i = std.fmt.parseInt(i32, s, 10) catch 0;
                return conv.int_val(i);
            } else {
                return conv.nil_val();
            }
        },
        else => return conv.nil_val(),
    }
}

/// Convert a value to a double.
pub fn double(argc: c_int, args: [*c]Value) callconv(.C) Value {
    if (argc != 1) return stdlib_error("double() expects one argument!", .{ .argn = argc });

    switch (args[0].type) {
        .VAL_INT => {
            const i = conv.as_int(args[0]);
            const d: f64 = @floatFromInt(i);
            return conv.double_val(d);
        },
        .VAL_OBJ => {
            if (conv.is_obj_type(args[0], .OBJ_STRING)) {
                const s = conv.as_zstring(args[0]);
                const d = std.fmt.parseFloat(f64, s) catch 0.0;
                return conv.double_val(d);
            } else {
                return conv.nil_val();
            }
        },
        else => return conv.nil_val(),
    }
}

/// Convert a value to a string.
pub fn str(argc: c_int, args: [*c]Value) callconv(.C) Value {
    if (argc != 1) return stdlib_error("str() expects one argument!", .{ .argn = argc });
    const value = args[0];
    var s: []u8 = undefined;
    switch (value.type) {
        .VAL_INT => {
            const i = conv.as_int(value);
            s = std.fmt.allocPrint(GlobalAlloc, "{d}", .{i}) catch return conv.nil_val();
        },
        .VAL_DOUBLE => {
            const d = conv.as_double(value);
            s = std.fmt.allocPrint(GlobalAlloc, "{}", .{d}) catch return conv.nil_val();
        },
        .VAL_COMPLEX => {
            const c = conv.as_complex(value);
            s = std.fmt.allocPrint(GlobalAlloc, "{}+{}i", .{ c.r, c.i }) catch return conv.nil_val();
        },
        else => return conv.nil_val(),
    }
    const val = conv.string_val(s);
    GlobalAlloc.free(s);
    return val;
}
