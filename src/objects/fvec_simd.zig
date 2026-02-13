const std = @import("std");
const simd_utils = @import("../simd_utils.zig");

/// Helper module for FloatVector SIMD operations
/// This centralizes all SIMD logic for FloatVector operations
/// Binary operation on two float vectors using SIMD
pub fn binaryOp(
    result_data: []f64,
    a_data: []const f64,
    b_data: []const f64,
    comptime op: BinaryOperation,
) void {
    const len = @min(@min(result_data.len, a_data.len), b_data.len);

    switch (op) {
        .add => simd_utils.SimdF64.add(result_data[0..len], a_data[0..len], b_data[0..len]),
        .sub => simd_utils.SimdF64.sub(result_data[0..len], a_data[0..len], b_data[0..len]),
        .mul => simd_utils.SimdF64.mul(result_data[0..len], a_data[0..len], b_data[0..len]),
        .div => simd_utils.SimdF64.div(result_data[0..len], a_data[0..len], b_data[0..len]),
    }
}

pub const BinaryOperation = enum {
    add,
    sub,
    mul,
    div,
};

/// Scalar operation on a float vector using SIMD
pub fn scalarOp(
    result_data: []f64,
    a_data: []const f64,
    scalar: f64,
    comptime op: ScalarOperation,
) void {
    const len = @min(result_data.len, a_data.len);

    switch (op) {
        .scale => simd_utils.SimdF64.scale(result_data[0..len], a_data[0..len], scalar),
        .add => simd_utils.SimdF64.addScalar(result_data[0..len], a_data[0..len], scalar),
        .sub => {
            // Subtract scalar: result[i] = a[i] - scalar
            const neg_scalar = -scalar;
            simd_utils.SimdF64.addScalar(result_data[0..len], a_data[0..len], neg_scalar);
        },
        .div => {
            // Divide by scalar: result[i] = a[i] / scalar
            const inv_scalar = 1.0 / scalar;
            simd_utils.SimdF64.scale(result_data[0..len], a_data[0..len], inv_scalar);
        },
    }
}

pub const ScalarOperation = enum {
    scale,
    add,
    sub,
    div,
};

/// Unary operation on a float vector
pub fn unaryOp(
    result_data: []f64,
    a_data: []const f64,
    comptime op: UnaryOperation,
) void {
    const len = @min(result_data.len, a_data.len);

    // For transcendental functions, we can't use pure SIMD vectorization
    // because Zig doesn't have vectorized sin/cos/etc.
    // But we can still optimize by processing multiple elements at once
    // and letting the compiler auto-vectorize when possible

    if (!simd_utils.shouldUseSIMD(len)) {
        scalarUnaryOp(result_data[0..len], a_data[0..len], op);
        return;
    }

    // Process in chunks for better cache locality and potential auto-vectorization
    const chunk_size = simd_utils.SimdF64.getVectorLength();
    var i: usize = 0;

    while (i + chunk_size <= len) : (i += chunk_size) {
        for (0..chunk_size) |j| {
            const idx = i + j;
            result_data[idx] = applyUnaryOp(a_data[idx], op);
        }
    }

    // Handle remaining elements
    while (i < len) : (i += 1) {
        result_data[i] = applyUnaryOp(a_data[i], op);
    }
}

pub const UnaryOperation = enum {
    sin,
    cos,
    sqrt,
    abs,
    exp,
    log,
};

fn applyUnaryOp(value: f64, comptime op: UnaryOperation) f64 {
    return switch (op) {
        .sin => @sin(value),
        .cos => @cos(value),
        .sqrt => @sqrt(value),
        .abs => @abs(value),
        .exp => @exp(value),
        .log => @log(value),
    };
}

fn scalarUnaryOp(result_data: []f64, a_data: []const f64, comptime op: UnaryOperation) void {
    for (0..result_data.len) |i| {
        result_data[i] = applyUnaryOp(a_data[i], op);
    }
}

