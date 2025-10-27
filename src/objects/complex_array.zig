const std = @import("std");

const reallocate = @import("../memory.zig").reallocate;
const allocateObject = @import("../object.zig").allocateObject;
const value_h = @import("../value.zig");
const Complex = value_h.Complex;
const obj_h = @import("obj.zig");
const Obj = obj_h.Obj;

// SIMD-optimized complex number array for high-performance mathematical operations
pub const ComplexArray = struct {
    obj: Obj,
    size: usize,
    count: usize,
    data: []Complex,

    const Self = *@This();

    // Initialize a new complex array with given capacity
    pub fn init(capacity: usize) Self {
        const complexArray = allocateObject(ComplexArray, .OBJ_COMPLEX_ARRAY);
        complexArray.size = capacity;
        complexArray.count = 0;
        complexArray.data = if (capacity > 0)
            @as([]Complex, @ptrCast(@alignCast(reallocate(null, 0, @sizeOf(Complex) * capacity))))
        else
            &[_]Complex{};
        return complexArray;
    }

    // Create a new complex array
    pub fn new(capacity: usize) Self {
        return init(capacity);
    }

    // Initialize an empty complex array
    pub fn initEmpty() Self {
        return init(0);
    }

    // Free the complex array
    pub fn deinit(self: Self) void {
        if (self.size > 0) {
            _ = reallocate(@ptrCast(self.data.ptr), @sizeOf(Complex) * self.size, 0);
        }
    }

    // Ensure the array has enough capacity
    fn ensureCapacity(self: Self, capacity: usize) void {
        if (self.size >= capacity) return;

        const oldCapacity = self.size;
        var newCapacity = if (oldCapacity < 8) 8 else oldCapacity * 2;
        if (newCapacity < capacity) newCapacity = capacity;

        self.data = @as([]Complex, @ptrCast(@alignCast(reallocate(if (oldCapacity > 0) @ptrCast(self.data.ptr) else null, @sizeOf(Complex) * oldCapacity, @sizeOf(Complex) * newCapacity))));
        self.size = newCapacity;
    }

    // Add a complex number to the array
    pub fn push(self: Self, value: Complex) void {
        self.ensureCapacity(self.count + 1);
        self.data[self.count] = value;
        self.count += 1;
    }

    // Get a complex number from the array
    pub fn get(self: Self, index: usize) Complex {
        if (index >= self.count) return Complex{ .r = 0.0, .i = 0.0 };
        return self.data[index];
    }

    // Set a complex number in the array
    pub fn set(self: Self, index: usize, value: Complex) void {
        if (index >= self.count) return;
        self.data[index] = value;
    }

    // SIMD-optimized complex addition
    pub fn add(self: Self, other: Self) Self {
        const min_count = @min(self.count, other.count);
        const result = ComplexArray.init(min_count);

        // Process elements in chunks of 2 complex numbers (4 f64 values)
        const Vec4 = @Vector(4, f64);
        const vec_iterations = @divTrunc(min_count, 2);

        var i: usize = 0;
        while (i < vec_iterations) : (i += 1) {
            const offset = i * 2;

            // Load 2 complex numbers from each array (4 f64 values each)
            const vec1 = Vec4{
                self.data[offset].r,
                self.data[offset].i,
                self.data[offset + 1].r,
                self.data[offset + 1].i,
            };

            const vec2 = Vec4{
                other.data[offset].r,
                other.data[offset].i,
                other.data[offset + 1].r,
                other.data[offset + 1].i,
            };

            // Add vectors
            const sum_result = vec1 + vec2;

            // Store results
            result.data[offset] = Complex{ .r = sum_result[0], .i = sum_result[1] };
            result.data[offset + 1] = Complex{ .r = sum_result[2], .i = sum_result[3] };
        }

        // Handle remaining elements
        const remaining = @mod(min_count, 2);
        if (remaining > 0) {
            const start = min_count - remaining;
            for (start..min_count) |j| {
                result.data[j] = Complex{
                    .r = self.data[j].r + other.data[j].r,
                    .i = self.data[j].i + other.data[j].i,
                };
            }
        }

        result.count = min_count;
        return result;
    }

    // SIMD-optimized complex subtraction
    pub fn sub(self: Self, other: Self) Self {
        const min_count = @min(self.count, other.count);
        const result = ComplexArray.init(min_count);

        const Vec4 = @Vector(4, f64);
        const vec_iterations = @divTrunc(min_count, 2);

        var i: usize = 0;
        while (i < vec_iterations) : (i += 1) {
            const offset = i * 2;

            const vec1 = Vec4{
                self.data[offset].r,
                self.data[offset].i,
                self.data[offset + 1].r,
                self.data[offset + 1].i,
            };

            const vec2 = Vec4{
                other.data[offset].r,
                other.data[offset].i,
                other.data[offset + 1].r,
                other.data[offset + 1].i,
            };

            const diff_result = vec1 - vec2;

            result.data[offset] = Complex{ .r = diff_result[0], .i = diff_result[1] };
            result.data[offset + 1] = Complex{ .r = diff_result[2], .i = diff_result[3] };
        }

        // Handle remaining elements
        const remaining = @mod(min_count, 2);
        if (remaining > 0) {
            const start = min_count - remaining;
            for (start..min_count) |j| {
                result.data[j] = Complex{
                    .r = self.data[j].r - other.data[j].r,
                    .i = self.data[j].i - other.data[j].i,
                };
            }
        }

        result.count = min_count;
        return result;
    }

    // SIMD-optimized complex multiplication
    pub fn mul(self: Self, other: Self) Self {
        const min_count = @min(self.count, other.count);
        const result = ComplexArray.init(min_count);

        // Complex multiplication: (a + bi)(c + di) = (ac - bd) + (ad + bc)i
        const Vec4 = @Vector(4, f64);
        const vec_iterations = @divTrunc(min_count, 2);

        var i: usize = 0;
        while (i < vec_iterations) : (i += 1) {
            const offset = i * 2;

            // Load first complex array data
            const a_vec = Vec4{
                self.data[offset].r, // a1
                self.data[offset].r, // a1 (duplicate for multiplication)
                self.data[offset + 1].r, // a2
                self.data[offset + 1].r, // a2 (duplicate)
            };

            const b_vec = Vec4{
                self.data[offset].i, // b1
                self.data[offset].i, // b1 (duplicate)
                self.data[offset + 1].i, // b2
                self.data[offset + 1].i, // b2 (duplicate)
            };

            // Load second complex array data
            const c_vec = Vec4{
                other.data[offset].r, // c1
                other.data[offset].i, // d1
                other.data[offset + 1].r, // c2
                other.data[offset + 1].i, // d2
            };

            const d_vec = Vec4{
                other.data[offset].i, // d1
                other.data[offset].r, // c1
                other.data[offset + 1].i, // d2
                other.data[offset + 1].r, // c2
            };

            // Calculate ac, ad, bc, bd using SIMD
            const ac_ad = a_vec * c_vec; // [a1*c1, a1*d1, a2*c2, a2*d2]
            const bd_bc = b_vec * d_vec; // [b1*d1, b1*c1, b2*d2, b2*c2]

            // Real parts: ac - bd
            result.data[offset].r = ac_ad[0] - bd_bc[0]; // a1*c1 - b1*d1
            result.data[offset + 1].r = ac_ad[2] - bd_bc[2]; // a2*c2 - b2*d2

            // Imaginary parts: ad + bc
            result.data[offset].i = ac_ad[1] + bd_bc[1]; // a1*d1 + b1*c1
            result.data[offset + 1].i = ac_ad[3] + bd_bc[3]; // a2*d2 + b2*c2
        }

        // Handle remaining elements
        const remaining = @mod(min_count, 2);
        if (remaining > 0) {
            const start = min_count - remaining;
            for (start..min_count) |j| {
                const a = self.data[j];
                const b = other.data[j];
                result.data[j] = Complex{
                    .r = a.r * b.r - a.i * b.i,
                    .i = a.r * b.i + a.i * b.r,
                };
            }
        }

        result.count = min_count;
        return result;
    }

    // SIMD-optimized scalar multiplication
    pub fn scale(self: Self, scalar: Complex) Self {
        const result = ComplexArray.init(self.count);
        const Vec4 = @Vector(4, f64);
        const vec_iterations = @divTrunc(self.count, 2);

        var i: usize = 0;
        while (i < vec_iterations) : (i += 1) {
            const offset = i * 2;

            // Load 2 complex numbers
            const a_vec = Vec4{
                self.data[offset].r,
                self.data[offset].i,
                self.data[offset + 1].r,
                self.data[offset + 1].i,
            };

            // Replicate scalar for SIMD operations
            const scalar_real = Vec4{ scalar.r, scalar.r, scalar.r, scalar.r };
            const scalar_imag = Vec4{ scalar.i, scalar.i, scalar.i, scalar.i };

            // Extract real and imaginary parts
            const real_parts = Vec4{ a_vec[0], a_vec[0], a_vec[2], a_vec[2] };
            const imag_parts = Vec4{ a_vec[1], a_vec[1], a_vec[3], a_vec[3] };

            // Compute (a + bi) * (c + di) = (ac - bd) + (ad + bc)i
            const ac = real_parts * scalar_real; // [a1*c, a1*c, a2*c, a2*c]
            const bd = imag_parts * scalar_imag; // [b1*d, b1*d, b2*d, b2*d]
            const ad = real_parts * scalar_imag; // [a1*d, a1*d, a2*d, a2*d]
            const bc = imag_parts * scalar_real; // [b1*c, b1*c, b2*c, b2*c]

            result.data[offset].r = ac[0] - bd[0];
            result.data[offset].i = ad[0] + bc[0];
            result.data[offset + 1].r = ac[2] - bd[2];
            result.data[offset + 1].i = ad[2] + bc[2];
        }

        // Handle remaining elements
        const remaining = @mod(self.count, 2);
        if (remaining > 0) {
            const start = self.count - remaining;
            for (start..self.count) |j| {
                const a = self.data[j];
                result.data[j] = Complex{
                    .r = a.r * scalar.r - a.i * scalar.i,
                    .i = a.r * scalar.i + a.i * scalar.r,
                };
            }
        }

        result.count = self.count;
        return result;
    }

    // SIMD-optimized magnitude calculation
    pub fn magnitude(self: Self) []f64 {
        const result: []f64 = @as([]f64, @ptrCast(@alignCast(reallocate(null, 0, @sizeOf(f64) * self.count))));
        const Vec4 = @Vector(4, f64);
        const vec_iterations = @divTrunc(self.count, 2);

        var i: usize = 0;
        while (i < vec_iterations) : (i += 1) {
            const offset = i * 2;

            // Load 2 complex numbers
            const complex_vec = Vec4{
                self.data[offset].r,
                self.data[offset].i,
                self.data[offset + 1].r,
                self.data[offset + 1].i,
            };

            // Square each component
            const squared = complex_vec * complex_vec;

            // Calculate magnitudes: sqrt(r^2 + i^2)
            result[offset] = @sqrt(squared[0] + squared[1]);
            result[offset + 1] = @sqrt(squared[2] + squared[3]);
        }

        // Handle remaining elements
        const remaining = @mod(self.count, 2);
        if (remaining > 0) {
            const start = self.count - remaining;
            for (start..self.count) |j| {
                const c = self.data[j];
                result[j] = @sqrt(c.r * c.r + c.i * c.i);
            }
        }

        return result;
    }

    // SIMD-optimized conjugate calculation
    pub fn conjugate(self: Self) Self {
        const result = ComplexArray.init(self.count);
        const Vec4 = @Vector(4, f64);
        const vec_iterations = @divTrunc(self.count, 2);

        // Create a mask to negate imaginary parts: [1, -1, 1, -1]
        const negate_mask = Vec4{ 1.0, -1.0, 1.0, -1.0 };

        var i: usize = 0;
        while (i < vec_iterations) : (i += 1) {
            const offset = i * 2;

            // Load 2 complex numbers
            const complex_vec = Vec4{
                self.data[offset].r,
                self.data[offset].i,
                self.data[offset + 1].r,
                self.data[offset + 1].i,
            };

            // Apply conjugate (negate imaginary parts)
            const conjugate_vec = complex_vec * negate_mask;

            result.data[offset] = Complex{ .r = conjugate_vec[0], .i = conjugate_vec[1] };
            result.data[offset + 1] = Complex{ .r = conjugate_vec[2], .i = conjugate_vec[3] };
        }

        // Handle remaining elements
        const remaining = @mod(self.count, 2);
        if (remaining > 0) {
            const start = self.count - remaining;
            for (start..self.count) |j| {
                result.data[j] = Complex{ .r = self.data[j].r, .i = -self.data[j].i };
            }
        }

        result.count = self.count;
        return result;
    }

    // Clear the array
    pub fn clear(self: Self) void {
        self.count = 0;
    }

    // Print the complex array for debugging
    pub fn print(self: Self) void {
        std.debug.print("[", .{});
        for (0..self.count) |i| {
            const c = self.data[i];
            if (i > 0) std.debug.print(", ", .{});
            std.debug.print("{d}+{d}i", .{ c.r, c.i });
        }
        std.debug.print("]\n", .{});
    }
};
