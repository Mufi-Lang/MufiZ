const std = @import("std");
const value_h = @import("../value.zig");
const Value = value_h.Value;
const obj_h = @import("../object.zig");
const Matrix = obj_h.Matrix;

/// Matrix creation functions (Octave-compatible)
/// Create identity matrix: eye(n) or eye(m, n)
pub fn nativeEye(arg_count: i32, args: [*]Value) Value {
    if (arg_count == 1) {
        if (!args[0].is_int()) {
            std.debug.print("eye: argument must be an integer\n", .{});
            return Value.init_nil();
        }
        const n = @as(usize, @intCast(args[0].as_int()));
        const matrix = Matrix.eye(n);
        return Value.init_obj(@ptrCast(matrix));
    } else if (arg_count == 2) {
        if (!args[0].is_int() or !args[1].is_int()) {
            std.debug.print("eye: arguments must be integers\n", .{});
            return Value.init_nil();
        }
        const rows = @as(usize, @intCast(args[0].as_int()));
        const cols = @as(usize, @intCast(args[1].as_int()));
        const matrix = Matrix.eye(@min(rows, cols));
        if (rows != cols) {
            // Create rectangular identity matrix
            const result = Matrix.zeros(rows, cols);
            const min_dim = @min(rows, cols);
            for (0..min_dim) |i| {
                result.set(i, i, 1.0);
            }
            return Value.init_obj(@ptrCast(result));
        }
        return Value.init_obj(@ptrCast(matrix));
    } else {
        std.debug.print("eye: wrong number of arguments\n", .{});
        return Value.init_nil();
    }
}

/// Create matrix of ones: ones(m, n)
pub fn nativeOnes(arg_count: i32, args: [*]Value) Value {
    if (arg_count == 1) {
        if (!args[0].is_int()) {
            std.debug.print("ones: argument must be an integer\n", .{});
            return Value.init_nil();
        }
        const n = @as(usize, @intCast(args[0].as_int()));
        const matrix = Matrix.ones(n, n);
        return Value.init_obj(@ptrCast(matrix));
    } else if (arg_count == 2) {
        if (!args[0].is_int() or !args[1].is_int()) {
            std.debug.print("ones: arguments must be integers\n", .{});
            return Value.init_nil();
        }
        const rows = @as(usize, @intCast(args[0].as_int()));
        const cols = @as(usize, @intCast(args[1].as_int()));
        const matrix = Matrix.ones(rows, cols);
        return Value.init_obj(@ptrCast(matrix));
    } else {
        std.debug.print("ones: wrong number of arguments\n", .{});
        return Value.init_nil();
    }
}

/// Create matrix of zeros: zeros(m, n)
pub fn nativeZeros(arg_count: i32, args: [*]Value) Value {
    if (arg_count == 1) {
        if (!args[0].is_int()) {
            std.debug.print("zeros: argument must be an integer\n", .{});
            return Value.init_nil();
        }
        const n = @as(usize, @intCast(args[0].as_int()));
        const matrix = Matrix.zeros(n, n);
        return Value.init_obj(@ptrCast(matrix));
    } else if (arg_count == 2) {
        if (!args[0].is_int() or !args[1].is_int()) {
            std.debug.print("zeros: arguments must be integers\n", .{});
            return Value.init_nil();
        }
        const rows = @as(usize, @intCast(args[0].as_int()));
        const cols = @as(usize, @intCast(args[1].as_int()));
        const matrix = Matrix.zeros(rows, cols);
        return Value.init_obj(@ptrCast(matrix));
    } else {
        std.debug.print("zeros: wrong number of arguments\n", .{});
        return Value.init_nil();
    }
}

