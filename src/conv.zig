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

pub fn what_is(val: Value) []const u8 {
    switch (val.type) {
        VAL_INT => return "Integer",
        VAL_DOUBLE => return "Double",
        VAL_BOOL => return "Boolean",
        VAL_NIL => return "NIL",
        VAL_OBJ => return "Object",
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

pub fn is_bool(val: Value) bool {
    return val.type == VAL_BOOL;
}

pub fn is_nil(val: Value) bool {
    return val.type == VAL_NIL;
}

pub fn is_int(val: Value) bool {
    return val.type == VAL_INT;
}

pub fn is_double(val: Value) bool {
    return val.type == VAL_DOUBLE;
}

pub fn is_obj(val: Value) bool {
    return val.type == VAL_OBJ;
}

pub fn is_complex(val: Value) bool {
    return val.type == VAL_COMPLEX;
}

pub fn as_obj(val: Value) ?*Obj {
    return @ptrCast(@alignCast(val.as.obj));
}

pub fn as_bool(val: Value) bool {
    return val.as.boolean;
}

pub fn as_int(val: Value) i32 {
    return val.as.num_int;
}

pub fn as_double(val: Value) f64 {
    return val.as.num_double;
}

pub fn as_complex(val: Value) Complex {
    return val.as.complex;
}

pub fn bool_val(b: bool) Value {
    return .{ .type = VAL_BOOL, .as = .{ .boolean = b } };
}

pub fn int_val(i: i32) Value {
    return .{ .type = VAL_INT, .as = .{ .num_int = i } };
}

pub fn complex_val(r: f64, i: f64) Value {
    const complex = Complex{ .r = r, .i = i };
    return .{ .type = VAL_COMPLEX, .as = .{ .complex = complex } };
}

pub fn nil_val() Value {
    return int_val(0);
}

pub fn double_val(f: f64) Value {
    return .{ .type = VAL_DOUBLE, .as = .{ .num_double = f } };
}

pub fn obj_val(o: ?*Obj) Value {
    return .{ .type = VAL_OBJ, .as = .{ .obj = @ptrCast(o) } };
}

pub fn is_obj_type(val: Value, ty: ObjType) bool {
    return is_obj(val) and as_obj(val).?.type == ty;
}

pub fn is_string(val: Value) bool {
    return is_obj(val) and is_obj_type(val, OBJ_STRING);
}

pub fn is_class(val: Value) bool {
    return is_obj(val) and is_obj_type(val, OBJ_CLASS);
}

pub fn is_instance(val: Value) bool {
    return is_obj(val) and is_obj_type(val, OBJ_INSTANCE);
}

pub fn as_string(val: Value) ?*ObjString {
    return @ptrCast(@alignCast(val.as.obj));
}

pub fn as_class(val: Value) ?*ObjClass {
    return @ptrCast(@alignCast(val.as.obj));
}

pub fn as_zstring(val: Value) []u8 {
    const objstr = as_string(val);
    const len: usize = @intCast(objstr.?.length);
    return @ptrCast(@alignCast(objstr.?.chars[0..len]));
}

pub fn string_val(s: []u8) Value {
    const chars: [*c]const u8 = @ptrCast(@alignCast(s.ptr));
    const length: c_int = @intCast(s.len);
    const obj_str = core.copyString(chars, length);
    return .{ .type = VAL_OBJ, .as = .{ .obj = @ptrCast(obj_str) } };
}

pub fn as_instance(val: Value) [*c]ObjInstance {
    return @ptrCast(@alignCast(val.as.obj));
}

pub fn json_val(val: Value) JValue {
    switch (val.type) {
        VAL_INT => return JValue{ .integer = @as(i64, @intCast(as_int(val))) },
        VAL_DOUBLE => return JValue{ .float = as_double(val) },
        VAL_BOOL => return JValue{ .bool = as_bool(val) },
        VAL_NIL => return JValue{ .integer = 0 },
        VAL_OBJ => {
            if (is_string(val)) {
                const s = as_zstring(val);
                return JValue{ .string = s };
            } else {
                return JValue{.null};
            }
        },
        else => return JValue{.null},
    }
}
