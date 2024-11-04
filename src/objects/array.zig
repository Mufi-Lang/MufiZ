const allocateObject = @import("../object.zig").allocateObject;
const reallocate = @import("../memory.zig").reallocate;
const Obj = @import("obj.zig").Obj;
const Value = @import("../value.zig").Value;
const std = @import("std");
const print = std.debug.print;

// The goal to have this by its own to help optimize this,
// easily look over the bounded methods and start putting optimizations
// similar to whats in the Zig ArrayList.

pub const ObjArray = extern struct {
    obj: Obj,
    capacity: Int,
    count: Int,
    pos: Int,
    _static: bool,
    values: [*c]Value,

    const Self = [*c]@This();
    const Int = i32;

    pub fn init(cap: Int, static: bool) Self {
        const self: Self = @ptrCast(@alignCast(allocateObject(@sizeOf(ObjArray), .OBJ_ARRAY)));
        self.*.capacity = cap;
        self.*.count = 0;
        self.*.values = @ptrCast(@alignCast(reallocate(null, 0, @intCast(@sizeOf(Value) *% cap))));
        self.*._static = static;
        return self;
    }

    pub fn deinit(self: Self) void {
        _ = reallocate(@ptrCast(self.*.values), @intCast(@sizeOf(Value) * self.*.capacity), 0);
        _ = reallocate(@ptrCast(self), @intCast(@sizeOf(ObjArray)), 0);
    }

    pub fn push(self: Self, value: Value) void {
        if ((self.*.capacity < self.*.count + 1) and !self.*._static) {
            const oldCap = self.*.capacity;
            self.*.capacity = if (oldCap < 8) 8 else oldCap * 2;
            self.*.values = @ptrCast(@alignCast(reallocate(@ptrCast(self.*.values), @intCast(@sizeOf(Value) *% oldCap), @intCast(@sizeOf(Value) *% self.*.capacity))));
        } else if ((self.*.capacity < self.*.count + 1) and self.*._static) {
            print("Array is full\n", .{});
            return;
        }
        self.*.values[@intCast(self.*.count)] = value;
        self.*.count += 1;
    }
};