/// Create random matrix: rand(m, n)
pub fn nativeRand(arg_count: i32, args: [*]Value) Value {
    if (arg_count == 1) {
        if (!args[0].is_int()) {
            std.debug.print("rand: argument must be an integer\n", .{});
            return Value.init_nil();
        }
        const n = @as(usize, @intCast(args[0].as_int()));
        const matrix = Matrix.rand(n, n);
        return Value.init_obj(@ptrCast(matrix));
    } else if (arg_count == 2) {
        if (!args[0].is_int() or !args[1].is_int()) {
            std.debug.print("rand: arguments must be integers\n", .{});
            return Value.init_nil();
        }
        const rows = @as(usize, @intCast(args[0].as_int()));
        const cols = @as(usize, @intCast(args[1].as_int()));
        const matrix = Matrix.rand(rows, cols);
        return Value.init_obj(@ptrCast(matrix));
    } else {
        std.debug.print("rand: wrong number of arguments\n", .{});
        return Value.init_nil();
    }
}

/// Create random normal matrix: randn(m, n)
pub fn nativeRandn(arg_count: i32, args: [*]Value) Value {
    if (arg_count == 1) {
        if (!args[0].is_int()) {
            std.debug.print("randn: argument must be an integer\n", .{});
            return Value.init_nil();
        }
        const n = @as(usize, @intCast(args[0].as_int()));
        const matrix = Matrix.randn(n, n);
        return Value.init_obj(@ptrCast(matrix));
    } else if (arg_count == 2) {
        if (!args[0].is_int() or !args[1].is_int()) {
            std.debug.print("randn: arguments must be integers\n", .{});
            return Value.init_nil();
        }
        const rows = @as(usize, @intCast(args[0].as_int()));
        const cols = @as(usize, @intCast(args[1].as_int()));
        const matrix = Matrix.randn(rows, cols);
        return Value.init_obj(@ptrCast(matrix));
    } else {
        std.debug.print("randn: wrong number of arguments\n", .{});
        return Value.init_nil();
    }
}

/// Matrix transpose: transpose(A) or A'
pub fn nativeTranspose(arg_count: i32, args: [*]Value) Value {
    if (arg_count != 1) {
        std.debug.print("transpose: wrong number of arguments\n", .{});
        return Value.init_nil();
    }

    if (!args[0].is_matrix()) {
        std.debug.print("transpose: argument must be a matrix\n", .{});
        return Value.init_nil();
    }

    const matrix = args[0].as_matrix();
    const result = matrix.transpose();
    return Value.init_obj(@ptrCast(result));
}

/// Matrix determinant: det(A)
pub fn nativeDet(arg_count: i32, args: [*]Value) Value {
    if (arg_count != 1) {
        std.debug.print("det: wrong number of arguments\n", .{});
        return Value.init_nil();
    }

    if (!args[0].is_matrix()) {
        std.debug.print("det: argument must be a matrix\n", .{});
        return Value.init_nil();
    }

    const matrix = args[0].as_matrix();
    const det_val = matrix.det();

    if (det_val == null) {
        std.debug.print("det: matrix must be square\n", .{});
        return Value.init_nil();
    }

    return Value.init_double(det_val.?);
}

/// Matrix inverse: inv(A)
pub fn nativeInv(arg_count: i32, args: [*]Value) Value {
    if (arg_count != 1) {
        std.debug.print("inv: wrong number of arguments\n", .{});
        return Value.init_nil();
    }

    if (!args[0].is_matrix()) {
        std.debug.print("inv: argument must be a matrix\n", .{});
        return Value.init_nil();
    }

    const matrix = args[0].as_matrix();
    const result = matrix.inv();

    if (result == null) {
        std.debug.print("inv: matrix is singular or not square\n", .{});
        return Value.init_nil();
    }

    return Value.init_obj(@ptrCast(result.?));
}

/// Matrix trace: trace(A)
pub fn nativeTrace(arg_count: i32, args: [*]Value) Value {
    if (arg_count != 1) {
        std.debug.print("trace: wrong number of arguments\n", .{});
        return Value.init_nil();
    }

    if (!args[0].is_matrix()) {
        std.debug.print("trace: argument must be a matrix\n", .{});
        return Value.init_nil();
    }

    const matrix = args[0].as_matrix();
    const trace_val = matrix.trace();
    return Value.init_double(trace_val);
}

