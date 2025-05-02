const value_h = @import("value.zig");
const obj_h = @import("object.zig");
const table_h = @import("table.zig");
const conv = @import("conv.zig");
const Entry = table_h.Entry;
const entries_ = table_h.entries_;
const Value = value_h.Value;
const vm_h = @import("vm.zig");
const runtimeError = vm_h.runtimeError;
const valuesEqual = value_h.valuesEqual;
const valueToString = value_h.valueToString;
const isObjType = obj_h.isObjType;
const notObjTypes = obj_h.notObjTypes;
const ObjString = obj_h.ObjString;
const ObjLinkedList = obj_h.ObjLinkedList;
const FloatVector = obj_h.FloatVector;
const ObjHashTable = obj_h.ObjHashTable;
const Obj = obj_h.Obj;
const Node = obj_h.Node;
const ObjTypeCheckParams = obj_h.ObjTypeCheckParams;
const printf = @cImport(@cInclude("stdio.h")).printf;
const fvec = @import("objects/fvec.zig");
const pushFloatVector = fvec.FloatVector.push;

pub fn assert_nf(argCount: c_int, args: [*c]Value) Value {
    if (argCount != @as(c_int, 2)) {
        runtimeError("assert() takes 1 argument.", .{});
        return Value.init_nil();
    }
    if (valuesEqual(args[0], args[1])) {
        return Value.init_nil();
    } else {
        runtimeError("Assertion failed {s} != {s}", .{ valueToString(args[0]), valueToString(args[1]) });
        return Value.init_nil();
    }
    return Value.init_nil();
}

pub fn iter_nf(argCount: c_int, args: [*c]Value) Value {
    _ = argCount;
    _ = args;
    return Value.init_nil();
}
pub fn next_nf(argCount: c_int, args: [*c]Value) Value {
    if (argCount != 1) {
        runtimeError("next() takes 1 argument.", .{});
        return Value.init_nil();
    }
    if (isObjType(args[0], .OBJ_FVECTOR)) {
        runtimeError("Argument must be an iterable.", .{});
        return Value.init_nil();
    }
    var next: Value = Value.init_nil();
    _ = &next;
    if (isObjType(args[0], .OBJ_FVECTOR)) {
        next = Value{
            .type = .VAL_DOUBLE,
            .as = .{
                .num_double = fvec.nextFloatVector(@as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj)))),
            },
        };
    }
    return next;
}
pub fn hasNext_nf(argCount: c_int, args: [*c]Value) Value {
    if (argCount != 1) {
        runtimeError("has_next() takes 1 argument.", .{});
        return Value.init_nil();
    }
    if (!isObjType(args[0], .OBJ_FVECTOR)) {
        runtimeError("Argument must be an iterable.", .{});
        return Value.init_nil();
    }
    var hasNext: bool = false;
    if (isObjType(args[0], .OBJ_FVECTOR)) {
        hasNext = fvec.hasNextFloatVector(@as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj))));
    }
    return Value{
        .type = .VAL_BOOL,
        .as = .{
            .boolean = hasNext,
        },
    };
}
pub fn peek_nf(argCount: c_int, args: [*c]Value) Value {
    if (argCount != @as(c_int, 2)) {
        runtimeError("peek() takes 2 argument.", .{});
        return Value.init_nil();
    }
    if (!isObjType(args[0], .OBJ_FVECTOR)) {
        runtimeError("Argument must be an iterable.", .{});
        return Value.init_nil();
    }
    if (!((args[1].type == .VAL_INT) or (args[1].is_double()))) {
        runtimeError("Second argument must be a number.", .{});
        return Value.init_nil();
    }
    var pos: c_int = if (args[1].is_double()) @intFromFloat(args[1].as_num_double()) else args[1].as.num_int;
    _ = &pos;
    var peek: Value = Value.init_nil();
    if (isObjType(args[0], .OBJ_FVECTOR)) {
        peek = Value{
            .type = .VAL_DOUBLE,
            .as = .{
                .num_double = fvec.peekFloatVector(@as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj))), pos),
            },
        };
    }
    return peek;
}
pub fn reset_nf(argCount: c_int, args: [*c]Value) Value {
    if (argCount != 1) {
        runtimeError("reset() takes 1 argument.", .{});
        return Value.init_nil();
    }
    if (!isObjType(args[0], .OBJ_FVECTOR)) {
        runtimeError("Argument must be an iterable.", .{});
        return Value.init_nil();
    }
    if (isObjType(args[0], .OBJ_FVECTOR)) {
        fvec.resetFloatVector(@as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj))));
    }
    return Value.init_nil();
}
pub fn skip_nf(argCount: c_int, args: [*c]Value) Value {
    if (argCount != @as(c_int, 2)) {
        runtimeError("skip() takes 2 arguments.", .{});
        return Value.init_nil();
    }
    if (!isObjType(args[0], .OBJ_FVECTOR)) {
        runtimeError("Argument must be an iterable.", .{});
        return Value.init_nil();
    }
    if (!((args[1].type == .VAL_INT) or (args[1].is_double()))) {
        runtimeError("Second argument must be a number.", .{});
        return Value.init_nil();
    }
    var skip: c_int = if (args[1].is_double()) @intFromFloat(args[1].as_num_double()) else args[1].as.num_int;
    _ = &skip;
    if (isObjType(args[0], .OBJ_FVECTOR)) {
        fvec.skipFloatVector(@as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj))), skip);
    }
    return Value.init_nil();
}

pub fn linkedlist_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &args;
    if (argCount != 0) {
        runtimeError("linked_list() takes no arguments.", .{});
        return Value.init_nil();
    }
    var l: [*c]ObjLinkedList = obj_h.newLinkedList();
    _ = &l;
    return Value{
        .type = .VAL_OBJ,
        .as = .{
            .obj = @as([*c]Obj, @ptrCast(@alignCast(l))),
        },
    };
}
pub fn hashtable_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &args;
    if (argCount != 0) {
        runtimeError("hash_table() takes no arguments.", .{});
        return Value.init_nil();
    }
    var h: [*c]ObjHashTable = obj_h.newHashTable();
    _ = &h;
    return Value{
        .type = .VAL_OBJ,
        .as = .{
            .obj = @as([*c]Obj, @ptrCast(@alignCast(h))),
        },
    };
}

