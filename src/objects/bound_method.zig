const std = @import("std");

const obj_h = @import("obj.zig");
const Obj = obj_h.Obj;
const Value = @import("../value.zig").Value;
const ObjClosure = @import("closure.zig").ObjClosure;

/// Bound method object binding a method to a receiver instance
pub const ObjBoundMethod = struct {
    obj: Obj,
    receiver: Value,
    method: *ObjClosure,
};
