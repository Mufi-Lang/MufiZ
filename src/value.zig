const std = @import("std");
const obj_h = @import("object.zig");
const scanner_h = @import("scanner.zig");
const Obj = obj_h.Obj;
const ObjString = obj_h.ObjString;
const ObjArray = obj_h.ObjArray;
const ObjFunction = obj_h.ObjFunction;
const ObjLinkedList = obj_h.ObjLinkedList;
const Node = obj_h.Node;
const FloatVector = obj_h.FloatVector;
const reallocate = @import("memory.zig").reallocate;
const print = std.debug.print;

pub const ValueType = enum(c_int) { VAL_BOOL = 0, VAL_NIL = 1, VAL_INT = 2, VAL_DOUBLE = 3, VAL_OBJ = 4, VAL_COMPLEX = 5 };

pub const Complex = extern struct {
    r: f64,
    i: f64,
};

pub const Value = extern struct {
    type: ValueType,
    as: extern union {
        boolean: bool,
        num_double: f64,
        num_int: c_int,
        obj: [*c]Obj,
        complex: Complex,
    },
};

pub const ValueArray = extern struct {
    capacity: c_int,
    count: c_int,
    values: [*c]Value,
};

pub inline fn IS_BOOL(value: anytype) @TypeOf(value.type == .VAL_BOOL) {
    _ = &value;
    return value.type == .VAL_BOOL;
}
pub inline fn IS_NIL(value: anytype) @TypeOf(value.type == .VAL_NIL) {
    _ = &value;
    return value.type == .VAL_NIL;
}
pub inline fn IS_INT(value: anytype) @TypeOf(value.type == .VAL_INT) {
    _ = &value;
    return value.type == .VAL_INT;
}
pub inline fn IS_DOUBLE(value: anytype) @TypeOf(value.type == .VAL_DOUBLE) {
    _ = &value;
    return value.type == .VAL_DOUBLE;
}
pub inline fn IS_OBJ(value: anytype) @TypeOf(value.type == .VAL_OBJ) {
    _ = &value;
    return value.type == .VAL_OBJ;
}
pub inline fn IS_COMPLEX(value: anytype) @TypeOf(value.type == .VAL_COMPLEX) {
    _ = &value;
    return value.type == .VAL_COMPLEX;
}
pub inline fn IS_PRIM_NUM(value: anytype) @TypeOf((IS_INT(value) != 0) or (IS_DOUBLE(value) != 0)) {
    _ = &value;
    return (IS_INT(value) != 0) or (IS_DOUBLE(value) != 0);
}
pub inline fn AS_OBJ(value: anytype) @TypeOf(value.as.obj) {
    _ = &value;
    return value.as.obj;
}
pub inline fn AS_BOOL(value: anytype) @TypeOf(value.as.boolean) {
    _ = &value;
    return value.as.boolean;
}
pub inline fn AS_INT(value: anytype) @TypeOf(value.as.num_int) {
    _ = &value;
    return value.as.num_int;
}
pub inline fn AS_DOUBLE(value: anytype) @TypeOf(value.as.num_double) {
    _ = &value;
    return value.as.num_double;
}
pub inline fn AS_COMPLEX(value: anytype) @TypeOf(value.as.complex) {
    _ = &value;
    return value.as.complex;
}
pub inline fn AS_NUM_DOUBLE(value: anytype) @TypeOf(if (IS_INT(value)) @import("std").zig.c_translation.cast(f64, AS_INT(value)) else AS_DOUBLE(value)) {
    _ = &value;
    return if (IS_INT(value)) @import("std").zig.c_translation.cast(f64, AS_INT(value)) else AS_DOUBLE(value);
}
pub inline fn AS_NUM_INT(value: anytype) @TypeOf(if (IS_DOUBLE(value)) @import("std").zig.c_translation.cast(c_int, AS_DOUBLE(value)) else AS_INT(value)) {
    _ = &value;
    return if (IS_DOUBLE(value)) @import("std").zig.c_translation.cast(c_int, AS_DOUBLE(value)) else AS_INT(value);
}

