const std = @import("std");
const conv = @import("../conv.zig");
const Value = @import("../core.zig").value_h.Value;
const stdlib_error = @import("../stdlib.zig").stdlib_error;
const NativeFn = @import("../stdlib.zig").NativeFn;
const type_check = conv.type_check;

// Int = 2
// Double = 3

pub fn ln(argc: c_int, args: [*c]Value) callconv(.C) Value {
    if (argc != 1) return stdlib_error("ln() expects one argument!", .{ .argn = argc });
    if (!type_check(1, args, 6)) return stdlib_error("ln() expects a Number!", .{ .value_type = conv.what_is(args[0]) });
    const double = args[0].as_num_double();
    return Value.init_double(@log(double));
}

/// log2(double) double
pub fn log2(argc: c_int, args: [*c]Value) callconv(.C) Value {
    if (argc != 1) return stdlib_error("log2() expects one argument!", .{ .argn = argc });
    if (!type_check(1, args, 6)) return stdlib_error("log2() expects a Number!", .{ .value_type = conv.what_is(args[0]) });
    const double = args[0].as_num_double();
    return Value.init_double(@log2(double));
}
/// log10(double) double
pub fn log10(argc: c_int, args: [*c]Value) callconv(.C) Value {
    if (argc != 1) return stdlib_error("log10() expects one argument!", .{ .argn = argc });
    if (!type_check(1, args, 6)) return stdlib_error("log10() expects a Number!", .{ .value_type = conv.what_is(args[0]) });
    const double = args[0].as_num_double();
    return Value.init_double(@log10(double));
}
/// pi() double
pub fn pi(argc: c_int, args: [*c]Value) callconv(.C) Value {
    _ = args;
    if (argc != 0) return stdlib_error("pi() expects one argument!", .{ .argn = argc });
    return Value.init_double(std.math.pi);
}

pub fn exp(argc: c_int, args: [*c]Value) callconv(.C) Value {
    if (argc != 1) return stdlib_error("exp() expects one argument!", .{ .argn = argc });
    if (!type_check(1, args, 6)) return stdlib_error("exp() expects a Number!", .{ .value_type = conv.what_is(args[0]) });
    const double = args[0].as_num_double();
    return Value.init_double(@exp(double));
}

/// sin(double) double
pub fn sin(argc: c_int, args: [*c]Value) callconv(.C) Value {
    if (argc != 1) return stdlib_error("sin() expects one argument!", .{ .argn = argc });
    if (!type_check(1, args, 6)) return stdlib_error("sin() expects a Number!", .{ .value_type = conv.what_is(args[0]) });
    const double = args[0].as_num_double();
    return Value.init_double(@sin(double));
}
/// cos(double) double
pub fn cos(argc: c_int, args: [*c]Value) callconv(.C) Value {
    if (argc != 1) return stdlib_error("cos() expects one argument!", .{ .argn = argc });
    if (!type_check(1, args, 6)) return stdlib_error("cos() expects a Number!", .{ .value_type = conv.what_is(args[0]) });
    const double = args[0].as_num_double();
    return Value.init_double(@cos(double));
}
/// tan(double) double
pub fn tan(argc: c_int, args: [*c]Value) callconv(.C) Value {
    if (argc != 1) return stdlib_error("tan() expects one argument!", .{ .argn = argc });
    if (!type_check(1, args, 6)) return stdlib_error("tan() expects a Number!", .{ .value_type = conv.what_is(args[0]) });
    const double = args[0].as_num_double();
    return Value.init_double(@tan(double));
}
/// asin(double) double
pub fn asin(argc: c_int, args: [*c]Value) callconv(.C) Value {
    if (argc != 1) return stdlib_error("asin() expects one argument!", .{ .argn = argc });
    if (!type_check(1, args, 6)) return stdlib_error("asin() expects a Number!", .{ .value_type = conv.what_is(args[0]) });
    const double = args[0].as_num_double();
    return Value.init_double(std.math.asin(double));
}
/// acos(double) double
pub fn acos(argc: c_int, args: [*c]Value) callconv(.C) Value {
    if (argc != 1) return stdlib_error("acos() expects one argument!", .{ .argn = argc });
    if (!type_check(1, args, 6)) return stdlib_error("acos() expects a Number!", .{ .value_type = conv.what_is(args[0]) });
    const double = args[0].as_num_double();
    return Value.init_double(std.math.acos(double));
}
/// atan(double) double
pub fn atan(argc: c_int, args: [*c]Value) callconv(.C) Value {
    if (argc != 1) return stdlib_error("atan() expects one argument!", .{ .argn = argc });
    if (!type_check(1, args, 6)) return stdlib_error("atan() expects a Number!", .{ .value_type = conv.what_is(args[0]) });
    const double = args[0].as_num_double();
    return Value.init_double(std.math.atan(double));
}

pub fn complex(argc: c_int, args: [*c]Value) callconv(.C) Value {
    if (argc != 2) return stdlib_error("complex() expects two arguments!", .{ .argn = argc });
    if (!type_check(2, args, 6)) return stdlib_error("complex() expects 2 Number!", .{ .value_type = conv.what_is(args[0]) });
    const r = args[0].as_num_double();
    const i = args[1].as_num_double();
    return Value.init_complex(.{ .r = r, .i = i });
}

