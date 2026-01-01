const std = @import("std");

const mem_utils = @import("../mem_utils.zig");
const allocateObject = @import("../object.zig").allocateObject;
const obj_h = @import("obj.zig");
const Obj = obj_h.Obj;
const value_h = @import("../value.zig");
const Value = value_h.Value;

/// A matrix row object that represents a single row from a matrix
/// This allows for A[row][col] syntax by returning this object from A[row]
/// and then indexing into it with [col]
pub const MatrixRow = struct {
    obj: Obj,
    matrix: *@import("matrix.zig").Matrix, // Reference to the parent matrix
    row_index: usize, // Which row this represents (0-based internally)

    const Self = *@This();

    /// Create a new matrix row object
    pub fn init(matrix: *@import("matrix.zig").Matrix, row_index: usize) Self {
        const matrix_row = allocateObject(@sizeOf(@This()), .OBJ_MATRIX_ROW);
        const typed_matrix_row: Self = @ptrCast(@alignCast(matrix_row));
        typed_matrix_row.matrix = matrix;
        typed_matrix_row.row_index = row_index;
        return typed_matrix_row;
    }

    /// Get an element from this row at the given column index
    pub fn get(self: Self, col_index: usize) f64 {
        return self.matrix.get(self.row_index, col_index);
    }

    /// Set an element in this row at the given column index
    pub fn set(self: Self, col_index: usize, value: f64) void {
        self.matrix.set(self.row_index, col_index, value);
    }

    /// Get the number of columns in this row
    pub fn length(self: Self) usize {
        return self.matrix.cols;
    }

    /// Print the matrix row for debugging
    pub fn print(self: Self) void {
        std.debug.print("MatrixRow[{}] from {}x{} matrix", .{ self.row_index, self.matrix.rows, self.matrix.cols });
    }
};
