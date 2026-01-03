const std = @import("std");
const stdlib_v2 = @import("../stdlib_v2.zig");
const Value = @import("../value.zig").Value;
const obj_h = @import("../object.zig");
const Matrix = obj_h.Matrix;

const DefineFunction = stdlib_v2.DefineFunction;
const ParamSpec = stdlib_v2.ParamSpec;

// === Implementation Functions ===

fn eye_impl(argc: i32, args: [*]Value) Value {
    if (argc == 1) {
        const n = @as(usize, @intCast(args[0].as_int()));
        const matrix = Matrix.eye(n);
        return Value.init_obj(@ptrCast(matrix));
    } else {
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
    }
}

fn ones_impl(argc: i32, args: [*]Value) Value {
    if (argc == 1) {
        const n = @as(usize, @intCast(args[0].as_int()));
        const matrix = Matrix.ones(n, n);
        return Value.init_obj(@ptrCast(matrix));
    } else {
        const rows = @as(usize, @intCast(args[0].as_int()));
        const cols = @as(usize, @intCast(args[1].as_int()));
        const matrix = Matrix.ones(rows, cols);
        return Value.init_obj(@ptrCast(matrix));
    }
}

fn zeros_impl(argc: i32, args: [*]Value) Value {
    if (argc == 1) {
        const n = @as(usize, @intCast(args[0].as_int()));
        const matrix = Matrix.zeros(n, n);
        return Value.init_obj(@ptrCast(matrix));
    } else {
        const rows = @as(usize, @intCast(args[0].as_int()));
        const cols = @as(usize, @intCast(args[1].as_int()));
        const matrix = Matrix.zeros(rows, cols);
        return Value.init_obj(@ptrCast(matrix));
    }
}

fn rand_impl(argc: i32, args: [*]Value) Value {
    if (argc == 1) {
        const n = @as(usize, @intCast(args[0].as_int()));
        const matrix = Matrix.rand(n, n);
        return Value.init_obj(@ptrCast(matrix));
    } else {
        const rows = @as(usize, @intCast(args[0].as_int()));
        const cols = @as(usize, @intCast(args[1].as_int()));
        const matrix = Matrix.rand(rows, cols);
        return Value.init_obj(@ptrCast(matrix));
    }
}

fn randn_impl(argc: i32, args: [*]Value) Value {
    if (argc == 1) {
        const n = @as(usize, @intCast(args[0].as_int()));
        const matrix = Matrix.randn(n, n);
        return Value.init_obj(@ptrCast(matrix));
    } else {
        const rows = @as(usize, @intCast(args[0].as_int()));
        const cols = @as(usize, @intCast(args[1].as_int()));
        const matrix = Matrix.randn(rows, cols);
        return Value.init_obj(@ptrCast(matrix));
    }
}

fn transpose_impl(_: i32, args: [*]Value) Value {
    const matrix = args[0].as_matrix();
    const result = matrix.transpose();
    return Value.init_obj(@ptrCast(result));
}

fn det_impl(_: i32, args: [*]Value) Value {
    const matrix = args[0].as_matrix();
    const det_val = matrix.det();
    if (det_val == null) {
        return stdlib_v2.stdlib_error("Matrix must be square for determinant calculation", .{});
    }
    return Value.init_double(det_val.?);
}

fn inv_impl(_: i32, args: [*]Value) Value {
    const matrix = args[0].as_matrix();
    const result = matrix.inv();
    if (result == null) {
        return stdlib_v2.stdlib_error("Matrix is singular or not square", .{});
    }
    return Value.init_obj(@ptrCast(result.?));
}

fn trace_impl(_: i32, args: [*]Value) Value {
    const matrix = args[0].as_matrix();
    const trace_val = matrix.trace();
    return Value.init_double(trace_val);
}

fn size_impl(_: i32, args: [*]Value) Value {
    const matrix = args[0].as_matrix();
    const dims = matrix.size();
    // Return as a 1x2 matrix [rows, cols]
    const result = Matrix.init(1, 2);
    result.set(0, 0, @floatFromInt(dims[0]));
    result.set(0, 1, @floatFromInt(dims[1]));
    return Value.init_obj(@ptrCast(result));
}

