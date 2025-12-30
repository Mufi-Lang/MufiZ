const std = @import("std");
const JValue = std.json.Value;

const obj_h = @import("object.zig");
const Obj = obj_h.Obj;
const ObjType = obj_h.ObjType;
const ObjString = obj_h.ObjString;
const ObjClass = obj_h.ObjClass;
const ObjInstance = obj_h.ObjInstance;
const value_h = @import("value.zig");
const Value = value_h.Value;
const ValueType = value_h.ValueType;
pub const Complex = value_h.Complex;

/// Returns the type of the given value
pub fn what_is(val: Value) []const u8 {
    switch (val.type) {
        .VAL_INT => return "Integer",
        .VAL_DOUBLE => return "Double",
        .VAL_BOOL => return "Boolean",
        .VAL_NIL => return "NIL",
        .VAL_OBJ => {
            const obj = val.as_obj();
            switch (obj.?.type) {
                .OBJ_CLOSURE => return "Closure",
                .OBJ_FUNCTION => return "Function",
                .OBJ_INSTANCE => return "Instance",
                .OBJ_NATIVE => return "Native",
                .OBJ_STRING => return "String",
                .OBJ_UPVALUE => return "Upvalue",
                .OBJ_BOUND_METHOD => return "Bound Method",
                .OBJ_CLASS => return "Class",
                .OBJ_LINKED_LIST => return "Linked List",
                .OBJ_HASH_TABLE => return "Hash Table",
                .OBJ_FVECTOR => return "Float Vector",
                .OBJ_MATRIX => return "Matrix",
                .OBJ_RANGE => return "Range",
                .OBJ_PAIR => return "Pair",
            }
        },
        .VAL_COMPLEX => return "Complex",
    }
}

/// Checks if the given range has the correct type
pub fn type_check(n: usize, values: [*]Value, val_type: i32) bool {
    const check_fn = switch (val_type) {
        0 => &Value.is_int,
        1 => &Value.is_double,
        2 => &Value.is_bool,
        3 => &Value.is_nil,
        4 => &Value.is_obj,
        5 => &Value.is_complex,
        6 => &Value.is_prim_num,
        else => return false,
    };
    for (0..n) |i| {
        if (check_fn(values[i])) continue else return false;
    }
    return true;
}

// Converts a Zig string to a C Null-Terminated string
pub fn cstr(s: []u8) [*]u8 {
    var ptr: [*]u8 = @ptrCast(s.ptr);
    ptr[s.len] = '\x00';
    return ptr;
}
