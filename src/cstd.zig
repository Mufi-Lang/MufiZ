const value_h = @import("value.zig");
const obj_h = @import("object.zig");
const table_h = @import("table.zig");
const Entry = table_h.Entry;
const entries_ = table_h.entries_;
const Value = value_h.Value;
const runtimeError = @import("vm.zig").runtimeError;
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
const vm = @import("vm.zig").vm;

pub export fn assert_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if (argCount != @as(c_int, 2)) {
        runtimeError("assert() takes 1 argument.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    if (valuesEqual(args[@as(c_uint, @intCast(@as(c_int, 0)))], args[@as(c_uint, @intCast(@as(c_int, 1)))])) {
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    } else {
        runtimeError("Assertion failed %s != %s", valueToString(args[@as(c_uint, @intCast(@as(c_int, 0)))]), valueToString(args[@as(c_uint, @intCast(@as(c_int, 1)))]));
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    return @import("std").mem.zeroes(Value);
}
pub fn iter_nf(argCount: c_int, args: [*c]Value) Value {
    _ = &argCount;
    _ = &args;
    return Value{
        .type = @as(c_uint, @bitCast(.VAL_NIL)),
        .as = .{
            .num_int = @as(c_int, 0),
        },
    };
}
pub export fn next_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if (argCount != @as(c_int, 1)) {
        runtimeError("next() takes 1 argument.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    if (!isObjType(args[@as(c_uint, @intCast(@as(c_int, 0)))], @as(c_uint, @bitCast(.OBJ_ARRAY))) and !isObjType(args[@as(c_uint, @intCast(@as(c_int, 0)))], @as(c_uint, @bitCast(.OBJ_FVECTOR)))) {
        runtimeError("Argument must be an iterable.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    var next: Value = Value{
        .type = @as(c_uint, @bitCast(.VAL_NIL)),
        .as = .{
            .num_int = @as(c_int, 0),
        },
    };
    _ = &next;
    if (isObjType(args[@as(c_uint, @intCast(@as(c_int, 0)))], @as(c_uint, @bitCast(.OBJ_ARRAY)))) {
        next = obj_h.nextObjectArray(@as([*c]ObjArray, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj))));
    } else if (isObjType(args[@as(c_uint, @intCast(@as(c_int, 0)))], @as(c_uint, @bitCast(.OBJ_FVECTOR)))) {
        next = Value{
            .type = @as(c_uint, @bitCast(.VAL_DOUBLE)),
            .as = .{
                .num_double = obj_h.nextFloatVector(@as([*c]FloatVector, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)))),
            },
        };
    }
    return next;
}
pub export fn hasNext_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if (argCount != @as(c_int, 1)) {
        runtimeError("has_next() takes 1 argument.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    if (!isObjType(args[@as(c_uint, @intCast(@as(c_int, 0)))], @as(c_uint, @bitCast(.OBJ_ARRAY))) and !isObjType(args[@as(c_uint, @intCast(@as(c_int, 0)))], @as(c_uint, @bitCast(.OBJ_FVECTOR)))) {
        runtimeError("Argument must be an iterable.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    var hasNext: bool = @as(c_int, 0) != 0;
    _ = &hasNext;
    if (isObjType(args[@as(c_uint, @intCast(@as(c_int, 0)))], @as(c_uint, @bitCast(.OBJ_ARRAY)))) {
        hasNext = obj_h.hasNextObjectArray(@as([*c]ObjArray, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj))));
    } else if (isObjType(args[@as(c_uint, @intCast(@as(c_int, 0)))], @as(c_uint, @bitCast(.OBJ_FVECTOR)))) {
        hasNext = obj_h.hasNextFloatVector(@as([*c]FloatVector, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj))));
    }
    return Value{
        .type = @as(c_uint, @bitCast(.VAL_BOOL)),
        .as = .{
            .boolean = hasNext,
        },
    };
}
pub export fn peek_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if (argCount != @as(c_int, 2)) {
        runtimeError("peek() takes 2 argument.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    if (!isObjType(args[@as(c_uint, @intCast(@as(c_int, 0)))], @as(c_uint, @bitCast(.OBJ_ARRAY))) and !isObjType(args[@as(c_uint, @intCast(@as(c_int, 0)))], @as(c_uint, @bitCast(.OBJ_FVECTOR)))) {
        runtimeError("Argument must be an iterable.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    if (!((args[@as(c_uint, @intCast(@as(c_int, 1)))].type == @as(c_uint, @bitCast(.VAL_INT))) or (args[@as(c_uint, @intCast(@as(c_int, 1)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE))))) {
        runtimeError("Second argument must be a number.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    var pos: c_int = if (args[@as(c_uint, @intCast(@as(c_int, 1)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE))) @as(c_int, @intFromFloat(args[@as(c_uint, @intCast(@as(c_int, 1)))].as.num_double)) else args[@as(c_uint, @intCast(@as(c_int, 1)))].as.num_int;
    _ = &pos;
    var peek: Value = Value{
        .type = @as(c_uint, @bitCast(.VAL_NIL)),
        .as = .{
            .num_int = @as(c_int, 0),
        },
    };
    _ = &peek;
    if (isObjType(args[@as(c_uint, @intCast(@as(c_int, 0)))], @as(c_uint, @bitCast(.OBJ_ARRAY)))) {
        peek = obj_h.peekObjectArray(@as([*c]ObjArray, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj))), pos);
    } else if (isObjType(args[@as(c_uint, @intCast(@as(c_int, 0)))], @as(c_uint, @bitCast(.OBJ_FVECTOR)))) {
        peek = Value{
            .type = @as(c_uint, @bitCast(.VAL_DOUBLE)),
            .as = .{
                .num_double = obj_h.peekFloatVector(@as([*c]FloatVector, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj))), pos),
            },
        };
    }
    return peek;
}
pub export fn reset_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if (argCount != @as(c_int, 1)) {
        runtimeError("reset() takes 1 argument.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    if (!isObjType(args[@as(c_uint, @intCast(@as(c_int, 0)))], @as(c_uint, @bitCast(.OBJ_ARRAY))) and !isObjType(args[@as(c_uint, @intCast(@as(c_int, 0)))], @as(c_uint, @bitCast(.OBJ_FVECTOR)))) {
        runtimeError("Argument must be an iterable.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    if (isObjType(args[@as(c_uint, @intCast(@as(c_int, 0)))], @as(c_uint, @bitCast(.OBJ_ARRAY)))) {
        obj_h.resetObjectArray(@as([*c]ObjArray, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj))));
    } else if (isObjType(args[@as(c_uint, @intCast(@as(c_int, 0)))], @as(c_uint, @bitCast(.OBJ_FVECTOR)))) {
        obj_h.resetFloatVector(@as([*c]FloatVector, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj))));
    }
    return Value{
        .type = @as(c_uint, @bitCast(.VAL_NIL)),
        .as = .{
            .num_int = @as(c_int, 0),
        },
    };
}
pub export fn skip_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if (argCount != @as(c_int, 2)) {
        runtimeError("skip() takes 2 arguments.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    if (!isObjType(args[@as(c_uint, @intCast(@as(c_int, 0)))], @as(c_uint, @bitCast(.OBJ_ARRAY))) and !isObjType(args[@as(c_uint, @intCast(@as(c_int, 0)))], @as(c_uint, @bitCast(.OBJ_FVECTOR)))) {
        runtimeError("Argument must be an iterable.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    if (!((args[@as(c_uint, @intCast(@as(c_int, 1)))].type == @as(c_uint, @bitCast(.VAL_INT))) or (args[@as(c_uint, @intCast(@as(c_int, 1)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE))))) {
        runtimeError("Second argument must be a number.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    var skip: c_int = if (args[@as(c_uint, @intCast(@as(c_int, 1)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE))) @as(c_int, @intFromFloat(args[@as(c_uint, @intCast(@as(c_int, 1)))].as.num_double)) else args[@as(c_uint, @intCast(@as(c_int, 1)))].as.num_int;
    _ = &skip;
    if (isObjType(args[@as(c_uint, @intCast(@as(c_int, 0)))], @as(c_uint, @bitCast(.OBJ_ARRAY)))) {
        obj_h.skipObjectArray(@as([*c]ObjArray, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj))), skip);
    } else if (isObjType(args[@as(c_uint, @intCast(@as(c_int, 0)))], @as(c_uint, @bitCast(.OBJ_FVECTOR)))) {
        obj_h.skipFloatVector(@as([*c]FloatVector, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj))), skip);
    }
    return Value{
        .type = @as(c_uint, @bitCast(.VAL_NIL)),
        .as = .{
            .num_int = @as(c_int, 0),
        },
    };
}
pub export fn array_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if (argCount == @as(c_int, 0)) {
        var a: [*c]ObjArray = obj_h.newArray();
        _ = &a;
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_OBJ)),
            .as = .{
                .obj = @as([*c]Obj, @ptrCast(@alignCast(a))),
            },
        };
    } else if ((argCount == @as(c_int, 1)) and (@as(c_int, @intFromBool(isObjType(args[@as(c_uint, @intCast(@as(c_int, 0)))], @as(c_uint, @bitCast(.OBJ_FVECTOR))))) != 0)) {
        var f: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
        _ = &f;
        var a: [*c]ObjArray = obj_h.newArrayWithCap(f.*.size, @as(c_int, 1) != 0);
        _ = &a;
        {
            var i: c_int = 0;
            _ = &i;
            while (i < f.*.count) : (i += 1) {
                obj_h.pushArray(a, Value{
                    .type = @as(c_uint, @bitCast(.VAL_DOUBLE)),
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
            .type = @as(c_uint, @bitCast(.VAL_OBJ)),
            .as = .{
                .obj = @as([*c]Obj, @ptrCast(@alignCast(a))),
            },
        };
    } else if (argCount >= @as(c_int, 1)) {
        if (!((args[@as(c_uint, @intCast(@as(c_int, 0)))].type == @as(c_uint, @bitCast(.VAL_INT))) or (args[@as(c_uint, @intCast(@as(c_int, 0)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE))))) {
            runtimeError("First argument must be a number when creating an array with a specified capacity.");
            return Value{
                .type = @as(c_uint, @bitCast(.VAL_NIL)),
                .as = .{
                    .num_int = @as(c_int, 0),
                },
            };
        }
        if ((argCount == @as(c_int, 2)) and !(args[@as(c_uint, @intCast(@as(c_int, 1)))].type == @as(c_uint, @bitCast(.VAL_BOOL)))) {
            runtimeError("Second argument must be a bool");
            return Value{
                .type = @as(c_uint, @bitCast(.VAL_NIL)),
                .as = .{
                    .num_int = @as(c_int, 0),
                },
            };
        }
        var a: [*c]ObjArray = obj_h.newArrayWithCap(if (args[@as(c_uint, @intCast(@as(c_int, 0)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE))) @as(c_int, @intFromFloat(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.num_double)) else args[@as(c_uint, @intCast(@as(c_int, 0)))].as.num_int, args[@as(c_uint, @intCast(@as(c_int, 1)))].as.boolean);
        _ = &a;
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_OBJ)),
            .as = .{
                .obj = @as([*c]Obj, @ptrCast(@alignCast(a))),
            },
        };
    } else {
        runtimeError("array() takes 0 or 1 argument.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    return @import("std").mem.zeroes(Value);
}
pub export fn linkedlist_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if (argCount != @as(c_int, 0)) {
        runtimeError("linked_list() takes no arguments.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    var l: [*c]ObjLinkedList = obj_h.newLinkedList();
    _ = &l;
    return Value{
        .type = @as(c_uint, @bitCast(.VAL_OBJ)),
        .as = .{
            .obj = @as([*c]Obj, @ptrCast(@alignCast(l))),
        },
    };
}
pub export fn hashtable_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if (argCount != @as(c_int, 0)) {
        runtimeError("hash_table() takes no arguments.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    var h: [*c]ObjHashTable = obj_h.newHashTable();
    _ = &h;
    return Value{
        .type = @as(c_uint, @bitCast(.VAL_OBJ)),
        .as = .{
            .obj = @as([*c]Obj, @ptrCast(@alignCast(h))),
        },
    };
}
pub export fn matrix_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if (!((args[@as(c_uint, @intCast(@as(c_int, 0)))].type == @as(c_uint, @bitCast(.VAL_INT))) or (args[@as(c_uint, @intCast(@as(c_int, 0)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE)))) or !((args[@as(c_uint, @intCast(@as(c_int, 1)))].type == @as(c_uint, @bitCast(.VAL_INT))) or (args[@as(c_uint, @intCast(@as(c_int, 1)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE))))) {
        runtimeError("Both arguments must be numbers.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    var rows: c_int = if (args[@as(c_uint, @intCast(@as(c_int, 0)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE))) @as(c_int, @intFromFloat(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.num_double)) else args[@as(c_uint, @intCast(@as(c_int, 0)))].as.num_int;
    _ = &rows;
    var cols: c_int = if (args[@as(c_uint, @intCast(@as(c_int, 1)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE))) @as(c_int, @intFromFloat(args[@as(c_uint, @intCast(@as(c_int, 1)))].as.num_double)) else args[@as(c_uint, @intCast(@as(c_int, 1)))].as.num_int;
    _ = &cols;
    var m: [*c]ObjMatrix = obj_h.newMatrix(rows, cols);
    _ = &m;
    return Value{
        .type = @as(c_uint, @bitCast(.VAL_OBJ)),
        .as = .{
            .obj = @as([*c]Obj, @ptrCast(@alignCast(m))),
        },
    };
}
pub export fn fvector_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if (argCount != @as(c_int, 1)) {
        runtimeError("fvec() takes 1 argument.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    if (!((args[@as(c_uint, @intCast(@as(c_int, 0)))].type == @as(c_uint, @bitCast(.VAL_INT))) or (args[@as(c_uint, @intCast(@as(c_int, 0)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE)))) and !isObjType(args[@as(c_uint, @intCast(@as(c_int, 0)))], @as(c_uint, @bitCast(.OBJ_ARRAY)))) {
        runtimeError("First argument must be an numbers or an array.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    if (isObjType(args[@as(c_uint, @intCast(@as(c_int, 0)))], @as(c_uint, @bitCast(.OBJ_ARRAY)))) {
        var a: [*c]ObjArray = @as([*c]ObjArray, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
        _ = &a;
        var f: [*c]FloatVector = obj_h.newFloatVector(a.*.capacity);
        _ = &f;
        {
            var i: c_int = 0;
            _ = &i;
            while (i < a.*.count) : (i += 1) {
                if (!(((blk: {
                    const tmp = i;
                    if (tmp >= 0) break :blk a.*.values + @as(usize, @intCast(tmp)) else break :blk a.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                }).*.type == @as(c_uint, @bitCast(.VAL_INT))) or ((blk: {
                    const tmp = i;
                    if (tmp >= 0) break :blk a.*.values + @as(usize, @intCast(tmp)) else break :blk a.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                }).*.type == @as(c_uint, @bitCast(.VAL_DOUBLE))))) {
                    runtimeError("All elements of the vector must be numbers.");
                    return Value{
                        .type = @as(c_uint, @bitCast(.VAL_NIL)),
                        .as = .{
                            .num_int = @as(c_int, 0),
                        },
                    };
                }
                obj_h.pushFloatVector(f, if ((blk: {
                    const tmp = i;
                    if (tmp >= 0) break :blk a.*.values + @as(usize, @intCast(tmp)) else break :blk a.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                }).*.type == @as(c_uint, @bitCast(.VAL_INT))) @as(f64, @floatFromInt((blk: {
                    const tmp = i;
                    if (tmp >= 0) break :blk a.*.values + @as(usize, @intCast(tmp)) else break :blk a.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                }).*.as.num_int)) else (blk: {
                    const tmp = i;
                    if (tmp >= 0) break :blk a.*.values + @as(usize, @intCast(tmp)) else break :blk a.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                }).*.as.num_double);
            }
        }
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_OBJ)),
            .as = .{
                .obj = @as([*c]Obj, @ptrCast(@alignCast(f))),
            },
        };
    } else {
        var n: c_int = if (args[@as(c_uint, @intCast(@as(c_int, 0)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE))) @as(c_int, @intFromFloat(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.num_double)) else args[@as(c_uint, @intCast(@as(c_int, 0)))].as.num_int;
        _ = &n;
        var f: [*c]FloatVector = obj_h.newFloatVector(n);
        _ = &f;
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_OBJ)),
            .as = .{
                .obj = @as([*c]Obj, @ptrCast(@alignCast(f))),
            },
        };
    }
    return @import("std").mem.zeroes(Value);
}
pub export fn range_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if (!((args[@as(c_uint, @intCast(@as(c_int, 0)))].type == @as(c_uint, @bitCast(.VAL_INT))) or (args[@as(c_uint, @intCast(@as(c_int, 0)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE)))) and !((args[@as(c_uint, @intCast(@as(c_int, 1)))].type == @as(c_uint, @bitCast(.VAL_INT))) or (args[@as(c_uint, @intCast(@as(c_int, 1)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE))))) {
        runtimeError("Both arguments must be numbers.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    var start: c_int = if (args[@as(c_uint, @intCast(@as(c_int, 0)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE))) @as(c_int, @intFromFloat(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.num_double)) else args[@as(c_uint, @intCast(@as(c_int, 0)))].as.num_int;
    _ = &start;
    var end: c_int = if (args[@as(c_uint, @intCast(@as(c_int, 1)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE))) @as(c_int, @intFromFloat(args[@as(c_uint, @intCast(@as(c_int, 1)))].as.num_double)) else args[@as(c_uint, @intCast(@as(c_int, 1)))].as.num_int;
    _ = &end;
    var a: [*c]ObjArray = obj_h.newArrayWithCap(end - start, @as(c_int, 1) != 0);
    _ = &a;
    {
        var i: c_int = start;
        _ = &i;
        while (i < end) : (i += 1) {
            obj_h.pushArray(a, Value{
                .type = @as(c_uint, @bitCast(.VAL_INT)),
                .as = .{
                    .num_int = i,
                },
            });
        }
    }
    return Value{
        .type = @as(c_uint, @bitCast(.VAL_OBJ)),
        .as = .{
            .obj = @as([*c]Obj, @ptrCast(@alignCast(a))),
        },
    };
}
pub export fn slice_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if ((@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_LINKED_LIST)),
        .count = @as(c_int, 1),
    }))) != 0) and ((@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_ARRAY)),
        .count = @as(c_int, 1),
    }))) != 0) and (@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_FVECTOR)),
        .count = @as(c_int, 1),
    }))) != 0))) {
        runtimeError("First argument must be an array, linked list or vector.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    if (!((args[@as(c_uint, @intCast(@as(c_int, 0)))].type == @as(c_uint, @bitCast(.VAL_INT))) or (args[@as(c_uint, @intCast(@as(c_int, 0)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE)))) and !((args[@as(c_uint, @intCast(@as(c_int, 1)))].type == @as(c_uint, @bitCast(.VAL_INT))) or (args[@as(c_uint, @intCast(@as(c_int, 1)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE))))) {
        runtimeError("Second and third arguments must be numbers.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    while (true) {
        switch (args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj.*.type) {
            @as(c_uint, @bitCast(@as(c_int, 8))) => {
                {
                    var a: [*c]ObjArray = @as([*c]ObjArray, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &a;
                    var start: c_int = if (args[@as(c_uint, @intCast(@as(c_int, 1)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE))) @as(c_int, @intFromFloat(args[@as(c_uint, @intCast(@as(c_int, 1)))].as.num_double)) else args[@as(c_uint, @intCast(@as(c_int, 1)))].as.num_int;
                    _ = &start;
                    var end: c_int = if (args[@as(c_uint, @intCast(@as(c_int, 2)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE))) @as(c_int, @intFromFloat(args[@as(c_uint, @intCast(@as(c_int, 2)))].as.num_double)) else args[@as(c_uint, @intCast(@as(c_int, 2)))].as.num_int;
                    _ = &end;
                    var s: [*c]ObjArray = obj_h.sliceArray(a, start, end);
                    _ = &s;
                    return Value{
                        .type = @as(c_uint, @bitCast(.VAL_OBJ)),
                        .as = .{
                            .obj = @as([*c]Obj, @ptrCast(@alignCast(s))),
                        },
                    };
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 12))) => {
                {
                    var f: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &f;
                    var start: c_int = if (args[@as(c_uint, @intCast(@as(c_int, 1)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE))) @as(c_int, @intFromFloat(args[@as(c_uint, @intCast(@as(c_int, 1)))].as.num_double)) else args[@as(c_uint, @intCast(@as(c_int, 1)))].as.num_int;
                    _ = &start;
                    var end: c_int = if (args[@as(c_uint, @intCast(@as(c_int, 2)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE))) @as(c_int, @intFromFloat(args[@as(c_uint, @intCast(@as(c_int, 2)))].as.num_double)) else args[@as(c_uint, @intCast(@as(c_int, 2)))].as.num_int;
                    _ = &end;
                    var s: [*c]FloatVector = obj_h.sliceFloatVector(f, start, end);
                    _ = &s;
                    return Value{
                        .type = @as(c_uint, @bitCast(.VAL_OBJ)),
                        .as = .{
                            .obj = @as([*c]Obj, @ptrCast(@alignCast(s))),
                        },
                    };
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 9))) => {
                {
                    var l: [*c]ObjLinkedList = @as([*c]ObjLinkedList, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &l;
                    var start: c_int = if (args[@as(c_uint, @intCast(@as(c_int, 1)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE))) @as(c_int, @intFromFloat(args[@as(c_uint, @intCast(@as(c_int, 1)))].as.num_double)) else args[@as(c_uint, @intCast(@as(c_int, 1)))].as.num_int;
                    _ = &start;
                    var end: c_int = if (args[@as(c_uint, @intCast(@as(c_int, 2)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE))) @as(c_int, @intFromFloat(args[@as(c_uint, @intCast(@as(c_int, 2)))].as.num_double)) else args[@as(c_uint, @intCast(@as(c_int, 2)))].as.num_int;
                    _ = &end;
                    var s: [*c]ObjLinkedList = obj_h.sliceLinkedList(l, start, end);
                    _ = &s;
                    return Value{
                        .type = @as(c_uint, @bitCast(.VAL_OBJ)),
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
    return @import("std").mem.zeroes(Value);
}
pub export fn splice_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if ((@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_LINKED_LIST)),
        .count = @as(c_int, 1),
    }))) != 0) and ((@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_ARRAY)),
        .count = @as(c_int, 1),
    }))) != 0) and (@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_FVECTOR)),
        .count = @as(c_int, 1),
    }))) != 0))) {
        runtimeError("First argument must be an array, linked list or vector.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    if (!((args[@as(c_uint, @intCast(@as(c_int, 1)))].type == @as(c_uint, @bitCast(.VAL_INT))) or (args[@as(c_uint, @intCast(@as(c_int, 1)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE)))) or !((args[@as(c_uint, @intCast(@as(c_int, 2)))].type == @as(c_uint, @bitCast(.VAL_INT))) or (args[@as(c_uint, @intCast(@as(c_int, 2)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE))))) {
        runtimeError("Second and third arguments must be numbers.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    while (true) {
        switch (args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj.*.type) {
            @as(c_uint, @bitCast(@as(c_int, 8))) => {
                {
                    var a: [*c]ObjArray = @as([*c]ObjArray, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &a;
                    var start: c_int = if (args[@as(c_uint, @intCast(@as(c_int, 1)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE))) @as(c_int, @intFromFloat(args[@as(c_uint, @intCast(@as(c_int, 1)))].as.num_double)) else args[@as(c_uint, @intCast(@as(c_int, 1)))].as.num_int;
                    _ = &start;
                    var end: c_int = if (args[@as(c_uint, @intCast(@as(c_int, 2)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE))) @as(c_int, @intFromFloat(args[@as(c_uint, @intCast(@as(c_int, 2)))].as.num_double)) else args[@as(c_uint, @intCast(@as(c_int, 2)))].as.num_int;
                    _ = &end;
                    var s: [*c]ObjArray = obj_h.spliceArray(a, start, end);
                    _ = &s;
                    return Value{
                        .type = @as(c_uint, @bitCast(.VAL_OBJ)),
                        .as = .{
                            .obj = @as([*c]Obj, @ptrCast(@alignCast(s))),
                        },
                    };
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 12))) => {
                {
                    var f: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &f;
                    var start: c_int = if (args[@as(c_uint, @intCast(@as(c_int, 1)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE))) @as(c_int, @intFromFloat(args[@as(c_uint, @intCast(@as(c_int, 1)))].as.num_double)) else args[@as(c_uint, @intCast(@as(c_int, 1)))].as.num_int;
                    _ = &start;
                    var end: c_int = if (args[@as(c_uint, @intCast(@as(c_int, 2)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE))) @as(c_int, @intFromFloat(args[@as(c_uint, @intCast(@as(c_int, 2)))].as.num_double)) else args[@as(c_uint, @intCast(@as(c_int, 2)))].as.num_int;
                    _ = &end;
                    var s: [*c]FloatVector = obj_h.spliceFloatVector(f, start, end);
                    _ = &s;
                    return Value{
                        .type = @as(c_uint, @bitCast(.VAL_OBJ)),
                        .as = .{
                            .obj = @as([*c]Obj, @ptrCast(@alignCast(s))),
                        },
                    };
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 9))) => {
                {
                    var l: [*c]ObjLinkedList = @as([*c]ObjLinkedList, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &l;
                    var start: c_int = if (args[@as(c_uint, @intCast(@as(c_int, 1)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE))) @as(c_int, @intFromFloat(args[@as(c_uint, @intCast(@as(c_int, 1)))].as.num_double)) else args[@as(c_uint, @intCast(@as(c_int, 1)))].as.num_int;
                    _ = &start;
                    var end: c_int = if (args[@as(c_uint, @intCast(@as(c_int, 2)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE))) @as(c_int, @intFromFloat(args[@as(c_uint, @intCast(@as(c_int, 2)))].as.num_double)) else args[@as(c_uint, @intCast(@as(c_int, 2)))].as.num_int;
                    _ = &end;
                    var s: [*c]ObjLinkedList = obj_h.spliceLinkedList(l, start, end);
                    _ = &s;
                    return Value{
                        .type = @as(c_uint, @bitCast(.VAL_OBJ)),
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
    return @import("std").mem.zeroes(Value);
}
pub export fn push_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if ((@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_LINKED_LIST)),
        .count = @as(c_int, 1),
    }))) != 0) and ((@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_ARRAY)),
        .count = @as(c_int, 1),
    }))) != 0) and (@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_FVECTOR)),
        .count = @as(c_int, 1),
    }))) != 0))) {
        runtimeError("First argument must be a list type.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    while (true) {
        switch (args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj.*.type) {
            @as(c_uint, @bitCast(@as(c_int, 8))) => {
                {
                    var a: [*c]ObjArray = @as([*c]ObjArray, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &a;
                    {
                        var i: c_int = 1;
                        _ = &i;
                        while (i < argCount) : (i += 1) {
                            obj_h.pushArray(a, (blk: {
                                const tmp = i;
                                if (tmp >= 0) break :blk args + @as(usize, @intCast(tmp)) else break :blk args - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                            }).*);
                        }
                    }
                    return Value{
                        .type = @as(c_uint, @bitCast(.VAL_NIL)),
                        .as = .{
                            .num_int = @as(c_int, 0),
                        },
                    };
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 12))) => {
                {
                    var f: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &f;
                    {
                        var i: c_int = 1;
                        _ = &i;
                        while (i < argCount) : (i += 1) {
                            if (!(((blk: {
                                const tmp = i;
                                if (tmp >= 0) break :blk args + @as(usize, @intCast(tmp)) else break :blk args - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                            }).*.type == @as(c_uint, @bitCast(.VAL_INT))) or ((blk: {
                                const tmp = i;
                                if (tmp >= 0) break :blk args + @as(usize, @intCast(tmp)) else break :blk args - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                            }).*.type == @as(c_uint, @bitCast(.VAL_DOUBLE))))) {
                                runtimeError("All elements of the vector must be numbers.");
                                return Value{
                                    .type = @as(c_uint, @bitCast(.VAL_NIL)),
                                    .as = .{
                                        .num_int = @as(c_int, 0),
                                    },
                                };
                            }
                            obj_h.pushFloatVector(f, if ((blk: {
                                const tmp = i;
                                if (tmp >= 0) break :blk args + @as(usize, @intCast(tmp)) else break :blk args - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                            }).*.type == @as(c_uint, @bitCast(.VAL_INT))) @as(f64, @floatFromInt((blk: {
                                const tmp = i;
                                if (tmp >= 0) break :blk args + @as(usize, @intCast(tmp)) else break :blk args - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                            }).*.as.num_int)) else (blk: {
                                const tmp = i;
                                if (tmp >= 0) break :blk args + @as(usize, @intCast(tmp)) else break :blk args - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                            }).*.as.num_double);
                        }
                    }
                    return Value{
                        .type = @as(c_uint, @bitCast(.VAL_NIL)),
                        .as = .{
                            .num_int = @as(c_int, 0),
                        },
                    };
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 9))) => {
                {
                    var l: [*c]ObjLinkedList = @as([*c]ObjLinkedList, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
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
                        .type = @as(c_uint, @bitCast(.VAL_NIL)),
                        .as = .{
                            .num_int = @as(c_int, 0),
                        },
                    };
                }
            },
            else => {
                runtimeError("Argument must be a linked list, array or float vector.");
                return Value{
                    .type = @as(c_uint, @bitCast(.VAL_NIL)),
                    .as = .{
                        .num_int = @as(c_int, 0),
                    },
                };
            },
        }
        break;
    }
    return @import("std").mem.zeroes(Value);
}
pub export fn pop_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if (argCount != @as(c_int, 1)) {
        runtimeError("pop() takes 1 argument.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    if ((@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_LINKED_LIST)),
        .count = @as(c_int, 1),
    }))) != 0) and ((@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_ARRAY)),
        .count = @as(c_int, 1),
    }))) != 0) and (@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_FVECTOR)),
        .count = @as(c_int, 1),
    }))) != 0))) {
        runtimeError("First argument must be a list type.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    while (true) {
        switch (args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj.*.type) {
            @as(c_uint, @bitCast(@as(c_int, 8))) => {
                {
                    var a: [*c]ObjArray = @as([*c]ObjArray, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &a;
                    return obj_h.popArray(a);
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 12))) => {
                {
                    var f: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &f;
                    return Value{
                        .type = @as(c_uint, @bitCast(.VAL_DOUBLE)),
                        .as = .{
                            .num_double = obj_h.popFloatVector(f),
                        },
                    };
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 9))) => {
                {
                    var l: [*c]ObjLinkedList = @as([*c]ObjLinkedList, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &l;
                    return obj_h.popBack(l);
                }
            },
            else => {
                runtimeError("Argument must be a linked list, array or float vector.");
                return Value{
                    .type = @as(c_uint, @bitCast(.VAL_NIL)),
                    .as = .{
                        .num_int = @as(c_int, 0),
                    },
                };
            },
        }
        break;
    }
    return @import("std").mem.zeroes(Value);
}
pub export fn nth_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if ((((@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_HASH_TABLE)),
        .count = @as(c_int, 1),
    }))) != 0) and (@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_MATRIX)),
        .count = @as(c_int, 1),
    }))) != 0)) and ((@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_LINKED_LIST)),
        .count = @as(c_int, 1),
    }))) != 0) and ((@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_ARRAY)),
        .count = @as(c_int, 1),
    }))) != 0) and (@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_FVECTOR)),
        .count = @as(c_int, 1),
    }))) != 0)))) and (@as(c_int, @intFromBool(isObjType(args[@as(c_uint, @intCast(@as(c_int, 0)))], @as(c_uint, @bitCast(.OBJ_HASH_TABLE))))) != 0)) {
        runtimeError("First argument must be an array, matrix, linked list or Vector.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    if (!((args[@as(c_uint, @intCast(@as(c_int, 1)))].type == @as(c_uint, @bitCast(.VAL_INT))) or (args[@as(c_uint, @intCast(@as(c_int, 1)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE))))) {
        runtimeError("Second argument must be a number.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    while (true) {
        switch (args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj.*.type) {
            @as(c_uint, @bitCast(@as(c_int, 11))) => {
                {
                    if ((argCount == @as(c_int, 3)) and ((args[@as(c_uint, @intCast(@as(c_int, 2)))].type == @as(c_uint, @bitCast(.VAL_INT))) or (args[@as(c_uint, @intCast(@as(c_int, 2)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE))))) {
                        var m: [*c]ObjMatrix = @as([*c]ObjMatrix, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                        _ = &m;
                        var row: c_int = if (args[@as(c_uint, @intCast(@as(c_int, 1)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE))) @as(c_int, @intFromFloat(args[@as(c_uint, @intCast(@as(c_int, 1)))].as.num_double)) else args[@as(c_uint, @intCast(@as(c_int, 1)))].as.num_int;
                        _ = &row;
                        var col: c_int = if (args[@as(c_uint, @intCast(@as(c_int, 2)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE))) @as(c_int, @intFromFloat(args[@as(c_uint, @intCast(@as(c_int, 2)))].as.num_double)) else args[@as(c_uint, @intCast(@as(c_int, 2)))].as.num_int;
                        _ = &col;
                        return obj_h.getMatrix(m, row, col);
                    }
                    break;
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 12))) => {
                {
                    var f: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &f;
                    var index_1: c_int = if (args[@as(c_uint, @intCast(@as(c_int, 1)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE))) @as(c_int, @intFromFloat(args[@as(c_uint, @intCast(@as(c_int, 1)))].as.num_double)) else args[@as(c_uint, @intCast(@as(c_int, 1)))].as.num_int;
                    _ = &index_1;
                    var value: f64 = obj_h.getFloatVector(f, index_1);
                    _ = &value;
                    return Value{
                        .type = @as(c_uint, @bitCast(.VAL_DOUBLE)),
                        .as = .{
                            .num_double = value,
                        },
                    };
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 8))) => {
                {
                    var a: [*c]ObjArray = @as([*c]ObjArray, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &a;
                    var index_1: c_int = if (args[@as(c_uint, @intCast(@as(c_int, 1)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE))) @as(c_int, @intFromFloat(args[@as(c_uint, @intCast(@as(c_int, 1)))].as.num_double)) else args[@as(c_uint, @intCast(@as(c_int, 1)))].as.num_int;
                    _ = &index_1;
                    if ((index_1 >= @as(c_int, 0)) and (index_1 < a.*.count)) {
                        return (blk: {
                            const tmp = index_1;
                            if (tmp >= 0) break :blk a.*.values + @as(usize, @intCast(tmp)) else break :blk a.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                        }).*;
                    }
                    break;
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 9))) => {
                {
                    var l: [*c]ObjLinkedList = @as([*c]ObjLinkedList, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &l;
                    var index_1: c_int = if (args[@as(c_uint, @intCast(@as(c_int, 1)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE))) @as(c_int, @intFromFloat(args[@as(c_uint, @intCast(@as(c_int, 1)))].as.num_double)) else args[@as(c_uint, @intCast(@as(c_int, 1)))].as.num_int;
                    _ = &index_1;
                    if ((index_1 >= @as(c_int, 0)) and (index_1 < l.*.count)) {
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
                    runtimeError("Invalid argument types or index out of bounds.");
                    return Value{
                        .type = @as(c_uint, @bitCast(.VAL_NIL)),
                        .as = .{
                            .num_int = @as(c_int, 0),
                        },
                    };
                }
            },
        }
        break;
    }
    return @import("std").mem.zeroes(Value);
}
pub export fn sort_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if ((@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_LINKED_LIST)),
        .count = @as(c_int, 1),
    }))) != 0) and ((@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_ARRAY)),
        .count = @as(c_int, 1),
    }))) != 0) and (@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_FVECTOR)),
        .count = @as(c_int, 1),
    }))) != 0))) {
        runtimeError("First argument must be a list type.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    while (true) {
        switch (args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj.*.type) {
            @as(c_uint, @bitCast(@as(c_int, 8))) => {
                {
                    var a: [*c]ObjArray = @as([*c]ObjArray, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &a;
                    obj_h.sortArray(a);
                    return Value{
                        .type = @as(c_uint, @bitCast(.VAL_NIL)),
                        .as = .{
                            .num_int = @as(c_int, 0),
                        },
                    };
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 12))) => {
                {
                    var f: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &f;
                    obj_h.sortFloatVector(f);
                    return Value{
                        .type = @as(c_uint, @bitCast(.VAL_NIL)),
                        .as = .{
                            .num_int = @as(c_int, 0),
                        },
                    };
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 9))) => {
                {
                    var l: [*c]ObjLinkedList = @as([*c]ObjLinkedList, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &l;
                    obj_h.mergeSort(l);
                    return Value{
                        .type = @as(c_uint, @bitCast(.VAL_NIL)),
                        .as = .{
                            .num_int = @as(c_int, 0),
                        },
                    };
                }
            },
            else => {
                runtimeError("Argument must be a linked list, array or float vector.");
                return Value{
                    .type = @as(c_uint, @bitCast(.VAL_NIL)),
                    .as = .{
                        .num_int = @as(c_int, 0),
                    },
                };
            },
        }
        break;
    }
    return @import("std").mem.zeroes(Value);
}
pub export fn contains_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if (((@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_LINKED_LIST)),
        .count = @as(c_int, 1),
    }))) != 0) and ((@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_ARRAY)),
        .count = @as(c_int, 1),
    }))) != 0) and (@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_FVECTOR)),
        .count = @as(c_int, 1),
    }))) != 0))) and !isObjType(args[@as(c_uint, @intCast(@as(c_int, 0)))], @as(c_uint, @bitCast(.OBJ_HASH_TABLE)))) {
        runtimeError("First argument must be a collection type.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    while (true) {
        switch (args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj.*.type) {
            @as(c_uint, @bitCast(@as(c_int, 8))) => {
                {
                    var a: [*c]ObjArray = @as([*c]ObjArray, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &a;
                    {
                        var i: c_int = 0;
                        _ = &i;
                        while (i < a.*.count) : (i += 1) {
                            if (valuesEqual((blk: {
                                const tmp = i;
                                if (tmp >= 0) break :blk a.*.values + @as(usize, @intCast(tmp)) else break :blk a.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                            }).*, args[@as(c_uint, @intCast(@as(c_int, 1)))])) {
                                return Value{
                                    .type = @as(c_uint, @bitCast(.VAL_BOOL)),
                                    .as = .{
                                        .boolean = @as(c_int, 1) != 0,
                                    },
                                };
                            }
                        }
                    }
                    return Value{
                        .type = @as(c_uint, @bitCast(.VAL_BOOL)),
                        .as = .{
                            .boolean = @as(c_int, 0) != 0,
                        },
                    };
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 12))) => {
                {
                    var f: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &f;
                    {
                        var i: c_int = 0;
                        _ = &i;
                        while (i < f.*.count) : (i += 1) {
                            if ((blk: {
                                const tmp = i;
                                if (tmp >= 0) break :blk f.*.data + @as(usize, @intCast(tmp)) else break :blk f.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                            }).* == (if (args[@as(c_uint, @intCast(@as(c_int, 1)))].type == @as(c_uint, @bitCast(.VAL_INT))) @as(f64, @floatFromInt(args[@as(c_uint, @intCast(@as(c_int, 1)))].as.num_int)) else args[@as(c_uint, @intCast(@as(c_int, 1)))].as.num_double)) {
                                return Value{
                                    .type = @as(c_uint, @bitCast(.VAL_BOOL)),
                                    .as = .{
                                        .boolean = @as(c_int, 1) != 0,
                                    },
                                };
                            }
                        }
                    }
                    return Value{
                        .type = @as(c_uint, @bitCast(.VAL_BOOL)),
                        .as = .{
                            .boolean = @as(c_int, 0) != 0,
                        },
                    };
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 10))) => {
                {
                    var h: [*c]ObjHashTable = @as([*c]ObjHashTable, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &h;
                    if (!valuesEqual(obj_h.getHashTable(h, @as([*c]ObjString, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 1)))].as.obj)))), Value{
                        .type = @as(c_uint, @bitCast(.VAL_NIL)),
                        .as = .{
                            .num_int = @as(c_int, 0),
                        },
                    })) {
                        return Value{
                            .type = @as(c_uint, @bitCast(.VAL_BOOL)),
                            .as = .{
                                .boolean = @as(c_int, 1) != 0,
                            },
                        };
                    } else {
                        return Value{
                            .type = @as(c_uint, @bitCast(.VAL_BOOL)),
                            .as = .{
                                .boolean = @as(c_int, 0) != 0,
                            },
                        };
                    }
                }
                {
                    var l: [*c]ObjLinkedList = @as([*c]ObjLinkedList, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &l;
                    var current: [*c]Node = l.*.head;
                    _ = &current;
                    while (current != @as([*c]Node, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) {
                        if (valuesEqual(current.*.data, args[@as(c_uint, @intCast(@as(c_int, 1)))])) {
                            return Value{
                                .type = @as(c_uint, @bitCast(.VAL_BOOL)),
                                .as = .{
                                    .boolean = @as(c_int, 1) != 0,
                                },
                            };
                        }
                        current = current.*.next;
                    }
                    return Value{
                        .type = @as(c_uint, @bitCast(.VAL_BOOL)),
                        .as = .{
                            .boolean = @as(c_int, 0) != 0,
                        },
                    };
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 9))) => {
                {
                    var l: [*c]ObjLinkedList = @as([*c]ObjLinkedList, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &l;
                    var current: [*c]Node = l.*.head;
                    _ = &current;
                    while (current != @as([*c]Node, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) {
                        if (valuesEqual(current.*.data, args[@as(c_uint, @intCast(@as(c_int, 1)))])) {
                            return Value{
                                .type = @as(c_uint, @bitCast(.VAL_BOOL)),
                                .as = .{
                                    .boolean = @as(c_int, 1) != 0,
                                },
                            };
                        }
                        current = current.*.next;
                    }
                    return Value{
                        .type = @as(c_uint, @bitCast(.VAL_BOOL)),
                        .as = .{
                            .boolean = @as(c_int, 0) != 0,
                        },
                    };
                }
            },
            else => {
                {
                    runtimeError("Invalid argument type.");
                    return Value{
                        .type = @as(c_uint, @bitCast(.VAL_NIL)),
                        .as = .{
                            .num_int = @as(c_int, 0),
                        },
                    };
                }
            },
        }
        break;
    }
    return @import("std").mem.zeroes(Value);
}
pub export fn insert_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if (argCount != @as(c_int, 3)) {
        runtimeError("insert() takes 3 arguments.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    if ((@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_ARRAY)),
        .count = @as(c_int, 1),
    }))) != 0) and (@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_FVECTOR)),
        .count = @as(c_int, 1),
    }))) != 0)) {
        runtimeError("First argument must be an array or vector.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    if (!((args[@as(c_uint, @intCast(@as(c_int, 1)))].type == @as(c_uint, @bitCast(.VAL_INT))) or (args[@as(c_uint, @intCast(@as(c_int, 1)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE))))) {
        runtimeError("Second argument must be a number.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    while (true) {
        switch (args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj.*.type) {
            @as(c_uint, @bitCast(@as(c_int, 12))) => {
                {
                    var f: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &f;
                    var index_1: c_int = if (args[@as(c_uint, @intCast(@as(c_int, 1)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE))) @as(c_int, @intFromFloat(args[@as(c_uint, @intCast(@as(c_int, 1)))].as.num_double)) else args[@as(c_uint, @intCast(@as(c_int, 1)))].as.num_int;
                    _ = &index_1;
                    if (!((args[@as(c_uint, @intCast(@as(c_int, 2)))].type == @as(c_uint, @bitCast(.VAL_INT))) or (args[@as(c_uint, @intCast(@as(c_int, 2)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE))))) {
                        runtimeError("Third argument must be a number.");
                        return Value{
                            .type = @as(c_uint, @bitCast(.VAL_NIL)),
                            .as = .{
                                .num_int = @as(c_int, 0),
                            },
                        };
                    }
                    obj_h.insertFloatVector(f, index_1, if (args[@as(c_uint, @intCast(@as(c_int, 2)))].type == @as(c_uint, @bitCast(.VAL_INT))) @as(f64, @floatFromInt(args[@as(c_uint, @intCast(@as(c_int, 2)))].as.num_int)) else args[@as(c_uint, @intCast(@as(c_int, 2)))].as.num_double);
                    return Value{
                        .type = @as(c_uint, @bitCast(.VAL_NIL)),
                        .as = .{
                            .num_int = @as(c_int, 0),
                        },
                    };
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 8))) => {
                {
                    var a: [*c]ObjArray = @as([*c]ObjArray, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &a;
                    var index_1: c_int = if (args[@as(c_uint, @intCast(@as(c_int, 1)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE))) @as(c_int, @intFromFloat(args[@as(c_uint, @intCast(@as(c_int, 1)))].as.num_double)) else args[@as(c_uint, @intCast(@as(c_int, 1)))].as.num_int;
                    _ = &index_1;
                    obj_h.insertArray(a, index_1, args[@as(c_uint, @intCast(@as(c_int, 2)))]);
                    return Value{
                        .type = @as(c_uint, @bitCast(.VAL_NIL)),
                        .as = .{
                            .num_int = @as(c_int, 0),
                        },
                    };
                }
            },
            else => {
                runtimeError("Invalid argument type.");
                return Value{
                    .type = @as(c_uint, @bitCast(.VAL_NIL)),
                    .as = .{
                        .num_int = @as(c_int, 0),
                    },
                };
            },
        }
        break;
    }
    return @import("std").mem.zeroes(Value);
}
pub export fn len_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if (((@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_HASH_TABLE)),
        .count = @as(c_int, 1),
    }))) != 0) and (@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_MATRIX)),
        .count = @as(c_int, 1),
    }))) != 0)) and ((@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_LINKED_LIST)),
        .count = @as(c_int, 1),
    }))) != 0) and ((@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_ARRAY)),
        .count = @as(c_int, 1),
    }))) != 0) and (@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_FVECTOR)),
        .count = @as(c_int, 1),
    }))) != 0)))) {
        runtimeError("First argument must be a collection type.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    while (true) {
        switch (args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj.*.type) {
            @as(c_uint, @bitCast(@as(c_int, 8))) => {
                {
                    var a: [*c]ObjArray = @as([*c]ObjArray, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &a;
                    return Value{
                        .type = @as(c_uint, @bitCast(.VAL_INT)),
                        .as = .{
                            .num_int = a.*.count,
                        },
                    };
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 11))) => {
                {
                    var m: [*c]ObjMatrix = @as([*c]ObjMatrix, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &m;
                    return Value{
                        .type = @as(c_uint, @bitCast(.VAL_INT)),
                        .as = .{
                            .num_int = m.*.rows * m.*.cols,
                        },
                    };
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 10))) => {
                {
                    var h: [*c]ObjHashTable = @as([*c]ObjHashTable, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &h;
                    return Value{
                        .type = @as(c_uint, @bitCast(.VAL_INT)),
                        .as = .{
                            .num_int = h.*.table.count,
                        },
                    };
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 12))) => {
                {
                    var f: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &f;
                    return Value{
                        .type = @as(c_uint, @bitCast(.VAL_INT)),
                        .as = .{
                            .num_int = f.*.count,
                        },
                    };
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 9))) => {
                {
                    var l: [*c]ObjLinkedList = @as([*c]ObjLinkedList, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &l;
                    return Value{
                        .type = @as(c_uint, @bitCast(.VAL_INT)),
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
    return @import("std").mem.zeroes(Value);
}
pub export fn search_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if ((@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_LINKED_LIST)),
        .count = @as(c_int, 1),
    }))) != 0) and ((@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_ARRAY)),
        .count = @as(c_int, 1),
    }))) != 0) and (@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_FVECTOR)),
        .count = @as(c_int, 1),
    }))) != 0))) {
        runtimeError("First argument must be a list type.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    while (true) {
        switch (args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj.*.type) {
            @as(c_uint, @bitCast(@as(c_int, 8))) => {
                {
                    var a: [*c]ObjArray = @as([*c]ObjArray, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &a;
                    var result: c_int = obj_h.searchArray(a, args[@as(c_uint, @intCast(@as(c_int, 1)))]);
                    _ = &result;
                    if (result == -@as(c_int, 1)) return Value{
                        .type = @as(c_uint, @bitCast(.VAL_NIL)),
                        .as = .{
                            .num_int = @as(c_int, 0),
                        },
                    };
                    return Value{
                        .type = @as(c_uint, @bitCast(.VAL_INT)),
                        .as = .{
                            .num_int = result,
                        },
                    };
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 12))) => {
                {
                    var f: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &f;
                    var result: c_int = obj_h.searchFloatVector(f, if (args[@as(c_uint, @intCast(@as(c_int, 1)))].type == @as(c_uint, @bitCast(.VAL_INT))) @as(f64, @floatFromInt(args[@as(c_uint, @intCast(@as(c_int, 1)))].as.num_int)) else args[@as(c_uint, @intCast(@as(c_int, 1)))].as.num_double);
                    _ = &result;
                    if (result == -@as(c_int, 1)) return Value{
                        .type = @as(c_uint, @bitCast(.VAL_NIL)),
                        .as = .{
                            .num_int = @as(c_int, 0),
                        },
                    };
                    return Value{
                        .type = @as(c_uint, @bitCast(.VAL_INT)),
                        .as = .{
                            .num_int = result,
                        },
                    };
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 9))) => {
                {
                    var l: [*c]ObjLinkedList = @as([*c]ObjLinkedList, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &l;
                    var result: c_int = obj_h.searchLinkedList(l, args[@as(c_uint, @intCast(@as(c_int, 1)))]);
                    _ = &result;
                    if (result == -@as(c_int, 1)) return Value{
                        .type = @as(c_uint, @bitCast(.VAL_NIL)),
                        .as = .{
                            .num_int = @as(c_int, 0),
                        },
                    };
                    return Value{
                        .type = @as(c_uint, @bitCast(.VAL_INT)),
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
    return @import("std").mem.zeroes(Value);
}
pub export fn is_empty_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if (((@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_HASH_TABLE)),
        .count = @as(c_int, 1),
    }))) != 0) and (@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_MATRIX)),
        .count = @as(c_int, 1),
    }))) != 0)) and ((@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_LINKED_LIST)),
        .count = @as(c_int, 1),
    }))) != 0) and ((@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_ARRAY)),
        .count = @as(c_int, 1),
    }))) != 0) and (@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_FVECTOR)),
        .count = @as(c_int, 1),
    }))) != 0)))) {
        runtimeError("First argument must be a collection type.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    while (true) {
        switch (args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj.*.type) {
            @as(c_uint, @bitCast(@as(c_int, 8))) => {
                {
                    var a: [*c]ObjArray = @as([*c]ObjArray, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &a;
                    return Value{
                        .type = @as(c_uint, @bitCast(.VAL_BOOL)),
                        .as = .{
                            .boolean = a.*.count == @as(c_int, 0),
                        },
                    };
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 10))) => {
                {
                    var h: [*c]ObjHashTable = @as([*c]ObjHashTable, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &h;
                    return Value{
                        .type = @as(c_uint, @bitCast(.VAL_BOOL)),
                        .as = .{
                            .boolean = h.*.table.count == @as(c_int, 0),
                        },
                    };
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 12))) => {
                {
                    var f: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &f;
                    return Value{
                        .type = @as(c_uint, @bitCast(.VAL_BOOL)),
                        .as = .{
                            .boolean = f.*.count == @as(c_int, 0),
                        },
                    };
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 9))) => {
                {
                    var l: [*c]ObjLinkedList = @as([*c]ObjLinkedList, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &l;
                    return Value{
                        .type = @as(c_uint, @bitCast(.VAL_BOOL)),
                        .as = .{
                            .boolean = l.*.count == @as(c_int, 0),
                        },
                    };
                }
            },
            else => {
                {
                    runtimeError("Unsupported type for is_empty().");
                    return Value{
                        .type = @as(c_uint, @bitCast(.VAL_NIL)),
                        .as = .{
                            .num_int = @as(c_int, 0),
                        },
                    };
                }
            },
        }
        break;
    }
    return @import("std").mem.zeroes(Value);
}
pub export fn equal_list_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if (!isObjType(args[@as(c_uint, @intCast(@as(c_int, 0)))], @as(c_uint, @bitCast(.OBJ_ARRAY))) and !isObjType(args[@as(c_uint, @intCast(@as(c_int, 0)))], @as(c_uint, @bitCast(.OBJ_LINKED_LIST)))) {
        runtimeError("First argument must be an array, linked list or vector.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    while (true) {
        switch (args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj.*.type) {
            @as(c_uint, @bitCast(@as(c_int, 8))) => {
                {
                    if (!isObjType(args[@as(c_uint, @intCast(@as(c_int, 1)))], @as(c_uint, @bitCast(.OBJ_ARRAY)))) {
                        runtimeError("Second argument must be an array.");
                        return Value{
                            .type = @as(c_uint, @bitCast(.VAL_NIL)),
                            .as = .{
                                .num_int = @as(c_int, 0),
                            },
                        };
                    }
                    var a: [*c]ObjArray = @as([*c]ObjArray, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &a;
                    var b: [*c]ObjArray = @as([*c]ObjArray, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 1)))].as.obj)));
                    _ = &b;
                    return Value{
                        .type = @as(c_uint, @bitCast(.VAL_BOOL)),
                        .as = .{
                            .boolean = obj_h.equalArray(a, b),
                        },
                    };
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 12))) => {
                {
                    if (!isObjType(args[@as(c_uint, @intCast(@as(c_int, 1)))], @as(c_uint, @bitCast(.OBJ_FVECTOR)))) {
                        runtimeError("Second argument must be a vector.");
                        return Value{
                            .type = @as(c_uint, @bitCast(.VAL_NIL)),
                            .as = .{
                                .num_int = @as(c_int, 0),
                            },
                        };
                    }
                    var a: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &a;
                    var b: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 1)))].as.obj)));
                    _ = &b;
                    return Value{
                        .type = @as(c_uint, @bitCast(.VAL_BOOL)),
                        .as = .{
                            .boolean = obj_h.equalFloatVector(a, b),
                        },
                    };
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 9))) => {
                {
                    if (!isObjType(args[@as(c_uint, @intCast(@as(c_int, 1)))], @as(c_uint, @bitCast(.OBJ_LINKED_LIST)))) {
                        runtimeError("Second argument must be a linked list.");
                        return Value{
                            .type = @as(c_uint, @bitCast(.VAL_NIL)),
                            .as = .{
                                .num_int = @as(c_int, 0),
                            },
                        };
                    }
                    var a: [*c]ObjLinkedList = @as([*c]ObjLinkedList, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &a;
                    var b: [*c]ObjLinkedList = @as([*c]ObjLinkedList, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 1)))].as.obj)));
                    _ = &b;
                    return Value{
                        .type = @as(c_uint, @bitCast(.VAL_BOOL)),
                        .as = .{
                            .boolean = obj_h.equalLinkedList(a, b),
                        },
                    };
                }
            },
            else => {
                {
                    runtimeError("Argument must be a linked list, array or float vector.");
                    return Value{
                        .type = @as(c_uint, @bitCast(.VAL_NIL)),
                        .as = .{
                            .num_int = @as(c_int, 0),
                        },
                    };
                }
            },
        }
        break;
    }
    return @import("std").mem.zeroes(Value);
}
pub export fn reverse_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if ((@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_LINKED_LIST)),
        .count = @as(c_int, 1),
    }))) != 0) and ((@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_ARRAY)),
        .count = @as(c_int, 1),
    }))) != 0) and (@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_FVECTOR)),
        .count = @as(c_int, 1),
    }))) != 0))) {
        runtimeError("First argument must be a list type.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    while (true) {
        switch (args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj.*.type) {
            @as(c_uint, @bitCast(@as(c_int, 8))) => {
                {
                    var a: [*c]ObjArray = @as([*c]ObjArray, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &a;
                    obj_h.reverseArray(a);
                    return Value{
                        .type = @as(c_uint, @bitCast(.VAL_NIL)),
                        .as = .{
                            .num_int = @as(c_int, 0),
                        },
                    };
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 12))) => {
                {
                    var f: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &f;
                    obj_h.reverseFloatVector(f);
                    return Value{
                        .type = @as(c_uint, @bitCast(.VAL_NIL)),
                        .as = .{
                            .num_int = @as(c_int, 0),
                        },
                    };
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 9))) => {
                {
                    var l: [*c]ObjLinkedList = @as([*c]ObjLinkedList, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &l;
                    obj_h.reverseLinkedList(l);
                    return Value{
                        .type = @as(c_uint, @bitCast(.VAL_NIL)),
                        .as = .{
                            .num_int = @as(c_int, 0),
                        },
                    };
                }
            },
            else => break,
        }
        break;
    }
    return @import("std").mem.zeroes(Value);
}
pub export fn merge_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if (argCount != @as(c_int, 2)) {
        runtimeError("merge() takes 2 arguments.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    if ((@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_LINKED_LIST)),
        .count = @as(c_int, 2),
    }))) != 0) and ((@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_ARRAY)),
        .count = @as(c_int, 2),
    }))) != 0) and (@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_FVECTOR)),
        .count = @as(c_int, 2),
    }))) != 0))) {
        runtimeError("Both arguments must be the same list type.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    while (true) {
        switch (args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj.*.type) {
            @as(c_uint, @bitCast(@as(c_int, 8))) => {
                {
                    var a: [*c]ObjArray = @as([*c]ObjArray, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &a;
                    var b: [*c]ObjArray = @as([*c]ObjArray, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 1)))].as.obj)));
                    _ = &b;
                    var c: [*c]ObjArray = obj_h.mergeArrays(a, b);
                    _ = &c;
                    return Value{
                        .type = @as(c_uint, @bitCast(.VAL_OBJ)),
                        .as = .{
                            .obj = @as([*c]Obj, @ptrCast(@alignCast(c))),
                        },
                    };
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 9))) => {
                {
                    var a: [*c]ObjLinkedList = @as([*c]ObjLinkedList, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &a;
                    var b: [*c]ObjLinkedList = @as([*c]ObjLinkedList, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 1)))].as.obj)));
                    _ = &b;
                    var c: [*c]ObjLinkedList = obj_h.mergeLinkedList(a, b);
                    _ = &c;
                    return Value{
                        .type = @as(c_uint, @bitCast(.VAL_OBJ)),
                        .as = .{
                            .obj = @as([*c]Obj, @ptrCast(@alignCast(c))),
                        },
                    };
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 12))) => {
                {
                    var a: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &a;
                    var b: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 1)))].as.obj)));
                    _ = &b;
                    var c: [*c]FloatVector = obj_h.mergeFloatVector(a, b);
                    _ = &c;
                    return Value{
                        .type = @as(c_uint, @bitCast(.VAL_OBJ)),
                        .as = .{
                            .obj = @as([*c]Obj, @ptrCast(@alignCast(c))),
                        },
                    };
                }
            },
            else => return Value{
                .type = @as(c_uint, @bitCast(.VAL_NIL)),
                .as = .{
                    .num_int = @as(c_int, 0),
                },
            },
        }
        break;
    }
    return @import("std").mem.zeroes(Value);
}
pub export fn clone_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if (((@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_HASH_TABLE)),
        .count = @as(c_int, 1),
    }))) != 0) and (@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_MATRIX)),
        .count = @as(c_int, 1),
    }))) != 0)) and ((@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_LINKED_LIST)),
        .count = @as(c_int, 1),
    }))) != 0) and ((@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_ARRAY)),
        .count = @as(c_int, 1),
    }))) != 0) and (@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_FVECTOR)),
        .count = @as(c_int, 1),
    }))) != 0)))) {
        runtimeError("First argument must be an array, linked list or vector.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    while (true) {
        switch (args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj.*.type) {
            @as(c_uint, @bitCast(@as(c_int, 8))) => {
                {
                    var a: [*c]ObjArray = @as([*c]ObjArray, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &a;
                    var c: [*c]ObjArray = obj_h.cloneArray(a);
                    _ = &c;
                    return Value{
                        .type = @as(c_uint, @bitCast(.VAL_OBJ)),
                        .as = .{
                            .obj = @as([*c]Obj, @ptrCast(@alignCast(c))),
                        },
                    };
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 12))) => {
                {
                    var f: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &f;
                    var c: [*c]FloatVector = obj_h.cloneFloatVector(f);
                    _ = &c;
                    return Value{
                        .type = @as(c_uint, @bitCast(.VAL_OBJ)),
                        .as = .{
                            .obj = @as([*c]Obj, @ptrCast(@alignCast(c))),
                        },
                    };
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 9))) => {
                {
                    var l: [*c]ObjLinkedList = @as([*c]ObjLinkedList, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &l;
                    var c: [*c]ObjLinkedList = obj_h.cloneLinkedList(l);
                    _ = &c;
                    return Value{
                        .type = @as(c_uint, @bitCast(.VAL_OBJ)),
                        .as = .{
                            .obj = @as([*c]Obj, @ptrCast(@alignCast(c))),
                        },
                    };
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 10))) => {
                {
                    var h: [*c]ObjHashTable = @as([*c]ObjHashTable, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &h;
                    var c: [*c]ObjHashTable = obj_h.cloneHashTable(h);
                    _ = &c;
                    return Value{
                        .type = @as(c_uint, @bitCast(.VAL_OBJ)),
                        .as = .{
                            .obj = @as([*c]Obj, @ptrCast(@alignCast(c))),
                        },
                    };
                }
            },
            else => {
                runtimeError("Unsupported type for clone().");
                return Value{
                    .type = @as(c_uint, @bitCast(.VAL_NIL)),
                    .as = .{
                        .num_int = @as(c_int, 0),
                    },
                };
            },
        }
        break;
    }
    return @import("std").mem.zeroes(Value);
}
pub export fn clear_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if (((@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_HASH_TABLE)),
        .count = @as(c_int, 1),
    }))) != 0) and (@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_MATRIX)),
        .count = @as(c_int, 1),
    }))) != 0)) and ((@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_LINKED_LIST)),
        .count = @as(c_int, 1),
    }))) != 0) and ((@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_ARRAY)),
        .count = @as(c_int, 1),
    }))) != 0) and (@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_FVECTOR)),
        .count = @as(c_int, 1),
    }))) != 0)))) {
        runtimeError("First argument must be an array, linked list, hash table or vector.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    while (true) {
        switch (args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj.*.type) {
            @as(c_uint, @bitCast(@as(c_int, 8))) => {
                obj_h.clearArray(@as([*c]ObjArray, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj))));
                break;
            },
            @as(c_uint, @bitCast(@as(c_int, 12))) => {
                obj_h.clearFloatVector(@as([*c]FloatVector, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj))));
                break;
            },
            @as(c_uint, @bitCast(@as(c_int, 9))) => {
                obj_h.clearLinkedList(@as([*c]ObjLinkedList, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj))));
                break;
            },
            @as(c_uint, @bitCast(@as(c_int, 10))) => {
                obj_h.clearHashTable(@as([*c]ObjHashTable, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj))));
                break;
            },
            else => {
                runtimeError("Unsupported type for clear().");
                return Value{
                    .type = @as(c_uint, @bitCast(.VAL_NIL)),
                    .as = .{
                        .num_int = @as(c_int, 0),
                    },
                };
            },
        }
        break;
    }
    return Value{
        .type = @as(c_uint, @bitCast(.VAL_NIL)),
        .as = .{
            .num_int = @as(c_int, 0),
        },
    };
}
pub export fn sum_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if ((@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_ARRAY)),
        .count = @as(c_int, 1),
    }))) != 0) and (@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_FVECTOR)),
        .count = @as(c_int, 1),
    }))) != 0)) {
        runtimeError("First argument must be an array or vector.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    while (true) {
        switch (args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj.*.type) {
            @as(c_uint, @bitCast(@as(c_int, 8))) => {
                {
                    var a: [*c]ObjArray = @as([*c]ObjArray, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &a;
                    return obj_h.sumArray(a);
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 12))) => {
                {
                    var f: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &f;
                    return Value{
                        .type = @as(c_uint, @bitCast(.VAL_DOUBLE)),
                        .as = .{
                            .num_double = obj_h.sumFloatVector(f),
                        },
                    };
                }
            },
            else => {
                runtimeError("Unsupported type for clear().");
                return Value{
                    .type = @as(c_uint, @bitCast(.VAL_NIL)),
                    .as = .{
                        .num_int = @as(c_int, 0),
                    },
                };
            },
        }
        break;
    }
    return @import("std").mem.zeroes(Value);
}
pub export fn mean_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if ((@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_ARRAY)),
        .count = @as(c_int, 1),
    }))) != 0) and (@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_FVECTOR)),
        .count = @as(c_int, 1),
    }))) != 0)) {
        runtimeError("First argument must be an array or vector.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    while (true) {
        switch (args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj.*.type) {
            @as(c_uint, @bitCast(@as(c_int, 8))) => return obj_h.meanArray(@as([*c]ObjArray, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)))),
            @as(c_uint, @bitCast(@as(c_int, 12))) => return Value{
                .type = @as(c_uint, @bitCast(.VAL_DOUBLE)),
                .as = .{
                    .num_double = obj_h.meanFloatVector(@as([*c]FloatVector, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)))),
                },
            },
            else => {
                runtimeError("Unsupported type for clear().");
                return Value{
                    .type = @as(c_uint, @bitCast(.VAL_NIL)),
                    .as = .{
                        .num_int = @as(c_int, 0),
                    },
                };
            },
        }
        break;
    }
    return @import("std").mem.zeroes(Value);
}
pub export fn std_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if ((@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_ARRAY)),
        .count = @as(c_int, 1),
    }))) != 0) and (@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_FVECTOR)),
        .count = @as(c_int, 1),
    }))) != 0)) {
        runtimeError("First argument must be an array or vector.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    while (true) {
        switch (args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj.*.type) {
            @as(c_uint, @bitCast(@as(c_int, 8))) => return obj_h.stdDevArray(@as([*c]ObjArray, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)))),
            @as(c_uint, @bitCast(@as(c_int, 12))) => return Value{
                .type = @as(c_uint, @bitCast(.VAL_DOUBLE)),
                .as = .{
                    .num_double = obj_h.stdDevFloatVector(@as([*c]FloatVector, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)))),
                },
            },
            else => {
                runtimeError("Unsupported type for clear().");
                return Value{
                    .type = @as(c_uint, @bitCast(.VAL_NIL)),
                    .as = .{
                        .num_int = @as(c_int, 0),
                    },
                };
            },
        }
        break;
    }
    return @import("std").mem.zeroes(Value);
}
pub export fn var_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if ((@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_ARRAY)),
        .count = @as(c_int, 1),
    }))) != 0) and (@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_FVECTOR)),
        .count = @as(c_int, 1),
    }))) != 0)) {
        runtimeError("First argument must be an array or vector.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    while (true) {
        switch (args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj.*.type) {
            @as(c_uint, @bitCast(@as(c_int, 8))) => {
                {
                    var a: [*c]ObjArray = @as([*c]ObjArray, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &a;
                    return obj_h.varianceArray(a);
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 12))) => {
                {
                    var f: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &f;
                    return Value{
                        .type = @as(c_uint, @bitCast(.VAL_DOUBLE)),
                        .as = .{
                            .num_double = obj_h.varianceFloatVector(f),
                        },
                    };
                }
            },
            else => {
                runtimeError("Unsupported type for clear().");
                return Value{
                    .type = @as(c_uint, @bitCast(.VAL_NIL)),
                    .as = .{
                        .num_int = @as(c_int, 0),
                    },
                };
            },
        }
        break;
    }
    return @import("std").mem.zeroes(Value);
}
pub export fn maxl_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if ((@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_ARRAY)),
        .count = @as(c_int, 1),
    }))) != 0) and (@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_FVECTOR)),
        .count = @as(c_int, 1),
    }))) != 0)) {
        runtimeError("First argument must be an array or vector.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    while (true) {
        switch (args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj.*.type) {
            @as(c_uint, @bitCast(@as(c_int, 8))) => {
                {
                    var a: [*c]ObjArray = @as([*c]ObjArray, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &a;
                    return obj_h.maxArray(a);
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 12))) => {
                {
                    var f: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &f;
                    return Value{
                        .type = @as(c_uint, @bitCast(.VAL_DOUBLE)),
                        .as = .{
                            .num_double = obj_h.maxFloatVector(f),
                        },
                    };
                }
            },
            else => {
                runtimeError("Unsupported type for clear().");
                return Value{
                    .type = @as(c_uint, @bitCast(.VAL_NIL)),
                    .as = .{
                        .num_int = @as(c_int, 0),
                    },
                };
            },
        }
        break;
    }
    return @import("std").mem.zeroes(Value);
}
pub export fn minl_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if ((@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_ARRAY)),
        .count = @as(c_int, 1),
    }))) != 0) and (@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_FVECTOR)),
        .count = @as(c_int, 1),
    }))) != 0)) {
        runtimeError("First argument must be an array or vector.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    while (true) {
        switch (args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj.*.type) {
            @as(c_uint, @bitCast(@as(c_int, 8))) => {
                {
                    var a: [*c]ObjArray = @as([*c]ObjArray, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &a;
                    return obj_h.minArray(a);
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 12))) => {
                {
                    var f: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &f;
                    return Value{
                        .type = @as(c_uint, @bitCast(.VAL_DOUBLE)),
                        .as = .{
                            .num_double = obj_h.minFloatVector(f),
                        },
                    };
                }
            },
            else => {
                runtimeError("Unsupported type for clear().");
                return Value{
                    .type = @as(c_uint, @bitCast(.VAL_NIL)),
                    .as = .{
                        .num_int = @as(c_int, 0),
                    },
                };
            },
        }
        break;
    }
    return @import("std").mem.zeroes(Value);
}
pub export fn dot_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if (!isObjType(args[@as(c_uint, @intCast(@as(c_int, 0)))], @as(c_uint, @bitCast(.OBJ_FVECTOR))) and !isObjType(args[@as(c_uint, @intCast(@as(c_int, 1)))], @as(c_uint, @bitCast(.OBJ_FVECTOR)))) {
        runtimeError("Both arguments must be vectors.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    var a: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
    _ = &a;
    var b: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 1)))].as.obj)));
    _ = &b;
    var result: f64 = obj_h.dotProduct(a, b);
    _ = &result;
    return Value{
        .type = @as(c_uint, @bitCast(.VAL_DOUBLE)),
        .as = .{
            .num_double = result,
        },
    };
}
pub export fn cross_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if (!isObjType(args[@as(c_uint, @intCast(@as(c_int, 0)))], @as(c_uint, @bitCast(.OBJ_FVECTOR))) and !isObjType(args[@as(c_uint, @intCast(@as(c_int, 1)))], @as(c_uint, @bitCast(.OBJ_FVECTOR)))) {
        runtimeError("Both arguments must be vectors.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    var a: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
    _ = &a;
    var b: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 1)))].as.obj)));
    _ = &b;
    var result: [*c]FloatVector = obj_h.crossProduct(a, b);
    _ = &result;
    return Value{
        .type = @as(c_uint, @bitCast(.VAL_OBJ)),
        .as = .{
            .obj = @as([*c]Obj, @ptrCast(@alignCast(result))),
        },
    };
}
pub export fn norm_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if (!isObjType(args[@as(c_uint, @intCast(@as(c_int, 0)))], @as(c_uint, @bitCast(.OBJ_FVECTOR)))) {
        runtimeError("First argument must be a vector.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    var a: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
    _ = &a;
    var result: [*c]FloatVector = obj_h.normalize(a);
    _ = &result;
    return Value{
        .type = @as(c_uint, @bitCast(.VAL_OBJ)),
        .as = .{
            .obj = @as([*c]Obj, @ptrCast(@alignCast(result))),
        },
    };
}
pub export fn proj_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if (!isObjType(args[@as(c_uint, @intCast(@as(c_int, 0)))], @as(c_uint, @bitCast(.OBJ_FVECTOR))) and !isObjType(args[@as(c_uint, @intCast(@as(c_int, 1)))], @as(c_uint, @bitCast(.OBJ_FVECTOR)))) {
        runtimeError("Both arguments must be vectors.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    var a: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
    _ = &a;
    var b: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 1)))].as.obj)));
    _ = &b;
    var result: [*c]FloatVector = obj_h.projection(a, b);
    _ = &result;
    return Value{
        .type = @as(c_uint, @bitCast(.VAL_OBJ)),
        .as = .{
            .obj = @as([*c]Obj, @ptrCast(@alignCast(result))),
        },
    };
}
pub export fn reject_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if (!isObjType(args[@as(c_uint, @intCast(@as(c_int, 0)))], @as(c_uint, @bitCast(.OBJ_FVECTOR))) and !isObjType(args[@as(c_uint, @intCast(@as(c_int, 1)))], @as(c_uint, @bitCast(.OBJ_FVECTOR)))) {
        runtimeError("Both arguments must be vectors.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    var a: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
    _ = &a;
    var b: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 1)))].as.obj)));
    _ = &b;
    var result: [*c]FloatVector = obj_h.rejection(a, b);
    _ = &result;
    return Value{
        .type = @as(c_uint, @bitCast(.VAL_OBJ)),
        .as = .{
            .obj = @as([*c]Obj, @ptrCast(@alignCast(result))),
        },
    };
}
pub export fn reflect_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if (!isObjType(args[@as(c_uint, @intCast(@as(c_int, 0)))], @as(c_uint, @bitCast(.OBJ_FVECTOR))) and !isObjType(args[@as(c_uint, @intCast(@as(c_int, 1)))], @as(c_uint, @bitCast(.OBJ_FVECTOR)))) {
        runtimeError("Both arguments must be vectors.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    var a: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
    _ = &a;
    var b: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 1)))].as.obj)));
    _ = &b;
    var result: [*c]FloatVector = obj_h.reflection(a, b);
    _ = &result;
    return Value{
        .type = @as(c_uint, @bitCast(.VAL_OBJ)),
        .as = .{
            .obj = @as([*c]Obj, @ptrCast(@alignCast(result))),
        },
    };
}
pub export fn refract_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if (((!isObjType(args[@as(c_uint, @intCast(@as(c_int, 0)))], @as(c_uint, @bitCast(.OBJ_FVECTOR))) and !isObjType(args[@as(c_uint, @intCast(@as(c_int, 1)))], @as(c_uint, @bitCast(.OBJ_FVECTOR)))) and !((args[@as(c_uint, @intCast(@as(c_int, 2)))].type == @as(c_uint, @bitCast(.VAL_INT))) or (args[@as(c_uint, @intCast(@as(c_int, 2)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE))))) and !((args[@as(c_uint, @intCast(@as(c_int, 3)))].type == @as(c_uint, @bitCast(.VAL_INT))) or (args[@as(c_uint, @intCast(@as(c_int, 3)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE))))) {
        runtimeError("First and second arguments must be vectors and the third and fourth arguments must be numbers.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    var a: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
    _ = &a;
    var b: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 1)))].as.obj)));
    _ = &b;
    var n1: f64 = if (args[@as(c_uint, @intCast(@as(c_int, 2)))].type == @as(c_uint, @bitCast(.VAL_INT))) @as(f64, @floatFromInt(args[@as(c_uint, @intCast(@as(c_int, 2)))].as.num_int)) else args[@as(c_uint, @intCast(@as(c_int, 2)))].as.num_double;
    _ = &n1;
    var n2: f64 = if (args[@as(c_uint, @intCast(@as(c_int, 3)))].type == @as(c_uint, @bitCast(.VAL_INT))) @as(f64, @floatFromInt(args[@as(c_uint, @intCast(@as(c_int, 3)))].as.num_int)) else args[@as(c_uint, @intCast(@as(c_int, 3)))].as.num_double;
    _ = &n2;
    var result: [*c]FloatVector = obj_h.refraction(a, b, n1, n2);
    _ = &result;
    return Value{
        .type = @as(c_uint, @bitCast(.VAL_OBJ)),
        .as = .{
            .obj = @as([*c]Obj, @ptrCast(@alignCast(result))),
        },
    };
}
pub export fn angle_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if (!isObjType(args[@as(c_uint, @intCast(@as(c_int, 0)))], @as(c_uint, @bitCast(.OBJ_FVECTOR))) or !isObjType(args[@as(c_uint, @intCast(@as(c_int, 1)))], @as(c_uint, @bitCast(.OBJ_FVECTOR)))) {
        runtimeError("Both arguments must be vectors.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    var a: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
    _ = &a;
    var b: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 1)))].as.obj)));
    _ = &b;
    var result: f64 = obj_h.angle(a, b);
    _ = &result;
    return Value{
        .type = @as(c_uint, @bitCast(.VAL_DOUBLE)),
        .as = .{
            .num_double = result,
        },
    };
}
pub export fn put_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if (argCount != @as(c_int, 3)) {
        runtimeError("put() takes 3 arguments.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    if (!isObjType(args[@as(c_uint, @intCast(@as(c_int, 0)))], @as(c_uint, @bitCast(.OBJ_HASH_TABLE)))) {
        runtimeError("First argument must be a hash table.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    if (!isObjType(args[@as(c_uint, @intCast(@as(c_int, 1)))], @as(c_uint, @bitCast(.OBJ_STRING)))) {
        runtimeError("Second argument must be a string.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    var h: [*c]ObjHashTable = @as([*c]ObjHashTable, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
    _ = &h;
    var key: [*c]ObjString = @as([*c]ObjString, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 1)))].as.obj)));
    _ = &key;
    return Value{
        .type = @as(c_uint, @bitCast(.VAL_BOOL)),
        .as = .{
            .boolean = obj_h.putHashTable(h, key, args[@as(c_uint, @intCast(@as(c_int, 2)))]),
        },
    };
}
pub export fn get_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if (argCount != @as(c_int, 2)) {
        runtimeError("get() takes 2 arguments.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    if (!isObjType(args[@as(c_uint, @intCast(@as(c_int, 0)))], @as(c_uint, @bitCast(.OBJ_HASH_TABLE)))) {
        runtimeError("First argument must be a hash table.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    if (!isObjType(args[@as(c_uint, @intCast(@as(c_int, 1)))], @as(c_uint, @bitCast(.OBJ_STRING)))) {
        runtimeError("Second argument must be a string.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    var h: [*c]ObjHashTable = @as([*c]ObjHashTable, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
    _ = &h;
    var key: [*c]ObjString = @as([*c]ObjString, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 1)))].as.obj)));
    _ = &key;
    return obj_h.getHashTable(h, key);
}
pub export fn remove_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if (argCount != @as(c_int, 2)) {
        runtimeError("remove() takes 2 arguments.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    if (!isObjType(args[@as(c_uint, @intCast(@as(c_int, 0)))], @as(c_uint, @bitCast(.OBJ_HASH_TABLE))) and ((@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_ARRAY)),
        .count = @as(c_int, 1),
    }))) != 0) and (@as(c_int, @intFromBool(notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = @as(c_uint, @bitCast(.OBJ_FVECTOR)),
        .count = @as(c_int, 1),
    }))) != 0))) {
        runtimeError("First argument must be a hash table, array, or float vector.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    if (!isObjType(args[@as(c_uint, @intCast(@as(c_int, 1)))], @as(c_uint, @bitCast(.OBJ_STRING))) and !((args[@as(c_uint, @intCast(@as(c_int, 1)))].type == @as(c_uint, @bitCast(.VAL_INT))) or (args[@as(c_uint, @intCast(@as(c_int, 1)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE))))) {
        runtimeError("Second argument must be a string or number.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    while (true) {
        switch (args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj.*.type) {
            @as(c_uint, @bitCast(@as(c_int, 10))) => {
                {
                    var h: [*c]ObjHashTable = @as([*c]ObjHashTable, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
                    _ = &h;
                    var key: [*c]ObjString = @as([*c]ObjString, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 1)))].as.obj)));
                    _ = &key;
                    return Value{
                        .type = @as(c_uint, @bitCast(.VAL_BOOL)),
                        .as = .{
                            .boolean = obj_h.removeHashTable(h, key),
                        },
                    };
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 8))) => {
                {
                    return obj_h.removeArray(@as([*c]ObjArray, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj))), if (args[@as(c_uint, @intCast(@as(c_int, 1)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE))) @as(c_int, @intFromFloat(args[@as(c_uint, @intCast(@as(c_int, 1)))].as.num_double)) else args[@as(c_uint, @intCast(@as(c_int, 1)))].as.num_int);
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 12))) => {
                {
                    return Value{
                        .type = @as(c_uint, @bitCast(.VAL_DOUBLE)),
                        .as = .{
                            .num_double = obj_h.removeFloatVector(@as([*c]FloatVector, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj))), if (args[@as(c_uint, @intCast(@as(c_int, 1)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE))) @as(c_int, @intFromFloat(args[@as(c_uint, @intCast(@as(c_int, 1)))].as.num_double)) else args[@as(c_uint, @intCast(@as(c_int, 1)))].as.num_int),
                        },
                    };
                }
            },
            else => {
                {
                    runtimeError("Argument must be a hash table, array or float vector.");
                    return Value{
                        .type = @as(c_uint, @bitCast(.VAL_NIL)),
                        .as = .{
                            .num_int = @as(c_int, 0),
                        },
                    };
                }
            },
        }
        break;
    }
    return @import("std").mem.zeroes(Value);
}
pub export fn push_front_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if (!isObjType(args[@as(c_uint, @intCast(@as(c_int, 0)))], @as(c_uint, @bitCast(.OBJ_LINKED_LIST)))) {
        runtimeError("First argument must be a linked list.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    var l: [*c]ObjLinkedList = @as([*c]ObjLinkedList, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
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
        .type = @as(c_uint, @bitCast(.VAL_NIL)),
        .as = .{
            .num_int = @as(c_int, 0),
        },
    };
}
pub export fn pop_front_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if (!isObjType(args[@as(c_uint, @intCast(@as(c_int, 0)))], @as(c_uint, @bitCast(.OBJ_LINKED_LIST)))) {
        runtimeError("First argument must be a linked list.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    var l: [*c]ObjLinkedList = @as([*c]ObjLinkedList, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
    _ = &l;
    return obj_h.popFront(l);
}
pub export fn set_row_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if (!isObjType(args[@as(c_uint, @intCast(@as(c_int, 0)))], @as(c_uint, @bitCast(.OBJ_MATRIX)))) {
        runtimeError("First argument must be a matrix.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    if (!((args[@as(c_uint, @intCast(@as(c_int, 1)))].type == @as(c_uint, @bitCast(.VAL_INT))) or (args[@as(c_uint, @intCast(@as(c_int, 1)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE))))) {
        runtimeError("Second argument must be an numbers.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    if (!isObjType(args[@as(c_uint, @intCast(@as(c_int, 2)))], @as(c_uint, @bitCast(.OBJ_ARRAY)))) {
        runtimeError("Third argument must be an array.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    var matrix: [*c]ObjMatrix = @as([*c]ObjMatrix, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
    _ = &matrix;
    var row: c_int = if (args[@as(c_uint, @intCast(@as(c_int, 1)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE))) @as(c_int, @intFromFloat(args[@as(c_uint, @intCast(@as(c_int, 1)))].as.num_double)) else args[@as(c_uint, @intCast(@as(c_int, 1)))].as.num_int;
    _ = &row;
    var array: [*c]ObjArray = @as([*c]ObjArray, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 2)))].as.obj)));
    _ = &array;
    obj_h.setRow(matrix, row, array);
    return Value{
        .type = @as(c_uint, @bitCast(.VAL_NIL)),
        .as = .{
            .num_int = @as(c_int, 0),
        },
    };
}
pub export fn set_col_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if (!isObjType(args[@as(c_uint, @intCast(@as(c_int, 0)))], @as(c_uint, @bitCast(.OBJ_MATRIX)))) {
        runtimeError("First argument must be a matrix.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    if (!((args[@as(c_uint, @intCast(@as(c_int, 1)))].type == @as(c_uint, @bitCast(.VAL_INT))) or (args[@as(c_uint, @intCast(@as(c_int, 1)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE))))) {
        runtimeError("Second argument must be an numbers.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    if (!isObjType(args[@as(c_uint, @intCast(@as(c_int, 2)))], @as(c_uint, @bitCast(.OBJ_ARRAY)))) {
        runtimeError("Third argument must be an array.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    var matrix: [*c]ObjMatrix = @as([*c]ObjMatrix, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
    _ = &matrix;
    var col: c_int = if (args[@as(c_uint, @intCast(@as(c_int, 1)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE))) @as(c_int, @intFromFloat(args[@as(c_uint, @intCast(@as(c_int, 1)))].as.num_double)) else args[@as(c_uint, @intCast(@as(c_int, 1)))].as.num_int;
    _ = &col;
    var array: [*c]ObjArray = @as([*c]ObjArray, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 2)))].as.obj)));
    _ = &array;
    obj_h.setCol(matrix, col, array);
    return Value{
        .type = @as(c_uint, @bitCast(.VAL_NIL)),
        .as = .{
            .num_int = @as(c_int, 0),
        },
    };
}

