const obj_h = @import("obj.zig");
const Obj = obj_h.Obj;
const allocateObject = @import("../object.zig").allocateObject;
const reallocate = @import("../memory.zig").reallocate;
const std = @import("std");

fn printf(s: []const u8) void {
    std.debug.print("{s}", .{s});
}

fn _data(self: [*c]FloatVector) FloatVector.Ptr {
    return self.*.data;
}

fn _size(self: [*c]FloatVector) FloatVector.Int {
    return self.*.size;
}

fn _sorted(self: FloatVector.Self) bool {
    return self.*.sorted;
}

pub fn _count(self: [*c]FloatVector) FloatVector.Int {
    return self.*.count;
}

fn _get(self: [*c]FloatVector, index: FloatVector.Int) f64 {
    if (index < 0 or index >= self.*.count) {
        printf("Index out of bounds\n");
        return 0.0;
    }
    return self.*.data[@intCast(index)];
}

pub fn _write(self: [*c]FloatVector, i: FloatVector.Int, val: f64) void {
    FloatVector.write(self, i, val);
}

pub const FloatVector = extern struct {
    obj: Obj,
    size: Int,
    count: Int,
    pos: Int,
    data: Ptr,
    sorted: bool,
    const Ptr = [*c]f64;
    const Self = [*c]@This();
    const Int = c_int;

    pub fn init(size: Int) Self {
        const vector: [*c]FloatVector = @ptrCast(@alignCast(allocateObject(@sizeOf(FloatVector), .OBJ_FVECTOR)));
        vector.*.size = size;
        vector.*.count = 0;
        vector.*.data = @as(Ptr, @ptrCast(@alignCast(reallocate(null, 0, @intCast(@sizeOf(f64) *% size)))));
        return vector;
    }

    pub fn deinit(self: Self) void {
        _ = reallocate(@as(?*anyopaque, @ptrCast(_data(self))), @intCast(@sizeOf(f32) *% _size(self)), 0);
        _ = reallocate(@as(?*anyopaque, @ptrCast(self)), @sizeOf(FloatVector), 0);
    }

    pub fn print(self: Self) void {
        printf("{");
        for (0..@intCast(_count(self))) |i| {
            printf("%.2f ", _get(self, @intCast(i)));
        }
        printf("}");
        printf("\n");
    }

    fn write(self: Self, i: Int, val: f64) void {
        self.*.data[@intCast(i)] = val;
    }

    fn true_sorted(self: Self) void {
        self.*.sorted = true;
    }

    fn false_sorted(self: Self) void {
        self.*.sorted = false;
    }

    fn count_increase(self: Self, i: Int) void {
        self.*.count += i;
    }

    pub fn sort(self: Self) void {
        if (_sorted(self)) return;
        if (_count(self) <= 1) {
            FloatVector.true_sorted(self);
            return;
        }

        quickSort(_data(self), 0, _count(self) - 1);
        FloatVector.true_sorted(self);
    }

    pub fn clone(self: Self) Self {
        const newVector = FloatVector.init(_size(self));
        for (0..@intCast(_count(self))) |i| {
            FloatVector.push(newVector, _get(self, @intCast(i)));
        }
        return newVector;
    }

    pub fn clear(self: Self) void {
        self.*.count = 0;
        FloatVector.false_sorted(self);
    }

    pub fn push(self: Self, val: f64) void {
        if (_count(self) + 1 > _size(self)) {
            printf("Vector is full\n");
            return;
        }
        _write(self, _count(self), val);
        FloatVector.count_increase(self, 1);
    }

    pub fn insert(self: Self, index: Int, val: f64) void {
        if ((index < 0) or (index >= _size(self))) {
            printf("Index out of bounds\n");
            return;
        }
        var i: usize = @intCast(_count(self));
        while (i > @as(usize, @intCast(index))) {
            _write(self, @intCast(i), _get(self, @intCast(i - 1)));
            i -= 1;
        }

        _write(self, @intCast(index), val);
        FloatVector.count_increase(self, 1);

        if ((_count(self) > 1) and (_get(self, @intCast(index)) < _get(self, @intCast(index - 1)))) {
            FloatVector.false_sorted(self);
        }
    }

    pub fn get(self: Self, index: Int) f64 {
        return _get(self, @intCast(index));
    }

    pub fn pop(self: Self) f64 {
        if (_count(self) == 0) {
            printf("Vector is empty\n");
            return 0;
        }
        const poppedValue: f64 = _get(self, _count(self) - 1);
        FloatVector.count_increase(self, -1);
        if (_count(self) == 0) {
            FloatVector.false_sorted(self);
        }
        return poppedValue;
    }

    pub fn remove(self: Self, index: Int) f64 {
        if ((index < 0) or (index >= _count(self))) {
            printf("Index out of bounds\n");
            return 0;
        }
        const removedValue: f64 = _get(self, @intCast(index));
        for (@as(usize, @intCast(index))..@as(usize, @intCast(_count(self) - 1))) |i| {
            _write(self, @as(Int, @intCast(i)), _get(self, @as(Int, @intCast(i + 1))));
        }
        FloatVector.count_increase(self, -1);
        if (((@intFromBool(_sorted(self)) != 0) and (index > 0)) and (_get(self, @intCast(index)) < _get(self, @intCast(index - 1)))) {
            FloatVector.false_sorted(self);
        }
        return removedValue;
    }

    pub fn merge(self: Self, other: Self) Self {
        const result = FloatVector.init(_size(self) + _size(other));
        for (0..@as(usize, @intCast(_count(self)))) |i| {
            FloatVector.push(result, _get(self, @as(Int, @intCast(i))));
        }
        for (0..@intCast(_count(other))) |i| {
            FloatVector.push(result, _get(other, @as(Int, @intCast(i))));
        }
        return result;
    }

    pub fn slice(self: Self, start: Int, end: Int) Self {
        if ((((start < 0) or (start >= _count(self)) or (end < 0)) or (end >= _count(self)))) {
            printf("Index out of bounds\n");
            return null;
        }
        const result = FloatVector.init((end - start) + 1);
        for (@as(usize, @intCast(start))..@as(usize, @intCast(end + 1))) |i| {
            FloatVector.push(result, _get(self, @intCast(i)));
        }
        return result;
    }

    pub fn splice(self: Self, start: Int, end: Int) Self {
        if ((((start < 0) or (start >= _count(self)) or (end < 0)) or (end >= _count(self)))) {
            printf("Index out of bounds\n");
            return null;
        }

        const result = FloatVector.init(_size(self));
        for (0..@as(usize, @intCast(start))) |i| {
            FloatVector.push(result, _get(self, @intCast(i)));
        }
        for (@as(usize, @intCast(end + 1))..@intCast(_count(self))) |i| {
            FloatVector.push(result, _get(self, @intCast(i)));
        }
        return result;
    }

    pub fn sum(self: Self) f64 {
        const len = _count(self);
        const Vec4 = @Vector(4, f64);
        var sum_vec: Vec4 = @splat(@as(f64, 0.0));

        // Process elements in chunks of 4
        const vec_iterations = @divTrunc(len, 4);
        var i: usize = 0;
        while (i < vec_iterations) : (i += 1) {
            const offset = i * 4;
            // Load 4 elements into a vector
            const data_vec = Vec4{
                _get(self, @as(Int, @intCast(offset))),
                _get(self, @as(Int, @intCast(offset + 1))),
                _get(self, @as(Int, @intCast(offset + 2))),
                _get(self, @as(Int, @intCast(offset + 3))),
            };
            sum_vec += data_vec;
        }

        // Sum up the vector elements
        var sum_value: f64 = @reduce(.Add, sum_vec);

        // Handle remaining elements
        const remaining = @mod(len, 4);
        if (remaining > 0) {
            const start = len - remaining;
            for (@intCast(start)..@intCast(len)) |j| {
                sum_value += _get(self, @as(Int, @intCast(j)));
            }
        }

        return sum_value;
    }

    pub fn mean(self: Self) f64 {
        return FloatVector.sum(self) / @as(f64, @floatFromInt(_count(self)));
    }

    pub fn variance(self: Self) f64 {

        const len = _count(self);
        const mean_value: f64 = FloatVector.mean(self);

        const Vec4 = @Vector(4, f64);
        const mean_vec: Vec4 = @splat(mean_value);
        var variance_vec: Vec4 = @splat(@as(f64, 0.0));

        // Process elements in chunks of 4
        const vec_iterations = @divTrunc(len, 4);
        var i: usize = 0;
        while (i < vec_iterations) : (i += 1) {
            const offset = i * 4;
            // Load 4 elements manually into a vector
            const data_vec = Vec4{
                _get(self, @as(Int, @intCast(offset))),
                _get(self, @as(Int, @intCast(offset + 1))),
                _get(self, @as(Int, @intCast(offset + 2))),
                _get(self, @as(Int, @intCast(offset + 3))),
            };
            const diff_vec = data_vec - mean_vec;
            variance_vec += diff_vec * diff_vec;
        }

        // Sum up the variance vector
        var variance_value: f64 = @reduce(.Add, variance_vec);

        // Handle remaining elements
        const remaining = @mod(len, 4);
        if (remaining > 0) {
            const start: usize = @intCast(len - remaining);
            for (start..@intCast(len)) |j| {
                const diff = _get(self, @as(Int, @intCast(j))) - mean_value;
                variance_value += diff * diff;
            }
        }

        return variance_value / @as(f64, @floatFromInt(len - 1));
    }

    pub fn stdDev(self: Self) f64 {
        return @sqrt(FloatVector.variance(self));
    }

    pub fn max(self: Self) f64 {
        var max_value: f64 = _get(self, 0);
        for (1..@as(usize, @intCast(_count(self)))) |i| {
            max_value = @max(_get(self, @as(Int, @intCast(i))), max_value);
        }
        return max_value;
    }

    pub fn min(self: Self) f64 {
        var min_value: f64 = _get(self, 0);
        for (1..@as(usize, @intCast(_count(self)))) |i| {
            min_value = @min(_get(self, @as(Int, @intCast(i))), min_value);
        }
        return min_value;
    }
};

