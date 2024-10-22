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
        num_int: i32,
        obj: [*c]Obj,
        complex: Complex,
    },

    const Self = @This();

    pub fn init_int(i: i32) Self {
        return Value{ .type = .VAL_INT, .as = .{ .num_int = i } };
    }

    pub fn init_double(d: f64) Self {
        return Value{ .type = .VAL_DOUBLE, .as = .{ .num_double = d } };
    }

    pub fn init_bool(b: bool) Self {
        return Value{ .type = .VAL_BOOL, .as = .{ .boolean = b } };
    }

    pub fn init_nil() Self {
        return Value.init_int(0);
    }

    pub fn init_obj(obj: [*c]Obj) Self {
        return Value{ .type = .VAL_OBJ, .as = .{ .obj = obj } };
    }

    pub fn init_complex(c: Complex) Self {
        return Value{ .type = .VAL_COMPLEX, .as = .{ .complex = c } };
    }

    fn negate(self: Self) Self {
        switch (self.type) {
            .VAL_INT => return Value.init_int(-self.as.num_int),
            .VAL_DOUBLE => return Value.init_double(-self.as.num_double),
            .VAL_COMPLEX => return Value.init_complex(.{ .r = -self.as.complex.r, .i = -self.as.complex.i }),
            else => @panic("Cannot negate non-numeric value"),
        }
    }

    pub fn add(self: Self, other: Value) Value {
        switch (self.type) {
            .VAL_INT => {
                switch (other.type) {
                    .VAL_INT => return Value.init_int(self.as.num_int + other.as.num_int),
                    .VAL_DOUBLE => return Value.init_int(self.as.num_int + @as(i32, @intFromFloat(other.as.num_double))),
                    .VAL_COMPLEX => return Value.init_complex(.{ .r = @as(f64, @floatFromInt(self.as.num_int)) + other.as.complex.r, .i = other.as.complex.i }),
                    else => @panic("Cannot add non-numeric value"),
                }
            },
            .VAL_DOUBLE => {
                switch (other.type) {
                    .VAL_INT => return Value.init_double(self.as.num_double + @as(f64, @floatFromInt(other.as.num_int))),
                    .VAL_DOUBLE => return Value.init_double(self.as.num_double + other.as.num_double),
                    .VAL_COMPLEX => return Value.init_complex(.{ .r = self.as.num_double + other.as.complex.r, .i = other.as.complex.i }),
                    else => {},
                }
            },
            .VAL_COMPLEX => {
                switch (other.type) {
                    .VAL_INT => return Value.init_complex(.{ .r = self.as.complex.r + @as(f64, @floatFromInt(other.as.num_int)), .i = self.as.complex.i }),
                    .VAL_DOUBLE => return Value.init_complex(.{ .r = self.as.complex.r + other.as.num_double, .i = self.as.complex.i }),
                    .VAL_COMPLEX => return Value.init_complex(.{ .r = self.as.complex.r + other.as.complex.r, .i = self.as.complex.i + other.as.complex.i }),
                    else => {},
                }
            },
            else => {},
        }
        return Value.init_nil();
    }

    pub fn sub(self: Self, other: Value) Value {
        return self.add(other.negate());
    }

    pub fn mul(self: Self, other: Value) Value {
        switch (self.type) {
            .VAL_INT => {
                switch (other.type) {
                    .VAL_INT => return Value.init_int(self.as.num_int * other.as.num_int),
                    .VAL_DOUBLE => return Value.init_double(@as(f64, @floatFromInt(self.as.num_int)) * other.as.num_double),
                    .VAL_COMPLEX => return Value.init_complex(.{ .r = @as(f64, @floatFromInt(self.as.num_int)) * other.as.complex.r, .i = @as(f64, @floatFromInt(self.as.num_int)) * other.as.complex.i }),
                    else => {},
                }
            },
            .VAL_DOUBLE => {
                switch (other.type) {
                    .VAL_INT => return Value.init_double(self.as.num_double * @as(f64, @floatFromInt(other.as.num_int))),
                    .VAL_DOUBLE => return Value.init_double(self.as.num_double * other.as.num_double),
                    .VAL_COMPLEX => return Value.init_complex(.{ .r = self.as.num_double * other.as.complex.r, .i = self.as.num_double * other.as.complex.i }),
                    else => {},
                }
            },
            .VAL_COMPLEX => {
                switch (other.type) {
                    .VAL_INT => return Value.init_complex(.{ .r = self.as.complex.r * @as(f64, @floatFromInt(other.as.num_int)), .i = self.as.complex.i * @as(f64, @floatFromInt(other.as.num_int)) }),
                    .VAL_DOUBLE => return Value.init_complex(.{ .r = self.as.complex.r * other.as.num_double, .i = self.as.complex.i * other.as.num_double }),
                    .VAL_COMPLEX => return Value.init_complex(.{ .r = self.as.complex.r * other.as.complex.r - self.as.complex.i * other.as.complex.i, .i = self.as.complex.r * other.as.complex.i + self.as.complex.i * other.as.complex.r }),
                    else => {},
                }
            },
            else => {},
        }
        return Value.init_nil();
    }

    pub fn div(self: Self, other: Value) Value {
        switch (self.type) {
            .VAL_INT => {
                switch (other.type) {
                    .VAL_INT => return Value.init_double(@as(f64, @floatFromInt(self.as.num_int)) / @as(f64, @floatFromInt(other.as.num_int))),
                    .VAL_DOUBLE => return Value.init_double(@as(f64, @floatFromInt(self.as.num_int)) / other.as.num_double),
                    .VAL_COMPLEX => {
                        const denominator = other.as.complex.r * other.as.complex.r + other.as.complex.i * other.as.complex.i;
                        return Value.init_complex(.{ .r = @as(f64, @floatFromInt(self.as.num_int)) * other.as.complex.r / denominator, .i = -@as(f64, @floatFromInt(self.as.num_int)) * other.as.complex.i / denominator });
                    },
                    else => {},
                }
            },
            .VAL_DOUBLE => {
                switch (other.type) {
                    .VAL_INT => return Value.init_double(self.as.num_double / @as(f64, @floatFromInt(other.as.num_int))),
                    .VAL_DOUBLE => return Value.init_double(self.as.num_double / other.as.num_double),
                    .VAL_COMPLEX => {
                        const denominator = other.as.complex.r * other.as.complex.r + other.as.complex.i * other.as.complex.i;
                        return Value.init_complex(.{ .r = self.as.num_double * other.as.complex.r / denominator, .i = -self.as.num_double * other.as.complex.i / denominator });
                    },
                    else => {},
                }
            },
            .VAL_COMPLEX => {
                switch (other.type) {
                    .VAL_INT => {
                        const denominator = @as(f64, @floatFromInt(other.as.num_int)) * @as(f64, @floatFromInt(other.as.num_int));
                        return Value.init_complex(.{ .r = self.as.complex.r * @as(f64, @floatFromInt(other.as.num_int)) / denominator, .i = self.as.complex.i * @as(f64, @floatFromInt(other.as.num_int)) / denominator });
                    },
                    .VAL_DOUBLE => {
                        const denominator = other.as.num_double * other.as.num_double;
                        return Value.init_complex(.{ .r = self.as.complex.r * other.as.num_double / denominator, .i = self.as.complex.i * other.as.num_double / denominator });
                    },
                    .VAL_COMPLEX => {
                        const denominator = other.as.complex.r * other.as.complex.r + other.as.complex.i * other.as.complex.i;
                        return Value.init_complex(.{ .r = (self.as.complex.r * other.as.complex.r + self.as.complex.i * other.as.complex.i) / denominator, .i = (self.as.complex.i * other.as.complex.r - self.as.complex.r * other.as.complex.i) / denominator });
                    },
                    else => {},
                }
            },
            else => {},
        }
        return Value.init_nil();
    }
};

