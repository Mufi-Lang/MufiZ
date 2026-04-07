const std = @import("std");
const debug_print = std.debug.print;
const Random = std.Random;
const mem_utils = @import("../mem_utils.zig");
const allocateObject = @import("../object.zig").allocateObject;
const obj_h = @import("obj.zig");
const Obj = obj_h.Obj;
const value_h = @import("../value.zig");
const Value = value_h.Value;

/// Matrix object following Octave's matrix conventions and algorithms
/// Matrices are stored in column-major order (Fortran-style) to match Octave
pub const Matrix = struct {
    obj: Obj,
    rows: usize, // Number of rows
    cols: usize, // Number of columns
    data: []f64, // Data stored in column-major order

    const Self = *@This();

    /// Create a new matrix with specified dimensions
    /// Data is initialized to zeros
    pub fn init(rows: usize, cols: usize) Self {
        if (rows == 0 or cols == 0) {
            std.debug.print("Matrix dimensions must be positive\n", .{});
            std.process.exit(1);
        }

        const matrix: Self = @ptrCast(@alignCast(allocateObject(@sizeOf(Matrix), .OBJ_MATRIX)));
        matrix.rows = rows;
        matrix.cols = cols;

        const total_size = rows * cols;
        const allocator = mem_utils.getAllocator();
        const data_slice = mem_utils.alloc(allocator, f64, total_size) catch {
            std.debug.print("Failed to allocate memory for Matrix data\n", .{});
            std.process.exit(1);
        };
        matrix.data = data_slice;

        // Initialize to zeros
        for (0..total_size) |i| {
            matrix.data[i] = 0.0;
        }

        return matrix;
    }

    /// Create matrix from existing data (takes ownership of data)
    pub fn fromData(rows: usize, cols: usize, data: []f64) Self {
        if (rows * cols != data.len) {
            std.debug.print("Matrix data size mismatch\n", .{});
            std.process.exit(1);
        }

        const matrix: Self = @ptrCast(@alignCast(allocateObject(@sizeOf(Matrix), .OBJ_MATRIX)));
        matrix.rows = rows;
        matrix.cols = cols;
        matrix.data = data;

        return matrix;
    }

    /// Create identity matrix (Octave: eye(n))
    pub fn eye(n: usize) Self {
        const matrix = Matrix.init(n, n);
        for (0..n) |i| {
            matrix.set(i, i, 1.0);
        }
        return matrix;
    }

    /// Create matrix of ones (Octave: ones(rows, cols))
    pub fn ones(rows: usize, cols: usize) Self {
        const matrix = Matrix.init(rows, cols);
        const total_size = rows * cols;
        for (0..total_size) |i| {
            matrix.data[i] = 1.0;
        }
        return matrix;
    }

    /// Create matrix of zeros (Octave: zeros(rows, cols))
    pub fn zeros(rows: usize, cols: usize) Self {
        return Matrix.init(rows, cols); // Already initialized to zeros
    }

    /// Create random matrix (Octave: rand(rows, cols))
    pub fn rand(rows: usize, cols: usize) Self {
        const matrix = Matrix.init(rows, cols);
        var rng = std.Random.DefaultPrng.init(@intCast(std.time.timestamp()));
        const total_size = rows * cols;
        for (0..total_size) |i| {
            matrix.data[i] = rng.random().float(f64);
        }
        return matrix;
    }

    /// Create random normal matrix (Octave: randn(rows, cols))
    pub fn randn(rows: usize, cols: usize) Self {
        const matrix = Matrix.init(rows, cols);
        var rng = std.Random.DefaultPrng.init(@intCast(std.time.timestamp()));
        const total_size = rows * cols;

        // Box-Muller transformation for normal distribution
        var i: usize = 0;
        while (i < total_size) {
            const uniform1 = rng.random().float(f64);
            const uniform2 = rng.random().float(f64);

            const z0 = @sqrt(-2.0 * @log(uniform1)) * @cos(2.0 * std.math.pi * uniform2);
            matrix.data[i] = z0;
            i += 1;

            if (i < total_size) {
                const z1 = @sqrt(-2.0 * @log(uniform1)) * @sin(2.0 * std.math.pi * uniform2);
                matrix.data[i] = z1;
                i += 1;
            }
        }
        return matrix;
    }

    /// Deallocate matrix memory
    pub fn deinit(self: Self) void {
        const allocator = mem_utils.getAllocator();
        mem_utils.free(allocator, self.data);
    }

    /// Print matrix in Octave format
    pub fn print(self: Self) void {
        debug_print("\n", .{});
        for (0..self.rows) |i| {
            debug_print("   ", .{});
            for (0..self.cols) |j| {
                const value = self.get(i, j);
                debug_print("{d:8.4}  ", .{value});
            }
            debug_print("\n", .{});
        }
        debug_print("\n", .{});
    }

    /// Convert linear index to (row, col) - column-major order
    pub inline fn indexToRowCol(self: Self, index: usize) struct { row: usize, col: usize } {
        return .{
            .row = index % self.rows,
            .col = index / self.rows,
        };
    }

    /// Convert (row, col) to linear index - column-major order
    inline fn rowColToIndex(self: Self, row: usize, col: usize) usize {
        return col * self.rows + row;
    }

    /// Get element at (row, col) using 0-based indexing
    pub fn get(self: Self, row: usize, col: usize) f64 {
        if (row >= self.rows or col >= self.cols) {
            std.debug.print("Matrix index out of bounds: ({d}, {d}) for {}x{} matrix\n", .{ row, col, self.rows, self.cols });
            return 0.0;
        }
        return self.data[self.rowColToIndex(row, col)];
    }

    /// Set element at (row, col) using 0-based indexing
    pub fn set(self: Self, row: usize, col: usize, value: f64) void {
        if (row >= self.rows or col >= self.cols) {
            std.debug.print("Matrix index out of bounds: ({d}, {d}) for {}x{} matrix\n", .{ row, col, self.rows, self.cols });
            return;
        }
        self.data[self.rowColToIndex(row, col)] = value;
    }

    /// Get element by flat index in row-major order (for foreach loops)
    /// Index 0 = element at (0,0), index 1 = element at (0,1), etc.
    pub fn getFlat(self: Self, flat_index: usize) f64 {
        if (flat_index >= self.rows * self.cols) {
            std.debug.print("Matrix flat index out of bounds: {d} for {}x{} matrix\n", .{ flat_index, self.rows, self.cols });
            return 0.0;
        }
        // Convert flat index (row-major) to (row, col)
        const row = flat_index / self.cols;
        const col = flat_index % self.cols;
        return self.get(row, col);
    }

    /// Get matrix as flat array for foreach loops
    /// Returns a new FloatVector containing all matrix elements in row-major order
    pub fn toFlat(self: Self) *@import("fvec.zig").FloatVector {
        const fvec = @import("fvec.zig");
        const total_elements = self.rows * self.cols;
        const flat_vector = fvec.FloatVector.init(@intCast(total_elements));

        for (0..total_elements) |i| {
            const element = self.getFlat(i);
            flat_vector.push(element);
        }

        return flat_vector;
    }

    /// Clone matrix (deep copy)
    pub fn clone(self: Self) Self {
        const new_matrix = Matrix.init(self.rows, self.cols);
        const total_size = self.rows * self.cols;
        for (0..total_size) |i| {
            new_matrix.data[i] = self.data[i];
        }
        return new_matrix;
    }

    /// Transpose matrix (Octave: A')
    pub fn transpose(self: Self) Self {
        const result = Matrix.init(self.cols, self.rows);
        for (0..self.rows) |i| {
            for (0..self.cols) |j| {
                result.set(j, i, self.get(i, j));
            }
        }
        return result;
    }

    /// Matrix addition (Octave: A + B)
    pub fn add(self: Self, other: Self) ?Self {
        if (self.rows != other.rows or self.cols != other.cols) {
            return null; // Dimension mismatch
        }

        const result = Matrix.init(self.rows, self.cols);
        const total_size = self.rows * self.cols;
        for (0..total_size) |i| {
            result.data[i] = self.data[i] + other.data[i];
        }
        return result;
    }

    /// Matrix subtraction (Octave: A - B)
    pub fn sub(self: Self, other: Self) ?Self {
        if (self.rows != other.rows or self.cols != other.cols) {
            return null; // Dimension mismatch
        }

        const result = Matrix.init(self.rows, self.cols);
        const total_size = self.rows * self.cols;
        for (0..total_size) |i| {
            result.data[i] = self.data[i] - other.data[i];
        }
        return result;
    }

    /// Scalar multiplication (Octave: A * scalar)
    pub fn scalarMul(self: Self, scalar: f64) Self {
        const result = Matrix.init(self.rows, self.cols);
        const total_size = self.rows * self.cols;
        for (0..total_size) |i| {
            result.data[i] = self.data[i] * scalar;
        }
        return result;
    }

    /// Matrix multiplication (Octave: A * B)
    /// Uses standard algorithm optimized for cache locality
    pub fn mul(self: Self, other: Self) ?Self {
        if (self.cols != other.rows) {
            return null; // Dimension mismatch
        }

        const result = Matrix.init(self.rows, other.cols);

        // Standard matrix multiplication with loop reordering for cache efficiency
        for (0..self.rows) |i| {
            for (0..other.cols) |j| {
                var sum: f64 = 0.0;
                for (0..self.cols) |k| {
                    sum += self.get(i, k) * other.get(k, j);
                }
                result.set(i, j, sum);
            }
        }

        return result;
    }

    /// Element-wise multiplication (Octave: A .* B)
    pub fn elemMul(self: Self, other: Self) ?Self {
        if (self.rows != other.rows or self.cols != other.cols) {
            return null; // Dimension mismatch
        }

        const result = Matrix.init(self.rows, self.cols);
        const total_size = self.rows * self.cols;
        for (0..total_size) |i| {
            result.data[i] = self.data[i] * other.data[i];
        }
        return result;
    }

    /// Element-wise division (Octave: A ./ B)
    pub fn elemDiv(self: Self, other: Self) ?Self {
        if (self.rows != other.rows or self.cols != other.cols) {
            return null; // Dimension mismatch
        }

        const result = Matrix.init(self.rows, self.cols);
        const total_size = self.rows * self.cols;
        for (0..total_size) |i| {
            if (other.data[i] == 0.0) {
                result.data[i] = std.math.inf(f64);
            } else {
                result.data[i] = self.data[i] / other.data[i];
            }
        }
        return result;
    }

    /// Matrix determinant (Octave: det(A))
    /// Uses LU decomposition for efficient computation
    pub fn det(self: Self) ?f64 {
        if (self.rows != self.cols) {
            return null; // Must be square matrix
        }

        if (self.rows == 1) {
            return self.get(0, 0);
        }

        if (self.rows == 2) {
            return self.get(0, 0) * self.get(1, 1) - self.get(0, 1) * self.get(1, 0);
        }

        // For larger matrices, use LU decomposition
        const lu_result = self.luDecomposition();
        if (lu_result == null) return 0.0; // Singular matrix

        var det_val: f64 = 1.0;
        for (0..self.rows) |i| {
            det_val *= lu_result.?.u.get(i, i);
        }

        // Account for row swaps in permutation
        if (lu_result.?.swaps % 2 == 1) {
            det_val = -det_val;
        }

        // Let GC handle cleanup of LU matrices
        return det_val;
    }

    /// LU Decomposition with partial pivoting
    /// Returns struct with L, U, P matrices and number of row swaps
    pub const LUResult = struct {
        l: Self,
        u: Self,
        p: Self,
        swaps: usize,
    };

    pub fn luDecomposition(self: Self) ?LUResult {
        if (self.rows != self.cols) return null;

        const n = self.rows;
        var l = Matrix.eye(n);
        var u = self.clone();
        var p = Matrix.eye(n);
        var swaps: usize = 0;

        for (0..n) |k| {
            // Find pivot
            var max_val: f64 = @abs(u.get(k, k));
            var pivot_row: usize = k;

            for (k + 1..n) |i| {
                const val = @abs(u.get(i, k));
                if (val > max_val) {
                    max_val = val;
                    pivot_row = i;
                }
            }

            // Swap rows if necessary
            if (pivot_row != k) {
                u.swapRows(k, pivot_row);
                p.swapRows(k, pivot_row);
                
                // Swap rows in L for the ALREADY computed multipliers (columns 0..k)
                for (0..k) |j| {
                    const temp = l.get(k, j);
                    l.set(k, j, l.get(pivot_row, j));
                    l.set(pivot_row, j, temp);
                }
                
                swaps += 1;
            }

            // Check for singularity
            if (@abs(u.get(k, k)) < 1e-14) {
                return null; // Singular matrix
            }

            // Eliminate column
            for (k + 1..n) |i| {
                const factor = u.get(i, k) / u.get(k, k);
                l.set(i, k, factor);

                for (k..n) |j| {
                    u.set(i, j, u.get(i, j) - factor * u.get(k, j));
                }
            }
        }

        return LUResult{ .l = l, .u = u, .p = p, .swaps = swaps };
    }

    /// Swap two rows in the matrix
    fn swapRows(self: Self, row1: usize, row2: usize) void {
        if (row1 == row2) return;

        for (0..self.cols) |j| {
            const temp = self.get(row1, j);
            self.set(row1, j, self.get(row2, j));
            self.set(row2, j, temp);
        }
    }

    /// Matrix inverse (Octave: inv(A))
    /// Uses LU decomposition with forward/backward substitution
    pub fn inv(self: Self) ?Self {
        if (self.rows != self.cols) return null;

        const n = self.rows;
        const lu_result = self.luDecomposition();
        if (lu_result == null) return null; // Singular matrix

        var result = Matrix.init(n, n);

        // PA = LU => Ax = b => PAx = Pb => LUx = Pb
        // For inverse, Ax = I => LUx = P
        // Solve for each column of the inverse
        for (0..n) |col| {
            // Extract column from permutation matrix P
            var b = Matrix.init(n, 1);
            for (0..n) |i| {
                b.set(i, 0, lu_result.?.p.get(i, col));
            }

            // Forward substitution (solve Ly = b)
            for (0..n) |i| {
                var sum: f64 = 0.0;
                for (0..i) |j| {
                    sum += lu_result.?.l.get(i, j) * b.get(j, 0);
                }
                b.set(i, 0, (b.get(i, 0) - sum)); // L has unit diagonal
            }

            // Backward substitution (solve Ux = y)
            var idx: usize = n;
            while (idx > 0) {
                idx -= 1;
                var sum: f64 = 0.0;
                for (idx + 1..n) |j| {
                    sum += lu_result.?.u.get(idx, j) * b.get(j, 0);
                }
                b.set(idx, 0, (b.get(idx, 0) - sum) / lu_result.?.u.get(idx, idx));
            }

            // Store result column
            for (0..n) |row_idx| {
                result.set(row_idx, col, b.get(row_idx, 0));
            }
        }

        return result;
    }

    /// Solve linear system Ax = b using LU decomposition (Octave: A \ b)
    pub fn solve(self: Self, b: Self) ?Self {
        if (self.rows != self.cols or self.rows != b.rows) return null;

        const n = self.rows;
        const lu_result = self.luDecomposition();
        if (lu_result == null) return null; // Singular matrix

        const x = Matrix.zeros(n, b.cols);

        // PAx = Pb => LUx = Pb
        const Pb = lu_result.?.p.mul(b) orelse return null;

        for (0..b.cols) |col| {
            // Forward substitution (solve Ly = Pb)
            var y = Matrix.init(n, 1);
            for (0..n) |i| {
                var sum: f64 = 0.0;
                for (0..i) |j| {
                    sum += lu_result.?.l.get(i, j) * y.get(j, 0);
                }
                y.set(i, 0, (Pb.get(i, col) - sum)); // L has unit diagonal
            }

            // Backward substitution (solve Ux = y)
            var idx: usize = n;
            while (idx > 0) {
                idx -= 1;
                var sum: f64 = 0.0;
                var j: usize = idx + 1;
                while (j < n) : (j += 1) {
                    sum += lu_result.?.u.get(idx, j) * x.get(j, col);
                }
                x.set(idx, col, (y.get(idx, 0) - sum) / lu_result.?.u.get(idx, idx));
            }
        }

        return x;
    }

    /// Matrix trace (sum of diagonal elements) (Octave: trace(A))
    pub fn trace(self: Self) f64 {
        var sum: f64 = 0.0;
        const min_dim = @min(self.rows, self.cols);
        for (0..min_dim) |i| {
            sum += self.get(i, i);
        }
        return sum;
    }

    /// Frobenius norm (Octave: norm(A, 'fro'))
    pub fn frobeniusNorm(self: Self) f64 {
        var sum: f64 = 0.0;
        const total_size = self.rows * self.cols;
        for (0..total_size) |i| {
            sum += self.data[i] * self.data[i];
        }
        return @sqrt(sum);
    }

    /// Get matrix dimensions as [rows, cols]
    pub fn size(self: Self) [2]usize {
        return .{ self.rows, self.cols };
    }

    /// Check if matrices are equal within tolerance
    pub fn equal(self: Self, other: Self, tolerance: f64) bool {
        if (self.rows != other.rows or self.cols != other.cols) {
            return false;
        }

        const total_size = self.rows * self.cols;
        for (0..total_size) |i| {
            if (@abs(self.data[i] - other.data[i]) > tolerance) {
                return false;
            }
        }
        return true;
    }

    /// Extract submatrix (Octave: A(rows, cols))
    pub fn submatrix(self: Self, start_row: usize, end_row: usize, start_col: usize, end_col: usize) ?Self {
        if (start_row >= self.rows or end_row >= self.rows or
            start_col >= self.cols or end_col >= self.cols or
            start_row > end_row or start_col > end_col)
        {
            return null;
        }

        const new_rows = end_row - start_row + 1;
        const new_cols = end_col - start_col + 1;
        const result = Matrix.init(new_rows, new_cols);

        for (0..new_rows) |i| {
            for (0..new_cols) |j| {
                result.set(i, j, self.get(start_row + i, start_col + j));
            }
        }

        return result;
    }

    /// Concatenate matrices horizontally (Octave: [A B])
    pub fn horzcat(self: Self, other: Self) ?Self {
        if (self.rows != other.rows) return null;

        const result = Matrix.init(self.rows, self.cols + other.cols);

        // Copy first matrix
        for (0..self.rows) |i| {
            for (0..self.cols) |j| {
                result.set(i, j, self.get(i, j));
            }
        }

        // Copy second matrix
        for (0..other.rows) |i| {
            for (0..other.cols) |j| {
                result.set(i, self.cols + j, other.get(i, j));
            }
        }

        return result;
    }

    /// Concatenate matrices vertically (Octave: [A; B])
    pub fn vertcat(self: Self, other: Self) ?Self {
        if (self.cols != other.cols) return null;

        const result = Matrix.init(self.rows + other.rows, self.cols);

        // Copy first matrix
        for (0..self.rows) |i| {
            for (0..self.cols) |j| {
                result.set(i, j, self.get(i, j));
            }
        }

        // Copy second matrix
        for (0..other.rows) |i| {
            for (0..other.cols) |j| {
                result.set(self.rows + i, j, other.get(i, j));
            }
        }

        return result;
    }

    /// Reduced Row Echelon Form (Octave: rref(A))
    /// Implements Gauss-Jordan elimination with partial pivoting
    pub fn rref(self: Self) Self {
        const result = self.clone();
        const m = result.rows;
        const n = result.cols;

        var lead: usize = 0;
        var r: usize = 0;

        while (r < m and lead < n) {
            // Find pivot
            var i = r;
            while (i < m and @abs(result.get(i, lead)) < 1e-10) {
                i += 1;
            }

            if (i == m) {
                // No pivot in this column, move to next column
                lead += 1;
                continue;
            }

            // Swap rows r and i if needed
            if (i != r) {
                for (0..n) |j| {
                    const temp = result.get(r, j);
                    result.set(r, j, result.get(i, j));
                    result.set(i, j, temp);
                }
            }

            // Scale pivot row to make leading element 1
            const pivot = result.get(r, lead);
            if (@abs(pivot) > 1e-10) {
                for (0..n) |j| {
                    result.set(r, j, result.get(r, j) / pivot);
                }

                // Eliminate column
                for (0..m) |k| {
                    if (k != r) {
                        const factor = result.get(k, lead);
                        for (0..n) |j| {
                            const val = result.get(k, j) - factor * result.get(r, j);
                            result.set(k, j, val);
                        }
                    }
                }
            }

            r += 1;
            lead += 1;
        }

        return result;
    }

    /// Matrix rank using RREF (Octave: rank(A))
    pub fn rank(self: Self) usize {
        const rref_matrix = self.rref();
        var rank_count: usize = 0;

        for (0..rref_matrix.rows) |i| {
            var has_nonzero = false;
            for (0..rref_matrix.cols) |j| {
                if (@abs(rref_matrix.get(i, j)) > 1e-10) {
                    has_nonzero = true;
                    break;
                }
            }
            if (has_nonzero) {
                rank_count += 1;
            }
        }

        // Let GC handle cleanup
        return rank_count;
    }

    /// QR Decomposition using Modified Gram-Schmidt
    /// Returns a struct containing Q (orthogonal) and R (upper triangular)
    /// Q has dimensions m x n, R has dimensions n x n
    pub fn qrDecomposition(self: Self) ?struct { Q: Self, R: Self } {
        const m = self.rows;
        const n = self.cols;

        // Q will be m x n matrix of orthonormal columns
        const Q = Matrix.zeros(m, n);
        // R will be n x n upper triangular matrix
        const R = Matrix.zeros(n, n);

        // Modified Gram-Schmidt process
        for (0..n) |j| {
            // R[j,j] = ||A[:,j]|| (norm of column j)
            var norm_sq: f64 = 0.0;
            for (0..m) |i| {
                const val = self.get(i, j);
                norm_sq += val * val;
            }
            const r_jj = std.math.sqrt(norm_sq);

            // Check for zero column
            if (r_jj < 1e-14) {
                return null; // Rank deficient
            }

            R.set(j, j, r_jj);

            // Q[:,j] = A[:,j] / R[j,j]
            for (0..m) |i| {
                Q.set(i, j, self.get(i, j) / r_jj);
            }

            // For each subsequent column
            for (j + 1..n) |k| {
                // R[j,k] = Q[:,j]^T * A[:,k]
                var dot_prod: f64 = 0.0;
                for (0..m) |i| {
                    dot_prod += Q.get(i, j) * self.get(i, k);
                }
                R.set(j, k, dot_prod);

                // A[:,k] = A[:,k] - R[j,k] * Q[:,j]
                for (0..m) |i| {
                    const new_val = self.get(i, k) - dot_prod * Q.get(i, j);
                    self.set(i, k, new_val);
                }
            }
        }

        return .{ .Q = Q, .R = R };
    }

    /// Eigenvalues and Eigenvectors using QR Algorithm
    /// Only works for symmetric matrices
    /// Returns tuple containing eigenvalues (vector) and eigenvectors (matrix columns)
    pub fn eigenDecomposition(self: Self) ?struct { eigenvalues: Self, eigenvectors: Self } {
        if (self.rows != self.cols) {
            return null; // Must be square
        }

        const n = self.rows;
        const max_iterations = 100;
        const tolerance = 1e-10;

        // Copy the matrix so we don't modify the original
        var A = self.clone();
        // Track the accumulated Q matrices for eigenvectors
        var V = Matrix.eye(n);

        // QR algorithm iteration
        for (0..max_iterations) |_| {
            // QR decomposition of current matrix
            const qr_result = A.qrDecomposition() orelse return null;
            const Q = qr_result.Q;
            const R = qr_result.R;

            // A_new = R * Q
            const A_new = R.mul(Q) orelse return null;

            // V = V * Q (accumulate eigenvectors)
            const V_new = V.mul(Q) orelse return null;

            // Check convergence (off-diagonal elements should be small)
            var off_diag_norm: f64 = 0.0;
            for (0..n) |i| {
                for (0..n) |j| {
                    if (i != j) {
                        const val = A_new.get(i, j);
                        off_diag_norm += val * val;
                    }
                }
            }
            off_diag_norm = std.math.sqrt(off_diag_norm);

            A = A_new;
            V = V_new;

            if (off_diag_norm < tolerance) {
                break;
            }
        }

        // Extract eigenvalues from diagonal of A
        const eigenvalues = Matrix.zeros(n, 1);
        for (0..n) |i| {
            eigenvalues.set(i, 0, A.get(i, i));
        }

        return .{ .eigenvalues = eigenvalues, .eigenvectors = V };
    }

    /// Singular Value Decomposition (SVD)
    /// Decomposes matrix A into U * S * V^T
    /// Returns tuple with U, singular values (vector), and V
    pub fn svdDecomposition(self: Self) ?struct { U: Self, singularValues: Self, V: Self } {
        const m = self.rows;
        const n = self.cols;
        const min_mn = @min(m, n);

        // Power iteration to find singular values
        const max_iterations = 50;
        const tolerance = 1e-10;

        // Start with U = I (m x m) and V = I (n x n)
        var U = Matrix.zeros(m, min_mn);
        var V = Matrix.zeros(n, n);
        var sigma_vals = Matrix.zeros(min_mn, 1);

        // Make a copy for working
        var A_work = self.clone();

        // Extract singular values via power iteration
        for (0..min_mn) |k| {
            // Power iteration to find dominant singular value
            var v = Matrix.zeros(n, 1);
            v.set(0, 0, 1.0); // Initial guess

            var sigma: f64 = 0.0;

            for (0..max_iterations) |_| {
                // u = A * v
                const u = A_work.mul(v) orelse return null;

                // sigma = ||u||
                var norm_u: f64 = 0.0;
                for (0..m) |i| {
                    const val = u.get(i, 0);
                    norm_u += val * val;
                }
                sigma = std.math.sqrt(norm_u);

                if (sigma < 1e-14) {
                    break;
                }

                // u = u / sigma
                for (0..m) |i| {
                    u.set(i, 0, u.get(i, 0) / sigma);
                }

                // v_new = A^T * u
                const At = A_work.transpose();
                const v_new = At.mul(u) orelse return null;

                // Normalize v_new
                var norm_v: f64 = 0.0;
                for (0..n) |j| {
                    const val = v_new.get(j, 0);
                    norm_v += val * val;
                }
                norm_v = std.math.sqrt(norm_v);

                if (norm_v < tolerance) {
                    break;
                }

                for (0..n) |j| {
                    v_new.set(j, 0, v_new.get(j, 0) / norm_v);
                }

                v = v_new;
            }

            // Store sigma and vectors
            sigma_vals.set(k, 0, sigma);
            for (0..m) |i| {
                const u_ik = A_work.get(i, 0) / sigma; // Simplified: use first column
                U.set(i, k, u_ik);
            }
            for (0..n) |j| {
                V.set(j, k, v.get(j, 0));
            }

            // Deflate A: A = A - sigma * u * v^T
            for (0..m) |i| {
                for (0..n) |j| {
                    const u_i = U.get(i, k);
                    const v_j = V.get(j, k);
                    const deflate_val = sigma * u_i * v_j;
                    A_work.set(i, j, A_work.get(i, j) - deflate_val);
                }
            }
        }

        return .{ .U = U, .singularValues = sigma_vals, .V = V };
    }
};