/// Matrix size: size(A)
pub fn nativeSize(arg_count: i32, args: [*]Value) Value {
    if (arg_count != 1) {
        std.debug.print("size: wrong number of arguments\n", .{});
        return Value.init_nil();
    }

    if (!args[0].is_matrix()) {
        std.debug.print("size: argument must be a matrix\n", .{});
        return Value.init_nil();
    }

    const matrix = args[0].as_matrix();
    const dims = matrix.size();

    // Return as a 1x2 matrix [rows, cols]
    const result = Matrix.init(1, 2);
    result.set(0, 0, @floatFromInt(dims[0]));
    result.set(0, 1, @floatFromInt(dims[1]));
    return Value.init_obj(@ptrCast(result));
}

/// Matrix norm: norm(A) (Frobenius norm)
pub fn nativeNorm(arg_count: i32, args: [*]Value) Value {
    if (arg_count != 1) {
        std.debug.print("norm: wrong number of arguments\n", .{});
        return Value.init_nil();
    }

    if (!args[0].is_matrix()) {
        std.debug.print("norm: argument must be a matrix\n", .{});
        return Value.init_nil();
    }

    const matrix = args[0].as_matrix();
    const norm_val = matrix.frobeniusNorm();
    return Value.init_double(norm_val);
}

/// Matrix element access: matrix(row, col)
pub fn nativeMatrixGet(arg_count: i32, args: [*]Value) Value {
    if (arg_count != 3) {
        std.debug.print("matrix_get: wrong number of arguments\n", .{});
        return Value.init_nil();
    }

    if (!args[0].is_matrix() or !args[1].is_int() or !args[2].is_int()) {
        std.debug.print("matrix_get: invalid arguments\n", .{});
        return Value.init_nil();
    }

    const matrix = args[0].as_matrix();
    const row = @as(usize, @intCast(args[1].as_int() - 1)); // Convert to 0-based
    const col = @as(usize, @intCast(args[2].as_int() - 1)); // Convert to 0-based

    if (row >= matrix.rows or col >= matrix.cols) {
        std.debug.print("matrix_get: index out of bounds\n", .{});
        return Value.init_nil();
    }

    const value = matrix.get(row, col);
    return Value.init_double(value);
}

/// Matrix element assignment: matrix(row, col) = value
pub fn nativeMatrixSet(arg_count: i32, args: [*]Value) Value {
    if (arg_count != 4) {
        std.debug.print("matrix_set: wrong number of arguments\n", .{});
        return Value.init_nil();
    }

    if (!args[0].is_matrix() or !args[1].is_int() or !args[2].is_int()) {
        std.debug.print("matrix_set: invalid arguments\n", .{});
        return Value.init_nil();
    }

    const matrix = args[0].as_matrix();
    const row = @as(usize, @intCast(args[1].as_int() - 1)); // Convert to 0-based
    const col = @as(usize, @intCast(args[2].as_int() - 1)); // Convert to 0-based

    if (row >= matrix.rows or col >= matrix.cols) {
        std.debug.print("matrix_set: index out of bounds\n", .{});
        return Value.init_nil();
    }

    var value: f64 = 0.0;
    if (args[3].is_double()) {
        value = args[3].as_double();
    } else if (args[3].is_int()) {
        value = @floatFromInt(args[3].as_int());
    } else {
        std.debug.print("matrix_set: value must be numeric\n", .{});
        return Value.init_nil();
    }

    matrix.set(row, col, value);
    return args[0]; // Return the matrix
}

/// Horizontal concatenation: horzcat(A, B) or [A B]
pub fn nativeHorzcat(arg_count: i32, args: [*]Value) Value {
    if (arg_count != 2) {
        std.debug.print("horzcat: wrong number of arguments\n", .{});
        return Value.init_nil();
    }

    if (!args[0].is_matrix() or !args[1].is_matrix()) {
        std.debug.print("horzcat: arguments must be matrices\n", .{});
        return Value.init_nil();
    }

    const matrix1 = args[0].as_matrix();
    const matrix2 = args[1].as_matrix();
    const result = matrix1.horzcat(matrix2);

    if (result == null) {
        std.debug.print("horzcat: matrices must have the same number of rows\n", .{});
        return Value.init_nil();
    }

    return Value.init_obj(@ptrCast(result.?));
}