pub const sliceFloatVector = FloatVector.slice;
pub const spliceFloatVector = FloatVector.splice;
pub const popFloatVector = FloatVector.pop;
pub const getFloatVector = _get;
pub const insertFloatVector = FloatVector.insert;
pub const mergeFloatVector = FloatVector.merge;
pub const cloneFloatVector = FloatVector.clone;
pub const clearFloatVector = FloatVector.clear;
pub const removeFloatVector = FloatVector.remove;
pub const sumFloatVector = FloatVector.sum;
pub const meanFloatVector = FloatVector.mean;
pub const stdDevFloatVector = FloatVector.stdDev;
pub const varianceFloatVector = FloatVector.variance;
pub const maxFloatVector = FloatVector.max;
pub const minFloatVector = FloatVector.min;

fn quickSort(arr: FloatVector.Ptr, low: FloatVector.Int, high: FloatVector.Int) void {
    if (low < high) {
        // Select pivot and partition array
        const pi = partition(arr, low, high);

        // Sort the sub-arrays
        if (pi > 0) {
            quickSort(arr, low, pi - 1);
        }
        quickSort(arr, pi + 1, high);
    }
}

fn partition(arr: FloatVector.Ptr, low: FloatVector.Int, high: FloatVector.Int) FloatVector.Int {
    const pivot = arr[@intCast(high)];
    var i = low - 1;

    var j = low;
    while (j < high) : (j += 1) {
        if (arr[@intCast(j)] <= pivot) {
            i += 1;
            swap(arr, i, j);
        }
    }

    swap(arr, i + 1, high);
    return i + 1;
}

fn swap(arr: FloatVector.Ptr, i: FloatVector.Int, j: FloatVector.Int) void {
    const temp = arr[@intCast(i)];
    arr[@intCast(i)] = arr[@intCast(j)];
    arr[@intCast(j)] = temp;
}

// SIMD
// pub const __m256 = @Vector(8, f32);
// pub const __m256d = @Vector(4, f64);
// pub const __m256_u = @Vector(8, f32);
// pub const __m256d_u = @Vector(4, f64);

