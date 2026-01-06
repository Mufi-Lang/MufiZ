const std = @import("std");

const obj_h = @import("obj.zig");
const Obj = obj_h.Obj;
const Value = @import("../value.zig").Value;

/// Type alias for native function pointers
pub const NativeFn = ?*const fn (i32, [*]Value) Value;

/// Native function object wrapping a Zig function
pub const ObjNative = struct {
    obj: Obj,
    function: NativeFn,
};
