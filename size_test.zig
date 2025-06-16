const std = @import("std");

const Value = @import("src/value.zig").Value;
const ValueType = @import("src/value.zig").ValueType;
const Complex = @import("src/value.zig").Complex;

pub fn main() void {
    std.debug.print("Value struct size: {} bytes\n", .{@sizeOf(Value)});
    std.debug.print("ValueType enum size: {} bytes\n", .{@sizeOf(ValueType)});
    std.debug.print("Complex struct size: {} bytes\n", .{@sizeOf(Complex)});
    std.debug.print("f64 size: {} bytes\n", .{@sizeOf(f64)});
    std.debug.print("i32 size: {} bytes\n", .{@sizeOf(i32)});
    std.debug.print("bool size: {} bytes\n", .{@sizeOf(bool)});
    std.debug.print("*void size: {} bytes\n", .{@sizeOf(*void)});

    // Show alignment
    std.debug.print("Value alignment: {} bytes\n", .{@alignOf(Value)});
}