// inline fn _mm256_setzero_pd() __m256d {
//     return .{ 0.0, 0.0, 0.0, 0.0 };
// }

// inline fn _mm256_storeu_pd(p: [*c]f64, a: __m256d) void {
//     const __p = p;
//     const __a = a;
//     const struct___storeu_pd = extern struct {
//         __v: __m256d_u align(1) = @import("std").mem.zeroes(__m256d_u),
//     };
//     @as([*c]struct___storeu_pd, @ptrCast(@alignCast(__p))).*.__v = __a;
// }

// inline fn _mm256_loadu_pd(p: [*c]const f64) __m256d {
//     const __p = p;
//     const struct___loadu_pd = extern struct {
//         __v: __m256d_u align(1) = @import("std").mem.zeroes(__m256d_u),
//     };
//     return @as([*c]const struct___loadu_pd, @ptrCast(@alignCast(__p))).*.__v;
// }

// inline fn _mm256_add_pd(a: __m256d, b: __m256d) __m256d {
//     return a + b;
// }

// inline fn _mm256_sub_pd(a: __m256d, b: __m256d) __m256d {
//     return a - b;
// }

// inline fn _mm256_mul_pd(a: __m256d, b: __m256d) __m256d {
//     return a * b;
// }

// inline fn _mm256_div_pd(a: __m256d, b: __m256d) __m256d {
//     return a / b;
// }

// inline fn _mm256_fmadd_pd(a: __m256d, b: __m256d, c: __m256d) __m256d {
//     return @mulAdd(__m256d, a, b, c);
// }

// inline fn _mm256_set1_pd(w: f64) __m256d {
//     return _mm256_set_pd(w, w, w, w);
// }

// inline fn _mm256_set_pd(a: f64, b: f64, c: f64, d: f64) __m256d {
//     return .{ d, c, b, a };
// }

// pub fn newFloatVector(arg_size: c_int) [*c]FloatVector {
//     var size = arg_size;
//     _ = &size;
//     var vector: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(allocateObject(@sizeOf(FloatVector), .OBJ_FVECTOR))));
//     _ = &vector;
//     vector.*.size = size;
//     vector.*.count = 0;
//     vector.*.data = @as([*c]f64, @ptrCast(@alignCast(reallocate(null, 0, @intCast(@sizeOf(f64) *% size)))));
//     return vector;
// }

// pub fn cloneFloatVector(arg_vector: [*c]FloatVector) [*c]FloatVector {
//     var vector = arg_vector;
//     _ = &vector;
//     var newVector: [*c]FloatVector = FloatVector.init(vector.*.size);
//     _ = &newVector;
//     {
//         var i: c_int = 0;
//         _ = &i;
//         while (i < vector.*.count) : (i += 1) {
//             FloatVector.push(newVector, (blk: {
//                 const tmp = i;
//                 if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
//             }).*);
//         }
//     }
//     return newVector;
// }
// pub fn clearFloatVector(arg_vector: [*c]FloatVector) void {
//     var vector = arg_vector;
//     _ = &vector;
//     vector.*.count = 0;
//     vector.*.sorted = false;
// }
// pub fn freeFloatVector(arg_vector: [*c]FloatVector) void {
//     var vector = arg_vector;
//     _ = &vector;
//     _ = reallocate(@as(?*anyopaque, @ptrCast(vector.*.data)), @intCast(@sizeOf(f32) *% vector.*.size), 0);
//     _ = reallocate(@as(?*anyopaque, @ptrCast(vector)), @sizeOf(FloatVector), 0);
// }

// pub fn FloatVector.push(vector: [*c]FloatVector, value: f64) void {
//     if (vector.*.count + 1 > vector.*.size) {
//         printf("Vector is full\n");
//         return;
//     }
//     vector.*.data[@intCast(vector.*.count)] = value;
//     vector.*.count += 1;

//     if (vector.*.count > 1 and vector.*.data[@intCast(vector.*.count - 2)] > value) vector.*.sorted = false;
// }

// pub fn insertFloatVector(vector: [*c]FloatVector, index_1: c_int, value: f64) void {
//     if ((index_1 < 0) or (index_1 >= vector.*.size)) {
//         printf("Index out of bounds\n");
//         return;
//     }
//     var i: usize = @intCast(vector.*.count);
//     while (i > index_1) : (i -= 1) {
//         vector.*.data[i] = vector.*.data[i - 1];
//     }

//     vector.*.data[@intCast(index_1)] = value;
//     vector.*.count += 1;

//     if (vector.*.count > 1 and (vector.*.data[@intCast(index_1)] < vector.*.data[@intCast(index_1 - 1)])) vector.*.sorted = false;
// }

// pub fn getFloatVector(arg_vector: [*c]FloatVector, arg_index_1: c_int) f64 {
//     var vector = arg_vector;
//     _ = &vector;
//     var index_1 = arg_index_1;
//     _ = &index_1;
//     if ((index_1 < 0) or (index_1 >= vector.*.count)) {
//         printf("Index out of bounds\n");
//         return 0;
//     }
//     return (blk: {
//         const tmp = index_1;
//         if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
//     }).*;
// }

