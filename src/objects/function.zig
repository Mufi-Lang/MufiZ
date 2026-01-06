const std = @import("std");

const chunk_h = @import("../chunk.zig");
const Chunk = chunk_h.Chunk;
const obj_h = @import("obj.zig");
const Obj = obj_h.Obj;
const ObjString = @import("string.zig").String;

/// Function object representing a compiled function with bytecode
pub const ObjFunction = struct {
    obj: Obj,
    arity: i32,
    upvalueCount: i32,
    chunk: Chunk,
    name: ?*ObjString,
};
