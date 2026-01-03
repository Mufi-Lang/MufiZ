const std = @import("std");
const Value = @import("../value.zig").Value;
const stdlib_v2 = @import("../stdlib_v2.zig");
const DefineFunction = stdlib_v2.DefineFunction;
const ParamSpec = stdlib_v2.ParamSpec;
const ParamType = stdlib_v2.ParamType;
const NoParams = stdlib_v2.NoParams;
const OneNumber = stdlib_v2.OneNumber;

// Implementation functions

fn now_impl(argc: i32, args: [*]Value) Value {
    _ = argc;
    _ = args;
    const time = std.time.timestamp();
    return Value.init_int(@intCast(time));
}

fn now_ns_impl(argc: i32, args: [*]Value) Value {
    _ = argc;
    _ = args;
    const time = std.time.nanoTimestamp();
    return Value.init_double(@floatFromInt(time));
}

fn now_ms_impl(argc: i32, args: [*]Value) Value {
    _ = argc;
    _ = args;
    const time = std.time.milliTimestamp();
    return Value.init_double(@floatFromInt(time));
}

fn now_us_impl(argc: i32, args: [*]Value) Value {
    _ = argc;
    _ = args;
    const time = std.time.microTimestamp();
    return Value.init_double(@floatFromInt(time));
}

fn sleep_impl(argc: i32, args: [*]Value) Value {
    _ = argc;
    const seconds = args[0].as_num_double();
    const nanoseconds = @as(u64, @intFromFloat(seconds * 1_000_000_000));
    std.Thread.sleep(nanoseconds);
    return Value.init_nil();
}

fn sleep_ms_impl(argc: i32, args: [*]Value) Value {
    _ = argc;
    const milliseconds = args[0].as_num_double();
    const nanoseconds = @as(u64, @intFromFloat(milliseconds * 1_000_000));
    std.Thread.sleep(nanoseconds);
    return Value.init_nil();
}

fn sleep_us_impl(argc: i32, args: [*]Value) Value {
    _ = argc;
    const microseconds = args[0].as_num_double();
    const nanoseconds = @as(u64, @intFromFloat(microseconds * 1_000));
    std.Thread.sleep(nanoseconds);
    return Value.init_nil();
}

fn time_diff_impl(argc: i32, args: [*]Value) Value {
    _ = argc;
    const start_time = args[0].as_num_double();
    const end_time = args[1].as_num_double();
    return Value.init_double(end_time - start_time);
}

// Public function wrappers with metadata

pub const now = DefineFunction(
    "now",
    "time",
    "Get current Unix timestamp in seconds",
    NoParams,
    .int,
    &[_][]const u8{
        "now() -> 1703123456",
    },
    now_impl,
);

pub const now_ns = DefineFunction(
    "now_ns",
    "time",
    "Get current timestamp in nanoseconds",
    NoParams,
    .double,
    &[_][]const u8{
        "now_ns() -> 1703123456789123456.0",
    },
    now_ns_impl,
);

pub const now_ms = DefineFunction(
    "now_ms",
    "time",
    "Get current timestamp in milliseconds",
    NoParams,
    .double,
    &[_][]const u8{
        "now_ms() -> 1703123456789.0",
    },
    now_ms_impl,
);

pub const now_us = DefineFunction(
    "now_us",
    "time",
    "Get current timestamp in microseconds",
    NoParams,
    .double,
    &[_][]const u8{
        "now_us() -> 1703123456789123.0",
    },
    now_us_impl,
);

pub const sleep = DefineFunction(
    "sleep",
    "time",
    "Sleep for specified number of seconds",
    OneNumber,
    .nil,
    &[_][]const u8{
        "sleep(1.5) -> nil  // Sleeps for 1.5 seconds",
        "sleep(0.1) -> nil  // Sleeps for 100 milliseconds",
    },
    sleep_impl,
);

pub const sleep_ms = DefineFunction(
    "sleep_ms",
    "time",
    "Sleep for specified number of milliseconds",
    OneNumber,
    .nil,
    &[_][]const u8{
        "sleep_ms(500) -> nil  // Sleeps for 500 milliseconds",
        "sleep_ms(1000) -> nil  // Sleeps for 1 second",
    },
    sleep_ms_impl,
);

pub const sleep_us = DefineFunction(
    "sleep_us",
    "time",
    "Sleep for specified number of microseconds",
    OneNumber,
    .nil,
    &[_][]const u8{
        "sleep_us(500000) -> nil  // Sleeps for 500 milliseconds",
        "sleep_us(1000000) -> nil  // Sleeps for 1 second",
    },
    sleep_us_impl,
);

pub const time_diff = DefineFunction(
    "time_diff",
    "time",
    "Calculate the difference between two timestamps",
    &[_]ParamSpec{
        .{ .name = "start", .type = .number },
        .{ .name = "end", .type = .number },
    },
    .double,
    &[_][]const u8{
        "time_diff(1000, 2000) -> 1000.0",
        "time_diff(now_ms(), now_ms() + 500) -> ~500.0",
    },
    time_diff_impl,
);