// pub fn popFloatVector(arg_vector: [*c]FloatVector) f64 {
//     var vector = arg_vector;
//     _ = &vector;
//     if (vector.*.count == 0) {
//         printf("Vector is empty\n");
//         return 0;
//     }
//     var poppedValue: f64 = (blk: {
//         const tmp = blk_1: {
//             const ref = &vector.*.count;
//             ref.* -= 1;
//             break :blk_1 ref.*;
//         };
//         if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
//     }).*;
//     _ = &poppedValue;
//     if (vector.*.count == 0) {
//         vector.*.sorted = false;
//     }
//     return poppedValue;
// }
// pub fn removeFloatVector(arg_vector: [*c]FloatVector, arg_index_1: c_int) f64 {
//     var vector = arg_vector;
//     _ = &vector;
//     var index_1 = arg_index_1;
//     _ = &index_1;
//     if ((index_1 < 0) or (index_1 >= vector.*.count)) {
//         printf("Index out of bounds\n");
//         return 0;
//     }
//     var removedValue: f64 = (blk: {
//         const tmp = index_1;
//         if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
//     }).*;
//     _ = &removedValue;
//     {
//         var i: c_int = index_1;
//         _ = &i;
//         while (i < (vector.*.count - 1)) : (i += 1) {
//             (blk: {
//                 const tmp = i;
//                 if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
//             }).* = (blk: {
//                 const tmp = i + 1;
//                 if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
//             }).*;
//         }
//     }
//     vector.*.count -= 1;
//     if (((@as(c_int, @intFromBool(vector.*.sorted)) != 0) and (index_1 > 0)) and ((blk: {
//         const tmp = index_1;
//         if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
//     }).* < (blk: {
//         const tmp = index_1 - 1;
//         if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
//     }).*)) {
//         vector.*.sorted = false;
//     }
//     return removedValue;
// }

// pub fn printFloatVector(arg_vector: [*c]FloatVector) void {
//     var vector = arg_vector;
//     _ = &vector;
//     printf("[");
//     {
//         var i: c_int = 0;
//         _ = &i;
//         while (i < vector.*.count) : (i += 1) {
//             printf("%.2f ", (blk: {
//                 const tmp = i;
//                 if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
//             }).*);
//         }
//     }
//     printf("]");
//     printf("\n");
// }

// pub fn mergeFloatVector(arg_a: [*c]FloatVector, arg_b: [*c]FloatVector) [*c]FloatVector {
//     var a = arg_a;
//     _ = &a;
//     var b = arg_b;
//     _ = &b;
//     var result: [*c]FloatVector = FloatVector.init(a.*.size + b.*.size);
//     _ = &result;
//     {
//         var i: c_int = 0;
//         _ = &i;
//         while (i < a.*.count) : (i += 1) {
//             FloatVector.push(result, (blk: {
//                 const tmp = i;
//                 if (tmp >= 0) break :blk a.*.data + @as(usize, @intCast(tmp)) else break :blk a.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
//             }).*);
//         }
//     }
//     {
//         var i: c_int = 0;
//         _ = &i;
//         while (i < b.*.count) : (i += 1) {
//             FloatVector.push(result, (blk: {
//                 const tmp = i;
//                 if (tmp >= 0) break :blk b.*.data + @as(usize, @intCast(tmp)) else break :blk b.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
//             }).*);
//         }
//     }
//     return result;
// }

// pub fn sliceFloatVector(arg_vector: [*c]FloatVector, arg_start: c_int, arg_end: c_int) [*c]FloatVector {
//     var vector = arg_vector;
//     _ = &vector;
//     var start = arg_start;
//     _ = &start;
//     var end = arg_end;
//     _ = &end;
//     if ((((start < 0) or (start >= vector.*.count)) or (end < 0)) or (end >= vector.*.count)) {
//         printf("Index out of bounds\n");
//         return null;
//     }
//     var result: [*c]FloatVector = FloatVector.init((end - start) + 1);
//     _ = &result;
//     {
//         var i: c_int = start;
//         _ = &i;
//         while (i <= end) : (i += 1) {
//             FloatVector.push(result, (blk: {
//                 const tmp = i;
//                 if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
//             }).*);
//         }
//     }
//     return result;
// }
// pub fn spliceFloatVector(arg_vector: [*c]FloatVector, arg_start: c_int, arg_end: c_int) [*c]FloatVector {
//     var vector = arg_vector;
//     _ = &vector;
//     var start = arg_start;
//     _ = &start;
//     var end = arg_end;
//     _ = &end;
//     if ((((start < 0) or (start >= vector.*.count)) or (end < 0)) or (end >= vector.*.count)) {
//         printf("Index out of bounds\n");
//         return null;
//     }
//     var result: [*c]FloatVector = FloatVector.init(vector.*.size);
//     _ = &result;
//     {
//         var i: c_int = 0;
//         _ = &i;
//         while (i < start) : (i += 1) {
//             FloatVector.push(result, (blk: {
//                 const tmp = i;
//                 if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
//             }).*);
//         }
//     }
//     {
//         var i: c_int = end + 1;
//         _ = &i;
//         while (i < vector.*.count) : (i += 1) {
//             FloatVector.push(result, (blk: {
//                 const tmp = i;
//                 if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
//             }).*);
//         }
//     }
//     return result;
// }

