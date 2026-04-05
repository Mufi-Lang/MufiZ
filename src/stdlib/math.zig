const std = @import("std");
const Value = @import("../value.zig").Value;
const stdlib_core = @import("../stdlib_core.zig");
const DefineFunction = stdlib_core.DefineFunction;
const ParamSpec = stdlib_core.ParamSpec;
const ParamType = stdlib_core.ParamType;
const NoParams = stdlib_core.NoParams;
const OneNumber = stdlib_core.OneNumber;
const TwoNumbers = stdlib_core.TwoNumbers;

const Prng = std.Random.Xoshiro256;

// Global PRNG seed state
var global_seed: u64 = 0x1234567890abcdef;

// Internal implementation functions (no validation needed here)
fn ln_impl(_: i32, args: [*]Value) Value {
    const double = args[0].as_num_double();
    return Value.init_double(@log(double));
}

fn log2_impl(_: i32, args: [*]Value) Value {
    const double = args[0].as_num_double();
    return Value.init_double(@log2(double));
}

fn log10_impl(_: i32, args: [*]Value) Value {
    const double = args[0].as_num_double();
    return Value.init_double(@log10(double));
}

fn pi_impl(_: i32, args: [*]Value) Value {
    _ = args;
    return Value.init_double(std.math.pi);
}

fn exp_impl(_: i32, args: [*]Value) Value {
    const double = args[0].as_num_double();
    return Value.init_double(@exp(double));
}

fn sin_impl(_: i32, args: [*]Value) Value {
    const double = args[0].as_num_double();
    return Value.init_double(@sin(double));
}

fn cos_impl(_: i32, args: [*]Value) Value {
    const double = args[0].as_num_double();
    return Value.init_double(@cos(double));
}

fn tan_impl(_: i32, args: [*]Value) Value {
    const double = args[0].as_num_double();
    return Value.init_double(@tan(double));
}

fn asin_impl(_: i32, args: [*]Value) Value {
    const double = args[0].as_num_double();
    return Value.init_double(std.math.asin(double));
}

fn acos_impl(_: i32, args: [*]Value) Value {
    const double = args[0].as_num_double();
    return Value.init_double(std.math.acos(double));
}

fn atan_impl(_: i32, args: [*]Value) Value {
    const double = args[0].as_num_double();
    return Value.init_double(std.math.atan(double));
}

fn complex_impl(_: i32, args: [*]Value) Value {
    const r = args[0].as_num_double();
    const i = args[1].as_num_double();
    return Value.init_complex(.{ .r = r, .i = i });
}

fn abs_impl(_: i32, args: [*]Value) Value {
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
        else => return stdlib_core.stdlib_error("abs() expects a Numeric Type!", .{}),
    }
}

fn phase_impl(_: i32, args: [*]Value) Value {
    const c = args[0].as_complex();
    return Value.init_double(std.math.atan2(c.i, c.r));
}

fn rand_impl(_: i32, args: [*]Value) Value {
    _ = args;
    var seed_bytes: [8]u8 = undefined;
    std.crypto.random.bytes(&seed_bytes);
    const seed = std.mem.readInt(u64, &seed_bytes, .little);
    var rng = Prng.init(seed);
    const r = rng.random().float(f64);
    return Value.init_double(r);
}

fn randn_impl(_: i32, args: [*]Value) Value {
    _ = args;
    var seed_bytes: [8]u8 = undefined;
    std.crypto.random.bytes(&seed_bytes);
    const seed = std.mem.readInt(u64, &seed_bytes, .little);
    var rng = Prng.init(seed);
    const r = rng.random().floatNorm(f64);
    return Value.init_double(r);
}

fn pow_impl(_: i32, args: [*]Value) Value {
    const base = args[0].as_num_double();
    const exponent = args[1].as_num_double();
    return Value.init_double(std.math.pow(f64, base, exponent));
}

fn sqrt_impl(_: i32, args: [*]Value) Value {
    const double = args[0].as_num_double();
    return Value.init_double(@sqrt(double));
}

fn ceil_impl(_: i32, args: [*]Value) Value {
    const double = args[0].as_num_double();
    return Value.init_int(@intFromFloat(@ceil(double)));
}

fn floor_impl(_: i32, args: [*]Value) Value {
    const double = args[0].as_num_double();
    return Value.init_int(@intFromFloat(@floor(double)));
}

fn round_impl(_: i32, args: [*]Value) Value {
    const double = args[0].as_num_double();
    return Value.init_int(@intFromFloat(@round(double)));
}

fn max_impl(_: i32, args: [*]Value) Value {
    const a = args[0].as_num_double();
    const b = args[1].as_num_double();
    return Value.init_double(@max(a, b));
}

fn min_impl(_: i32, args: [*]Value) Value {
    const a = args[0].as_num_double();
    const b = args[1].as_num_double();
    return Value.init_double(@min(a, b));
}

<<<<<<< HEAD
// ============================================================================
// Phase 1: New Math Functions
// ============================================================================

// Hyperbolic trigonometric functions
=======
// ===== Hyperbolic Functions =====

>>>>>>> 44216b23d36fa487e45525341b2478b089f83d67
fn sinh_impl(_: i32, args: [*]Value) Value {
    const double = args[0].as_num_double();
    return Value.init_double(std.math.sinh(double));
}

fn cosh_impl(_: i32, args: [*]Value) Value {
    const double = args[0].as_num_double();
    return Value.init_double(std.math.cosh(double));
}

