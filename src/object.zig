const std = @import("std");
const value_h = @import("value.zig");
const table_h = @import("table.zig");
const chunk_h = @import("chunk.zig");
const memory_h = @import("memory.zig");
const vm_h = @import("vm.zig");
const reallocate = memory_h.reallocate;
const Table = table_h.Table;
const Value = value_h.Value;
const Chunk = chunk_h.Chunk;
const AS_OBJ = value_h.AS_OBJ;
const printf = @cImport(@cInclude("stdio.h")).printf;
const push = vm_h.push;
const pop = vm_h.pop;
const scanner_h = @import("scanner.zig");
const memcpy = @cImport(@cInclude("string.h")).memcpy;
const valuesEqual = value_h.valuesEqual;
const qsort = @cImport(@cInclude("stdlib.h")).qsort;

pub const __m256 = @Vector(8, f32);
pub const __m256d = @Vector(4, f64);
pub const __m256i = @Vector(4, c_longlong);
pub const __m256_u = @Vector(8, f32);
pub const __m256d_u = @Vector(4, f64);
pub const __m256i_u = @Vector(4, c_longlong);
pub const __v4df = @Vector(4, f64);

pub inline fn _mm256_setzero_pd() __m256d {
    return blk: {
        const tmp = 0.0;
        const tmp_1 = 0.0;
        const tmp_2 = 0.0;
        const tmp_3 = 0.0;
        break :blk __m256d{
            tmp,
            tmp_1,
            tmp_2,
            tmp_3,
        };
    };
}

pub inline fn _mm256_storeu_pd(p: [*c]f64, a: __m256d) void {
    var __p = p;
    _ = &__p;
    var __a = a;
    _ = &__a;
    const struct___storeu_pd = extern struct {
        __v: __m256d_u align(1) = @import("std").mem.zeroes(__m256d_u),
    };
    _ = &struct___storeu_pd;
    @as([*c]struct___storeu_pd, @ptrCast(@alignCast(__p))).*.__v = __a;
}

pub inline fn _mm256_loadu_pd(p: [*c]const f64) __m256d {
    var __p = p;
    _ = &__p;
    const struct___loadu_pd = extern struct {
        __v: __m256d_u align(1) = @import("std").mem.zeroes(__m256d_u),
    };
    _ = &struct___loadu_pd;
    return @as([*c]const struct___loadu_pd, @ptrCast(@alignCast(__p))).*.__v;
}

pub inline fn _mm256_add_pd(a: __m256d, b: __m256d) __m256d {
    var __a = a;
    _ = &__a;
    var __b = b;
    _ = &__b;
    return @as(__m256d, @bitCast(@as(__v4df, @bitCast(__a)) + @as(__v4df, @bitCast(__b))));
}

pub inline fn _mm256_sub_pd(a: __m256d, b: __m256d) __m256d {
    var __a = a;
    _ = &__a;
    var __b = b;
    _ = &__b;
    return @as(__m256d, @bitCast(@as(__v4df, @bitCast(__a)) - @as(__v4df, @bitCast(__b))));
}

pub inline fn _mm256_mul_pd(a: __m256d, b: __m256d) __m256d {
    var __a = a;
    _ = &__a;
    var __b = b;
    _ = &__b;
    return @as(__m256d, @bitCast(@as(__v4df, @bitCast(__a)) * @as(__v4df, @bitCast(__b))));
}

pub inline fn _mm256_div_pd(a: __m256d, b: __m256d) __m256d {
    var __a = a;
    _ = &__a;
    var __b = b;
    _ = &__b;
    return @as(__m256d, @bitCast(@as(__v4df, @bitCast(__a)) / @as(__v4df, @bitCast(__b))));
}

pub inline fn _mm256_set1_pd(w: f64) __m256d {
    var __w = w;
    _ = &__w;
    return _mm256_set_pd(__w, __w, __w, __w);
}

pub inline fn _mm256_set_pd(a: f64, b: f64, c: f64, d: f64) __m256d {
    var __a = a;
    _ = &__a;
    var __b = b;
    _ = &__b;
    var __c = c;
    _ = &__c;
    var __d = d;
    _ = &__d;
    return blk: {
        const tmp = __d;
        const tmp_1 = __c;
        const tmp_2 = __b;
        const tmp_3 = __a;
        break :blk __m256d{
            tmp,
            tmp_1,
            tmp_2,
            tmp_3,
        };
    };
}

pub const Obj = extern struct {
    type: ObjType,
    isMarked: bool,
    next: [*c]Obj,
};

pub const ObjString = extern struct {
    obj: Obj,
    length: c_int,
    chars: [*c]u8,
    hash: u64,
};

pub const ObjType = enum(c_int) {
    OBJ_CLOSURE = 0,
    OBJ_FUNCTION = 1,
    OBJ_INSTANCE = 2,
    OBJ_NATIVE = 3,
    OBJ_STRING = 4,
    OBJ_UPVALUE = 5,
    OBJ_BOUND_METHOD = 6,
    OBJ_CLASS = 7,
    OBJ_ARRAY = 8,
    OBJ_LINKED_LIST = 9,
    OBJ_HASH_TABLE = 10,
    OBJ_MATRIX = 11,
    OBJ_FVECTOR = 12,
};

pub const Node = extern struct {
    data: Value,
    prev: [*c]Node,
    next: [*c]Node,
};

pub const ObjLinkedList = extern struct {
    obj: Obj,
    head: [*c]Node,
    tail: [*c]Node,
    count: c_int,
};

pub const ObjHashTable = extern struct {
    obj: Obj,
    table: Table,
};

pub const ObjArray = extern struct {
    obj: Obj,
    capacity: c_int,
    count: c_int,
    pos: c_int,
    _static: bool,
    values: [*c]Value,
};

pub const ObjMatrix = extern struct {
    obj: Obj,
    rows: c_int,
    cols: c_int,
    len: c_int,
    data: [*c]ObjArray = @import("std").mem.zeroes([*c]ObjArray),
};

pub const FloatVector = extern struct {
    obj: Obj,
    size: c_int,
    count: c_int,
    pos: c_int,
    data: [*c]f64 = @import("std").mem.zeroes([*c]f64),
    sorted: bool,
};

pub const ObjFunction = extern struct {
    obj: Obj,
    arity: c_int,
    upvalueCount: c_int,
    chunk: Chunk,
    name: [*c]ObjString,
};

pub const NativeFn = ?*const fn (c_int, [*c]Value) callconv(.C) Value;
pub const ObjNative = extern struct {
    obj: Obj,
    function: NativeFn,
};

pub const ObjUpvalue = extern struct {
    obj: Obj,
    location: [*c]Value,
    closed: Value,
    next: [*c]ObjUpvalue,
};

pub const ObjClosure = extern struct {
    obj: Obj,
    function: [*c]ObjFunction,
    upvalues: [*c][*c]ObjUpvalue,
    upvalueCount: c_int,
};
pub const ObjClass = extern struct {
    obj: Obj,
    name: [*c]ObjString,
    methods: Table,
};
pub const ObjInstance = extern struct {
    obj: Obj,
    klass: [*c]ObjClass,
    fields: Table,
};
pub const ObjBoundMethod = extern struct {
    obj: Obj,
    receiver: Value,
    method: [*c]ObjClosure,
};

pub fn allocateObject(arg_size: usize, arg_type: ObjType) callconv(.C) [*c]Obj {
    var size = arg_size;
    _ = &size;
    var @"type" = arg_type;
    _ = &@"type";
    var object: [*c]Obj = @as([*c]Obj, @ptrCast(@alignCast(reallocate(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))), @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))), size))));
    _ = &object;
    object.*.type = @"type";
    object.*.isMarked = @as(c_int, 0) != 0;
    object.*.next = vm_h.vm.objects;
    vm_h.vm.objects = object;
    _ = printf("%p allocate %zu for %d\n", @as([*c]ObjArray, @ptrCast(@alignCast(object))), size);
    return object;
}

pub export fn cityhash64(arg_buf: [*c]const u8, arg_len: usize) u64 {
    var buf = arg_buf;
    _ = &buf;
    var len = arg_len;
    _ = &len;
    var seed: u64 = @as(u64, @bitCast(@as(c_ulong, @truncate(@as(c_ulonglong, 11160318154034397263)))));
    _ = &seed;
    const m: u64 = @as(u64, @bitCast(@as(c_ulong, @truncate(@as(c_ulonglong, 14313749767032793493)))));
    _ = &m;
    const r: c_int = 47;
    _ = &r;
    var h: u64 = seed ^ (len *% m);
    _ = &h;
    var data: [*c]const u64 = @as([*c]const u64, @ptrCast(@alignCast(buf)));
    _ = &data;
    var end: [*c]const u64 = data + (len / @as(usize, @bitCast(@as(c_long, @as(c_int, 8)))));
    _ = &end;
    while (data != end) {
        var k: u64 = (blk: {
            const ref = &data;
            const tmp = ref.*;
            ref.* += 1;
            break :blk tmp;
        }).*;
        _ = &k;
        k *%= m;
        k ^= k >> @intCast(r);
        k *%= m;
        h ^= k;
        h *%= m;
    }
    var data2: [*c]const u8 = @as([*c]const u8, @ptrCast(@alignCast(data)));
    _ = &data2;
    while (true) {
        switch (len & @as(usize, @bitCast(@as(c_long, @as(c_int, 7))))) {
            @as(usize, @bitCast(@as(c_long, @as(c_int, 7)))) => {
                h ^= @as(u64, @bitCast(@as(c_ulong, data2[@as(c_uint, @intCast(@as(c_int, 6)))]))) << @intCast(48);
                h ^= @as(u64, @bitCast(@as(c_ulong, data2[@as(c_uint, @intCast(@as(c_int, 5)))]))) << @intCast(40);
                h ^= @as(u64, @bitCast(@as(c_ulong, data2[@as(c_uint, @intCast(@as(c_int, 4)))]))) << @intCast(32);
                h ^= @as(u64, @bitCast(@as(c_ulong, data2[@as(c_uint, @intCast(@as(c_int, 3)))]))) << @intCast(24);
                h ^= @as(u64, @bitCast(@as(c_ulong, data2[2]))) << @intCast(16);
                h ^= @as(u64, @bitCast(@as(c_ulong, data2[1]))) << @intCast(8);
                h ^= @as(u64, @bitCast(@as(c_ulong, data2[0])));
                h *%= m;
            },
            @as(usize, @bitCast(@as(c_long, @as(c_int, 6)))) => {
                h ^= @as(u64, @bitCast(@as(c_ulong, data2[@as(c_uint, @intCast(@as(c_int, 5)))]))) << @intCast(40);
                h ^= @as(u64, @bitCast(@as(c_ulong, data2[@as(c_uint, @intCast(@as(c_int, 4)))]))) << @intCast(32);
                h ^= @as(u64, @bitCast(@as(c_ulong, data2[@as(c_uint, @intCast(@as(c_int, 3)))]))) << @intCast(24);
                h ^= @as(u64, @bitCast(@as(c_ulong, data2[2]))) << @intCast(16);
                h ^= @as(u64, @bitCast(@as(c_ulong, data2[1]))) << @intCast(8);
                h ^= @as(u64, @bitCast(@as(c_ulong, data2[0])));
                h *%= m;
            },
            @as(usize, @bitCast(@as(c_long, @as(c_int, 5)))) => {
                h ^= @as(u64, @bitCast(@as(c_ulong, data2[@as(c_uint, @intCast(@as(c_int, 4)))]))) << @intCast(32);
                h ^= @as(u64, @bitCast(@as(c_ulong, data2[@as(c_uint, @intCast(@as(c_int, 3)))]))) << @intCast(24);
                h ^= @as(u64, @bitCast(@as(c_ulong, data2[2]))) << @intCast(16);
                h ^= @as(u64, @bitCast(@as(c_ulong, data2[1]))) << @intCast(8);
                h ^= @as(u64, @bitCast(@as(c_ulong, data2[0])));
                h *%= m;
            },
            @as(usize, @bitCast(@as(c_long, @as(c_int, 4)))) => {
                h ^= @as(u64, @bitCast(@as(c_ulong, data2[@as(c_uint, @intCast(@as(c_int, 3)))]))) << @intCast(24);
                h ^= @as(u64, @bitCast(@as(c_ulong, data2[2]))) << @intCast(16);
                h ^= @as(u64, @bitCast(@as(c_ulong, data2[1]))) << @intCast(8);
                h ^= @as(u64, @bitCast(@as(c_ulong, data2[0])));
                h *%= m;
            },
            @as(usize, @bitCast(@as(c_long, @as(c_int, 3)))) => {
                h ^= @as(u64, @bitCast(@as(c_ulong, data2[2]))) << @intCast(16);
                h ^= @as(u64, @bitCast(@as(c_ulong, data2[1]))) << @intCast(8);
                h ^= @as(u64, @bitCast(@as(c_ulong, data2[0])));
                h *%= m;
            },
            @as(usize, @bitCast(@as(c_long, @as(c_int, 2)))) => {
                h ^= @as(u64, @bitCast(@as(c_ulong, data2[1]))) << @intCast(8);
                h ^= @as(u64, @bitCast(@as(c_ulong, data2[0])));
                h *%= m;
            },
            @as(usize, @bitCast(@as(c_long, @as(c_int, 1)))) => {
                h ^= @as(u64, @bitCast(@as(c_ulong, data2[0])));
                h *%= m;
            },
            else => {},
        }
        break;
    }
    h ^= h >> @intCast(r);
    h *%= m;
    h ^= h >> @intCast(r);
    return h;
}

pub fn add_val(arg_a: Value, arg_b: Value) callconv(.C) Value {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    while (true) {
        switch (a.type) {
            .VAL_INT => {
                if (b.type == .VAL_INT) {
                    return Value{
                        .type = .VAL_INT,
                        .as = .{
                            .num_int = a.as.num_int + b.as.num_int,
                        },
                    };
                } else if (b.type == .VAL_DOUBLE) {
                    return Value{
                        .type = .VAL_DOUBLE,
                        .as = .{
                            .num_double = @as(f64, @floatFromInt(a.as.num_int)) + b.as.num_double,
                        },
                    };
                }
                break;
            },
            .VAL_DOUBLE => {
                if (b.type == .VAL_INT) {
                    return Value{
                        .type = .VAL_DOUBLE,
                        .as = .{
                            .num_double = a.as.num_double + @as(f64, @floatFromInt(b.as.num_int)),
                        },
                    };
                } else if (b.type == .VAL_DOUBLE) {
                    return Value{
                        .type = .VAL_DOUBLE,
                        .as = .{
                            .num_double = a.as.num_double + b.as.num_double,
                        },
                    };
                }
                break;
            },
            else => break,
        }
        break;
    }
    return Value{
        .type = .VAL_NIL,
        .as = .{
            .num_int = @as(c_int, 0),
        },
    };
}
pub fn sub_val(arg_a: Value, arg_b: Value) callconv(.C) Value {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    while (true) {
        switch (a.type) {
            .VAL_INT => {
                if (b.type == .VAL_INT) {
                    return Value{
                        .type = .VAL_INT,
                        .as = .{
                            .num_int = a.as.num_int - b.as.num_int,
                        },
                    };
                } else if (b.type == .VAL_DOUBLE) {
                    return Value{
                        .type = .VAL_DOUBLE,
                        .as = .{
                            .num_double = @as(f64, @floatFromInt(a.as.num_int)) - b.as.num_double,
                        },
                    };
                }
                break;
            },
            .VAL_DOUBLE => {
                if (b.type == .VAL_INT) {
                    return Value{
                        .type = .VAL_DOUBLE,
                        .as = .{
                            .num_double = a.as.num_double - @as(f64, @floatFromInt(b.as.num_int)),
                        },
                    };
                } else if (b.type == .VAL_DOUBLE) {
                    return Value{
                        .type = .VAL_DOUBLE,
                        .as = .{
                            .num_double = a.as.num_double - b.as.num_double,
                        },
                    };
                }
                break;
            },
            else => break,
        }
        break;
    }
    return Value{
        .type = .VAL_NIL,
        .as = .{
            .num_int = @as(c_int, 0),
        },
    };
}
pub fn mul_val(arg_a: Value, arg_b: Value) callconv(.C) Value {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    while (true) {
        switch (a.type) {
            .VAL_INT => {
                if (b.type == .VAL_INT) {
                    return Value{
                        .type = .VAL_INT,
                        .as = .{
                            .num_int = a.as.num_int * b.as.num_int,
                        },
                    };
                } else if (b.type == .VAL_DOUBLE) {
                    return Value{
                        .type = .VAL_DOUBLE,
                        .as = .{
                            .num_double = @as(f64, @floatFromInt(a.as.num_int)) * b.as.num_double,
                        },
                    };
                }
                break;
            },
            .VAL_DOUBLE => {
                if (b.type == .VAL_INT) {
                    return Value{
                        .type = .VAL_DOUBLE,
                        .as = .{
                            .num_double = a.as.num_double * @as(f64, @floatFromInt(b.as.num_int)),
                        },
                    };
                } else if (b.type == .VAL_DOUBLE) {
                    return Value{
                        .type = .VAL_DOUBLE,
                        .as = .{
                            .num_double = a.as.num_double * b.as.num_double,
                        },
                    };
                }
                break;
            },
            else => break,
        }
        break;
    }
    return Value{
        .type = .VAL_NIL,
        .as = .{
            .num_int = @as(c_int, 0),
        },
    };
}
pub fn div_val(arg_a: Value, arg_b: Value) callconv(.C) Value {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    while (true) {
        switch (a.type) {
            .VAL_INT => {
                if (b.type == .VAL_INT) {
                    return Value{
                        .type = .VAL_INT,
                        .as = .{
                            .num_int = @divTrunc(a.as.num_int, b.as.num_int),
                        },
                    };
                } else if (b.type == .VAL_DOUBLE) {
                    return Value{
                        .type = .VAL_DOUBLE,
                        .as = .{
                            .num_double = @as(f64, @floatFromInt(a.as.num_int)) / b.as.num_double,
                        },
                    };
                }
                break;
            },
            .VAL_DOUBLE => {
                if (b.type == .VAL_INT) {
                    return Value{
                        .type = .VAL_DOUBLE,
                        .as = .{
                            .num_double = a.as.num_double / @as(f64, @floatFromInt(b.as.num_int)),
                        },
                    };
                } else if (b.type == .VAL_DOUBLE) {
                    return Value{
                        .type = .VAL_DOUBLE,
                        .as = .{
                            .num_double = a.as.num_double / b.as.num_double,
                        },
                    };
                }
                break;
            },
            else => break,
        }
        break;
    }
    return Value{
        .type = .VAL_NIL,
        .as = .{
            .num_int = @as(c_int, 0),
        },
    };
}