// pub fn sumFloatVector(arg_vector: [*c]FloatVector) f64 {
//     var vector = arg_vector;
//     _ = &vector;
//     var sum: f64 = 0;
//     _ = &sum;
//     var simdSize: usize = @intCast(@as(usize, @intCast(vector.*.count)) - @as(usize, @intCast(vector.*.count)) % 4);
//     _ = &simdSize;
//     var simd_sum: __m256 = @as(__m256, @bitCast(_mm256_setzero_pd()));
//     _ = &simd_sum;
//     {
//         var i: usize = 0;
//         _ = &i;
//         while (i < simdSize) : (i +%= 4) {
//             var simd_arr: __m256 = @as(__m256, @bitCast(_mm256_loadu_pd(&vector.*.data[i])));
//             _ = &simd_arr;
//             simd_sum = @as(__m256, @bitCast(_mm256_add_pd(@as(__m256d, @bitCast(simd_arr)), @as(__m256d, @bitCast(simd_sum)))));
//         }
//     }
//     {
//         var i: usize = simdSize;
//         _ = &i;
//         while (i < vector.*.count) : (i +%= 1) {
//             sum += vector.*.data[i];
//         }
//     }
//     var simd_sum_arr: [4]f64 = undefined;
//     _ = &simd_sum_arr;
//     _mm256_storeu_pd(@as([*c]f64, @ptrCast(@alignCast(&simd_sum_arr))), @as(__m256d, @bitCast(simd_sum)));
//     {
//         var i: c_int = 0;
//         _ = &i;
//         while (i < @as(c_int, 4)) : (i += 1) {
//             sum += simd_sum_arr[@as(c_uint, @intCast(i))];
//         }
//     }
//     return sum;
// }
// pub fn meanFloatVector(arg_vector: [*c]FloatVector) f64 {
//     var vector = arg_vector;
//     _ = &vector;
//     return sumFloatVector(vector) / @as(f64, @floatFromInt(vector.*.count));
// }
// pub fn varianceFloatVector(arg_vector: [*c]FloatVector) f64 {
//     var vector = arg_vector;
//     _ = &vector;
//     var mean: f64 = meanFloatVector(vector);
//     _ = &mean;
//     var variance: f64 = 0;
//     _ = &variance;
//     var simdSize: usize = @intCast(@as(usize, @intCast(vector.*.count)) - @as(usize, @intCast(vector.*.count)) % 4);
//     _ = &simdSize;
//     var simd_variance: __m256 = @as(__m256, @bitCast(_mm256_setzero_pd()));
//     _ = &simd_variance;
//     {
//         var i: usize = 0;
//         _ = &i;
//         while (i < simdSize) : (i +%= 4) {
//             var simd_arr: __m256 = @as(__m256, @bitCast(_mm256_loadu_pd(&vector.*.data[i])));
//             _ = &simd_arr;
//             var simd_diff: __m256 = @as(__m256, @bitCast(_mm256_sub_pd(@as(__m256d, @bitCast(simd_arr)), _mm256_set1_pd(mean))));
//             _ = &simd_diff;
//             simd_variance = @as(__m256, @bitCast(_mm256_fmadd_pd(@as(__m256d, @bitCast(simd_diff)), @as(__m256d, @bitCast(simd_diff)), @as(__m256d, @bitCast(simd_variance)))));
//         }
//     }
//     {
//         var i: usize = simdSize;
//         _ = &i;
//         while (i < vector.*.count) : (i +%= 1) {
//             variance += (vector.*.data[i] - mean) * (vector.*.data[i] - mean);
//         }
//     }
//     var simd_variance_arr: [4]f64 = undefined;
//     _ = &simd_variance_arr;
//     _mm256_storeu_pd(@as([*c]f64, @ptrCast(@alignCast(&simd_variance_arr))), @as(__m256d, @bitCast(simd_variance)));
//     {
//         var i: c_int = 0;
//         _ = &i;
//         while (i < @as(c_int, 4)) : (i += 1) {
//             variance += simd_variance_arr[@as(c_uint, @intCast(i))];
//         }
//     }
//     return variance / @as(f64, @floatFromInt(vector.*.count - 1));
// }
// pub fn stdDevFloatVector(arg_vector: [*c]FloatVector) f64 {
//     var vector = arg_vector;
//     _ = &vector;
//     return @sqrt(varianceFloatVector(vector));
// }
// pub fn maxFloatVector(arg_vector: [*c]FloatVector) f64 {
//     var vector = arg_vector;
//     _ = &vector;
//     var _max: f64 = vector.*.data[0];
//     _ = &_max;
//     {
//         var i: c_int = 1;
//         _ = &i;
//         while (i < vector.*.count) : (i += 1) {
//             if ((blk: {
//                 const tmp = i;
//                 if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
//             }).* > _max) {
//                 _max = (blk: {
//                     const tmp = i;
//                     if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
//                 }).*;
//             }
//         }
//     }
//     return _max;
// }

// pub fn minFloatVector(arg_vector: [*c]FloatVector) f64 {
//     var vector = arg_vector;
//     _ = &vector;
//     var min: f64 = vector.*.data[0];
//     _ = &min;
//     {
//         var i: c_int = 1;
//         _ = &i;
//         while (i < vector.*.count) : (i += 1) {
//             if ((blk: {
//                 const tmp = i;
//                 if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
//             }).* < min) {
//                 min = (blk: {
//                     const tmp = i;
//                     if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
//                 }).*;
//             }
//         }
//     }
//     return min;
// }

pub fn addFloatVector(vector1: [*c]FloatVector, vector2: [*c]FloatVector) [*c]FloatVector {
    if (_size(vector1) != _size(vector2)) {
        printf("Vectors are not of the same size\n");
        return null;
    }

    const result = FloatVector.init(_size(vector1));
    const len = vector1.*.count;

    // Process elements in chunks of 4
    const Vec4 = @Vector(4, f64);
    const vec_iterations = @divTrunc(len, 4);

    var i: usize = 0;
    while (i < vec_iterations) : (i += 1) {
        const offset = i * 4;

        // Load 4 elements from each vector
        const vec1 = Vec4{
            vector1.*.data[offset],
            vector1.*.data[offset + 1],
            vector1.*.data[offset + 2],
            vector1.*.data[offset + 3],
        };

        const vec2 = Vec4{
            vector2.*.data[offset],
            vector2.*.data[offset + 1],
            vector2.*.data[offset + 2],
            vector2.*.data[offset + 3],
        };

        // Add vectors and store result
        const sum = vec1 + vec2;
        result.*.data[offset] = sum[0];
        result.*.data[offset + 1] = sum[1];
        result.*.data[offset + 2] = sum[2];
        result.*.data[offset + 3] = sum[3];
    }

    // Handle remaining elements
    const remaining = @mod(len, 4);
    if (remaining > 0) {
        const start: usize = @intCast(len - remaining);
        for (start..@intCast(len)) |j| {
            result.*.data[j] = vector1.*.data[j] + vector2.*.data[j];
        }
    }

    result.*.count = len;
    return result;
}
pub fn subFloatVector(vector1: [*c]FloatVector, vector2: [*c]FloatVector) [*c]FloatVector {
    if (_size(vector1) != _size(vector2)) {
        printf("Vectors are not of the same size\n");
        return null;
    }

    const result = FloatVector.init(_size(vector1));
    const len = vector1.*.count;

    // Process elements in chunks of 4
    const Vec4 = @Vector(4, f64);
    const vec_iterations = @divTrunc(len, 4);

    var i: usize = 0;
    while (i < vec_iterations) : (i += 1) {
        const offset = i * 4;

        // Load 4 elements from each vector
        const vec1 = Vec4{
            vector1.*.data[offset],
            vector1.*.data[offset + 1],
            vector1.*.data[offset + 2],
            vector1.*.data[offset + 3],
        };

        const vec2 = Vec4{
            vector2.*.data[offset],
            vector2.*.data[offset + 1],
            vector2.*.data[offset + 2],
            vector2.*.data[offset + 3],
        };

        // Add vectors and store result
        const diff = vec1 - vec2;
        result.*.data[offset] = diff[0];
        result.*.data[offset + 1] = diff[1];
        result.*.data[offset + 2] = diff[2];
        result.*.data[offset + 3] = diff[3];
    }

    // Handle remaining elements
    const remaining = @mod(len, 4);
    if (remaining > 0) {
        const start: usize = @intCast(len - remaining);
        for (start..@intCast(len)) |j| {
            result.*.data[j] = vector1.*.data[j] - vector2.*.data[j];
        }
    }

    result.*.count = len;
    return result;
}