/// Vertical concatenation: vertcat(A, B) or [A; B]
pub fn nativeVertcat(arg_count: i32, args: [*]Value) Value {
    if (arg_count != 2) {
        std.debug.print("vertcat: wrong number of arguments\n", .{});
        return Value.init_nil();
    }

    if (!args[0].is_matrix() or !args[1].is_matrix()) {
        std.debug.print("vertcat: arguments must be matrices\n", .{});
        return Value.init_nil();
    }

    const matrix1 = args[0].as_matrix();
    const matrix2 = args[1].as_matrix();
    const result = matrix1.vertcat(matrix2);

    if (result == null) {
        std.debug.print("vertcat: matrices must have the same number of columns\n", .{});
        return Value.init_nil();
    }

    return Value.init_obj(@ptrCast(result.?));
}

/// Create matrix from array data: matrix(data, rows, cols)
pub fn nativeMatrix(arg_count: i32, args: [*]Value) Value {
    if (arg_count != 3) {
        std.debug.print("matrix: wrong number of arguments\n", .{});
        return Value.init_nil();
    }

    if (!args[0].is_fvec() or !args[1].is_int() or !args[2].is_int()) {
        std.debug.print("matrix: invalid arguments (expected vector, rows, cols)\n", .{});
        return Value.init_nil();
    }

    const vector = args[0].as_fvec();
    const rows = @as(usize, @intCast(args[1].as_int()));
    const cols = @as(usize, @intCast(args[2].as_int()));

    if (vector.count != rows * cols) {
        std.debug.print("matrix: vector size does not match matrix dimensions\n", .{});
        return Value.init_nil();
    }

    const matrix = Matrix.init(rows, cols);

    // Copy data from vector to matrix (column-major order)
    for (0..rows) |i| {
        for (0..cols) |j| {
            const vector_index = j * rows + i; // Column-major indexing
            matrix.set(i, j, vector.data[vector_index]);
        }
    }

    return Value.init_obj(@ptrCast(matrix));
}

/// Reshape matrix: reshape(A, m, n)
pub fn nativeReshape(arg_count: i32, args: [*]Value) Value {
    if (arg_count != 3) {
        std.debug.print("reshape: wrong number of arguments\n", .{});
        return Value.init_nil();
    }

    if (!args[0].is_matrix() or !args[1].is_int() or !args[2].is_int()) {
        std.debug.print("reshape: invalid arguments\n", .{});
        return Value.init_nil();
    }

    const matrix = args[0].as_matrix();
    const new_rows = @as(usize, @intCast(args[1].as_int()));
    const new_cols = @as(usize, @intCast(args[2].as_int()));

    if (matrix.rows * matrix.cols != new_rows * new_cols) {
        std.debug.print("reshape: number of elements must remain the same\n", .{});
        return Value.init_nil();
    }

    const result = Matrix.init(new_rows, new_cols);

    // Copy data maintaining column-major order
    for (0..matrix.rows * matrix.cols) |i| {
        const old_pos = matrix.indexToRowCol(i);
        const new_i = i % new_rows;
        const new_j = i / new_rows;
        result.set(new_i, new_j, matrix.get(old_pos.row, old_pos.col));
    }

    return Value.init_obj(@ptrCast(result));
}

/// Matrix RREF: rref(A)
pub fn nativeRref(arg_count: i32, args: [*]Value) Value {
    if (arg_count != 1) {
        std.debug.print("rref: wrong number of arguments\n", .{});
        return Value.init_nil();
    }

    if (!args[0].is_matrix()) {
        std.debug.print("rref: argument must be a matrix\n", .{});
        return Value.init_nil();
    }

    const matrix = args[0].as_matrix();
    const result = matrix.rref();
    return Value.init_obj(@ptrCast(result));
}

/// Matrix rank: rank(A)
pub fn nativeRank(arg_count: i32, args: [*]Value) Value {
    if (arg_count != 1) {
        std.debug.print("rank: wrong number of arguments\n", .{});
        return Value.init_nil();
    }

    if (!args[0].is_matrix()) {
        std.debug.print("rank: argument must be a matrix\n", .{});
        return Value.init_nil();
    }

    const matrix = args[0].as_matrix();
    const rank_val = matrix.rank();
    return Value.init_int(@intCast(rank_val));
}