pub const ValueArray = extern struct {
    capacity: c_int,
    count: c_int,
    values: [*c]Value,
};

pub inline fn IS_BOOL(value: anytype) bool {
    return value.type == .VAL_BOOL;
}
pub inline fn IS_NIL(value: anytype) bool {
    return value.type == .VAL_NIL;
}
pub inline fn IS_INT(value: anytype) bool {
    return value.type == .VAL_INT;
}
pub inline fn IS_DOUBLE(value: anytype) bool {
    return value.type == .VAL_DOUBLE;
}
pub inline fn IS_OBJ(value: anytype) bool {
    return value.type == .VAL_OBJ;
}
pub inline fn IS_COMPLEX(value: anytype) bool {
    return value.type == .VAL_COMPLEX;
}
pub inline fn IS_PRIM_NUM(value: anytype) bool {
    return IS_INT(value) or IS_DOUBLE(value);
}
pub inline fn AS_OBJ(value: anytype) @TypeOf(value.as.obj) {
    return value.as.obj;
}
pub inline fn AS_BOOL(value: anytype) @TypeOf(value.as.boolean) {
    return value.as.boolean;
}
pub inline fn AS_INT(value: anytype) @TypeOf(value.as.num_int) {
    return value.as.num_int;
}
pub inline fn AS_DOUBLE(value: anytype) @TypeOf(value.as.num_double) {
    return value.as.num_double;
}
pub inline fn AS_COMPLEX(value: anytype) @TypeOf(value.as.complex) {
    return value.as.complex;
}
pub inline fn AS_NUM_DOUBLE(value: anytype) @TypeOf(if (IS_INT(value)) @import("std").zig.c_translation.cast(f64, AS_INT(value)) else AS_DOUBLE(value)) {
    return if (IS_INT(value)) @import("std").zig.c_translation.cast(f64, AS_INT(value)) else AS_DOUBLE(value);
}
pub inline fn AS_NUM_INT(value: anytype) @TypeOf(if (IS_DOUBLE(value)) @import("std").zig.c_translation.cast(c_int, AS_DOUBLE(value)) else AS_INT(value)) {
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

pub inline fn OBJ_VAL(value: [*c]Obj) Value {
    return .{ .type = .VAL_OBJ, .as = .{ .obj = value } };
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

pub fn valueToString(value: Value) []const u8 {
    switch (value.type) {
        .VAL_BOOL => return if (AS_BOOL(value)) "true" else "false",
        .VAL_NIL => return "nil",
        .VAL_INT => {
            const s = std.fmt.allocPrint(std.heap.c_allocator, "{d}", .{AS_INT(value)}) catch unreachable;
            return s;
        },
        .VAL_DOUBLE => {
            const s = std.fmt.allocPrint(std.heap.c_allocator, "{d}", .{AS_DOUBLE(value)}) catch unreachable;
            return s;
        },
        .VAL_COMPLEX => {
            const c = AS_COMPLEX(value);
            const s = std.fmt.allocPrint(std.heap.c_allocator, "{d} + {d}i", .{ c.r, c.i }) catch unreachable;
            return s;
        },
        .VAL_OBJ => {
            return "object";
        },
    }
    return null;
}
