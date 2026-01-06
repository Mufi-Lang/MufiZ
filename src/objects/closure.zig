const std = @import("std");

const obj_h = @import("obj.zig");
const Obj = obj_h.Obj;
const ObjFunction = @import("function.zig").ObjFunction;
const ObjUpvalue = @import("upvalue.zig").ObjUpvalue;

/// Closure object combining a function with its captured variables
pub const ObjClosure = struct {
    obj: Obj,
    function: *ObjFunction,
    upvalues: ?[*]?*ObjUpvalue,
    upvalueCount: i32,
};