pub fn fvector_nf(argCount: c_int, args: [*c]Value) Value {
    if (argCount != 1) {
        runtimeError("fvec() takes 1 argument.", .{});
        return Value.init_nil();
    }
    if (!(args[0].is_int() or args[0].is_double())) {
        runtimeError("First argument must be a number.", .{});
        return Value.init_nil();
    }

    const cap: i32 = if (args[0].is_double()) @intFromFloat(args[0].as_num_double()) else args[0].as.num_int;
    const f: [*c]FloatVector = fvec.FloatVector.init(cap);
    return Value.init_obj(@ptrCast(@alignCast(f)));
}

// pub fn range_nf(argCount: c_int, args: [*c]Value) Value {
//     _ = &argCount;
//     if (!((args[0].type == .VAL_INT) or (args[0].is_double())) and !((args[1].type == .VAL_INT) or (args[1].is_double()))) {
//         runtimeError("Both arguments must be numbers.", .{});
//         return Value.init_nil();
//     }
//     var start: c_int = if (args[0].is_double()) @intFromFloat(args[0].as_num_double()) else args[0].as.num_int;
//     _ = &start;
//     var end: c_int = if (args[1].is_double()) @intFromFloat(args[1].as_num_double()) else args[1].as.num_int;
//     _ = &end;
//     var a: [*c]ObjArray = obj_h.newArrayWithCap(end - start, true);
//     _ = &a;
//     {
//         var i: c_int = start;
//         _ = &i;
//         while (i < end) : (i += 1) {
//             obj_h.pushArray(a, Value.init_int(i));
//         }
//     }
//     return Value{
//         .type = .VAL_OBJ,
//         .as = .{
//             .obj = @as([*c]Obj, @ptrCast(@alignCast(a))),
//         },
//     };
// }
pub fn slice_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_LINKED_LIST,
        .count = 1,
    })) and (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    }))) {
        runtimeError("First argument must be an array, linked list or vector.", .{});
        return Value.init_nil();
    }
    if (!((args[0].type == .VAL_INT) or (args[0].is_double())) and !((args[1].type == .VAL_INT) or (args[1].is_double()))) {
        runtimeError("Second and third arguments must be numbers.", .{});
        return Value.init_nil();
    }
    while (true) {
        switch (args[0].as.obj.*.type) {
            .OBJ_FVECTOR => {
                {
                    var f: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &f;
                    var start: c_int = if (args[1].is_double()) @intFromFloat(args[1].as_num_double()) else args[1].as.num_int;
                    _ = &start;
                    var end: c_int = if (args[2].type == .VAL_DOUBLE) @intFromFloat(args[2].as.num_double) else args[2].as.num_int;
                    _ = &end;
                    var s: [*c]FloatVector = fvec.sliceFloatVector(f, start, end);
                    _ = &s;
                    return Value{
                        .type = .VAL_OBJ,
                        .as = .{
                            .obj = @as([*c]Obj, @ptrCast(@alignCast(s))),
                        },
                    };
                }
            },
            .OBJ_LINKED_LIST => {
                {
                    var l: [*c]ObjLinkedList = @as([*c]ObjLinkedList, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &l;
                    var start: c_int = if (args[1].is_double()) @intFromFloat(args[1].as_num_double()) else args[1].as.num_int;
                    _ = &start;
                    var end: c_int = if (args[2].type == .VAL_DOUBLE) @intFromFloat(args[2].as.num_double) else args[2].as.num_int;
                    _ = &end;
                    var s: [*c]ObjLinkedList = obj_h.sliceLinkedList(l, start, end);
                    _ = &s;
                    return Value{
                        .type = .VAL_OBJ,
                        .as = .{
                            .obj = @as([*c]Obj, @ptrCast(@alignCast(s))),
                        },
                    };
                }
            },
            else => break,
        }
        break;
    }
    return Value.init_nil();
}
pub fn splice_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_LINKED_LIST,
        .count = 1,
    })) and (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    }))) {
        runtimeError("First argument must be an array, linked list or vector.", .{});
        return Value.init_nil();
    }
    if (!((args[1].type == .VAL_INT) or (args[1].is_double())) or !((args[2].type == .VAL_INT) or (args[2].type == .VAL_DOUBLE))) {
        runtimeError("Second and third arguments must be numbers.", .{});
        return Value.init_nil();
    }
    while (true) {
        switch (args[0].as.obj.*.type) {
            .OBJ_FVECTOR => {
                {
                    var f: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &f;
                    var start: c_int = if (args[1].is_double()) @intFromFloat(args[1].as_num_double()) else args[1].as.num_int;
                    _ = &start;
                    var end: c_int = if (args[2].type == .VAL_DOUBLE) @intFromFloat(args[2].as.num_double) else args[2].as.num_int;
                    _ = &end;
                    var s: [*c]FloatVector = fvec.spliceFloatVector(f, start, end);
                    _ = &s;
                    return Value{
                        .type = .VAL_OBJ,
                        .as = .{
                            .obj = @as([*c]Obj, @ptrCast(@alignCast(s))),
                        },
                    };
                }
            },
            .OBJ_LINKED_LIST => {
                {
                    var l: [*c]ObjLinkedList = @as([*c]ObjLinkedList, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &l;
                    var start: c_int = if (args[1].is_double()) @intFromFloat(args[1].as_num_double()) else args[1].as.num_int;
                    _ = &start;
                    var end: c_int = if (args[2].type == .VAL_DOUBLE) @intFromFloat(args[2].as.num_double) else args[2].as.num_int;
                    _ = &end;
                    var s: [*c]ObjLinkedList = obj_h.spliceLinkedList(l, start, end);
                    _ = &s;
                    return Value{
                        .type = .VAL_OBJ,
                        .as = .{
                            .obj = @as([*c]Obj, @ptrCast(@alignCast(s))),
                        },
                    };
                }
            },
            else => break,
        }
        break;
    }
    return Value.init_nil();
}
pub fn push_nf(argCount: c_int, args: [*c]Value) Value {
    if (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_LINKED_LIST,
        .count = 1,
    }) and notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    })) {
        runtimeError("First argument must be a list type.", .{});
        return Value.init_nil();
    }
    switch (args[0].as.obj.*.type) {
        .OBJ_FVECTOR => {
            const f: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
            for (1..@intCast(argCount)) |i| {
                if (args[i].type == .VAL_DOUBLE) {
                    pushFloatVector(f, args[i].as.num_double);
                } else if (args[i].type == .VAL_INT) {
                    pushFloatVector(f, @floatFromInt(args[i].as.num_int));
                } else {
                    runtimeError("All elements of the vector must be numbers.", .{});
                    return Value.init_nil();
                }
            }

            return Value.init_nil();
        },
        .OBJ_LINKED_LIST => {
            const l: [*c]ObjLinkedList = @as([*c]ObjLinkedList, @ptrCast(@alignCast(args[0].as.obj)));

            var i: c_int = 1;
            while (i < argCount) : (i += 1) {
                obj_h.pushBack(l, (blk: {
                    const tmp = i;
                    if (tmp >= 0) break :blk args + @as(usize, @intCast(tmp)) else break :blk args - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                }).*);
            }

            return Value.init_nil();
        },
        else => {
            runtimeError("Argument must be a linked list, array or float vector.", .{});
            return Value{
                .type = .VAL_NIL,
                .as = .{
                    .num_int = 0,
                },
            };
        },
    }
}
pub fn pop_nf(argCount: c_int, args: [*c]Value) Value {
    if (argCount != 1) {
        runtimeError("pop() takes 1 argument.", .{});
        return Value.init_nil();
    }
    if ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_LINKED_LIST,
        .count = 1,
    })) and (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    }))) {
        runtimeError("First argument must be a list type.", .{});
        return Value.init_nil();
    }
    while (true) {
        switch (args[0].as.obj.*.type) {
            .OBJ_FVECTOR => {
                {
                    var f: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &f;
                    return Value{
                        .type = .VAL_DOUBLE,
                        .as = .{
                            .num_double = fvec.popFloatVector(f),
                        },
                    };
                }
            },
            .OBJ_LINKED_LIST => {
                {
                    var l: [*c]ObjLinkedList = @as([*c]ObjLinkedList, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &l;
                    return obj_h.popBack(l);
                }
            },
            else => {
                runtimeError("Argument must be a linked list, array or float vector.", .{});
                return Value.init_nil();
            },
        }
        break;
    }
    return Value.init_nil();
}
pub fn nth_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    if ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_HASH_TABLE,
        .count = 1,
    })) and ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_LINKED_LIST,
        .count = 1,
    })) and (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    }))) and (isObjType(args[0], .OBJ_HASH_TABLE))) {
        runtimeError("First argument must be an array, matrix, linked list or Vector.", .{});
        return Value.init_nil();
    }
    if (!((args[1].type == .VAL_INT) or (args[1].is_double()))) {
        runtimeError("Second argument must be a number.", .{});
        return Value.init_nil();
    }
    while (true) {
        switch (args[0].as.obj.*.type) {
            .OBJ_FVECTOR => {
                {
                    var f: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &f;
                    var index_1: c_int = if (args[1].is_double()) @intFromFloat(args[1].as_num_double()) else args[1].as.num_int;
                    _ = &index_1;
                    var value: f64 = fvec.getFloatVector(f, index_1);
                    _ = &value;
                    return Value{
                        .type = .VAL_DOUBLE,
                        .as = .{
                            .num_double = value,
                        },
                    };
                }
            },

            .OBJ_LINKED_LIST => {
                {
                    var l: [*c]ObjLinkedList = @as([*c]ObjLinkedList, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &l;
                    var index_1: c_int = if (args[1].is_double()) @intFromFloat(args[1].as_num_double()) else args[1].as.num_int;
                    _ = &index_1;
                    if ((index_1 >= 0) and (index_1 < l.*.count)) {
                        var node: [*c]Node = l.*.head;
                        _ = &node;
                        {
                            var i: c_int = 0;
                            _ = &i;
                            while (i < index_1) : (i += 1) {
                                node = node.*.next;
                            }
                        }
                        return node.*.data;
                    }
                    break;
                }
            },
            else => {
                {
                    runtimeError("Invalid argument types or index out of bounds.", .{});
                    return Value.init_nil();
                }
            },
        }
        break;
    }
    return Value.init_nil();
}
pub fn sort_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_LINKED_LIST,
        .count = 1,
    }) and (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    }))) {
        runtimeError("First argument must be a list type.", .{});
        return Value.init_nil();
    }
    while (true) {
        switch (args[0].as.obj.*.type) {
            .OBJ_FVECTOR => {
                {
                    var f: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &f;
                    fvec.FloatVector.sort(f);
                    return Value.init_nil();
                }
            },
            .OBJ_LINKED_LIST => {
                {
                    var l: [*c]ObjLinkedList = @as([*c]ObjLinkedList, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &l;
                    obj_h.mergeSort(l);
                    return Value.init_nil();
                }
            },
            else => {
                runtimeError("Argument must be a linked list, array or float vector.", .{});
                return Value.init_nil();
            },
        }
        break;
    }
    return Value.init_nil();
}
pub fn contains_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_LINKED_LIST,
        .count = 1,
    })) and (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    })) and !isObjType(args[0], .OBJ_HASH_TABLE)) {
        runtimeError("First argument must be a collection type.", .{});
        return Value.init_nil();
    }
    while (true) {
        switch (args[0].as.obj.*.type) {
            .OBJ_FVECTOR => {
                //TODO: Implement contains for float vector
                return Value.init_bool(false);
            },
            .OBJ_HASH_TABLE => {
                {
                    var h: [*c]ObjHashTable = @as([*c]ObjHashTable, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &h;
                    if (!valuesEqual(obj_h.getHashTable(h, @as([*c]ObjString, @ptrCast(@alignCast(args[1].as.obj)))), Value.init_nil())) {
                        return Value.init_bool(false);
                    }
                }
                {
                    var l: [*c]ObjLinkedList = @as([*c]ObjLinkedList, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &l;
                    var current: [*c]Node = l.*.head;
                    _ = &current;
                    while (current != @as([*c]Node, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(0)))))) {
                        if (valuesEqual(current.*.data, args[1])) {
                            return Value{
                                .type = .VAL_BOOL,
                                .as = .{
                                    .boolean = true,
                                },
                            };
                        }
                        current = current.*.next;
                    }
                    return Value.init_bool(false);
                }
            },
            .OBJ_LINKED_LIST => {
                {
                    var l: [*c]ObjLinkedList = @as([*c]ObjLinkedList, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &l;
                    var current: [*c]Node = l.*.head;
                    _ = &current;
                    while (current != @as([*c]Node, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(0)))))) {
                        if (valuesEqual(current.*.data, args[1])) {
                            return Value{
                                .type = .VAL_BOOL,
                                .as = .{
                                    .boolean = true,
                                },
                            };
                        }
                        current = current.*.next;
                    }
                    return Value.init_bool(false);
                }
            },
            else => {
                {
                    runtimeError("Invalid argument type.", .{});
                    return Value.init_nil();
                }
            },
        }
        break;
    }
    return Value.init_nil();
}
pub fn insert_nf(argCount: c_int, args: [*c]Value) Value {
    if (argCount != @as(c_int, 3)) {
        runtimeError("insert() takes 3 arguments.", .{});
        return Value.init_nil();
    }
    if (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    })) {
        runtimeError("First argument must be an array or vector.", .{});
        return Value.init_nil();
    }
    if (!((args[1].type == .VAL_INT) or (args[1].is_double()))) {
        runtimeError("Second argument must be a number.", .{});
        return Value.init_nil();
    }
    while (true) {
        switch (args[0].as.obj.*.type) {
            .OBJ_FVECTOR => {
                {
                    var f: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &f;
                    var index_1: c_int = if (args[1].is_double()) @intFromFloat(args[1].as_num_double()) else args[1].as.num_int;
                    _ = &index_1;
                    if (!((args[2].type == .VAL_INT) or (args[2].type == .VAL_DOUBLE))) {
                        runtimeError("Third argument must be a number.", .{});
                        return Value{
                            .type = .VAL_NIL,
                            .as = .{
                                .num_int = 0,
                            },
                        };
                    }
                    fvec.insertFloatVector(f, index_1, if (args[2].type == .VAL_INT) @floatFromInt(args[2].as.num_int) else args[2].as.num_double);
                    return Value.init_nil();
                }
            },
            else => {
                runtimeError("Invalid argument type.", .{});
                return Value.init_nil();
            },
        }
        break;
    }
    return Value.init_nil();
}
pub fn len_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_HASH_TABLE,
        .count = 1,
    })) and ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_LINKED_LIST,
        .count = 1,
    })) and (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    })))) {
        runtimeError("First argument must be a collection type.", .{});
        return Value.init_nil();
    }
    while (true) {
        switch (args[0].as.obj.*.type) {
            .OBJ_HASH_TABLE => {
                {
                    var h: [*c]ObjHashTable = @as([*c]ObjHashTable, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &h;
                    return Value{
                        .type = .VAL_INT,
                        .as = .{
                            .num_int = h.*.table.count,
                        },
                    };
                }
            },
            .OBJ_FVECTOR => {
                {
                    var f: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &f;
                    return Value{
                        .type = .VAL_INT,
                        .as = .{
                            .num_int = f.*.count,
                        },
                    };
                }
            },
            .OBJ_LINKED_LIST => {
                {
                    var l: [*c]ObjLinkedList = @as([*c]ObjLinkedList, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &l;
                    return Value{
                        .type = .VAL_INT,
                        .as = .{
                            .num_int = l.*.count,
                        },
                    };
                }
            },
            else => break,
        }
        break;
    }
    return Value.init_nil();
}
pub fn search_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_LINKED_LIST,
        .count = 1,
    }) and (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    })))) {
        runtimeError("First argument must be a list type.", .{});
        return Value.init_nil();
    }
    while (true) {
        switch (args[0].as.obj.*.type) {
            .OBJ_FVECTOR => {
                {
                    var f: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &f;
                    var result: c_int = fvec.searchFloatVector(f, if (args[1].type == .VAL_INT) @floatFromInt(args[1].as.num_int) else args[1].as_num_double());
                    _ = &result;
                    if (result == -1) return Value.init_nil();
                    return Value{
                        .type = .VAL_INT,
                        .as = .{
                            .num_int = result,
                        },
                    };
                }
            },
            .OBJ_LINKED_LIST => {
                {
                    var l: [*c]ObjLinkedList = @as([*c]ObjLinkedList, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &l;
                    var result: c_int = obj_h.searchLinkedList(l, args[1]);
                    _ = &result;
                    if (result == -1) return Value.init_nil();
                    return Value{
                        .type = .VAL_INT,
                        .as = .{
                            .num_int = result,
                        },
                    };
                }
            },
            else => break,
        }
        break;
    }
    return Value.init_nil();
}
pub fn is_empty_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_HASH_TABLE,
        .count = 1,
    })) and ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_LINKED_LIST,
        .count = 1,
    })) and (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    })))) {
        runtimeError("First argument must be a collection type.", .{});
        return Value.init_nil();
    }
    while (true) {
        switch (args[0].as.obj.*.type) {
            .OBJ_HASH_TABLE => {
                {
                    var h: [*c]ObjHashTable = @as([*c]ObjHashTable, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &h;
                    return Value{
                        .type = .VAL_BOOL,
                        .as = .{
                            .boolean = h.*.table.count == 0,
                        },
                    };
                }
            },
            .OBJ_FVECTOR => {
                {
                    var f: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &f;
                    return Value{
                        .type = .VAL_BOOL,
                        .as = .{
                            .boolean = f.*.count == 0,
                        },
                    };
                }
            },
            .OBJ_LINKED_LIST => {
                {
                    var l: [*c]ObjLinkedList = @as([*c]ObjLinkedList, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &l;
                    return Value{
                        .type = .VAL_BOOL,
                        .as = .{
                            .boolean = l.*.count == 0,
                        },
                    };
                }
            },
            else => {
                {
                    runtimeError("Unsupported type for is_empty().", .{});
                    return Value.init_nil();
                }
            },
        }
        break;
    }
    return Value.init_nil();
}
pub fn equal_list_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;
    if (!isObjType(args[0], .OBJ_LINKED_LIST)) {
        runtimeError("First argument must be an array, linked list or vector.", .{});
        return Value.init_nil();
    }
    while (true) {
        switch (args[0].as.obj.*.type) {
            .OBJ_FVECTOR => {
                {
                    if (!isObjType(args[1], .OBJ_FVECTOR)) {
                        runtimeError("Second argument must be a vector.", .{});
                        return Value{
                            .type = .VAL_NIL,
                            .as = .{
                                .num_int = 0,
                            },
                        };
                    }
                    var a: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &a;
                    var b: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[1].as.obj)));
                    _ = &b;
                    return Value{
                        .type = .VAL_BOOL,
                        .as = .{
                            .boolean = fvec.equalFloatVector(a, b),
                        },
                    };
                }
            },
            .OBJ_LINKED_LIST => {
                {
                    if (!isObjType(args[1], .OBJ_LINKED_LIST)) {
                        runtimeError("Second argument must be a linked list.", .{});
                        return Value{
                            .type = .VAL_NIL,
                            .as = .{
                                .num_int = 0,
                            },
                        };
                    }
                    var a: [*c]ObjLinkedList = @as([*c]ObjLinkedList, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &a;
                    var b: [*c]ObjLinkedList = @as([*c]ObjLinkedList, @ptrCast(@alignCast(args[1].as.obj)));
                    _ = &b;
                    return Value{
                        .type = .VAL_BOOL,
                        .as = .{
                            .boolean = obj_h.equalLinkedList(a, b),
                        },
                    };
                }
            },
            else => {
                {
                    runtimeError("Argument must be a linked list, array or float vector.", .{});
                    return Value.init_nil();
                }
            },
        }
        break;
    }
    return Value.init_nil();
}
pub fn reverse_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_LINKED_LIST,
        .count = 1,
    })) and (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    }))) {
        runtimeError("First argument must be a list type.", .{});
        return Value.init_nil();
    }
    while (true) {
        switch (args[0].as.obj.*.type) {
            .OBJ_FVECTOR => {
                {
                    var f: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &f;
                    fvec.reverseFloatVector(f);
                    return Value.init_nil();
                }
            },
            .OBJ_LINKED_LIST => {
                {
                    var l: [*c]ObjLinkedList = @as([*c]ObjLinkedList, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &l;
                    obj_h.reverseLinkedList(l);
                    return Value.init_nil();
                }
            },
            else => break,
        }
        break;
    }
    return Value.init_nil();
}
pub fn merge_nf(argCount: c_int, args: [*c]Value) Value {
    if (argCount != @as(c_int, 2)) {
        runtimeError("merge() takes 2 arguments.", .{});
        return Value.init_nil();
    }
    if ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_LINKED_LIST,
        .count = @as(c_int, 2),
    })) and (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = @as(c_int, 2),
    }))) {
        runtimeError("Both arguments must be the same list type.", .{});
        return Value.init_nil();
    }
    while (true) {
        switch (args[0].as.obj.*.type) {
            .OBJ_LINKED_LIST => {
                {
                    var a: [*c]ObjLinkedList = @as([*c]ObjLinkedList, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &a;
                    var b: [*c]ObjLinkedList = @as([*c]ObjLinkedList, @ptrCast(@alignCast(args[1].as.obj)));
                    _ = &b;
                    var c: [*c]ObjLinkedList = obj_h.mergeLinkedList(a, b);
                    _ = &c;
                    return Value{
                        .type = .VAL_OBJ,
                        .as = .{
                            .obj = @as([*c]Obj, @ptrCast(@alignCast(c))),
                        },
                    };
                }
            },
            .OBJ_FVECTOR => {
                {
                    var a: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &a;
                    var b: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[1].as.obj)));
                    _ = &b;
                    var c: [*c]FloatVector = fvec.mergeFloatVector(a, b);
                    _ = &c;
                    return Value{
                        .type = .VAL_OBJ,
                        .as = .{
                            .obj = @as([*c]Obj, @ptrCast(@alignCast(c))),
                        },
                    };
                }
            },
            else => return Value{
                .type = .VAL_NIL,
                .as = .{
                    .num_int = 0,
                },
            },
        }
        break;
    }
    return Value.init_nil();
}
pub fn clone_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_HASH_TABLE,
        .count = 1,
    })) and ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_LINKED_LIST,
        .count = 1,
    })) and (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    })))) {
        runtimeError("First argument must be an array, linked list or vector.", .{});
        return Value.init_nil();
    }
    while (true) {
        switch (args[0].as.obj.*.type) {
            .OBJ_FVECTOR => {
                {
                    var f: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &f;
                    var c: [*c]FloatVector = fvec.cloneFloatVector(f);
                    _ = &c;
                    return Value{
                        .type = .VAL_OBJ,
                        .as = .{
                            .obj = @as([*c]Obj, @ptrCast(@alignCast(c))),
                        },
                    };
                }
            },
            .OBJ_LINKED_LIST => {
                {
                    var l: [*c]ObjLinkedList = @as([*c]ObjLinkedList, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &l;
                    var c: [*c]ObjLinkedList = obj_h.cloneLinkedList(l);
                    _ = &c;
                    return Value{
                        .type = .VAL_OBJ,
                        .as = .{
                            .obj = @as([*c]Obj, @ptrCast(@alignCast(c))),
                        },
                    };
                }
            },
            .OBJ_HASH_TABLE => {
                {
                    var h: [*c]ObjHashTable = @as([*c]ObjHashTable, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &h;
                    var c: [*c]ObjHashTable = obj_h.cloneHashTable(h);
                    _ = &c;
                    return Value{
                        .type = .VAL_OBJ,
                        .as = .{
                            .obj = @as([*c]Obj, @ptrCast(@alignCast(c))),
                        },
                    };
                }
            },
            else => {
                runtimeError("Unsupported type for clone().", .{});
                return Value.init_nil();
            },
        }
        break;
    }
    return Value.init_nil();
}
pub fn clear_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;
    if ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_HASH_TABLE,
        .count = 1,
    }) and (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_LINKED_LIST,
        .count = 1,
    })) and (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    })))) {
        runtimeError("First argument must be an array, linked list, hash table or vector.", .{});
        return Value.init_nil();
    }

    switch (args[0].as.obj.*.type) {
        .OBJ_FVECTOR => {
            fvec.clearFloatVector(@as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj))));
        },
        .OBJ_LINKED_LIST => {
            obj_h.clearLinkedList(@as([*c]ObjLinkedList, @ptrCast(@alignCast(args[0].as.obj))));
        },
        .OBJ_HASH_TABLE => {
            obj_h.clearHashTable(@as([*c]ObjHashTable, @ptrCast(@alignCast(args[0].as.obj))));
        },
        else => {
            runtimeError("Unsupported type for clear().", .{});
        },
    }

    return Value.init_nil();
}
pub fn sum_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    }))) {
        runtimeError("First argument must be an array or vector.", .{});
        return Value.init_nil();
    }
    while (true) {
        switch (args[0].as.obj.*.type) {
            .OBJ_FVECTOR => {
                {
                    var f: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &f;
                    return Value{
                        .type = .VAL_DOUBLE,
                        .as = .{
                            .num_double = fvec.sumFloatVector(f),
                        },
                    };
                }
            },
            else => {
                runtimeError("Unsupported type for clear().", .{});
                return Value.init_nil();
            },
        }
        break;
    }
    return Value.init_nil();
}
pub fn mean_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    }))) {
        runtimeError("First argument must be an array or vector.", .{});
        return Value.init_nil();
    }

    switch (args[0].as.obj.*.type) {
        .OBJ_FVECTOR => return Value.init_double(fvec.meanFloatVector(@ptrCast(@alignCast(args[0].as.obj)))),
        else => {
            runtimeError("Unsupported type for mean().", .{});
            return Value.init_nil();
        },
    }

    return Value.init_nil();
}
pub fn std_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    }))) {
        runtimeError("First argument must be an array or vector.", .{});
        return Value.init_nil();
    }
    while (true) {
        switch (args[0].as.obj.*.type) {
            .OBJ_FVECTOR => return Value{
                .type = .VAL_DOUBLE,
                .as = .{
                    .num_double = fvec.stdDevFloatVector(@as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj)))),
                },
            },
            else => {
                runtimeError("Unsupported type for clear().", .{});
                return Value.init_nil();
            },
        }
        break;
    }
    return Value.init_nil();
}
pub fn var_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    }))) {
        runtimeError("First argument must be an array or vector.", .{});
        return Value.init_nil();
    }
    while (true) {
        switch (args[0].as.obj.*.type) {
            .OBJ_FVECTOR => {
                {
                    var f: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &f;
                    return Value{
                        .type = .VAL_DOUBLE,
                        .as = .{
                            .num_double = fvec.varianceFloatVector(f),
                        },
                    };
                }
            },
            else => {
                runtimeError("Unsupported type for clear().", .{});
                return Value.init_nil();
            },
        }
        break;
    }
    return Value.init_nil();
}
pub fn maxl_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    }))) {
        runtimeError("First argument must be an array or vector.", .{});
        return Value.init_nil();
    }
    while (true) {
        switch (args[0].as.obj.*.type) {
            .OBJ_FVECTOR => {
                {
                    var f: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &f;
                    return Value{
                        .type = .VAL_DOUBLE,
                        .as = .{
                            .num_double = fvec.maxFloatVector(f),
                        },
                    };
                }
            },
            else => {
                runtimeError("Unsupported type for clear().", .{});
                return Value.init_nil();
            },
        }
        break;
    }
    return Value.init_nil();
}
pub fn minl_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    }))) {
        runtimeError("First argument must be an array or vector.", .{});
        return Value.init_nil();
    }
    while (true) {
        switch (args[0].as.obj.*.type) {
            .OBJ_FVECTOR => {
                {
                    var f: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &f;
                    return Value{
                        .type = .VAL_DOUBLE,
                        .as = .{
                            .num_double = fvec.minFloatVector(f),
                        },
                    };
                }
            },
            else => {
                runtimeError("Unsupported type for clear().", .{});
                return Value.init_nil();
            },
        }
        break;
    }
    return Value.init_nil();
}
pub fn dot_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if (!isObjType(args[0], .OBJ_FVECTOR) and !isObjType(args[1], .OBJ_FVECTOR)) {
        runtimeError("Both arguments must be vectors.", .{});
        return Value.init_nil();
    }
    var a: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
    _ = &a;
    var b: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[1].as.obj)));
    _ = &b;
    var result: f64 = fvec.dotProduct(a, b);
    _ = &result;
    return Value{
        .type = .VAL_DOUBLE,
        .as = .{
            .num_double = result,
        },
    };
}
pub fn cross_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if (!isObjType(args[0], .OBJ_FVECTOR) and !isObjType(args[1], .OBJ_FVECTOR)) {
        runtimeError("Both arguments must be vectors.", .{});
        return Value.init_nil();
    }
    var a: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
    _ = &a;
    var b: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[1].as.obj)));
    _ = &b;
    var result: [*c]FloatVector = fvec.crossProduct(a, b);
    _ = &result;
    return Value{
        .type = .VAL_OBJ,
        .as = .{
            .obj = @as([*c]Obj, @ptrCast(@alignCast(result))),
        },
    };
}
pub fn norm_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if (!isObjType(args[0], .OBJ_FVECTOR)) {
        runtimeError("First argument must be a vector.", .{});
        return Value.init_nil();
    }
    var a: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
    _ = &a;
    var result: [*c]FloatVector = fvec.normalize(a);
    _ = &result;
    return Value{
        .type = .VAL_OBJ,
        .as = .{
            .obj = @as([*c]Obj, @ptrCast(@alignCast(result))),
        },
    };
}
pub fn proj_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if (!isObjType(args[0], .OBJ_FVECTOR) and !isObjType(args[1], .OBJ_FVECTOR)) {
        runtimeError("Both arguments must be vectors.", .{});
        return Value.init_nil();
    }
    var a: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
    _ = &a;
    var b: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[1].as.obj)));
    _ = &b;
    var result: [*c]FloatVector = fvec.projection(a, b);
    _ = &result;
    return Value{
        .type = .VAL_OBJ,
        .as = .{
            .obj = @as([*c]Obj, @ptrCast(@alignCast(result))),
        },
    };
}
pub fn reject_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if (!isObjType(args[0], .OBJ_FVECTOR) and !isObjType(args[1], .OBJ_FVECTOR)) {
        runtimeError("Both arguments must be vectors.", .{});
        return Value.init_nil();
    }
    var a: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
    _ = &a;
    var b: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[1].as.obj)));
    _ = &b;
    var result: [*c]FloatVector = fvec.rejection(a, b);
    _ = &result;
    return Value{
        .type = .VAL_OBJ,
        .as = .{
            .obj = @as([*c]Obj, @ptrCast(@alignCast(result))),
        },
    };
}
pub fn reflect_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if (!isObjType(args[0], .OBJ_FVECTOR) and !isObjType(args[1], .OBJ_FVECTOR)) {
        runtimeError("Both arguments must be vectors.", .{});
        return Value.init_nil();
    }
    var a: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
    _ = &a;
    var b: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[1].as.obj)));
    _ = &b;
    var result: [*c]FloatVector = fvec.reflection(a, b);
    _ = &result;
    return Value{
        .type = .VAL_OBJ,
        .as = .{
            .obj = @as([*c]Obj, @ptrCast(@alignCast(result))),
        },
    };
}
pub fn refract_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if (((!isObjType(args[0], .OBJ_FVECTOR) and !isObjType(args[1], .OBJ_FVECTOR)) and !((args[2].type == .VAL_INT) or (args[2].type == .VAL_DOUBLE))) and !((args[@as(c_uint, @intCast(@as(c_int, 3)))].type == .VAL_INT) or (args[@as(c_uint, @intCast(@as(c_int, 3)))].type == .VAL_DOUBLE))) {
        runtimeError("First and second arguments must be vectors and the third and fourth arguments must be numbers.", .{});
        return Value.init_nil();
    }
    var a: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
    _ = &a;
    var b: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[1].as.obj)));
    _ = &b;
    var n1: f64 = if (args[2].type == .VAL_INT) @floatFromInt(args[2].as.num_int) else args[2].as.num_double;
    _ = &n1;
    var n2: f64 = if (args[@as(c_uint, @intCast(@as(c_int, 3)))].type == .VAL_INT) @floatFromInt(args[@as(c_uint, @intCast(@as(c_int, 3)))].as.num_int) else args[@as(c_uint, @intCast(@as(c_int, 3)))].as.num_double;
    _ = &n2;
    var result: [*c]FloatVector = fvec.refraction(a, b, n1, n2);
    _ = &result;
    return Value{
        .type = .VAL_OBJ,
        .as = .{
            .obj = @as([*c]Obj, @ptrCast(@alignCast(result))),
        },
    };
}
pub fn angle_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if (!isObjType(args[0], .OBJ_FVECTOR) or !isObjType(args[1], .OBJ_FVECTOR)) {
        runtimeError("Both arguments must be vectors.", .{});
        return Value.init_nil();
    }
    var a: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
    _ = &a;
    var b: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[1].as.obj)));
    _ = &b;
    var result: f64 = fvec.angle(a, b);
    _ = &result;
    return Value{
        .type = .VAL_DOUBLE,
        .as = .{
            .num_double = result,
        },
    };
}
pub fn put_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if (argCount != @as(c_int, 3)) {
        runtimeError("put() takes 3 arguments.", .{});
        return Value.init_nil();
    }
    if (!isObjType(args[0], .OBJ_HASH_TABLE)) {
        runtimeError("First argument must be a hash table.", .{});
        return Value.init_nil();
    }
    if (!isObjType(args[1], .OBJ_STRING)) {
        runtimeError("Second argument must be a string.", .{});
        return Value.init_nil();
    }
    var h: [*c]ObjHashTable = @as([*c]ObjHashTable, @ptrCast(@alignCast(args[0].as.obj)));
    _ = &h;
    var key: [*c]ObjString = @as([*c]ObjString, @ptrCast(@alignCast(args[1].as.obj)));
    _ = &key;
    return Value{
        .type = .VAL_BOOL,
        .as = .{
            .boolean = obj_h.putHashTable(h, key, args[2]),
        },
    };
}
pub fn get_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if (argCount != @as(c_int, 2)) {
        runtimeError("get() takes 2 arguments.", .{});
        return Value.init_nil();
    }
    if (!isObjType(args[0], .OBJ_HASH_TABLE)) {
        runtimeError("First argument must be a hash table.", .{});
        return Value.init_nil();
    }
    if (!isObjType(args[1], .OBJ_STRING)) {
        runtimeError("Second argument must be a string.", .{});
        return Value.init_nil();
    }
    var h: [*c]ObjHashTable = @as([*c]ObjHashTable, @ptrCast(@alignCast(args[0].as.obj)));
    _ = &h;
    var key: [*c]ObjString = @as([*c]ObjString, @ptrCast(@alignCast(args[1].as.obj)));
    _ = &key;
    return obj_h.getHashTable(h, key);
}
pub fn remove_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if (argCount != @as(c_int, 2)) {
        runtimeError("remove() takes 2 arguments.", .{});
        return Value.init_nil();
    }
    if (!isObjType(args[0], .OBJ_HASH_TABLE) and (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    }))) {
        runtimeError("First argument must be a hash table, array, or float vector.", .{});
        return Value.init_nil();
    }
    if (!isObjType(args[1], .OBJ_STRING) and !((args[1].type == .VAL_INT) or (args[1].is_double()))) {
        runtimeError("Second argument must be a string or number.", .{});
        return Value.init_nil();
    }
    while (true) {
        switch (args[0].as.obj.*.type) {
            .OBJ_HASH_TABLE => {
                {
                    var h: [*c]ObjHashTable = @as([*c]ObjHashTable, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &h;
                    var key: [*c]ObjString = @as([*c]ObjString, @ptrCast(@alignCast(args[1].as.obj)));
                    _ = &key;
                    return Value{
                        .type = .VAL_BOOL,
                        .as = .{
                            .boolean = obj_h.removeHashTable(h, key),
                        },
                    };
                }
            },
            .OBJ_FVECTOR => {
                {
                    return Value{
                        .type = .VAL_DOUBLE,
                        .as = .{
                            .num_double = fvec.removeFloatVector(@as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj))), if (args[1].is_double()) @intFromFloat(args[1].as_num_double()) else args[1].as.num_int),
                        },
                    };
                }
            },
            else => {
                {
                    runtimeError("Argument must be a hash table, array or float vector.", .{});
                    return Value.init_nil();
                }
            },
        }
        break;
    }
    return Value.init_nil();
}
pub fn push_front_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if (!isObjType(args[0], .OBJ_LINKED_LIST)) {
        runtimeError("First argument must be a linked list.", .{});
        return Value.init_nil();
    }
    var l: [*c]ObjLinkedList = @as([*c]ObjLinkedList, @ptrCast(@alignCast(args[0].as.obj)));
    _ = &l;
    {
        var i: c_int = 1;
        _ = &i;
        while (i < argCount) : (i += 1) {
            obj_h.pushFront(l, (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk args + @as(usize, @intCast(tmp)) else break :blk args - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*);
        }
    }
    return Value.init_nil();
}
pub fn pop_front_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if (!isObjType(args[0], .OBJ_LINKED_LIST)) {
        runtimeError("First argument must be a linked list.", .{});
        return Value.init_nil();
    }
    var l: [*c]ObjLinkedList = @as([*c]ObjLinkedList, @ptrCast(@alignCast(args[0].as.obj)));
    _ = &l;
    return obj_h.popFront(l);
}