/// Power operation: result[i] = a[i] ^ exponent
pub fn powOp(result_data: []f64, a_data: []const f64, exponent: f64) void {
    const len = @min(result_data.len, a_data.len);

    if (!simd_utils.shouldUseSIMD(len)) {
        for (0..len) |i| {
            result_data[i] = std.math.pow(f64, a_data[i], exponent);
        }
        return;
    }

    // Process in chunks for better cache locality
    const chunk_size = simd_utils.SimdF64.getVectorLength();
    var i: usize = 0;

    while (i + chunk_size <= len) : (i += chunk_size) {
        for (0..chunk_size) |j| {
            const idx = i + j;
            result_data[idx] = std.math.pow(f64, a_data[idx], exponent);
        }
    }

    // Handle remaining elements
    while (i < len) : (i += 1) {
        result_data[i] = std.math.pow(f64, a_data[i], exponent);
    }
}

/// Comparison operation returning 1.0 or 0.0
pub fn compareOp(
    result_data: []f64,
    a_data: []const f64,
    b_data: []const f64,
    comptime op: CompareOperation,
) void {
    const len = @min(@min(result_data.len, a_data.len), b_data.len);

    if (!simd_utils.shouldUseSIMD(len)) {
        scalarCompareOp(result_data[0..len], a_data[0..len], b_data[0..len], op);
        return;
    }

    // SIMD comparison with mask conversion
    const vec_len = simd_utils.SimdF64.getVectorLength();
    const VecType = @Vector(vec_len, f64);

    const vec_iterations = len / vec_len;
    var i: usize = 0;

    while (i < vec_iterations) : (i += 1) {
        const offset = i * vec_len;
        const vec_a: VecType = a_data[offset..][0..vec_len].*;
        const vec_b: VecType = b_data[offset..][0..vec_len].*;

        // Perform comparison
        const mask = switch (op) {
            .greater_than => vec_a > vec_b,
            .less_than => vec_a < vec_b,
            .greater_equal => vec_a >= vec_b,
            .less_equal => vec_a <= vec_b,
            .equal => vec_a == vec_b,
            .not_equal => vec_a != vec_b,
        };

        // Convert boolean mask to 1.0/0.0
        for (0..vec_len) |j| {
            result_data[offset + j] = if (mask[j]) 1.0 else 0.0;
        }
    }

    // Handle remaining elements
    const remaining_start = vec_iterations * vec_len;
    scalarCompareOp(
        result_data[remaining_start..len],
        a_data[remaining_start..len],
        b_data[remaining_start..len],
        op,
    );
}

pub const CompareOperation = enum {
    greater_than,
    less_than,
    greater_equal,
    less_equal,
    equal,
    not_equal,
};

fn scalarCompareOp(
    result_data: []f64,
    a_data: []const f64,
    b_data: []const f64,
    comptime op: CompareOperation,
) void {
    for (0..result_data.len) |i| {
        const cmp_result = switch (op) {
            .greater_than => a_data[i] > b_data[i],
            .less_than => a_data[i] < b_data[i],
            .greater_equal => a_data[i] >= b_data[i],
            .less_equal => a_data[i] <= b_data[i],
            .equal => a_data[i] == b_data[i],
            .not_equal => a_data[i] != b_data[i],
        };
        result_data[i] = if (cmp_result) 1.0 else 0.0;
    }
}

/// Sum all elements using SIMD
pub fn sum(data: []const f64) f64 {
    return simd_utils.SimdF64.sum(data);
}

/// Compute mean (simple wrapper around sum)
pub fn mean(data: []const f64) f64 {
    if (data.len == 0) return 0.0;
    return sum(data) / @as(f64, @floatFromInt(data.len));
}

/// Compute variance using SIMD
pub fn variance(data: []const f64, mean_val: f64) f64 {
    return simd_utils.SimdF64.variance(data, mean_val);
}
