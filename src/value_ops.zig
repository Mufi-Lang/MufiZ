/// MufiZ Value Operations Optimization Module
///
/// This module provides optimized implementations of arithmetic operations
/// for the Value type system. It uses lookup tables and fast-path optimizations
/// to reduce the overhead of nested switch statements in hot paths.
///
/// ## Design Goals:
/// - Reduce nested switch complexity in arithmetic operations
/// - Provide fast paths for common type combinations
/// - Maintain type safety and error handling
/// - Keep code maintainable and extensible

const std = @import("std");
const value_h = @import("value.zig");
const Value = value_h.Value;
const ValueType = value_h.ValueType;
const Complex = value_h.Complex;

/// Fast path: Add two integers
/// Returns null if types don't match, allowing fallback to general path
pub inline fn addIntInt(a: Value, b: Value) ?Value {
    if (a.type == .VAL_INT and b.type == .VAL_INT) {
        return Value.init_int(a.as.num_int + b.as.num_int);
    }
    return null;
}

/// Fast path: Add two doubles
/// Returns null if types don't match, allowing fallback to general path
pub inline fn addDoubleDouble(a: Value, b: Value) ?Value {
    if (a.type == .VAL_DOUBLE and b.type == .VAL_DOUBLE) {
        return Value.init_double(a.as.num_double + b.as.num_double);
    }
    return null;
}

/// Fast path: Multiply two integers
/// Returns null if types don't match, allowing fallback to general path
pub inline fn mulIntInt(a: Value, b: Value) ?Value {
    if (a.type == .VAL_INT and b.type == .VAL_INT) {
        return Value.init_int(a.as.num_int * b.as.num_int);
    }
    return null;
}

/// Fast path: Multiply two doubles
/// Returns null if types don't match, allowing fallback to general path
pub inline fn mulDoubleDouble(a: Value, b: Value) ?Value {
    if (a.type == .VAL_DOUBLE and b.type == .VAL_DOUBLE) {
        return Value.init_double(a.as.num_double * b.as.num_double);
    }
    return null;
}

/// Fast path: Divide two integers (result is double)
/// Returns null if types don't match, allowing fallback to general path
pub inline fn divIntInt(a: Value, b: Value) ?Value {
    if (a.type == .VAL_INT and b.type == .VAL_INT) {
        const af = @as(f64, @floatFromInt(a.as.num_int));
        const bf = @as(f64, @floatFromInt(b.as.num_int));
        return Value.init_double(af / bf);
    }
    return null;
}

/// Fast path: Divide two doubles
/// Returns null if types don't match, allowing fallback to general path
pub inline fn divDoubleDouble(a: Value, b: Value) ?Value {
    if (a.type == .VAL_DOUBLE and b.type == .VAL_DOUBLE) {
        return Value.init_double(a.as.num_double / b.as.num_double);
    }
    return null;
}

/// Convert a value to f64 for numeric operations
/// This is an optimized version that avoids the switch when type is known
pub inline fn toDouble(val: Value) f64 {
    return switch (val.type) {
        .VAL_INT => @as(f64, @floatFromInt(val.as.num_int)),
        .VAL_DOUBLE => val.as.num_double,
        else => unreachable,
    };
}

/// Type combination encoding for dispatch
/// Encodes two ValueTypes into a single u16 for fast lookup
pub inline fn encodeTypes(a: ValueType, b: ValueType) u16 {
    const a_val: u16 = @intCast(@intFromEnum(a));
    const b_val: u16 = @intCast(@intFromEnum(b));
    return (a_val << 8) | b_val;
}

/// Check if both values are primitive numeric types (int or double)
/// This enables fast-path optimizations
pub inline fn bothPrimNumeric(a: Value, b: Value) bool {
    return (a.type == .VAL_INT or a.type == .VAL_DOUBLE) and
           (b.type == .VAL_INT or b.type == .VAL_DOUBLE);
}

/// Add two complex numbers
pub inline fn addComplex(a: Complex, b: Complex) Complex {
    return .{
        .r = a.r + b.r,
        .i = a.i + b.i,
    };
}

/// Multiply two complex numbers
pub inline fn mulComplex(a: Complex, b: Complex) Complex {
    return .{
        .r = a.r * b.r - a.i * b.i,
        .i = a.r * b.i + a.i * b.r,
    };
}

/// Divide two complex numbers
pub inline fn divComplex(a: Complex, b: Complex) Complex {
    const denominator = b.r * b.r + b.i * b.i;
    return .{
        .r = (a.r * b.r + a.i * b.i) / denominator,
        .i = (a.i * b.r - a.r * b.i) / denominator,
    };
}

/// Scale a complex number by a real scalar
pub inline fn scaleComplex(c: Complex, scalar: f64) Complex {
    return .{
        .r = c.r * scalar,
        .i = c.i * scalar,
    };
}