fn norm_impl(_: i32, args: [*]Value) Value {
    const matrix = args[0].as_matrix();
    const norm_val = matrix.frobeniusNorm();
    return Value.init_double(norm_val);
}

fn matrix_get_impl(_: i32, args: [*]Value) Value {
    const matrix = args[0].as_matrix();
    const row = @as(usize, @intCast(args[1].as_int()));
    const col = @as(usize, @intCast(args[2].as_int()));

    if (row >= matrix.rows or col >= matrix.cols) {
        return stdlib_v2.stdlib_error("Matrix index out of bounds", .{});
    }

    const value = matrix.get(row, col);
    return Value.init_double(value);
}

fn matrix_set_impl(_: i32, args: [*]Value) Value {
    const matrix = args[0].as_matrix();
    const row = @as(usize, @intCast(args[1].as_int()));
    const col = @as(usize, @intCast(args[2].as_int()));

    if (row >= matrix.rows or col >= matrix.cols) {
        return stdlib_v2.stdlib_error("Matrix index out of bounds", .{});
    }

    var value: f64 = 0.0;
    if (args[3].is_double()) {
        value = args[3].as_double();
    } else if (args[3].is_int()) {
        value = @floatFromInt(args[3].as_int());
    } else {
        return stdlib_v2.stdlib_error("Value must be numeric", .{});
    }

    matrix.set(row, col, value);
    return args[0]; // Return the matrix
}

fn flatten_impl(_: i32, args: [*]Value) Value {
    const matrix = args[0].as_matrix();
    const flat_vector = matrix.toFlat();
    return Value.init_obj(@ptrCast(flat_vector));
}

fn horzcat_impl(_: i32, args: [*]Value) Value {
    const matrix1 = args[0].as_matrix();
    const matrix2 = args[1].as_matrix();
    const result = matrix1.horzcat(matrix2);

    if (result == null) {
        return stdlib_v2.stdlib_error("Matrices must have the same number of rows for horizontal concatenation", .{});
    }

    return Value.init_obj(@ptrCast(result.?));
}

fn vertcat_impl(_: i32, args: [*]Value) Value {
    const matrix1 = args[0].as_matrix();
    const matrix2 = args[1].as_matrix();
    const result = matrix1.vertcat(matrix2);

    if (result == null) {
        return stdlib_v2.stdlib_error("Matrices must have the same number of columns for vertical concatenation", .{});
    }

    return Value.init_obj(@ptrCast(result.?));
}

