const value = @cImport(@cInclude("value.h"));
const object = @cImport(@cInclude("object.h"));
const Value = value.Value;
const Obj = object.Obj;
const ObjType = object.ObjType;
const ObjString = object.ObjString;
pub const VAL_INT = value.VAL_INT;
pub const VAL_BOOL = value.VAL_BOOL;
pub const VAL_DOUBLE = value.VAL_DOUBLE;
pub const VAL_NIL = value.VAL_NIL;
pub const VAL_OBJ = value.VAL_OBJ;
pub const OBJ_STRING = object.OBJ_STRING;

pub fn what_is(val: Value) []const u8 {
    switch (val.type) {
        VAL_INT => return "Integer",
        VAL_DOUBLE => return "Double",
        VAL_BOOL => return "Boolean",
        VAL_NIL => return "NIL",
        VAL_OBJ => return "Object",
        else => return "Unknown",
    }
}

/// Checks if the given range has the correct type
pub fn type_check(n: usize, values: [*c]Value, val_type: i32) bool {
    var check_fn = switch (val_type) {
        VAL_INT => &is_int,
        VAL_DOUBLE => &is_double,
        VAL_BOOL => &is_bool,
        VAL_NIL => &is_nil,
        VAL_OBJ => &is_obj,
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

pub fn bool_val(b: bool) Value {
    return .{ .type = VAL_BOOL, .as = .{ .boolean = b } };
}

pub fn int_val(i: i32) Value {
    return .{ .type = VAL_INT, .as = .{ .num_int = i } };
}

pub fn nil_val() Value {
    return int_val(0);
}

pub fn double_val(f: f64) Value {
    return .{ .type = VAL_DOUBLE, .as = .{ .num_double = f } };
}

pub fn obj_val(o: ?*Obj) Value {
    return .{ .type = VAL_OBJ, .as = .{ .obj = o } };
}

inline fn is_obj_type(val: Value, ty: ObjType) bool {
    return is_obj(val) and as_obj(val).?.type == ty;
}

// TODO: Broken causes segmentation faults
pub fn as_string(val: Value) ?*ObjString {
    return @ptrCast(@alignCast(as_obj(val)));
}

// TODO: Broken causes segmentation faults
pub fn as_cstring(val: Value) [*c]u8 {
    const ptr = as_string(val) orelse return @ptrCast(@constCast(""));
    return ptr.chars;
}
