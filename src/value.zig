const std = @import("std");

pub const Obj = anyopaque;
pub const ObjString = anyopaque;

pub const ValueType = enum(c_int) {
    VAL_BOOL = 0,
    VAL_NIL = 1,
    VAL_INT = 2,
    VAL_DOUBLE = 3,
    VAL_OBJ = 4,
};

pub const ValueArray = extern struct { capacity: i32, count: i32, values: [*c]Value };

pub export fn initValueArray(array: [*c]ValueArray) callconv(.C) void {
    array.*.values = null;
    array.*.count = 0;
    array.*.capacity = 0;
}

inline fn grow_cap(old: i32) i32 {
    return @max(8, old * 2);
}

pub export fn writeValueArray(array: [*c]ValueArray, value: Value) callconv(.C) void {
    _ = value;
    if (array.capacity < array.count + 1) {
        const oldCap = array.capacity;
        _ = oldCap;
    }
}

pub const Value = extern struct { type: ValueType, as: union(enum) { boolean: bool, num_double: f64, num_int: i32, obj: ?*Obj } };

pub export fn IS_BOOL(value: Value) callconv(.C) bool {
    return value.type == .VAL_BOOL;
}

pub export fn IS_NIL(value: Value) callconv(.C) bool {
    return value.type == .VAL_NIL;
}

pub export fn IS_INT(value: Value) callconv(.C) bool {
    return value.type == .VAL_INT;
}

pub export fn IS_DOUBLE(value: Value) callconv(.C) bool {
    return value.type == .VAL_DOUBLE;
}

pub export fn IS_OBJ(value: Value) callconv(.C) bool {
    return value.type == .VAL_OBJ;
}

pub export fn AS_OBJ(value: Value) callconv(.C) ?*Obj {
    return value.as.obj;
}

pub export fn AS_BOOL(value: Value) callconv(.C) bool {
    return value.as.boolean;
}

pub export fn AS_INT(value: Value) callconv(.C) i32 {
    return value.as.num_int;
}

pub export fn AS_DOUBLE(value: Value) callconv(.C) f64 {
    return value.as.num_double;
}

pub export fn BOOL_VAL(value: bool) callconv(.C) Value {
    return .{ .type = .VAL_BOOL, .as = .{ .boolean = value } };
}

pub export fn INT_VAL(value: i32) callconv(.C) Value {
    return .{ .type = .VAL_INT, .as = .{ .num_int = value } };
}

pub export fn NIL_VAL() callconv(.C) Value {
    return INT_VAL(0);
}

pub export fn DOUBLE_VAL(value: f64) callconv(.C) Value {
    return .{ .type = .VAL_DOUBLE, .as = .{ .num_double = value } };
}

pub export fn OBJ_VAL(object: Obj) callconv(.C) Value {
    return .{ .type = .VAL_OBJ, .as = .{ .obj = &object } };
}
