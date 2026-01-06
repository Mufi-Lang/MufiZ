const std = @import("std");

const obj_h = @import("obj.zig");
const Obj = obj_h.Obj;
const Value = @import("../value.zig").Value;

/// Upvalue object for capturing variables in closures
pub const ObjUpvalue = struct {
    obj: Obj,
    location: [*]Value,
    closed: Value,
    next: ?*ObjUpvalue,
};