pub fn abs(argc: c_int, args: [*c]Value) callconv(.C) Value {
    if (argc != 1) return stdlib_error("abs() expects one argument!", .{ .argn = argc });
    switch (args[0].type) {
        .VAL_COMPLEX => {
            const c = args[0].as_complex();
            return Value.init_double(@sqrt(c.r * c.r + c.i * c.i));
        },
        .VAL_DOUBLE => {
            const d = args[0].as_num_double();
            return Value.init_double(@abs(d));
        },
        .VAL_INT => {
            const i = args[0].as_num_int();
            return Value.init_int(@intCast(@abs(i)));
        },
        else => return stdlib_error("abs() expects a Numeric Type!", .{ .value_type = conv.what_is(args[0]) }),
    }
}

pub fn phase(argc: c_int, args: [*c]Value) callconv(.C) Value {
    if (argc != 1) return stdlib_error("phase() expects one argument!", .{ .argn = argc });
    if (!type_check(1, args, 5)) return stdlib_error("phase() expects a Complex!", .{ .value_type = conv.what_is(args[0]) });
    const c = args[0].as_complex();
    return Value.init_double(std.math.atan2(c.i, c.r));
}

pub fn sfc(argc: c_int, args: [*c]Value) callconv(.C) Value {
    _ = args;
    if (argc != 0) return stdlib_error("rand() expects no arguments!", .{ .argn = argc });
    const seed: u64 = @intCast(std.time.milliTimestamp());
    var gen = std.rand.Sfc64.init(seed);
    const random = gen.random().int(i32);
    return Value.init_int(random);
}

pub fn rand(argc: c_int, args: [*c]Value) callconv(.C) Value {
    _ = args;
    if (argc != 0) return stdlib_error("rand() expects no arguments!", .{ .argn = argc });
    var pcg = std.rand.Pcg.init(@intCast(std.time.microTimestamp()));
    var random = pcg.random();
    const r = random.float(f64);
    return Value.init_double(r);
}

pub fn randn(argc: c_int, args: [*c]Value) callconv(.C) Value {
    _ = args;
    if (argc != 0) return stdlib_error("randn() expects no arguments!", .{ .argn = argc });
    var pcg = std.rand.Pcg.init(@intCast(std.time.microTimestamp()));
    var random = pcg.random();
    const r = random.floatNorm(f64);
    return Value.init_double(r);
}

pub fn pow(argc: c_int, args: [*c]Value) callconv(.C) Value {
    if (argc != 2) return stdlib_error("pow() expects two arguments!", .{ .argn = argc });
    if (!type_check(2, args, 6)) return stdlib_error("pow() expects 2 Number!", .{ .value_type = conv.what_is(args[0]) });
    const base = args[0].as_num_double();
    const exponent = args[1].as_num_double();
    return Value.init_double(std.math.pow(f64, base, exponent));
}

pub fn sqrt(argc: c_int, args: [*c]Value) callconv(.C) Value {
    if (argc != 1) return stdlib_error("sqrt() expects one argument!", .{ .argn = argc });
    if (!type_check(1, args, 6)) return stdlib_error("sqrt() expects a Number!", .{ .value_type = conv.what_is(args[0]) });
    const double = args[0].as_num_double();
    return Value.init_double(@sqrt(double));
}

pub fn ceil(argc: c_int, args: [*c]Value) callconv(.C) Value {
    if (argc != 1) return stdlib_error("ceil() expects one argument!", .{ .argn = argc });
    if (!type_check(1, args, 6)) return stdlib_error("ceil() expects a Number!", .{ .value_type = conv.what_is(args[0]) });
    const double = args[0].as_num_double();
    return Value.init_int(@intFromFloat(@ceil(double)));
}

pub fn floor(argc: c_int, args: [*c]Value) callconv(.C) Value {
    if (argc != 1) return stdlib_error("floor() expects one argument!", .{ .argn = argc });
    if (!type_check(1, args, 6)) return stdlib_error("floor() expects a Number!", .{ .value_type = conv.what_is(args[0]) });
    const double = args[0].as_num_double();
    return Value.init_int(@intFromFloat(@floor(double)));
}

pub fn round(argc: c_int, args: [*c]Value) callconv(.C) Value {
    if (argc != 1) return stdlib_error("round() expects one argument!", .{ .argn = argc });
    if (!type_check(1, args, 6)) return stdlib_error("round() expects a Number!", .{ .value_type = conv.what_is(args[0]) });
    const double = args[0].as_num_double();
    return Value.init_int(@intFromFloat(@round(double)));
}

pub fn max(argc: c_int, args: [*c]Value) callconv(.C) Value {
    if (argc != 2) return stdlib_error("max() expects two arguments!", .{ .argn = argc });
    if (!type_check(2, args, 6)) return stdlib_error("max() expects 2 Number!", .{ .value_type = conv.what_is(args[0]) });
    const a = args[0].as_num_double();
    const b = args[1].as_num_double();
    return Value.init_double(@max(a, b));
}

pub fn min(argc: c_int, args: [*c]Value) callconv(.C) Value {
    if (argc != 2) return stdlib_error("min() expects two arguments!", .{ .argn = argc });
    if (!type_check(2, args, 6)) return stdlib_error("min() expects 2 Number!", .{ .value_type = conv.what_is(args[0]) });
    const a = args[0].as_num_double();
    const b = args[1].as_num_double();
    return Value.init_double(@min(a, b));
}