pub inline fn OBJ_TYPE(value: anytype) @TypeOf(AS_OBJ(value).*.type) {
    _ = &value;
    return AS_OBJ(value).*.type;
}
pub inline fn IS_BOUND_METHOD(value: anytype) @TypeOf(isObjType(value, .OBJ_BOUND_METHOD)) {
    _ = &value;
    return isObjType(value, .OBJ_BOUND_METHOD);
}
pub inline fn IS_CLASS(value: anytype) @TypeOf(isObjType(value, .OBJ_CLASS)) {
    _ = &value;
    return isObjType(value, .OBJ_CLASS);
}
pub inline fn IS_CLOSURE(value: anytype) @TypeOf(isObjType(value, .OBJ_CLOSURE)) {
    _ = &value;
    return isObjType(value, .OBJ_CLOSURE);
}
pub inline fn IS_FUNCTION(value: anytype) @TypeOf(isObjType(value, .OBJ_FUNCTION)) {
    _ = &value;
    return isObjType(value, .OBJ_FUNCTION);
}
pub inline fn IS_INSTANCE(value: anytype) @TypeOf(isObjType(value, .OBJ_INSTANCE)) {
    _ = &value;
    return isObjType(value, .OBJ_INSTANCE);
}
pub inline fn IS_NATIVE(value: anytype) @TypeOf(isObjType(value, .OBJ_NATIVE)) {
    _ = &value;
    return isObjType(value, .OBJ_NATIVE);
}
pub inline fn IS_STRING(value: anytype) @TypeOf(isObjType(value, .OBJ_STRING)) {
    _ = &value;
    return isObjType(value, .OBJ_STRING);
}
pub inline fn IS_ARRAY(value: anytype) @TypeOf(isObjType(value, .OBJ_ARRAY)) {
    _ = &value;
    return isObjType(value, .OBJ_ARRAY);
}
pub inline fn IS_LINKED_LIST(value: anytype) @TypeOf(isObjType(value, .OBJ_LINKED_LIST)) {
    _ = &value;
    return isObjType(value, .OBJ_LINKED_LIST);
}
pub inline fn IS_HASH_TABLE(value: anytype) @TypeOf(isObjType(value, .OBJ_HASH_TABLE)) {
    _ = &value;
    return isObjType(value, .OBJ_HASH_TABLE);
}
pub inline fn IS_MATRIX(value: anytype) @TypeOf(isObjType(value, .OBJ_MATRIX)) {
    _ = &value;
    return isObjType(value, .OBJ_MATRIX);
}
pub inline fn IS_FVECTOR(value: anytype) @TypeOf(isObjType(value, .OBJ_FVECTOR)) {
    _ = &value;
    return isObjType(value, .OBJ_FVECTOR);
}
pub inline fn NOT_ARRAY_TYPES(values: anytype, n: anytype) @TypeOf((notObjTypes(@import("std").mem.zeroInit(ObjTypeCheckParams, .{ values, .OBJ_ARRAY, n })) != 0) and (notObjTypes(@import("std").mem.zeroInit(ObjTypeCheckParams, .{ values, .OBJ_FVECTOR, n })) != 0)) {
    _ = &values;
    _ = &n;
    return (notObjTypes(@import("std").mem.zeroInit(ObjTypeCheckParams, .{ values, .OBJ_ARRAY, n })) != 0) and (notObjTypes(@import("std").mem.zeroInit(ObjTypeCheckParams, .{ values, .OBJ_FVECTOR, n })) != 0);
}
pub inline fn NOT_LIST_TYPES(values: anytype, n: anytype) @TypeOf((notObjTypes(@import("std").mem.zeroInit(ObjTypeCheckParams, .{ values, .OBJ_LINKED_LIST, n })) != 0) and (NOT_ARRAY_TYPES(values, n) != 0)) {
    _ = &values;
    _ = &n;
    return (notObjTypes(@import("std").mem.zeroInit(ObjTypeCheckParams, .{ values, .OBJ_LINKED_LIST, n })) != 0) and (NOT_ARRAY_TYPES(values, n) != 0);
}
pub inline fn NOT_COLLECTION_TYPES(values: anytype, n: anytype) @TypeOf(((notObjTypes(@import("std").mem.zeroInit(ObjTypeCheckParams, .{ values, .OBJ_HASH_TABLE, n })) != 0) and (notObjTypes(@import("std").mem.zeroInit(ObjTypeCheckParams, .{ values, .OBJ_MATRIX, n })) != 0)) and (NOT_LIST_TYPES(values, n) != 0)) {
    _ = &values;
    _ = &n;
    return ((notObjTypes(@import("std").mem.zeroInit(ObjTypeCheckParams, .{ values, .OBJ_HASH_TABLE, n })) != 0) and (notObjTypes(@import("std").mem.zeroInit(ObjTypeCheckParams, .{ values, .OBJ_MATRIX, n })) != 0)) and (NOT_LIST_TYPES(values, n) != 0);
}
pub inline fn AS_BOUND_METHOD(value: anytype) [*c]ObjBoundMethod {
    _ = &value;
    return @import("std").zig.c_translation.cast([*c]ObjBoundMethod, AS_OBJ(value));
}
pub inline fn AS_CLASS(value: anytype) [*c]ObjClass {
    _ = &value;
    return @import("std").zig.c_translation.cast([*c]ObjClass, AS_OBJ(value));
}
pub inline fn AS_CLOSURE(value: anytype) [*c]ObjClosure {
    _ = &value;
    return @import("std").zig.c_translation.cast([*c]ObjClosure, AS_OBJ(value));
}
pub inline fn AS_FUNCTION(value: anytype) [*c]ObjFunction {
    _ = &value;
    return @import("std").zig.c_translation.cast([*c]ObjFunction, AS_OBJ(value));
}
pub inline fn AS_INSTANCE(value: anytype) [*c]ObjInstance {
    _ = &value;
    return @import("std").zig.c_translation.cast([*c]ObjInstance, AS_OBJ(value));
}
pub inline fn AS_NATIVE(value: anytype) @TypeOf(@import("std").zig.c_translation.cast([*c]ObjNative, AS_OBJ(value)).*.function) {
    _ = &value;
    return @import("std").zig.c_translation.cast([*c]ObjNative, AS_OBJ(value)).*.function;
}
pub inline fn AS_STRING(value: anytype) [*c]ObjString {
    _ = &value;
    return @import("std").zig.c_translation.cast([*c]ObjString, AS_OBJ(value));
}
pub inline fn AS_CSTRING(value: anytype) @TypeOf(@import("std").zig.c_translation.cast([*c]ObjString, AS_OBJ(value)).*.chars) {
    _ = &value;
    return @import("std").zig.c_translation.cast([*c]ObjString, AS_OBJ(value)).*.chars;
}
pub inline fn AS_ARRAY(value: anytype) [*c]ObjArray {
    _ = &value;
    return @import("std").zig.c_translation.cast([*c]ObjArray, AS_OBJ(value));
}
pub inline fn AS_LINKED_LIST(value: anytype) [*c]ObjLinkedList {
    _ = &value;
    return @import("std").zig.c_translation.cast([*c]ObjLinkedList, AS_OBJ(value));
}
pub inline fn AS_HASH_TABLE(value: anytype) [*c]ObjHashTable {
    _ = &value;
    return @import("std").zig.c_translation.cast([*c]ObjHashTable, AS_OBJ(value));
}
pub inline fn AS_MATRIX(value: anytype) [*c]ObjMatrix {
    _ = &value;
    return @import("std").zig.c_translation.cast([*c]ObjMatrix, AS_OBJ(value));
}
pub inline fn AS_FVECTOR(value: anytype) [*c]FloatVector {
    _ = &value;
    return @import("std").zig.c_translation.cast([*c]FloatVector, AS_OBJ(value));
}

pub export fn newBoundMethod(arg_receiver: Value, arg_method: [*c]ObjClosure) [*c]ObjBoundMethod {
    var receiver = arg_receiver;
    _ = &receiver;
    var method = arg_method;
    _ = &method;
    var bound: [*c]ObjBoundMethod = @as([*c]ObjBoundMethod, @ptrCast(@alignCast(allocateObject(@sizeOf(ObjBoundMethod), .OBJ_BOUND_METHOD))));
    _ = &bound;
    bound.*.receiver = receiver;
    bound.*.method = method;
    return bound;
}
pub export fn newClass(arg_name: [*c]ObjString) [*c]ObjClass {
    var name = arg_name;
    _ = &name;
    var klass: [*c]ObjClass = @as([*c]ObjClass, @ptrCast(@alignCast(allocateObject(@sizeOf(ObjClass), .OBJ_CLASS))));
    _ = &klass;
    klass.*.name = name;
    table_h.initTable(&klass.*.methods);
    return klass;
}
pub export fn newClosure(arg_function: [*c]ObjFunction) [*c]ObjClosure {
    var function = arg_function;
    _ = &function;
    var upvalues: [*c][*c]ObjUpvalue = @as([*c][*c]ObjUpvalue, @ptrCast(@alignCast(reallocate(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))), @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))), @sizeOf([*c]ObjUpvalue) *% @as(c_ulong, @bitCast(@as(c_long, function.*.upvalueCount)))))));
    _ = &upvalues;
    {
        var i: c_int = 0;
        _ = &i;
        while (i < function.*.upvalueCount) : (i += 1) {
            (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk upvalues + @as(usize, @intCast(tmp)) else break :blk upvalues - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).* = null;
        }
    }
    var closure: [*c]ObjClosure = @as([*c]ObjClosure, @ptrCast(@alignCast(allocateObject(@sizeOf(ObjClosure), .OBJ_CLOSURE))));
    _ = &closure;
    closure.*.function = function;
    closure.*.upvalues = upvalues;
    closure.*.upvalueCount = function.*.upvalueCount;
    return closure;
}

pub export fn newFunction() [*c]ObjFunction {
    var function: [*c]ObjFunction = @as([*c]ObjFunction, @ptrCast(@alignCast(allocateObject(@sizeOf(ObjFunction), .OBJ_FUNCTION))));
    _ = &function;
    function.*.arity = 0;
    function.*.upvalueCount = 0;
    function.*.name = null;
    chunk_h.initChunk(&function.*.chunk);
    return function;
}

pub export fn newInstance(arg_klass: [*c]ObjClass) [*c]ObjInstance {
    var klass = arg_klass;
    _ = &klass;
    var instance: [*c]ObjInstance = @as([*c]ObjInstance, @ptrCast(@alignCast(allocateObject(@sizeOf(ObjInstance), .OBJ_INSTANCE))));
    _ = &instance;
    instance.*.klass = klass;
    table_h.initTable(&instance.*.fields);
    return instance;
}

pub export fn newNative(arg_function: NativeFn) [*c]ObjNative {
    var function = arg_function;
    _ = &function;
    var native: [*c]ObjNative = @as([*c]ObjNative, @ptrCast(@alignCast(allocateObject(@sizeOf(ObjNative), .OBJ_NATIVE))));
    _ = &native;
    native.*.function = function;
    return native;
}

pub const AllocStringParams = extern struct {
    chars: [*c]u8 = @import("std").mem.zeroes([*c]u8),
    length: c_int,
    hash: u64 = @import("std").mem.zeroes(u64),
};

pub export fn allocateString(arg_params: AllocStringParams) [*c]ObjString {
    var params = arg_params;
    _ = &params;
    var string: [*c]ObjString = @as([*c]ObjString, @ptrCast(@alignCast(allocateObject(@sizeOf(ObjString), .OBJ_STRING))));
    _ = &string;
    string.*.length = params.length;
    string.*.chars = params.chars;
    string.*.hash = params.hash;
    push(Value{
        .type = .VAL_OBJ,
        .as = .{
            .obj = @as([*c]Obj, @ptrCast(@alignCast(string))),
        },
    });
    _ = table_h.tableSet(&vm_h.vm.strings, string, Value{
        .type = .VAL_NIL,
        .as = .{
            .num_int = @as(c_int, 0),
        },
    });
    _ = pop();
    return string;
}

pub export fn hashString(key: [*c]const u8, length: c_int) u64 {
    const FNV_OFFSET_BASIS: u64 = 0xcbf29ce484222325;
    const FNV_PRIME: u64 = 0x100000001b3;

    var hash = FNV_OFFSET_BASIS;
    for (0..@intCast(length)) |i| {
        hash ^= @intCast(key[i]);
        hash = hash *% FNV_PRIME;
    }
    return hash;
}

pub export fn takeString(arg_chars: [*c]u8, arg_length: c_int) [*c]ObjString {
    var chars = arg_chars;
    _ = &chars;
    var length = arg_length;
    _ = &length;
    var hash: u64 = hashString(chars, length);
    _ = &hash;
    var interned: [*c]ObjString = table_h.tableFindString(&vm_h.vm.strings, chars, length, hash);
    _ = &interned;
    if (interned != @as([*c]ObjString, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) {
        _ = reallocate(@as(?*anyopaque, @ptrCast(chars)), @sizeOf(u8) *% @as(c_ulong, @bitCast(@as(c_long, length + @as(c_int, 1)))), @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))));
        return interned;
    }
    return allocateString(AllocStringParams{
        .chars = chars,
        .length = length,
        .hash = hash,
    });
}

pub export fn copyString(arg_chars: [*c]const u8, arg_length: c_int) [*c]ObjString {
    var chars = arg_chars;
    _ = &chars;
    var length = arg_length;
    _ = &length;
    var hash: u64 = hashString(chars, length);
    _ = &hash;
    var interned: [*c]ObjString = table_h.tableFindString(&vm_h.vm.strings, chars, length, hash);
    _ = &interned;
    if (interned != @as([*c]ObjString, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) return interned;
    var heapChars: [*c]u8 = @as([*c]u8, @ptrCast(@alignCast(reallocate(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))), @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))), @sizeOf(u8) *% @as(c_ulong, @bitCast(@as(c_long, length + @as(c_int, 1))))))));
    _ = &heapChars;
    _ = memcpy(@as(?*anyopaque, @ptrCast(heapChars)), @as(?*const anyopaque, @ptrCast(chars)), @as(c_ulong, @bitCast(@as(c_long, length))));
    (blk: {
        const tmp = length;
        if (tmp >= 0) break :blk heapChars + @as(usize, @intCast(tmp)) else break :blk heapChars - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).* = '\x00';
    return allocateString(AllocStringParams{
        .chars = heapChars,
        .length = length,
        .hash = hash,
    });
}

pub export fn newUpvalue(arg_slot: [*c]Value) [*c]ObjUpvalue {
    var slot = arg_slot;
    _ = &slot;
    var upvalue: [*c]ObjUpvalue = @as([*c]ObjUpvalue, @ptrCast(@alignCast(allocateObject(@sizeOf(ObjUpvalue), .OBJ_UPVALUE))));
    _ = &upvalue;
    upvalue.*.location = slot;
    upvalue.*.closed = Value{
        .type = .VAL_NIL,
        .as = .{
            .num_int = @as(c_int, 0),
        },
    };
    upvalue.*.next = null;
    return upvalue;
}