fn tanh_impl(_: i32, args: [*]Value) Value {
    const double = args[0].as_num_double();
    return Value.init_double(std.math.tanh(double));
}

fn asinh_impl(_: i32, args: [*]Value) Value {
    const double = args[0].as_num_double();
    return Value.init_double(std.math.asinh(double));
}

fn acosh_impl(_: i32, args: [*]Value) Value {
    const double = args[0].as_num_double();
    return Value.init_double(std.math.acosh(double));
}

fn atanh_impl(_: i32, args: [*]Value) Value {
    const double = args[0].as_num_double();
    return Value.init_double(std.math.atanh(double));
}

<<<<<<< HEAD
// Two-argument arctangent
=======
// ===== Angle and Utility Functions =====

>>>>>>> 44216b23d36fa487e45525341b2478b089f83d67
fn atan2_impl(_: i32, args: [*]Value) Value {
    const y = args[0].as_num_double();
    const x = args[1].as_num_double();
    return Value.init_double(std.math.atan2(y, x));
}

<<<<<<< HEAD
// Angle conversion functions
fn deg2rad_impl(_: i32, args: [*]Value) Value {
    const degrees = args[0].as_num_double();
    return Value.init_double(degrees * std.math.pi / 180.0);
}

fn rad2deg_impl(_: i32, args: [*]Value) Value {
    const radians = args[0].as_num_double();
    return Value.init_double(radians * 180.0 / std.math.pi);
}

// Euclidean distance
fn hypot_impl(_: i32, args: [*]Value) Value {
    const x = args[0].as_num_double();
    const y = args[1].as_num_double();
    return Value.init_double(std.math.hypot(x, y));
}

// Complex number operations
fn conj_impl(_: i32, args: [*]Value) Value {
    const c = args[0].as_complex();
    return Value.init_complex(.{ .r = c.r, .i = -c.i });
}

fn real_impl(_: i32, args: [*]Value) Value {
    const c = args[0].as_complex();
    return Value.init_double(c.r);
}

fn imag_impl(_: i32, args: [*]Value) Value {
    const c = args[0].as_complex();
    return Value.init_double(c.i);
}

// Integer math functions
fn gcd_impl(_: i32, args: [*]Value) Value {
    var a: i64 = @abs(args[0].as_num_int());
    var b: i64 = @abs(args[1].as_num_int());
    
    while (b != 0) {
        const temp = b;
        b = @mod(a, b);
        a = temp;
    }
    return Value.init_int(@intCast(a));
}

fn lcm_impl(_: i32, args: [*]Value) Value {
    const a: i64 = @abs(args[0].as_num_int());
    const b: i64 = @abs(args[1].as_num_int());
    
    if (a == 0 or b == 0) {
        return Value.init_int(0);
    }
    
    // LCM(a,b) = |a*b| / GCD(a,b)
    var gcd_a = a;
    var gcd_b = b;
    while (gcd_b != 0) {
        const temp = gcd_b;
        gcd_b = @mod(gcd_a, gcd_b);
        gcd_a = temp;
    }
    
    return Value.init_int(@intCast(@divTrunc(a * b, gcd_a)));
}

fn factorial_impl(_: i32, args: [*]Value) Value {
    const n = args[0].as_num_int();
    
    if (n < 0) {
        return stdlib_core.stdlib_error("factorial() requires non-negative integer", .{});
    }
    
    if (n > 20) {
        return stdlib_core.stdlib_error("factorial() overflow: n > 20", .{});
    }
    
    var result: i64 = 1;
    var i: i64 = 2;
    while (i <= n) : (i += 1) {
        result *= i;
    }
    
    return Value.init_int(@intCast(result));
}

// Rounding and utility functions
fn trunc_impl(_: i32, args: [*]Value) Value {
    const double = args[0].as_num_double();
    return Value.init_int(@intFromFloat(@trunc(double)));
}

