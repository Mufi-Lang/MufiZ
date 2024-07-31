const std = @import("std");

fn addArrays(arr1: []const f64, arr2: []const f64, comptime size: usize) [size]f64 {
    const Vector = @Vector(4, f64);
    var result: [size]f64 = undefined;
    var i: usize = 0;
    while (i + 4 <= size) : (i += 4) {
        const v1: Vector = arr1[i..][0..4].*;
        const v2: Vector = arr2[i..][0..4].*;
        const sum: Vector = v1 + v2;
        @memcpy(result[i..][0..4], sum);
    }
    while (i < size) : (i += 1) {
        result[i] = arr1[i] + arr2[i];
    }
    return result;
}

pub fn main() !void {
    const size = 15;
    const arr1 = [_]f64{ 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0 };
    const arr2 = [_]f64{ 1.0, 2.0, 1.0, 2.0, 1.0, 2.0, 1.0, 2.0, 1.0, 2.0, 1.0, 2.0, 1.0, 2.0, 1.0 };

    const result = addArrays(&arr1, &arr2, size);

    std.debug.print("Result: ", .{});
    for (result) |val| {
        std.debug.print("{d:.2} ", .{val});
    }
    std.debug.print("\n", .{});
}
