const obj_h = @import("obj.zig");
const Obj = obj_h.Obj;
const allocateObject = @import("../object.zig").allocateObject;
const reallocate = @import("../memory.zig").reallocate;
const std = @import("std");

pub const FloatVector = struct {
    obj: Obj,
    size: usize,
    count: usize,
    pos: usize,
    data: []f64,
    sorted: bool,

    const Self = *@This();

    pub fn init(size: usize) Self {
        const vector: Self = @ptrCast(@alignCast(allocateObject(@sizeOf(FloatVector), .OBJ_FVECTOR)));
        vector.size = size;
        vector.count = 0;
        vector.pos = 0;
        vector.sorted = false;
        if (size == 0) {
            vector.data = &[_]f64{};
        } else {
            const byte_size = @sizeOf(f64) * size;
            const raw_ptr = reallocate(null, 0, byte_size);
            if (raw_ptr == null) {
                std.debug.print("Failed to allocate memory for FloatVector data\n", .{});
                std.process.exit(1);
            }
            vector.data = @as([*]f64, @ptrCast(@alignCast(raw_ptr.?)))[0..size];
        }
        return vector;
    }

    pub fn deinit(self: Self) void {
        if (self.data.len > 0) {
            _ = reallocate(@as(?*anyopaque, @ptrCast(self.data.ptr)), @sizeOf(f64) * self.data.len, 0);
        }
        _ = reallocate(@as(?*anyopaque, @ptrCast(self)), @sizeOf(FloatVector), 0);
    }

    pub fn print(self: Self) void {
        std.debug.print("[", .{});
        for (0..self.count) |i| {
            std.debug.print("{d:.2}", .{self.data[i]});
            if (i < self.count - 1) std.debug.print(", ", .{});
        }
        std.debug.print("]\n", .{});
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
        const result = FloatVector.init(self.size);
        for (0..self.count) |i| {
            result.data[i] = self.data[i];
        }
        result.count = self.count;
        result.sorted = self.sorted;
        return result;
    }

    pub fn clear(self: Self) void {
        self.count = 0;
        self.pos = 0;
        self.sorted = false;
    }

    pub fn push(self: Self, value: f64) void {
        if (self.count >= self.size) {
            const new_size = if (self.size == 0) 1 else self.size * 2;
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
        self.data[self.count] = value;
        self.count += 1;
        self.sorted = false;
    }

    pub fn insert(self: Self, index: usize, value: f64) void {
        if (index > self.count) return;

        if (self.count >= self.size) {
            const new_size = if (self.size == 0) 1 else self.size * 2;
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
        const result = FloatVector.init(total_count);

        for (0..self.count) |i| {
            FloatVector.push(result, self.data[i]);
        }
        for (0..other.count) |i| {
            FloatVector.push(result, other.data[i]);
        }
        return result;
    }

    pub fn slice(self: Self, start: usize, end: usize) Self {
        if (start >= self.count or end >= self.count or start > end) {
            std.debug.print("Index out of bounds\n", .{});
            return FloatVector.init(0);
        }

        const result = FloatVector.init(end - start + 1);
        for (start..end + 1) |i| {
            FloatVector.push(result, self.data[i]);
        }
        return result;
    }

    pub fn splice(self: Self, start: usize, end: usize) Self {
        if (start >= self.count or end >= self.count or start > end) {
            std.debug.print("Index out of bounds\n", .{});
            return FloatVector.init(0);
        }

        const result = FloatVector.init(self.size);
        for (0..start) |i| {
            FloatVector.push(result, self.data[i]);
        }
        for (end + 1..self.count) |i| {
            FloatVector.push(result, self.data[i]);
        }
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