pub inline fn BOOL_VAL(value: bool) Value {
    return .{ .VAL_BOOL, .{ .boolean = value } };
}

pub inline fn NIL_VAL() Value {
    return .{ .VAL_NIL, .{ .num_int = 0 } };
}

pub inline fn INT_VAL(value: c_int) Value {
    return .{ .VAL_INT, .{ .num_int = value } };
}

pub inline fn DOUBLE_VAL(value: f64) Value {
    return .{ .VAL_DOUBLE, .{ .num_double = value } };
}

pub inline fn OBJ_VAL(value: ?*anyopaque) Value {
    return .{ .VAL_OBJ, .{ .obj = @ptrCast(@alignCast(value)) } };
}

pub inline fn COMPLEX_VAL(value: Complex) Value {
    return .{ .VAL_COMPLEX, .{ .complex = value } };
}

pub fn valuesEqual(a: Value, b: Value) bool {
    if (a.type != b.type) return false;
    switch (a.type) {
        .VAL_BOOL => return AS_BOOL(a) == AS_BOOL(b),
        .VAL_NIL => return true,
        .VAL_INT => return a.as.num_int == b.as.num_int,
        .VAL_DOUBLE => return a.as.num_double == b.as.num_double,
        .VAL_OBJ => {
            {
                const obj_a: [*c]Obj = a.as.obj;
                const obj_b: [*c]Obj = b.as.obj;
                if (obj_a.*.type != obj_b.*.type) return false;
                switch (obj_a.*.type) {
                    .OBJ_STRING => {
                        {
                            const str_a: [*c]ObjString = @as([*c]ObjString, @ptrCast(@alignCast(a.as.obj)));
                            const str_b: [*c]ObjString = @as([*c]ObjString, @ptrCast(@alignCast(b.as.obj)));
                            return (str_a.*.length == str_b.*.length) and (scanner_h.memcmp(@ptrCast(str_a.*.chars), @ptrCast(str_b.*.chars), @intCast(str_a.*.length)) == 0);
                        }
                    },
                    .OBJ_ARRAY => {
                        {
                            const arr_a: [*c]ObjArray = @as([*c]ObjArray, @ptrCast(@alignCast(a.as.obj)));
                            const arr_b: [*c]ObjArray = @as([*c]ObjArray, @ptrCast(@alignCast(b.as.obj)));
                            if (arr_a.*.count != arr_b.*.count) return false;
                            var i: c_int = 0;
                            while (i < arr_a.*.count) : (i += 1) {
                                if (!valuesEqual(arr_a.*.values[@intCast(i)], arr_b.*.values[@intCast(i)])) return false;
                            }
                            return true;
                        }
                    },
                    .OBJ_LINKED_LIST => {
                        {
                            const list_a: [*c]ObjLinkedList = @as([*c]ObjLinkedList, @ptrCast(@alignCast(a.as.obj)));
                            const list_b: [*c]ObjLinkedList = @as([*c]ObjLinkedList, @ptrCast(@alignCast(b.as.obj)));
                            if (list_a.*.count != list_b.*.count) return false;
                            var node_a: [*c]Node = list_a.*.head;
                            var node_b: [*c]Node = list_b.*.head;
                            while (node_a != @as([*c]Node, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) {
                                if (!valuesEqual(node_a.*.data, node_b.*.data)) return false;
                                node_a = node_a.*.next;
                                node_b = node_b.*.next;
                            }
                            return true;
                        }
                    },
                    .OBJ_FVECTOR => {
                        {
                            const vec_a: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(a.as.obj)));
                            const vec_b: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(b.as.obj)));
                            if (vec_a.*.count != vec_b.*.count) return false;

                            var i: c_int = 0;
                            while (i < vec_a.*.count) : (i += 1) {
                                if (vec_a.*.data[@intCast(i)] != vec_b.*.data[@intCast(i)]) return false;
                            }

                            return true;
                        }
                    },
                    else => return false,
                }
            }
        },
        .VAL_COMPLEX => {
            const c_a: Complex = a.as.complex;
            const c_b: Complex = b.as.complex;
            return (c_a.r == c_b.r) and (c_a.i == c_b.i);
        },
    }
}