pub fn workspace_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if (argCount != 0) {
        runtimeError("workspace() takes no arguments.", .{});
        return Value.init_nil();
    }
    var e: [*c]Entry = entries_(&vm_h.vm.globals);
    _ = &e;
    _ = printf("Workspace:\n");
    {
        var i: c_int = 0;
        _ = &i;
        while (i < vm_h.vm.globals.capacity) : (i += 1) {
            if (((blk: {
                const tmp = i;
                if (tmp >= 0) break :blk e + @as(usize, @intCast(tmp)) else break :blk e - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*.key != @as([*c]ObjString, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(0)))))) and !isObjType((blk: {
                const tmp = i;
                if (tmp >= 0) break :blk e + @as(usize, @intCast(tmp)) else break :blk e - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*.value, .OBJ_NATIVE)) {
                _ = printf("%s: ", (blk: {
                    const tmp = i;
                    if (tmp >= 0) break :blk e + @as(usize, @intCast(tmp)) else break :blk e - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                }).*.key.*.chars);
                value_h.printValue((blk: {
                    const tmp = i;
                    if (tmp >= 0) break :blk e + @as(usize, @intCast(tmp)) else break :blk e - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                }).*.value);
                _ = printf("\n");
            }
        }
    }
    return Value.init_nil();
}
pub fn linspace_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if (argCount != @as(c_int, 3)) {
        runtimeError("linspace() takes 3 arguments.", .{});
        return Value.init_nil();
    }
    if ((!((args[0].type == .VAL_INT) or (args[0].is_double())) and !((args[1].type == .VAL_INT) or (args[1].is_double()))) and !((args[2].type == .VAL_INT) or (args[2].type == .VAL_DOUBLE))) {
        runtimeError("First and second arguments must be numbers and the third argument must be an numbers.", .{});
        return Value.init_nil();
    }
    var start: f64 = if (args[0].type == .VAL_INT) @floatFromInt(args[0].as.num_int) else args[0].as_num_double();
    _ = &start;
    var end: f64 = if (args[1].type == .VAL_INT) @floatFromInt(args[1].as.num_int) else args[1].as_num_double();
    _ = &end;
    var n: c_int = if (args[2].type == .VAL_DOUBLE) @intFromFloat(args[2].as.num_double) else args[2].as.num_int;
    _ = &n;
    var a: [*c]FloatVector = fvec.linspace(start, end, n);
    _ = &a;
    return Value{
        .type = .VAL_OBJ,
        .as = .{
            .obj = @as([*c]Obj, @ptrCast(@alignCast(a))),
        },
    };
}
pub fn interp1_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if (argCount != @as(c_int, 3)) {
        runtimeError("interp1() takes 3 arguments.", .{});
        return Value.init_nil();
    }
    if ((!isObjType(args[0], .OBJ_FVECTOR) and !isObjType(args[1], .OBJ_FVECTOR)) and !((args[2].type == .VAL_INT) or (args[2].type == .VAL_DOUBLE))) {
        runtimeError("First and second arguments must be vectors and the third argument must be a number.", .{});
        return Value.init_nil();
    }
    var x: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
    _ = &x;
    var y: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[1].as.obj)));
    _ = &y;
    var x0: f64 = if (args[2].type == .VAL_INT) @floatFromInt(args[2].as.num_int) else args[2].as.num_double;
    _ = &x0;
    var result: f64 = fvec.interp1(x, y, x0);
    _ = &result;
    return Value{
        .type = .VAL_DOUBLE,
        .as = .{
            .num_double = result,
        },
    };
}
pub fn simd_stat_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if (argCount != 0) {
        runtimeError("simd_stat() takes 0 arguments.", .{});
    }
    _ = printf("x86_64 SIMD AVX2 Enabled\n");
    return Value.init_nil();
}
