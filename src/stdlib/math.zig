const std = @import("std");
const conv = @import("../conv.zig");
const Value = @cImport(@cInclude("value.h")).Value;
const stdlib_error = @import("../stdlib.zig").stdlib_error;

pub fn log2(argc: c_int, args: [*c]Value) callconv(.C) Value {
    if (argc > 1 or !conv.is_double(args[0])) return stdlib_error("log2() expects a double!", args[0]);
    const double = conv.as_double(args[0]);
    return conv.double_val(@log2(double));
}
