const std = @import("std");
const mem_utils = @import("../mem_utils.zig");
const allocateObject = @import("../object.zig").allocateObject;
const obj_h = @import("obj.zig");
const Obj = obj_h.Obj;

/// Unified n-dimensional tensor type that subsumes both FVec (1D) and Matrix (2D)
/// Stored in row-major order for compatibility and efficiency
/// Can represent any dimensional array (1D, 2D, 3D, etc.)
pub const Tensor = struct {
    obj: Obj,
    rank: usize,                    // Number of dimensions (1 for vector, 2 for matrix, etc.)
    shape: []usize,                 // Dimensions: shape[i] = size of dimension i
    stride: []usize,                // Strides for efficient indexing
    data: []f64,                    // Flat data storage (row-major order)
    offset: usize = 0,              // For views/slices (not yet implemented)

    const Self = *@This();

    /// Create a new tensor with specified dimensions
    /// Initializes all elements to zero
    pub fn init(shape_slice: []const usize) Self {
        if (shape_slice.len == 0) {
            std.debug.print("Tensor rank must be > 0\n", .{});
            std.process.exit(1);
        }

        // Verify all dimensions are positive
        for (shape_slice) |dim| {
            if (dim == 0) {
                std.debug.print("Tensor dimensions must be positive\n", .{});
                std.process.exit(1);
            }
        }

        // Calculate total size
        var total_size: usize = 1;
        for (shape_slice) |dim| {
            total_size *= dim;
        }

        const tensor: Self = @ptrCast(@alignCast(allocateObject(@sizeOf(Tensor), .OBJ_TENSOR)));

        const allocator = mem_utils.getAllocator();

        // Allocate and copy shape
        const shape_alloc = mem_utils.alloc(allocator, usize, shape_slice.len) catch {
            std.debug.print("Failed to allocate shape for Tensor\n", .{});
            std.process.exit(1);
        };
        for (0..shape_slice.len) |i| {
            shape_alloc[i] = shape_slice[i];
        }
        tensor.shape = shape_alloc;
        tensor.rank = shape_slice.len;

        // Allocate and compute strides (row-major: rightmost dimension changes fastest)
        const stride_alloc = mem_utils.alloc(allocator, usize, shape_slice.len) catch {
            std.debug.print("Failed to allocate stride for Tensor\n", .{});
            std.process.exit(1);
        };
        stride_alloc[shape_slice.len - 1] = 1;
        if (shape_slice.len > 1) {
            var i: i64 = @intCast(shape_slice.len - 2);
            while (i >= 0) : (i -= 1) {
                stride_alloc[@intCast(i)] = stride_alloc[@intCast(i + 1)] * shape_slice[@intCast(i + 1)];
            }
        }
        tensor.stride = stride_alloc;

        // Allocate data (all zeros)
        const data_slice = mem_utils.alloc(allocator, f64, total_size) catch {
            std.debug.print("Failed to allocate data for Tensor\n", .{});
            std.process.exit(1);
        };
        for (0..total_size) |i| {
            data_slice[i] = 0.0;
        }
        tensor.data = data_slice;

        return tensor;
    }

    /// Create 1D tensor (vector)
    pub fn vector(len: usize) Self {
        const shape = &[_]usize{len};
        return Tensor.init(shape);
    }

    /// Create 2D tensor (matrix)
    pub fn matrix(rows: usize, cols: usize) Self {
        const shape = &[_]usize{ rows, cols };
        return Tensor.init(shape);
    }

    /// Create 3D tensor
    pub fn tensor3D(d1: usize, d2: usize, d3: usize) Self {
        const shape = &[_]usize{ d1, d2, d3 };
        return Tensor.init(shape);
    }

    /// Total number of elements in tensor
    pub fn size(self: Self) usize {
        var total: usize = 1;
        for (0..self.rank) |i| {
            total *= self.shape[i];
        }
        return total;
    }

    /// Compute linear index from multi-dimensional indices
    fn computeIndex(self: Self, indices: []const usize) usize {
        if (indices.len != self.rank) {
            std.debug.print("Index dimension mismatch: expected {}, got {}\n", .{ self.rank, indices.len });
            std.process.exit(1);
        }

        var index: usize = 0;
        for (0..self.rank) |i| {
            if (indices[i] >= self.shape[i]) {
                std.debug.print("Index out of bounds at dimension {}: {} >= {}\n", .{ i, indices[i], self.shape[i] });
                std.process.exit(1);
            }
            index += indices[i] * self.stride[i];
        }
        return index;
    }

    /// Get value at multi-dimensional indices
    pub fn getND(self: Self, indices: []const usize) f64 {
        const idx = self.computeIndex(indices);
        return self.data[idx];
    }

    /// Set value at multi-dimensional indices
    pub fn setND(self: Self, indices: []const usize, value: f64) void {
        const idx = self.computeIndex(indices);
        self.data[idx] = value;
    }

    /// Get 1D element (for vectors)
    pub fn get1D(self: Self, i: usize) f64 {
        if (self.rank != 1) {
            std.debug.print("Expected 1D tensor, got {}D\n", .{self.rank});
            std.process.exit(1);
        }
        const indices = &[_]usize{i};
        return self.getND(indices);
    }

    /// Set 1D element
    pub fn set1D(self: Self, i: usize, value: f64) void {
        if (self.rank != 1) {
            std.debug.print("Expected 1D tensor, got {}D\n", .{self.rank});
            std.process.exit(1);
        }
        const indices = &[_]usize{i};
        self.setND(indices, value);
    }

    /// Get 2D element (for matrices)
    pub fn get2D(self: Self, i: usize, j: usize) f64 {
        if (self.rank != 2) {
            std.debug.print("Expected 2D tensor, got {}D\n", .{self.rank});
            std.process.exit(1);
        }
        const indices = &[_]usize{ i, j };
        return self.getND(indices);
    }

    /// Set 2D element
    pub fn set2D(self: Self, i: usize, j: usize, value: f64) void {
        if (self.rank != 2) {
            std.debug.print("Expected 2D tensor, got {}D\n", .{self.rank});
            std.process.exit(1);
        }
        const indices = &[_]usize{ i, j };
        self.setND(indices, value);
    }

    /// Get 3D element
    pub fn get3D(self: Self, i: usize, j: usize, k: usize) f64 {
        if (self.rank != 3) {
            std.debug.print("Expected 3D tensor, got {}D\n", .{self.rank});
            std.process.exit(1);
        }
        const indices = &[_]usize{ i, j, k };
        return self.getND(indices);
    }

    /// Set 3D element
    pub fn set3D(self: Self, i: usize, j: usize, k: usize, value: f64) void {
        if (self.rank != 3) {
            std.debug.print("Expected 3D tensor, got {}D\n", .{self.rank});
            std.process.exit(1);
        }
        const indices = &[_]usize{ i, j, k };
        self.setND(indices, value);
    }

    /// Create identity matrix (for 2D tensors)
    pub fn eye(n: usize) Self {
        const t = Tensor.matrix(n, n);
        for (0..n) |i| {
            t.set2D(i, i, 1.0);
        }
        return t;
    }

    /// Create tensor of zeros
    pub fn zeros(shape_slice: []const usize) Self {
        return Tensor.init(shape_slice);
    }

    /// Create tensor of ones
    pub fn ones(shape_slice: []const usize) Self {
        const t = Tensor.init(shape_slice);
        for (0..t.size()) |i| {
            t.data[i] = 1.0;
        }
        return t;
    }

    /// Element-wise addition
    pub fn add(self: Self, other: Self) ?Self {
        if (self.rank != other.rank) return null;
        for (0..self.rank) |i| {
            if (self.shape[i] != other.shape[i]) return null;
        }

        const result = Tensor.init(self.shape);
        for (0..self.size()) |i| {
            result.data[i] = self.data[i] + other.data[i];
        }
        return result;
    }

    /// Element-wise subtraction
    pub fn subtract(self: Self, other: Self) ?Self {
        if (self.rank != other.rank) return null;
        for (0..self.rank) |i| {
            if (self.shape[i] != other.shape[i]) return null;
        }

        const result = Tensor.init(self.shape);
        for (0..self.size()) |i| {
            result.data[i] = self.data[i] - other.data[i];
        }
        return result;
    }

    /// Element-wise multiplication
    pub fn multiply(self: Self, other: Self) ?Self {
        if (self.rank != other.rank) return null;
        for (0..self.rank) |i| {
            if (self.shape[i] != other.shape[i]) return null;
        }

        const result = Tensor.init(self.shape);
        for (0..self.size()) |i| {
            result.data[i] = self.data[i] * other.data[i];
        }
        return result;
    }

    /// Element-wise division
    pub fn divide(self: Self, other: Self) ?Self {
        if (self.rank != other.rank) return null;
        for (0..self.rank) |i| {
            if (self.shape[i] != other.shape[i]) return null;
        }

        const result = Tensor.init(self.shape);
        for (0..self.size()) |i| {
            if (other.data[i] == 0) return null; // Division by zero
            result.data[i] = self.data[i] / other.data[i];
        }
        return result;
    }

    /// Matrix multiplication for 2D tensors (matrices)
    /// For self[m×n] @ other[n×p], returns result[m×p]
    /// Uses blocked algorithm for better cache locality
    pub fn matmul(self: Self, other: Self) ?Self {
        if (self.rank != 2 or other.rank != 2) return null;
        if (self.shape[1] != other.shape[0]) return null;

        const m = self.shape[0];
        const n = self.shape[1];
        const p = other.shape[1];

        var result_shape = [_]usize{m, p};
        const result = Tensor.init(&result_shape);

        const block_size = 64;
        
        if (m < block_size or n < block_size or p < block_size) {
            // Simple algorithm for small tensors
            for (0..m) |i| {
                for (0..p) |j| {
                    var accum: f64 = 0;
                    for (0..n) |k| {
                        const a_val = self.get2D(i, k);
                        const b_val = other.get2D(k, j);
                        accum += a_val * b_val;
                    }
                    result.set2D(i, j, accum);
                }
            }
        } else {
            // Blocked algorithm for large tensors
            var bi: usize = 0;
            while (bi < m) : (bi += block_size) {
                const bi_end = @min(bi + block_size, m);
                
                var bj: usize = 0;
                while (bj < p) : (bj += block_size) {
                    const bj_end = @min(bj + block_size, p);
                    
                    var bk: usize = 0;
                    while (bk < n) : (bk += block_size) {
                        const bk_end = @min(bk + block_size, n);
                        
                        // Compute block
                        var i = bi;
                        while (i < bi_end) : (i += 1) {
                            var j = bj;
                            while (j < bj_end) : (j += 1) {
                                var sum: f64 = 0;
                                var k = bk;
                                while (k < bk_end) : (k += 1) {
                                    sum += self.get2D(i, k) * other.get2D(k, j);
                                }
                                result.set2D(i, j, result.get2D(i, j) + sum);
                            }
                        }
                    }
                }
            }
        }
        return result;
    }

    /// Scalar addition
    pub fn addScalar(self: Self, scalar: f64) Self {
        const result = Tensor.init(self.shape);
        for (0..self.size()) |i| {
            result.data[i] = self.data[i] + scalar;
        }
        return result;
    }

    /// Scalar multiplication
    pub fn scalarMultiply(self: Self, scalar: f64) Self {
        const result = Tensor.init(self.shape);
        for (0..self.size()) |i| {
            result.data[i] = self.data[i] * scalar;
        }
        return result;
    }

    /// Sum of all elements
    pub fn sum(self: Self) f64 {
        var total: f64 = 0;
        for (0..self.size()) |i| {
            total += self.data[i];
        }
        return total;
    }

    /// Mean of all elements
    pub fn mean(self: Self) f64 {
        if (self.size() == 0) return 0;
        return self.sum() / @as(f64, @floatFromInt(self.size()));
    }

    /// Reshape tensor to new shape (must have same total size)
    pub fn reshape(self: Self, new_shape_slice: []const usize) ?Self {
        var new_size: usize = 1;
        for (new_shape_slice) |dim| {
            new_size *= dim;
        }

        if (new_size != self.size()) {
            return null; // Size mismatch
        }

        const result = Tensor.init(new_shape_slice);
        for (0..self.size()) |i| {
            result.data[i] = self.data[i];
        }
        return result;
    }

    /// Squeeze out dimensions of size 1
    pub fn squeeze(self: Self) Self {
        var new_shape_list: [32]usize = undefined;
        var new_rank: usize = 0;

        for (0..self.rank) |i| {
            if (self.shape[i] != 1) {
                new_shape_list[new_rank] = self.shape[i];
                new_rank += 1;
            }
        }

        if (new_rank == 0) {
            // All dimensions are 1, result is scalar - create 1D tensor of size 1
            new_shape_list[0] = 1;
            new_rank = 1;
        }

        const result = Tensor.init(new_shape_list[0..new_rank]);
        for (0..self.size()) |i| {
            result.data[i] = self.data[i];
        }
        return result;
    }

    /// Flatten to 1D tensor
    pub fn flatten(self: Self) Self {
        const shape = &[_]usize{self.size()};
        const result = Tensor.init(shape);
        for (0..self.size()) |i| {
            result.data[i] = self.data[i];
        }
        return result;
    }

    /// Transpose 2D tensor (swap rows and columns)
    pub fn transpose(self: Self) ?Self {
        if (self.rank != 2) return null;

        const rows = self.shape[0];
        const cols = self.shape[1];
        const shape = &[_]usize{ cols, rows };
        const result = Tensor.init(shape);

        for (0..rows) |i| {
            for (0..cols) |j| {
                result.set2D(j, i, self.get2D(i, j));
            }
        }

        return result;
    }

    /// Deallocate tensor
    pub fn deinit(self: Self) void {
        const allocator = mem_utils.getAllocator();
        if (self.data.len > 0) {
            mem_utils.free(allocator, self.data);
        }
        if (self.shape.len > 0) {
            mem_utils.free(allocator, self.shape);
        }
        if (self.stride.len > 0) {
            mem_utils.free(allocator, self.stride);
        }
        const self_slice = @as([*]u8, @ptrCast(self))[0..@sizeOf(Tensor)];
        mem_utils.free(allocator, self_slice);
    }

    /// Print tensor (basic formatting)
    pub fn print(self: Self) void {
        if (self.rank == 1) {
            std.debug.print("[", .{});
            for (0..self.shape[0]) |i| {
                if (i > 0) std.debug.print(", ", .{});
                std.debug.print("{d:.2}", .{self.get1D(i)});
            }
            std.debug.print("]", .{});
        } else if (self.rank == 2) {
            std.debug.print("[\n", .{});
            for (0..self.shape[0]) |i| {
                std.debug.print("  [", .{});
                for (0..self.shape[1]) |j| {
                    if (j > 0) std.debug.print(", ", .{});
                    std.debug.print("{d:.2}", .{self.get2D(i, j)});
                }
                std.debug.print("]\n", .{});
            }
            std.debug.print("]", .{});
        } else {
            std.debug.print("Tensor({}-D: shape=[", .{self.rank});
            for (0..self.rank) |i| {
                if (i > 0) std.debug.print("×", .{});
                std.debug.print("{}", .{self.shape[i]});
            }
            std.debug.print("])", .{});
        }
    }
};
