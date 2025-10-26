const std = @import("std");

const Value = @import("src/value.zig").Value;
const ValueType = @import("src/value.zig").ValueType;
const Complex = @import("src/value.zig").Complex;
const Obj = @import("src/objects/obj.zig").Obj;
const ObjType = @import("src/objects/obj.zig").ObjType;
const Generation = @import("src/objects/obj.zig").Generation;
const CycleColor = @import("src/objects/obj.zig").CycleColor;

pub fn main() void {
    std.debug.print("=== Value Structure ===\n", .{});
    std.debug.print("Value struct size: {} bytes\n", .{@sizeOf(Value)});
    std.debug.print("ValueType enum size: {} bytes\n", .{@sizeOf(ValueType)});
    std.debug.print("Complex struct size: {} bytes\n", .{@sizeOf(Complex)});
    std.debug.print("f64 size: {} bytes\n", .{@sizeOf(f64)});
    std.debug.print("i32 size: {} bytes\n", .{@sizeOf(i32)});
    std.debug.print("bool size: {} bytes\n", .{@sizeOf(bool)});
    std.debug.print("*void size: {} bytes\n", .{@sizeOf(*void)});
    std.debug.print("Value alignment: {} bytes\n", .{@alignOf(Value)});

    std.debug.print("\n=== Object Structure (OPTIMIZED) ===\n", .{});
    std.debug.print("Obj struct size: {} bytes (target: ≤24 bytes)\n", .{@sizeOf(Obj)});
    std.debug.print("Obj alignment: {} bytes\n", .{@alignOf(Obj)});
    std.debug.print("ObjType enum size: {} bytes\n", .{@sizeOf(ObjType)});
    std.debug.print("Generation enum size: {} bytes\n", .{@sizeOf(Generation)});
    std.debug.print("CycleColor enum size: {} bytes\n", .{@sizeOf(CycleColor)});
    
    const obj_size = @sizeOf(Obj);
    const old_size = 48; // Approximate old size with poor packing
    const savings = old_size - obj_size;
    const savings_pct = (savings * 100) / old_size;
    
    std.debug.print("\n=== Memory Savings ===\n", .{});
    std.debug.print("Old Obj size: ~{} bytes (with poor field ordering)\n", .{old_size});
    std.debug.print("New Obj size: {} bytes (with optimized field ordering)\n", .{obj_size});
    std.debug.print("Savings per object: {} bytes ({}% reduction)\n", .{savings, savings_pct});
    std.debug.print("Objects per cache line (64 bytes): {} objects\n", .{64 / obj_size});
}