fn sign_impl(_: i32, args: [*]Value) Value {
    switch (args[0].type) {
        .VAL_DOUBLE => {
            const d = args[0].as_num_double();
            if (d > 0.0) return Value.init_int(1);
            if (d < 0.0) return Value.init_int(-1);
            return Value.init_int(0);
        },
        .VAL_INT => {
            const i = args[0].as_num_int();
            if (i > 0) return Value.init_int(1);
            if (i < 0) return Value.init_int(-1);
            return Value.init_int(0);
        },
        else => return stdlib_core.stdlib_error("sign() expects a number", .{}),
    }
=======
fn sign_impl(_: i32, args: [*]Value) Value {
    const double = args[0].as_num_double();
    if (double > 0.0) return Value.init_int(1);
    if (double < 0.0) return Value.init_int(-1);
    return Value.init_int(0);
>>>>>>> 44216b23d36fa487e45525341b2478b089f83d67
}

fn clamp_impl(_: i32, args: [*]Value) Value {
    const x = args[0].as_num_double();
    const min_val = args[1].as_num_double();
    const max_val = args[2].as_num_double();
<<<<<<< HEAD
    
    if (min_val > max_val) {
        return stdlib_core.stdlib_error("clamp() requires min <= max", .{});
    }
    
    return Value.init_double(std.math.clamp(x, min_val, max_val));
=======
    const clamped = @max(min_val, @min(max_val, x));
    return Value.init_double(clamped);
}

// ===== Complex Number Utilities =====

fn real_impl(_: i32, args: [*]Value) Value {
    if (args[0].type == .VAL_COMPLEX) {
        const c = args[0].as_complex();
        return Value.init_double(c.r);
    } else if (args[0].type == .VAL_DOUBLE) {
        return Value.init_double(args[0].as_num_double());
    } else if (args[0].type == .VAL_INT) {
        return Value.init_int(args[0].as_num_int());
    } else {
        return stdlib_core.stdlib_error("real() expects a number or complex type!", .{});
    }
}

fn imag_impl(_: i32, args: [*]Value) Value {
    if (args[0].type == .VAL_COMPLEX) {
        const c = args[0].as_complex();
        return Value.init_double(c.i);
    } else if (args[0].type == .VAL_DOUBLE or args[0].type == .VAL_INT) {
        return Value.init_double(0.0);
    } else {
        return stdlib_core.stdlib_error("imag() expects a number or complex type!", .{});
    }
}

fn conj_impl(_: i32, args: [*]Value) Value {
    if (args[0].type == .VAL_COMPLEX) {
        const c = args[0].as_complex();
        return Value.init_complex(.{ .r = c.r, .i = -c.i });
    } else if (args[0].type == .VAL_DOUBLE or args[0].type == .VAL_INT) {
        // Conjugate of real number is itself
        return args[0];
    } else {
        return stdlib_core.stdlib_error("conj() expects a number or complex type!", .{});
    }
}

// ===== Phase 4: Enhanced Randomness & Special Functions =====

fn set_seed_impl(_: i32, args: [*]Value) Value {
    const seed_i32 = args[0].as_num_int();
    const seed_u32: u32 = @bitCast(seed_i32);
    global_seed = @as(u64, seed_u32);
    return Value.init_nil();
}

fn get_seed_impl(_: i32, args: [*]Value) Value {
    _ = args;
    const seed_u32: u32 = @truncate(global_seed);
    return Value.init_int(@as(i32, @bitCast(seed_u32)));
}

fn randint_impl(_: i32, args: [*]Value) Value {
    const min_val = args[0].as_num_int();
    const max_val = args[1].as_num_int();
    
    if (min_val >= max_val) {
        return stdlib_core.stdlib_error("randint: min must be less than max!", .{});
    }
    
    var rng = Prng.init(global_seed);
    global_seed +%= 1;
    
    const range = @as(u32, @intCast(max_val - min_val));
    const random_offset = rng.random().int(u32) % range;
    
    return Value.init_int(min_val + @as(i32, @intCast(random_offset)));
}

fn randrange_impl(_: i32, args: [*]Value) Value {
    const min_val = args[0].as_num_double();
    const max_val = args[1].as_num_double();
    const count = @as(usize, @intCast(args[2].as_num_int()));
    
    if (min_val >= max_val) {
        return stdlib_core.stdlib_error("randrange: min must be less than max!", .{});
    }
    
    const object_h = @import("../object.zig");
    const FloatVector = object_h.FloatVector;
    const result = FloatVector.init(count);
    
    var rng = Prng.init(global_seed);
    const range = max_val - min_val;
    
    for (0..count) |i| {
        const r = rng.random().float(f64);
        result.data[i] = min_val + r * range;
        global_seed +%= 1;
    }
    result.size = count;
    
    return Value.init_obj(@ptrCast(result));
}

fn isnan_impl(_: i32, args: [*]Value) Value {
    const num = args[0].as_num_double();
    return Value.init_int(if (std.math.isNan(num)) 1 else 0);
}

fn isinf_impl(_: i32, args: [*]Value) Value {
    const num = args[0].as_num_double();
    return Value.init_int(if (std.math.isInf(num)) 1 else 0);
}

fn isfinite_impl(_: i32, args: [*]Value) Value {
    const num = args[0].as_num_double();
    return Value.init_int(if (std.math.isFinite(num)) 1 else 0);
}

fn factorial_impl(_: i32, args: [*]Value) Value {
    const n = args[0].as_num_int();
    
    if (n < 0) {
        return stdlib_core.stdlib_error("factorial: n must be non-negative!", .{});
    }
    
    var result: i32 = 1;
    var i: i32 = 2;
    while (i <= n) : (i += 1) {
        result *= i;
    }
    
    return Value.init_int(result);
}

fn gcd_impl(_: i32, args: [*]Value) Value {
    var a: u32 = @bitCast(@abs(args[0].as_num_int()));
    var b: u32 = @bitCast(@abs(args[1].as_num_int()));
    
    while (b != 0) {
        const temp = b;
        b = a % b;
        a = temp;
    }
    
    return Value.init_int(@as(i32, @bitCast(a)));
}

fn lcm_impl(_: i32, args: [*]Value) Value {
    const a: u32 = @bitCast(@abs(args[0].as_num_int()));
    const b: u32 = @bitCast(@abs(args[1].as_num_int()));
    
    if (a == 0 or b == 0) {
        return Value.init_int(0);
    }
    
    var gcd_a = a;
    var gcd_b = b;
    while (gcd_b != 0) {
        const temp = gcd_b;
        gcd_b = gcd_a % gcd_b;
        gcd_a = temp;
    }
    
    return Value.init_int(@as(i32, @bitCast((a / gcd_a) * b)));
}

fn isprime_impl(_: i32, args: [*]Value) Value {
    const n = args[0].as_num_int();
    
    if (n < 2) return Value.init_int(0);
    if (n == 2) return Value.init_int(1);
    if (@rem(n, 2) == 0) return Value.init_int(0);
    
    var i: i32 = 3;
    while (i * i <= n) : (i += 2) {
        if (@rem(n, i) == 0) return Value.init_int(0);
    }
    
    return Value.init_int(1);
}

fn nextprime_impl(_: i32, args: [*]Value) Value {
    var n = args[0].as_num_int() + 1;
    
    while (n < 1000000) : (n += 1) {
        if (n < 2) continue;
        if (n == 2) return Value.init_int(n);
        if (@rem(n, 2) == 0) continue;
        
        var is_prime = true;
        var i: i32 = 3;
        while (i * i <= n) : (i += 2) {
            if (@rem(n, i) == 0) {
                is_prime = false;
                break;
            }
        }
        
        if (is_prime) return Value.init_int(n);
    }
    
    return stdlib_core.stdlib_error("nextprime: no prime found!", .{});
>>>>>>> 44216b23d36fa487e45525341b2478b089f83d67
}

// Auto-registered function wrappers with metadata
pub const ln = DefineFunction(
    "ln",
    "math",
    "Natural logarithm",
    OneNumber,
    .double,
    &[_][]const u8{"ln(2.71828) -> 1.0"},
    ln_impl,
);

pub const log2 = DefineFunction(
    "log2",
    "math",
    "Base-2 logarithm",
    OneNumber,
    .double,
    &[_][]const u8{"log2(8) -> 3.0"},
    log2_impl,
);

pub const log10 = DefineFunction(
    "log10",
    "math",
    "Base-10 logarithm",
    OneNumber,
    .double,
    &[_][]const u8{"log10(100) -> 2.0"},
    log10_impl,
);

pub const pi = DefineFunction(
    "pi",
    "math",
    "Pi constant (3.14159...)",
    NoParams,
    .double,
    &[_][]const u8{"pi() -> 3.141592653589793"},
    pi_impl,
);

pub const exp = DefineFunction(
    "exp",
    "math",
    "Exponential function (e^x)",
    OneNumber,
    .double,
    &[_][]const u8{"exp(1) -> 2.718281828459045"},
    exp_impl,
);

pub const sin = DefineFunction(
    "sin",
    "math",
    "Sine function",
    OneNumber,
    .double,
    &[_][]const u8{"sin(pi()/2) -> 1.0"},
    sin_impl,
);

pub const cos = DefineFunction(
    "cos",
    "math",
    "Cosine function",
    OneNumber,
    .double,
    &[_][]const u8{"cos(0) -> 1.0"},
    cos_impl,
);

pub const tan = DefineFunction(
    "tan",
    "math",
    "Tangent function",
    OneNumber,
    .double,
    &[_][]const u8{"tan(pi()/4) -> 1.0"},
    tan_impl,
);

pub const asin = DefineFunction(
    "asin",
    "math",
    "Arcsine function",
    OneNumber,
    .double,
    &[_][]const u8{"asin(1) -> 1.5707963267948966"},
    asin_impl,
);

pub const acos = DefineFunction(
    "acos",
    "math",
    "Arccosine function",
    OneNumber,
    .double,
    &[_][]const u8{"acos(0) -> 1.5707963267948966"},
    acos_impl,
);

pub const atan = DefineFunction(
    "atan",
    "math",
    "Arctangent function",
    OneNumber,
    .double,
    &[_][]const u8{"atan(1) -> 0.7853981633974483"},
    atan_impl,
);

pub const complex = DefineFunction(
    "complex",
    "math",
    "Creates a complex number from real and imaginary parts",
    &[_]ParamSpec{
        .{ .name = "real", .type = .number },
        .{ .name = "imaginary", .type = .number },
    },
    .complex,
    &[_][]const u8{"complex(3, 4) -> 3+4i"},
    complex_impl,
);

pub const abs = DefineFunction(
    "abs",
    "math",
    "Absolute value or magnitude",
    &[_]ParamSpec{
        .{ .name = "value", .type = .any }, // Can be number or complex
    },
    .number,
    &[_][]const u8{
        "abs(-5) -> 5",
        "abs(3.14) -> 3.14",
        "abs(complex(3, 4)) -> 5.0",
    },
    abs_impl,
);

pub const phase = DefineFunction(
    "phase",
    "math",
    "Phase (argument) of a complex number",
    &[_]ParamSpec{
        .{ .name = "complex", .type = .complex },
    },
    .double,
    &[_][]const u8{"phase(complex(1, 1)) -> 0.7853981633974483"},
    phase_impl,
);

pub const rand = DefineFunction(
    "rand",
    "math",
    "Random float in range [0, 1)",
    NoParams,
    .double,
    &[_][]const u8{"rand() -> 0.42"},
    rand_impl,
);

pub const randn = DefineFunction(
    "randn",
    "math",
    "Random number from normal distribution",
    NoParams,
    .double,
    &[_][]const u8{"randn() -> -0.123"},
    randn_impl,
);

pub const pow = DefineFunction(
    "pow",
    "math",
    "Power function (base^exponent)",
    TwoNumbers,
    .double,
    &[_][]const u8{"pow(2, 3) -> 8.0"},
    pow_impl,
);

pub const sqrt = DefineFunction(
    "sqrt",
    "math",
    "Square root",
    OneNumber,
    .double,
    &[_][]const u8{"sqrt(16) -> 4.0"},
    sqrt_impl,
);

pub const ceil = DefineFunction(
    "ceil",
    "math",
    "Ceiling function (round up to nearest integer)",
    OneNumber,
    .int,
    &[_][]const u8{"ceil(3.2) -> 4"},
    ceil_impl,
);

pub const floor = DefineFunction(
    "floor",
    "math",
    "Floor function (round down to nearest integer)",
    OneNumber,
    .int,
    &[_][]const u8{"floor(3.8) -> 3"},
    floor_impl,
);

pub const round = DefineFunction(
    "round",
    "math",
    "Round to nearest integer",
    OneNumber,
    .int,
    &[_][]const u8{"round(3.6) -> 4"},
    round_impl,
);

pub const max = DefineFunction(
    "max",
    "math",
    "Maximum of two numbers",
    TwoNumbers,
    .double,
    &[_][]const u8{"max(3, 7) -> 7.0"},
    max_impl,
);

pub const min = DefineFunction(
    "min",
    "math",
    "Minimum of two numbers",
    TwoNumbers,
    .double,
    &[_][]const u8{"min(3, 7) -> 3.0"},
    min_impl,
);

<<<<<<< HEAD
// ============================================================================
// Phase 1: New Math Functions
// ============================================================================

// Hyperbolic trigonometric functions
=======
// ===== Hyperbolic Functions =====

>>>>>>> 44216b23d36fa487e45525341b2478b089f83d67
pub const sinh = DefineFunction(
    "sinh",
    "math",
    "Hyperbolic sine function",
    OneNumber,
    .double,
<<<<<<< HEAD
    &[_][]const u8{"sinh(0) -> 0.0", "sinh(1) -> 1.1752011936438014"},
=======
    &[_][]const u8{"sinh(0) -> 0.0"},
>>>>>>> 44216b23d36fa487e45525341b2478b089f83d67
    sinh_impl,
);

pub const cosh = DefineFunction(
    "cosh",
    "math",
    "Hyperbolic cosine function",
    OneNumber,
    .double,
<<<<<<< HEAD
    &[_][]const u8{"cosh(0) -> 1.0", "cosh(1) -> 1.5430806348152437"},
=======
    &[_][]const u8{"cosh(0) -> 1.0"},
>>>>>>> 44216b23d36fa487e45525341b2478b089f83d67
    cosh_impl,
);

pub const tanh = DefineFunction(
    "tanh",
    "math",
    "Hyperbolic tangent function",
    OneNumber,
    .double,
<<<<<<< HEAD
    &[_][]const u8{"tanh(0) -> 0.0", "tanh(1) -> 0.7615941559557649"},
=======
    &[_][]const u8{"tanh(0) -> 0.0"},
>>>>>>> 44216b23d36fa487e45525341b2478b089f83d67
    tanh_impl,
);

pub const asinh = DefineFunction(
    "asinh",
    "math",
    "Inverse hyperbolic sine function",
    OneNumber,
    .double,
<<<<<<< HEAD
    &[_][]const u8{"asinh(0) -> 0.0", "asinh(1) -> 0.881373587019543"},
=======
    &[_][]const u8{"asinh(0) -> 0.0"},
>>>>>>> 44216b23d36fa487e45525341b2478b089f83d67
    asinh_impl,
);

pub const acosh = DefineFunction(
    "acosh",
    "math",
    "Inverse hyperbolic cosine function",
    OneNumber,
    .double,
<<<<<<< HEAD
    &[_][]const u8{"acosh(1) -> 0.0", "acosh(2) -> 1.3169578969248166"},
=======
    &[_][]const u8{"acosh(1) -> 0.0"},
>>>>>>> 44216b23d36fa487e45525341b2478b089f83d67
    acosh_impl,
);

pub const atanh = DefineFunction(
    "atanh",
    "math",
    "Inverse hyperbolic tangent function",
    OneNumber,
    .double,
<<<<<<< HEAD
    &[_][]const u8{"atanh(0) -> 0.0", "atanh(0.5) -> 0.5493061443340548"},
    atanh_impl,
);

pub const atan2 = DefineFunction(
    "atan2",
    "math",
    "Two-argument arctangent (atan2(y, x))",
    &[_]ParamSpec{
        .{ .name = "y", .type = .number },
        .{ .name = "x", .type = .number },
    },
    .double,
    &[_][]const u8{"atan2(1, 1) -> 0.7853981633974483", "atan2(0, -1) -> 3.141592653589793"},
    atan2_impl,
);

pub const deg2rad = DefineFunction(
    "deg2rad",
    "math",
    "Convert degrees to radians",
    OneNumber,
    .double,
    &[_][]const u8{"deg2rad(180) -> 3.141592653589793", "deg2rad(90) -> 1.5707963267948966"},
    deg2rad_impl,
);

pub const rad2deg = DefineFunction(
    "rad2deg",
    "math",
    "Convert radians to degrees",
    OneNumber,
    .double,
    &[_][]const u8{"rad2deg(3.14159) -> 180.0", "rad2deg(1.5708) -> 90.0"},
    rad2deg_impl,
);

pub const hypot = DefineFunction(
    "hypot",
    "math",
    "Euclidean distance sqrt(x²+y²)",
    TwoNumbers,
    .double,
    &[_][]const u8{"hypot(3, 4) -> 5.0", "hypot(5, 12) -> 13.0"},
    hypot_impl,
);

pub const conj = DefineFunction(
    "conj",
    "math",
    "Complex conjugate",
    &[_]ParamSpec{
        .{ .name = "complex", .type = .complex },
    },
    .complex,
    &[_][]const u8{"conj(3+4i) -> 3-4i"},
    conj_impl,
);

pub const real = DefineFunction(
    "real",
    "math",
    "Extract real part of complex number",
    &[_]ParamSpec{
        .{ .name = "complex", .type = .complex },
    },
    .double,
    &[_][]const u8{"real(3+4i) -> 3.0"},
    real_impl,
);

pub const imag = DefineFunction(
    "imag",
    "math",
    "Extract imaginary part of complex number",
    &[_]ParamSpec{
        .{ .name = "complex", .type = .complex },
    },
    .double,
    &[_][]const u8{"imag(3+4i) -> 4.0"},
    imag_impl,
);

pub const gcd = DefineFunction(
    "gcd",
    "math",
    "Greatest common divisor",
    &[_]ParamSpec{
        .{ .name = "a", .type = .int },
        .{ .name = "b", .type = .int },
    },
    .int,
    &[_][]const u8{"gcd(12, 8) -> 4", "gcd(21, 14) -> 7"},
    gcd_impl,
);

pub const lcm = DefineFunction(
    "lcm",
    "math",
    "Least common multiple",
    &[_]ParamSpec{
        .{ .name = "a", .type = .int },
        .{ .name = "b", .type = .int },
    },
    .int,
    &[_][]const u8{"lcm(12, 8) -> 24", "lcm(21, 14) -> 42"},
    lcm_impl,
);

pub const factorial = DefineFunction(
    "factorial",
    "math",
    "Factorial function (n!)",
    &[_]ParamSpec{
        .{ .name = "n", .type = .int },
    },
    .int,
    &[_][]const u8{"factorial(5) -> 120", "factorial(0) -> 1"},
    factorial_impl,
);

pub const trunc = DefineFunction(
    "trunc",
    "math",
    "Truncate to integer (remove fractional part)",
    OneNumber,
    .int,
    &[_][]const u8{"trunc(3.9) -> 3", "trunc(-2.5) -> -2"},
    trunc_impl,
=======
    &[_][]const u8{"atanh(0) -> 0.0"},
    atanh_impl,
);

// ===== Angle and Utility Functions =====

pub const atan2 = DefineFunction(
    "atan2",
    "math",
    "Two-argument arctangent with proper quadrant handling",
    TwoNumbers,
    .double,
    &[_][]const u8{"atan2(1, 1) -> 0.7853981633974483"},
    atan2_impl,
>>>>>>> 44216b23d36fa487e45525341b2478b089f83d67
);

pub const sign = DefineFunction(
    "sign",
    "math",
<<<<<<< HEAD
    "Sign function (-1, 0, or 1)",
    OneNumber,
    .int,
    &[_][]const u8{"sign(5.2) -> 1", "sign(-3) -> -1", "sign(0) -> 0"},
=======
    "Sign function: returns -1, 0, or 1",
    OneNumber,
    .int,
    &[_][]const u8{
        "sign(5) -> 1",
        "sign(-3) -> -1",
        "sign(0) -> 0",
    },
>>>>>>> 44216b23d36fa487e45525341b2478b089f83d67
    sign_impl,
);

pub const clamp = DefineFunction(
    "clamp",
    "math",
    "Clamp value to range [min, max]",
    &[_]ParamSpec{
<<<<<<< HEAD
        .{ .name = "x", .type = .number },
=======
        .{ .name = "value", .type = .number },
>>>>>>> 44216b23d36fa487e45525341b2478b089f83d67
        .{ .name = "min", .type = .number },
        .{ .name = "max", .type = .number },
    },
    .double,
<<<<<<< HEAD
    &[_][]const u8{"clamp(5, 0, 10) -> 5.0", "clamp(15, 0, 10) -> 10.0", "clamp(-5, 0, 10) -> 0.0"},
    clamp_impl,
);

// ============================================================
// Phase 3: Vector Operations
// ============================================================

fn dot_impl(_: i32, args: [*]Value) Value {
    const v1 = args[0];
    const v2 = args[1];
    
    if (!Value.is_obj_type(v1, .OBJ_FVECTOR) or !Value.is_obj_type(v2, .OBJ_FVECTOR)) {
        return Value.init_nil();
    }
    
    const vec1 = v1.as_vector();
    const vec2 = v2.as_vector();
    
    if (vec1.count != vec2.count) {
        return Value.init_nil();
    }
    
    var dot_sum: f64 = 0.0;
    for (0..vec1.count) |i| {
        dot_sum += vec1.data[i] * vec2.data[i];
    }
    
    return Value.init_double(dot_sum);
}

fn norm_impl(_: i32, args: [*]Value) Value {
    const v = args[0];
    
    if (!Value.is_obj_type(v, .OBJ_FVECTOR)) {
        return Value.init_nil();
    }
    
    const vec = v.as_vector();
    var sum_sq: f64 = 0.0;
    
    for (0..vec.count) |i| {
        sum_sq += vec.data[i] * vec.data[i];
    }
    
    return Value.init_double(@sqrt(sum_sq));
}

fn length_impl(_: i32, args: [*]Value) Value {
    return norm_impl(1, args);
}

pub const dot = DefineFunction(
    "dot",
    "math",
    "Dot product of two vectors",
    &[_]ParamSpec{
        .{ .name = "v1", .type = .object },
        .{ .name = "v2", .type = .object },
    },
    .double,
    &[_][]const u8{"dot([1,2], [3,4]) -> 11.0"},
    dot_impl,
);

pub const norm = DefineFunction(
    "norm",
    "math",
    "Vector norm (magnitude)",
    &[_]ParamSpec{
        .{ .name = "v", .type = .object },
    },
    .double,
    &[_][]const u8{"norm([3,4]) -> 5.0"},
    norm_impl,
);

pub const length = DefineFunction(
    "length",
    "math",
    "Vector length",
    &[_]ParamSpec{
        .{ .name = "v", .type = .object },
    },
    .double,
    &[_][]const u8{"length([3,4]) -> 5.0"},
    length_impl,
);

// ============================================================
// Phase 4: Statistical Functions
// ============================================================

fn sum_impl(_: i32, args: [*]Value) Value {
    const arr = args[0];
    
    if (!Value.is_obj_type(arr, .OBJ_LINKED_LIST) and 
        !Value.is_obj_type(arr, .OBJ_FVECTOR)) {
        return Value.init_double(0.0);
    }
    
    var total: f64 = 0.0;
    
    if (Value.is_obj_type(arr, .OBJ_LINKED_LIST)) {
        const list = arr.as_linked_list();
        var node = list.head;
        while (node != null) {
            const item = node.?.data;
            if (item.is_prim_num()) {
                total += item.as_num_double();
            }
            node = node.?.next;
        }
    } else {
        const vec = arr.as_vector();
        for (0..vec.count) |i| {
            total += vec.data[i];
        }
    }
    
    return Value.init_double(total);
}

fn mean_impl(_: i32, args: [*]Value) Value {
    const arr = args[0];
    
    if (!Value.is_obj_type(arr, .OBJ_LINKED_LIST) and 
        !Value.is_obj_type(arr, .OBJ_FVECTOR)) {
        return Value.init_nil();
    }
    
    var count: f64 = 0.0;
    var total: f64 = 0.0;
    
    if (Value.is_obj_type(arr, .OBJ_LINKED_LIST)) {
        const list = arr.as_linked_list();
        var node = list.head;
        while (node != null) {
            const item = node.?.data;
            if (item.is_prim_num()) {
                total += item.as_num_double();
                count += 1.0;
            }
            node = node.?.next;
        }
    } else {
        const vec = arr.as_vector();
        count = @floatFromInt(vec.count);
        for (0..vec.count) |i| {
            total += vec.data[i];
        }
    }
    
    if (count == 0.0) {
        return Value.init_nil();
    }
    
    return Value.init_double(total / count);
}

fn variance_impl(_: i32, args: [*]Value) Value {
    const arr = args[0];
    
    if (!Value.is_obj_type(arr, .OBJ_LINKED_LIST) and 
        !Value.is_obj_type(arr, .OBJ_FVECTOR)) {
        return Value.init_nil();
    }
    
    // First compute mean
    var count: f64 = 0.0;
    var total: f64 = 0.0;
    
    if (Value.is_obj_type(arr, .OBJ_LINKED_LIST)) {
        const list = arr.as_linked_list();
        var node = list.head;
        while (node != null) {
            const item = node.?.data;
            if (item.is_prim_num()) {
                total += item.as_num_double();
                count += 1.0;
            }
            node = node.?.next;
        }
    } else {
        const vec = arr.as_vector();
        count = @floatFromInt(vec.count);
        for (0..vec.count) |i| {
            total += vec.data[i];
        }
    }
    
    if (count < 2.0) {
        return Value.init_nil();
    }
    
    const avg = total / count;
    
    // Compute variance
    var sum_sq_dev: f64 = 0.0;
    
    if (Value.is_obj_type(arr, .OBJ_LINKED_LIST)) {
        const list = arr.as_linked_list();
        var node = list.head;
        while (node != null) {
            const item = node.?.data;
            if (item.is_prim_num()) {
                const dev = item.as_num_double() - avg;
                sum_sq_dev += dev * dev;
            }
            node = node.?.next;
        }
    } else {
        const vec = arr.as_vector();
        for (0..vec.count) |i| {
            const dev = vec.data[i] - avg;
            sum_sq_dev += dev * dev;
        }
    }
    
    return Value.init_double(sum_sq_dev / (count - 1.0));
}

fn stddev_impl(_: i32, args: [*]Value) Value {
    const var_result = variance_impl(1, args);
    
    if (var_result.type == .VAL_NIL) {
        return Value.init_nil();
    }
    
    const var_val = var_result.as_num_double();
    return Value.init_double(@sqrt(var_val));
}

pub const sum = DefineFunction(
    "sum",
    "math",
    "Sum of array elements",
    &[_]ParamSpec{
        .{ .name = "arr", .type = .object },
    },
    .double,
    &[_][]const u8{"sum([1,2,3]) -> 6.0"},
    sum_impl,
);

pub const mean = DefineFunction(
    "mean",
    "math",
    "Mean of array",
    &[_]ParamSpec{
        .{ .name = "arr", .type = .object },
    },
    .double,
    &[_][]const u8{"mean([1,2,3]) -> 2.0"},
    mean_impl,
);

pub const variance = DefineFunction(
    "variance",
    "math",
    "Variance of array",
    &[_]ParamSpec{
        .{ .name = "arr", .type = .object },
    },
    .double,
    &[_][]const u8{"variance([1,2,3]) -> 1.0"},
    variance_impl,
);

pub const stddev = DefineFunction(
    "stddev",
    "math",
    "Standard deviation",
    &[_]ParamSpec{
        .{ .name = "arr", .type = .object },
    },
    .double,
    &[_][]const u8{"stddev([1,2,3]) -> ~1.41"},
    stddev_impl,
=======
    &[_][]const u8{
        "clamp(5, 0, 10) -> 5.0",
        "clamp(-5, 0, 10) -> 0.0",
        "clamp(15, 0, 10) -> 10.0",
    },
    clamp_impl,
);

// ===== Complex Number Utilities =====

pub const real = DefineFunction(
    "real",
    "math",
    "Extract real part of a complex number (or return the number itself)",
    &[_]ParamSpec{
        .{ .name = "value", .type = .any },
    },
    .number,
    &[_][]const u8{
        "real(complex(3, 4)) -> 3.0",
        "real(5) -> 5",
    },
    real_impl,
);

pub const imag = DefineFunction(
    "imag",
    "math",
    "Extract imaginary part of a complex number (or return 0 for real numbers)",
    &[_]ParamSpec{
        .{ .name = "value", .type = .any },
    },
    .double,
    &[_][]const u8{
        "imag(complex(3, 4)) -> 4.0",
        "imag(5) -> 0.0",
    },
    imag_impl,
);

pub const conj = DefineFunction(
    "conj",
    "math",
    "Complex conjugate (negates imaginary part)",
    &[_]ParamSpec{
        .{ .name = "value", .type = .any },
    },
    .any,
    &[_][]const u8{
        "conj(complex(3, 4)) -> complex(3, -4)",
        "conj(5) -> 5",
    },
    conj_impl,
);

// ===== Phase 4: Enhanced Randomness & Special Functions =====

pub const set_seed = DefineFunction(
    "set_seed",
    "math",
    "Set global PRNG seed for reproducibility",
    &[_]ParamSpec{
        .{ .name = "seed", .type = .int },
    },
    .nil,
    &[_][]const u8{"set_seed(42)"},
    set_seed_impl,
);

pub const get_seed = DefineFunction(
    "get_seed",
    "math",
    "Get current PRNG seed value",
    NoParams,
    .int,
    &[_][]const u8{"get_seed() -> 42"},
    get_seed_impl,
);

pub const randint = DefineFunction(
    "randint",
    "math",
    "Random integer in range [min, max)",
    TwoNumbers,
    .int,
    &[_][]const u8{"randint(1, 10) -> random int in range"},
    randint_impl,
);

pub const randrange = DefineFunction(
    "randrange",
    "math",
    "n random floats in range [min, max)",
    &[_]ParamSpec{
        .{ .name = "min", .type = .number },
        .{ .name = "max", .type = .number },
        .{ .name = "n", .type = .int },
    },
    .object,
    &[_][]const u8{"randrange(0, 1, 5) -> 5 random floats"},
    randrange_impl,
);

pub const isnan = DefineFunction(
    "isnan",
    "math",
    "Check if value is NaN",
    OneNumber,
    .int,
    &[_][]const u8{"isnan(0/0) -> 1", "isnan(5) -> 0"},
    isnan_impl,
);

pub const isinf = DefineFunction(
    "isinf",
    "math",
    "Check if value is infinite",
    OneNumber,
    .int,
    &[_][]const u8{"isinf(1/0) -> 1", "isinf(5) -> 0"},
    isinf_impl,
);

pub const isfinite = DefineFunction(
    "isfinite",
    "math",
    "Check if value is finite",
    OneNumber,
    .int,
    &[_][]const u8{"isfinite(5) -> 1", "isfinite(1/0) -> 0"},
    isfinite_impl,
);

pub const factorial = DefineFunction(
    "factorial",
    "math",
    "Factorial (n!)",
    OneNumber,
    .int,
    &[_][]const u8{
        "factorial(5) -> 120",
        "factorial(0) -> 1",
    },
    factorial_impl,
);

pub const gcd = DefineFunction(
    "gcd",
    "math",
    "Greatest common divisor",
    TwoNumbers,
    .int,
    &[_][]const u8{
        "gcd(48, 18) -> 6",
        "gcd(100, 50) -> 50",
    },
    gcd_impl,
);

pub const lcm = DefineFunction(
    "lcm",
    "math",
    "Least common multiple",
    TwoNumbers,
    .int,
    &[_][]const u8{
        "lcm(12, 18) -> 36",
        "lcm(4, 6) -> 12",
    },
    lcm_impl,
);

pub const isprime = DefineFunction(
    "isprime",
    "math",
    "Check if number is prime (returns 1 or 0)",
    OneNumber,
    .int,
    &[_][]const u8{
        "isprime(17) -> 1",
        "isprime(10) -> 0",
    },
    isprime_impl,
);

pub const nextprime = DefineFunction(
    "nextprime",
    "math",
    "Find next prime number after n",
    OneNumber,
    .int,
    &[_][]const u8{
        "nextprime(10) -> 11",
        "nextprime(20) -> 23",
    },
    nextprime_impl,
>>>>>>> 44216b23d36fa487e45525341b2478b089f83d67
);
