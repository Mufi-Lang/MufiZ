const std = @import("std");
const JValue = std.json.Value;
const core = @import("core.zig");
const Value = core.Value;
const Obj = core.Obj;
const ObjType = core.ObjType;
const ObjString = core.ObjString;
const ObjClass = core.ObjClass;
const ObjInstance = core.ObjInstance;
pub const VAL_INT = core.VAL_INT;
pub const VAL_BOOL = core.VAL_BOOL;
pub const VAL_DOUBLE = core.VAL_DOUBLE;
pub const VAL_NIL = core.VAL_NIL;
pub const VAL_OBJ = core.VAL_OBJ;
pub const OBJ_STRING = core.OBJ_STRING;
pub const OBJ_CLASS = core.OBJ_CLASS;
pub const VAL_COMPLEX = core.VAL_COMPLEX;
pub const Complex = core.Complex;
pub const OBJ_INSTANCE = core.OBJ_INSTANCE;

/// Returns the type of the given value
pub fn what_is(val: Value) []const u8 {
    switch (val.type) {
        VAL_INT => return "Integer",
        VAL_DOUBLE => return "Double",
        VAL_BOOL => return "Boolean",
        VAL_NIL => return "NIL",
        VAL_OBJ => {
            const obj = as_obj(val);
            switch (obj.?.type) {
                core.OBJ_CLOSURE => return "Closure",
                core.OBJ_FUNCTION => return "Function",
                core.OBJ_INSTANCE => return "Instance",
                core.OBJ_NATIVE => return "Native",
                core.OBJ_STRING => return "String",
                core.OBJ_UPVALUE => return "Upvalue",
                core.OBJ_BOUND_METHOD => return "Bound Method",
                core.OBJ_CLASS => return "Class",
                core.OBJ_ARRAY => return "Array",
                core.OBJ_LINKED_LIST => return "Linked List",
                core.OBJ_HASH_TABLE => return "Hash Table",
                core.OBJ_MATRIX => return "Matrix",
                core.OBJ_FVECTOR => return "Float Vector",
                else => return "Unknown Object Type",
            }
        },
        VAL_COMPLEX => return "Complex",
        else => return "Unknown",
    }
}

/// Checks if the given range has the correct type
pub fn type_check(n: usize, values: [*c]Value, val_type: i32) bool {
    const check_fn = switch (val_type) {
        VAL_INT => &is_int,
        VAL_DOUBLE => &is_double,
        VAL_BOOL => &is_bool,
        VAL_NIL => &is_nil,
        VAL_OBJ => &is_obj,
        VAL_COMPLEX => &is_complex,
        6 => &is_prim_num,
        else => return false,
    };
    for (0..n) |i| {
        if (check_fn(values[i])) continue else return false;
    }
    return true;
}

/// Converts a Zig string to a C Null-Terminated string
pub fn cstr(s: []u8) [*c]u8 {
    var ptr: [*c]u8 = @ptrCast(s.ptr);
    ptr[s.len] = '\x00';
    return ptr;
}

/// Checks if the given value is a bool
pub fn is_bool(val: Value) bool {
    return val.type == VAL_BOOL;
}

/// Checks if the given value is nil
pub fn is_nil(val: Value) bool {
    return val.type == VAL_NIL;
}

/// Checks if the given value is an integer
pub fn is_int(val: Value) bool {
    return val.type == VAL_INT;
}

/// Checks if the given value is a double
pub fn is_double(val: Value) bool {
    return val.type == VAL_DOUBLE;
}

/// Checks if the given value is an object
pub fn is_obj(val: Value) bool {
    return val.type == VAL_OBJ;
}

/// Checks if the given value is a complex number
pub fn is_complex(val: Value) bool {
    return val.type == VAL_COMPLEX;
}

pub fn is_prim_num(val: Value) bool {
    return is_int(val) or is_double(val);
}

/// Checks if the given object is of the given type
pub fn is_obj_type(val: Value, ty: ObjType) bool {
    return is_obj(val) and as_obj(val).?.type == ty;
}

/// Checks if the given object is a string
pub fn is_string(val: Value) bool {
    return is_obj(val) and is_obj_type(val, OBJ_STRING);
}

/// Checks if the given object is a class
pub fn is_class(val: Value) bool {
    return is_obj(val) and is_obj_type(val, OBJ_CLASS);
}

/// Checks if the given object is an instance
pub fn is_instance(val: Value) bool {
    return is_obj(val) and is_obj_type(val, OBJ_INSTANCE);
}

/// Casts a value to a boolean
pub fn bool_val(b: bool) Value {
    return .{ .type = VAL_BOOL, .as = .{ .boolean = b } };
}

/// Casts a value to an integer
pub fn int_val(i: i32) Value {
    return .{ .type = VAL_INT, .as = .{ .num_int = i } };
}

/// Casts a value to a complex number
pub fn complex_val(r: f64, i: f64) Value {
    const complex = Complex{ .r = r, .i = i };
    return .{ .type = VAL_COMPLEX, .as = .{ .complex = complex } };
}

/// Returns a nil value
pub fn nil_val() Value {
    return int_val(0);
}

/// Returns a double value
pub fn double_val(f: f64) Value {
    return .{ .type = VAL_DOUBLE, .as = .{ .num_double = f } };
}

/// Returns an object value
pub fn obj_val(o: ?*Obj) Value {
    return .{ .type = VAL_OBJ, .as = .{ .obj = @ptrCast(o) } };
}

/// Casts a value to an object
pub fn as_obj(val: Value) ?*Obj {
    return @ptrCast(@alignCast(val.as.obj));
}

/// Casts a value to a boolean
pub fn as_bool(val: Value) bool {
    return val.as.boolean;
}

/// Casts a value to an integer
pub fn as_int(val: Value) i32 {
    return val.as.num_int;
}

/// Casts a value to a double
pub fn as_double(val: Value) f64 {
    return val.as.num_double;
}

/// Casts a value to a complex number
pub fn as_complex(val: Value) Complex {
    return val.as.complex;
}

pub fn as_num_double(val: Value) f64 {
    return switch (val.type) {
        VAL_INT => @floatFromInt(val.as.num_int),
        VAL_DOUBLE => val.as.num_double,
        else => 0.0,
    };
}

pub fn as_num_int(val: Value) i32 {
    return switch (val.type) {
        VAL_INT => val.as.num_int,
        VAL_DOUBLE => @intFromFloat(val.as.num_double),
        else => 0,
    };
}

/// Casts a value to a string
pub fn as_string(val: Value) ?*ObjString {
    return @ptrCast(@alignCast(val.as.obj));
}

/// Casts a value to a class
pub fn as_class(val: Value) ?*ObjClass {
    return @ptrCast(@alignCast(val.as.obj));
}

/// Casts a value to a string (zig string)
pub fn as_zstring(val: Value) []u8 {
    const objstr = as_string(val);
    const len: usize = @intCast(objstr.?.length);
    return @ptrCast(@alignCast(objstr.?.chars[0..len]));
}

/// Returns a string value
pub fn string_val(s: []u8) Value {
    const chars: [*c]const u8 = @ptrCast(@alignCast(s.ptr));
    const length: c_int = @intCast(s.len);
    const obj_str = core.copyString(chars, length);
    return .{ .type = VAL_OBJ, .as = .{ .obj = @ptrCast(obj_str) } };
}

/// Casts a value to an instance
pub fn as_instance(val: Value) [*c]ObjInstance {
    return @ptrCast(@alignCast(val.as.obj));
}