pub export fn mergeArrays(arg_a: [*c]ObjArray, arg_b: [*c]ObjArray) [*c]ObjArray {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    var result: [*c]ObjArray = newArrayWithCap(a.*.count + b.*.count, @as(c_int, 0) != 0);
    _ = &result;
    {
        var i: c_int = 0;
        _ = &i;
        while (i < a.*.count) : (i += 1) {
            pushArray(result, (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk a.*.values + @as(usize, @intCast(tmp)) else break :blk a.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*);
        }
    }
    {
        var i: c_int = 0;
        _ = &i;
        while (i < b.*.count) : (i += 1) {
            pushArray(result, (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk b.*.values + @as(usize, @intCast(tmp)) else break :blk b.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*);
        }
    }
    return result;
}
pub export fn cloneArray(arg_arr: [*c]ObjArray) [*c]ObjArray {
    var arr = arg_arr;
    _ = &arr;
    var _static: bool = arr.*._static;
    _ = &_static;
    var newArray_1: [*c]ObjArray = newArrayWithCap(arr.*.count, _static);
    _ = &newArray_1;
    {
        var i: c_int = 0;
        _ = &i;
        while (i < arr.*.count) : (i += 1) {
            pushArray(newArray_1, (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk arr.*.values + @as(usize, @intCast(tmp)) else break :blk arr.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*);
        }
    }
    return newArray_1;
}
pub export fn clearArray(arg_arr: [*c]ObjArray) void {
    var arr = arg_arr;
    _ = &arr;
    arr.*.count = 0;
}
pub export fn pushArray(arg_array: [*c]ObjArray, arg_val: Value) void {
    var array = arg_array;
    _ = &array;
    var val = arg_val;
    _ = &val;
    if ((array.*.capacity < (array.*.count + @as(c_int, 1))) and !array.*._static) {
        var oldCapacity: c_int = array.*.capacity;
        _ = &oldCapacity;
        array.*.capacity = if (oldCapacity < @as(c_int, 8)) @as(c_int, 8) else oldCapacity * @as(c_int, 2);
        array.*.values = @as([*c]Value, @ptrCast(@alignCast(reallocate(@as(?*anyopaque, @ptrCast(array.*.values)), @sizeOf(Value) *% @as(c_ulong, @bitCast(@as(c_long, oldCapacity))), @sizeOf(Value) *% @as(c_ulong, @bitCast(@as(c_long, array.*.capacity)))))));
    } else if ((array.*.capacity < (array.*.count + @as(c_int, 1))) and (@as(c_int, @intFromBool(array.*._static)) != 0)) {
        _ = printf("Array is full");
        return;
    }
    (blk: {
        const tmp = blk_1: {
            const ref = &array.*.count;
            const tmp_2 = ref.*;
            ref.* += 1;
            break :blk_1 tmp_2;
        };
        if (tmp >= 0) break :blk array.*.values + @as(usize, @intCast(tmp)) else break :blk array.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).* = val;
}
pub export fn insertArray(arg_arr: [*c]ObjArray, arg_index_1: c_int, arg_value: Value) void {
    var arr = arg_arr;
    _ = &arr;
    var index_1 = arg_index_1;
    _ = &index_1;
    var value = arg_value;
    _ = &value;
    if ((index_1 < @as(c_int, 0)) or (index_1 > arr.*.count)) {
        _ = printf("Index out of bounds");
        return;
    }
    if ((arr.*.capacity < (arr.*.count + @as(c_int, 1))) and !arr.*._static) {
        var oldCapacity: c_int = arr.*.capacity;
        _ = &oldCapacity;
        arr.*.capacity = if (oldCapacity < @as(c_int, 8)) @as(c_int, 8) else oldCapacity * @as(c_int, 2);
        arr.*.values = @as([*c]Value, @ptrCast(@alignCast(reallocate(@as(?*anyopaque, @ptrCast(arr.*.values)), @sizeOf(Value) *% @as(c_ulong, @bitCast(@as(c_long, oldCapacity))), @sizeOf(Value) *% @as(c_ulong, @bitCast(@as(c_long, arr.*.capacity)))))));
    } else if ((arr.*.capacity < (arr.*.count + @as(c_int, 1))) and (@as(c_int, @intFromBool(arr.*._static)) != 0)) {
        _ = printf("Array is full");
        return;
    }
    {
        var i: c_int = arr.*.count;
        _ = &i;
        while (i > index_1) : (i -= 1) {
            (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk arr.*.values + @as(usize, @intCast(tmp)) else break :blk arr.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).* = (blk: {
                const tmp = i - @as(c_int, 1);
                if (tmp >= 0) break :blk arr.*.values + @as(usize, @intCast(tmp)) else break :blk arr.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*;
        }
    }
    (blk: {
        const tmp = index_1;
        if (tmp >= 0) break :blk arr.*.values + @as(usize, @intCast(tmp)) else break :blk arr.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).* = value;
    arr.*.count += 1;
}
pub export fn removeArray(arg_arr: [*c]ObjArray, arg_index_1: c_int) Value {
    var arr = arg_arr;
    _ = &arr;
    var index_1 = arg_index_1;
    _ = &index_1;
    if ((index_1 < @as(c_int, 0)) or (index_1 >= arr.*.count)) {
        _ = printf("Index out of bounds");
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    var v: Value = (blk: {
        const tmp = index_1;
        if (tmp >= 0) break :blk arr.*.values + @as(usize, @intCast(tmp)) else break :blk arr.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).*;
    _ = &v;
    {
        var i: c_int = index_1;
        _ = &i;
        while (i < (arr.*.count - @as(c_int, 1))) : (i += 1) {
            (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk arr.*.values + @as(usize, @intCast(tmp)) else break :blk arr.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).* = (blk: {
                const tmp = i + @as(c_int, 1);
                if (tmp >= 0) break :blk arr.*.values + @as(usize, @intCast(tmp)) else break :blk arr.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*;
        }
    }
    arr.*.count -= 1;
    return v;
}
pub export fn getArray(arg_arr: [*c]ObjArray, arg_index_1: c_int) Value {
    var arr = arg_arr;
    _ = &arr;
    var index_1 = arg_index_1;
    _ = &index_1;
    if ((index_1 < @as(c_int, 0)) or (index_1 >= arr.*.count)) {
        _ = printf("Index out of bounds");
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    return (blk: {
        const tmp = index_1;
        if (tmp >= 0) break :blk arr.*.values + @as(usize, @intCast(tmp)) else break :blk arr.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).*;
}
pub export fn popArray(arg_array: [*c]ObjArray) Value {
    var array = arg_array;
    _ = &array;
    if (array.*.count == @as(c_int, 0)) {
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    return (blk: {
        const tmp = blk_1: {
            const ref = &array.*.count;
            ref.* -= 1;
            break :blk_1 ref.*;
        };
        if (tmp >= 0) break :blk array.*.values + @as(usize, @intCast(tmp)) else break :blk array.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).*;
}
pub export fn sortArray(arg_array: [*c]ObjArray) void {
    var array = arg_array;
    _ = &array;
    // @cImport(@cInclude("stdlib.h")).qsort(@ptrCast(array.*.values), @as(usize, @bitCast(@as(c_long, array.*.count))), @sizeOf(Value), &value_h.compareValues);
}
pub fn valuesLess(arg_a: Value, arg_b: Value) callconv(.C) bool {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    if ((a.type == .VAL_INT) and (b.type == .VAL_INT)) {
        return a.as.num_int < b.as.num_int;
    } else if ((a.type == .VAL_DOUBLE) and (b.type == .VAL_DOUBLE)) {
        return a.as.num_double < b.as.num_double;
    }
    return @as(c_int, 0) != 0;
}
pub export fn searchArray(arg_array: [*c]ObjArray, arg_value: Value) c_int {
    var array = arg_array;
    _ = &array;
    var value = arg_value;
    _ = &value;
    var low: c_int = 0;
    _ = &low;
    var high: c_int = array.*.count - @as(c_int, 1);
    _ = &high;
    while (low <= high) {
        var mid: c_int = @divTrunc(low + high, @as(c_int, 2));
        _ = &mid;
        var midValue: Value = (blk: {
            const tmp = mid;
            if (tmp >= 0) break :blk array.*.values + @as(usize, @intCast(tmp)) else break :blk array.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
        }).*;
        _ = &midValue;
        if (valuesEqual(midValue, value)) {
            return mid;
        } else if (valuesLess(midValue, value)) {
            low = mid + @as(c_int, 1);
        } else {
            high = mid - @as(c_int, 1);
        }
    }
    return -@as(c_int, 1);
}
pub export fn reverseArray(arg_array: [*c]ObjArray) void {
    var array = arg_array;
    _ = &array;
    var i: c_int = 0;
    _ = &i;
    var j: c_int = array.*.count - @as(c_int, 1);
    _ = &j;
    while (i < j) {
        var temp: Value = (blk: {
            const tmp = i;
            if (tmp >= 0) break :blk array.*.values + @as(usize, @intCast(tmp)) else break :blk array.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
        }).*;
        _ = &temp;
        (blk: {
            const tmp = i;
            if (tmp >= 0) break :blk array.*.values + @as(usize, @intCast(tmp)) else break :blk array.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
        }).* = (blk: {
            const tmp = j;
            if (tmp >= 0) break :blk array.*.values + @as(usize, @intCast(tmp)) else break :blk array.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
        }).*;
        (blk: {
            const tmp = j;
            if (tmp >= 0) break :blk array.*.values + @as(usize, @intCast(tmp)) else break :blk array.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
        }).* = temp;
        i += 1;
        j -= 1;
    }
}
pub export fn equalArray(arg_a: [*c]ObjArray, arg_b: [*c]ObjArray) bool {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    if (a.*.count != b.*.count) {
        return @as(c_int, 0) != 0;
    }
    {
        var i: c_int = 0;
        _ = &i;
        while (i < a.*.count) : (i += 1) {
            if (!valuesEqual((blk: {
                const tmp = i;
                if (tmp >= 0) break :blk a.*.values + @as(usize, @intCast(tmp)) else break :blk a.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*, (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk b.*.values + @as(usize, @intCast(tmp)) else break :blk b.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*)) {
                return @as(c_int, 0) != 0;
            }
        }
    }
    return @as(c_int, 1) != 0;
}
pub export fn freeObjectArray(arg_array: [*c]ObjArray) void {
    var array = arg_array;
    _ = &array;
    _ = reallocate(@as(?*anyopaque, @ptrCast(array.*.values)), @sizeOf(Value) *% @as(c_ulong, @bitCast(@as(c_long, array.*.capacity))), @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))));
    _ = reallocate(@as(?*anyopaque, @ptrCast(array)), @sizeOf(ObjArray), @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))));
}
pub export fn sliceArray(arg_array: [*c]ObjArray, arg_start: c_int, arg_end: c_int) [*c]ObjArray {
    var array = arg_array;
    _ = &array;
    var start = arg_start;
    _ = &start;
    var end = arg_end;
    _ = &end;
    var sliced: [*c]ObjArray = newArrayWithCap(end - start, @as(c_int, 1) != 0);
    _ = &sliced;
    {
        var i: c_int = start;
        _ = &i;
        while (i < end) : (i += 1) {
            pushArray(sliced, (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk array.*.values + @as(usize, @intCast(tmp)) else break :blk array.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*);
        }
    }
    return sliced;
}
pub export fn spliceArray(arg_array: [*c]ObjArray, arg_start: c_int, arg_end: c_int) [*c]ObjArray {
    var array = arg_array;
    _ = &array;
    var start = arg_start;
    _ = &start;
    var end = arg_end;
    _ = &end;
    if (((((start < @as(c_int, 0)) or (start >= array.*.count)) or (end < @as(c_int, 0))) or (end > array.*.count)) or (start > end)) {
        _ = printf("Index out of bounds");
        return null;
    }
    var spliced: [*c]ObjArray = newArrayWithCap(end - start, @as(c_int, 0) != 0);
    _ = &spliced;
    {
        var i: c_int = 0;
        _ = &i;
        while (i < start) : (i += 1) {
            pushArray(spliced, (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk array.*.values + @as(usize, @intCast(tmp)) else break :blk array.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*);
        }
    }
    {
        var i: c_int = end + @as(c_int, 1);
        _ = &i;
        while (i < array.*.count) : (i += 1) {
            pushArray(spliced, (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk array.*.values + @as(usize, @intCast(tmp)) else break :blk array.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*);
        }
    }
    return spliced;
}
pub export fn addArray(arg_a: [*c]ObjArray, arg_b: [*c]ObjArray) [*c]ObjArray {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    if (a.*.count != b.*.count) {
        _ = printf("Arrays must have the same length");
        return null;
    }
    var _static: bool = (@as(c_int, @intFromBool(a.*._static)) != 0) and (@as(c_int, @intFromBool(b.*._static)) != 0);
    _ = &_static;
    var result: [*c]ObjArray = newArrayWithCap(a.*.count, _static);
    _ = &result;
    {
        var i: c_int = 0;
        _ = &i;
        while (i < a.*.count) : (i += 1) {
            var res: Value = add_val((blk: {
                const tmp = i;
                if (tmp >= 0) break :blk a.*.values + @as(usize, @intCast(tmp)) else break :blk a.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*, (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk b.*.values + @as(usize, @intCast(tmp)) else break :blk b.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*);
            _ = &res;
            pushArray(result, res);
        }
    }
    return result;
}
pub export fn subArray(arg_a: [*c]ObjArray, arg_b: [*c]ObjArray) [*c]ObjArray {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    if (a.*.count != b.*.count) {
        _ = printf("Arrays must have the same length");
        return null;
    }
    var _static: bool = (@as(c_int, @intFromBool(a.*._static)) != 0) and (@as(c_int, @intFromBool(b.*._static)) != 0);
    _ = &_static;
    var result: [*c]ObjArray = newArrayWithCap(a.*.count, _static);
    _ = &result;
    {
        var i: c_int = 0;
        _ = &i;
        while (i < a.*.count) : (i += 1) {
            var res: Value = sub_val((blk: {
                const tmp = i;
                if (tmp >= 0) break :blk a.*.values + @as(usize, @intCast(tmp)) else break :blk a.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*, (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk b.*.values + @as(usize, @intCast(tmp)) else break :blk b.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*);
            _ = &res;
            pushArray(result, res);
        }
    }
    return result;
}
pub export fn mulArray(arg_a: [*c]ObjArray, arg_b: [*c]ObjArray) [*c]ObjArray {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    if (a.*.count != b.*.count) {
        _ = printf("Arrays must have the same length");
        return null;
    }
    var _static: bool = (@as(c_int, @intFromBool(a.*._static)) != 0) and (@as(c_int, @intFromBool(b.*._static)) != 0);
    _ = &_static;
    var result: [*c]ObjArray = newArrayWithCap(a.*.count, _static);
    _ = &result;
    {
        var i: c_int = 0;
        _ = &i;
        while (i < a.*.count) : (i += 1) {
            var res: Value = mul_val((blk: {
                const tmp = i;
                if (tmp >= 0) break :blk a.*.values + @as(usize, @intCast(tmp)) else break :blk a.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*, (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk b.*.values + @as(usize, @intCast(tmp)) else break :blk b.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*);
            _ = &res;
            pushArray(result, res);
        }
    }
    return result;
}
pub export fn divArray(arg_a: [*c]ObjArray, arg_b: [*c]ObjArray) [*c]ObjArray {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    if (a.*.count != b.*.count) {
        _ = printf("Arrays must have the same length");
        return null;
    }
    var _static: bool = (@as(c_int, @intFromBool(a.*._static)) != 0) and (@as(c_int, @intFromBool(b.*._static)) != 0);
    _ = &_static;
    var result: [*c]ObjArray = newArrayWithCap(a.*.count, _static);
    _ = &result;
    {
        var i: c_int = 0;
        _ = &i;
        while (i < a.*.count) : (i += 1) {
            var res: Value = div_val((blk: {
                const tmp = i;
                if (tmp >= 0) break :blk a.*.values + @as(usize, @intCast(tmp)) else break :blk a.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*, (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk b.*.values + @as(usize, @intCast(tmp)) else break :blk b.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*);
            _ = &res;
            pushArray(result, res);
        }
    }
    return result;
}
pub export fn sumArray(arg_array: [*c]ObjArray) Value {
    var array = arg_array;
    _ = &array;
    var sum: Value = Value{
        .type = .VAL_DOUBLE,
        .as = .{
            .num_double = 0.0,
        },
    };
    _ = &sum;
    {
        var i: c_int = 0;
        _ = &i;
        while (i < array.*.count) : (i += 1) {
            sum = add_val(sum, (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk array.*.values + @as(usize, @intCast(tmp)) else break :blk array.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*);
        }
    }
    return sum;
}
pub export fn minArray(arg_array: [*c]ObjArray) Value {
    var array = arg_array;
    _ = &array;
    if (array.*.count == @as(c_int, 0)) {
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    var _min: Value = array.*.values[0];
    _ = &_min;
    {
        var i: c_int = 1;
        _ = &i;
        while (i < array.*.count) : (i += 1) {
            if (valuesLess((blk: {
                const tmp = i;
                if (tmp >= 0) break :blk array.*.values + @as(usize, @intCast(tmp)) else break :blk array.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*, _min)) {
                _min = (blk: {
                    const tmp = i;
                    if (tmp >= 0) break :blk array.*.values + @as(usize, @intCast(tmp)) else break :blk array.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                }).*;
            }
        }
    }
    return _min;
}
pub export fn maxArray(arg_array: [*c]ObjArray) Value {
    var array = arg_array;
    _ = &array;
    if (array.*.count == @as(c_int, 0)) {
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    var _max: Value = array.*.values[0];
    _ = &_max;
    {
        var i: c_int = 1;
        _ = &i;
        while (i < array.*.count) : (i += 1) {
            if (valuesLess(_max, (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk array.*.values + @as(usize, @intCast(tmp)) else break :blk array.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*)) {
                _max = (blk: {
                    const tmp = i;
                    if (tmp >= 0) break :blk array.*.values + @as(usize, @intCast(tmp)) else break :blk array.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                }).*;
            }
        }
    }
    return _max;
}
pub export fn meanArray(arg_array: [*c]ObjArray) Value {
    var array = arg_array;
    _ = &array;
    if (array.*.count == @as(c_int, 0)) {
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    var sum: Value = array.*.values[0];
    _ = &sum;
    {
        var i: c_int = 1;
        _ = &i;
        while (i < array.*.count) : (i += 1) {
            sum = add_val(sum, (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk array.*.values + @as(usize, @intCast(tmp)) else break :blk array.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*);
        }
    }
    var mean: Value = div_val(sum, Value{
        .type = .VAL_DOUBLE,
        .as = .{
            .num_double = @as(f64, @floatFromInt(array.*.count)),
        },
    });
    _ = &mean;
    return mean;
}
pub export fn varianceArray(arg_array: [*c]ObjArray) Value {
    var array = arg_array;
    _ = &array;
    if (array.*.count == @as(c_int, 0)) {
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    var mean: Value = meanArray(array);
    _ = &mean;
    var sum: Value = Value{
        .type = .VAL_DOUBLE,
        .as = .{
            .num_double = 0.0,
        },
    };
    _ = &sum;
    {
        var i: c_int = 0;
        _ = &i;
        while (i < array.*.count) : (i += 1) {
            var temp: Value = sub_val((blk: {
                const tmp = i;
                if (tmp >= 0) break :blk array.*.values + @as(usize, @intCast(tmp)) else break :blk array.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*, mean);
            _ = &temp;
            sum = add_val(sum, mul_val(temp, temp));
        }
    }
    var variance: Value = if (array.*.count > @as(c_int, 1)) div_val(sum, Value{
        .type = .VAL_DOUBLE,
        .as = .{
            .num_double = @as(f64, @floatFromInt(array.*.count - @as(c_int, 1))),
        },
    }) else Value{
        .type = .VAL_NIL,
        .as = .{
            .num_int = @as(c_int, 0),
        },
    };
    _ = &variance;
    return variance;
}
pub export fn stdDevArray(arg_array: [*c]ObjArray) Value {
    var array = arg_array;
    _ = &array;
    var variance: Value = varianceArray(array);
    _ = &variance;
    return Value{
        .type = .VAL_DOUBLE,
        .as = .{
            .num_double = @sqrt(variance.as.num_double),
        },
    };
}
pub export fn lenArray(arg_array: [*c]ObjArray) c_int {
    var array = arg_array;
    _ = &array;
    return array.*.count;
}
pub export fn printArray(arg_arr: [*c]ObjArray) void {
    var arr = arg_arr;
    _ = &arr;
    _ = printf("[");
    {
        var i: c_int = 0;
        _ = &i;
        while (i < arr.*.count) : (i += 1) {
            value_h.printValue((blk: {
                const tmp = i;
                if (tmp >= 0) break :blk arr.*.values + @as(usize, @intCast(tmp)) else break :blk arr.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*);
            if (i != (arr.*.count - @as(c_int, 1))) {
                _ = printf(", ");
            }
        }
    }
    _ = printf("]");
}
pub fn split(arg_list: [*c]ObjLinkedList, arg_left: [*c]ObjLinkedList, arg_right: [*c]ObjLinkedList) callconv(.C) void {
    var list = arg_list;
    _ = &list;
    var left = arg_left;
    _ = &left;
    var right = arg_right;
    _ = &right;
    var count: c_int = list.*.count;
    _ = &count;
    var middle: c_int = @divTrunc(count, @as(c_int, 2));
    _ = &middle;
    left.*.head = list.*.head;
    left.*.count = middle;
    right.*.count = count - middle;
    var current: [*c]Node = list.*.head;
    _ = &current;
    {
        var i: c_int = 0;
        _ = &i;
        while (i < (middle - @as(c_int, 1))) : (i += 1) {
            current = current.*.next;
        }
    }
    left.*.tail = current;
    right.*.head = current.*.next;
    current.*.next = null;
    right.*.head.*.prev = null;
}
pub fn merge(arg_left: [*c]Node, arg_right: [*c]Node) callconv(.C) [*c]Node {
    var left = arg_left;
    _ = &left;
    var right = arg_right;
    _ = &right;
    if (left == @as([*c]Node, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) return right;
    if (right == @as([*c]Node, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) return left;
    if (value_h.valueCompare(left.*.data, right.*.data) < @as(c_int, 0)) {
        left.*.next = merge(left.*.next, right);
        left.*.next.*.prev = left;
        left.*.prev = null;
        return left;
    } else {
        right.*.next = merge(left, right.*.next);
        right.*.next.*.prev = right;
        right.*.prev = null;
        return right;
    }
    return null;
}
pub fn overWriteArray(arg_array: [*c]ObjArray, arg_index_1: c_int, arg_value: Value) callconv(.C) void {
    var array = arg_array;
    _ = &array;
    var index_1 = arg_index_1;
    _ = &index_1;
    var value = arg_value;
    _ = &value;
    if ((index_1 < @as(c_int, 0)) or (index_1 >= array.*.count)) {
        _ = printf("Index out of bounds");
        return;
    }
    (blk: {
        const tmp = index_1;
        if (tmp >= 0) break :blk array.*.values + @as(usize, @intCast(tmp)) else break :blk array.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).* = value;
}
pub export fn swapRow(arg_matrix: [*c]ObjMatrix, arg_row1: c_int, arg_row2: c_int) void {
    var matrix = arg_matrix;
    _ = &matrix;
    var row1 = arg_row1;
    _ = &row1;
    var row2 = arg_row2;
    _ = &row2;
    if (((((matrix != @as([*c]ObjMatrix, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) and (row1 >= @as(c_int, 0))) and (row1 < matrix.*.rows)) and (row2 >= @as(c_int, 0))) and (row2 < matrix.*.rows)) {
        {
            var col: c_int = 0;
            _ = &col;
            while (col < matrix.*.cols) : (col += 1) {
                var temp: Value = (blk: {
                    const tmp = (row1 * matrix.*.cols) + col;
                    if (tmp >= 0) break :blk matrix.*.data.*.values + @as(usize, @intCast(tmp)) else break :blk matrix.*.data.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                }).*;
                _ = &temp;
                overWriteArray(matrix.*.data, (row1 * matrix.*.cols) + col, (blk: {
                    const tmp = (row2 * matrix.*.cols) + col;
                    if (tmp >= 0) break :blk matrix.*.data.*.values + @as(usize, @intCast(tmp)) else break :blk matrix.*.data.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                }).*);
                overWriteArray(matrix.*.data, (row2 * matrix.*.cols) + col, temp);
            }
        }
    }
}
pub fn copyMatrix(arg_matrix: [*c]ObjMatrix) callconv(.C) [*c]ObjMatrix {
    var matrix = arg_matrix;
    _ = &matrix;
    var copy: [*c]ObjMatrix = newMatrix(matrix.*.rows, matrix.*.cols);
    _ = &copy;
    {
        var i: c_int = 0;
        _ = &i;
        while (i < matrix.*.len) : (i += 1) {
            (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk copy.*.data.*.values + @as(usize, @intCast(tmp)) else break :blk copy.*.data.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).* = (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk matrix.*.data.*.values + @as(usize, @intCast(tmp)) else break :blk matrix.*.data.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*;
        }
    }
    return copy;
}
pub export fn backSubstitution(arg_matrix: [*c]ObjMatrix, arg_vector: [*c]ObjArray) [*c]ObjArray {
    var matrix = arg_matrix;
    _ = &matrix;
    var vector = arg_vector;
    _ = &vector;
    if (matrix.*.rows != matrix.*.cols) {
        _ = printf("Matrix is not square");
        return null;
    }
    if (matrix.*.rows != vector.*.count) {
        _ = printf("Matrix and vector dimensions do not match");
        return null;
    }
    var result: [*c]ObjArray = newArrayWithCap(matrix.*.rows, @as(c_int, 1) != 0);
    _ = &result;
    {
        var i: c_int = matrix.*.rows - @as(c_int, 1);
        _ = &i;
        while (i >= @as(c_int, 0)) : (i -= 1) {
            var sum: f64 = 0;
            _ = &sum;
            {
                var j: c_int = i + @as(c_int, 1);
                _ = &j;
                while (j < matrix.*.cols) : (j += 1) {
                    sum += getMatrix(matrix, i, j).as.num_double * (blk: {
                        const tmp = j;
                        if (tmp >= 0) break :blk result.*.values + @as(usize, @intCast(tmp)) else break :blk result.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                    }).*.as.num_double;
                }
            }
            var value: f64 = ((blk: {
                const tmp = i;
                if (tmp >= 0) break :blk vector.*.values + @as(usize, @intCast(tmp)) else break :blk vector.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*.as.num_double - sum) / getMatrix(matrix, i, i).as.num_double;
            _ = &value;
            pushArray(result, Value{
                .type = .VAL_DOUBLE,
                .as = .{
                    .num_double = value,
                },
            });
        }
    }
    reverseArray(result);
    return result;
}
pub fn compare_double(arg_a: ?*const anyopaque, arg_b: ?*const anyopaque) callconv(.C) c_int {
    const a: *f64 = @ptrCast(@constCast(@alignCast(arg_a)));
    const b: *f64 = @ptrCast(@constCast(@alignCast(arg_b)));

    return @intFromFloat(a.* - b.*);
}
pub fn binarySearchFloatVector(arg_vector: [*c]FloatVector, arg_value: f64) callconv(.C) c_int {
    var vector = arg_vector;
    _ = &vector;
    var value = arg_value;
    _ = &value;
    var left: c_int = 0;
    _ = &left;
    var right: c_int = vector.*.count - @as(c_int, 1);
    _ = &right;
    while (left <= right) {
        var mid: c_int = left + @divTrunc(right - left, @as(c_int, 2));
        _ = &mid;
        if ((blk: {
            const tmp = mid;
            if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
        }).* == value) {
            return mid;
        }
        if ((blk: {
            const tmp = mid;
            if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
        }).* < value) {
            left = mid + @as(c_int, 1);
        } else {
            right = mid - @as(c_int, 1);
        }
    }
    return -@as(c_int, 1);
}
pub fn printFunction(arg_function: [*c]ObjFunction) callconv(.C) void {
    var function = arg_function;
    _ = &function;
    if (function.*.name == @as([*c]ObjString, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) {
        _ = printf("<script>");
        return;
    }
    _ = printf("<fn %s>", function.*.name.*.chars);
}
pub export fn newArray() [*c]ObjArray {
    return newArrayWithCap(@as(c_int, 0), @as(c_int, 0) != 0);
}
pub export fn newArrayWithCap(arg_capacity: c_int, arg__static: bool) [*c]ObjArray {
    var capacity = arg_capacity;
    _ = &capacity;
    var _static = arg__static;
    _ = &_static;
    var array: [*c]ObjArray = @as([*c]ObjArray, @ptrCast(@alignCast(allocateObject(@sizeOf(ObjArray), .OBJ_ARRAY))));
    _ = &array;
    array.*.capacity = capacity;
    array.*.count = 0;
    array.*.values = @as([*c]Value, @ptrCast(@alignCast(reallocate(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))), @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))), @sizeOf(Value) *% @as(c_ulong, @bitCast(@as(c_long, capacity)))))));
    array.*._static = _static;
    return array;
}
pub export fn nextObjectArray(arg_array: [*c]ObjArray) Value {
    var array = arg_array;
    _ = &array;
    if (array.*.pos >= array.*.count) {
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    return (blk: {
        const tmp = blk_1: {
            const ref = &array.*.pos;
            const tmp_2 = ref.*;
            ref.* += 1;
            break :blk_1 tmp_2;
        };
        if (tmp >= 0) break :blk array.*.values + @as(usize, @intCast(tmp)) else break :blk array.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).*;
}
pub export fn hasNextObjectArray(arg_array: [*c]ObjArray) bool {
    var array = arg_array;
    _ = &array;
    return array.*.pos < array.*.count;
}
pub export fn peekObjectArray(arg_array: [*c]ObjArray, arg_pos: c_int) Value {
    var array = arg_array;
    _ = &array;
    var pos = arg_pos;
    _ = &pos;
    if (pos >= array.*.count) {
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    return (blk: {
        const tmp = pos;
        if (tmp >= 0) break :blk array.*.values + @as(usize, @intCast(tmp)) else break :blk array.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).*;
}
pub export fn resetObjectArray(arg_array: [*c]ObjArray) void {
    var array = arg_array;
    _ = &array;
    array.*.pos = 0;
}
pub export fn skipObjectArray(arg_array: [*c]ObjArray, arg_n: c_int) void {
    var array = arg_array;
    _ = &array;
    var n = arg_n;
    _ = &n;
    array.*.pos = if ((array.*.pos + n) < array.*.count) array.*.pos + n else array.*.count;
}
pub export fn newLinkedList() [*c]ObjLinkedList {
    var list: [*c]ObjLinkedList = @as([*c]ObjLinkedList, @ptrCast(@alignCast(allocateObject(@sizeOf(ObjLinkedList), .OBJ_LINKED_LIST))));
    _ = &list;
    list.*.head = null;
    list.*.tail = null;
    list.*.count = 0;
    return list;
}
pub export fn cloneLinkedList(arg_list: [*c]ObjLinkedList) [*c]ObjLinkedList {
    var list = arg_list;
    _ = &list;
    var newList: [*c]ObjLinkedList = newLinkedList();
    _ = &newList;
    var current: [*c]Node = list.*.head;
    _ = &current;
    while (current != @as([*c]Node, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) {
        pushBack(newList, current.*.data);
        current = current.*.next;
    }
    return newList;
}
pub export fn clearLinkedList(arg_list: [*c]ObjLinkedList) void {
    var list = arg_list;
    _ = &list;
    var current: [*c]Node = list.*.head;
    _ = &current;
    while (current != @as([*c]Node, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) {
        var next: [*c]Node = current.*.next;
        _ = &next;
        _ = reallocate(@as(?*anyopaque, @ptrCast(current)), @sizeOf(Node), @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))));
        current = next;
    }
    list.*.head = null;
    list.*.tail = null;
    list.*.count = 0;
}
pub export fn pushFront(arg_list: [*c]ObjLinkedList, arg_value: Value) void {
    var list = arg_list;
    _ = &list;
    var value = arg_value;
    _ = &value;
    var node: [*c]Node = @as([*c]Node, @ptrCast(@alignCast(reallocate(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))), @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))), @sizeOf(Node) *% @as(c_ulong, @bitCast(@as(c_long, @as(c_int, 1))))))));
    _ = &node;
    node.*.data = value;
    node.*.prev = null;
    node.*.next = list.*.head;
    if (list.*.head != @as([*c]Node, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) {
        list.*.head.*.prev = node;
    }
    list.*.head = node;
    if (list.*.tail == @as([*c]Node, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) {
        list.*.tail = node;
    }
    list.*.count += 1;
}
pub export fn pushBack(arg_list: [*c]ObjLinkedList, arg_value: Value) void {
    var list = arg_list;
    _ = &list;
    var value = arg_value;
    _ = &value;
    var node: [*c]Node = @as([*c]Node, @ptrCast(@alignCast(reallocate(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))), @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))), @sizeOf(Node) *% @as(c_ulong, @bitCast(@as(c_long, @as(c_int, 1))))))));
    _ = &node;
    node.*.data = value;
    node.*.prev = list.*.tail;
    node.*.next = null;
    if (list.*.tail != @as([*c]Node, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) {
        list.*.tail.*.next = node;
    }
    list.*.tail = node;
    if (list.*.head == @as([*c]Node, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) {
        list.*.head = node;
    }
    list.*.count += 1;
}
pub export fn popFront(arg_list: [*c]ObjLinkedList) Value {
    var list = arg_list;
    _ = &list;
    if (list.*.head == @as([*c]Node, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) {
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    var node: [*c]Node = list.*.head;
    _ = &node;
    var data: Value = node.*.data;
    _ = &data;
    list.*.head = node.*.next;
    if (list.*.head != @as([*c]Node, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) {
        list.*.head.*.prev = null;
    }
    if (list.*.tail == node) {
        list.*.tail = null;
    }
    list.*.count -= 1;
    _ = reallocate(@as(?*anyopaque, @ptrCast(node)), @sizeOf(Node), @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))));
    return data;
}
pub export fn popBack(arg_list: [*c]ObjLinkedList) Value {
    var list = arg_list;
    _ = &list;
    if (list.*.tail == @as([*c]Node, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) {
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    var node: [*c]Node = list.*.tail;
    _ = &node;
    var data: Value = node.*.data;
    _ = &data;
    list.*.tail = node.*.prev;
    if (list.*.tail != @as([*c]Node, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) {
        list.*.tail.*.next = null;
    }
    if (list.*.head == node) {
        list.*.head = null;
    }
    list.*.count -= 1;
    _ = reallocate(@as(?*anyopaque, @ptrCast(node)), @sizeOf(Node), @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))));
    return data;
}
pub export fn equalLinkedList(arg_a: [*c]ObjLinkedList, arg_b: [*c]ObjLinkedList) bool {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    if (a.*.count != b.*.count) {
        return @as(c_int, 0) != 0;
    }
    var currentA: [*c]Node = a.*.head;
    _ = &currentA;
    var currentB: [*c]Node = b.*.head;
    _ = &currentB;
    while (currentA != @as([*c]Node, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) {
        if (!valuesEqual(currentA.*.data, currentB.*.data)) {
            return @as(c_int, 0) != 0;
        }
        currentA = currentA.*.next;
        currentB = currentB.*.next;
    }
    return @as(c_int, 1) != 0;
}
pub export fn freeObjectLinkedList(arg_list: [*c]ObjLinkedList) void {
    var list = arg_list;
    _ = &list;
    var current: [*c]Node = list.*.head;
    _ = &current;
    while (current != @as([*c]Node, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) {
        var next: [*c]Node = current.*.next;
        _ = &next;
        _ = reallocate(@as(?*anyopaque, @ptrCast(current)), @sizeOf(Node), @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))));
        current = next;
    }
    _ = reallocate(@as(?*anyopaque, @ptrCast(list)), @sizeOf(ObjLinkedList), @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))));
}
pub export fn mergeSort(arg_list: [*c]ObjLinkedList) void {
    var list = arg_list;
    _ = &list;
    if (list.*.count < @as(c_int, 2)) {
        return;
    }
    var left: ObjLinkedList = undefined;
    _ = &left;
    var right: ObjLinkedList = undefined;
    _ = &right;
    split(list, &left, &right);
    mergeSort(&left);
    mergeSort(&right);
    list.*.head = merge(left.head, right.head);
    var current: [*c]Node = list.*.head;
    _ = &current;
    while (current.*.next != @as([*c]Node, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) {
        current = current.*.next;
    }
    list.*.tail = current;
}
pub export fn searchLinkedList(arg_list: [*c]ObjLinkedList, arg_value: Value) c_int {
    var list = arg_list;
    _ = &list;
    var value = arg_value;
    _ = &value;
    var current: [*c]Node = list.*.head;
    _ = &current;
    var index_1: c_int = 0;
    _ = &index_1;
    while (current != @as([*c]Node, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) {
        if (valuesEqual(current.*.data, value)) {
            return index_1;
        }
        current = current.*.next;
        index_1 += 1;
    }
    return -@as(c_int, 1);
}
pub export fn reverseLinkedList(arg_list: [*c]ObjLinkedList) void {
    var list = arg_list;
    _ = &list;
    var current: [*c]Node = list.*.head;
    _ = &current;
    while (current != @as([*c]Node, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) {
        var temp: [*c]Node = current.*.next;
        _ = &temp;
        current.*.next = current.*.prev;
        current.*.prev = temp;
        current = temp;
    }
    var temp: [*c]Node = list.*.head;
    _ = &temp;
    list.*.head = list.*.tail;
    list.*.tail = temp;
}
pub export fn mergeLinkedList(arg_a: [*c]ObjLinkedList, arg_b: [*c]ObjLinkedList) [*c]ObjLinkedList {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    var result: [*c]ObjLinkedList = newLinkedList();
    _ = &result;
    var currentA: [*c]Node = a.*.head;
    _ = &currentA;
    var currentB: [*c]Node = b.*.head;
    _ = &currentB;
    while ((currentA != @as([*c]Node, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) and (currentB != @as([*c]Node, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0)))))))) {
        if (value_h.valueCompare(currentA.*.data, currentB.*.data) < @as(c_int, 0)) {
            pushBack(result, currentA.*.data);
            currentA = currentA.*.next;
        } else {
            pushBack(result, currentB.*.data);
            currentB = currentB.*.next;
        }
    }
    while (currentA != @as([*c]Node, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) {
        pushBack(result, currentA.*.data);
        currentA = currentA.*.next;
    }
    while (currentB != @as([*c]Node, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) {
        pushBack(result, currentB.*.data);
        currentB = currentB.*.next;
    }
    return result;
}
pub export fn sliceLinkedList(arg_list: [*c]ObjLinkedList, arg_start: c_int, arg_end: c_int) [*c]ObjLinkedList {
    var list = arg_list;
    _ = &list;
    var start = arg_start;
    _ = &start;
    var end = arg_end;
    _ = &end;
    var sliced: [*c]ObjLinkedList = newLinkedList();
    _ = &sliced;
    var current: [*c]Node = list.*.head;
    _ = &current;
    var index_1: c_int = 0;
    _ = &index_1;
    while (current != @as([*c]Node, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) {
        if ((index_1 >= start) and (index_1 < end)) {
            pushBack(sliced, current.*.data);
        }
        current = current.*.next;
        index_1 += 1;
    }
    return sliced;
}
pub export fn spliceLinkedList(arg_list: [*c]ObjLinkedList, arg_start: c_int, arg_end: c_int) [*c]ObjLinkedList {
    var list = arg_list;
    _ = &list;
    var start = arg_start;
    _ = &start;
    var end = arg_end;
    _ = &end;
    var spliced: [*c]ObjLinkedList = newLinkedList();
    _ = &spliced;
    var current: [*c]Node = list.*.head;
    _ = &current;
    var index_1: c_int = 0;
    _ = &index_1;
    while (current != @as([*c]Node, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) {
        var next: [*c]Node = current.*.next;
        _ = &next;
        if ((index_1 >= start) and (index_1 < end)) {
            pushBack(spliced, current.*.data);
            if (current.*.prev != @as([*c]Node, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) {
                current.*.prev.*.next = current.*.next;
            }
            if (current.*.next != @as([*c]Node, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) {
                current.*.next.*.prev = current.*.prev;
            }
            _ = reallocate(@as(?*anyopaque, @ptrCast(current)), @sizeOf(Node), @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))));
        }
        current = next;
        index_1 += 1;
    }
    return spliced;
}
pub export fn newHashTable() [*c]ObjHashTable {
    var htable: [*c]ObjHashTable = @as([*c]ObjHashTable, @ptrCast(@alignCast(allocateObject(@sizeOf(ObjHashTable), .OBJ_HASH_TABLE))));
    _ = &htable;
    table_h.initTable(&htable.*.table);
    return htable;
}
pub export fn cloneHashTable(arg_table: [*c]ObjHashTable) [*c]ObjHashTable {
    var table = arg_table;
    _ = &table;
    var newTable: [*c]ObjHashTable = newHashTable();
    _ = &newTable;
    table_h.tableAddAll(&table.*.table, &newTable.*.table);
    return newTable;
}
pub export fn clearHashTable(arg_table: [*c]ObjHashTable) void {
    var table = arg_table;
    _ = &table;
    table_h.freeTable(&table.*.table);
    table_h.initTable(&table.*.table);
}
pub export fn putHashTable(arg_table: [*c]ObjHashTable, arg_key: [*c]ObjString, arg_value: Value) bool {
    var table = arg_table;
    _ = &table;
    var key = arg_key;
    _ = &key;
    var value = arg_value;
    _ = &value;
    return table_h.tableSet(&table.*.table, key, value);
}
pub export fn getHashTable(arg_table: [*c]ObjHashTable, arg_key: [*c]ObjString) Value {
    var table = arg_table;
    _ = &table;
    var key = arg_key;
    _ = &key;
    var value: Value = undefined;
    _ = &value;
    if (table_h.tableGet(&table.*.table, key, &value)) {
        return value;
    } else {
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    return @import("std").mem.zeroes(Value);
}
pub export fn removeHashTable(arg_table: [*c]ObjHashTable, arg_key: [*c]ObjString) bool {
    var table = arg_table;
    _ = &table;
    var key = arg_key;
    _ = &key;
    return table_h.tableDelete(&table.*.table, key);
}
pub export fn freeObjectHashTable(arg_table: [*c]ObjHashTable) void {
    var table = arg_table;
    _ = &table;
    table_h.freeTable(&table.*.table);
    _ = reallocate(@as(?*anyopaque, @ptrCast(table)), @sizeOf(ObjHashTable), @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))));
}
pub extern fn mergeHashTable(a: [*c]ObjHashTable, b: [*c]ObjHashTable) [*c]ObjHashTable;
pub extern fn keysHashTable(table: [*c]ObjHashTable) [*c]ObjArray;
pub extern fn valuesHashTable(table: [*c]ObjHashTable) [*c]ObjArray;
pub export fn newMatrix(arg_rows: c_int, arg_cols: c_int) [*c]ObjMatrix {
    var rows = arg_rows;
    _ = &rows;
    var cols = arg_cols;
    _ = &cols;
    var matrix: [*c]ObjMatrix = @as([*c]ObjMatrix, @ptrCast(@alignCast(allocateObject(@sizeOf(ObjMatrix), .OBJ_MATRIX))));
    _ = &matrix;
    matrix.*.rows = rows;
    matrix.*.cols = cols;
    matrix.*.len = rows * cols;
    matrix.*.data = newArrayWithCap(matrix.*.len, @as(c_int, 1) != 0);
    {
        var i: c_int = 0;
        _ = &i;
        while (i < matrix.*.len) : (i += 1) {
            pushArray(matrix.*.data, Value{
                .type = .VAL_DOUBLE,
                .as = .{
                    .num_double = 0.0,
                },
            });
        }
    }
    return matrix;
}
pub export fn printMatrix(arg_matrix: [*c]ObjMatrix) void {
    var matrix = arg_matrix;
    _ = &matrix;
    if (matrix != @as([*c]ObjMatrix, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) {
        if (matrix.*.data.*.count > @as(c_int, 0)) {
            {
                {
                    var i: c_int = 0;
                    _ = &i;
                    while (i < matrix.*.len) : (i += 1) {
                        value_h.printValue((blk: {
                            const tmp = i;
                            if (tmp >= 0) break :blk matrix.*.data.*.values + @as(usize, @intCast(tmp)) else break :blk matrix.*.data.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                        }).*);
                        _ = printf(" ");
                        if (@import("std").zig.c_translation.signedRemainder(i + @as(c_int, 1), matrix.*.cols) == @as(c_int, 0)) {
                            _ = printf("\n");
                        }
                    }
                }
            }
        } else {
            _ = printf("[]\n");
        }
    }
}
pub export fn setRow(arg_matrix: [*c]ObjMatrix, arg_row: c_int, arg_values: [*c]ObjArray) void {
    var matrix = arg_matrix;
    _ = &matrix;
    var row = arg_row;
    _ = &row;
    var values = arg_values;
    _ = &values;
    if ((((matrix != @as([*c]ObjMatrix, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) and (values != @as([*c]ObjArray, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0)))))))) and (row >= @as(c_int, 0))) and (row < matrix.*.rows)) {
        {
            var col: c_int = 0;
            _ = &col;
            while (col < matrix.*.cols) : (col += 1) {
                overWriteArray(matrix.*.data, (row * matrix.*.cols) + col, (blk: {
                    const tmp = col;
                    if (tmp >= 0) break :blk values.*.values + @as(usize, @intCast(tmp)) else break :blk values.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                }).*);
            }
        }
    }
}
pub export fn setCol(arg_matrix: [*c]ObjMatrix, arg_col: c_int, arg_values: [*c]ObjArray) void {
    var matrix = arg_matrix;
    _ = &matrix;
    var col = arg_col;
    _ = &col;
    var values = arg_values;
    _ = &values;
    if ((((matrix != @as([*c]ObjMatrix, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) and (values != @as([*c]ObjArray, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0)))))))) and (col >= @as(c_int, 0))) and (col < matrix.*.cols)) {
        {
            var row: c_int = 0;
            _ = &row;
            while (row < matrix.*.rows) : (row += 1) {
                overWriteArray(matrix.*.data, (row * matrix.*.cols) + col, (blk: {
                    const tmp = row;
                    if (tmp >= 0) break :blk values.*.values + @as(usize, @intCast(tmp)) else break :blk values.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                }).*);
            }
        }
    }
}
pub export fn setMatrix(arg_matrix: [*c]ObjMatrix, arg_row: c_int, arg_col: c_int, arg_value: Value) void {
    var matrix = arg_matrix;
    _ = &matrix;
    var row = arg_row;
    _ = &row;
    var col = arg_col;
    _ = &col;
    var value = arg_value;
    _ = &value;
    if (((((matrix != @as([*c]ObjMatrix, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) and (row >= @as(c_int, 0))) and (row < matrix.*.rows)) and (col >= @as(c_int, 0))) and (col < matrix.*.cols)) {
        overWriteArray(matrix.*.data, (row * matrix.*.cols) + col, value);
    }
}
pub export fn getMatrix(arg_matrix: [*c]ObjMatrix, arg_row: c_int, arg_col: c_int) Value {
    var matrix = arg_matrix;
    _ = &matrix;
    var row = arg_row;
    _ = &row;
    var col = arg_col;
    _ = &col;
    if (((((matrix != @as([*c]ObjMatrix, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) and (row >= @as(c_int, 0))) and (row < matrix.*.rows)) and (col >= @as(c_int, 0))) and (col < matrix.*.cols)) {
        return (blk: {
            const tmp = (row * matrix.*.cols) + col;
            if (tmp >= 0) break :blk matrix.*.data.*.values + @as(usize, @intCast(tmp)) else break :blk matrix.*.data.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
        }).*;
    }
    return Value{
        .type = .VAL_NIL,
        .as = .{
            .num_int = @as(c_int, 0),
        },
    };
}
pub export fn addMatrix(arg_a: [*c]ObjMatrix, arg_b: [*c]ObjMatrix) [*c]ObjMatrix {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    if ((a.*.rows != b.*.rows) or (a.*.cols != b.*.cols)) {
        _ = printf("Matrix dimensions do not match");
        return null;
    }
    var result: [*c]ObjMatrix = newMatrix(a.*.rows, a.*.cols);
    _ = &result;
    {
        var i: c_int = 0;
        _ = &i;
        while (i < a.*.len) : (i += 1) {
            overWriteArray(result.*.data, i, Value{
                .type = .VAL_DOUBLE,
                .as = .{
                    .num_double = (blk: {
                        const tmp = i;
                        if (tmp >= 0) break :blk a.*.data.*.values + @as(usize, @intCast(tmp)) else break :blk a.*.data.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                    }).*.as.num_double + (blk: {
                        const tmp = i;
                        if (tmp >= 0) break :blk b.*.data.*.values + @as(usize, @intCast(tmp)) else break :blk b.*.data.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                    }).*.as.num_double,
                },
            });
        }
    }
    return result;
}
pub export fn subMatrix(arg_a: [*c]ObjMatrix, arg_b: [*c]ObjMatrix) [*c]ObjMatrix {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    if ((a.*.rows != b.*.rows) or (a.*.cols != b.*.cols)) {
        _ = printf("Matrix dimensions do not match");
        return null;
    }
    var result: [*c]ObjMatrix = newMatrix(a.*.rows, a.*.cols);
    _ = &result;
    {
        var i: c_int = 0;
        _ = &i;
        while (i < a.*.len) : (i += 1) {
            overWriteArray(result.*.data, i, Value{
                .type = .VAL_DOUBLE,
                .as = .{
                    .num_double = (blk: {
                        const tmp = i;
                        if (tmp >= 0) break :blk a.*.data.*.values + @as(usize, @intCast(tmp)) else break :blk a.*.data.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                    }).*.as.num_double - (blk: {
                        const tmp = i;
                        if (tmp >= 0) break :blk b.*.data.*.values + @as(usize, @intCast(tmp)) else break :blk b.*.data.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                    }).*.as.num_double,
                },
            });
        }
    }
    return result;
}
pub export fn mulMatrix(arg_a: [*c]ObjMatrix, arg_b: [*c]ObjMatrix) [*c]ObjMatrix {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    if (a.*.cols != b.*.rows) {
        _ = printf("Matrix dimensions do not match");
        return null;
    }
    var result: [*c]ObjMatrix = newMatrix(a.*.rows, b.*.cols);
    _ = &result;
    {
        var i: c_int = 0;
        _ = &i;
        while (i < a.*.rows) : (i += 1) {
            {
                var j: c_int = 0;
                _ = &j;
                while (j < b.*.cols) : (j += 1) {
                    var sum: Value = Value{
                        .type = .VAL_DOUBLE,
                        .as = .{
                            .num_double = 0.0,
                        },
                    };
                    _ = &sum;
                    {
                        var k: c_int = 0;
                        _ = &k;
                        while (k < a.*.cols) : (k += 1) {
                            var temp: Value = Value{
                                .type = .VAL_DOUBLE,
                                .as = .{
                                    .num_double = getMatrix(a, i, k).as.num_double * getMatrix(b, k, j).as.num_double,
                                },
                            };
                            _ = &temp;
                            sum = Value{
                                .type = .VAL_DOUBLE,
                                .as = .{
                                    .num_double = sum.as.num_double + temp.as.num_double,
                                },
                            };
                        }
                    }
                    setMatrix(result, i, j, sum);
                }
            }
        }
    }
    return result;
}
pub export fn divMatrix(arg_a: [*c]ObjMatrix, arg_b: [*c]ObjMatrix) [*c]ObjMatrix {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    if ((a.*.rows != b.*.rows) or (a.*.cols != b.*.cols)) {
        _ = printf("Matrix dimensions do not match");
        return null;
    }
    var result: [*c]ObjMatrix = newMatrix(a.*.rows, a.*.cols);
    _ = &result;
    {
        var i: c_int = 0;
        _ = &i;
        while (i < a.*.len) : (i += 1) {
            overWriteArray(result.*.data, i, Value{
                .type = .VAL_DOUBLE,
                .as = .{
                    .num_double = (blk: {
                        const tmp = i;
                        if (tmp >= 0) break :blk a.*.data.*.values + @as(usize, @intCast(tmp)) else break :blk a.*.data.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                    }).*.as.num_double / (blk: {
                        const tmp = i;
                        if (tmp >= 0) break :blk b.*.data.*.values + @as(usize, @intCast(tmp)) else break :blk b.*.data.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                    }).*.as.num_double,
                },
            });
        }
    }
    return result;
}
pub export fn transposeMatrix(arg_matrix: [*c]ObjMatrix) [*c]ObjMatrix {
    var matrix = arg_matrix;
    _ = &matrix;
    var result: [*c]ObjMatrix = newMatrix(matrix.*.cols, matrix.*.rows);
    _ = &result;
    {
        var i: c_int = 0;
        _ = &i;
        while (i < matrix.*.rows) : (i += 1) {
            {
                var j: c_int = 0;
                _ = &j;
                while (j < matrix.*.cols) : (j += 1) {
                    setMatrix(result, j, i, getMatrix(matrix, i, j));
                }
            }
        }
    }
    return result;
}
pub export fn scaleMatrix(arg_matrix: [*c]ObjMatrix, arg_scalar: Value) [*c]ObjMatrix {
    var matrix = arg_matrix;
    _ = &matrix;
    var scalar = arg_scalar;
    _ = &scalar;
    var result: [*c]ObjMatrix = newMatrix(matrix.*.rows, matrix.*.cols);
    _ = &result;
    {
        var i: c_int = 0;
        _ = &i;
        while (i < matrix.*.len) : (i += 1) {
            overWriteArray(result.*.data, i, mul_val((blk: {
                const tmp = i;
                if (tmp >= 0) break :blk matrix.*.data.*.values + @as(usize, @intCast(tmp)) else break :blk matrix.*.data.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*, scalar));
        }
    }
    return result;
}
pub extern fn swapRows(matrix: [*c]ObjMatrix, row1: c_int, row2: c_int) void;
pub export fn rref(arg_matrix: [*c]ObjMatrix) void {
    var matrix = arg_matrix;
    _ = &matrix;
    var lead: c_int = 0;
    _ = &lead;
    {
        var r: c_int = 0;
        _ = &r;
        while (r < matrix.*.rows) : (r += 1) {
            if (lead >= matrix.*.cols) {
                return;
            }
            var i: c_int = r;
            _ = &i;
            while (getMatrix(matrix, i, lead).as.num_double == 0.0) {
                i += 1;
                if (i == matrix.*.rows) {
                    i = r;
                    lead += 1;
                    if (lead == matrix.*.cols) {
                        return;
                    }
                }
            }
            swapRow(matrix, i, r);
            var div_1: Value = getMatrix(matrix, r, lead);
            _ = &div_1;
            if (div_1.as.num_double != 0.0) {
                {
                    var j: c_int = 0;
                    _ = &j;
                    while (j < matrix.*.cols) : (j += 1) {
                        var temp: Value = Value{
                            .type = .VAL_DOUBLE,
                            .as = .{
                                .num_double = getMatrix(matrix, r, j).as.num_double / div_1.as.num_double,
                            },
                        };
                        _ = &temp;
                        setMatrix(matrix, r, j, temp);
                    }
                }
            }
            {
                var i_1: c_int = 0;
                _ = &i_1;
                while (i_1 < matrix.*.rows) : (i_1 += 1) {
                    if (i_1 != r) {
                        var sub: Value = getMatrix(matrix, i_1, lead);
                        _ = &sub;
                        {
                            var j: c_int = 0;
                            _ = &j;
                            while (j < matrix.*.cols) : (j += 1) {
                                var temp: Value = Value{
                                    .type = .VAL_DOUBLE,
                                    .as = .{
                                        .num_double = getMatrix(matrix, i_1, j).as.num_double - (getMatrix(matrix, r, j).as.num_double * sub.as.num_double),
                                    },
                                };
                                _ = &temp;
                                setMatrix(matrix, i_1, j, temp);
                            }
                        }
                    }
                }
            }
            lead += 1;
        }
    }
}
pub export fn rank(arg_matrix: [*c]ObjMatrix) c_int {
    var matrix = arg_matrix;
    _ = &matrix;
    var copy: [*c]ObjMatrix = newMatrix(matrix.*.rows, matrix.*.cols);
    _ = &copy;
    {
        var i: c_int = 0;
        _ = &i;
        while (i < matrix.*.len) : (i += 1) {
            (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk copy.*.data.*.values + @as(usize, @intCast(tmp)) else break :blk copy.*.data.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).* = (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk matrix.*.data.*.values + @as(usize, @intCast(tmp)) else break :blk matrix.*.data.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*;
        }
    }
    rref(copy);
    var rank_1: c_int = 0;
    _ = &rank_1;
    {
        var i: c_int = 0;
        _ = &i;
        while (i < copy.*.rows) : (i += 1) {
            {
                var j: c_int = 0;
                _ = &j;
                while (j < copy.*.cols) : (j += 1) {
                    if (getMatrix(copy, i, j).as.num_double != 0.0) {
                        rank_1 += 1;
                        break;
                    }
                }
            }
        }
    }
    freeObjectArray(copy.*.data);
    _ = reallocate(@as(?*anyopaque, @ptrCast(copy)), @sizeOf(ObjMatrix), @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))));
    return rank_1;
}
pub export fn identityMatrix(arg_n: c_int) [*c]ObjMatrix {
    var n = arg_n;
    _ = &n;
    var result: [*c]ObjMatrix = newMatrix(n, n);
    _ = &result;
    {
        var i: c_int = 0;
        _ = &i;
        while (i < n) : (i += 1) {
            setMatrix(result, i, i, Value{
                .type = .VAL_DOUBLE,
                .as = .{
                    .num_double = 1.0,
                },
            });
        }
    }
    return result;
}
pub export fn lu(arg_matrix: [*c]ObjMatrix) [*c]ObjMatrix {
    var matrix = arg_matrix;
    _ = &matrix;
    var L: [*c]ObjMatrix = newMatrix(matrix.*.rows, matrix.*.cols);
    _ = &L;
    var U: [*c]ObjMatrix = newMatrix(matrix.*.rows, matrix.*.cols);
    _ = &U;
    {
        var i: c_int = 0;
        _ = &i;
        while (i < matrix.*.rows) : (i += 1) {
            {
                var j: c_int = 0;
                _ = &j;
                while (j < matrix.*.cols) : (j += 1) {
                    if (j < i) {
                        setMatrix(L, i, j, getMatrix(matrix, i, j));
                    } else if (j == i) {
                        setMatrix(L, i, j, Value{
                            .type = .VAL_DOUBLE,
                            .as = .{
                                .num_double = 1.0,
                            },
                        });
                        setMatrix(U, i, j, getMatrix(matrix, i, j));
                    } else {
                        setMatrix(L, i, j, Value{
                            .type = .VAL_DOUBLE,
                            .as = .{
                                .num_double = 0.0,
                            },
                        });
                        setMatrix(U, i, j, getMatrix(matrix, i, j));
                    }
                }
            }
        }
    }
    {
        var i: c_int = 0;
        _ = &i;
        while (i < matrix.*.rows) : (i += 1) {
            {
                var j: c_int = 0;
                _ = &j;
                while (j < matrix.*.cols) : (j += 1) {
                    if (j < i) {
                        setMatrix(U, i, j, Value{
                            .type = .VAL_DOUBLE,
                            .as = .{
                                .num_double = 0.0,
                            },
                        });
                    } else if (j == i) {
                        setMatrix(L, i, j, Value{
                            .type = .VAL_DOUBLE,
                            .as = .{
                                .num_double = 1.0,
                            },
                        });
                    } else {
                        var sum: Value = Value{
                            .type = .VAL_DOUBLE,
                            .as = .{
                                .num_double = 0.0,
                            },
                        };
                        _ = &sum;
                        {
                            var k: c_int = 0;
                            _ = &k;
                            while (k < i) : (k += 1) {
                                var temp: Value = Value{
                                    .type = .VAL_DOUBLE,
                                    .as = .{
                                        .num_double = getMatrix(L, i, k).as.num_double * getMatrix(U, k, j).as.num_double,
                                    },
                                };
                                _ = &temp;
                                sum = Value{
                                    .type = .VAL_DOUBLE,
                                    .as = .{
                                        .num_double = sum.as.num_double + temp.as.num_double,
                                    },
                                };
                            }
                        }
                        setMatrix(U, i, j, sub_val(getMatrix(matrix, i, j), sum));
                    }
                }
            }
        }
    }
    var result: [*c]ObjMatrix = newMatrix(@as(c_int, 2), @as(c_int, 1));
    _ = &result;
    setMatrix(result, @as(c_int, 0), @as(c_int, 0), Value{
        .type = .VAL_OBJ,
        .as = .{
            .obj = @as([*c]Obj, @ptrCast(@alignCast(L))),
        },
    });
    setMatrix(result, @as(c_int, 1), @as(c_int, 0), Value{
        .type = .VAL_OBJ,
        .as = .{
            .obj = @as([*c]Obj, @ptrCast(@alignCast(U))),
        },
    });
    return result;
}
pub export fn determinant(arg_matrix: [*c]ObjMatrix) f64 {
    var matrix = arg_matrix;
    _ = &matrix;
    if (matrix.*.rows != matrix.*.cols) {
        return 0.0;
    }
    var n: c_int = matrix.*.rows;
    _ = &n;
    var copy: [*c]ObjMatrix = copyMatrix(matrix);
    _ = &copy;
    var det: f64 = 1.0;
    _ = &det;
    if (n == @as(c_int, 2)) {
        var a: Value = getMatrix(copy, @as(c_int, 0), @as(c_int, 0));
        _ = &a;
        var b: Value = getMatrix(copy, @as(c_int, 0), @as(c_int, 1));
        _ = &b;
        var c: Value = getMatrix(copy, @as(c_int, 1), @as(c_int, 0));
        _ = &c;
        var d: Value = getMatrix(copy, @as(c_int, 1), @as(c_int, 1));
        _ = &d;
        var det_1: f64 = undefined;
        _ = &det_1;
        if ((((a.type == .VAL_DOUBLE) and (b.type == .VAL_DOUBLE)) and (c.type == .VAL_DOUBLE)) and (d.type == .VAL_DOUBLE)) {
            var a_val: f64 = a.as.num_double;
            _ = &a_val;
            var b_val: f64 = b.as.num_double;
            _ = &b_val;
            var c_val: f64 = c.as.num_double;
            _ = &c_val;
            var d_val: f64 = d.as.num_double;
            _ = &d_val;
            det_1 = (a_val * d_val) - (b_val * c_val);
        } else {
            var a_val: c_int = a.as.num_int;
            _ = &a_val;
            var b_val: c_int = b.as.num_int;
            _ = &b_val;
            var c_val: c_int = c.as.num_int;
            _ = &c_val;
            var d_val: c_int = d.as.num_int;
            _ = &d_val;
            det_1 = @as(f64, @floatFromInt((a_val * d_val) - (b_val * c_val)));
        }
        return det_1;
    }
    {
        var i: c_int = 0;
        _ = &i;
        while (i < n) : (i += 1) {
            {
                var j: c_int = i + @as(c_int, 1);
                _ = &j;
                while (j < n) : (j += 1) {
                    var factor: f64 = undefined;
                    _ = &factor;
                    if ((getMatrix(copy, j, i).type == .VAL_DOUBLE) and (getMatrix(copy, i, i).type == .VAL_DOUBLE)) {
                        factor = getMatrix(copy, j, i).as.num_double / getMatrix(copy, i, i).as.num_double;
                    } else {
                        var numerator: c_int = getMatrix(copy, j, i).as.num_int;
                        _ = &numerator;
                        var denominator: c_int = getMatrix(copy, i, i).as.num_int;
                        _ = &denominator;
                        factor = @as(f64, @floatFromInt(numerator)) / @as(f64, @floatFromInt(denominator));
                    }
                    {
                        var k: c_int = i;
                        _ = &k;
                        while (k < n) : (k += 1) {
                            var newValue: f64 = undefined;
                            _ = &newValue;
                            if ((getMatrix(copy, j, k).type == .VAL_DOUBLE) and (getMatrix(copy, i, k).type == .VAL_DOUBLE)) {
                                newValue = getMatrix(copy, j, k).as.num_double - (factor * getMatrix(copy, i, k).as.num_double);
                            } else {
                                var value1: c_int = getMatrix(copy, j, k).as.num_int;
                                _ = &value1;
                                var value2: c_int = getMatrix(copy, i, k).as.num_int;
                                _ = &value2;
                                newValue = @as(f64, @floatFromInt(value1)) - (factor * @as(f64, @floatFromInt(value2)));
                            }
                            setMatrix(copy, j, k, Value{
                                .type = .VAL_DOUBLE,
                                .as = .{
                                    .num_double = newValue,
                                },
                            });
                        }
                    }
                }
            }
            if (getMatrix(copy, i, i).type == .VAL_DOUBLE) {
                det *= getMatrix(copy, i, i).as.num_double;
            } else {
                var value: c_int = getMatrix(copy, i, i).as.num_int;
                _ = &value;
                det *= @as(f64, @floatFromInt(value));
            }
        }
    }
    freeObjectArray(copy.*.data);
    _ = reallocate(@as(?*anyopaque, @ptrCast(copy)), @sizeOf(ObjMatrix), @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))));
    return det;
}
pub extern fn inverseMatrix(matrix: [*c]ObjMatrix) [*c]ObjMatrix;
pub extern fn equalMatrix(a: [*c]ObjMatrix, b: [*c]ObjMatrix) bool;
pub extern fn solveMatrix(matrix: [*c]ObjMatrix, vector: [*c]ObjArray) [*c]ObjArray;
pub export fn newFloatVector(arg_size: c_int) [*c]FloatVector {
    var size = arg_size;
    _ = &size;
    var vector: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(allocateObject(@sizeOf(FloatVector), .OBJ_FVECTOR))));
    _ = &vector;
    vector.*.size = size;
    vector.*.count = 0;
    vector.*.data = @as([*c]f64, @ptrCast(@alignCast(reallocate(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))), @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))), @sizeOf(f64) *% @as(c_ulong, @bitCast(@as(c_long, size)))))));
    return vector;
}
pub export fn cloneFloatVector(arg_vector: [*c]FloatVector) [*c]FloatVector {
    var vector = arg_vector;
    _ = &vector;
    var newVector: [*c]FloatVector = newFloatVector(vector.*.size);
    _ = &newVector;
    {
        var i: c_int = 0;
        _ = &i;
        while (i < vector.*.count) : (i += 1) {
            pushFloatVector(newVector, (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*);
        }
    }
    return newVector;
}
pub export fn clearFloatVector(arg_vector: [*c]FloatVector) void {
    var vector = arg_vector;
    _ = &vector;
    vector.*.count = 0;
    vector.*.sorted = @as(c_int, 1) != 0;
}
pub export fn freeFloatVector(arg_vector: [*c]FloatVector) void {
    var vector = arg_vector;
    _ = &vector;
    _ = reallocate(@as(?*anyopaque, @ptrCast(vector.*.data)), @sizeOf(f32) *% @as(c_ulong, @bitCast(@as(c_long, vector.*.size))), @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))));
    _ = reallocate(@as(?*anyopaque, @ptrCast(vector)), @sizeOf(FloatVector), @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))));
}
pub export fn fromArray(arg_array: [*c]ObjArray) [*c]FloatVector {
    var array = arg_array;
    _ = &array;
    var vector: [*c]FloatVector = newFloatVector(array.*.count);
    _ = &vector;
    {
        var i: c_int = 0;
        _ = &i;
        while (i < array.*.count) : (i += 1) {
            if ((blk: {
                const tmp = i;
                if (tmp >= 0) break :blk array.*.values + @as(usize, @intCast(tmp)) else break :blk array.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*.type == .VAL_DOUBLE) {
                pushFloatVector(vector, (blk: {
                    const tmp = i;
                    if (tmp >= 0) break :blk array.*.values + @as(usize, @intCast(tmp)) else break :blk array.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                }).*.as.num_double);
            } else if ((blk: {
                const tmp = i;
                if (tmp >= 0) break :blk array.*.values + @as(usize, @intCast(tmp)) else break :blk array.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*.type == .VAL_INT) {
                pushFloatVector(vector, @as(f64, @floatFromInt((blk: {
                    const tmp = i;
                    if (tmp >= 0) break :blk array.*.values + @as(usize, @intCast(tmp)) else break :blk array.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                }).*.as.num_int)));
            } else {
                continue;
            }
        }
    }
    return vector;
}
pub export fn pushFloatVector(arg_vector: [*c]FloatVector, arg_value: f64) void {
    var vector = arg_vector;
    _ = &vector;
    var value = arg_value;
    _ = &value;
    if ((vector.*.count + @as(c_int, 1)) > vector.*.size) {
        _ = printf("Vector is full\n");
        return;
    }
    (blk: {
        const tmp = vector.*.count;
        if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).* = value;
    vector.*.count += 1;
    if ((vector.*.count > @as(c_int, 1)) and ((blk: {
        const tmp = vector.*.count - @as(c_int, 2);
        if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).* > value)) {
        vector.*.sorted = @as(c_int, 0) != 0;
    }
}
pub export fn insertFloatVector(arg_vector: [*c]FloatVector, arg_index_1: c_int, arg_value: f64) void {
    var vector = arg_vector;
    _ = &vector;
    var index_1 = arg_index_1;
    _ = &index_1;
    var value = arg_value;
    _ = &value;
    if ((index_1 < @as(c_int, 0)) or (index_1 >= vector.*.size)) {
        _ = printf("Index out of bounds\n");
        return;
    }
    {
        var i: c_int = vector.*.count;
        _ = &i;
        while (i > index_1) : (i -= 1) {
            (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).* = (blk: {
                const tmp = i - @as(c_int, 1);
                if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*;
        }
    }
    (blk: {
        const tmp = index_1;
        if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).* = value;
    vector.*.count += 1;
    if ((vector.*.count > @as(c_int, 1)) and ((blk: {
        const tmp = index_1;
        if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).* < (blk: {
        const tmp = index_1 - @as(c_int, 1);
        if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).*)) {
        vector.*.sorted = @as(c_int, 0) != 0;
    }
}
pub export fn getFloatVector(arg_vector: [*c]FloatVector, arg_index_1: c_int) f64 {
    var vector = arg_vector;
    _ = &vector;
    var index_1 = arg_index_1;
    _ = &index_1;
    if ((index_1 < @as(c_int, 0)) or (index_1 >= vector.*.count)) {
        _ = printf("Index out of bounds\n");
        return 0;
    }
    return (blk: {
        const tmp = index_1;
        if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).*;
}
pub export fn popFloatVector(arg_vector: [*c]FloatVector) f64 {
    var vector = arg_vector;
    _ = &vector;
    if (vector.*.count == @as(c_int, 0)) {
        _ = printf("Vector is empty\n");
        return 0;
    }
    var poppedValue: f64 = (blk: {
        const tmp = blk_1: {
            const ref = &vector.*.count;
            ref.* -= 1;
            break :blk_1 ref.*;
        };
        if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).*;
    _ = &poppedValue;
    if (vector.*.count == @as(c_int, 0)) {
        vector.*.sorted = @as(c_int, 1) != 0;
    }
    return poppedValue;
}
pub export fn removeFloatVector(arg_vector: [*c]FloatVector, arg_index_1: c_int) f64 {
    var vector = arg_vector;
    _ = &vector;
    var index_1 = arg_index_1;
    _ = &index_1;
    if ((index_1 < @as(c_int, 0)) or (index_1 >= vector.*.count)) {
        _ = printf("Index out of bounds\n");
        return 0;
    }
    var removedValue: f64 = (blk: {
        const tmp = index_1;
        if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).*;
    _ = &removedValue;
    {
        var i: c_int = index_1;
        _ = &i;
        while (i < (vector.*.count - @as(c_int, 1))) : (i += 1) {
            (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).* = (blk: {
                const tmp = i + @as(c_int, 1);
                if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*;
        }
    }
    vector.*.count -= 1;
    if (((@as(c_int, @intFromBool(vector.*.sorted)) != 0) and (index_1 > @as(c_int, 0))) and ((blk: {
        const tmp = index_1;
        if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).* < (blk: {
        const tmp = index_1 - @as(c_int, 1);
        if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).*)) {
        vector.*.sorted = @as(c_int, 0) != 0;
    }
    return removedValue;
}
pub export fn printFloatVector(arg_vector: [*c]FloatVector) void {
    var vector = arg_vector;
    _ = &vector;
    _ = printf("[");
    {
        var i: c_int = 0;
        _ = &i;
        while (i < vector.*.count) : (i += 1) {
            _ = printf("%.2f ", (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*);
        }
    }
    _ = printf("]");
    _ = printf("\n");
}
pub export fn mergeFloatVector(arg_a: [*c]FloatVector, arg_b: [*c]FloatVector) [*c]FloatVector {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    var result: [*c]FloatVector = newFloatVector(a.*.size + b.*.size);
    _ = &result;
    {
        var i: c_int = 0;
        _ = &i;
        while (i < a.*.count) : (i += 1) {
            pushFloatVector(result, (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk a.*.data + @as(usize, @intCast(tmp)) else break :blk a.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*);
        }
    }
    {
        var i: c_int = 0;
        _ = &i;
        while (i < b.*.count) : (i += 1) {
            pushFloatVector(result, (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk b.*.data + @as(usize, @intCast(tmp)) else break :blk b.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*);
        }
    }
    return result;
}
pub export fn sliceFloatVector(arg_vector: [*c]FloatVector, arg_start: c_int, arg_end: c_int) [*c]FloatVector {
    var vector = arg_vector;
    _ = &vector;
    var start = arg_start;
    _ = &start;
    var end = arg_end;
    _ = &end;
    if ((((start < @as(c_int, 0)) or (start >= vector.*.count)) or (end < @as(c_int, 0))) or (end >= vector.*.count)) {
        _ = printf("Index out of bounds\n");
        return null;
    }
    var result: [*c]FloatVector = newFloatVector((end - start) + @as(c_int, 1));
    _ = &result;
    {
        var i: c_int = start;
        _ = &i;
        while (i <= end) : (i += 1) {
            pushFloatVector(result, (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*);
        }
    }
    return result;
}
pub export fn spliceFloatVector(arg_vector: [*c]FloatVector, arg_start: c_int, arg_end: c_int) [*c]FloatVector {
    var vector = arg_vector;
    _ = &vector;
    var start = arg_start;
    _ = &start;
    var end = arg_end;
    _ = &end;
    if ((((start < @as(c_int, 0)) or (start >= vector.*.count)) or (end < @as(c_int, 0))) or (end >= vector.*.count)) {
        _ = printf("Index out of bounds\n");
        return null;
    }
    var result: [*c]FloatVector = newFloatVector(vector.*.size);
    _ = &result;
    {
        var i: c_int = 0;
        _ = &i;
        while (i < start) : (i += 1) {
            pushFloatVector(result, (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*);
        }
    }
    {
        var i: c_int = end + @as(c_int, 1);
        _ = &i;
        while (i < vector.*.count) : (i += 1) {
            pushFloatVector(result, (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*);
        }
    }
    return result;
}
pub export fn sumFloatVector(arg_vector: [*c]FloatVector) f64 {
    var vector = arg_vector;
    _ = &vector;
    var sum: f64 = 0;
    _ = &sum;
    var simdSize: usize = @as(usize, @bitCast(@as(c_long, vector.*.count - @import("std").zig.c_translation.signedRemainder(vector.*.count, @as(c_int, 4)))));
    _ = &simdSize;
    var simd_sum: __m256 = @as(__m256, @bitCast(_mm256_setzero_pd()));
    _ = &simd_sum;
    {
        var i: usize = 0;
        _ = &i;
        while (i < simdSize) : (i +%= @as(usize, @bitCast(@as(c_long, @as(c_int, 4))))) {
            var simd_arr: __m256 = @as(__m256, @bitCast(_mm256_loadu_pd(&vector.*.data[i])));
            _ = &simd_arr;
            simd_sum = @as(__m256, @bitCast(_mm256_add_pd(@as(__m256d, @bitCast(simd_arr)), @as(__m256d, @bitCast(simd_sum)))));
        }
    }
    {
        var i: usize = simdSize;
        _ = &i;
        while (i < @as(usize, @bitCast(@as(c_long, vector.*.count)))) : (i +%= 1) {
            sum += vector.*.data[i];
        }
    }
    var simd_sum_arr: [4]f64 = undefined;
    _ = &simd_sum_arr;
    _mm256_storeu_pd(@as([*c]f64, @ptrCast(@alignCast(&simd_sum_arr))), @as(__m256d, @bitCast(simd_sum)));
    {
        var i: c_int = 0;
        _ = &i;
        while (i < @as(c_int, 4)) : (i += 1) {
            sum += simd_sum_arr[@as(c_uint, @intCast(i))];
        }
    }
    return sum;
}
pub export fn meanFloatVector(arg_vector: [*c]FloatVector) f64 {
    var vector = arg_vector;
    _ = &vector;
    return sumFloatVector(vector) / @as(f64, @floatFromInt(vector.*.count));
}
pub export fn varianceFloatVector(arg_vector: [*c]FloatVector) f64 {
    var vector = arg_vector;
    _ = &vector;
    var mean: f64 = meanFloatVector(vector);
    _ = &mean;
    var variance: f64 = 0;
    _ = &variance;
    var simdSize: usize = @as(usize, @bitCast(@as(c_long, vector.*.count - @import("std").zig.c_translation.signedRemainder(vector.*.count, @as(c_int, 4)))));
    _ = &simdSize;
    var simd_variance: __m256 = @as(__m256, @bitCast(_mm256_setzero_pd()));
    _ = &simd_variance;
    {
        var i: usize = 0;
        _ = &i;
        while (i < simdSize) : (i +%= @as(usize, @bitCast(@as(c_long, @as(c_int, 4))))) {
            var simd_arr: __m256 = @as(__m256, @bitCast(_mm256_loadu_pd(&vector.*.data[i])));
            _ = &simd_arr;
            var simd_diff: __m256 = @as(__m256, @bitCast(_mm256_sub_pd(@as(__m256d, @bitCast(simd_arr)), _mm256_set1_pd(mean))));
            _ = &simd_diff;
            //simd_variance = @as(__m256, @bitCast(_mm256_add_pd(@as(__m256d, @bitCast(simd_diff)), @as(__m256d, @bitCast(simd_diff)), @as(__m256d, @bitCast(simd_variance)))));
        }
    }
    {
        var i: usize = simdSize;
        _ = &i;
        while (i < @as(usize, @bitCast(@as(c_long, vector.*.count)))) : (i +%= 1) {
            variance += (vector.*.data[i] - mean) * (vector.*.data[i] - mean);
        }
    }
    var simd_variance_arr: [4]f64 = undefined;
    _ = &simd_variance_arr;
    _mm256_storeu_pd(@as([*c]f64, @ptrCast(@alignCast(&simd_variance_arr))), @as(__m256d, @bitCast(simd_variance)));
    {
        var i: c_int = 0;
        _ = &i;
        while (i < @as(c_int, 4)) : (i += 1) {
            variance += simd_variance_arr[@as(c_uint, @intCast(i))];
        }
    }
    return variance / @as(f64, @floatFromInt(vector.*.count - @as(c_int, 1)));
}
pub export fn stdDevFloatVector(arg_vector: [*c]FloatVector) f64 {
    var vector = arg_vector;
    _ = &vector;
    return @sqrt(varianceFloatVector(vector));
}
pub export fn maxFloatVector(arg_vector: [*c]FloatVector) f64 {
    var vector = arg_vector;
    _ = &vector;
    var _max: f64 = vector.*.data[0];
    _ = &_max;
    {
        var i: c_int = 1;
        _ = &i;
        while (i < vector.*.count) : (i += 1) {
            if ((blk: {
                const tmp = i;
                if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).* > _max) {
                _max = (blk: {
                    const tmp = i;
                    if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                }).*;
            }
        }
    }
    return _max;
}

pub export fn minFloatVector(arg_vector: [*c]FloatVector) f64 {
    var vector = arg_vector;
    _ = &vector;
    var min: f64 = vector.*.data[0];
    _ = &min;
    {
        var i: c_int = 1;
        _ = &i;
        while (i < vector.*.count) : (i += 1) {
            if ((blk: {
                const tmp = i;
                if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).* < min) {
                min = (blk: {
                    const tmp = i;
                    if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                }).*;
            }
        }
    }
    return min;
}
pub export fn addFloatVector(arg_vector1: [*c]FloatVector, arg_vector2: [*c]FloatVector) [*c]FloatVector {
    var vector1 = arg_vector1;
    _ = &vector1;
    var vector2 = arg_vector2;
    _ = &vector2;
    if (vector1.*.size != vector2.*.size) {
        _ = printf("Vectors are not of the same size\n");
        return null;
    }
    var result: [*c]FloatVector = newFloatVector(vector1.*.size);
    _ = &result;
    var simdSize: usize = @as(usize, @bitCast(@as(c_long, vector1.*.count - @import("std").zig.c_translation.signedRemainder(vector1.*.count, @as(c_int, 4)))));
    _ = &simdSize;
    {
        var i: usize = 0;
        _ = &i;
        while (i < simdSize) : (i +%= @as(usize, @bitCast(@as(c_long, @as(c_int, 4))))) {
            var simd_arr1: __m256 = @as(__m256, @bitCast(_mm256_loadu_pd(&vector1.*.data[i])));
            _ = &simd_arr1;
            var simd_arr2: __m256 = @as(__m256, @bitCast(_mm256_loadu_pd(&vector2.*.data[i])));
            _ = &simd_arr2;
            var simd_result: __m256 = @as(__m256, @bitCast(_mm256_add_pd(@as(__m256d, @bitCast(simd_arr1)), @as(__m256d, @bitCast(simd_arr2)))));
            _ = &simd_result;
            _mm256_storeu_pd(&result.*.data[i], @as(__m256d, @bitCast(simd_result)));
        }
    }
    {
        var i: usize = simdSize;
        _ = &i;
        while (i < @as(usize, @bitCast(@as(c_long, vector1.*.count)))) : (i +%= 1) {
            result.*.data[i] = vector1.*.data[i] + vector2.*.data[i];
        }
    }
    result.*.count = vector1.*.count;
    return result;
}
pub export fn subFloatVector(arg_vector1: [*c]FloatVector, arg_vector2: [*c]FloatVector) [*c]FloatVector {
    var vector1 = arg_vector1;
    _ = &vector1;
    var vector2 = arg_vector2;
    _ = &vector2;
    if (vector1.*.size != vector2.*.size) {
        _ = printf("Vectors are not of the same size\n");
        return null;
    }
    var result: [*c]FloatVector = newFloatVector(vector1.*.size);
    _ = &result;
    var simdSize: usize = @as(usize, @bitCast(@as(c_long, vector1.*.count - @import("std").zig.c_translation.signedRemainder(vector1.*.count, @as(c_int, 4)))));
    _ = &simdSize;
    {
        var i: usize = 0;
        _ = &i;
        while (i < simdSize) : (i +%= @as(usize, @bitCast(@as(c_long, @as(c_int, 4))))) {
            var simd_arr1: __m256 = @as(__m256, @bitCast(_mm256_loadu_pd(&vector1.*.data[i])));
            _ = &simd_arr1;
            var simd_arr2: __m256 = @as(__m256, @bitCast(_mm256_loadu_pd(&vector2.*.data[i])));
            _ = &simd_arr2;
            var simd_result: __m256 = @as(__m256, @bitCast(_mm256_sub_pd(@as(__m256d, @bitCast(simd_arr1)), @as(__m256d, @bitCast(simd_arr2)))));
            _ = &simd_result;
            _mm256_storeu_pd(&result.*.data[i], @as(__m256d, @bitCast(simd_result)));
        }
    }
    {
        var i: usize = simdSize;
        _ = &i;
        while (i < @as(usize, @bitCast(@as(c_long, vector1.*.count)))) : (i +%= 1) {
            result.*.data[i] = vector1.*.data[i] - vector2.*.data[i];
        }
    }
    result.*.count = vector1.*.count;
    return result;
}
pub export fn mulFloatVector(arg_vector1: [*c]FloatVector, arg_vector2: [*c]FloatVector) [*c]FloatVector {
    var vector1 = arg_vector1;
    _ = &vector1;
    var vector2 = arg_vector2;
    _ = &vector2;
    if (vector1.*.size != vector2.*.size) {
        _ = printf("Vectors are not of the same size\n");
        return null;
    }
    var result: [*c]FloatVector = newFloatVector(vector1.*.size);
    _ = &result;
    var simdSize: usize = @as(usize, @bitCast(@as(c_long, vector1.*.count - @import("std").zig.c_translation.signedRemainder(vector1.*.count, @as(c_int, 4)))));
    _ = &simdSize;
    {
        var i: usize = 0;
        _ = &i;
        while (i < simdSize) : (i +%= @as(usize, @bitCast(@as(c_long, @as(c_int, 4))))) {
            var simd_arr1: __m256 = @as(__m256, @bitCast(_mm256_loadu_pd(&vector1.*.data[i])));
            _ = &simd_arr1;
            var simd_arr2: __m256 = @as(__m256, @bitCast(_mm256_loadu_pd(&vector2.*.data[i])));
            _ = &simd_arr2;
            var simd_result: __m256 = @as(__m256, @bitCast(_mm256_mul_pd(@as(__m256d, @bitCast(simd_arr1)), @as(__m256d, @bitCast(simd_arr2)))));
            _ = &simd_result;
            _mm256_storeu_pd(&result.*.data[i], @as(__m256d, @bitCast(simd_result)));
        }
    }
    {
        var i: usize = simdSize;
        _ = &i;
        while (i < @as(usize, @bitCast(@as(c_long, vector1.*.count)))) : (i +%= 1) {
            result.*.data[i] = vector1.*.data[i] * vector2.*.data[i];
        }
    }
    result.*.count = vector1.*.count;
    return result;
}
pub export fn divFloatVector(arg_vector1: [*c]FloatVector, arg_vector2: [*c]FloatVector) [*c]FloatVector {
    var vector1 = arg_vector1;
    _ = &vector1;
    var vector2 = arg_vector2;
    _ = &vector2;
    if (vector1.*.size != vector2.*.size) {
        _ = printf("Vectors are not of the same size\n");
        return null;
    }
    var result: [*c]FloatVector = newFloatVector(vector1.*.size);
    _ = &result;
    var simdSize: usize = @as(usize, @bitCast(@as(c_long, vector1.*.count - @import("std").zig.c_translation.signedRemainder(vector1.*.count, @as(c_int, 4)))));
    _ = &simdSize;
    {
        var i: usize = 0;
        _ = &i;
        while (i < simdSize) : (i +%= @as(usize, @bitCast(@as(c_long, @as(c_int, 4))))) {
            var simd_arr1: __m256 = @as(__m256, @bitCast(_mm256_loadu_pd(&vector1.*.data[i])));
            _ = &simd_arr1;
            var simd_arr2: __m256 = @as(__m256, @bitCast(_mm256_loadu_pd(&vector2.*.data[i])));
            _ = &simd_arr2;
            var simd_result: __m256 = @as(__m256, @bitCast(_mm256_div_pd(@as(__m256d, @bitCast(simd_arr1)), @as(__m256d, @bitCast(simd_arr2)))));
            _ = &simd_result;
            _mm256_storeu_pd(&result.*.data[i], @as(__m256d, @bitCast(simd_result)));
        }
    }
    {
        var i: usize = simdSize;
        _ = &i;
        while (i < @as(usize, @bitCast(@as(c_long, vector1.*.count)))) : (i +%= 1) {
            result.*.data[i] = vector1.*.data[i] / vector2.*.data[i];
        }
    }
    result.*.count = vector1.*.count;
    return result;
}
pub export fn equalFloatVector(arg_a: [*c]FloatVector, arg_b: [*c]FloatVector) bool {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    if (a.*.count != b.*.count) {
        return @as(c_int, 0) != 0;
    }
    {
        var i: c_int = 0;
        _ = &i;
        while (i < a.*.count) : (i += 1) {
            if ((blk: {
                const tmp = i;
                if (tmp >= 0) break :blk a.*.data + @as(usize, @intCast(tmp)) else break :blk a.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).* != (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk b.*.data + @as(usize, @intCast(tmp)) else break :blk b.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*) {
                return @as(c_int, 0) != 0;
            }
        }
    }
    return @as(c_int, 1) != 0;
}
pub export fn scaleFloatVector(arg_vector: [*c]FloatVector, arg_scalar: f64) [*c]FloatVector {
    var vector = arg_vector;
    _ = &vector;
    var scalar = arg_scalar;
    _ = &scalar;
    var result: [*c]FloatVector = newFloatVector(vector.*.size);
    _ = &result;
    var simdSize: usize = @as(usize, @bitCast(@as(c_long, vector.*.count - @import("std").zig.c_translation.signedRemainder(vector.*.count, @as(c_int, 4)))));
    _ = &simdSize;
    {
        var i: usize = 0;
        _ = &i;
        while (i < simdSize) : (i +%= @as(usize, @bitCast(@as(c_long, @as(c_int, 4))))) {
            var simd_arr1: __m256 = @as(__m256, @bitCast(_mm256_loadu_pd(&vector.*.data[i])));
            _ = &simd_arr1;
            var simd_scalar: __m256 = @as(__m256, @bitCast(_mm256_set1_pd(scalar)));
            _ = &simd_scalar;
            var simd_result: __m256 = @as(__m256, @bitCast(_mm256_mul_pd(@as(__m256d, @bitCast(simd_arr1)), @as(__m256d, @bitCast(simd_scalar)))));
            _ = &simd_result;
            _mm256_storeu_pd(&result.*.data[i], @as(__m256d, @bitCast(simd_result)));
        }
    }
    {
        var i: usize = simdSize;
        _ = &i;
        while (i < @as(usize, @bitCast(@as(c_long, vector.*.count)))) : (i +%= 1) {
            result.*.data[i] = vector.*.data[i] * scalar;
        }
    }
    result.*.count = vector.*.count;
    return result;
}
pub export fn singleAddFloatVector(arg_a: [*c]FloatVector, arg_b: f64) [*c]FloatVector {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    var result: [*c]FloatVector = newFloatVector(a.*.size);
    _ = &result;
    var simdSize: usize = @as(usize, @bitCast(@as(c_long, a.*.count - @import("std").zig.c_translation.signedRemainder(a.*.count, @as(c_int, 4)))));
    _ = &simdSize;
    {
        var i: usize = 0;
        _ = &i;
        while (i < simdSize) : (i +%= @as(usize, @bitCast(@as(c_long, @as(c_int, 4))))) {
            var simd_arr1: __m256 = @as(__m256, @bitCast(_mm256_loadu_pd(&a.*.data[i])));
            _ = &simd_arr1;
            var simd_scalar: __m256 = @as(__m256, @bitCast(_mm256_set1_pd(b)));
            _ = &simd_scalar;
            var simd_result: __m256 = @as(__m256, @bitCast(_mm256_add_pd(@as(__m256d, @bitCast(simd_arr1)), @as(__m256d, @bitCast(simd_scalar)))));
            _ = &simd_result;
            _mm256_storeu_pd(&result.*.data[i], @as(__m256d, @bitCast(simd_result)));
        }
    }
    {
        var i: usize = simdSize;
        _ = &i;
        while (i < @as(usize, @bitCast(@as(c_long, a.*.count)))) : (i +%= 1) {
            result.*.data[i] = a.*.data[i] + b;
        }
    }
    result.*.count = a.*.count;
    return result;
}
pub export fn singleSubFloatVector(arg_a: [*c]FloatVector, arg_b: f64) [*c]FloatVector {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    var result: [*c]FloatVector = newFloatVector(a.*.size);
    _ = &result;
    var simdSize: usize = @as(usize, @bitCast(@as(c_long, a.*.count - @import("std").zig.c_translation.signedRemainder(a.*.count, @as(c_int, 4)))));
    _ = &simdSize;
    {
        var i: usize = 0;
        _ = &i;
        while (i < simdSize) : (i +%= @as(usize, @bitCast(@as(c_long, @as(c_int, 4))))) {
            var simd_arr1: __m256 = @as(__m256, @bitCast(_mm256_loadu_pd(&a.*.data[i])));
            _ = &simd_arr1;
            var simd_scalar: __m256 = @as(__m256, @bitCast(_mm256_set1_pd(b)));
            _ = &simd_scalar;
            var simd_result: __m256 = @as(__m256, @bitCast(_mm256_sub_pd(@as(__m256d, @bitCast(simd_arr1)), @as(__m256d, @bitCast(simd_scalar)))));
            _ = &simd_result;
            _mm256_storeu_pd(&result.*.data[i], @as(__m256d, @bitCast(simd_result)));
        }
    }
    {
        var i: usize = simdSize;
        _ = &i;
        while (i < @as(usize, @bitCast(@as(c_long, a.*.count)))) : (i +%= 1) {
            result.*.data[i] = a.*.data[i] - b;
        }
    }
    result.*.count = a.*.count;
    return result;
}
pub extern fn singleMulFloatVector(a: [*c]FloatVector, b: f64) [*c]FloatVector;
pub export fn singleDivFloatVector(arg_a: [*c]FloatVector, arg_b: f64) [*c]FloatVector {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    return scaleFloatVector(a, 1.0 / b);
}
pub export fn sortFloatVector(arg_vector: [*c]FloatVector) void {
    var vector = arg_vector;
    _ = &vector;
    if (vector.*.sorted) return;
    qsort(@as(?*anyopaque, @ptrCast(vector.*.data)), @as(usize, @bitCast(@as(c_long, vector.*.count))), @sizeOf(f64), &compare_double);
}
pub export fn reverseFloatVector(arg_vector: [*c]FloatVector) void {
    var vector = arg_vector;
    _ = &vector;
    {
        var i: c_int = 0;
        _ = &i;
        while (i < @divTrunc(vector.*.count, @as(c_int, 2))) : (i += 1) {
            var temp: f64 = (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*;
            _ = &temp;
            (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).* = (blk: {
                const tmp = (vector.*.count - i) - @as(c_int, 1);
                if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*;
            (blk: {
                const tmp = (vector.*.count - i) - @as(c_int, 1);
                if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).* = temp;
        }
    }
}
pub export fn nextFloatVector(arg_vector: [*c]FloatVector) f64 {
    var vector = arg_vector;
    _ = &vector;
    if (hasNextFloatVector(vector)) {
        return (blk: {
            const tmp = blk_1: {
                const ref = &vector.*.pos;
                const tmp_2 = ref.*;
                ref.* += 1;
                break :blk_1 tmp_2;
            };
            if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
        }).*;
    }
    return 0.0;
}
pub export fn hasNextFloatVector(arg_vector: [*c]FloatVector) bool {
    var vector = arg_vector;
    _ = &vector;
    return vector.*.pos < vector.*.count;
}
pub export fn peekFloatVector(arg_vector: [*c]FloatVector, arg_pos: c_int) f64 {
    var vector = arg_vector;
    _ = &vector;
    var pos = arg_pos;
    _ = &pos;
    if (pos < vector.*.count) {
        return (blk: {
            const tmp = pos;
            if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
        }).*;
    }
    return 0.0;
}
pub export fn resetFloatVector(arg_vector: [*c]FloatVector) void {
    var vector = arg_vector;
    _ = &vector;
    vector.*.pos = 0;
}
pub export fn skipFloatVector(arg_vector: [*c]FloatVector, arg_n: c_int) void {
    var vector = arg_vector;
    _ = &vector;
    var n = arg_n;
    _ = &n;
    vector.*.pos = if ((vector.*.pos + n) < vector.*.count) vector.*.pos + n else vector.*.count;
}
pub export fn searchFloatVector(arg_vector: [*c]FloatVector, arg_value: f64) c_int {
    var vector = arg_vector;
    _ = &vector;
    var value = arg_value;
    _ = &value;
    if (vector.*.sorted) {
        return binarySearchFloatVector(vector, value);
    } else {
        {
            var i: c_int = 0;
            _ = &i;
            while (i < vector.*.count) : (i += 1) {
                if ((blk: {
                    const tmp = i;
                    if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                }).* == value) {
                    return i;
                }
            }
        }
    }
    return -@as(c_int, 1);
}
pub export fn linspace(arg_start: f64, arg_end: f64, arg_n: c_int) [*c]FloatVector {
    var start = arg_start;
    _ = &start;
    var end = arg_end;
    _ = &end;
    var n = arg_n;
    _ = &n;
    var result: [*c]FloatVector = newFloatVector(n);
    _ = &result;
    var step: f64 = (end - start) / @as(f64, @floatFromInt(n - @as(c_int, 1)));
    _ = &step;
    {
        var i: c_int = 0;
        _ = &i;
        while (i < n) : (i += 1) {
            (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk result.*.data + @as(usize, @intCast(tmp)) else break :blk result.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).* = start + (@as(f64, @floatFromInt(i)) * step);
        }
    }
    result.*.count = n;
    return result;
}
pub export fn interp1(arg_x: [*c]FloatVector, arg_y: [*c]FloatVector, arg_x0: f64) f64 {
    var x = arg_x;
    _ = &x;
    var y = arg_y;
    _ = &y;
    var x0 = arg_x0;
    _ = &x0;
    if (x.*.count != y.*.count) {
        _ = printf("x and y must have the same length\n");
        return 0;
    }
    if ((x0 < x.*.data[0]) or (x0 > (blk: {
        const tmp = x.*.count - @as(c_int, 1);
        if (tmp >= 0) break :blk x.*.data + @as(usize, @intCast(tmp)) else break :blk x.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).*)) {
        _ = printf("x0 is out of bounds\n");
        return 0;
    }
    var i: c_int = 0;
    _ = &i;
    while (x0 > (blk: {
        const tmp = i;
        if (tmp >= 0) break :blk x.*.data + @as(usize, @intCast(tmp)) else break :blk x.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).*) {
        i += 1;
    }
    if (x0 == (blk: {
        const tmp = i;
        if (tmp >= 0) break :blk x.*.data + @as(usize, @intCast(tmp)) else break :blk x.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).*) {
        return (blk: {
            const tmp = i;
            if (tmp >= 0) break :blk y.*.data + @as(usize, @intCast(tmp)) else break :blk y.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
        }).*;
    }
    var slope: f64 = ((blk: {
        const tmp = i;
        if (tmp >= 0) break :blk y.*.data + @as(usize, @intCast(tmp)) else break :blk y.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).* - (blk: {
        const tmp = i - @as(c_int, 1);
        if (tmp >= 0) break :blk y.*.data + @as(usize, @intCast(tmp)) else break :blk y.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).*) / ((blk: {
        const tmp = i;
        if (tmp >= 0) break :blk x.*.data + @as(usize, @intCast(tmp)) else break :blk x.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).* - (blk: {
        const tmp = i - @as(c_int, 1);
        if (tmp >= 0) break :blk x.*.data + @as(usize, @intCast(tmp)) else break :blk x.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).*);
    _ = &slope;
    return (blk: {
        const tmp = i - @as(c_int, 1);
        if (tmp >= 0) break :blk y.*.data + @as(usize, @intCast(tmp)) else break :blk y.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).* + (slope * (x0 - (blk: {
        const tmp = i - @as(c_int, 1);
        if (tmp >= 0) break :blk x.*.data + @as(usize, @intCast(tmp)) else break :blk x.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).*));
}
pub export fn dotProduct(arg_a: [*c]FloatVector, arg_b: [*c]FloatVector) f64 {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    if ((a.*.size != @as(c_int, 3)) and (b.*.size != @as(c_int, 3))) {
        _ = printf("Vectors are not of size 3\n");
        return 0;
    }
    return ((a.*.data[0] * b.*.data[0]) + (a.*.data[1] * b.*.data[1])) + (a.*.data[2] * b.*.data[2]);
}
pub export fn crossProduct(arg_a: [*c]FloatVector, arg_b: [*c]FloatVector) [*c]FloatVector {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    if ((a.*.size != @as(c_int, 3)) and (b.*.size != @as(c_int, 3))) {
        _ = printf("Vectors are not of size 3\n");
        return null;
    }
    var result: [*c]FloatVector = newFloatVector(@as(c_int, 3));
    _ = &result;
    result.*.data[0] = (a.*.data[1] * b.*.data[2]) - (a.*.data[2] * b.*.data[1]);
    result.*.data[1] = (a.*.data[2] * b.*.data[0]) - (a.*.data[0] * b.*.data[2]);
    result.*.data[2] = (a.*.data[0] * b.*.data[1]) - (a.*.data[1] * b.*.data[0]);
    result.*.count = 3;
    return result;
}
pub export fn magnitude(arg_vector: [*c]FloatVector) f64 {
    var vector = arg_vector;
    _ = &vector;
    var sum: f64 = (std.math.pow(f64, vector.*.data[0], @as(f64, @floatFromInt(@as(c_int, 2)))) + std.math.pow(f64, vector.*.data[1], @as(f64, @floatFromInt(@as(c_int, 2))))) + std.math.pow(f64, vector.*.data[2], @as(f64, @floatFromInt(@as(c_int, 2))));
    _ = &sum;
    return @sqrt(sum);
}
pub export fn normalize(arg_vector: [*c]FloatVector) [*c]FloatVector {
    var vector = arg_vector;
    _ = &vector;
    var mag: f64 = magnitude(vector);
    _ = &mag;
    if (mag == @as(f64, @floatFromInt(@as(c_int, 0)))) {
        _ = printf("Cannot normalize a zero vector\n");
        return null;
    }
    return scaleFloatVector(vector, 1.0 / mag);
}
pub export fn projection(arg_a: [*c]FloatVector, arg_b: [*c]FloatVector) [*c]FloatVector {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    return scaleFloatVector(b, dotProduct(a, b) / dotProduct(b, b));
}
pub export fn rejection(arg_a: [*c]FloatVector, arg_b: [*c]FloatVector) [*c]FloatVector {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    return subFloatVector(a, projection(a, b));
}
pub export fn reflection(arg_a: [*c]FloatVector, arg_b: [*c]FloatVector) [*c]FloatVector {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    return subFloatVector(scaleFloatVector(projection(a, b), @as(f64, @floatFromInt(@as(c_int, 2)))), a);
}
pub export fn refraction(arg_a: [*c]FloatVector, arg_b: [*c]FloatVector, arg_n1: f64, arg_n2: f64) [*c]FloatVector {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    var n1 = arg_n1;
    _ = &n1;
    var n2 = arg_n2;
    _ = &n2;
    var dot: f64 = dotProduct(a, b);
    _ = &dot;
    var mag_a: f64 = magnitude(a);
    _ = &mag_a;
    var mag_b: f64 = magnitude(b);
    _ = &mag_b;
    var theta: f64 = std.math.acos(dot / (mag_a * mag_b));
    _ = &theta;
    var sin_theta_r: f64 = (n1 / n2) * std.math.sin(theta);
    _ = &sin_theta_r;
    if (sin_theta_r > @as(f64, @floatFromInt(@as(c_int, 1)))) {
        _ = printf("Total internal reflection\n");
        return null;
    }
    var cos_theta_r: f64 = @sqrt(@as(f64, @floatFromInt(@as(c_int, 1))) - std.math.pow(f64, sin_theta_r, @as(f64, @floatFromInt(@as(c_int, 2)))));
    _ = &cos_theta_r;
    var result: [*c]FloatVector = scaleFloatVector(a, n1 / n2);
    _ = &result;
    var temp: [*c]FloatVector = scaleFloatVector(b, ((n1 / n2) * cos_theta_r) - @sqrt(@as(f64, @floatFromInt(@as(c_int, 1))) - std.math.pow(f64, sin_theta_r, @as(f64, @floatFromInt(@as(c_int, 2))))));
    _ = &temp;
    return addFloatVector(result, temp);
}
pub export fn angle(arg_a: [*c]FloatVector, arg_b: [*c]FloatVector) f64 {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    return std.math.acos(dotProduct(a, b) / (magnitude(a) * magnitude(b)));
}
pub export fn printObject(arg_value: Value) void {
    var value = arg_value;
    _ = &value;
    while (true) {
        switch (value.as.obj.*.type) {
            .OBJ_BOUND_METHOD => {
                {
                    printFunction(@as([*c]ObjBoundMethod, @ptrCast(@alignCast(value.as.obj))).*.method.*.function);
                    break;
                }
            },
            .OBJ_CLASS => {
                _ = printf("%s", @as([*c]ObjClass, @ptrCast(@alignCast(value.as.obj))).*.name.*.chars);
                break;
            },
            .OBJ_CLOSURE => {
                printFunction(@as([*c]ObjClosure, @ptrCast(@alignCast(value.as.obj))).*.function);
                break;
            },
            .OBJ_FUNCTION => {
                printFunction(@as([*c]ObjFunction, @ptrCast(@alignCast(value.as.obj))));
                break;
            },
            .OBJ_INSTANCE => {
                _ = printf("%s instance", @as([*c]ObjInstance, @ptrCast(@alignCast(value.as.obj))).*.klass.*.name.*.chars);
                break;
            },
            .OBJ_NATIVE => {
                _ = printf("<native fn>");
                break;
            },
            .OBJ_STRING => {
                _ = printf("%s", @as([*c]ObjString, @ptrCast(@alignCast(value.as.obj))).*.chars);
                break;
            },
            .OBJ_UPVALUE => {
                _ = printf("upvalue");
                break;
            },
            .OBJ_ARRAY => {
                {
                    var array: [*c]ObjArray = @as([*c]ObjArray, @ptrCast(@alignCast(value.as.obj)));
                    _ = &array;
                    _ = printf("[");
                    {
                        var i: c_int = 0;
                        _ = &i;
                        while (i < array.*.count) : (i += 1) {
                            value_h.printValue((blk: {
                                const tmp = i;
                                if (tmp >= 0) break :blk array.*.values + @as(usize, @intCast(tmp)) else break :blk array.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                            }).*);
                            if (i != (array.*.count - @as(c_int, 1))) {
                                _ = printf(", ");
                            }
                        }
                    }
                    _ = printf("]");
                    break;
                }
            },
            .OBJ_FVECTOR => {
                {
                    var vector: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(value.as.obj)));
                    _ = &vector;
                    _ = printf("[");
                    {
                        var i: c_int = 0;
                        _ = &i;
                        while (i < vector.*.count) : (i += 1) {
                            _ = printf("%.2f", (blk: {
                                const tmp = i;
                                if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                            }).*);
                            if (i != (vector.*.count - @as(c_int, 1))) {
                                _ = printf(", ");
                            }
                        }
                    }
                    _ = printf("]");
                    break;
                }
            },
            .OBJ_LINKED_LIST => {
                {
                    _ = printf("[");
                    var current: [*c]Node = @as([*c]ObjLinkedList, @ptrCast(@alignCast(value.as.obj))).*.head;
                    _ = &current;
                    while (current != @as([*c]Node, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) {
                        value_h.printValue(current.*.data);
                        if (current.*.next != @as([*c]Node, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) {
                            _ = printf(", ");
                        }
                        current = current.*.next;
                    }
                    _ = printf("]");
                    break;
                }
            },
            .OBJ_HASH_TABLE => {
                {
                    var hashtable: [*c]ObjHashTable = @as([*c]ObjHashTable, @ptrCast(@alignCast(value.as.obj)));
                    _ = &hashtable;
                    _ = printf("{");
                    var entries: [*c]table_h.Entry = hashtable.*.table.entries;
                    _ = &entries;
                    var count: c_int = 0;
                    _ = &count;
                    {
                        var i: c_int = 0;
                        _ = &i;
                        while (i < hashtable.*.table.capacity) : (i += 1) {
                            if ((blk: {
                                const tmp = i;
                                if (tmp >= 0) break :blk entries + @as(usize, @intCast(tmp)) else break :blk entries - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                            }).*.key != @as([*c]ObjString, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) {
                                if (count > @as(c_int, 0)) {
                                    _ = printf(", ");
                                }
                                value_h.printValue(Value{
                                    .type = .VAL_OBJ,
                                    .as = .{
                                        .obj = @as([*c]Obj, @ptrCast(@alignCast((blk: {
                                            const tmp = i;
                                            if (tmp >= 0) break :blk entries + @as(usize, @intCast(tmp)) else break :blk entries - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                                        }).*.key))),
                                    },
                                });
                                _ = printf(": ");
                                value_h.printValue((blk: {
                                    const tmp = i;
                                    if (tmp >= 0) break :blk entries + @as(usize, @intCast(tmp)) else break :blk entries - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                                }).*.value);
                                count += 1;
                            }
                        }
                    }
                    _ = printf("}");
                    break;
                }
            },
            .OBJ_MATRIX => {
                {
                    printMatrix(@as([*c]ObjMatrix, @ptrCast(@alignCast(value.as.obj))));
                    break;
                }
            },
        }
        break;
    }
}
pub fn isObjType(arg_value: Value, arg_type: ObjType) callconv(.C) bool {
    var value = arg_value;
    _ = &value;
    var @"type" = arg_type;
    _ = &@"type";
    return (value.type == .VAL_OBJ) and (value.as.obj.*.type == @"type");
}

pub const ObjTypeCheckParams = extern struct {
    values: [*c]Value,
    objType: ObjType,
    count: c_int,
};
pub fn notObjTypes(arg_params: ObjTypeCheckParams) callconv(.C) bool {
    var params = arg_params;
    _ = &params;
    {
        var i: c_int = 0;
        _ = &i;
        while (i < params.count) : (i += 1) {
            if (isObjType((blk: {
                const tmp = i;
                if (tmp >= 0) break :blk params.values + @as(usize, @intCast(tmp)) else break :blk params.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*, params.objType)) {
                return @as(c_int, 0) != 0;
            }
        }
    }
    return @as(c_int, 1) != 0;
}