pub export fn set_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if (argCount != @as(c_int, 4)) {
        runtimeError("set() takes 4 arguments.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    if (!isObjType(args[@as(c_uint, @intCast(@as(c_int, 0)))], @as(c_uint, @bitCast(.OBJ_MATRIX)))) {
        runtimeError("First argument must be a matrix.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    if (!((args[@as(c_uint, @intCast(@as(c_int, 1)))].type == @as(c_uint, @bitCast(.VAL_INT))) or (args[@as(c_uint, @intCast(@as(c_int, 1)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE))))) {
        runtimeError("Second argument must be an numbers.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    if (!((args[@as(c_uint, @intCast(@as(c_int, 2)))].type == @as(c_uint, @bitCast(.VAL_INT))) or (args[@as(c_uint, @intCast(@as(c_int, 2)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE))))) {
        runtimeError("Third argument must be an numbers.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    var matrix: [*c]ObjMatrix = @as([*c]ObjMatrix, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
    _ = &matrix;
    var row: c_int = if (args[@as(c_uint, @intCast(@as(c_int, 1)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE))) @as(c_int, @intFromFloat(args[@as(c_uint, @intCast(@as(c_int, 1)))].as.num_double)) else args[@as(c_uint, @intCast(@as(c_int, 1)))].as.num_int;
    _ = &row;
    var col: c_int = if (args[@as(c_uint, @intCast(@as(c_int, 2)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE))) @as(c_int, @intFromFloat(args[@as(c_uint, @intCast(@as(c_int, 2)))].as.num_double)) else args[@as(c_uint, @intCast(@as(c_int, 2)))].as.num_int;
    _ = &col;
    obj_h.setMatrix(matrix, row, col, args[@as(c_uint, @intCast(@as(c_int, 3)))]);
    return Value{
        .type = @as(c_uint, @bitCast(.VAL_NIL)),
        .as = .{
            .num_int = @as(c_int, 0),
        },
    };
}
pub export fn kolasa_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if (argCount != @as(c_int, 0)) {
        runtimeError("kolasa() takes no arguments.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
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
                .type = @as(c_uint, @bitCast(.VAL_DOUBLE)),
                .as = .{
                    .num_double = @as(f64, @floatFromInt(i + @as(c_int, 1))),
                },
            };
        }
    }
    return Value{
        .type = @as(c_uint, @bitCast(.VAL_OBJ)),
        .as = .{
            .obj = @as([*c]Obj, @ptrCast(@alignCast(m))),
        },
    };
}
pub export fn rref_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if (!isObjType(args[@as(c_uint, @intCast(@as(c_int, 0)))], @as(c_uint, @bitCast(.OBJ_MATRIX)))) {
        runtimeError("First argument must be a matrix.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    var m: [*c]ObjMatrix = @as([*c]ObjMatrix, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
    _ = &m;
    obj_h.rref(m);
    return Value{
        .type = @as(c_uint, @bitCast(.VAL_NIL)),
        .as = .{
            .num_int = @as(c_int, 0),
        },
    };
}
pub export fn rank_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if (!isObjType(args[@as(c_uint, @intCast(@as(c_int, 0)))], @as(c_uint, @bitCast(.OBJ_MATRIX)))) {
        runtimeError("First argument must be a matrix.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    var m: [*c]ObjMatrix = @as([*c]ObjMatrix, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
    _ = &m;
    return Value{
        .type = @as(c_uint, @bitCast(.VAL_INT)),
        .as = .{
            .num_int = obj_h.rank(m),
        },
    };
}
pub export fn transpose_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if (!isObjType(args[@as(c_uint, @intCast(@as(c_int, 0)))], @as(c_uint, @bitCast(.OBJ_MATRIX)))) {
        runtimeError("First argument must be a matrix.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    var m: [*c]ObjMatrix = @as([*c]ObjMatrix, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
    _ = &m;
    var t: [*c]ObjMatrix = obj_h.transposeMatrix(m);
    _ = &t;
    return Value{
        .type = @as(c_uint, @bitCast(.VAL_OBJ)),
        .as = .{
            .obj = @as([*c]Obj, @ptrCast(@alignCast(t))),
        },
    };
}
pub export fn determinant_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if (!isObjType(args[@as(c_uint, @intCast(@as(c_int, 0)))], @as(c_uint, @bitCast(.OBJ_MATRIX)))) {
        runtimeError("First argument must be a matrix.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    var m: [*c]ObjMatrix = @as([*c]ObjMatrix, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
    _ = &m;
    return Value{
        .type = @as(c_uint, @bitCast(.VAL_DOUBLE)),
        .as = .{
            .num_double = obj_h.determinant(m),
        },
    };
}
pub export fn lu_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if (!isObjType(args[@as(c_uint, @intCast(@as(c_int, 0)))], @as(c_uint, @bitCast(.OBJ_MATRIX)))) {
        runtimeError("First argument must be a matrix.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    var m: [*c]ObjMatrix = @as([*c]ObjMatrix, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
    _ = &m;
    var result: [*c]ObjMatrix = obj_h.lu(m);
    _ = &result;
    return Value{
        .type = @as(c_uint, @bitCast(.VAL_OBJ)),
        .as = .{
            .obj = @as([*c]Obj, @ptrCast(@alignCast(result))),
        },
    };
}
pub export fn workspace_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if (argCount != @as(c_int, 0)) {
        runtimeError("workspace() takes no arguments.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    var e: [*c]Entry = entries_(&vm.globals);
    _ = &e;
    _ = printf("Workspace:\n");
    {
        var i: c_int = 0;
        _ = &i;
        while (i < vm.globals.capacity) : (i += 1) {
            if (((blk: {
                const tmp = i;
                if (tmp >= 0) break :blk e + @as(usize, @intCast(tmp)) else break :blk e - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*.key != @as([*c]ObjString, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) and !isObjType((blk: {
                const tmp = i;
                if (tmp >= 0) break :blk e + @as(usize, @intCast(tmp)) else break :blk e - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*.value, @as(c_uint, @bitCast(.OBJ_NATIVE)))) {
                _ = printf("%s: ", (blk: {
                    const tmp = i;
                    if (tmp >= 0) break :blk e + @as(usize, @intCast(tmp)) else break :blk e - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                }).*.key.*.chars);
                if (isObjType((blk: {
                    const tmp = i;
                    if (tmp >= 0) break :blk e + @as(usize, @intCast(tmp)) else break :blk e - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                }).*.value, @as(c_uint, @bitCast(.OBJ_MATRIX)))) {
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
        .type = @as(c_uint, @bitCast(.VAL_NIL)),
        .as = .{
            .num_int = @as(c_int, 0),
        },
    };
}
pub export fn linspace_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if (argCount != @as(c_int, 3)) {
        runtimeError("linspace() takes 3 arguments.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    if ((!((args[@as(c_uint, @intCast(@as(c_int, 0)))].type == @as(c_uint, @bitCast(.VAL_INT))) or (args[@as(c_uint, @intCast(@as(c_int, 0)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE)))) and !((args[@as(c_uint, @intCast(@as(c_int, 1)))].type == @as(c_uint, @bitCast(.VAL_INT))) or (args[@as(c_uint, @intCast(@as(c_int, 1)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE))))) and !((args[@as(c_uint, @intCast(@as(c_int, 2)))].type == @as(c_uint, @bitCast(.VAL_INT))) or (args[@as(c_uint, @intCast(@as(c_int, 2)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE))))) {
        runtimeError("First and second arguments must be numbers and the third argument must be an numbers.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    var start: f64 = if (args[@as(c_uint, @intCast(@as(c_int, 0)))].type == @as(c_uint, @bitCast(.VAL_INT))) @as(f64, @floatFromInt(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.num_int)) else args[@as(c_uint, @intCast(@as(c_int, 0)))].as.num_double;
    _ = &start;
    var end: f64 = if (args[@as(c_uint, @intCast(@as(c_int, 1)))].type == @as(c_uint, @bitCast(.VAL_INT))) @as(f64, @floatFromInt(args[@as(c_uint, @intCast(@as(c_int, 1)))].as.num_int)) else args[@as(c_uint, @intCast(@as(c_int, 1)))].as.num_double;
    _ = &end;
    var n: c_int = if (args[@as(c_uint, @intCast(@as(c_int, 2)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE))) @as(c_int, @intFromFloat(args[@as(c_uint, @intCast(@as(c_int, 2)))].as.num_double)) else args[@as(c_uint, @intCast(@as(c_int, 2)))].as.num_int;
    _ = &n;
    var a: [*c]FloatVector = obj_h.linspace(start, end, n);
    _ = &a;
    return Value{
        .type = @as(c_uint, @bitCast(.VAL_OBJ)),
        .as = .{
            .obj = @as([*c]Obj, @ptrCast(@alignCast(a))),
        },
    };
}
pub export fn interp1_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if (argCount != @as(c_int, 3)) {
        runtimeError("interp1() takes 3 arguments.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    if ((!isObjType(args[@as(c_uint, @intCast(@as(c_int, 0)))], @as(c_uint, @bitCast(.OBJ_FVECTOR))) and !isObjType(args[@as(c_uint, @intCast(@as(c_int, 1)))], @as(c_uint, @bitCast(.OBJ_FVECTOR)))) and !((args[@as(c_uint, @intCast(@as(c_int, 2)))].type == @as(c_uint, @bitCast(.VAL_INT))) or (args[@as(c_uint, @intCast(@as(c_int, 2)))].type == @as(c_uint, @bitCast(.VAL_DOUBLE))))) {
        runtimeError("First and second arguments must be vectors and the third argument must be a number.");
        return Value{
            .type = @as(c_uint, @bitCast(.VAL_NIL)),
            .as = .{
                .num_int = @as(c_int, 0),
            },
        };
    }
    var x: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 0)))].as.obj)));
    _ = &x;
    var y: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(args[@as(c_uint, @intCast(@as(c_int, 1)))].as.obj)));
    _ = &y;
    var x0: f64 = if (args[@as(c_uint, @intCast(@as(c_int, 2)))].type == @as(c_uint, @bitCast(.VAL_INT))) @as(f64, @floatFromInt(args[@as(c_uint, @intCast(@as(c_int, 2)))].as.num_int)) else args[@as(c_uint, @intCast(@as(c_int, 2)))].as.num_double;
    _ = &x0;
    var result: f64 = obj_h.interp1(x, y, x0);
    _ = &result;
    return Value{
        .type = @as(c_uint, @bitCast(.VAL_DOUBLE)),
        .as = .{
            .num_double = result,
        },
    };
}
pub export fn simd_stat_nf(arg_argCount: c_int, arg_args: [*c]Value) Value {
    var argCount = arg_argCount;
    _ = &argCount;
    var args = arg_args;
    _ = &args;
    if (argCount != @as(c_int, 0)) {
        runtimeError("simd_stat() takes 0 arguments.");
    }
    _ = printf("x86_64 SIMD AVX2 Enabled\n");
    return Value{
        .type = @as(c_uint, @bitCast(.VAL_NIL)),
        .as = .{
            .num_int = @as(c_int, 0),
        },
    };
}