pub fn mulFloatVector(vector1: [*c]FloatVector, vector2: [*c]FloatVector) [*c]FloatVector {
    if (_size(vector1) != _size(vector2)) {
        printf("Vectors are not of the same size\n");
        return null;
    }

    const result = FloatVector.init(_size(vector1));
    const len = vector1.*.count;

    // Process elements in chunks of 4
    const Vec4 = @Vector(4, f64);
    const vec_iterations = @divTrunc(len, 4);

    var i: usize = 0;
    while (i < vec_iterations) : (i += 1) {
        const offset = i * 4;

        // Load 4 elements from each vector
        const vec1 = Vec4{
            vector1.*.data[offset],
            vector1.*.data[offset + 1],
            vector1.*.data[offset + 2],
            vector1.*.data[offset + 3],
        };

        const vec2 = Vec4{
            vector2.*.data[offset],
            vector2.*.data[offset + 1],
            vector2.*.data[offset + 2],
            vector2.*.data[offset + 3],
        };

        // Add vectors and store result
        const prod = vec1 * vec2;
        result.*.data[offset] = prod[0];
        result.*.data[offset + 1] = prod[1];
        result.*.data[offset + 2] = prod[2];
        result.*.data[offset + 3] = prod[3];
    }

    // Handle remaining elements
    const remaining = @mod(len, 4);
    if (remaining > 0) {
        const start: usize = @intCast(len - remaining);
        for (start..@intCast(len)) |j| {
            result.*.data[j] = vector1.*.data[j] * vector2.*.data[j];
        }
    }

    result.*.count = len;
    return result;
}

pub fn divFloatVector(vector1: [*c]FloatVector, vector2: [*c]FloatVector) [*c]FloatVector {
    if (_size(vector1) != _size(vector2)) {
        printf("Vectors are not of the same size\n");
        return null;
    }

    const result = FloatVector.init(_size(vector1));
    const len = vector1.*.count;

    // Process elements in chunks of 4
    const Vec4 = @Vector(4, f64);
    const vec_iterations = @divTrunc(len, 4);

    var i: usize = 0;
    while (i < vec_iterations) : (i += 1) {
        const offset = i * 4;

        // Load 4 elements from each vector
        const vec1 = Vec4{
            vector1.*.data[offset],
            vector1.*.data[offset + 1],
            vector1.*.data[offset + 2],
            vector1.*.data[offset + 3],
        };

        const vec2 = Vec4{
            vector2.*.data[offset],
            vector2.*.data[offset + 1],
            vector2.*.data[offset + 2],
            vector2.*.data[offset + 3],
        };

        // Add vectors and store result
        const quotient = vec1 / vec2;
        result.*.data[offset] = quotient[0];
        result.*.data[offset + 1] = quotient[1];
        result.*.data[offset + 2] = quotient[2];
        result.*.data[offset + 3] = quotient[3];
    }

    // Handle remaining elements
    const remaining = @mod(len, 4);
    if (remaining > 0) {
        const start: usize = @intCast(len - remaining);
        for (start..@intCast(len)) |j| {
            result.*.data[j] = vector1.*.data[j] / vector2.*.data[j];
        }
    }

    result.*.count = len;
    return result;
}

pub fn equalFloatVector(a: [*c]FloatVector, b: [*c]FloatVector) bool {
    if (_count(a) != _count(b)) return false;

    for (0..@intCast(_count(a))) |i| {
        if (_get(a, @intCast(i)) != _get(b, @intCast(i))) return false;
    }
    return true;
}

pub fn scaleFloatVector(vector: [*c]FloatVector, scalar: f64) [*c]FloatVector {
    const result = FloatVector.init(vector.*.size);
    const simdSize: usize = @intCast(vector.*.count - @mod(vector.*.count, 4));

    // Process 4 elements at a time using Zig SIMD
    var i: usize = 0;
    while (i < simdSize) : (i += 4) {
        const vec4 = @Vector(4, f64){
            vector.*.data[i],
            vector.*.data[i + 1],
            vector.*.data[i + 2],
            vector.*.data[i + 3],
        };
        const scaled = vec4 * @as(@Vector(4, f64), @splat(scalar));

        result.*.data[i] = scaled[0];
        result.*.data[i + 1] = scaled[1];
        result.*.data[i + 2] = scaled[2];
        result.*.data[i + 3] = scaled[3];
    }

    // Process remaining elements
    i = simdSize;
    while (i < vector.*.count) : (i += 1) {
        result.*.data[i] = vector.*.data[i] * scalar;
    }

    result.*.count = vector.*.count;
    return result;
}
pub fn singleAddFloatVector(vector: [*c]FloatVector, scalar: f64) [*c]FloatVector {
    const result = FloatVector.init(vector.*.size);
    const simdSize: usize = @intCast(vector.*.count - @mod(vector.*.count, 4));

    // Process 4 elements at a time using Zig SIMD
    var i: usize = 0;
    while (i < simdSize) : (i += 4) {
        const vec4 = @Vector(4, f64){
            vector.*.data[i],
            vector.*.data[i + 1],
            vector.*.data[i + 2],
            vector.*.data[i + 3],
        };
        const sum = vec4 + @as(@Vector(4, f64), @splat(scalar));

        result.*.data[i] = sum[0];
        result.*.data[i + 1] = sum[1];
        result.*.data[i + 2] = sum[2];
        result.*.data[i + 3] = sum[3];
    }

    // Process remaining elements
    i = simdSize;
    while (i < vector.*.count) : (i += 1) {
        result.*.data[i] = vector.*.data[i] * scalar;
    }

    result.*.count = vector.*.count;
    return result;
}