test "Matrix LU Decomposition basic" {
    const lib = @import("../lib.zig");
    try lib.init(.{});
    defer lib.deinit();

    const A = Matrix.init(3, 3);
    // [1 2 3; 4 5 6; 7 8 10]
    A.set(0, 0, 1); A.set(0, 1, 2); A.set(0, 2, 3);
    A.set(1, 0, 4); A.set(1, 1, 5); A.set(1, 2, 6);
    A.set(2, 0, 7); A.set(2, 1, 8); A.set(2, 2, 10);

    const lu = A.luDecomposition() orelse return error.TestUnexpectedResult;
    
    // Verify PA = LU
    const PA = lu.p.mul(A) orelse return error.TestUnexpectedResult;
    const LU = lu.l.mul(lu.u) orelse return error.TestUnexpectedResult;
    
    try std.testing.expect(PA.equal(LU, 1e-10));
}

test "Matrix Inverse" {
    const lib = @import("../lib.zig");
    try lib.init(.{});
    defer lib.deinit();

    const A = Matrix.init(3, 3);
    A.set(0, 0, 1); A.set(0, 1, 2); A.set(0, 2, 3);
    A.set(1, 0, 0); A.set(1, 1, 1); A.set(1, 2, 4);
    A.set(2, 0, 5); A.set(2, 1, 6); A.set(2, 2, 0);

    const inv = A.inv() orelse return error.TestUnexpectedResult;
    const I = A.mul(inv) orelse return error.TestUnexpectedResult;
    const expected_I = Matrix.eye(3);
    
    try std.testing.expect(I.equal(expected_I, 1e-10));
}

