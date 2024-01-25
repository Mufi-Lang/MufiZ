const std = @import("std");
const conv = @import("../conv.zig");
const Value = @cImport(@cInclude("value.h")).Value;
const stdlib_error = @import("../stdlib.zig").stdlib_error;
const NativeFn = @import("../stdlib.zig").NativeFn;
const type_check = conv.type_check;

// Int = 2
// Double = 3
/// log2(double) double
pub fn log2(argc: c_int, args: [*c]Value) callconv(.C) Value {
    if (argc != 1) return stdlib_error("log2() expects one argument!", .{ .argn = argc });
    if (!type_check(1, args, 3)) return stdlib_error("log2() expects a Double!", .{ .value_type = conv.what_is(args[0]) });
    const double = conv.as_double(args[0]);
    return conv.double_val(@log2(double));
}
/// log10(double) double
pub fn log10(argc: c_int, args: [*c]Value) callconv(.C) Value {
    if (argc != 1) return stdlib_error("log10() expects one argument!", .{ .argn = argc });
    if (!type_check(1, args, 3)) return stdlib_error("log10() expects a Double!", .{ .value_type = conv.what_is(args[0]) });
    const double = conv.as_double(args[0]);
    return conv.double_val(@log10(double));
}
/// pi() double
pub fn pi(argc: c_int, args: [*c]Value) callconv(.C) Value {
    _ = args;
    if (argc != 0) return stdlib_error("pi() expects one argument!", .{ .argn = argc });
    return conv.double_val(std.math.pi);
}

pub fn exp(argc: c_int, args: [*c]Value) callconv(.C) Value {
    if (argc != 1) return stdlib_error("exp() expects one argument!", .{ .argn = argc });
    if (!type_check(1, args, 3)) return stdlib_error("exp() expects a Double!", .{ .value_type = conv.what_is(args[0]) });
    const double = conv.as_double(args[0]);
    return conv.double_val(@exp(double));
}

/// sin(double) double
pub fn sin(argc: c_int, args: [*c]Value) callconv(.C) Value {
    if (argc != 1) return stdlib_error("sin() expects one argument!", .{ .argn = argc });
    if (!type_check(1, args, 3)) return stdlib_error("sin() expects a Double!", .{ .value_type = conv.what_is(args[0]) });
    const double = conv.as_double(args[0]);
    return conv.double_val(@sin(double));
}
/// cos(double) double
pub fn cos(argc: c_int, args: [*c]Value) callconv(.C) Value {
    if (argc != 1) return stdlib_error("cos() expects one argument!", .{ .argn = argc });
    if (!type_check(1, args, 3)) return stdlib_error("cos() expects a Double!", .{ .value_type = conv.what_is(args[0]) });
    const double = conv.as_double(args[0]);
    return conv.double_val(@cos(double));
}
/// tan(double) double
pub fn tan(argc: c_int, args: [*c]Value) callconv(.C) Value {
    if(argc != 1) return stdlib_error("tan() expects one argument!", .{ .argn = argc });
    if(!type_check(1, args, 3)) return stdlib_error("tan() expects a Double!", .{ .value_type = conv.what_is(args[0]) });
    const double = conv.as_double(args[0]);
    return conv.double_val(@tan(double));
}
/// asin(double) double
pub fn asin(argc: c_int, args: [*c]Value) callconv(.C) Value {
    if(argc != 1) return stdlib_error("asin() expects one argument!", .{ .argn = argc });
    if(!type_check(1, args, 3)) return stdlib_error("asin() expects a Double!", .{ .value_type = conv.what_is(args[0]) });
    const double = conv.as_double(args[0]);
    return conv.double_val(std.math.asin(double));
}
/// acos(double) double
pub fn acos(argc: c_int, args: [*c]Value) callconv(.C) Value {
    if(argc != 1) return stdlib_error("acos() expects one argument!", .{ .argn = argc });
    if(!type_check(1, args, 3)) return stdlib_error("acos() expects a Double!", .{ .value_type = conv.what_is(args[0]) });
    const double = conv.as_double(args[0]);
    return conv.double_val(std.math.acos(double));
}
/// atan(double) double
pub fn atan(argc: c_int, args: [*c]Value) callconv(.C) Value {
    if(argc != 1) return stdlib_error("atan() expects one argument!", .{ .argn = argc });
    if(!type_check(1, args, 3)) return stdlib_error("atan() expects a Double!", .{ .value_type = conv.what_is(args[0]) });
    const double = conv.as_double(args[0]);
    return conv.double_val(std.math.atan(double));
}