pub fn singleSubFloatVector(vector: [*c]FloatVector, b: f64) [*c]FloatVector {
    return singleAddFloatVector(vector, b * -1.0);
}

pub fn singleDivFloatVector(a: [*c]FloatVector, b: f64) [*c]FloatVector {
    return scaleFloatVector(a, 1.0 / b);
}

pub fn reverseFloatVector(arg_vector: [*c]FloatVector) void {
    var vector = arg_vector;
    _ = &vector;
    {
        var i: c_int = 0;
        _ = &i;
        while (i < @divTrunc(vector.*.count, @as(c_int, 2))) : (i += 1) {
            var temp: f64 = (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*;
            _ = &temp;
            (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).* = (blk: {
                const tmp = (vector.*.count - i) - 1;
                if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*;
            (blk: {
                const tmp = (vector.*.count - i) - 1;
                if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).* = temp;
        }
    }
}
pub fn nextFloatVector(arg_vector: [*c]FloatVector) f64 {
    var vector = arg_vector;
    _ = &vector;
    if (hasNextFloatVector(vector)) {
        return (blk: {
            const tmp = blk_1: {
                const ref = &vector.*.pos;
                const tmp_2 = ref.*;
                ref.* += 1;
                break :blk_1 tmp_2;
            };
            if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
        }).*;
    }
    return 0.0;
}
pub fn hasNextFloatVector(arg_vector: [*c]FloatVector) bool {
    var vector = arg_vector;
    _ = &vector;
    return vector.*.pos < vector.*.count;
}
pub fn peekFloatVector(arg_vector: [*c]FloatVector, arg_pos: c_int) f64 {
    var vector = arg_vector;
    _ = &vector;
    var pos = arg_pos;
    _ = &pos;
    if (pos < vector.*.count) {
        return (blk: {
            const tmp = pos;
            if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
        }).*;
    }
    return 0.0;
}
pub fn resetFloatVector(arg_vector: [*c]FloatVector) void {
    var vector = arg_vector;
    _ = &vector;
    vector.*.pos = 0;
}
pub fn skipFloatVector(arg_vector: [*c]FloatVector, arg_n: c_int) void {
    var vector = arg_vector;
    _ = &vector;
    var n = arg_n;
    _ = &n;
    vector.*.pos = if ((vector.*.pos + n) < vector.*.count) vector.*.pos + n else vector.*.count;
}
pub fn searchFloatVector(arg_vector: [*c]FloatVector, arg_value: f64) c_int {
    var vector = arg_vector;
    _ = &vector;
    var value = arg_value;
    _ = &value;
    if (vector.*.sorted) {
        return binarySearchFloatVector(vector, value);
    } else {
        {
            var i: c_int = 0;
            _ = &i;
            while (i < vector.*.count) : (i += 1) {
                if ((blk: {
                    const tmp = i;
                    if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                }).* == value) {
                    return i;
                }
            }
        }
    }
    return -1;
}
pub fn linspace(arg_start: f64, arg_end: f64, arg_n: c_int) [*c]FloatVector {
    var start = arg_start;
    _ = &start;
    var end = arg_end;
    _ = &end;
    var n = arg_n;
    _ = &n;
    var result: [*c]FloatVector = FloatVector.init(n);
    _ = &result;
    var step: f64 = (end - start) / @as(f64, @floatFromInt(n - 1));
    _ = &step;
    {
        var i: c_int = 0;
        _ = &i;
        while (i < n) : (i += 1) {
            (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk result.*.data + @as(usize, @intCast(tmp)) else break :blk result.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).* = start + (@as(f64, @floatFromInt(i)) * step);
        }
    }
    result.*.count = n;
    return result;
}
pub fn interp1(arg_x: [*c]FloatVector, arg_y: [*c]FloatVector, arg_x0: f64) f64 {
    var x = arg_x;
    _ = &x;
    var y = arg_y;
    _ = &y;
    var x0 = arg_x0;
    _ = &x0;
    if (x.*.count != y.*.count) {
        printf("x and y must have the same length\n");
        return 0;
    }
    if ((x0 < x.*.data[0]) or (x0 > (blk: {
        const tmp = x.*.count - 1;
        if (tmp >= 0) break :blk x.*.data + @as(usize, @intCast(tmp)) else break :blk x.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).*)) {
        printf("x0 is out of bounds\n");
        return 0;
    }
    var i: c_int = 0;
    _ = &i;
    while (x0 > (blk: {
        const tmp = i;
        if (tmp >= 0) break :blk x.*.data + @as(usize, @intCast(tmp)) else break :blk x.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).*) {
        i += 1;
    }
    if (x0 == (blk: {
        const tmp = i;
        if (tmp >= 0) break :blk x.*.data + @as(usize, @intCast(tmp)) else break :blk x.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).*) {
        return (blk: {
            const tmp = i;
            if (tmp >= 0) break :blk y.*.data + @as(usize, @intCast(tmp)) else break :blk y.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
        }).*;
    }
    var slope: f64 = ((blk: {
        const tmp = i;
        if (tmp >= 0) break :blk y.*.data + @as(usize, @intCast(tmp)) else break :blk y.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).* - (blk: {
        const tmp = i - 1;
        if (tmp >= 0) break :blk y.*.data + @as(usize, @intCast(tmp)) else break :blk y.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).*) / ((blk: {
        const tmp = i;
        if (tmp >= 0) break :blk x.*.data + @as(usize, @intCast(tmp)) else break :blk x.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).* - (blk: {
        const tmp = i - 1;
        if (tmp >= 0) break :blk x.*.data + @as(usize, @intCast(tmp)) else break :blk x.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).*);
    _ = &slope;
    return (blk: {
        const tmp = i - 1;
        if (tmp >= 0) break :blk y.*.data + @as(usize, @intCast(tmp)) else break :blk y.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).* + (slope * (x0 - (blk: {
        const tmp = i - 1;
        if (tmp >= 0) break :blk x.*.data + @as(usize, @intCast(tmp)) else break :blk x.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).*));
}
pub fn dotProduct(arg_a: [*c]FloatVector, arg_b: [*c]FloatVector) f64 {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    if ((a.*.size != @as(c_int, 3)) and (b.*.size != @as(c_int, 3))) {
        printf("Vectors are not of size 3\n");
        return 0;
    }
    return ((a.*.data[0] * b.*.data[0]) + (a.*.data[1] * b.*.data[1])) + (a.*.data[2] * b.*.data[2]);
}
pub fn crossProduct(arg_a: [*c]FloatVector, arg_b: [*c]FloatVector) [*c]FloatVector {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    if ((a.*.size != @as(c_int, 3)) and (b.*.size != @as(c_int, 3))) {
        printf("Vectors are not of size 3\n");
        return null;
    }
    var result: [*c]FloatVector = FloatVector.init(@as(c_int, 3));
    _ = &result;
    result.*.data[0] = (a.*.data[1] * b.*.data[2]) - (a.*.data[2] * b.*.data[1]);
    result.*.data[1] = (a.*.data[2] * b.*.data[0]) - (a.*.data[0] * b.*.data[2]);
    result.*.data[2] = (a.*.data[0] * b.*.data[1]) - (a.*.data[1] * b.*.data[0]);
    result.*.count = 3;
    return result;
}
pub fn magnitude(arg_vector: [*c]FloatVector) f64 {
    var vector = arg_vector;
    _ = &vector;
    var sum: f64 = (std.math.pow(f64, vector.*.data[0], @as(f64, @floatFromInt(@as(c_int, 2)))) + std.math.pow(f64, vector.*.data[1], @as(f64, @floatFromInt(@as(c_int, 2))))) + std.math.pow(f64, vector.*.data[2], @as(f64, @floatFromInt(@as(c_int, 2))));
    _ = &sum;
    return @sqrt(sum);
}
pub fn normalize(arg_vector: [*c]FloatVector) [*c]FloatVector {
    var vector = arg_vector;
    _ = &vector;
    var mag: f64 = magnitude(vector);
    _ = &mag;
    if (mag == @as(f64, @floatFromInt(0))) {
        printf("Cannot normalize a zero vector\n");
        return null;
    }
    return scaleFloatVector(vector, 1.0 / mag);
}
pub fn projection(arg_a: [*c]FloatVector, arg_b: [*c]FloatVector) [*c]FloatVector {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    return scaleFloatVector(b, dotProduct(a, b) / dotProduct(b, b));
}
pub fn rejection(arg_a: [*c]FloatVector, arg_b: [*c]FloatVector) [*c]FloatVector {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    return subFloatVector(a, projection(a, b));
}
pub fn reflection(arg_a: [*c]FloatVector, arg_b: [*c]FloatVector) [*c]FloatVector {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    return subFloatVector(scaleFloatVector(projection(a, b), @as(f64, @floatFromInt(@as(c_int, 2)))), a);
}
pub fn refraction(arg_a: [*c]FloatVector, arg_b: [*c]FloatVector, arg_n1: f64, arg_n2: f64) [*c]FloatVector {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    var n1 = arg_n1;
    _ = &n1;
    var n2 = arg_n2;
    _ = &n2;
    var dot: f64 = dotProduct(a, b);
    _ = &dot;
    var mag_a: f64 = magnitude(a);
    _ = &mag_a;
    var mag_b: f64 = magnitude(b);
    _ = &mag_b;
    var theta: f64 = std.math.acos(dot / (mag_a * mag_b));
    _ = &theta;
    var sin_theta_r: f64 = (n1 / n2) * std.math.sin(theta);
    _ = &sin_theta_r;
    if (sin_theta_r > @as(f64, @floatFromInt(1))) {
        printf("Total internal reflection\n");
        return null;
    }
    var cos_theta_r: f64 = @sqrt(@as(f64, @floatFromInt(1)) - std.math.pow(f64, sin_theta_r, @as(f64, @floatFromInt(@as(c_int, 2)))));
    _ = &cos_theta_r;
    var result: [*c]FloatVector = scaleFloatVector(a, n1 / n2);
    _ = &result;
    var temp: [*c]FloatVector = scaleFloatVector(b, ((n1 / n2) * cos_theta_r) - @sqrt(@as(f64, @floatFromInt(1)) - std.math.pow(f64, sin_theta_r, @as(f64, @floatFromInt(@as(c_int, 2))))));
    _ = &temp;
    return addFloatVector(result, temp);
}
pub fn angle(arg_a: [*c]FloatVector, arg_b: [*c]FloatVector) f64 {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    return std.math.acos(dotProduct(a, b) / (magnitude(a) * magnitude(b)));
}

pub fn compare_double(arg_a: ?*const anyopaque, arg_b: ?*const anyopaque) callconv(.C) c_int {
    const a: *f64 = @ptrCast(@constCast(@alignCast(arg_a)));
    const b: *f64 = @ptrCast(@constCast(@alignCast(arg_b)));

    return @intFromFloat(a.* - b.*);
}
pub fn binarySearchFloatVector(arg_vector: [*c]FloatVector, arg_value: f64) callconv(.C) c_int {
    var vector = arg_vector;
    _ = &vector;
    var value = arg_value;
    _ = &value;
    var left: c_int = 0;
    _ = &left;
    var right: c_int = vector.*.count - 1;
    _ = &right;
    while (left <= right) {
        var mid: c_int = left + @divTrunc(right - left, @as(c_int, 2));
        _ = &mid;
        if ((blk: {
            const tmp = mid;
            if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
        }).* == value) {
            return mid;
        }
        if ((blk: {
            const tmp = mid;
            if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
        }).* < value) {
            left = mid + 1;
        } else {
            right = mid - 1;
        }
    }
    return -1;
}