fn matrix_create_impl(_: i32, args: [*]Value) Value {
    const vector = args[0].as_fvec();
    const rows = @as(usize, @intCast(args[1].as_int()));
    const cols = @as(usize, @intCast(args[2].as_int()));

    if (vector.count != rows * cols) {
        return stdlib_v2.stdlib_error("Vector size does not match matrix dimensions", .{});
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

fn reshape_impl(_: i32, args: [*]Value) Value {
    const matrix = args[0].as_matrix();
    const new_rows = @as(usize, @intCast(args[1].as_int()));
    const new_cols = @as(usize, @intCast(args[2].as_int()));

    if (matrix.rows * matrix.cols != new_rows * new_cols) {
        return stdlib_v2.stdlib_error("Number of elements must remain the same when reshaping", .{});
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

fn rref_impl(_: i32, args: [*]Value) Value {
    const matrix = args[0].as_matrix();
    const result = matrix.rref();
    return Value.init_obj(@ptrCast(result));
}

fn rank_impl(_: i32, args: [*]Value) Value {
    const matrix = args[0].as_matrix();
    const rank_val = matrix.rank();
    return Value.init_int(@intCast(rank_val));
}

// === Parameter Specifications ===

const SizeParam = &[_]ParamSpec{.{ .name = "size", .type = .int }};
const TwoSizeParams = &[_]ParamSpec{
    .{ .name = "rows", .type = .int },
    .{ .name = "cols", .type = .int },
};
const MatrixParam = &[_]ParamSpec{.{ .name = "matrix", .type = .object }};
const TwoMatrixParams = &[_]ParamSpec{
    .{ .name = "matrix1", .type = .object },
    .{ .name = "matrix2", .type = .object },
};
const MatrixIndexParams = &[_]ParamSpec{
    .{ .name = "matrix", .type = .object },
    .{ .name = "row", .type = .int },
    .{ .name = "col", .type = .int },
};
const MatrixSetParams = &[_]ParamSpec{
    .{ .name = "matrix", .type = .object },
    .{ .name = "row", .type = .int },
    .{ .name = "col", .type = .int },
    .{ .name = "value", .type = .number },
};
const MatrixCreateParams = &[_]ParamSpec{
    .{ .name = "data", .type = .object },
    .{ .name = "rows", .type = .int },
    .{ .name = "cols", .type = .int },
};
const MatrixReshapeParams = &[_]ParamSpec{
    .{ .name = "matrix", .type = .object },
    .{ .name = "rows", .type = .int },
    .{ .name = "cols", .type = .int },
};

// Flexible parameter specs for functions that accept 1 or 2 arguments
const SizeOrTwoSizeParams = &[_]ParamSpec{
    .{ .name = "size_or_rows", .type = .int },
    .{ .name = "cols", .type = .int, .optional = true },
};

// === Public Function Definitions ===

pub const eye = DefineFunction(
    "eye",
    "matrix",
    "Create an identity matrix of the specified size",
    SizeOrTwoSizeParams,
    .object,
    &[_][]const u8{ "eye(3) -> 3x3 identity matrix", "eye(2, 3) -> 2x3 identity matrix" },
    eye_impl,
);

pub const ones = DefineFunction(
    "ones",
    "matrix",
    "Create a matrix filled with ones",
    SizeOrTwoSizeParams,
    .object,
    &[_][]const u8{ "ones(2) -> 2x2 matrix of ones", "ones(3, 2) -> 3x2 matrix of ones" },
    ones_impl,
);

pub const zeros = DefineFunction(
    "zeros",
    "matrix",
    "Create a matrix filled with zeros",
    SizeOrTwoSizeParams,
    .object,
    &[_][]const u8{ "zeros(2) -> 2x2 matrix of zeros", "zeros(3, 2) -> 3x2 matrix of zeros" },
    zeros_impl,
);

pub const rand = DefineFunction(
    "rand",
    "matrix",
    "Create a matrix filled with random values between 0 and 1",
    SizeOrTwoSizeParams,
    .object,
    &[_][]const u8{ "rand(2) -> 2x2 matrix of random values", "rand(3, 2) -> 3x2 matrix of random values" },
    rand_impl,
);

pub const randn = DefineFunction(
    "randn",
    "matrix",
    "Create a matrix filled with normally distributed random values",
    SizeOrTwoSizeParams,
    .object,
    &[_][]const u8{ "randn(2) -> 2x2 matrix of normal random values", "randn(3, 2) -> 3x2 matrix of normal random values" },
    randn_impl,
);

pub const transpose = DefineFunction(
    "transpose",
    "matrix",
    "Calculate the transpose of a matrix",
    MatrixParam,
    .object,
    &[_][]const u8{ "transpose([[1, 2], [3, 4]]) -> [[1, 3], [2, 4]]", "transpose(A) -> A'" },
    transpose_impl,
);

pub const det = DefineFunction(
    "det",
    "matrix",
    "Calculate the determinant of a square matrix",
    MatrixParam,
    .double,
    &[_][]const u8{ "det([[1, 2], [3, 4]]) -> -2.0", "det(eye(3)) -> 1.0" },
    det_impl,
);

pub const inv = DefineFunction(
    "inv",
    "matrix",
    "Calculate the inverse of a square matrix",
    MatrixParam,
    .object,
    &[_][]const u8{ "inv([[1, 2], [3, 4]]) -> inverse matrix", "inv(eye(3)) -> eye(3)" },
    inv_impl,
);

pub const trace = DefineFunction(
    "trace",
    "matrix",
    "Calculate the trace (sum of diagonal elements) of a matrix",
    MatrixParam,
    .double,
    &[_][]const u8{ "trace([[1, 2], [3, 4]]) -> 5.0", "trace(eye(3)) -> 3.0" },
    trace_impl,
);

pub const size = DefineFunction(
    "size",
    "matrix",
    "Get the dimensions of a matrix",
    MatrixParam,
    .object,
    &[_][]const u8{ "size([[1, 2, 3], [4, 5, 6]]) -> [2, 3]", "size(eye(4)) -> [4, 4]" },
    size_impl,
);

pub const norm = DefineFunction(
    "norm",
    "matrix",
    "Calculate the Frobenius norm of a matrix",
    MatrixParam,
    .double,
    &[_][]const u8{ "norm([[3, 4]]) -> 5.0", "norm(eye(2)) -> sqrt(2)" },
    norm_impl,
);

pub const matrix_get = DefineFunction(
    "matrix_get",
    "matrix",
    "Get the value at a specific position in a matrix",
    MatrixIndexParams,
    .double,
    &[_][]const u8{ "matrix_get(A, 0, 1) -> value at row 0, column 1", "matrix_get(eye(3), 1, 1) -> 1.0" },
    matrix_get_impl,
);

pub const matrix_set = DefineFunction(
    "matrix_set",
    "matrix",
    "Set the value at a specific position in a matrix",
    MatrixSetParams,
    .object,
    &[_][]const u8{ "matrix_set(A, 0, 1, 5.0) -> modified matrix", "matrix_set(zeros(2), 1, 0, 3.14) -> matrix with value set" },
    matrix_set_impl,
);

pub const flatten = DefineFunction(
    "flatten",
    "matrix",
    "Flatten a matrix into a vector",
    MatrixParam,
    .object,
    &[_][]const u8{ "flatten([[1, 2], [3, 4]]) -> [1, 3, 2, 4] (column-major)", "flatten(eye(2)) -> [1, 0, 0, 1]" },
    flatten_impl,
);

pub const horzcat = DefineFunction(
    "horzcat",
    "matrix",
    "Horizontally concatenate two matrices",
    TwoMatrixParams,
    .object,
    &[_][]const u8{ "horzcat([1; 2], [3; 4]) -> [1, 3; 2, 4]", "horzcat(A, B) -> [A B]" },
    horzcat_impl,
);

pub const vertcat = DefineFunction(
    "vertcat",
    "matrix",
    "Vertically concatenate two matrices",
    TwoMatrixParams,
    .object,
    &[_][]const u8{ "vertcat([1, 2], [3, 4]) -> [1, 2; 3, 4]", "vertcat(A, B) -> [A; B]" },
    vertcat_impl,
);

pub const matrix_create = DefineFunction(
    "matrix_create",
    "matrix",
    "Create a matrix from vector data with specified dimensions",
    MatrixCreateParams,
    .object,
    &[_][]const u8{ "matrix_create([1, 2, 3, 4], 2, 2) -> 2x2 matrix", "matrix_create(data_vec, m, n) -> m×n matrix" },
    matrix_create_impl,
);

pub const reshape = DefineFunction(
    "reshape",
    "matrix",
    "Reshape a matrix to new dimensions",
    MatrixReshapeParams,
    .object,
    &[_][]const u8{ "reshape(A, 2, 3) -> reshape A to 2x3", "reshape([1, 2, 3, 4], 2, 2) -> 2x2 matrix" },
    reshape_impl,
);

pub const rref = DefineFunction(
    "rref",
    "matrix",
    "Calculate the reduced row echelon form of a matrix",
    MatrixParam,
    .object,
    &[_][]const u8{ "rref([[1, 2], [2, 4]]) -> row echelon form", "rref(A) -> reduced form of A" },
    rref_impl,
);

pub const rank = DefineFunction(
    "rank",
    "matrix",
    "Calculate the rank of a matrix",
    MatrixParam,
    .int,
    &[_][]const u8{ "rank([[1, 2], [2, 4]]) -> 1", "rank(eye(3)) -> 3" },
    rank_impl,
);
