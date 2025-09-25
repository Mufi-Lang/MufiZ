const std = @import("std");
const obj_h = @import("obj.zig");
const Obj = obj_h.Obj;
const allocateObject = @import("../object.zig").allocateObject;
const reallocate = @import("../memory.zig").reallocate;

/// A multi-dimensional tensor implementation that can replace both FVec and Matrix.
/// Supports 1D (vector), 2D (matrix), and 3D operations with flexible dimensionality.
pub const Tensor = struct {
    obj: Obj,
    order: u8,      // Tensor order (1D, 2D, 3D)
    dim1: usize,    // First dimension (always present)
    dim2: usize,    // Second dimension (0 if not used)
    dim3: usize,    // Third dimension (0 if not used)
    ptr: [*]f64,    // Data pointer

    const Self = *@This();

    /// Initialize a 1D tensor (vector)
    pub fn init1D(size: usize) Self {
        const tensor: Self = @ptrCast(@alignCast(allocateObject(@sizeOf(Tensor), .OBJ_TENSOR)));
        tensor.order = 1;
        tensor.dim1 = size;
        tensor.dim2 = 0;
        tensor.dim3 = 0;
        
        const total_size = size;
        const byte_size = @sizeOf(f64) * total_size;
        const raw_ptr = reallocate(null, 0, byte_size);
        if (raw_ptr == null) {
            std.debug.print("Failed to allocate memory for Tensor data\n", .{});
            std.process.exit(1);
        }
        tensor.ptr = @as([*]f64, @ptrCast(@alignCast(raw_ptr.?)));
        
        // Initialize data to zero
        for (0..total_size) |i| {
            tensor.ptr[i] = 0.0;
        }
        
        return tensor;
    }

    /// Initialize a 2D tensor (matrix)
    pub fn init2D(rows: usize, cols: usize) Self {
        const tensor: Self = @ptrCast(@alignCast(allocateObject(@sizeOf(Tensor), .OBJ_TENSOR)));
        tensor.order = 2;
        tensor.dim1 = rows;
        tensor.dim2 = cols;
        tensor.dim3 = 0;
        
        const total_size = rows * cols;
        const byte_size = @sizeOf(f64) * total_size;
        const raw_ptr = reallocate(null, 0, byte_size);
        if (raw_ptr == null) {
            std.debug.print("Failed to allocate memory for Tensor data\n", .{});
            std.process.exit(1);
        }
        tensor.ptr = @as([*]f64, @ptrCast(@alignCast(raw_ptr.?)));
        
        // Initialize data to zero
        for (0..total_size) |i| {
            tensor.ptr[i] = 0.0;
        }
        
        return tensor;
    }

    /// Initialize a 3D tensor
    pub fn init3D(dim1: usize, dim2: usize, dim3: usize) Self {
        const tensor: Self = @ptrCast(@alignCast(allocateObject(@sizeOf(Tensor), .OBJ_TENSOR)));
        tensor.order = 3;
        tensor.dim1 = dim1;
        tensor.dim2 = dim2;
        tensor.dim3 = dim3;
        
        const total_size = dim1 * dim2 * dim3;
        const byte_size = @sizeOf(f64) * total_size;
        const raw_ptr = reallocate(null, 0, byte_size);
        if (raw_ptr == null) {
            std.debug.print("Failed to allocate memory for Tensor data\n", .{});
            std.process.exit(1);
        }
        tensor.ptr = @as([*]f64, @ptrCast(@alignCast(raw_ptr.?)));
        
        // Initialize data to zero
        for (0..total_size) |i| {
            tensor.ptr[i] = 0.0;
        }
        
        return tensor;
    }

    /// Get total number of elements in the tensor
    pub fn totalSize(self: Self) usize {
        return switch (self.order) {
            1 => self.dim1,
            2 => self.dim1 * self.dim2,
            3 => self.dim1 * self.dim2 * self.dim3,
            else => 0,
        };
    }

    /// Get element from 1D tensor
    pub fn get1D(self: Self, i: usize) f64 {
        if (self.order != 1 or i >= self.dim1) return 0.0;
        return self.ptr[i];
    }

    /// Set element in 1D tensor
    pub fn set1D(self: Self, i: usize, value: f64) void {
        if (self.order != 1 or i >= self.dim1) return;
        self.ptr[i] = value;
    }

    /// Get element from 2D tensor
    pub fn get2D(self: Self, i: usize, j: usize) f64 {
        if (self.order != 2 or i >= self.dim1 or j >= self.dim2) return 0.0;
        const index = i * self.dim2 + j;
        return self.ptr[index];
    }

    /// Set element in 2D tensor
    pub fn set2D(self: Self, i: usize, j: usize, value: f64) void {
        if (self.order != 2 or i >= self.dim1 or j >= self.dim2) return;
        const index = i * self.dim2 + j;
        self.ptr[index] = value;
    }

    /// Get element from 3D tensor
    pub fn get3D(self: Self, i: usize, j: usize, k: usize) f64 {
        if (self.order != 3 or i >= self.dim1 or j >= self.dim2 or k >= self.dim3) return 0.0;
        const index = i * (self.dim2 * self.dim3) + j * self.dim3 + k;
        return self.ptr[index];
    }

    /// Set element in 3D tensor
    pub fn set3D(self: Self, i: usize, j: usize, k: usize, value: f64) void {
        if (self.order != 3 or i >= self.dim1 or j >= self.dim2 or k >= self.dim3) return;
        const index = i * (self.dim2 * self.dim3) + j * self.dim3 + k;
        self.ptr[index] = value;
    }

    /// Deallocate tensor memory
    pub fn deinit(self: Self) void {
        const total_size = self.totalSize();
        if (total_size > 0) {
            _ = reallocate(@as(?*anyopaque, @ptrCast(self.ptr)), @sizeOf(f64) * total_size, 0);
        }
        _ = reallocate(@as(?*anyopaque, @ptrCast(self)), @sizeOf(Tensor), 0);
    }

    /// Print tensor contents
    pub fn print(self: Self) void {
        switch (self.order) {
            1 => {
                std.debug.print("[", .{});
                for (0..self.dim1) |i| {
                    std.debug.print("{d:.2}", .{self.ptr[i]});
                    if (i < self.dim1 - 1) std.debug.print(", ", .{});
                }
                std.debug.print("]\n", .{});
            },
            2 => {
                std.debug.print("[\n", .{});
                for (0..self.dim1) |i| {
                    std.debug.print("  [", .{});
                    for (0..self.dim2) |j| {
                        const index = i * self.dim2 + j;
                        std.debug.print("{d:.2}", .{self.ptr[index]});
                        if (j < self.dim2 - 1) std.debug.print(", ", .{});
                    }
                    std.debug.print("]", .{});
                    if (i < self.dim1 - 1) std.debug.print(",", .{});
                    std.debug.print("\n", .{});
                }
                std.debug.print("]\n", .{});
            },
            3 => {
                std.debug.print("[\n", .{});
                for (0..self.dim1) |i| {
                    std.debug.print("  [\n", .{});
                    for (0..self.dim2) |j| {
                        std.debug.print("    [", .{});
                        for (0..self.dim3) |k| {
                            const index = i * (self.dim2 * self.dim3) + j * self.dim3 + k;
                            std.debug.print("{d:.2}", .{self.ptr[index]});
                            if (k < self.dim3 - 1) std.debug.print(", ", .{});
                        }
                        std.debug.print("]", .{});
                        if (j < self.dim2 - 1) std.debug.print(",", .{});
                        std.debug.print("\n", .{});
                    }
                    std.debug.print("  ]", .{});
                    if (i < self.dim1 - 1) std.debug.print(",", .{});
                    std.debug.print("\n", .{});
                }
                std.debug.print("]\n", .{});
            },
            else => {
                std.debug.print("Invalid tensor order: {}\n", .{self.order});
            },
        }
    }

    /// Clone tensor
    pub fn clone(self: Self) Self {
        const result = switch (self.order) {
            1 => Tensor.init1D(self.dim1),
            2 => Tensor.init2D(self.dim1, self.dim2),
            3 => Tensor.init3D(self.dim1, self.dim2, self.dim3),
            else => unreachable,
        };
        
        const total_size = self.totalSize();
        for (0..total_size) |i| {
            result.ptr[i] = self.ptr[i];
        }
        
        return result;
    }

    /// Fill tensor with a constant value
    pub fn fill(self: Self, value: f64) void {
        const total_size = self.totalSize();
        for (0..total_size) |i| {
            self.ptr[i] = value;
        }
    }

    /// Add scalar to all elements
    pub fn addScalar(self: Self, scalar: f64) Self {
        const result = self.clone();
        const total_size = self.totalSize();
        for (0..total_size) |i| {
            result.ptr[i] += scalar;
        }
        return result;
    }

    /// Multiply all elements by scalar
    pub fn scale(self: Self, scalar: f64) Self {
        const result = self.clone();
        const total_size = self.totalSize();
        for (0..total_size) |i| {
            result.ptr[i] *= scalar;
        }
        return result;
    }

    /// Element-wise addition of two tensors (must have same dimensions)
    pub fn add(self: Self, other: Self) ?Self {
        if (self.order != other.order or 
            self.dim1 != other.dim1 or 
            self.dim2 != other.dim2 or 
            self.dim3 != other.dim3) {
            return null; // Incompatible dimensions
        }
        
        const result = self.clone();
        const total_size = self.totalSize();
        for (0..total_size) |i| {
            result.ptr[i] += other.ptr[i];
        }
        return result;
    }

    /// Element-wise subtraction of two tensors
    pub fn subtract(self: Self, other: Self) ?Self {
        if (self.order != other.order or 
            self.dim1 != other.dim1 or 
            self.dim2 != other.dim2 or 
            self.dim3 != other.dim3) {
            return null; // Incompatible dimensions
        }
        
        const result = self.clone();
        const total_size = self.totalSize();
        for (0..total_size) |i| {
            result.ptr[i] -= other.ptr[i];
        }
        return result;
    }

    /// Dot product for 1D tensors
    pub fn dot(self: Self, other: Self) ?f64 {
        if (self.order != 1 or other.order != 1 or self.dim1 != other.dim1) {
            return null;
        }
        
        var result: f64 = 0.0;
        for (0..self.dim1) |i| {
            result += self.ptr[i] * other.ptr[i];
        }
        return result;
    }

    /// Matrix multiplication for 2D tensors
    pub fn matmul(self: Self, other: Self) ?Self {
        if (self.order != 2 or other.order != 2 or self.dim2 != other.dim1) {
            return null; // Invalid dimensions for matrix multiplication
        }
        
        const result = Tensor.init2D(self.dim1, other.dim2);
        for (0..self.dim1) |i| {
            for (0..other.dim2) |j| {
                var sum: f64 = 0.0;
                for (0..self.dim2) |k| {
                    const a_val = self.get2D(i, k);
                    const b_val = other.get2D(k, j);
                    sum += a_val * b_val;
                }
                result.set2D(i, j, sum);
            }
        }
        return result;
    }

    /// Transpose a 2D tensor
    pub fn transpose(self: Self) ?Self {
        if (self.order != 2) return null;
        
        const result = Tensor.init2D(self.dim2, self.dim1);
        for (0..self.dim1) |i| {
            for (0..self.dim2) |j| {
                const value = self.get2D(i, j);
                result.set2D(j, i, value);
            }
        }
        return result;
    }
};