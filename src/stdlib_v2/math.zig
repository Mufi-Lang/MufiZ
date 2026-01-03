const std = @import("std");
const Value = @import("../value.zig").Value;
const stdlib_v2 = @import("../stdlib_v2.zig");
const DefineFunction = stdlib_v2.DefineFunction;
const ParamSpec = stdlib_v2.ParamSpec;
const ParamType = stdlib_v2.ParamType;
const NoParams = stdlib_v2.NoParams;
const OneNumber = stdlib_v2.OneNumber;
const TwoNumbers = stdlib_v2.TwoNumbers;

const Prng = std.Random.Xoshiro256;

// Internal implementation functions (no validation needed here)
fn ln_impl(argc: i32, args: [*]Value) Value {
    const double = args[0].as_num_double();
    return Value.init_double(@log(double));
}

fn log2_impl(argc: i32, args: [*]Value) Value {
    const double = args[0].as_num_double();
    return Value.init_double(@log2(double));
}

fn log10_impl(argc: i32, args: [*]Value) Value {
    const double = args[0].as_num_double();
    return Value.init_double(@log10(double));
}

fn pi_impl(argc: i32, args: [*]Value) Value {
    _ = args;
    _ = argc;
    return Value.init_double(std.math.pi);
}

fn exp_impl(argc: i32, args: [*]Value) Value {
    const double = args[0].as_num_double();
    return Value.init_double(@exp(double));
}

fn sin_impl(argc: i32, args: [*]Value) Value {
    const double = args[0].as_num_double();
    return Value.init_double(@sin(double));
}

fn cos_impl(argc: i32, args: [*]Value) Value {
    const double = args[0].as_num_double();
    return Value.init_double(@cos(double));
}

fn tan_impl(argc: i32, args: [*]Value) Value {
    const double = args[0].as_num_double();
    return Value.init_double(@tan(double));
}

fn asin_impl(argc: i32, args: [*]Value) Value {
    const double = args[0].as_num_double();
    return Value.init_double(std.math.asin(double));
}

fn acos_impl(argc: i32, args: [*]Value) Value {
    const double = args[0].as_num_double();
    return Value.init_double(std.math.acos(double));
}

fn atan_impl(argc: i32, args: [*]Value) Value {
    const double = args[0].as_num_double();
    return Value.init_double(std.math.atan(double));
}

fn complex_impl(argc: i32, args: [*]Value) Value {
    const r = args[0].as_num_double();
    const i = args[1].as_num_double();
    return Value.init_complex(.{ .r = r, .i = i });
}

fn abs_impl(argc: i32, args: [*]Value) Value {
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
        else => return stdlib_v2.stdlib_error("abs() expects a Numeric Type!", .{}),
    }
}

fn phase_impl(argc: i32, args: [*]Value) Value {
    const c = args[0].as_complex();
    return Value.init_double(std.math.atan2(c.i, c.r));
}

fn rand_impl(argc: i32, args: [*]Value) Value {
    _ = args;
    _ = argc;
    var seed_bytes: [8]u8 = undefined;
    std.crypto.random.bytes(&seed_bytes);
    const seed = std.mem.readInt(u64, &seed_bytes, .little);
    var rng = Prng.init(seed);
    const r = rng.random().float(f64);
    return Value.init_double(r);
}

fn randn_impl(argc: i32, args: [*]Value) Value {
    _ = args;
    _ = argc;
    var seed_bytes: [8]u8 = undefined;
    std.crypto.random.bytes(&seed_bytes);
    const seed = std.mem.readInt(u64, &seed_bytes, .little);
    var rng = Prng.init(seed);
    const r = rng.random().floatNorm(f64);
    return Value.init_double(r);
}

fn pow_impl(argc: i32, args: [*]Value) Value {
    const base = args[0].as_num_double();
    const exponent = args[1].as_num_double();
    return Value.init_double(std.math.pow(f64, base, exponent));
}

fn sqrt_impl(argc: i32, args: [*]Value) Value {
    const double = args[0].as_num_double();
    return Value.init_double(@sqrt(double));
}

fn ceil_impl(argc: i32, args: [*]Value) Value {
    const double = args[0].as_num_double();
    return Value.init_int(@intFromFloat(@ceil(double)));
}

fn floor_impl(argc: i32, args: [*]Value) Value {
    const double = args[0].as_num_double();
    return Value.init_int(@intFromFloat(@floor(double)));
}

fn round_impl(argc: i32, args: [*]Value) Value {
    const double = args[0].as_num_double();
    return Value.init_int(@intFromFloat(@round(double)));
}

fn max_impl(argc: i32, args: [*]Value) Value {
    const a = args[0].as_num_double();
    const b = args[1].as_num_double();
    return Value.init_double(@max(a, b));
}

fn min_impl(argc: i32, args: [*]Value) Value {
    const a = args[0].as_num_double();
    const b = args[1].as_num_double();
    return Value.init_double(@min(a, b));
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