pub fn valueCompare(a: Value, b: Value) c_int {
    if (a.type != b.type) return -1;

    switch (a.type) {
        .VAL_BOOL => return @intCast(@intFromBool(AS_BOOL(a)) - @intFromBool(AS_BOOL(b))),
        .VAL_NIL => return 0,
        .VAL_INT => {
            const a1: c_int = a.as.num_int;
            const b1: c_int = b.as.num_int;

            if (a1 > b1) return 1;
            if (a1 < b1) return -1;
            if (a1 == b1) return 0;
        },
        .VAL_DOUBLE => {
            const a1: f64 = a.as.num_double;
            const b1: f64 = b.as.num_double;

            if (a1 > b1) return 1;
            if (a1 < b1) return -1;
            if (a1 == b1) return 0;
        },
        else => return -1,
    }
    return -1;
}

pub fn initValueArray(array: [*c]ValueArray) void {
    array.*.values = null;
    array.*.capacity = 0;
    array.*.count = 0;
}

pub fn writeValueArray(array: [*c]ValueArray, value: Value) void {
    if (array.*.capacity < (array.*.count + 1)) {
        const oldCapacity: c_int = array.*.capacity;
        array.*.capacity = if (oldCapacity < 8) 8 else oldCapacity * 2;
        array.*.values = @ptrCast(@alignCast(reallocate(@ptrCast(array.*.values), @intCast(@sizeOf(Value) * oldCapacity), @intCast(@sizeOf(Value) * array.*.capacity))));
    }
    array.*.values[@intCast(array.*.count)] = value;
    array.*.count += 1;
}
pub fn freeValueArray(array: [*c]ValueArray) void {
    _ = reallocate(@ptrCast(array.*.values), @intCast(@sizeOf(Value) * array.*.capacity), 0);
    initValueArray(array);
}
pub fn printValue(value: Value) void {
    switch (value.type) {
        .VAL_BOOL => {
            print("{s}", .{if (AS_BOOL(value)) "true" else "false"});
        },
        .VAL_NIL => {
            print("nil", .{});
        },
        .VAL_DOUBLE => {
            var val: f64 = value.as.num_double;

            if (@abs(val) < 0.0000000001) {
                val = 0.0;
            }
            print("{d}", .{val});
        },
        .VAL_INT => {
            print("{d}", .{value.as.num_int});
        },
        .VAL_COMPLEX => {
            const c: Complex = value.as.complex;
            print("{d} + {d}i", .{ c.r, c.i });
        },
        .VAL_OBJ => {
            obj_h.printObject(value);
        },
    }
}

pub fn valueToString(value: Value) [*c]u8 {
    switch (value.type) {
        .VAL_BOOL => return if (AS_BOOL(value)) @ptrCast(@constCast("true")) else @ptrCast(@constCast("false")),
        .VAL_NIL => return @ptrCast(@constCast("nil")),
        .VAL_INT => {
            const s = std.fmt.allocPrint(std.heap.c_allocator, "{d}", .{AS_INT(value)}) catch return null;
            return @ptrCast(s);
        },
        .VAL_DOUBLE => {
            const s = std.fmt.allocPrint(std.heap.c_allocator, "{d}", .{AS_DOUBLE(value)}) catch return null;
            return @ptrCast(s);
        },
        .VAL_COMPLEX => {
            const c = AS_COMPLEX(value);
            const s = std.fmt.allocPrint(std.heap.c_allocator, "{d} + {d}i", .{ c.r, c.i }) catch return null;
            return @ptrCast(s);
        },
        .VAL_OBJ => {
            return @ptrCast(@constCast("object"));
        },
    }
    return null;
}
