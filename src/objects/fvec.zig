const std = @import("std");

const reallocate = @import("../memory.zig").reallocate;
const allocateObject = @import("../object.zig").allocateObject;
const obj_h = @import("obj.zig");
const Obj = obj_h.Obj;

/// A dynamic vector implementation for floating point numbers.
/// It provides automatic resizing when capacity is exhausted.
pub const FloatVector = struct {
    obj: Obj,
    size: usize, // Current capacity
    count: usize, // Current number of elements
    pos: usize, // Current position for iterator methods
    data: []f64, // Underlying data storage
    sorted: bool, // Whether the vector is sorted
    rows: usize, // Number of rows (for 2D matrix support)
    cols: usize, // Number of columns (for 2D matrix support)

    const Self = *@This();

    /// Creates a new float vector with the specified initial capacity.
    /// The vector will grow automatically as needed when elements are added.
    /// @param initial_capacity The initial capacity of the vector. If 0, a default capacity of 8 will be used.
    pub fn init(initial_capacity: usize) Self {
        const vector: Self = @ptrCast(@alignCast(allocateObject(@sizeOf(FloatVector), .OBJ_FVECTOR)));
        // Default initial capacity if none specified
        const capacity = if (initial_capacity == 0) 8 else initial_capacity;
        vector.size = capacity;
        vector.count = 0;
        vector.pos = 0;
        vector.sorted = false;
        vector.rows = 0; // 1D vector by default, will be set when elements are added
        vector.cols = 1; // Treat as n x 1 column vector by default

        const byte_size = @sizeOf(f64) * capacity;
        const raw_ptr = reallocate(null, 0, byte_size);
        if (raw_ptr == null) {
            std.debug.print("Failed to reallocate memory for FloatVector data\n", .{});
            std.process.exit(1);
        }
        vector.data = @as([*]f64, @ptrCast(@alignCast(raw_ptr.?)))[0..capacity];

        return vector;
    }

    /// Creates a new float vector with the default capacity (8).
    pub fn new() Self {
        return FloatVector.init(8);
    }

    /// Creates an empty vector with minimal initial allocation.
    /// The vector will still grow automatically when elements are added.
    pub fn initEmpty() Self {
        return FloatVector.init(0);
    }

    /// Creates a new matrix with the specified dimensions.
    /// Elements are initialized to zero.
    /// @param rows Number of rows in the matrix
    /// @param cols Number of columns in the matrix
    pub fn initMatrix(rows: usize, cols: usize) Self {
        const total_size = rows * cols;
        const vector: Self = @ptrCast(@alignCast(allocateObject(@sizeOf(FloatVector), .OBJ_FVECTOR)));
        vector.size = total_size;
        vector.count = total_size;
        vector.pos = 0;
        vector.sorted = false;
        vector.rows = rows;
        vector.cols = cols;

        const byte_size = @sizeOf(f64) * total_size;
        const raw_ptr = reallocate(null, 0, byte_size);
        if (raw_ptr == null) {
            std.debug.print("Failed to reallocate memory for FloatVector data\n", .{});
            std.process.exit(1);
        }
        vector.data = @as([*]f64, @ptrCast(@alignCast(raw_ptr.?)))[0..total_size];
        
        // Initialize all elements to zero
        @memset(vector.data, 0.0);

        return vector;
    }

    /// Creates an identity matrix of the specified size.
    /// @param size Dimension of the square matrix (size x size)
    pub fn identity(size: usize) Self {
        const matrix = FloatVector.initMatrix(size, size);
        for (0..size) |i| {
            matrix.data[i * size + i] = 1.0;
        }
        return matrix;
    }

    /// Creates a matrix filled with zeros.
    /// @param rows Number of rows
    /// @param cols Number of columns
    pub fn zeros(rows: usize, cols: usize) Self {
        return FloatVector.initMatrix(rows, cols);
    }

    /// Creates a matrix filled with ones.
    /// @param rows Number of rows
    /// @param cols Number of columns
    pub fn ones(rows: usize, cols: usize) Self {
        const matrix = FloatVector.initMatrix(rows, cols);
        for (0..matrix.count) |i| {
            matrix.data[i] = 1.0;
        }
        return matrix;
    }

    /// Check if this is a matrix (2D) or a vector (1D)
    pub fn isMatrix(self: Self) bool {
        return self.rows > 0 and self.cols > 0;
    }

    /// Check if this is a 1D vector
    pub fn isVector(self: Self) bool {
        return self.cols == 1 or self.rows == 0;
    }

    pub fn deinit(self: Self) void {
        if (self.data.len > 0) {
            _ = reallocate(@as(?*anyopaque, @ptrCast(self.data.ptr)), @sizeOf(f64) * self.data.len, 0);
        }
        _ = reallocate(@as(?*anyopaque, @ptrCast(self)), @sizeOf(FloatVector), 0);
    }

    pub fn print(self: Self) void {
        if (self.isMatrix() and self.rows > 1) {
            // Print as a 2D matrix
            std.debug.print("[\n", .{});
            for (0..self.rows) |i| {
                std.debug.print("  [", .{});
                for (0..self.cols) |j| {
                    const idx = i * self.cols + j;
                    std.debug.print("{d:.2}", .{self.data[idx]});
                    if (j < self.cols - 1) std.debug.print(", ", .{});
                }
                std.debug.print("]", .{});
                if (i < self.rows - 1) std.debug.print(",\n", .{});
            }
            std.debug.print("\n]", .{});
        } else {
            // Print as a 1D vector
            std.debug.print("[", .{});
            for (0..self.count) |i| {
                std.debug.print("{d:.2}", .{self.data[i]});
                if (i < self.count - 1) std.debug.print(", ", .{});
            }
            std.debug.print("]", .{});
        }
    }

    fn write(self: Self, i: usize, val: f64) void {
        if (i >= self.size) return;
        self.data[i] = val;
    }

    fn true_sorted(self: Self) void {
        self.sorted = true;
    }

    fn false_sorted(self: Self) void {
        self.sorted = false;
    }

    fn count_increase(self: Self) void {
        self.count += 1;
    }

    pub fn sort(self: Self) void {
        if (self.count <= 1) return;
        quickSort(self.data, 0, @intCast(self.count - 1));
        self.sorted = true;
    }

    pub fn clone(self: Self) Self {
        // Allocate exactly what we need
        const capacity = if (self.count > 0) self.count else 8;
        const result = FloatVector.init(capacity);
        if (self.count > 0) {
            @memcpy(result.data[0..self.count], self.data[0..self.count]);
        }
        result.count = self.count;
        result.sorted = self.sorted;
        result.rows = self.rows;
        result.cols = self.cols;
        return result;
    }

    pub fn clear(self: Self) void {
        self.count = 0;
        self.pos = 0;
        self.sorted = false;
        // Reset to 1D vector when cleared
        self.rows = 0;
        self.cols = 1;
    }

    /// Clears the vector and optionally shrinks its capacity.
    /// @param shrink If true, capacity will be reduced to match count
    pub fn clearAndShrink(self: Self, shrink: bool) void {
        self.clear();
        if (shrink) {
            self.shrinkToFit(0);
        }
    }

    /// Ensures the vector has at least the needed capacity.
    /// This is called automatically by methods that add elements.
    fn ensureCapacity(self: Self, needed_capacity: usize) void {
        if (self.size >= needed_capacity) return;

        const new_size = @max(needed_capacity, self.size * 2);
        const new_byte_size = @sizeOf(f64) * new_size;
        const old_byte_size = @sizeOf(f64) * self.size;
        const raw_ptr = reallocate(@as(?*anyopaque, @ptrCast(self.data.ptr)), old_byte_size, new_byte_size);
        if (raw_ptr == null) {
            std.debug.print("Failed to reallocate memory for FloatVector data\n", .{});
            std.process.exit(1);
        }
        self.data = @as([*]f64, @ptrCast(@alignCast(raw_ptr.?)))[0..new_size];
        self.size = new_size;
    }

    /// Explicitly reserves capacity for the vector.
    /// Use this to avoid multiple reallocations when you know how many elements you'll add.
    /// @param new_capacity The minimum capacity to ensure
    pub fn reserve(self: Self, new_capacity: usize) void {
        if (new_capacity <= self.size) return;

        self.ensureCapacity(new_capacity);
    }

    /// Shrinks the capacity to match the count plus an optional extra buffer.
    /// Use this to reduce memory usage when the vector won't grow much.
    /// @param extra_buffer Additional capacity to reserve beyond current count
    pub fn shrinkToFit(self: Self, extra_buffer: usize) void {
        if (self.count == 0) {
            if (self.size > 0) {
                _ = reallocate(@as(?*anyopaque, @ptrCast(self.data.ptr)), @sizeOf(f64) * self.size, 0);
                self.data = &[_]f64{};
                self.size = 0;
            }
            return;
        }

        const new_size = self.count + extra_buffer;
        if (new_size >= self.size) return;

        const new_byte_size = @sizeOf(f64) * new_size;
        const old_byte_size = @sizeOf(f64) * self.size;
        const raw_ptr = reallocate(@as(?*anyopaque, @ptrCast(self.data.ptr)), old_byte_size, new_byte_size);
        if (raw_ptr == null) {
            std.debug.print("Failed to reallocate memory for FloatVector data\n", .{});
            std.process.exit(1);
        }
        self.data = @as([*]f64, @ptrCast(@alignCast(raw_ptr.?)))[0..new_size];
        self.size = new_size;
    }

    pub fn push(self: Self, value: f64) void {
        if (self.count >= self.size) {
            self.ensureCapacity(self.count + 1);
        }
        self.data[self.count] = value;
        self.count += 1;
        self.sorted = false;
        // Update rows when pushing to 1D vector
        if (self.cols == 1) {
            self.rows = self.count;
        }
    }

    /// Adds multiple values to the vector in a single operation.
    /// This is more efficient than calling push() multiple times.
    /// @param values Slice of values to add to the vector
    pub fn pushMany(self: Self, values: []const f64) void {
        if (values.len == 0) return;

        // Ensure we have enough space for all values
        if (self.count + values.len > self.size) {
            self.ensureCapacity(self.count + values.len);
        }

        // Copy all values at once
        @memcpy(self.data[self.count .. self.count + values.len], values);
        self.count += values.len;
        self.sorted = false;
        // Update rows when pushing to 1D vector
        if (self.cols == 1) {
            self.rows = self.count;
        }
    }

    pub fn insert(self: Self, index: usize, value: f64) void {
        if (index > self.count) return;

        if (self.count >= self.size) {
            self.ensureCapacity(self.count + 1);
        }

        var i = self.count;
        while (i > index) {
            self.data[i] = self.data[i - 1];
            i -= 1;
        }
        self.data[index] = value;
        self.count += 1;
        self.sorted = false;
    }

    pub fn get(self: Self, index: usize) f64 {
        if (index >= self.count) return 0.0;
        return self.data[index];
    }

    pub fn set(self: Self, index: usize, value: f64) void {
        if (index >= self.count) return;
        self.data[index] = value;
    }

    pub fn pop(self: Self) f64 {
        if (self.count == 0) return 0.0;
        self.count -= 1;
        return self.data[self.count];
    }

    pub fn remove(self: Self, index: usize) f64 {
        if (index >= self.count) return 0.0;

        const removedValue = self.data[index];

        for (index..self.count - 1) |i| {
            self.data[i] = self.data[i + 1];
        }

        self.count -= 1;
        return removedValue;
    }

    pub fn merge(self: Self, other: Self) Self {
        const total_count = self.count + other.count;
        // Start with a small capacity if both are empty
        const initial_capacity = if (total_count > 0) total_count else 8;
        const result = FloatVector.init(initial_capacity);

        // Pre-reserve the capacity to avoid multiple resizes
        result.ensureCapacity(total_count);

        for (0..self.count) |i| {
            result.push(self.data[i]);
        }
        for (0..other.count) |i| {
            result.push(other.data[i]);
        }
        return result;
    }

    pub fn slice(self: Self, start: usize, end: usize) Self {
        if (start >= self.count or end >= self.count or start > end) {
            std.debug.print("Index out of bounds\n", .{});
            return FloatVector.new();
        }

        const slice_size = end - start + 1;
        const result = FloatVector.init(slice_size);
        result.count = slice_size;

        @memcpy(result.data[0..slice_size], self.data[start .. end + 1]);
        return result;
    }

    pub fn splice(self: Self, start: usize, end: usize) Self {
        if (start >= self.count or end >= self.count or start > end) {
            std.debug.print("Index out of bounds\n", .{});
            return FloatVector.new();
        }

        const splice_size = self.count - (end - start + 1);
        const result = FloatVector.init(splice_size);

        if (start > 0) {
            @memcpy(result.data[0..start], self.data[0..start]);
        }

        if (end + 1 < self.count) {
            @memcpy(result.data[start..splice_size], self.data[end + 1 .. self.count]);
        }

        result.count = splice_size;
        return result;
    }

    pub fn sum(self: Self) f64 {
        const len = self.count;
        const Vec4 = @Vector(4, f64);
        var sum_vec: Vec4 = @splat(@as(f64, 0.0));

        // Process elements in chunks of 4
        const vec_iterations = @divTrunc(len, 4);
        var i: usize = 0;
        while (i < vec_iterations) : (i += 1) {
            const offset = i * 4;
            // Load 4 elements into a vector
            const data_vec = Vec4{
                self.data[offset],
                self.data[offset + 1],
                self.data[offset + 2],
                self.data[offset + 3],
            };
            sum_vec += data_vec;
        }

        // Sum up the vector elements
        var sum_value: f64 = @reduce(.Add, sum_vec);

        // Handle remaining elements
        const remaining = @mod(len, 4);
        if (remaining > 0) {
            const start = len - remaining;
            for (start..len) |j| {
                sum_value += self.data[j];
            }
        }

        return sum_value;
    }

    pub fn mean(self: Self) f64 {
        return FloatVector.sum(self) / @as(f64, @floatFromInt(self.count));
    }

    pub fn variance(self: Self) f64 {
        if (self.count == 0) return 0.0;
        const mean_val = FloatVector.mean(self);

        const len = self.count;
        const Vec4 = @Vector(4, f64);
        var sum_vec: Vec4 = @splat(@as(f64, 0.0));

        // Process elements in chunks of 4
        const vec_iterations = @divTrunc(len, 4);
        var i: usize = 0;
        while (i < vec_iterations) : (i += 1) {
            const offset = i * 4;
            // Load 4 elements into a vector
            const diff_vec = Vec4{
                self.data[offset] - mean_val,
                self.data[offset + 1] - mean_val,
                self.data[offset + 2] - mean_val,
                self.data[offset + 3] - mean_val,
            };
            sum_vec += diff_vec * diff_vec;
        }

        // Sum up the vector elements
        var sum_value: f64 = @reduce(.Add, sum_vec);

        // Handle remaining elements
        const remaining = @mod(len, 4);
        if (remaining > 0) {
            const start = len - remaining;
            for (start..len) |j| {
                const diff = self.data[j] - mean_val;
                sum_value += diff * diff;
            }
        }

        return sum_value / @as(f64, @floatFromInt(self.count - 1));
    }

    pub fn std_dev(self: Self) f64 {
        return @sqrt(FloatVector.variance(self));
    }

    pub fn max(self: Self) f64 {
        if (self.count == 0) return 0.0;
        var max_val = self.data[0];
        for (1..self.count) |i| {
            if (self.data[i] > max_val) max_val = self.data[i];
        }
        return max_val;
    }

    pub fn min(self: Self) f64 {
        if (self.count == 0) return 0.0;
        var min_val = self.data[0];
        for (1..self.count) |i| {
            if (self.data[i] < min_val) min_val = self.data[i];
        }
        return min_val;
    }

    pub fn add(a: Self, b: Self) Self {
        const min_count = @min(a.count, b.count);
        const result = FloatVector.init(min_count);

        // Process elements in chunks of 4 using SIMD
        const Vec4 = @Vector(4, f64);
        const vec_iterations = @divTrunc(min_count, 4);

        var i: usize = 0;
        while (i < vec_iterations) : (i += 1) {
            const offset = i * 4;

            // Load 4 elements from each vector
            const vec1 = Vec4{
                a.data[offset],
                a.data[offset + 1],
                a.data[offset + 2],
                a.data[offset + 3],
            };

            const vec2 = Vec4{
                b.data[offset],
                b.data[offset + 1],
                b.data[offset + 2],
                b.data[offset + 3],
            };

            // Add vectors and store result
            const sum_result = vec1 + vec2;
            result.data[offset] = sum_result[0];
            result.data[offset + 1] = sum_result[1];
            result.data[offset + 2] = sum_result[2];
            result.data[offset + 3] = sum_result[3];
        }

        // Handle remaining elements
        const remaining = @mod(min_count, 4);
        if (remaining > 0) {
            const start = min_count - remaining;
            for (start..min_count) |j| {
                result.data[j] = a.data[j] + b.data[j];
            }
        }

        result.count = min_count;
        return result;
    }

    pub fn sub(a: Self, b: Self) Self {
        const min_count = @min(a.count, b.count);
        const result = FloatVector.init(min_count);

        // Process elements in chunks of 4 using SIMD
        const Vec4 = @Vector(4, f64);
        const vec_iterations = @divTrunc(min_count, 4);

        var i: usize = 0;
        while (i < vec_iterations) : (i += 1) {
            const offset = i * 4;

            // Load 4 elements from each vector
            const vec1 = Vec4{
                a.data[offset],
                a.data[offset + 1],
                a.data[offset + 2],
                a.data[offset + 3],
            };

            const vec2 = Vec4{
                b.data[offset],
                b.data[offset + 1],
                b.data[offset + 2],
                b.data[offset + 3],
            };

            // Subtract vectors and store result
            const diff = vec1 - vec2;
            result.data[offset] = diff[0];
            result.data[offset + 1] = diff[1];
            result.data[offset + 2] = diff[2];
            result.data[offset + 3] = diff[3];
        }

        // Handle remaining elements
        const remaining = @mod(min_count, 4);
        if (remaining > 0) {
            const start = min_count - remaining;
            for (start..min_count) |j| {
                result.data[j] = a.data[j] - b.data[j];
            }
        }

        result.count = min_count;
        return result;
    }

    pub fn mul(a: Self, b: Self) Self {
        const min_count = @min(a.count, b.count);
        const result = FloatVector.init(min_count);

        // Process elements in chunks of 4 using SIMD
        const Vec4 = @Vector(4, f64);
        const vec_iterations = @divTrunc(min_count, 4);

        var i: usize = 0;
        while (i < vec_iterations) : (i += 1) {
            const offset = i * 4;

            // Load 4 elements from each vector
            const vec1 = Vec4{
                a.data[offset],
                a.data[offset + 1],
                a.data[offset + 2],
                a.data[offset + 3],
            };

            const vec2 = Vec4{
                b.data[offset],
                b.data[offset + 1],
                b.data[offset + 2],
                b.data[offset + 3],
            };

            // Multiply vectors and store result
            const prod = vec1 * vec2;
            result.data[offset] = prod[0];
            result.data[offset + 1] = prod[1];
            result.data[offset + 2] = prod[2];
            result.data[offset + 3] = prod[3];
        }

        // Handle remaining elements
        const remaining = @mod(min_count, 4);
        if (remaining > 0) {
            const start = min_count - remaining;
            for (start..min_count) |j| {
                result.data[j] = a.data[j] * b.data[j];
            }
        }

        result.count = min_count;
        return result;
    }

    pub fn div(a: Self, b: Self) Self {
        const min_count = @min(a.count, b.count);
        const result = FloatVector.init(min_count);

        // Process elements in chunks of 4 using SIMD
        const Vec4 = @Vector(4, f64);
        const vec_iterations = @divTrunc(min_count, 4);

        var i: usize = 0;
        while (i < vec_iterations) : (i += 1) {
            const offset = i * 4;

            // Load 4 elements from each vector
            const vec1 = Vec4{
                a.data[offset],
                a.data[offset + 1],
                a.data[offset + 2],
                a.data[offset + 3],
            };

            const vec2 = Vec4{
                b.data[offset],
                b.data[offset + 1],
                b.data[offset + 2],
                b.data[offset + 3],
            };

            // Divide vectors and store result
            const quotient = vec1 / vec2;
            result.data[offset] = quotient[0];
            result.data[offset + 1] = quotient[1];
            result.data[offset + 2] = quotient[2];
            result.data[offset + 3] = quotient[3];
        }

        // Handle remaining elements
        const remaining = @mod(min_count, 4);
        if (remaining > 0) {
            const start = min_count - remaining;
            for (start..min_count) |j| {
                if (b.data[j] != 0.0) {
                    result.data[j] = a.data[j] / b.data[j];
                } else {
                    result.data[j] = 0.0;
                }
            }
        }

        result.count = min_count;
        return result;
    }

    pub fn equal(a: Self, b: Self) bool {
        if (a.count != b.count) return false;

        for (0..a.count) |i| {
            if (a.data[i] != b.data[i]) return false;
        }
        return true;
    }

    pub fn scale(self: Self, scalar: f64) Self {
        const result = FloatVector.init(self.count);
        const simdSize = self.count - @mod(self.count, 4);

        // Process 4 elements at a time using Zig SIMD
        var i: usize = 0;
        while (i < simdSize) : (i += 4) {
            const vec4 = @Vector(4, f64){
                self.data[i],
                self.data[i + 1],
                self.data[i + 2],
                self.data[i + 3],
            };
            const scaled = vec4 * @as(@Vector(4, f64), @splat(scalar));

            result.data[i] = scaled[0];
            result.data[i + 1] = scaled[1];
            result.data[i + 2] = scaled[2];
            result.data[i + 3] = scaled[3];
        }

        // Process remaining elements
        i = simdSize;
        while (i < self.count) : (i += 1) {
            result.data[i] = self.data[i] * scalar;
        }

        result.count = self.count;
        return result;
    }

    pub fn single_add(self: Self, scalar: f64) Self {
        const result = FloatVector.init(self.count);
        const simdSize = self.count - @mod(self.count, 4);

        // Process 4 elements at a time using Zig SIMD
        var i: usize = 0;
        while (i < simdSize) : (i += 4) {
            const vec4 = @Vector(4, f64){
                self.data[i],
                self.data[i + 1],
                self.data[i + 2],
                self.data[i + 3],
            };
            const added = vec4 + @as(@Vector(4, f64), @splat(scalar));

            result.data[i] = added[0];
            result.data[i + 1] = added[1];
            result.data[i + 2] = added[2];
            result.data[i + 3] = added[3];
        }

        // Process remaining elements
        i = simdSize;
        while (i < self.count) : (i += 1) {
            result.data[i] = self.data[i] + scalar;
        }

        result.count = self.count;
        return result;
    }

    pub fn single_sub(self: Self, scalar: f64) Self {
        return self.single_add(-scalar);
    }

    pub fn single_div(self: Self, scalar: f64) Self {
        return self.scale(1.0 / scalar);
    }

    pub fn reverse(self: Self) void {
        if (self.count <= 1) return;

        var i: usize = 0;
        var j: usize = self.count - 1;
        while (i < j) {
            const temp = self.data[i];
            self.data[i] = self.data[j];
            self.data[j] = temp;
            i += 1;
            j -= 1;
        }
    }

    pub fn next(self: Self) f64 {
        if (self.pos >= self.count) return 0.0;
        const value = self.data[self.pos];
        self.pos += 1;
        return value;
    }

    pub fn has_next(self: Self) bool {
        return self.pos < self.count;
    }

    pub fn peek(self: Self) f64 {
        if (self.pos >= self.count) return 0.0;
        return self.data[self.pos];
    }

    pub fn reset(self: Self) void {
        self.pos = 0;
    }

    pub fn skip(self: Self, amt: usize) void {
        if (self.pos < self.count) self.pos += amt;
    }

    pub fn search(v: Self, value: f64) i32 {
        if (v.sorted) {
            return binary_search(v, value);
        } else {
            for (0..v.count) |i| {
                if (v.data[i] == value) {
                    return @intCast(i);
                }
            }
        }
        return -1;
    }

    pub fn linspace(start: f64, end: f64, n: i32) Self {
        const count: usize = @intCast(@max(n, 0));
        const result: Self = FloatVector.init(count);
        if (count == 0) return result;

        if (count == 1) {
            FloatVector.push(result, start);
            return result;
        }

        const step: f64 = (end - start) / @as(f64, @floatFromInt(count - 1));
        for (0..count) |i| {
            const value = start + (@as(f64, @floatFromInt(i)) * step);
            FloatVector.push(result, value);
        }
        return result;
    }

    pub fn interp1(x: Self, y: Self, x0: f64) f64 {
        if (x.count != y.count or x.count == 0) return 0.0;
        if (x.count == 1) return y.data[0];

        // Find the interpolation interval
        for (0..x.count - 1) |i| {
            if (x0 >= x.data[i] and x0 <= x.data[i + 1]) {
                const t = (x0 - x.data[i]) / (x.data[i + 1] - x.data[i]);
                return y.data[i] + t * (y.data[i + 1] - y.data[i]);
            }
        }

        // Extrapolation
        if (x0 < x.data[0]) {
            return y.data[0];
        } else {
            return y.data[x.count - 1];
        }
    }

    pub fn dot(a: Self, b: Self) f64 {
        const min_count = @min(a.count, b.count);
        var result: f64 = 0.0;
        for (0..min_count) |i| {
            result += a.data[i] * b.data[i];
        }
        return result;
    }

    pub fn cross(a: Self, b: Self) Self {
        if (a.count != 3 or b.count != 3) {
            return FloatVector.init(0);
        }

        const result = FloatVector.init(3);
        FloatVector.push(result, a.data[1] * b.data[2] - a.data[2] * b.data[1]);
        FloatVector.push(result, a.data[2] * b.data[0] - a.data[0] * b.data[2]);
        FloatVector.push(result, a.data[0] * b.data[1] - a.data[1] * b.data[0]);
        return result;
    }

    pub fn magnitude(self: Self) f64 {
        return @sqrt(FloatVector.dot(self, self));
    }

    pub fn normalize(self: Self) Self {
        const mag = FloatVector.magnitude(self);
        if (mag == 0.0) return FloatVector.clone(self);
        return FloatVector.single_div(self, mag);
    }

    pub fn projection(a: Self, b: Self) Self {
        const dot_ab = FloatVector.dot(a, b);
        const dot_bb = FloatVector.dot(b, b);
        if (dot_bb == 0.0) return FloatVector.init(0);
        return FloatVector.scale(b, dot_ab / dot_bb);
    }

    pub fn rejection(a: Self, b: Self) Self {
        const proj = FloatVector.projection(a, b);
        return FloatVector.sub(a, proj);
    }

    pub fn reflection(incident: Self, normal: Self) Self {
        const dot_product = FloatVector.dot(incident, normal);
        const scaled_normal = FloatVector.scale(normal, 2.0 * dot_product);
        return FloatVector.sub(incident, scaled_normal);
    }

    pub fn refraction(incident: Self, normal: Self, eta: f64) Self {
        const dot_product = FloatVector.dot(incident, normal);
        const k = 1.0 - eta * eta * (1.0 - dot_product * dot_product);

        if (k < 0.0) {
            return FloatVector.init(0); // Total internal reflection
        }

        const eta_incident = FloatVector.scale(incident, eta);
        const term = eta * dot_product + @sqrt(k);
        const eta_normal = FloatVector.scale(normal, term);

        return FloatVector.sub(eta_incident, eta_normal);
    }

    pub fn angle(a: Self, b: Self) f64 {
        const dot_product = FloatVector.dot(a, b);
        const mag_a = FloatVector.magnitude(a);
        const mag_b = FloatVector.magnitude(b);

        if (mag_a == 0.0 or mag_b == 0.0) return 0.0;

        const cos_theta = dot_product / (mag_a * mag_b);
        return std.math.acos(@max(-1.0, @min(1.0, cos_theta)));
    }

    pub fn binary_search(vector: Self, value: f64) i32 {
        var left: i32 = 0;
        var right: i32 = @intCast(vector.count - 1);

        while (left <= right) {
            const mid = left + @divTrunc((right - left), 2);
            const mid_value = vector.data[@intCast(mid)];

            if (compare_double(mid_value, value) == 0) {
                return mid;
            } else if (compare_double(mid_value, value) < 0) {
                left = mid + 1;
            } else {
                right = mid - 1;
            }
        }
        return -1;
    }

    // ============ Matrix Operations ============

    /// Get element at (row, col) for matrix access
    pub fn getAt(self: Self, row: usize, col: usize) f64 {
        if (!self.isMatrix() or row >= self.rows or col >= self.cols) {
            return 0.0;
        }
        return self.data[row * self.cols + col];
    }

    /// Set element at (row, col) for matrix access
    pub fn setAt(self: Self, row: usize, col: usize, value: f64) void {
        if (!self.isMatrix() or row >= self.rows or col >= self.cols) {
            return;
        }
        self.data[row * self.cols + col] = value;
    }

    /// Get a row from the matrix as a new vector
    pub fn getRow(self: Self, row: usize) Self {
        if (!self.isMatrix() or row >= self.rows) {
            return FloatVector.init(0);
        }
        
        const result = FloatVector.init(self.cols);
        const start = row * self.cols;
        @memcpy(result.data[0..self.cols], self.data[start..start + self.cols]);
        result.count = self.cols;
        result.rows = 1;
        result.cols = self.cols;
        return result;
    }

    /// Get a column from the matrix as a new vector
    pub fn getCol(self: Self, col: usize) Self {
        if (!self.isMatrix() or col >= self.cols) {
            return FloatVector.init(0);
        }
        
        const result = FloatVector.init(self.rows);
        for (0..self.rows) |i| {
            result.data[i] = self.data[i * self.cols + col];
        }
        result.count = self.rows;
        result.rows = self.rows;
        result.cols = 1;
        return result;
    }

    /// Transpose a matrix
    pub fn transpose(self: Self) Self {
        if (!self.isMatrix()) {
            return FloatVector.clone(self);
        }

        const result = FloatVector.initMatrix(self.cols, self.rows);
        
        // Use SIMD-friendly access pattern when possible
        for (0..self.rows) |i| {
            for (0..self.cols) |j| {
                result.data[j * self.rows + i] = self.data[i * self.cols + j];
            }
        }
        
        return result;
    }

    /// Reshape a matrix/vector to new dimensions
    pub fn reshape(self: Self, new_rows: usize, new_cols: usize) Self {
        if (new_rows * new_cols != self.count) {
            std.debug.print("Cannot reshape: size mismatch\n", .{});
            return FloatVector.clone(self);
        }

        const result = FloatVector.clone(self);
        result.rows = new_rows;
        result.cols = new_cols;
        return result;
    }

    /// Matrix multiplication using SIMD acceleration
    pub fn matmul(a: Self, b: Self) Self {
        // Check dimensions: a is (m x n), b is (n x p), result is (m x p)
        if (!a.isMatrix() or !b.isMatrix()) {
            std.debug.print("Both operands must be matrices\n", .{});
            return FloatVector.init(0);
        }
        
        if (a.cols != b.rows) {
            std.debug.print("Matrix dimensions incompatible for multiplication: ({d}x{d}) * ({d}x{d})\n", .{a.rows, a.cols, b.rows, b.cols});
            return FloatVector.init(0);
        }

        const m = a.rows;
        const n = a.cols; // = b.rows
        const p = b.cols;
        
        const result = FloatVector.initMatrix(m, p);

        // Use SIMD for the inner loop when possible
        const Vec4 = @Vector(4, f64);
        
        for (0..m) |i| {
            for (0..p) |j| {
                var sum_vec: Vec4 = @splat(@as(f64, 0.0));
                const vec_iterations = @divTrunc(n, 4);
                
                // Process 4 elements at a time
                var k: usize = 0;
                while (k < vec_iterations) : (k += 1) {
                    const k_offset = k * 4;
                    
                    // Load 4 elements from row i of matrix a
                    const a_vec = Vec4{
                        a.data[i * a.cols + k_offset],
                        a.data[i * a.cols + k_offset + 1],
                        a.data[i * a.cols + k_offset + 2],
                        a.data[i * a.cols + k_offset + 3],
                    };
                    
                    // Load 4 elements from column j of matrix b
                    const b_vec = Vec4{
                        b.data[(k_offset) * b.cols + j],
                        b.data[(k_offset + 1) * b.cols + j],
                        b.data[(k_offset + 2) * b.cols + j],
                        b.data[(k_offset + 3) * b.cols + j],
                    };
                    
                    sum_vec += a_vec * b_vec;
                }
                
                // Sum up the vector
                var sum: f64 = @reduce(.Add, sum_vec);
                
                // Handle remaining elements
                const remaining = @mod(n, 4);
                if (remaining > 0) {
                    const start = n - remaining;
                    for (start..n) |k_rem| {
                        sum += a.data[i * a.cols + k_rem] * b.data[k_rem * b.cols + j];
                    }
                }
                
                result.data[i * p + j] = sum;
            }
        }
        
        return result;
    }

    /// Matrix addition (element-wise)
    pub fn matadd(a: Self, b: Self) Self {
        if (!a.isMatrix() or !b.isMatrix()) {
            // Fall back to vector addition
            return FloatVector.add(a, b);
        }
        
        if (a.rows != b.rows or a.cols != b.cols) {
            std.debug.print("Matrix dimensions must match for addition\n", .{});
            return FloatVector.init(0);
        }

        const result = FloatVector.initMatrix(a.rows, a.cols);
        
        // Use SIMD for element-wise addition
        const Vec4 = @Vector(4, f64);
        const vec_iterations = @divTrunc(a.count, 4);
        
        var i: usize = 0;
        while (i < vec_iterations) : (i += 1) {
            const offset = i * 4;
            const vec1 = Vec4{
                a.data[offset],
                a.data[offset + 1],
                a.data[offset + 2],
                a.data[offset + 3],
            };
            const vec2 = Vec4{
                b.data[offset],
                b.data[offset + 1],
                b.data[offset + 2],
                b.data[offset + 3],
            };
            const sum_result = vec1 + vec2;
            result.data[offset] = sum_result[0];
            result.data[offset + 1] = sum_result[1];
            result.data[offset + 2] = sum_result[2];
            result.data[offset + 3] = sum_result[3];
        }
        
        // Handle remaining elements
        const remaining = @mod(a.count, 4);
        if (remaining > 0) {
            const start = a.count - remaining;
            for (start..a.count) |j| {
                result.data[j] = a.data[j] + b.data[j];
            }
        }
        
        return result;
    }

    /// Matrix subtraction (element-wise)
    pub fn matsub(a: Self, b: Self) Self {
        if (!a.isMatrix() or !b.isMatrix()) {
            // Fall back to vector subtraction
            return FloatVector.sub(a, b);
        }
        
        if (a.rows != b.rows or a.cols != b.cols) {
            std.debug.print("Matrix dimensions must match for subtraction\n", .{});
            return FloatVector.init(0);
        }

        const result = FloatVector.initMatrix(a.rows, a.cols);
        
        // Use SIMD for element-wise subtraction
        const Vec4 = @Vector(4, f64);
        const vec_iterations = @divTrunc(a.count, 4);
        
        var i: usize = 0;
        while (i < vec_iterations) : (i += 1) {
            const offset = i * 4;
            const vec1 = Vec4{
                a.data[offset],
                a.data[offset + 1],
                a.data[offset + 2],
                a.data[offset + 3],
            };
            const vec2 = Vec4{
                b.data[offset],
                b.data[offset + 1],
                b.data[offset + 2],
                b.data[offset + 3],
            };
            const diff = vec1 - vec2;
            result.data[offset] = diff[0];
            result.data[offset + 1] = diff[1];
            result.data[offset + 2] = diff[2];
            result.data[offset + 3] = diff[3];
        }
        
        // Handle remaining elements
        const remaining = @mod(a.count, 4);
        if (remaining > 0) {
            const start = a.count - remaining;
            for (start..a.count) |j| {
                result.data[j] = a.data[j] - b.data[j];
            }
        }
        
        return result;
    }

    /// Matrix element-wise multiplication (Hadamard product)
    pub fn matmul_elementwise(a: Self, b: Self) Self {
        if (!a.isMatrix() or !b.isMatrix()) {
            // Fall back to vector multiplication
            return FloatVector.mul(a, b);
        }
        
        if (a.rows != b.rows or a.cols != b.cols) {
            std.debug.print("Matrix dimensions must match for element-wise multiplication\n", .{});
            return FloatVector.init(0);
        }

        const result = FloatVector.initMatrix(a.rows, a.cols);
        
        // Use SIMD for element-wise multiplication
        const Vec4 = @Vector(4, f64);
        const vec_iterations = @divTrunc(a.count, 4);
        
        var i: usize = 0;
        while (i < vec_iterations) : (i += 1) {
            const offset = i * 4;
            const vec1 = Vec4{
                a.data[offset],
                a.data[offset + 1],
                a.data[offset + 2],
                a.data[offset + 3],
            };
            const vec2 = Vec4{
                b.data[offset],
                b.data[offset + 1],
                b.data[offset + 2],
                b.data[offset + 3],
            };
            const prod = vec1 * vec2;
            result.data[offset] = prod[0];
            result.data[offset + 1] = prod[1];
            result.data[offset + 2] = prod[2];
            result.data[offset + 3] = prod[3];
        }
        
        // Handle remaining elements
        const remaining = @mod(a.count, 4);
        if (remaining > 0) {
            const start = a.count - remaining;
            for (start..a.count) |j| {
                result.data[j] = a.data[j] * b.data[j];
            }
        }
        
        return result;
    }

    /// Matrix scalar multiplication
    pub fn matscale(self: Self, scalar: f64) Self {
        if (!self.isMatrix()) {
            return FloatVector.scale(self, scalar);
        }

        const result = FloatVector.initMatrix(self.rows, self.cols);
        
        // Use SIMD for scalar multiplication
        const Vec4 = @Vector(4, f64);
        const scalar_vec: Vec4 = @splat(scalar);
        const vec_iterations = @divTrunc(self.count, 4);
        
        var i: usize = 0;
        while (i < vec_iterations) : (i += 1) {
            const offset = i * 4;
            const vec = Vec4{
                self.data[offset],
                self.data[offset + 1],
                self.data[offset + 2],
                self.data[offset + 3],
            };
            const scaled = vec * scalar_vec;
            result.data[offset] = scaled[0];
            result.data[offset + 1] = scaled[1];
            result.data[offset + 2] = scaled[2];
            result.data[offset + 3] = scaled[3];
        }
        
        // Handle remaining elements
        const remaining = @mod(self.count, 4);
        if (remaining > 0) {
            const start = self.count - remaining;
            for (start..self.count) |j| {
                result.data[j] = self.data[j] * scalar;
            }
        }
        
        return result;
    }
};

fn quickSort(arr: []f64, low: i32, high: i32) void {
    if (low < high) {
        const pi = partition(arr, low, high);
        quickSort(arr, low, pi - 1);
        quickSort(arr, pi + 1, high);
    }
}

fn partition(arr: []f64, low: i32, high: i32) i32 {
    const pivot = arr[@intCast(high)];
    var i = low - 1;

    for (@intCast(low)..@intCast(high)) |j| {
        if (arr[j] <= pivot) {
            i += 1;
            swap(arr, @intCast(i), @intCast(j));
        }
    }
    swap(arr, @intCast(i + 1), @intCast(high));
    return i + 1;
}

fn swap(arr: []f64, i: usize, j: usize) void {
    const temp = arr[i];
    arr[i] = arr[j];
    arr[j] = temp;
}

pub inline fn compare_double(a: f64, b: f64) i32 {
    if (a < b) return -1;
    if (a > b) return 1;
    return 0;
}
