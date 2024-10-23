const value_h = @import("value.zig");
const obj_h = @import("object.zig");
const table_h = @import("table.zig");
const conv = @import("conv.zig");
const nil = Value.init_nil;
const Entry = table_h.Entry;
const entries_ = table_h.entries_;
const Value = value_h.Value;
const vm_h = @import("vm.zig");
const runtimeError = vm_h.runtimeError;
const valuesEqual = value_h.valuesEqual;
const valueToString = value_h.valueToString;
const isObjType = obj_h.isObjType;
const notObjTypes = obj_h.notObjTypes;
const ObjArray = obj_h.ObjArray;
const ObjString = obj_h.ObjString;
const ObjLinkedList = obj_h.ObjLinkedList;
const FloatVector = obj_h.FloatVector;
const ObjHashTable = obj_h.ObjHashTable;
const ObjMatrix = obj_h.ObjMatrix;
const Obj = obj_h.Obj;
const Node = obj_h.Node;
const ObjTypeCheckParams = obj_h.ObjTypeCheckParams;
const printf = @cImport(@cInclude("stdio.h")).printf;

pub export fn assert_nf(argCount: c_int, args: [*c]Value) Value {
    if (argCount != @as(c_int, 2)) {
        runtimeError("assert() takes 1 argument.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    if (valuesEqual(args[0], args[1])) {
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    } else {
        runtimeError("Assertion failed {s} != {s}", .{ valueToString(args[0]), valueToString(args[1]) });
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    return Value.init_nil();
}
pub fn iter_nf(argCount: c_int, args: [*c]Value) Value {
    _ = argCount;
    _ = args;
    return Value{
        .type = .VAL_NIL,
        .as = .{
            .num_int = 0,
        },
    };
}
pub export fn next_nf(argCount: c_int, args: [*c]Value) Value {
    if (argCount != 1) {
        runtimeError("next() takes 1 argument.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    if (!isObjType(args[0], .OBJ_ARRAY) and !isObjType(args[0], .OBJ_FVECTOR)) {
        runtimeError("Argument must be an iterable.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    var next: Value = Value{
        .type = .VAL_NIL,
        .as = .{
            .num_int = 0,
        },
    };
    _ = &next;
    if (isObjType(args[0], .OBJ_ARRAY)) {
        next = obj_h.nextObjectArray(@as([*c]ObjArray, @ptrCast(@alignCast(args[0].as.obj))));
    } else if (isObjType(args[0], .OBJ_FVECTOR)) {
        next = Value{
            .type = .VAL_DOUBLE,
            .as = .{
                .num_double = obj_h.nextFloatVector(@as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj)))),
            },
        };
    }
    return next;
}
pub export fn hasNext_nf(argCount: c_int, args: [*c]Value) Value {
    if (argCount != 1) {
        runtimeError("has_next() takes 1 argument.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    if (!isObjType(args[0], .OBJ_ARRAY) and !isObjType(args[0], .OBJ_FVECTOR)) {
        runtimeError("Argument must be an iterable.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    var hasNext: bool = 0 != 0;
    _ = &hasNext;
    if (isObjType(args[0], .OBJ_ARRAY)) {
        hasNext = obj_h.hasNextObjectArray(@as([*c]ObjArray, @ptrCast(@alignCast(args[0].as.obj))));
    } else if (isObjType(args[0], .OBJ_FVECTOR)) {
        hasNext = obj_h.hasNextFloatVector(@as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj))));
    }
    return Value{
        .type = .VAL_BOOL,
        .as = .{
            .boolean = hasNext,
        },
    };
}
pub export fn peek_nf(argCount: c_int, args: [*c]Value) Value {
    if (argCount != @as(c_int, 2)) {
        runtimeError("peek() takes 2 argument.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    if (!isObjType(args[0], .OBJ_ARRAY) and !isObjType(args[0], .OBJ_FVECTOR)) {
        runtimeError("Argument must be an iterable.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    if (!((args[1].type == .VAL_INT) or (args[1].type == .VAL_DOUBLE))) {
        runtimeError("Second argument must be a number.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    var pos: c_int = if (args[1].type == .VAL_DOUBLE) @intFromFloat(args[1].as.num_double) else args[1].as.num_int;
    _ = &pos;
    var peek: Value = Value{
        .type = .VAL_NIL,
        .as = .{
            .num_int = 0,
        },
    };
    _ = &peek;
    if (isObjType(args[0], .OBJ_ARRAY)) {
        peek = obj_h.peekObjectArray(@as([*c]ObjArray, @ptrCast(@alignCast(args[0].as.obj))), pos);
    } else if (isObjType(args[0], .OBJ_FVECTOR)) {
        peek = Value{
            .type = .VAL_DOUBLE,
            .as = .{
                .num_double = obj_h.peekFloatVector(@as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj))), pos),
            },
        };
    }
    return peek;
}
pub export fn reset_nf(argCount: c_int, args: [*c]Value) Value {
    if (argCount != 1) {
        runtimeError("reset() takes 1 argument.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    if (!isObjType(args[0], .OBJ_ARRAY) and !isObjType(args[0], .OBJ_FVECTOR)) {
        runtimeError("Argument must be an iterable.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    if (isObjType(args[0], .OBJ_ARRAY)) {
        obj_h.resetObjectArray(@as([*c]ObjArray, @ptrCast(@alignCast(args[0].as.obj))));
    } else if (isObjType(args[0], .OBJ_FVECTOR)) {
        obj_h.resetFloatVector(@as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj))));
    }
    return Value{
        .type = .VAL_NIL,
        .as = .{
            .num_int = 0,
        },
    };
}
pub export fn skip_nf(argCount: c_int, args: [*c]Value) Value {
    if (argCount != @as(c_int, 2)) {
        runtimeError("skip() takes 2 arguments.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    if (!isObjType(args[0], .OBJ_ARRAY) and !isObjType(args[0], .OBJ_FVECTOR)) {
        runtimeError("Argument must be an iterable.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    if (!((args[1].type == .VAL_INT) or (args[1].type == .VAL_DOUBLE))) {
        runtimeError("Second argument must be a number.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    var skip: c_int = if (args[1].type == .VAL_DOUBLE) @intFromFloat(args[1].as.num_double) else args[1].as.num_int;
    _ = &skip;
    if (isObjType(args[0], .OBJ_ARRAY)) {
        obj_h.skipObjectArray(@as([*c]ObjArray, @ptrCast(@alignCast(args[0].as.obj))), skip);
    } else if (isObjType(args[0], .OBJ_FVECTOR)) {
        obj_h.skipFloatVector(@as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj))), skip);
    }
    return Value{
        .type = .VAL_NIL,
        .as = .{
            .num_int = 0,
        },
    };
}
pub export fn array_nf(argCount: c_int, args: [*c]Value) Value {
    if (argCount == 0) {
        var a: [*c]ObjArray = obj_h.newArray();
        _ = &a;
        return Value{
            .type = .VAL_OBJ,
            .as = .{
                .obj = @as([*c]Obj, @ptrCast(@alignCast(a))),
            },
        };
    } else if ((argCount == 1) and isObjType(args[0], .OBJ_FVECTOR)) {
        var f: [*c]FloatVector = @ptrCast(@alignCast(args[0].as.obj));
        _ = &f;
        var a: [*c]ObjArray = obj_h.newArrayWithCap(f.*.size, 1 != 0);
        _ = &a;
        {
            var i: c_int = 0;
            _ = &i;
            while (i < f.*.count) : (i += 1) {
                obj_h.pushArray(a, Value{
                    .type = .VAL_DOUBLE,
                    .as = .{
                        .num_double = (blk: {
                            const tmp = i;
                            if (tmp >= 0) break :blk f.*.data + @as(usize, @intCast(tmp)) else break :blk f.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                        }).*,
                    },
                });
            }
        }
        return Value{
            .type = .VAL_OBJ,
            .as = .{
                .obj = @as([*c]Obj, @ptrCast(@alignCast(a))),
            },
        };
    } else if (argCount >= 1) {
        if (!((args[0].type == .VAL_INT) or (args[0].type == .VAL_DOUBLE))) {
            runtimeError("First argument must be a number when creating an array with a specified capacity.", .{});
            return Value{
                .type = .VAL_NIL,
                .as = .{
                    .num_int = 0,
                },
            };
        }
        if ((argCount == @as(c_int, 2)) and !(args[1].type == .VAL_BOOL)) {
            runtimeError("Second argument must be a bool", .{});
            return Value{
                .type = .VAL_NIL,
                .as = .{
                    .num_int = 0,
                },
            };
        }
        var a: [*c]ObjArray = obj_h.newArrayWithCap(if (args[0].type == .VAL_DOUBLE) @intFromFloat(args[0].as.num_double) else args[0].as.num_int, args[1].as.boolean);
        _ = &a;
        return Value{
            .type = .VAL_OBJ,
            .as = .{
                .obj = @as([*c]Obj, @ptrCast(@alignCast(a))),
            },
        };
    } else {
        runtimeError("array() takes 0 or 1 argument.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    return Value.init_nil();
}
pub export fn linkedlist_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &args;
    if (argCount != 0) {
        runtimeError("linked_list() takes no arguments.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
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
pub export fn hashtable_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &args;
    if (argCount != 0) {
        runtimeError("hash_table() takes no arguments.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
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
pub export fn matrix_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;
    if (!((args[0].type == .VAL_INT) or (args[0].type == .VAL_DOUBLE)) or !((args[1].type == .VAL_INT) or (args[1].type == .VAL_DOUBLE))) {
        runtimeError("Both arguments must be numbers.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    var rows: c_int = if (args[0].type == .VAL_DOUBLE) @intFromFloat(args[0].as.num_double) else args[0].as.num_int;
    _ = &rows;
    var cols: c_int = if (args[1].type == .VAL_DOUBLE) @intFromFloat(args[1].as.num_double) else args[1].as.num_int;
    _ = &cols;
    var m: [*c]ObjMatrix = obj_h.newMatrix(rows, cols);
    _ = &m;
    return Value{
        .type = .VAL_OBJ,
        .as = .{
            .obj = @as([*c]Obj, @ptrCast(@alignCast(m))),
        },
    };
}
pub export fn fvector_nf(argCount: c_int, args: [*c]Value) Value {
    if (argCount != 1) {
        runtimeError("fvec() takes 1 argument.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    if (!((args[0].type == .VAL_INT) or (args[0].type == .VAL_DOUBLE)) and !isObjType(args[0], .OBJ_ARRAY)) {
        runtimeError("First argument must be an numbers or an array.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    if (isObjType(args[0], .OBJ_ARRAY)) {
        var a: [*c]ObjArray = @as([*c]ObjArray, @ptrCast(@alignCast(args[0].as.obj)));
        _ = &a;
        var f: [*c]FloatVector = obj_h.newFloatVector(a.*.capacity);
        _ = &f;
        {
            var i: usize = 0;
            _ = &i;
            while (i < a.*.count) : (i += 1) {
                if (!(((blk: {
                    const tmp = i;
                    if (tmp >= 0) break :blk a.*.values + @as(usize, @intCast(tmp)) else break :blk a.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                }).*.type == .VAL_INT) or ((blk: {
                    const tmp = i;
                    if (tmp >= 0) break :blk a.*.values + @as(usize, @intCast(tmp)) else break :blk a.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                }).*.type == .VAL_DOUBLE))) {
                    runtimeError("All elements of the vector must be numbers.", .{});
                    return Value{
                        .type = .VAL_NIL,
                        .as = .{
                            .num_int = 0,
                        },
                    };
                }
                obj_h.pushFloatVector(f, value_h.AS_NUM_DOUBLE(a.*.values[i]));
            }
        }
        return Value{
            .type = .VAL_OBJ,
            .as = .{
                .obj = @as([*c]Obj, @ptrCast(@alignCast(f))),
            },
        };
    } else {
        var n: c_int = if (args[0].type == .VAL_DOUBLE) @intFromFloat(args[0].as.num_double) else args[0].as.num_int;
        _ = &n;
        var f: [*c]FloatVector = obj_h.newFloatVector(n);
        _ = &f;
        return Value{
            .type = .VAL_OBJ,
            .as = .{
                .obj = @as([*c]Obj, @ptrCast(@alignCast(f))),
            },
        };
    }
    return Value.init_nil();
}
pub export fn range_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;
    if (!((args[0].type == .VAL_INT) or (args[0].type == .VAL_DOUBLE)) and !((args[1].type == .VAL_INT) or (args[1].type == .VAL_DOUBLE))) {
        runtimeError("Both arguments must be numbers.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    var start: c_int = if (args[0].type == .VAL_DOUBLE) @intFromFloat(args[0].as.num_double) else args[0].as.num_int;
    _ = &start;
    var end: c_int = if (args[1].type == .VAL_DOUBLE) @intFromFloat(args[1].as.num_double) else args[1].as.num_int;
    _ = &end;
    var a: [*c]ObjArray = obj_h.newArrayWithCap(end - start, 1 != 0);
    _ = &a;
    {
        var i: c_int = start;
        _ = &i;
        while (i < end) : (i += 1) {
            obj_h.pushArray(a, Value{
                .type = .VAL_INT,
                .as = .{
                    .num_int = i,
                },
            });
        }
    }
    return Value{
        .type = .VAL_OBJ,
        .as = .{
            .obj = @as([*c]Obj, @ptrCast(@alignCast(a))),
        },
    };
}
pub export fn slice_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_LINKED_LIST,
        .count = 1,
    })) and ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_ARRAY,
        .count = 1,
    })) and (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    })))) {
        runtimeError("First argument must be an array, linked list or vector.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    if (!((args[0].type == .VAL_INT) or (args[0].type == .VAL_DOUBLE)) and !((args[1].type == .VAL_INT) or (args[1].type == .VAL_DOUBLE))) {
        runtimeError("Second and third arguments must be numbers.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    while (true) {
        switch (args[0].as.obj.*.type) {
            .OBJ_ARRAY => {
                {
                    var a: [*c]ObjArray = @as([*c]ObjArray, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &a;
                    var start: c_int = if (args[1].type == .VAL_DOUBLE) @intFromFloat(args[1].as.num_double) else args[1].as.num_int;
                    _ = &start;
                    var end: c_int = if (args[2].type == .VAL_DOUBLE) @intFromFloat(args[2].as.num_double) else args[2].as.num_int;
                    _ = &end;
                    var s: [*c]ObjArray = obj_h.sliceArray(a, start, end);
                    _ = &s;
                    return Value{
                        .type = .VAL_OBJ,
                        .as = .{
                            .obj = @as([*c]Obj, @ptrCast(@alignCast(s))),
                        },
                    };
                }
            },
            .OBJ_FVECTOR => {
                {
                    var f: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &f;
                    var start: c_int = if (args[1].type == .VAL_DOUBLE) @intFromFloat(args[1].as.num_double) else args[1].as.num_int;
                    _ = &start;
                    var end: c_int = if (args[2].type == .VAL_DOUBLE) @intFromFloat(args[2].as.num_double) else args[2].as.num_int;
                    _ = &end;
                    var s: [*c]FloatVector = obj_h.sliceFloatVector(f, start, end);
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
                    var start: c_int = if (args[1].type == .VAL_DOUBLE) @intFromFloat(args[1].as.num_double) else args[1].as.num_int;
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
pub export fn splice_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_LINKED_LIST,
        .count = 1,
    })) and ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_ARRAY,
        .count = 1,
    })) and (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    })))) {
        runtimeError("First argument must be an array, linked list or vector.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    if (!((args[1].type == .VAL_INT) or (args[1].type == .VAL_DOUBLE)) or !((args[2].type == .VAL_INT) or (args[2].type == .VAL_DOUBLE))) {
        runtimeError("Second and third arguments must be numbers.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    while (true) {
        switch (args[0].as.obj.*.type) {
            .OBJ_ARRAY => {
                {
                    var a: [*c]ObjArray = @as([*c]ObjArray, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &a;
                    var start: c_int = if (args[1].type == .VAL_DOUBLE) @intFromFloat(args[1].as.num_double) else args[1].as.num_int;
                    _ = &start;
                    var end: c_int = if (args[2].type == .VAL_DOUBLE) @intFromFloat(args[2].as.num_double) else args[2].as.num_int;
                    _ = &end;
                    var s: [*c]ObjArray = obj_h.spliceArray(a, start, end);
                    _ = &s;
                    return Value{
                        .type = .VAL_OBJ,
                        .as = .{
                            .obj = @as([*c]Obj, @ptrCast(@alignCast(s))),
                        },
                    };
                }
            },
            .OBJ_FVECTOR => {
                {
                    var f: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &f;
                    var start: c_int = if (args[1].type == .VAL_DOUBLE) @intFromFloat(args[1].as.num_double) else args[1].as.num_int;
                    _ = &start;
                    var end: c_int = if (args[2].type == .VAL_DOUBLE) @intFromFloat(args[2].as.num_double) else args[2].as.num_int;
                    _ = &end;
                    var s: [*c]FloatVector = obj_h.spliceFloatVector(f, start, end);
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
                    var start: c_int = if (args[1].type == .VAL_DOUBLE) @intFromFloat(args[1].as.num_double) else args[1].as.num_int;
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
pub export fn push_nf(argCount: c_int, args: [*c]Value) Value {
    if (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_LINKED_LIST,
        .count = 1,
    }) and notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_ARRAY,
        .count = 1,
    }) and notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    })) {
        runtimeError("First argument must be a list type.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    switch (args[0].as.obj.*.type) {
        .OBJ_ARRAY => {
            {
                const a: [*c]ObjArray = @as([*c]ObjArray, @ptrCast(@alignCast(args[0].as.obj)));
                for (0..@intCast(argCount)) |i| {
                    obj_h.pushArray(a, args[i]);
                }
                return Value{
                    .type = .VAL_NIL,
                    .as = .{
                        .num_int = 0,
                    },
                };
            }
        },
        .OBJ_FVECTOR => {
            {
                const f: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
                for (0..@intCast(argCount)) |i| {
                    if (args[i].type == .VAL_DOUBLE) {
                        obj_h.pushFloatVector(f, args[i].as.num_double);
                    } else if (args[i].type == .VAL_INT) {
                        obj_h.pushFloatVector(f, @floatFromInt(args[i].as.num_int));
                    } else {
                        runtimeError("All elements of the vector must be numbers.", .{});
                        return Value{
                            .type = .VAL_NIL,
                            .as = .{
                                .num_int = 0,
                            },
                        };
                    }
                }
            }
            return Value{
                .type = .VAL_NIL,
                .as = .{
                    .num_int = 0,
                },
            };
        },
        .OBJ_LINKED_LIST => {
            {
                var l: [*c]ObjLinkedList = @as([*c]ObjLinkedList, @ptrCast(@alignCast(args[0].as.obj)));
                _ = &l;
                {
                    var i: c_int = 1;
                    _ = &i;
                    while (i < argCount) : (i += 1) {
                        obj_h.pushBack(l, (blk: {
                            const tmp = i;
                            if (tmp >= 0) break :blk args + @as(usize, @intCast(tmp)) else break :blk args - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                        }).*);
                    }
                }
                return Value{
                    .type = .VAL_NIL,
                    .as = .{
                        .num_int = 0,
                    },
                };
            }
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
pub export fn pop_nf(argCount: c_int, args: [*c]Value) Value {
    if (argCount != 1) {
        runtimeError("pop() takes 1 argument.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    if ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_LINKED_LIST,
        .count = 1,
    })) and ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_ARRAY,
        .count = 1,
    })) and (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    })))) {
        runtimeError("First argument must be a list type.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    while (true) {
        switch (args[0].as.obj.*.type) {
            .OBJ_ARRAY => {
                {
                    var a: [*c]ObjArray = @as([*c]ObjArray, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &a;
                    return obj_h.popArray(a);
                }
            },
            .OBJ_FVECTOR => {
                {
                    var f: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &f;
                    return Value{
                        .type = .VAL_DOUBLE,
                        .as = .{
                            .num_double = obj_h.popFloatVector(f),
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
                return Value{
                    .type = .VAL_NIL,
                    .as = .{
                        .num_int = 0,
                    },
                };
            },
        }
        break;
    }
    return Value.init_nil();
}
pub export fn nth_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    if ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_HASH_TABLE,
        .count = 1,
    })) and (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_MATRIX,
        .count = 1,
    })) and ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_LINKED_LIST,
        .count = 1,
    })) and ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_ARRAY,
        .count = 1,
    })) and (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    })))) and (isObjType(args[0], .OBJ_HASH_TABLE))) {
        runtimeError("First argument must be an array, matrix, linked list or Vector.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    if (!((args[1].type == .VAL_INT) or (args[1].type == .VAL_DOUBLE))) {
        runtimeError("Second argument must be a number.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    while (true) {
        switch (args[0].as.obj.*.type) {
            .OBJ_MATRIX => {
                {
                    if ((argCount == @as(c_int, 3)) and ((args[2].type == .VAL_INT) or (args[2].type == .VAL_DOUBLE))) {
                        var m: [*c]ObjMatrix = @as([*c]ObjMatrix, @ptrCast(@alignCast(args[0].as.obj)));
                        _ = &m;
                        var row: c_int = if (args[1].type == .VAL_DOUBLE) @intFromFloat(args[1].as.num_double) else args[1].as.num_int;
                        _ = &row;
                        var col: c_int = if (args[2].type == .VAL_DOUBLE) @intFromFloat(args[2].as.num_double) else args[2].as.num_int;
                        _ = &col;
                        return obj_h.getMatrix(m, row, col);
                    }
                    break;
                }
            },
            .OBJ_FVECTOR => {
                {
                    var f: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &f;
                    var index_1: c_int = if (args[1].type == .VAL_DOUBLE) @intFromFloat(args[1].as.num_double) else args[1].as.num_int;
                    _ = &index_1;
                    var value: f64 = obj_h.getFloatVector(f, index_1);
                    _ = &value;
                    return Value{
                        .type = .VAL_DOUBLE,
                        .as = .{
                            .num_double = value,
                        },
                    };
                }
            },
            .OBJ_ARRAY => {
                {
                    var a: [*c]ObjArray = @as([*c]ObjArray, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &a;
                    var index_1: c_int = if (args[1].type == .VAL_DOUBLE) @intFromFloat(args[1].as.num_double) else args[1].as.num_int;
                    _ = &index_1;
                    if ((index_1 >= 0) and (index_1 < a.*.count)) {
                        return (blk: {
                            const tmp = index_1;
                            if (tmp >= 0) break :blk a.*.values + @as(usize, @intCast(tmp)) else break :blk a.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                        }).*;
                    }
                    break;
                }
            },
            .OBJ_LINKED_LIST => {
                {
                    var l: [*c]ObjLinkedList = @as([*c]ObjLinkedList, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &l;
                    var index_1: c_int = if (args[1].type == .VAL_DOUBLE) @intFromFloat(args[1].as.num_double) else args[1].as.num_int;
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
                    return Value{
                        .type = .VAL_NIL,
                        .as = .{
                            .num_int = 0,
                        },
                    };
                }
            },
        }
        break;
    }
    return Value.init_nil();
}
pub export fn sort_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_LINKED_LIST,
        .count = 1,
    }) and ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_ARRAY,
        .count = 1,
    })) and (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    })))) {
        runtimeError("First argument must be a list type.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    while (true) {
        switch (args[0].as.obj.*.type) {
            .OBJ_ARRAY => {
                {
                    var a: [*c]ObjArray = @as([*c]ObjArray, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &a;
                    obj_h.sortArray(a);
                    return Value{
                        .type = .VAL_NIL,
                        .as = .{
                            .num_int = 0,
                        },
                    };
                }
            },
            .OBJ_FVECTOR => {
                {
                    var f: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &f;
                    obj_h.sortFloatVector(f);
                    return Value{
                        .type = .VAL_NIL,
                        .as = .{
                            .num_int = 0,
                        },
                    };
                }
            },
            .OBJ_LINKED_LIST => {
                {
                    var l: [*c]ObjLinkedList = @as([*c]ObjLinkedList, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &l;
                    obj_h.mergeSort(l);
                    return Value{
                        .type = .VAL_NIL,
                        .as = .{
                            .num_int = 0,
                        },
                    };
                }
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
        break;
    }
    return Value.init_nil();
}
pub export fn contains_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_LINKED_LIST,
        .count = 1,
    })) and ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_ARRAY,
        .count = 1,
    })) and (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    }))) and !isObjType(args[0], .OBJ_HASH_TABLE)) {
        runtimeError("First argument must be a collection type.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    while (true) {
        switch (args[0].as.obj.*.type) {
            .OBJ_ARRAY => {
                {
                    var a: [*c]ObjArray = @as([*c]ObjArray, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &a;
                    {
                        var i: c_int = 0;
                        _ = &i;
                        while (i < a.*.count) : (i += 1) {
                            if (valuesEqual((blk: {
                                const tmp = i;
                                if (tmp >= 0) break :blk a.*.values + @as(usize, @intCast(tmp)) else break :blk a.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                            }).*, args[1])) {
                                return Value{
                                    .type = .VAL_BOOL,
                                    .as = .{
                                        .boolean = 1 != 0,
                                    },
                                };
                            }
                        }
                    }
                    return Value{
                        .type = .VAL_BOOL,
                        .as = .{
                            .boolean = 0 != 0,
                        },
                    };
                }
            },
            .OBJ_FVECTOR => {
                //TODO: Implement contains for float vector
                return Value{
                    .type = .VAL_BOOL,
                    .as = .{
                        .boolean = 0 != 0,
                    },
                };
            },
            .OBJ_HASH_TABLE => {
                {
                    var h: [*c]ObjHashTable = @as([*c]ObjHashTable, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &h;
                    if (!valuesEqual(obj_h.getHashTable(h, @as([*c]ObjString, @ptrCast(@alignCast(args[1].as.obj)))), Value{
                        .type = .VAL_NIL,
                        .as = .{
                            .num_int = 0,
                        },
                    })) {
                        return Value{
                            .type = .VAL_BOOL,
                            .as = .{
                                .boolean = 1 != 0,
                            },
                        };
                    } else {
                        return Value{
                            .type = .VAL_BOOL,
                            .as = .{
                                .boolean = 0 != 0,
                            },
                        };
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
                                    .boolean = 1 != 0,
                                },
                            };
                        }
                        current = current.*.next;
                    }
                    return Value{
                        .type = .VAL_BOOL,
                        .as = .{
                            .boolean = 0 != 0,
                        },
                    };
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
                                    .boolean = 1 != 0,
                                },
                            };
                        }
                        current = current.*.next;
                    }
                    return Value{
                        .type = .VAL_BOOL,
                        .as = .{
                            .boolean = 0 != 0,
                        },
                    };
                }
            },
            else => {
                {
                    runtimeError("Invalid argument type.", .{});
                    return Value{
                        .type = .VAL_NIL,
                        .as = .{
                            .num_int = 0,
                        },
                    };
                }
            },
        }
        break;
    }
    return Value.init_nil();
}
pub export fn insert_nf(argCount: c_int, args: [*c]Value) Value {
    if (argCount != @as(c_int, 3)) {
        runtimeError("insert() takes 3 arguments.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    if ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_ARRAY,
        .count = 1,
    })) and (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    }))) {
        runtimeError("First argument must be an array or vector.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    if (!((args[1].type == .VAL_INT) or (args[1].type == .VAL_DOUBLE))) {
        runtimeError("Second argument must be a number.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    while (true) {
        switch (args[0].as.obj.*.type) {
            .OBJ_FVECTOR => {
                {
                    var f: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &f;
                    var index_1: c_int = if (args[1].type == .VAL_DOUBLE) @intFromFloat(args[1].as.num_double) else args[1].as.num_int;
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
                    obj_h.insertFloatVector(f, index_1, if (args[2].type == .VAL_INT) @floatFromInt(args[2].as.num_int) else args[2].as.num_double);
                    return Value{
                        .type = .VAL_NIL,
                        .as = .{
                            .num_int = 0,
                        },
                    };
                }
            },
            .OBJ_ARRAY => {
                {
                    var a: [*c]ObjArray = @as([*c]ObjArray, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &a;
                    var index_1: c_int = if (args[1].type == .VAL_DOUBLE) @intFromFloat(args[1].as.num_double) else args[1].as.num_int;
                    _ = &index_1;
                    obj_h.insertArray(a, index_1, args[2]);
                    return Value{
                        .type = .VAL_NIL,
                        .as = .{
                            .num_int = 0,
                        },
                    };
                }
            },
            else => {
                runtimeError("Invalid argument type.", .{});
                return Value{
                    .type = .VAL_NIL,
                    .as = .{
                        .num_int = 0,
                    },
                };
            },
        }
        break;
    }
    return Value.init_nil();
}
pub export fn len_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_HASH_TABLE,
        .count = 1,
    })) and (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_MATRIX,
        .count = 1,
    })) and ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_LINKED_LIST,
        .count = 1,
    })) and ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_ARRAY,
        .count = 1,
    })) and (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    }))))) {
        runtimeError("First argument must be a collection type.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    while (true) {
        switch (args[0].as.obj.*.type) {
            .OBJ_ARRAY => {
                {
                    var a: [*c]ObjArray = @as([*c]ObjArray, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &a;
                    return Value{
                        .type = .VAL_INT,
                        .as = .{
                            .num_int = a.*.count,
                        },
                    };
                }
            },
            .OBJ_MATRIX => {
                {
                    var m: [*c]ObjMatrix = @as([*c]ObjMatrix, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &m;
                    return Value{
                        .type = .VAL_INT,
                        .as = .{
                            .num_int = m.*.rows * m.*.cols,
                        },
                    };
                }
            },
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
pub export fn search_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_LINKED_LIST,
        .count = 1,
    }) and ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_ARRAY,
        .count = 1,
    })) and (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    }))))) {
        runtimeError("First argument must be a list type.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    while (true) {
        switch (args[0].as.obj.*.type) {
            .OBJ_ARRAY => {
                {
                    var a: [*c]ObjArray = @as([*c]ObjArray, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &a;
                    var result: c_int = obj_h.searchArray(a, args[1]);
                    _ = &result;
                    if (result == -1) return Value{
                        .type = .VAL_NIL,
                        .as = .{
                            .num_int = 0,
                        },
                    };
                    return Value{
                        .type = .VAL_INT,
                        .as = .{
                            .num_int = result,
                        },
                    };
                }
            },
            .OBJ_FVECTOR => {
                {
                    var f: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &f;
                    var result: c_int = obj_h.searchFloatVector(f, if (args[1].type == .VAL_INT) @floatFromInt(args[1].as.num_int) else args[1].as.num_double);
                    _ = &result;
                    if (result == -1) return Value{
                        .type = .VAL_NIL,
                        .as = .{
                            .num_int = 0,
                        },
                    };
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
                    if (result == -1) return Value{
                        .type = .VAL_NIL,
                        .as = .{
                            .num_int = 0,
                        },
                    };
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
pub export fn is_empty_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_HASH_TABLE,
        .count = 1,
    })) and (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_MATRIX,
        .count = 1,
    })) and ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_LINKED_LIST,
        .count = 1,
    })) and ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_ARRAY,
        .count = 1,
    })) and (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    }))))) {
        runtimeError("First argument must be a collection type.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    while (true) {
        switch (args[0].as.obj.*.type) {
            .OBJ_ARRAY => {
                {
                    var a: [*c]ObjArray = @as([*c]ObjArray, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &a;
                    return Value{
                        .type = .VAL_BOOL,
                        .as = .{
                            .boolean = a.*.count == 0,
                        },
                    };
                }
            },
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
                    return Value{
                        .type = .VAL_NIL,
                        .as = .{
                            .num_int = 0,
                        },
                    };
                }
            },
        }
        break;
    }
    return Value.init_nil();
}
pub export fn equal_list_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;
    if (!isObjType(args[0], .OBJ_ARRAY) and !isObjType(args[0], .OBJ_LINKED_LIST)) {
        runtimeError("First argument must be an array, linked list or vector.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    while (true) {
        switch (args[0].as.obj.*.type) {
            .OBJ_ARRAY => {
                {
                    if (!isObjType(args[1], .OBJ_ARRAY)) {
                        runtimeError("Second argument must be an array.", .{});
                        return Value{
                            .type = .VAL_NIL,
                            .as = .{
                                .num_int = 0,
                            },
                        };
                    }
                    var a: [*c]ObjArray = @as([*c]ObjArray, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &a;
                    var b: [*c]ObjArray = @as([*c]ObjArray, @ptrCast(@alignCast(args[1].as.obj)));
                    _ = &b;
                    return Value{
                        .type = .VAL_BOOL,
                        .as = .{
                            .boolean = obj_h.equalArray(a, b),
                        },
                    };
                }
            },
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
                            .boolean = obj_h.equalFloatVector(a, b),
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
                    return Value{
                        .type = .VAL_NIL,
                        .as = .{
                            .num_int = 0,
                        },
                    };
                }
            },
        }
        break;
    }
    return Value.init_nil();
}
pub export fn reverse_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_LINKED_LIST,
        .count = 1,
    })) and ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_ARRAY,
        .count = 1,
    })) and (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    })))) {
        runtimeError("First argument must be a list type.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    while (true) {
        switch (args[0].as.obj.*.type) {
            .OBJ_ARRAY => {
                {
                    var a: [*c]ObjArray = @as([*c]ObjArray, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &a;
                    obj_h.reverseArray(a);
                    return Value{
                        .type = .VAL_NIL,
                        .as = .{
                            .num_int = 0,
                        },
                    };
                }
            },
            .OBJ_FVECTOR => {
                {
                    var f: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &f;
                    obj_h.reverseFloatVector(f);
                    return Value{
                        .type = .VAL_NIL,
                        .as = .{
                            .num_int = 0,
                        },
                    };
                }
            },
            .OBJ_LINKED_LIST => {
                {
                    var l: [*c]ObjLinkedList = @as([*c]ObjLinkedList, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &l;
                    obj_h.reverseLinkedList(l);
                    return Value{
                        .type = .VAL_NIL,
                        .as = .{
                            .num_int = 0,
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
pub export fn merge_nf(argCount: c_int, args: [*c]Value) Value {
    if (argCount != @as(c_int, 2)) {
        runtimeError("merge() takes 2 arguments.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    if ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_LINKED_LIST,
        .count = @as(c_int, 2),
    })) and ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_ARRAY,
        .count = @as(c_int, 2),
    })) and (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = @as(c_int, 2),
    })))) {
        runtimeError("Both arguments must be the same list type.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    while (true) {
        switch (args[0].as.obj.*.type) {
            .OBJ_ARRAY => {
                {
                    var a: [*c]ObjArray = @as([*c]ObjArray, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &a;
                    var b: [*c]ObjArray = @as([*c]ObjArray, @ptrCast(@alignCast(args[1].as.obj)));
                    _ = &b;
                    var c: [*c]ObjArray = obj_h.mergeArrays(a, b);
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
                    var c: [*c]FloatVector = obj_h.mergeFloatVector(a, b);
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
pub export fn clone_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_HASH_TABLE,
        .count = 1,
    })) and (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_MATRIX,
        .count = 1,
    })) and ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_LINKED_LIST,
        .count = 1,
    })) and ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_ARRAY,
        .count = 1,
    })) and (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    }))))) {
        runtimeError("First argument must be an array, linked list or vector.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    while (true) {
        switch (args[0].as.obj.*.type) {
            .OBJ_ARRAY => {
                {
                    var a: [*c]ObjArray = @as([*c]ObjArray, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &a;
                    var c: [*c]ObjArray = obj_h.cloneArray(a);
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
                    var f: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &f;
                    var c: [*c]FloatVector = obj_h.cloneFloatVector(f);
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
                return Value{
                    .type = .VAL_NIL,
                    .as = .{
                        .num_int = 0,
                    },
                };
            },
        }
        break;
    }
    return Value.init_nil();
}
pub export fn clear_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_HASH_TABLE,
        .count = 1,
    }) and (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_MATRIX,
        .count = 1,
    })) and (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_LINKED_LIST,
        .count = 1,
    })) and ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_ARRAY,
        .count = 1,
    })) and (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    }))))) {
        runtimeError("First argument must be an array, linked list, hash table or vector.", .{});
        return nil();
    }

    switch (args[0].as.obj.*.type) {
        .OBJ_ARRAY => {
            obj_h.clearArray(@as([*c]ObjArray, @ptrCast(@alignCast(args[0].as.obj))));
        },
        .OBJ_FVECTOR => {
            obj_h.clearFloatVector(@as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj))));
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

    return nil();
}
pub export fn sum_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_ARRAY,
        .count = 1,
    })) and (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    }))) {
        runtimeError("First argument must be an array or vector.", .{});
        return nil();
    }
    while (true) {
        switch (args[0].as.obj.*.type) {
            .OBJ_ARRAY => {
                {
                    var a: [*c]ObjArray = @as([*c]ObjArray, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &a;
                    return obj_h.sumArray(a);
                }
            },
            .OBJ_FVECTOR => {
                {
                    var f: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &f;
                    return Value{
                        .type = .VAL_DOUBLE,
                        .as = .{
                            .num_double = obj_h.sumFloatVector(f),
                        },
                    };
                }
            },
            else => {
                runtimeError("Unsupported type for clear().", .{});
                return Value{
                    .type = .VAL_NIL,
                    .as = .{
                        .num_int = 0,
                    },
                };
            },
        }
        break;
    }
    return Value.init_nil();
}
pub export fn mean_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_ARRAY,
        .count = 1,
    })) and (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    }))) {
        runtimeError("First argument must be an array or vector.", .{});
        return nil();
    }

    switch (args[0].as.obj.*.type) {
        .OBJ_ARRAY => return obj_h.meanArray(@as([*c]ObjArray, @ptrCast(@alignCast(args[0].as.obj)))),
        .OBJ_FVECTOR => return Value.init_double(obj_h.meanFloatVector(@ptrCast(@alignCast(args[0].as.obj)))),
        else => {
            runtimeError("Unsupported type for mean().", .{});
            return nil();
        },
    }

    return nil();
}
pub export fn std_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_ARRAY,
        .count = 1,
    })) and (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    }))) {
        runtimeError("First argument must be an array or vector.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    while (true) {
        switch (args[0].as.obj.*.type) {
            .OBJ_ARRAY => return obj_h.stdDevArray(@as([*c]ObjArray, @ptrCast(@alignCast(args[0].as.obj)))),
            .OBJ_FVECTOR => return Value{
                .type = .VAL_DOUBLE,
                .as = .{
                    .num_double = obj_h.stdDevFloatVector(@as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj)))),
                },
            },
            else => {
                runtimeError("Unsupported type for clear().", .{});
                return Value{
                    .type = .VAL_NIL,
                    .as = .{
                        .num_int = 0,
                    },
                };
            },
        }
        break;
    }
    return Value.init_nil();
}
pub export fn var_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_ARRAY,
        .count = 1,
    })) and (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    }))) {
        runtimeError("First argument must be an array or vector.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    while (true) {
        switch (args[0].as.obj.*.type) {
            .OBJ_ARRAY => {
                {
                    var a: [*c]ObjArray = @as([*c]ObjArray, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &a;
                    return obj_h.varianceArray(a);
                }
            },
            .OBJ_FVECTOR => {
                {
                    var f: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &f;
                    return Value{
                        .type = .VAL_DOUBLE,
                        .as = .{
                            .num_double = obj_h.varianceFloatVector(f),
                        },
                    };
                }
            },
            else => {
                runtimeError("Unsupported type for clear().", .{});
                return Value{
                    .type = .VAL_NIL,
                    .as = .{
                        .num_int = 0,
                    },
                };
            },
        }
        break;
    }
    return Value.init_nil();
}
pub export fn maxl_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_ARRAY,
        .count = 1,
    })) and (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    }))) {
        runtimeError("First argument must be an array or vector.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    while (true) {
        switch (args[0].as.obj.*.type) {
            .OBJ_ARRAY => {
                {
                    var a: [*c]ObjArray = @as([*c]ObjArray, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &a;
                    return obj_h.maxArray(a);
                }
            },
            .OBJ_FVECTOR => {
                {
                    var f: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &f;
                    return Value{
                        .type = .VAL_DOUBLE,
                        .as = .{
                            .num_double = obj_h.maxFloatVector(f),
                        },
                    };
                }
            },
            else => {
                runtimeError("Unsupported type for clear().", .{});
                return Value{
                    .type = .VAL_NIL,
                    .as = .{
                        .num_int = 0,
                    },
                };
            },
        }
        break;
    }
    return Value.init_nil();
}
pub export fn minl_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_ARRAY,
        .count = 1,
    })) and (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    }))) {
        runtimeError("First argument must be an array or vector.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    while (true) {
        switch (args[0].as.obj.*.type) {
            .OBJ_ARRAY => {
                {
                    var a: [*c]ObjArray = @as([*c]ObjArray, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &a;
                    return obj_h.minArray(a);
                }
            },
            .OBJ_FVECTOR => {
                {
                    var f: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
                    _ = &f;
                    return Value{
                        .type = .VAL_DOUBLE,
                        .as = .{
                            .num_double = obj_h.minFloatVector(f),
                        },
                    };
                }
            },
            else => {
                runtimeError("Unsupported type for clear().", .{});
                return Value{
                    .type = .VAL_NIL,
                    .as = .{
                        .num_int = 0,
                    },
                };
            },
        }
        break;
    }
    return Value.init_nil();
}
pub export fn dot_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if (!isObjType(args[0], .OBJ_FVECTOR) and !isObjType(args[1], .OBJ_FVECTOR)) {
        runtimeError("Both arguments must be vectors.", .{});
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
    var result: f64 = obj_h.dotProduct(a, b);
    _ = &result;
    return Value{
        .type = .VAL_DOUBLE,
        .as = .{
            .num_double = result,
        },
    };
}
pub export fn cross_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if (!isObjType(args[0], .OBJ_FVECTOR) and !isObjType(args[1], .OBJ_FVECTOR)) {
        runtimeError("Both arguments must be vectors.", .{});
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
    var result: [*c]FloatVector = obj_h.crossProduct(a, b);
    _ = &result;
    return Value{
        .type = .VAL_OBJ,
        .as = .{
            .obj = @as([*c]Obj, @ptrCast(@alignCast(result))),
        },
    };
}
pub export fn norm_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if (!isObjType(args[0], .OBJ_FVECTOR)) {
        runtimeError("First argument must be a vector.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    var a: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
    _ = &a;
    var result: [*c]FloatVector = obj_h.normalize(a);
    _ = &result;
    return Value{
        .type = .VAL_OBJ,
        .as = .{
            .obj = @as([*c]Obj, @ptrCast(@alignCast(result))),
        },
    };
}
pub export fn proj_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if (!isObjType(args[0], .OBJ_FVECTOR) and !isObjType(args[1], .OBJ_FVECTOR)) {
        runtimeError("Both arguments must be vectors.", .{});
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
    var result: [*c]FloatVector = obj_h.projection(a, b);
    _ = &result;
    return Value{
        .type = .VAL_OBJ,
        .as = .{
            .obj = @as([*c]Obj, @ptrCast(@alignCast(result))),
        },
    };
}
pub export fn reject_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if (!isObjType(args[0], .OBJ_FVECTOR) and !isObjType(args[1], .OBJ_FVECTOR)) {
        runtimeError("Both arguments must be vectors.", .{});
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
    var result: [*c]FloatVector = obj_h.rejection(a, b);
    _ = &result;
    return Value{
        .type = .VAL_OBJ,
        .as = .{
            .obj = @as([*c]Obj, @ptrCast(@alignCast(result))),
        },
    };
}
pub export fn reflect_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if (!isObjType(args[0], .OBJ_FVECTOR) and !isObjType(args[1], .OBJ_FVECTOR)) {
        runtimeError("Both arguments must be vectors.", .{});
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
    var result: [*c]FloatVector = obj_h.reflection(a, b);
    _ = &result;
    return Value{
        .type = .VAL_OBJ,
        .as = .{
            .obj = @as([*c]Obj, @ptrCast(@alignCast(result))),
        },
    };
}
pub export fn refract_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if (((!isObjType(args[0], .OBJ_FVECTOR) and !isObjType(args[1], .OBJ_FVECTOR)) and !((args[2].type == .VAL_INT) or (args[2].type == .VAL_DOUBLE))) and !((args[@as(c_uint, @intCast(@as(c_int, 3)))].type == .VAL_INT) or (args[@as(c_uint, @intCast(@as(c_int, 3)))].type == .VAL_DOUBLE))) {
        runtimeError("First and second arguments must be vectors and the third and fourth arguments must be numbers.", .{});
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
    var n1: f64 = if (args[2].type == .VAL_INT) @floatFromInt(args[2].as.num_int) else args[2].as.num_double;
    _ = &n1;
    var n2: f64 = if (args[@as(c_uint, @intCast(@as(c_int, 3)))].type == .VAL_INT) @floatFromInt(args[@as(c_uint, @intCast(@as(c_int, 3)))].as.num_int) else args[@as(c_uint, @intCast(@as(c_int, 3)))].as.num_double;
    _ = &n2;
    var result: [*c]FloatVector = obj_h.refraction(a, b, n1, n2);
    _ = &result;
    return Value{
        .type = .VAL_OBJ,
        .as = .{
            .obj = @as([*c]Obj, @ptrCast(@alignCast(result))),
        },
    };
}
pub export fn angle_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if (!isObjType(args[0], .OBJ_FVECTOR) or !isObjType(args[1], .OBJ_FVECTOR)) {
        runtimeError("Both arguments must be vectors.", .{});
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
    var result: f64 = obj_h.angle(a, b);
    _ = &result;
    return Value{
        .type = .VAL_DOUBLE,
        .as = .{
            .num_double = result,
        },
    };
}
pub export fn put_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if (argCount != @as(c_int, 3)) {
        runtimeError("put() takes 3 arguments.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    if (!isObjType(args[0], .OBJ_HASH_TABLE)) {
        runtimeError("First argument must be a hash table.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    if (!isObjType(args[1], .OBJ_STRING)) {
        runtimeError("Second argument must be a string.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
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
pub export fn get_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if (argCount != @as(c_int, 2)) {
        runtimeError("get() takes 2 arguments.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    if (!isObjType(args[0], .OBJ_HASH_TABLE)) {
        runtimeError("First argument must be a hash table.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    if (!isObjType(args[1], .OBJ_STRING)) {
        runtimeError("Second argument must be a string.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    var h: [*c]ObjHashTable = @as([*c]ObjHashTable, @ptrCast(@alignCast(args[0].as.obj)));
    _ = &h;
    var key: [*c]ObjString = @as([*c]ObjString, @ptrCast(@alignCast(args[1].as.obj)));
    _ = &key;
    return obj_h.getHashTable(h, key);
}
pub export fn remove_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if (argCount != @as(c_int, 2)) {
        runtimeError("remove() takes 2 arguments.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    if (!isObjType(args[0], .OBJ_HASH_TABLE) and ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_ARRAY,
        .count = 1,
    })) and (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    })))) {
        runtimeError("First argument must be a hash table, array, or float vector.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    if (!isObjType(args[1], .OBJ_STRING) and !((args[1].type == .VAL_INT) or (args[1].type == .VAL_DOUBLE))) {
        runtimeError("Second argument must be a string or number.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
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
            .OBJ_ARRAY => {
                {
                    return obj_h.removeArray(@as([*c]ObjArray, @ptrCast(@alignCast(args[0].as.obj))), if (args[1].type == .VAL_DOUBLE) @intFromFloat(args[1].as.num_double) else args[1].as.num_int);
                }
            },
            .OBJ_FVECTOR => {
                {
                    return Value{
                        .type = .VAL_DOUBLE,
                        .as = .{
                            .num_double = obj_h.removeFloatVector(@as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj))), if (args[1].type == .VAL_DOUBLE) @intFromFloat(args[1].as.num_double) else args[1].as.num_int),
                        },
                    };
                }
            },
            else => {
                {
                    runtimeError("Argument must be a hash table, array or float vector.", .{});
                    return Value{
                        .type = .VAL_NIL,
                        .as = .{
                            .num_int = 0,
                        },
                    };
                }
            },
        }
        break;
    }
    return Value.init_nil();
}
pub export fn push_front_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if (!isObjType(args[0], .OBJ_LINKED_LIST)) {
        runtimeError("First argument must be a linked list.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
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
    return Value{
        .type = .VAL_NIL,
        .as = .{
            .num_int = 0,
        },
    };
}
pub export fn pop_front_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if (!isObjType(args[0], .OBJ_LINKED_LIST)) {
        runtimeError("First argument must be a linked list.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    var l: [*c]ObjLinkedList = @as([*c]ObjLinkedList, @ptrCast(@alignCast(args[0].as.obj)));
    _ = &l;
    return obj_h.popFront(l);
}
pub export fn set_row_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if (!isObjType(args[0], .OBJ_MATRIX)) {
        runtimeError("First argument must be a matrix.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    if (!((args[1].type == .VAL_INT) or (args[1].type == .VAL_DOUBLE))) {
        runtimeError("Second argument must be an numbers.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    if (!isObjType(args[2], .OBJ_ARRAY)) {
        runtimeError("Third argument must be an array.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    var matrix: [*c]ObjMatrix = @as([*c]ObjMatrix, @ptrCast(@alignCast(args[0].as.obj)));
    _ = &matrix;
    var row: c_int = if (args[1].type == .VAL_DOUBLE) @intFromFloat(args[1].as.num_double) else args[1].as.num_int;
    _ = &row;
    var array: [*c]ObjArray = @as([*c]ObjArray, @ptrCast(@alignCast(args[2].as.obj)));
    _ = &array;
    obj_h.setRow(matrix, row, array);
    return Value{
        .type = .VAL_NIL,
        .as = .{
            .num_int = 0,
        },
    };
}
pub export fn set_col_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if (!isObjType(args[0], .OBJ_MATRIX)) {
        runtimeError("First argument must be a matrix.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    if (!((args[1].type == .VAL_INT) or (args[1].type == .VAL_DOUBLE))) {
        runtimeError("Second argument must be an numbers.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    if (!isObjType(args[2], .OBJ_ARRAY)) {
        runtimeError("Third argument must be an array.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    var matrix: [*c]ObjMatrix = @as([*c]ObjMatrix, @ptrCast(@alignCast(args[0].as.obj)));
    _ = &matrix;
    var col: c_int = if (args[1].type == .VAL_DOUBLE) @intFromFloat(args[1].as.num_double) else args[1].as.num_int;
    _ = &col;
    var array: [*c]ObjArray = @as([*c]ObjArray, @ptrCast(@alignCast(args[2].as.obj)));
    _ = &array;
    obj_h.setCol(matrix, col, array);
    return Value{
        .type = .VAL_NIL,
        .as = .{
            .num_int = 0,
        },
    };
}

pub export fn set_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if (argCount != @as(c_int, 4)) {
        runtimeError("set() takes 4 arguments.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    if (!isObjType(args[0], .OBJ_MATRIX)) {
        runtimeError("First argument must be a matrix.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    if (!((args[1].type == .VAL_INT) or (args[1].type == .VAL_DOUBLE))) {
        runtimeError("Second argument must be an numbers.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    if (!((args[2].type == .VAL_INT) or (args[2].type == .VAL_DOUBLE))) {
        runtimeError("Third argument must be an numbers.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    var matrix: [*c]ObjMatrix = @as([*c]ObjMatrix, @ptrCast(@alignCast(args[0].as.obj)));
    _ = &matrix;
    var row: c_int = if (args[1].type == .VAL_DOUBLE) @intFromFloat(args[1].as.num_double) else args[1].as.num_int;
    _ = &row;
    var col: c_int = if (args[2].type == .VAL_DOUBLE) @intFromFloat(args[2].as.num_double) else args[2].as.num_int;
    _ = &col;
    obj_h.setMatrix(matrix, row, col, args[@as(c_uint, @intCast(@as(c_int, 3)))]);
    return Value{
        .type = .VAL_NIL,
        .as = .{
            .num_int = 0,
        },
    };
}
pub export fn kolasa_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if (argCount != 0) {
        runtimeError("kolasa() takes no arguments.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    var m: [*c]ObjMatrix = obj_h.newMatrix(@as(c_int, 3), @as(c_int, 3));
    _ = &m;
    {
        var i: c_int = 0;
        _ = &i;
        while (i < m.*.len) : (i += 1) {
            (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk m.*.data.*.values + @as(usize, @intCast(tmp)) else break :blk m.*.data.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).* = Value{
                .type = .VAL_DOUBLE,
                .as = .{
                    .num_double = @as(f64, @floatFromInt(i + 1)),
                },
            };
        }
    }
    return Value{
        .type = .VAL_OBJ,
        .as = .{
            .obj = @as([*c]Obj, @ptrCast(@alignCast(m))),
        },
    };
}
pub export fn rref_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if (!isObjType(args[0], .OBJ_MATRIX)) {
        runtimeError("First argument must be a matrix.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    var m: [*c]ObjMatrix = @as([*c]ObjMatrix, @ptrCast(@alignCast(args[0].as.obj)));
    _ = &m;
    obj_h.rref(m);
    return Value{
        .type = .VAL_NIL,
        .as = .{
            .num_int = 0,
        },
    };
}
pub export fn rank_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if (!isObjType(args[0], .OBJ_MATRIX)) {
        runtimeError("First argument must be a matrix.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    var m: [*c]ObjMatrix = @as([*c]ObjMatrix, @ptrCast(@alignCast(args[0].as.obj)));
    _ = &m;
    return Value{
        .type = .VAL_INT,
        .as = .{
            .num_int = obj_h.rank(m),
        },
    };
}
pub export fn transpose_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if (!isObjType(args[0], .OBJ_MATRIX)) {
        runtimeError("First argument must be a matrix.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    var m: [*c]ObjMatrix = @as([*c]ObjMatrix, @ptrCast(@alignCast(args[0].as.obj)));
    _ = &m;
    var t: [*c]ObjMatrix = obj_h.transposeMatrix(m);
    _ = &t;
    return Value{
        .type = .VAL_OBJ,
        .as = .{
            .obj = @as([*c]Obj, @ptrCast(@alignCast(t))),
        },
    };
}
pub export fn determinant_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if (!isObjType(args[0], .OBJ_MATRIX)) {
        runtimeError("First argument must be a matrix.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    var m: [*c]ObjMatrix = @as([*c]ObjMatrix, @ptrCast(@alignCast(args[0].as.obj)));
    _ = &m;
    return Value{
        .type = .VAL_DOUBLE,
        .as = .{
            .num_double = obj_h.determinant(m),
        },
    };
}
pub export fn lu_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if (!isObjType(args[0], .OBJ_MATRIX)) {
        runtimeError("First argument must be a matrix.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    var m: [*c]ObjMatrix = @as([*c]ObjMatrix, @ptrCast(@alignCast(args[0].as.obj)));
    _ = &m;
    var result: [*c]ObjMatrix = obj_h.lu(m);
    _ = &result;
    return Value{
        .type = .VAL_OBJ,
        .as = .{
            .obj = @as([*c]Obj, @ptrCast(@alignCast(result))),
        },
    };
}
pub export fn workspace_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if (argCount != 0) {
        runtimeError("workspace() takes no arguments.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
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
                if (isObjType((blk: {
                    const tmp = i;
                    if (tmp >= 0) break :blk e + @as(usize, @intCast(tmp)) else break :blk e - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                }).*.value, .OBJ_MATRIX)) {
                    _ = printf("\n");
                }
                value_h.printValue((blk: {
                    const tmp = i;
                    if (tmp >= 0) break :blk e + @as(usize, @intCast(tmp)) else break :blk e - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                }).*.value);
                _ = printf("\n");
            }
        }
    }
    return Value{
        .type = .VAL_NIL,
        .as = .{
            .num_int = 0,
        },
    };
}
pub export fn linspace_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if (argCount != @as(c_int, 3)) {
        runtimeError("linspace() takes 3 arguments.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    if ((!((args[0].type == .VAL_INT) or (args[0].type == .VAL_DOUBLE)) and !((args[1].type == .VAL_INT) or (args[1].type == .VAL_DOUBLE))) and !((args[2].type == .VAL_INT) or (args[2].type == .VAL_DOUBLE))) {
        runtimeError("First and second arguments must be numbers and the third argument must be an numbers.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    var start: f64 = if (args[0].type == .VAL_INT) @floatFromInt(args[0].as.num_int) else args[0].as.num_double;
    _ = &start;
    var end: f64 = if (args[1].type == .VAL_INT) @floatFromInt(args[1].as.num_int) else args[1].as.num_double;
    _ = &end;
    var n: c_int = if (args[2].type == .VAL_DOUBLE) @intFromFloat(args[2].as.num_double) else args[2].as.num_int;
    _ = &n;
    var a: [*c]FloatVector = obj_h.linspace(start, end, n);
    _ = &a;
    return Value{
        .type = .VAL_OBJ,
        .as = .{
            .obj = @as([*c]Obj, @ptrCast(@alignCast(a))),
        },
    };
}
pub export fn interp1_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if (argCount != @as(c_int, 3)) {
        runtimeError("interp1() takes 3 arguments.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    if ((!isObjType(args[0], .OBJ_FVECTOR) and !isObjType(args[1], .OBJ_FVECTOR)) and !((args[2].type == .VAL_INT) or (args[2].type == .VAL_DOUBLE))) {
        runtimeError("First and second arguments must be vectors and the third argument must be a number.", .{});
        return Value{
            .type = .VAL_NIL,
            .as = .{
                .num_int = 0,
            },
        };
    }
    var x: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
    _ = &x;
    var y: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[1].as.obj)));
    _ = &y;
    var x0: f64 = if (args[2].type == .VAL_INT) @floatFromInt(args[2].as.num_int) else args[2].as.num_double;
    _ = &x0;
    var result: f64 = obj_h.interp1(x, y, x0);
    _ = &result;
    return Value{
        .type = .VAL_DOUBLE,
        .as = .{
            .num_double = result,
        },
    };
}
pub export fn simd_stat_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;

    _ = &args;
    if (argCount != 0) {
        runtimeError("simd_stat() takes 0 arguments.", .{});
    }
    _ = printf("x86_64 SIMD AVX2 Enabled\n");
    return Value{
        .type = .VAL_NIL,
        .as = .{
            .num_int = 0,
        },
    };
}