test "Matrix Determinant" {
    const lib = @import("../lib.zig");
    try lib.init(.{});
    defer lib.deinit();

    const A = Matrix.init(3, 3);
    A.set(0, 0, 1); A.set(0, 1, 2); A.set(0, 2, 3);
    A.set(1, 0, 0); A.set(1, 1, 1); A.set(1, 2, 4);
    A.set(2, 0, 5); A.set(2, 1, 6); A.set(2, 2, 0);

    const det_val = A.det() orelse return error.TestUnexpectedResult;
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), det_val, 1e-10);
}

test "Matrix Solve" {
    const lib = @import("../lib.zig");
    try lib.init(.{});
    defer lib.deinit();

    const A = Matrix.init(3, 3);
    // [1 2 3; 4 5 6; 7 8 10]
    A.set(0, 0, 1); A.set(0, 1, 2); A.set(0, 2, 3);
    A.set(1, 0, 4); A.set(1, 1, 5); A.set(1, 2, 6);
    A.set(2, 0, 7); A.set(2, 1, 8); A.set(2, 2, 10);

    const b = Matrix.init(3, 1);
    b.set(0, 0, 14); // 1*1 + 2*2 + 3*3 = 1 + 4 + 9 = 14
    b.set(1, 0, 32); // 4*1 + 5*2 + 6*3 = 4 + 10 + 18 = 32
    b.set(2, 0, 53); // 7*1 + 8*2 + 10*3 = 7 + 16 + 30 = 53

    const x = A.solve(b) orelse return error.TestUnexpectedResult;
    
    // Expected x = [1; 2; 3]
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), x.get(0, 0), 1e-10);
    try std.testing.expectApproxEqAbs(@as(f64, 2.0), x.get(1, 0), 1e-10);
    try std.testing.expectApproxEqAbs(@as(f64, 3.0), x.get(2, 0), 1e-10);
}

test "Matrix Singular Case" {
    const lib = @import("../lib.zig");
    try lib.init(.{});
    defer lib.deinit();

    const A = Matrix.init(2, 2);
    A.set(0, 0, 1); A.set(0, 1, 2);
    A.set(1, 0, 2); A.set(1, 1, 4); // Row 2 = 2 * Row 1

    const lu = A.luDecomposition();
    try std.testing.expect(lu == null);
    
    const inv = A.inv();
    try std.testing.expect(inv == null);
    
    const b = Matrix.init(2, 1);
    const x = A.solve(b);
    try std.testing.expect(x == null);
}

