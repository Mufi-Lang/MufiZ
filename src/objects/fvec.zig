const obj_h = @import("obj.zig");
const Obj = obj_h.Obj;
const allocateObject = @import("../object.zig").allocateObject;
const reallocate = @import("../memory.zig").reallocate;
const std = @import("std");

fn printf(s: []const u8) void {
    std.debug.print("{s}", .{s});
}
const qsort = @cImport(@cInclude("stdlib.h")).qsort;

pub const FloatVector = extern struct {
    obj: Obj,
    size: c_int,
    count: c_int,
    pos: c_int,
    data: [*c]f64 = @import("std").mem.zeroes([*c]f64),
    sorted: bool,
};

pub fn sortFloatVector(vector: *FloatVector) void {
    if (vector.sorted) return;
    if (vector.count <= 1) {
        vector.sorted = true;
        return;
    }

    quickSort(vector.data, 0, vector.count - 1);
    vector.sorted = true;
}

fn quickSort(arr: [*c]f64, low: c_int, high: c_int) void {
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

fn partition(arr: [*c]f64, low: c_int, high: c_int) c_int {
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

fn swap(arr: [*c]f64, i: c_int, j: c_int) void {
    const temp = arr[@intCast(i)];
    arr[@intCast(i)] = arr[@intCast(j)];
    arr[@intCast(j)] = temp;
}

// SIMD
pub const __m256 = @Vector(8, f32);
pub const __m256d = @Vector(4, f64);
pub const __m256_u = @Vector(8, f32);
pub const __m256d_u = @Vector(4, f64);

pub inline fn _mm256_setzero_pd() __m256d {
    return .{ 0.0, 0.0, 0.0, 0.0 };
}

pub inline fn _mm256_storeu_pd(p: [*c]f64, a: __m256d) void {
    const __p = p;
    const __a = a;
    const struct___storeu_pd = extern struct {
        __v: __m256d_u align(1) = @import("std").mem.zeroes(__m256d_u),
    };
    @as([*c]struct___storeu_pd, @ptrCast(@alignCast(__p))).*.__v = __a;
}

pub inline fn _mm256_loadu_pd(p: [*c]const f64) __m256d {
    const __p = p;
    const struct___loadu_pd = extern struct {
        __v: __m256d_u align(1) = @import("std").mem.zeroes(__m256d_u),
    };
    return @as([*c]const struct___loadu_pd, @ptrCast(@alignCast(__p))).*.__v;
}

pub inline fn _mm256_add_pd(a: __m256d, b: __m256d) __m256d {
    return a + b;
}

pub inline fn _mm256_sub_pd(a: __m256d, b: __m256d) __m256d {
    return a - b;
}

pub inline fn _mm256_mul_pd(a: __m256d, b: __m256d) __m256d {
    return a * b;
}

pub inline fn _mm256_div_pd(a: __m256d, b: __m256d) __m256d {
    return a / b;
}

pub inline fn _mm256_fmadd_pd(a: __m256d, b: __m256d, c: __m256d) __m256d {
    return @mulAdd(__m256d, a, b, c);
}

pub inline fn _mm256_set1_pd(w: f64) __m256d {
    return _mm256_set_pd(w, w, w, w);
}

pub inline fn _mm256_set_pd(a: f64, b: f64, c: f64, d: f64) __m256d {
    return .{ d, c, b, a };
}

pub fn newFloatVector(arg_size: c_int) [*c]FloatVector {
    var size = arg_size;
    _ = &size;
    var vector: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(allocateObject(@sizeOf(FloatVector), .OBJ_FVECTOR))));
    _ = &vector;
    vector.*.size = size;
    vector.*.count = 0;
    vector.*.data = @as([*c]f64, @ptrCast(@alignCast(reallocate(null, 0, @intCast(@sizeOf(f64) *% size)))));
    return vector;
}
pub fn cloneFloatVector(arg_vector: [*c]FloatVector) [*c]FloatVector {
    var vector = arg_vector;
    _ = &vector;
    var newVector: [*c]FloatVector = newFloatVector(vector.*.size);
    _ = &newVector;
    {
        var i: c_int = 0;
        _ = &i;
        while (i < vector.*.count) : (i += 1) {
            pushFloatVector(newVector, (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*);
        }
    }
    return newVector;
}
pub fn clearFloatVector(arg_vector: [*c]FloatVector) void {
    var vector = arg_vector;
    _ = &vector;
    vector.*.count = 0;
    vector.*.sorted = false;
}
pub fn freeFloatVector(arg_vector: [*c]FloatVector) void {
    var vector = arg_vector;
    _ = &vector;
    _ = reallocate(@as(?*anyopaque, @ptrCast(vector.*.data)), @intCast(@sizeOf(f32) *% vector.*.size), 0);
    _ = reallocate(@as(?*anyopaque, @ptrCast(vector)), @sizeOf(FloatVector), 0);
}

pub fn pushFloatVector(vector: [*c]FloatVector, value: f64) void {
    if (vector.*.count + 1 > vector.*.size) {
        printf("Vector is full\n");
        return;
    }
    vector.*.data[@intCast(vector.*.count)] = value;
    vector.*.count += 1;

    if (vector.*.count > 1 and vector.*.data[@intCast(vector.*.count - 2)] > value) vector.*.sorted = false;
}

pub fn insertFloatVector(vector: [*c]FloatVector, index_1: c_int, value: f64) void {
    if ((index_1 < 0) or (index_1 >= vector.*.size)) {
        printf("Index out of bounds\n");
        return;
    }
    var i: usize = @intCast(vector.*.count);
    while (i > index_1) : (i -= 1) {
        vector.*.data[i] = vector.*.data[i - 1];
    }

    vector.*.data[@intCast(index_1)] = value;
    vector.*.count += 1;

    if (vector.*.count > 1 and (vector.*.data[@intCast(index_1)] < vector.*.data[@intCast(index_1 - 1)])) vector.*.sorted = false;
}

pub fn getFloatVector(arg_vector: [*c]FloatVector, arg_index_1: c_int) f64 {
    var vector = arg_vector;
    _ = &vector;
    var index_1 = arg_index_1;
    _ = &index_1;
    if ((index_1 < 0) or (index_1 >= vector.*.count)) {
        printf("Index out of bounds\n");
        return 0;
    }
    return (blk: {
        const tmp = index_1;
        if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).*;
}

pub fn popFloatVector(arg_vector: [*c]FloatVector) f64 {
    var vector = arg_vector;
    _ = &vector;
    if (vector.*.count == 0) {
        printf("Vector is empty\n");
        return 0;
    }
    var poppedValue: f64 = (blk: {
        const tmp = blk_1: {
            const ref = &vector.*.count;
            ref.* -= 1;
            break :blk_1 ref.*;
        };
        if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).*;
    _ = &poppedValue;
    if (vector.*.count == 0) {
        vector.*.sorted = false;
    }
    return poppedValue;
}
pub fn removeFloatVector(arg_vector: [*c]FloatVector, arg_index_1: c_int) f64 {
    var vector = arg_vector;
    _ = &vector;
    var index_1 = arg_index_1;
    _ = &index_1;
    if ((index_1 < 0) or (index_1 >= vector.*.count)) {
        printf("Index out of bounds\n");
        return 0;
    }
    var removedValue: f64 = (blk: {
        const tmp = index_1;
        if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).*;
    _ = &removedValue;
    {
        var i: c_int = index_1;
        _ = &i;
        while (i < (vector.*.count - 1)) : (i += 1) {
            (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).* = (blk: {
                const tmp = i + 1;
                if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*;
        }
    }
    vector.*.count -= 1;
    if (((@as(c_int, @intFromBool(vector.*.sorted)) != 0) and (index_1 > 0)) and ((blk: {
        const tmp = index_1;
        if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).* < (blk: {
        const tmp = index_1 - 1;
        if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).*)) {
        vector.*.sorted = false;
    }
    return removedValue;
}

pub fn printFloatVector(arg_vector: [*c]FloatVector) void {
    var vector = arg_vector;
    _ = &vector;
    printf("[");
    {
        var i: c_int = 0;
        _ = &i;
        while (i < vector.*.count) : (i += 1) {
            printf("%.2f ", (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*);
        }
    }
    printf("]");
    printf("\n");
}

pub fn mergeFloatVector(arg_a: [*c]FloatVector, arg_b: [*c]FloatVector) [*c]FloatVector {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    var result: [*c]FloatVector = newFloatVector(a.*.size + b.*.size);
    _ = &result;
    {
        var i: c_int = 0;
        _ = &i;
        while (i < a.*.count) : (i += 1) {
            pushFloatVector(result, (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk a.*.data + @as(usize, @intCast(tmp)) else break :blk a.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*);
        }
    }
    {
        var i: c_int = 0;
        _ = &i;
        while (i < b.*.count) : (i += 1) {
            pushFloatVector(result, (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk b.*.data + @as(usize, @intCast(tmp)) else break :blk b.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*);
        }
    }
    return result;
}

pub fn sliceFloatVector(arg_vector: [*c]FloatVector, arg_start: c_int, arg_end: c_int) [*c]FloatVector {
    var vector = arg_vector;
    _ = &vector;
    var start = arg_start;
    _ = &start;
    var end = arg_end;
    _ = &end;
    if ((((start < 0) or (start >= vector.*.count)) or (end < 0)) or (end >= vector.*.count)) {
        printf("Index out of bounds\n");
        return null;
    }
    var result: [*c]FloatVector = newFloatVector((end - start) + 1);
    _ = &result;
    {
        var i: c_int = start;
        _ = &i;
        while (i <= end) : (i += 1) {
            pushFloatVector(result, (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*);
        }
    }
    return result;
}
pub fn spliceFloatVector(arg_vector: [*c]FloatVector, arg_start: c_int, arg_end: c_int) [*c]FloatVector {
    var vector = arg_vector;
    _ = &vector;
    var start = arg_start;
    _ = &start;
    var end = arg_end;
    _ = &end;
    if ((((start < 0) or (start >= vector.*.count)) or (end < 0)) or (end >= vector.*.count)) {
        printf("Index out of bounds\n");
        return null;
    }
    var result: [*c]FloatVector = newFloatVector(vector.*.size);
    _ = &result;
    {
        var i: c_int = 0;
        _ = &i;
        while (i < start) : (i += 1) {
            pushFloatVector(result, (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*);
        }
    }
    {
        var i: c_int = end + 1;
        _ = &i;
        while (i < vector.*.count) : (i += 1) {
            pushFloatVector(result, (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*);
        }
    }
    return result;
}

pub fn sumFloatVector(arg_vector: [*c]FloatVector) f64 {
    var vector = arg_vector;
    _ = &vector;
    var sum: f64 = 0;
    _ = &sum;
    var simdSize: usize = @intCast(@as(usize, @intCast(vector.*.count)) - @as(usize, @intCast(vector.*.count)) % 4);
    _ = &simdSize;
    var simd_sum: __m256 = @as(__m256, @bitCast(_mm256_setzero_pd()));
    _ = &simd_sum;
    {
        var i: usize = 0;
        _ = &i;
        while (i < simdSize) : (i +%= 4) {
            var simd_arr: __m256 = @as(__m256, @bitCast(_mm256_loadu_pd(&vector.*.data[i])));
            _ = &simd_arr;
            simd_sum = @as(__m256, @bitCast(_mm256_add_pd(@as(__m256d, @bitCast(simd_arr)), @as(__m256d, @bitCast(simd_sum)))));
        }
    }
    {
        var i: usize = simdSize;
        _ = &i;
        while (i < vector.*.count) : (i +%= 1) {
            sum += vector.*.data[i];
        }
    }
    var simd_sum_arr: [4]f64 = undefined;
    _ = &simd_sum_arr;
    _mm256_storeu_pd(@as([*c]f64, @ptrCast(@alignCast(&simd_sum_arr))), @as(__m256d, @bitCast(simd_sum)));
    {
        var i: c_int = 0;
        _ = &i;
        while (i < @as(c_int, 4)) : (i += 1) {
            sum += simd_sum_arr[@as(c_uint, @intCast(i))];
        }
    }
    return sum;
}
pub fn meanFloatVector(arg_vector: [*c]FloatVector) f64 {
    var vector = arg_vector;
    _ = &vector;
    return sumFloatVector(vector) / @as(f64, @floatFromInt(vector.*.count));
}
pub fn varianceFloatVector(arg_vector: [*c]FloatVector) f64 {
    var vector = arg_vector;
    _ = &vector;
    var mean: f64 = meanFloatVector(vector);
    _ = &mean;
    var variance: f64 = 0;
    _ = &variance;
    var simdSize: usize = @intCast(@as(usize, @intCast(vector.*.count)) - @as(usize, @intCast(vector.*.count)) % 4);
    _ = &simdSize;
    var simd_variance: __m256 = @as(__m256, @bitCast(_mm256_setzero_pd()));
    _ = &simd_variance;
    {
        var i: usize = 0;
        _ = &i;
        while (i < simdSize) : (i +%= 4) {
            var simd_arr: __m256 = @as(__m256, @bitCast(_mm256_loadu_pd(&vector.*.data[i])));
            _ = &simd_arr;
            var simd_diff: __m256 = @as(__m256, @bitCast(_mm256_sub_pd(@as(__m256d, @bitCast(simd_arr)), _mm256_set1_pd(mean))));
            _ = &simd_diff;
            simd_variance = @as(__m256, @bitCast(_mm256_fmadd_pd(@as(__m256d, @bitCast(simd_diff)), @as(__m256d, @bitCast(simd_diff)), @as(__m256d, @bitCast(simd_variance)))));
        }
    }
    {
        var i: usize = simdSize;
        _ = &i;
        while (i < vector.*.count) : (i +%= 1) {
            variance += (vector.*.data[i] - mean) * (vector.*.data[i] - mean);
        }
    }
    var simd_variance_arr: [4]f64 = undefined;
    _ = &simd_variance_arr;
    _mm256_storeu_pd(@as([*c]f64, @ptrCast(@alignCast(&simd_variance_arr))), @as(__m256d, @bitCast(simd_variance)));
    {
        var i: c_int = 0;
        _ = &i;
        while (i < @as(c_int, 4)) : (i += 1) {
            variance += simd_variance_arr[@as(c_uint, @intCast(i))];
        }
    }
    return variance / @as(f64, @floatFromInt(vector.*.count - 1));
}
pub fn stdDevFloatVector(arg_vector: [*c]FloatVector) f64 {
    var vector = arg_vector;
    _ = &vector;
    return @sqrt(varianceFloatVector(vector));
}
pub fn maxFloatVector(arg_vector: [*c]FloatVector) f64 {
    var vector = arg_vector;
    _ = &vector;
    var _max: f64 = vector.*.data[0];
    _ = &_max;
    {
        var i: c_int = 1;
        _ = &i;
        while (i < vector.*.count) : (i += 1) {
            if ((blk: {
                const tmp = i;
                if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).* > _max) {
                _max = (blk: {
                    const tmp = i;
                    if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                }).*;
            }
        }
    }
    return _max;
}

pub fn minFloatVector(arg_vector: [*c]FloatVector) f64 {
    var vector = arg_vector;
    _ = &vector;
    var min: f64 = vector.*.data[0];
    _ = &min;
    {
        var i: c_int = 1;
        _ = &i;
        while (i < vector.*.count) : (i += 1) {
            if ((blk: {
                const tmp = i;
                if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).* < min) {
                min = (blk: {
                    const tmp = i;
                    if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                }).*;
            }
        }
    }
    return min;
}
pub fn addFloatVector(arg_vector1: [*c]FloatVector, arg_vector2: [*c]FloatVector) [*c]FloatVector {
    var vector1 = arg_vector1;
    _ = &vector1;
    var vector2 = arg_vector2;
    _ = &vector2;
    if (vector1.*.size != vector2.*.size) {
        printf("Vectors are not of the same size\n");
        return null;
    }
    var result: [*c]FloatVector = newFloatVector(vector1.*.size);
    _ = &result;
    var simdSize: usize = @intCast(@as(usize, @intCast(vector1.*.count)) - @as(usize, @intCast(vector1.*.count)) % 4);
    _ = &simdSize;
    {
        var i: usize = 0;
        _ = &i;
        while (i < simdSize) : (i +%= 4) {
            var simd_arr1: __m256 = @as(__m256, @bitCast(_mm256_loadu_pd(&vector1.*.data[i])));
            _ = &simd_arr1;
            var simd_arr2: __m256 = @as(__m256, @bitCast(_mm256_loadu_pd(&vector2.*.data[i])));
            _ = &simd_arr2;
            var simd_result: __m256 = @as(__m256, @bitCast(_mm256_add_pd(@as(__m256d, @bitCast(simd_arr1)), @as(__m256d, @bitCast(simd_arr2)))));
            _ = &simd_result;
            _mm256_storeu_pd(&result.*.data[i], @as(__m256d, @bitCast(simd_result)));
        }
    }
    {
        var i: usize = simdSize;
        _ = &i;
        while (i < vector1.*.count) : (i +%= 1) {
            result.*.data[i] = vector1.*.data[i] + vector2.*.data[i];
        }
    }
    result.*.count = vector1.*.count;
    return result;
}
pub fn subFloatVector(arg_vector1: [*c]FloatVector, arg_vector2: [*c]FloatVector) [*c]FloatVector {
    var vector1 = arg_vector1;
    _ = &vector1;
    var vector2 = arg_vector2;
    _ = &vector2;
    if (vector1.*.size != vector2.*.size) {
        printf("Vectors are not of the same size\n");
        return null;
    }
    var result: [*c]FloatVector = newFloatVector(vector1.*.size);
    _ = &result;
    var simdSize: usize = @intCast(@as(usize, @intCast(vector1.*.count)) - @as(usize, @intCast(vector1.*.count)) % 4);
    _ = &simdSize;
    {
        var i: usize = 0;
        _ = &i;
        while (i < simdSize) : (i +%= 4) {
            var simd_arr1: __m256 = @as(__m256, @bitCast(_mm256_loadu_pd(&vector1.*.data[i])));
            _ = &simd_arr1;
            var simd_arr2: __m256 = @as(__m256, @bitCast(_mm256_loadu_pd(&vector2.*.data[i])));
            _ = &simd_arr2;
            var simd_result: __m256 = @as(__m256, @bitCast(_mm256_sub_pd(@as(__m256d, @bitCast(simd_arr1)), @as(__m256d, @bitCast(simd_arr2)))));
            _ = &simd_result;
            _mm256_storeu_pd(&result.*.data[i], @as(__m256d, @bitCast(simd_result)));
        }
    }
    {
        var i: usize = simdSize;
        _ = &i;
        while (i < vector1.*.count) : (i +%= 1) {
            result.*.data[i] = vector1.*.data[i] - vector2.*.data[i];
        }
    }
    result.*.count = vector1.*.count;
    return result;
}
pub fn mulFloatVector(arg_vector1: [*c]FloatVector, arg_vector2: [*c]FloatVector) [*c]FloatVector {
    var vector1 = arg_vector1;
    _ = &vector1;
    var vector2 = arg_vector2;
    _ = &vector2;
    if (vector1.*.size != vector2.*.size) {
        printf("Vectors are not of the same size\n");
        return null;
    }
    var result: [*c]FloatVector = newFloatVector(vector1.*.size);
    _ = &result;
    var simdSize: usize = @intCast(@as(usize, @intCast(vector1.*.count)) - @as(usize, @intCast(vector1.*.count)) % 4);
    _ = &simdSize;
    {
        var i: usize = 0;
        _ = &i;
        while (i < simdSize) : (i +%= 4) {
            var simd_arr1: __m256 = @as(__m256, @bitCast(_mm256_loadu_pd(&vector1.*.data[i])));
            _ = &simd_arr1;
            var simd_arr2: __m256 = @as(__m256, @bitCast(_mm256_loadu_pd(&vector2.*.data[i])));
            _ = &simd_arr2;
            var simd_result: __m256 = @as(__m256, @bitCast(_mm256_mul_pd(@as(__m256d, @bitCast(simd_arr1)), @as(__m256d, @bitCast(simd_arr2)))));
            _ = &simd_result;
            _mm256_storeu_pd(&result.*.data[i], @as(__m256d, @bitCast(simd_result)));
        }
    }
    {
        var i: usize = simdSize;
        _ = &i;
        while (i < vector1.*.count) : (i +%= 1) {
            result.*.data[i] = vector1.*.data[i] * vector2.*.data[i];
        }
    }
    result.*.count = vector1.*.count;
    return result;
}
pub fn divFloatVector(arg_vector1: [*c]FloatVector, arg_vector2: [*c]FloatVector) [*c]FloatVector {
    var vector1 = arg_vector1;
    _ = &vector1;
    var vector2 = arg_vector2;
    _ = &vector2;
    if (vector1.*.size != vector2.*.size) {
        printf("Vectors are not of the same size\n");
        return null;
    }
    var result: [*c]FloatVector = newFloatVector(vector1.*.size);
    _ = &result;
    var simdSize: usize = @intCast(@as(usize, @intCast(vector1.*.count)) - @as(usize, @intCast(vector1.*.count)) % 4);
    _ = &simdSize;
    {
        var i: usize = 0;
        _ = &i;
        while (i < simdSize) : (i +%= 4) {
            var simd_arr1: __m256 = @as(__m256, @bitCast(_mm256_loadu_pd(&vector1.*.data[i])));
            _ = &simd_arr1;
            var simd_arr2: __m256 = @as(__m256, @bitCast(_mm256_loadu_pd(&vector2.*.data[i])));
            _ = &simd_arr2;
            var simd_result: __m256 = @as(__m256, @bitCast(_mm256_div_pd(@as(__m256d, @bitCast(simd_arr1)), @as(__m256d, @bitCast(simd_arr2)))));
            _ = &simd_result;
            _mm256_storeu_pd(&result.*.data[i], @as(__m256d, @bitCast(simd_result)));
        }
    }
    {
        var i: usize = simdSize;
        _ = &i;
        while (i < vector1.*.count) : (i +%= 1) {
            result.*.data[i] = vector1.*.data[i] / vector2.*.data[i];
        }
    }
    result.*.count = vector1.*.count;
    return result;
}
pub fn equalFloatVector(a: [*c]FloatVector, b: [*c]FloatVector) bool {
    if (a.*.count != b.*.count) return false;

    for (0..@intCast(a.*.count)) |i| {
        if (a.*.data[i] != b.*.data[i]) return false;
    }
    return true;
}
pub fn scaleFloatVector(arg_vector: [*c]FloatVector, arg_scalar: f64) [*c]FloatVector {
    var vector = arg_vector;
    _ = &vector;
    var scalar = arg_scalar;
    _ = &scalar;
    var result: [*c]FloatVector = newFloatVector(vector.*.size);
    _ = &result;
    var simdSize: usize = @intCast(@as(usize, @intCast(vector.*.count)) - @as(usize, @intCast(vector.*.count)) % 4);
    _ = &simdSize;
    {
        var i: usize = 0;
        _ = &i;
        while (i < simdSize) : (i +%= 4) {
            var simd_arr1: __m256 = @as(__m256, @bitCast(_mm256_loadu_pd(&vector.*.data[i])));
            _ = &simd_arr1;
            var simd_scalar: __m256 = @as(__m256, @bitCast(_mm256_set1_pd(scalar)));
            _ = &simd_scalar;
            var simd_result: __m256 = @as(__m256, @bitCast(_mm256_mul_pd(@as(__m256d, @bitCast(simd_arr1)), @as(__m256d, @bitCast(simd_scalar)))));
            _ = &simd_result;
            _mm256_storeu_pd(&result.*.data[i], @as(__m256d, @bitCast(simd_result)));
        }
    }
    {
        var i: usize = simdSize;
        _ = &i;
        while (i < vector.*.count) : (i +%= 1) {
            result.*.data[i] = vector.*.data[i] * scalar;
        }
    }
    result.*.count = vector.*.count;
    return result;
}
pub fn singleAddFloatVector(arg_a: [*c]FloatVector, arg_b: f64) [*c]FloatVector {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    var result: [*c]FloatVector = newFloatVector(a.*.size);
    _ = &result;
    var simdSize: usize = @intCast(@as(usize, @intCast(a.*.count)) - @as(usize, @intCast(a.*.count)) % 4);
    _ = &simdSize;
    {
        var i: usize = 0;
        _ = &i;
        while (i < simdSize) : (i +%= 4) {
            var simd_arr1: __m256 = @as(__m256, @bitCast(_mm256_loadu_pd(&a.*.data[i])));
            _ = &simd_arr1;
            var simd_scalar: __m256 = @as(__m256, @bitCast(_mm256_set1_pd(b)));
            _ = &simd_scalar;
            var simd_result: __m256 = @as(__m256, @bitCast(_mm256_add_pd(@as(__m256d, @bitCast(simd_arr1)), @as(__m256d, @bitCast(simd_scalar)))));
            _ = &simd_result;
            _mm256_storeu_pd(&result.*.data[i], @as(__m256d, @bitCast(simd_result)));
        }
    }
    {
        var i: usize = simdSize;
        _ = &i;
        while (i < a.*.count) : (i +%= 1) {
            result.*.data[i] = a.*.data[i] + b;
        }
    }
    result.*.count = a.*.count;
    return result;
}
pub fn singleSubFloatVector(arg_a: [*c]FloatVector, arg_b: f64) [*c]FloatVector {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    var result: [*c]FloatVector = newFloatVector(a.*.size);
    _ = &result;
    var simdSize: usize = @intCast(@as(usize, @intCast(a.*.count)) - @as(usize, @intCast(a.*.count)) % 4);
    _ = &simdSize;
    {
        var i: usize = 0;
        _ = &i;
        while (i < simdSize) : (i +%= 4) {
            var simd_arr1: __m256 = @as(__m256, @bitCast(_mm256_loadu_pd(&a.*.data[i])));
            _ = &simd_arr1;
            var simd_scalar: __m256 = @as(__m256, @bitCast(_mm256_set1_pd(b)));
            _ = &simd_scalar;
            var simd_result: __m256 = @as(__m256, @bitCast(_mm256_sub_pd(@as(__m256d, @bitCast(simd_arr1)), @as(__m256d, @bitCast(simd_scalar)))));
            _ = &simd_result;
            _mm256_storeu_pd(&result.*.data[i], @as(__m256d, @bitCast(simd_result)));
        }
    }
    {
        var i: usize = simdSize;
        _ = &i;
        while (i < a.*.count) : (i +%= 1) {
            result.*.data[i] = a.*.data[i] - b;
        }
    }
    result.*.count = a.*.count;
    return result;
}
pub extern fn singleMulFloatVector(a: [*c]FloatVector, b: f64) [*c]FloatVector;
pub fn singleDivFloatVector(arg_a: [*c]FloatVector, arg_b: f64) [*c]FloatVector {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
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
    var result: [*c]FloatVector = newFloatVector(n);
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
    var result: [*c]FloatVector = newFloatVector(@as(c_int, 3));
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
