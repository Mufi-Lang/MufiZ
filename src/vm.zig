const chunk_h = @import("chunk.zig");
const value_h = @import("value.zig");
const table_h = @import("table.zig");
const object_h = @import("object.zig");
const cstd_h = @import("cstd.zig");
const debug_h = @import("debug.zig");
const compiler_h = @import("compiler.zig");
const memory_h = @import("memory.zig");
const debug_opts = @import("debug");
const reallocate = memory_h.reallocate;
const memcpy = @cImport(@cInclude("string.h")).memcpy;
const strlen = @cImport(@cInclude("string.h")).strlen;
const ObjClosure = object_h.ObjClosure;
const ObjString = object_h.ObjString;
const ObjUpvalue = object_h.ObjUpvalue;
const ObjFunction = object_h.ObjFunction;
const ObjNative = object_h.ObjNative;
const ObjArray = object_h.ObjArray;
const FloatVector = object_h.FloatVector;
const printf = @cImport(@cInclude("stdio.h")).printf;
const printValue = value_h.printValue;
const tableGet = table_h.tableGet;
const tableSet = table_h.tableSet;
const tableDelete = table_h.tableDelete;
const isObjType = object_h.isObjType;
const newUpvalue = object_h.newUpvalue;
const newBoundMethod = object_h.newBoundMethod;
const ObjInstance = object_h.ObjInstance;
const newInstance = object_h.newInstance;
const newArrayWithCap = object_h.newArrayWithCap;
const takeString = object_h.takeString;
const pushArray = object_h.pushArray;
const newFloatVector = object_h.newFloatVector;
const pushFloatVector = object_h.pushFloatVector;
const equalArray = object_h.equalArray;
const ObjLinkedList = object_h.ObjLinkedList;
const equalLinkedList = object_h.equalLinkedList;
const valuesEqual = value_h.valuesEqual;
const addArray = object_h.addArray;
const addFloatVector = object_h.addFloatVector;
const singleAddFloatVector = object_h.singleAddFloatVector;
const ObjMatrix = object_h.ObjMatrix;
const addMatrix = object_h.addMatrix;
const subMatrix = object_h.subMatrix;
const subArray = object_h.subArray;
const subFloatVector = object_h.subFloatVector;
const singleSubFloatVector = object_h.singleSubFloatVector;
const mulMatrix = object_h.mulMatrix;
const mulArray = object_h.mulArray;
const mulFloatVector = object_h.mulFloatVector;
const scaleFloatVector = object_h.scaleFloatVector;
const divMatrix = object_h.divMatrix;
const divFloatVector = object_h.divFloatVector;
const divArray = object_h.divArray;
const singleDivFloatVector = object_h.singleDivFloatVector;
const Obj = object_h.Obj;
const Value = value_h.Value;
const Chunk = chunk_h.Chunk;
const Table = table_h.Table;
const NativeFn = object_h.NativeFn;
const ObjBoundMethod = object_h.ObjBoundMethod;
const ObjClass = object_h.ObjClass;
const Complex = value_h.Complex;
const std = @import("std");
const print = std.debug.print;
const sqrt = std.math.sqrt;
const atan2 = std.math.atan2;
const cos = std.math.cos;
const sin = std.math.sin;

pub const FRAMES_MAX = @as(c_int, 64);
pub const STACK_MAX = FRAMES_MAX * UINT8_COUNT;
pub const UINT8_COUNT = UINT8_MAX + 1;
pub const UINT8_MAX: c_int = @intCast(std.math.maxInt(u8));

pub const CallFrame = extern struct {
    closure: [*c]ObjClosure,
    ip: [*c]u8,
    slots: [*c]Value,
};

pub const VM = struct {
    frames: [64]CallFrame = std.mem.zeroes([64]CallFrame),
    frameCount: c_int = 0,
    chunk: [*c]Chunk = null,
    ip: [*c]u8 = null,
    stack: [16384]Value,
    stackTop: [*c]Value = null,
    globals: Table,
    strings: Table,
    initString: [*c]ObjString = copyString(@ptrCast("init"), 4),
    openUpvalues: [*c]ObjUpvalue = null,
    bytesAllocated: u128 = 0,
    nextGC: u128 = 1024 * 1024,
    objects: [*c]Obj = null,
    grayCount: c_int = 0,
    grayCapacity: c_int = 0,
    grayStack: [*c][*c]Obj = null,
};

pub export fn initVM() void {
    resetStack();
    initTable(&vm.globals);
    initTable(&vm.strings);
}

pub const InterpretResult = enum(c_int) {
    INTERPRET_OK = 0,
    INTERPRET_COMPILE_ERROR = 1,
    INTERPRET_RUNTIME_ERROR = 2,
};

inline fn pow(a: f64, b: f64) f64 {
    return std.math.pow(f64, a, b);
}

pub var vm: VM = undefined;

const initTable = table_h.initTable;
const freeTable = table_h.freeTable;
const copyString = object_h.copyString;
const freeObjects = memory_h.freeObjects;

// todo!()
pub fn runtimeError(comptime format: []const u8, args: anytype) void {
    const stderr = std.io.getStdErr().writer();
    stderr.print(format, args) catch {};
    stderr.writeByte('\n') catch {};

    var i: i32 = @intCast(vm.frameCount - 1);
    while (i >= 0) : (i -= 1) {
        const frame = &vm.frames[@intCast(i)];
        const function = frame.*.closure.*.function;
        const instruction: usize = @intFromPtr(frame.ip) - @intFromPtr(function.*.chunk.code) - 1;

        stderr.print("[line {d}] in ", .{function.*.chunk.lines[instruction]}) catch {};

        if (function.*.name == null) {
            stderr.writeAll("script\n") catch {};
        } else {
            const name = function.*.name.*.chars;
            const len: usize = @intCast(function.*.name.*.length);
            stderr.print("{s}()\n", .{@as([]u8, @ptrCast(@alignCast(name[0..len])))}) catch {};
        }
    }

    resetStack();
}

pub export fn freeVM() void {
    freeTable(&vm.globals);
    freeTable(&vm.strings);
    vm.initString = null;
    freeObjects();
}
pub export fn importCollections() void {
    defineNative("assert", cstd_h.assert_nf);
    defineNative("simd_stat", &cstd_h.simd_stat_nf);
    defineNative("array", &cstd_h.array_nf);
    defineNative("linked_list", &cstd_h.linkedlist_nf);
    defineNative("hash_table", &cstd_h.hashtable_nf);
    defineNative("matrix", &cstd_h.matrix_nf);
    defineNative("fvec", &cstd_h.fvector_nf);
    defineNative("range", &cstd_h.range_nf);
    defineNative("linspace", &cstd_h.linspace_nf);
    defineNative("slice", &cstd_h.slice_nf);
    defineNative("splice", &cstd_h.splice_nf);
    defineNative("push", &cstd_h.push_nf);
    defineNative("pop", &cstd_h.pop_nf);
    defineNative("push_front", &cstd_h.push_front_nf);
    defineNative("pop_front", &cstd_h.pop_front_nf);
    defineNative("nth", &cstd_h.nth_nf);
    defineNative("sort", &cstd_h.sort_nf);
    defineNative("contains", &cstd_h.contains_nf);
    defineNative("insert", &cstd_h.insert_nf);
    defineNative("len", &cstd_h.len_nf);
    defineNative("search", &cstd_h.search_nf);
    defineNative("is_empty", &cstd_h.is_empty_nf);
    defineNative("equal_list", &cstd_h.equal_list_nf);
    defineNative("reverse", &cstd_h.reverse_nf);
    defineNative("merge", &cstd_h.merge_nf);
    defineNative("clone", &cstd_h.clone_nf);
    defineNative("clear", &cstd_h.clear_nf);
    defineNative("next", &cstd_h.next_nf);
    defineNative("has_next", &cstd_h.hasNext_nf);
    defineNative("reset", &cstd_h.reset_nf);
    defineNative("skip", &cstd_h.skip_nf);
    defineNative("put", &cstd_h.put_nf);
    defineNative("get", &cstd_h.get_nf);
    defineNative("remove", &cstd_h.remove_nf);
    defineNative("set_row", &cstd_h.set_row_nf);
    defineNative("set_col", &cstd_h.set_col_nf);
    defineNative("set", &cstd_h.set_nf);
    defineNative("kolasa", &cstd_h.kolasa_nf);
    defineNative("rref", &cstd_h.rref_nf);
    defineNative("rank", &cstd_h.rank_nf);
    defineNative("transpose", &cstd_h.transpose_nf);
    defineNative("det", &cstd_h.determinant_nf);
    defineNative("lu", &cstd_h.lu_nf);
    defineNative("workspace", &cstd_h.workspace_nf);
    defineNative("interp1", &cstd_h.interp1_nf);
    defineNative("sum", &cstd_h.sum_nf);
    defineNative("mean", &cstd_h.mean_nf);
    defineNative("std", &cstd_h.std_nf);
    defineNative("vari", &cstd_h.var_nf);
    defineNative("maxl", &cstd_h.maxl_nf);
    defineNative("minl", &cstd_h.minl_nf);
    defineNative("dot", &cstd_h.dot_nf);
    defineNative("cross", &cstd_h.cross_nf);
    defineNative("norm", &cstd_h.norm_nf);
    defineNative("angle", &cstd_h.angle_nf);
    defineNative("proj", &cstd_h.proj_nf);
    defineNative("reflect", &cstd_h.reflect_nf);
    defineNative("reject", &cstd_h.reject_nf);
    defineNative("refract", &cstd_h.refract_nf);
}

inline fn zstr(s: [*c]ObjString) []u8 {
    const len: usize = @intCast(s.*.length);
    return @ptrCast(@alignCast(s.*.chars[0..len]));
}

pub export fn interpret(arg_source: [*c]const u8) InterpretResult {
    var source = arg_source;
    _ = &source;
    var function: [*c]ObjFunction = compiler_h.compile(source);
    _ = &function;
    if (function == null) return .INTERPRET_COMPILE_ERROR;
    push(Value{
        .type = .VAL_OBJ,
        .as = .{
            .obj = @as([*c]Obj, @ptrCast(@alignCast(function))),
        },
    });
    var closure: [*c]ObjClosure = object_h.newClosure(function);
    _ = &closure;
    _ = pop();
    push(Value{
        .type = .VAL_OBJ,
        .as = .{
            .obj = @as([*c]Obj, @ptrCast(@alignCast(closure))),
        },
    });
    _ = call(closure, 0);
    return run();
}
pub export fn push(arg_value: Value) void {
    var value = arg_value;
    _ = &value;
    vm.stackTop.* = value;
    vm.stackTop += 1;
}
pub export fn pop() Value {
    vm.stackTop -= 1;
    return vm.stackTop.*;
}
pub export fn defineNative(arg_name: [*c]const u8, arg_function: NativeFn) void {
    var name = arg_name;
    _ = &name;
    var function = arg_function;
    _ = &function;
    push(Value{
        .type = .VAL_OBJ,
        .as = .{
            .obj = @as([*c]Obj, @ptrCast(@alignCast(copyString(name, @as(c_int, @bitCast(@as(c_uint, @truncate(strlen(name))))))))),
        },
    });
    push(Value{
        .type = .VAL_OBJ,
        .as = .{
            .obj = @as([*c]Obj, @ptrCast(@alignCast(object_h.newNative(function)))),
        },
    });
    _ = table_h.tableSet(&vm.globals, @as([*c]ObjString, @ptrCast(@alignCast(vm.stack[@as(c_uint, @intCast(0))].as.obj))), vm.stack[@as(c_uint, @intCast(1))]);
    _ = pop();
    _ = pop();
}

pub fn resetStack() callconv(.C) void {
    vm.stackTop = @as([*c]Value, @ptrCast(@alignCast(&vm.stack)));
    vm.frameCount = 0;
    vm.openUpvalues = null;
}
pub fn peek(arg_distance: c_int) callconv(.C) Value {
    var distance = arg_distance;
    _ = &distance;
    return (blk: {
        const tmp = -1 - distance;
        if (tmp >= 0) break :blk vm.stackTop + @as(usize, @intCast(tmp)) else break :blk vm.stackTop - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).*;
}
pub fn call(arg_closure: [*c]ObjClosure, arg_argCount: c_int) callconv(.C) bool {
    var closure = arg_closure;
    _ = &closure;
    var argCount = arg_argCount;
    _ = &argCount;
    if (argCount != closure.*.function.*.arity) {
        runtimeError("Expected {d} arguments but got {d}.", .{ closure.*.function.*.arity, argCount });
        return false;
    }
    if (vm.frameCount == @as(c_int, 64)) {
        runtimeError("Stack overflow.", .{});
        return false;
    }
    var frame: [*c]CallFrame = &vm.frames[
        @as(c_uint, @intCast(blk: {
            const ref = &vm.frameCount;
            const tmp = ref.*;
            ref.* += 1;
            break :blk tmp;
        }))
    ];
    _ = &frame;
    frame.*.closure = closure;
    frame.*.ip = closure.*.function.*.chunk.code;
    frame.*.slots = (vm.stackTop - @as(usize, @bitCast(@as(isize, @intCast(argCount))))) - @as(usize, @bitCast(@as(isize, @intCast(1))));
    return true;
}
pub fn callValue(arg_callee: Value, arg_argCount: c_int) callconv(.C) bool {
    var callee = arg_callee;
    _ = &callee;
    var argCount = arg_argCount;
    _ = &argCount;
    if (callee.type == .VAL_OBJ) {
        while (true) {
            switch (callee.as.obj.*.type) {
                .OBJ_BOUND_METHOD => {
                    {
                        var bound: [*c]ObjBoundMethod = @as([*c]ObjBoundMethod, @ptrCast(@alignCast(callee.as.obj)));
                        _ = &bound;
                        (blk: {
                            const tmp = -argCount - 1;
                            if (tmp >= 0) break :blk vm.stackTop + @as(usize, @intCast(tmp)) else break :blk vm.stackTop - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                        }).* = bound.*.receiver;
                        return call(bound.*.method, argCount);
                    }
                },
                .OBJ_CLASS => {
                    {
                        var klass: [*c]ObjClass = @as([*c]ObjClass, @ptrCast(@alignCast(callee.as.obj)));
                        _ = &klass;
                        (blk: {
                            const tmp = -argCount - 1;
                            if (tmp >= 0) break :blk vm.stackTop + @as(usize, @intCast(tmp)) else break :blk vm.stackTop - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                        }).* = Value{
                            .type = .VAL_OBJ,
                            .as = .{
                                .obj = @as([*c]Obj, @ptrCast(@alignCast(object_h.newInstance(klass)))),
                            },
                        };
                        var initializer: Value = undefined;
                        _ = &initializer;
                        if (tableGet(&klass.*.methods, vm.initString, &initializer)) {
                            return call(@as([*c]ObjClosure, @ptrCast(@alignCast(initializer.as.obj))), argCount);
                        } else if (argCount != 0) {
                            runtimeError("Expected 0 arguments but got {d}.", .{argCount});
                            return false;
                        }
                        return true;
                    }
                },
                .OBJ_CLOSURE => return call(@as([*c]ObjClosure, @ptrCast(@alignCast(callee.as.obj))), argCount),
                .OBJ_INSTANCE => {
                    {
                        var klass: [*c]ObjClass = @as([*c]ObjClass, @ptrCast(@alignCast(callee.as.obj)));
                        _ = &klass;
                        (blk: {
                            const tmp = -argCount - 1;
                            if (tmp >= 0) break :blk vm.stackTop + @as(usize, @intCast(tmp)) else break :blk vm.stackTop - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                        }).* = Value{
                            .type = .VAL_OBJ,
                            .as = .{
                                .obj = @as([*c]Obj, @ptrCast(@alignCast(object_h.newInstance(klass)))),
                            },
                        };
                        return true;
                    }
                },
                .OBJ_NATIVE => {
                    {
                        var native: NativeFn = @as([*c]ObjNative, @ptrCast(@alignCast(callee.as.obj))).*.function;
                        _ = &native;
                        var result: Value = native.?(argCount, vm.stackTop - @as(usize, @bitCast(@as(isize, @intCast(argCount)))));
                        _ = &result;
                        vm.stackTop -= @as(usize, @bitCast(@as(isize, @intCast(argCount + 1))));
                        push(result);
                        return true;
                    }
                },
                else => break,
            }
            break;
        }
    }
    runtimeError("Can only call functions and classes.", .{});
    return false;
}
pub fn invokeFromClass(arg_klass: [*c]ObjClass, arg_name: [*c]ObjString, arg_argCount: c_int) callconv(.C) bool {
    var klass = arg_klass;
    _ = &klass;
    var name = arg_name;
    _ = &name;
    var argCount = arg_argCount;
    _ = &argCount;
    var method: Value = undefined;
    _ = &method;
    if (!tableGet(&klass.*.methods, name, &method)) {
        const len: usize = @intCast(name.*.length);
        runtimeError("Undefined property '{s}'.", .{name.*.chars[0..len]});
        return false;
    }
    return call(@as([*c]ObjClosure, @ptrCast(@alignCast(method.as.obj))), argCount);
}
pub fn invoke(arg_name: [*c]ObjString, arg_argCount: c_int) callconv(.C) bool {
    var name = arg_name;
    _ = &name;
    var argCount = arg_argCount;
    _ = &argCount;
    var receiver: Value = peek(argCount);
    _ = &receiver;
    if (!object_h.isObjType(receiver, .OBJ_INSTANCE)) {
        runtimeError("Only instances have methods.", .{});
        return false;
    }
    var instance: [*c]ObjInstance = @as([*c]ObjInstance, @ptrCast(@alignCast(receiver.as.obj)));
    _ = &instance;
    var value: Value = undefined;
    _ = &value;
    if (tableGet(&instance.*.fields, name, &value)) {
        (blk: {
            const tmp = -argCount - 1;
            if (tmp >= 0) break :blk vm.stackTop + @as(usize, @intCast(tmp)) else break :blk vm.stackTop - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
        }).* = value;
        return callValue(value, argCount);
    }
    return invokeFromClass(instance.*.klass, name, argCount);
}
pub fn bindMethod(arg_klass: [*c]ObjClass, arg_name: [*c]ObjString) callconv(.C) bool {
    var klass = arg_klass;
    _ = &klass;
    var name = arg_name;
    _ = &name;
    var method: Value = undefined;
    _ = &method;
    if (!tableGet(&klass.*.methods, name, &method)) {
        runtimeError("Undefined property '{s}'.", .{@as([]u8, @ptrCast(@alignCast(name.*.chars[0..@intCast(name.*.length)])))});
        return false;
    }
    var bound: [*c]ObjBoundMethod = object_h.newBoundMethod(peek(0), @as([*c]ObjClosure, @ptrCast(@alignCast(method.as.obj))));
    _ = &bound;
    _ = pop();
    push(Value{
        .type = .VAL_OBJ,
        .as = .{
            .obj = @as([*c]Obj, @ptrCast(@alignCast(bound))),
        },
    });
    return true;
}
pub fn captureUpvalue(arg_local: [*c]Value) callconv(.C) [*c]ObjUpvalue {
    var local = arg_local;
    _ = &local;
    var prevUpvalue: [*c]ObjUpvalue = null;
    _ = &prevUpvalue;
    var upvalue: [*c]ObjUpvalue = vm.openUpvalues;
    _ = &upvalue;
    while ((upvalue != null) and (upvalue.*.location > local)) {
        prevUpvalue = upvalue;
        upvalue = upvalue.*.next;
    }
    while ((upvalue != null) and (upvalue.*.location == local)) {
        return upvalue;
    }
    var createdUpvalue: [*c]ObjUpvalue = object_h.newUpvalue(local);
    _ = &createdUpvalue;
    createdUpvalue.*.next = upvalue;
    if (prevUpvalue == null) {
        vm.openUpvalues = createdUpvalue;
    } else {
        prevUpvalue.*.next = createdUpvalue;
    }
    return createdUpvalue;
}
pub fn closeUpvalues(arg_last: [*c]Value) callconv(.C) void {
    var last = arg_last;
    _ = &last;
    while ((vm.openUpvalues != null) and (vm.openUpvalues.*.location >= last)) {
        var upvalue: [*c]ObjUpvalue = vm.openUpvalues;
        _ = &upvalue;
        upvalue.*.closed = upvalue.*.location.*;
        upvalue.*.location = &upvalue.*.closed;
        vm.openUpvalues = upvalue.*.next;
    }
}
pub fn defineMethod(arg_name: [*c]ObjString) callconv(.C) void {
    var name = arg_name;
    _ = &name;
    var method: Value = peek(0);
    _ = &method;
    var klass: [*c]ObjClass = @as([*c]ObjClass, @ptrCast(@alignCast(peek(1).as.obj)));
    _ = &klass;
    _ = tableSet(&klass.*.methods, name, method);
    _ = pop();
}
pub fn isFalsey(arg_value: Value) callconv(.C) bool {
    var value = arg_value;
    _ = &value;
    return (value.type == .VAL_NIL) or ((value.type == .VAL_BOOL) and !value.as.boolean);
}
pub fn concatenate() callconv(.C) void {
    var b: [*c]ObjString = @as([*c]ObjString, @ptrCast(@alignCast(peek(0).as.obj)));
    _ = &b;
    var a: [*c]ObjString = @as([*c]ObjString, @ptrCast(@alignCast(peek(1).as.obj)));
    _ = &a;
    var length: c_int = a.*.length + b.*.length;
    _ = &length;
    var chars: [*c]u8 = @as([*c]u8, @ptrCast(@alignCast(reallocate(null, 0, @intCast(@sizeOf(u8) *% length + 1)))));
    _ = &chars;
    _ = memcpy(@as(?*anyopaque, @ptrCast(chars)), @as(?*const anyopaque, @ptrCast(a.*.chars)), @intCast(a.*.length));
    _ = memcpy(@as(?*anyopaque, @ptrCast(chars + @as(usize, @bitCast(@as(isize, @intCast(a.*.length)))))), @as(?*const anyopaque, @ptrCast(b.*.chars)), @intCast(b.*.length));
    (blk: {
        const tmp = length;
        if (tmp >= 0) break :blk chars + @as(usize, @intCast(tmp)) else break :blk chars - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).* = '\x00';
    var result: [*c]ObjString = takeString(chars, length);
    _ = &result;
    _ = pop();
    _ = pop();
    push(Value{
        .type = .VAL_OBJ,
        .as = .{
            .obj = @as([*c]Obj, @ptrCast(@alignCast(result))),
        },
    });
}
pub fn complex_add() callconv(.C) void {
    var b: Complex = pop().as.complex;
    _ = &b;
    var a: Complex = pop().as.complex;
    _ = &a;
    var result: Complex = undefined;
    _ = &result;
    result.r = a.r + b.r;
    result.i = a.i + b.i;
    push(Value{
        .type = .VAL_COMPLEX,
        .as = .{
            .complex = result,
        },
    });
}
pub fn complex_sub() callconv(.C) void {
    var b: Complex = pop().as.complex;
    _ = &b;
    var a: Complex = pop().as.complex;
    _ = &a;
    var result: Complex = undefined;
    _ = &result;
    result.r = a.r - b.r;
    result.i = a.i - b.i;
    push(Value{
        .type = .VAL_COMPLEX,
        .as = .{
            .complex = result,
        },
    });
}
pub fn complex_mul() callconv(.C) void {
    var b: Complex = pop().as.complex;
    _ = &b;
    var a: Complex = pop().as.complex;
    _ = &a;
    var result: Complex = undefined;
    _ = &result;
    result.r = (a.r * b.r) - (a.i * b.i);
    result.i = (a.r * b.i) + (a.i * b.r);
    push(Value{
        .type = .VAL_COMPLEX,
        .as = .{
            .complex = result,
        },
    });
}
pub fn complex_div() callconv(.C) void {
    var b: Complex = pop().as.complex;
    _ = &b;
    var a: Complex = pop().as.complex;
    _ = &a;
    var result: Complex = undefined;
    _ = &result;
    result.r = ((a.r * b.r) + (a.i * b.i)) / ((b.r * b.r) + (b.i * b.i));
    result.i = ((a.i * b.r) - (a.r * b.i)) / ((b.r * b.r) + (b.i * b.i));
    push(Value{
        .type = .VAL_COMPLEX,
        .as = .{
            .complex = result,
        },
    });
}
pub fn setArray(arg_array: [*c]ObjArray, arg_index_1: c_int, arg_value: Value) callconv(.C) void {
    var array = arg_array;
    _ = &array;
    var index_1 = arg_index_1;
    _ = &index_1;
    var value = arg_value;
    _ = &value;
    if (index_1 >= array.*.count) {
        runtimeError("Index out of bounds.", .{});
        return;
    }
    (blk: {
        const tmp = index_1;
        if (tmp >= 0) break :blk array.*.values + @as(usize, @intCast(tmp)) else break :blk array.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).* = value;
}
pub fn setFloatVector(arg_fvec: [*c]FloatVector, arg_index_1: c_int, arg_value: f64) callconv(.C) void {
    var fvec = arg_fvec;
    _ = &fvec;
    var index_1 = arg_index_1;
    _ = &index_1;
    var value = arg_value;
    _ = &value;
    if (index_1 >= fvec.*.count) {
        runtimeError("Index out of bounds.", .{});
        return;
    }
    (blk: {
        const tmp = index_1;
        if (tmp >= 0) break :blk fvec.*.data + @as(usize, @intCast(tmp)) else break :blk fvec.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).* = value;
}

pub fn run() callconv(.C) InterpretResult {
    var frame: [*c]CallFrame = &vm.frames[@intCast(vm.frameCount - 1)];
    if (debug_opts.trace_exec) {
        print("         ", .{});

        var slot: [*c]Value = @ptrCast(@alignCast(&vm.stack));
        while (slot < vm.stackTop) : (slot += 1) {
            print("[ ", .{});
            printValue(slot.*);
            print(" ]", .{});
        }

        print("\n", .{});
        const chunk = &frame.*.closure.*.function.*.chunk;
        const offset = @intFromPtr(frame.*.ip) - @intFromPtr(frame.*.closure.*.function.*.chunk.code);
        const instruction_index = @divExact(offset, @sizeOf(u8));
        const c_instruction_index = @as(c_int, @truncate(instruction_index));

        _ = debug_h.disassembleInstruction(chunk, c_instruction_index);
    }
    while (true) {
        var instruction: u8 = undefined;
        _ = &instruction;
        while (true) {
            switch (@as(c_int, @bitCast(@as(c_uint, blk: {
                const tmp = (blk_1: {
                    const ref = &frame.*.ip;
                    const tmp_2 = ref.*;
                    ref.* += 1;
                    break :blk_1 tmp_2;
                }).*;
                instruction = tmp;
                break :blk tmp;
            })))) {
                0 => {
                    {
                        var constant: Value = frame.*.closure.*.function.*.chunk.constants.values[
                            (blk: {
                                const ref = &frame.*.ip;
                                const tmp = ref.*;
                                ref.* += 1;
                                break :blk tmp;
                            }).*
                        ];
                        _ = &constant;
                        push(constant);
                        break;
                    }
                },
                1 => {
                    push(Value{
                        .type = .VAL_NIL,
                        .as = .{
                            .num_int = 0,
                        },
                    });
                    break;
                },
                @as(c_int, 2) => {
                    push(Value{
                        .type = .VAL_BOOL,
                        .as = .{
                            .boolean = 1 != 0,
                        },
                    });
                    break;
                },
                @as(c_int, 3) => {
                    push(Value{
                        .type = .VAL_BOOL,
                        .as = .{
                            .boolean = 0 != 0,
                        },
                    });
                    break;
                },
                @as(c_int, 4) => {
                    _ = pop();
                    break;
                },
                @as(c_int, 5) => {
                    {
                        var slot: u8 = (blk: {
                            const ref = &frame.*.ip;
                            const tmp = ref.*;
                            ref.* += 1;
                            break :blk tmp;
                        }).*;
                        _ = &slot;
                        push(frame.*.slots[slot]);
                        break;
                    }
                },
                @as(c_int, 6) => {
                    {
                        var slot: u8 = (blk: {
                            const ref = &frame.*.ip;
                            const tmp = ref.*;
                            ref.* += 1;
                            break :blk tmp;
                        }).*;
                        _ = &slot;
                        frame.*.slots[slot] = peek(0);
                        break;
                    }
                },
                @as(c_int, 7) => {
                    {
                        var name: [*c]ObjString = @as([*c]ObjString, @ptrCast(@alignCast(frame.*.closure.*.function.*.chunk.constants.values[
                            (blk: {
                                const ref = &frame.*.ip;
                                const tmp = ref.*;
                                ref.* += 1;
                                break :blk tmp;
                            }).*
                        ].as.obj)));
                        _ = &name;
                        var value: Value = undefined;
                        _ = &value;
                        if (!tableGet(&vm.globals, name, &value)) {
                            runtimeError("Undefined variable '{s}'.", .{zstr(name)});
                            return .INTERPRET_RUNTIME_ERROR;
                        }
                        push(value);
                        break;
                    }
                },
                @as(c_int, 8) => {
                    {
                        var name: [*c]ObjString = @as([*c]ObjString, @ptrCast(@alignCast(frame.*.closure.*.function.*.chunk.constants.values[
                            (blk: {
                                const ref = &frame.*.ip;
                                const tmp = ref.*;
                                ref.* += 1;
                                break :blk tmp;
                            }).*
                        ].as.obj)));
                        _ = &name;
                        _ = tableSet(&vm.globals, name, peek(0));
                        _ = pop();
                        break;
                    }
                },
                @as(c_int, 9) => {
                    {
                        var name: [*c]ObjString = @as([*c]ObjString, @ptrCast(@alignCast(frame.*.closure.*.function.*.chunk.constants.values[
                            (blk: {
                                const ref = &frame.*.ip;
                                const tmp = ref.*;
                                ref.* += 1;
                                break :blk tmp;
                            }).*
                        ].as.obj)));
                        _ = &name;
                        if (tableSet(&vm.globals, name, peek(0))) {
                            _ = tableDelete(&vm.globals, name);
                            runtimeError("Undefined variable '{s}'.", .{zstr(name)});
                            return .INTERPRET_RUNTIME_ERROR;
                        }
                        break;
                    }
                },
                @as(c_int, 10) => {
                    {
                        var slot: u8 = (blk: {
                            const ref = &frame.*.ip;
                            const tmp = ref.*;
                            ref.* += 1;
                            break :blk tmp;
                        }).*;
                        _ = &slot;
                        push(frame.*.closure.*.upvalues[slot].*.location.*);
                        break;
                    }
                },
                @as(c_int, 11) => {
                    {
                        var slot: u8 = (blk: {
                            const ref = &frame.*.ip;
                            const tmp = ref.*;
                            ref.* += 1;
                            break :blk tmp;
                        }).*;
                        _ = &slot;
                        frame.*.closure.*.upvalues[slot].*.location.* = peek(0);
                        break;
                    }
                },
                @as(c_int, 12) => {
                    {
                        if (!isObjType(peek(0), .OBJ_INSTANCE)) {
                            runtimeError("Only instances have properties.", .{});
                            return .INTERPRET_RUNTIME_ERROR;
                        }
                        var instance: [*c]ObjInstance = @as([*c]ObjInstance, @ptrCast(@alignCast(peek(0).as.obj)));
                        _ = &instance;
                        var name: [*c]ObjString = @as([*c]ObjString, @ptrCast(@alignCast(frame.*.closure.*.function.*.chunk.constants.values[
                            (blk: {
                                const ref = &frame.*.ip;
                                const tmp = ref.*;
                                ref.* += 1;
                                break :blk tmp;
                            }).*
                        ].as.obj)));
                        _ = &name;
                        var value: Value = undefined;
                        _ = &value;
                        if (tableGet(&instance.*.fields, name, &value)) {
                            _ = pop();
                            push(value);
                            break;
                        }
                        if (!bindMethod(instance.*.klass, name)) {
                            return .INTERPRET_RUNTIME_ERROR;
                        }
                        break;
                    }
                },
                @as(c_int, 13) => {
                    {
                        if (!isObjType(peek(1), .OBJ_INSTANCE)) {
                            runtimeError("Only instances have fields.", .{});
                            return .INTERPRET_RUNTIME_ERROR;
                        }
                        var instance: [*c]ObjInstance = @as([*c]ObjInstance, @ptrCast(@alignCast(peek(1).as.obj)));
                        _ = &instance;
                        _ = tableSet(&instance.*.fields, @as([*c]ObjString, @ptrCast(@alignCast(frame.*.closure.*.function.*.chunk.constants.values[
                            (blk: {
                                const ref = &frame.*.ip;
                                const tmp = ref.*;
                                ref.* += 1;
                                break :blk tmp;
                            }).*
                        ].as.obj))), peek(0));
                        var value: Value = pop();
                        _ = &value;
                        _ = pop();
                        push(value);
                        break;
                    }
                },
                @as(c_int, 14) => {
                    {
                        var name: [*c]ObjString = @as([*c]ObjString, @ptrCast(@alignCast(frame.*.closure.*.function.*.chunk.constants.values[
                            (blk: {
                                const ref = &frame.*.ip;
                                const tmp = ref.*;
                                ref.* += 1;
                                break :blk tmp;
                            }).*
                        ].as.obj)));
                        _ = &name;
                        var superclass: [*c]ObjClass = @as([*c]ObjClass, @ptrCast(@alignCast(pop().as.obj)));
                        _ = &superclass;
                        if (!bindMethod(superclass, name)) {
                            return .INTERPRET_RUNTIME_ERROR;
                        }
                        break;
                    }
                },
                @as(c_int, 44) => {
                    {}
                    {
                        _ = printf("Index get\n");
                        var idx: c_int = @as(c_int, @bitCast(@as(c_uint, (blk: {
                            const ref = &frame.*.ip;
                            const tmp = ref.*;
                            ref.* += 1;
                            break :blk tmp;
                        }).*)));
                        _ = &idx;
                        var array: Value = frame.*.closure.*.function.*.chunk.constants.values[
                            (blk: {
                                const ref = &frame.*.ip;
                                const tmp = ref.*;
                                ref.* += 1;
                                break :blk tmp;
                            }).*
                        ];
                        _ = &array;
                        printValue(array);
                        if (!isObjType(array, .OBJ_ARRAY)) {
                            runtimeError("Only arrays support indexing.", .{});
                            return .INTERPRET_RUNTIME_ERROR;
                        }
                        var arrObj = @as([*c]ObjArray, @ptrCast(@alignCast(array.as.obj)));
                        _ = &arrObj;
                        if ((idx < 0) or (idx >= arrObj.*.count)) {
                            runtimeError("Index out of bounds.", .{});
                            return .INTERPRET_RUNTIME_ERROR;
                        }
                        push((blk: {
                            const tmp = idx;
                            if (tmp >= 0) break :blk arrObj.*.values + @as(usize, @intCast(tmp)) else break :blk arrObj.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                        }).*);
                        break;
                    }
                },
                @as(c_int, 15) => {
                    {
                        _ = printf("Index get\n");
                        var idx: c_int = @as(c_int, @bitCast(@as(c_uint, (blk: {
                            const ref = &frame.*.ip;
                            const tmp = ref.*;
                            ref.* += 1;
                            break :blk tmp;
                        }).*)));
                        _ = &idx;
                        var array: Value = frame.*.closure.*.function.*.chunk.constants.values[
                            (blk: {
                                const ref = &frame.*.ip;
                                const tmp = ref.*;
                                ref.* += 1;
                                break :blk tmp;
                            }).*
                        ];
                        _ = &array;
                        printValue(array);
                        if (!isObjType(array, .OBJ_ARRAY)) {
                            runtimeError("Only arrays support indexing.", .{});
                            return .INTERPRET_RUNTIME_ERROR;
                        }
                        var arrObj = @as([*c]ObjArray, @ptrCast(@alignCast(array.as.obj)));
                        _ = &arrObj;
                        if ((idx < 0) or (idx >= arrObj.*.count)) {
                            runtimeError("Index out of bounds.", .{});
                            return .INTERPRET_RUNTIME_ERROR;
                        }
                        push((blk: {
                            const tmp = idx;
                            if (tmp >= 0) break :blk arrObj.*.values + @as(usize, @intCast(tmp)) else break :blk arrObj.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                        }).*);
                        break;
                    }
                },
                @as(c_int, 16) => {
                    {
                        var value: Value = pop();
                        _ = &value;
                        var index_1: Value = pop();
                        _ = &index_1;
                        var array: Value = peek(@as(c_int, 2));
                        _ = &array;
                        if (!isObjType(array, .OBJ_ARRAY)) {
                            runtimeError("Only arrays support indexing.", .{});
                            return .INTERPRET_RUNTIME_ERROR;
                        }
                        if (!(index_1.type == .VAL_INT)) {
                            runtimeError("Array index must be an integer.", .{});
                            return .INTERPRET_RUNTIME_ERROR;
                        }
                        var idx: c_int = index_1.as.num_int;
                        _ = &idx;
                        var arrObj = @as([*c]ObjArray, @ptrCast(@alignCast(array.as.obj)));
                        _ = &arrObj;
                        if ((idx < 0) or (idx >= arrObj.*.count)) {
                            runtimeError("Index out of bounds.", .{});
                            return .INTERPRET_RUNTIME_ERROR;
                        }
                        (blk: {
                            const tmp = idx;
                            if (tmp >= 0) break :blk arrObj.*.values + @as(usize, @intCast(tmp)) else break :blk arrObj.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                        }).* = value;
                        break;
                    }
                },
                @as(c_int, 42) => {
                    {
                        var count: c_int = @as(c_int, @bitCast(@as(c_uint, (blk: {
                            const ref = &frame.*.ip;
                            const tmp = ref.*;
                            ref.* += 1;
                            break :blk tmp;
                        }).*)));
                        _ = &count;
                        var array = object_h.newArrayWithCap(count, 1 != 0);
                        _ = &array;
                        {
                            var i: c_int = 0;
                            _ = &i;
                            while (i < count) : (i += 1) {
                                pushArray(array, peek((count - i) - 1));
                            }
                        }
                        {
                            var i: c_int = 0;
                            _ = &i;
                            while (i < count) : (i += 1) {
                                _ = pop();
                            }
                        }
                        push(Value{
                            .type = .VAL_OBJ,
                            .as = .{
                                .obj = @as([*c]Obj, @ptrCast(@alignCast(array))),
                            },
                        });
                        break;
                    }
                },
                @as(c_int, 43) => {
                    {
                        var count: c_int = @as(c_int, @bitCast(@as(c_uint, (blk: {
                            const ref = &frame.*.ip;
                            const tmp = ref.*;
                            ref.* += 1;
                            break :blk tmp;
                        }).*)));
                        _ = &count;
                        var fvec = object_h.newFloatVector(count);
                        _ = &fvec;
                        {
                            var i: c_int = 0;
                            _ = &i;
                            while (i < count) : (i += 1) {
                                pushFloatVector(fvec, peek((count - i) - 1).as.num_double);
                            }
                        }
                        {
                            var i: c_int = 0;
                            _ = &i;
                            while (i < count) : (i += 1) {
                                _ = pop();
                            }
                        }
                        push(Value{
                            .type = .VAL_OBJ,
                            .as = .{
                                .obj = @as([*c]Obj, @ptrCast(@alignCast(fvec))),
                            },
                        });
                        break;
                    }
                },
                @as(c_int, 17) => {
                    {
                        if ((isObjType(peek(0), .OBJ_ARRAY)) and (isObjType(peek(1), .OBJ_ARRAY))) {
                            var b = @as([*c]ObjArray, @ptrCast(@alignCast(pop().as.obj)));
                            _ = &b;
                            var a = @as([*c]ObjArray, @ptrCast(@alignCast(pop().as.obj)));
                            _ = &a;
                            push(Value{
                                .type = .VAL_BOOL,
                                .as = .{
                                    .boolean = equalArray(a, b),
                                },
                            });
                        } else if ((isObjType(peek(0), .OBJ_LINKED_LIST)) and (isObjType(peek(1), .OBJ_LINKED_LIST))) {
                            var b: [*c]ObjLinkedList = @as([*c]ObjLinkedList, @ptrCast(@alignCast(pop().as.obj)));
                            _ = &b;
                            var a: [*c]ObjLinkedList = @as([*c]ObjLinkedList, @ptrCast(@alignCast(pop().as.obj)));
                            _ = &a;
                            push(Value{
                                .type = .VAL_BOOL,
                                .as = .{
                                    .boolean = equalLinkedList(a, b),
                                },
                            });
                        } else {
                            var b: Value = pop();
                            _ = &b;
                            var a: Value = pop();
                            _ = &a;
                            push(Value{
                                .type = .VAL_BOOL,
                                .as = .{
                                    .boolean = valuesEqual(a, b),
                                },
                            });
                        }
                        break;
                    }
                },
                @as(c_int, 18) => {
                    while (true) {
                        if ((peek(0).type == .VAL_INT) and (peek(1).type == .VAL_INT)) {
                            var b: c_int = pop().as.num_int;
                            _ = &b;
                            var a: c_int = pop().as.num_int;
                            _ = &a;
                            push(Value{
                                .type = .VAL_BOOL,
                                .as = .{
                                    .boolean = a > b,
                                },
                            });
                        } else if ((peek(0).type == .VAL_DOUBLE) and (peek(1).type == .VAL_DOUBLE)) {
                            var b: f64 = pop().as.num_double;
                            _ = &b;
                            var a: f64 = pop().as.num_double;
                            _ = &a;
                            push(Value{
                                .type = .VAL_BOOL,
                                .as = .{
                                    .boolean = a > b,
                                },
                            });
                        } else {
                            runtimeError("Operands must be numeric type (double/int/complex).", .{});
                            return .INTERPRET_RUNTIME_ERROR;
                        }
                        if (!false) break;
                    }
                    break;
                },
                @as(c_int, 19) => {
                    while (true) {
                        if ((peek(0).type == .VAL_INT) and (peek(1).type == .VAL_INT)) {
                            var b: c_int = pop().as.num_int;
                            _ = &b;
                            var a: c_int = pop().as.num_int;
                            _ = &a;
                            push(Value{
                                .type = .VAL_BOOL,
                                .as = .{
                                    .boolean = a < b,
                                },
                            });
                        } else if ((peek(0).type == .VAL_DOUBLE) and (peek(1).type == .VAL_DOUBLE)) {
                            var b: f64 = pop().as.num_double;
                            _ = &b;
                            var a: f64 = pop().as.num_double;
                            _ = &a;
                            push(Value{
                                .type = .VAL_BOOL,
                                .as = .{
                                    .boolean = a < b,
                                },
                            });
                        } else {
                            runtimeError("Operands must be numeric type (double/int/complex).", .{});
                            return .INTERPRET_RUNTIME_ERROR;
                        }
                        if (!false) break;
                    }
                    break;
                },
                @as(c_int, 20) => {
                    {
                        if (isObjType(peek(0), .OBJ_STRING) and (isObjType(peek(1), .OBJ_STRING))) {
                            concatenate();
                        } else if ((isObjType(peek(0), .OBJ_ARRAY)) and (isObjType(peek(1), .OBJ_ARRAY))) {
                            const b = @as([*c]ObjArray, @ptrCast(@alignCast(pop().as.obj)));
                            const a = @as([*c]ObjArray, @ptrCast(@alignCast(pop().as.obj)));
                            const result = addArray(a, b);
                            push(Value.init_obj(@ptrCast(result)));
                        } else if ((isObjType(peek(0), .OBJ_FVECTOR)) and (isObjType(peek(1), .OBJ_FVECTOR))) {
                            const b = @as([*c]FloatVector, @ptrCast(@alignCast(pop().as.obj)));
                            const a = @as([*c]FloatVector, @ptrCast(@alignCast(pop().as.obj)));
                            const result = addFloatVector(a, b);
                            push(Value.init_obj(@ptrCast(result)));
                        } else {
                            const b = pop();
                            const a = pop();
                            if (a.type == .VAL_NIL) {
                                runtimeError("Invalid Binary Operation.", .{});
                                return .INTERPRET_RUNTIME_ERROR;
                            }
                            push(a.add(b));
                        }
                    }
                    break;
                },
                @as(c_int, 21) => {
                    if ((isObjType(peek(0), .OBJ_MATRIX)) and (isObjType(peek(1), .OBJ_MATRIX))) {
                        const b = @as([*c]ObjMatrix, @ptrCast(@alignCast(pop().as.obj)));
                        const a = @as([*c]ObjMatrix, @ptrCast(@alignCast(pop().as.obj)));
                        const result = subMatrix(a, b);
                        push(Value.init_obj(@ptrCast(result)));
                    } else if ((isObjType(peek(0), .OBJ_ARRAY)) and (isObjType(peek(1), .OBJ_ARRAY))) {
                        const b = @as([*c]ObjArray, @ptrCast(@alignCast(pop().as.obj)));
                        const a = @as([*c]ObjArray, @ptrCast(@alignCast(pop().as.obj)));
                        const result = subArray(a, b);
                        push(Value.init_obj(@ptrCast(result)));
                    } else if ((isObjType(peek(0), .OBJ_FVECTOR)) and (isObjType(peek(1), .OBJ_FVECTOR))) {
                        const b = @as([*c]FloatVector, @ptrCast(@alignCast(pop().as.obj)));
                        const a = @as([*c]FloatVector, @ptrCast(@alignCast(pop().as.obj)));
                        const result = subFloatVector(a, b);
                        push(Value.init_obj(@ptrCast(result)));
                    }
                    // else if ((isObjType(peek(1), .OBJ_FVECTOR)) and (peek(0).type == .VAL_DOUBLE)) {
                    //     var b: f64 = pop().as.num_double;
                    //     _ = &b;
                    //     var a = @as([*c]FloatVector, @ptrCast(@alignCast(pop().as.obj)));
                    //     _ = &a;
                    //     var result = singleSubFloatVector(a, b);
                    //     _ = &result;
                    //     push(Value{
                    //         .type = .VAL_OBJ,
                    //         .as = .{
                    //             .obj = @as([*c]Obj, @ptrCast(@alignCast(result))),
                    //         },
                    //     });
                    // }
                    // else if ((peek(1).type == .VAL_DOUBLE) and (isObjType(peek(0), .OBJ_FVECTOR))) {
                    //     var b = @as([*c]FloatVector, @ptrCast(@alignCast(pop().as.obj)));
                    //     _ = &b;
                    //     var a: f64 = pop().as.num_double;
                    //     _ = &a;
                    //     var result = singleSubFloatVector(b, a);
                    //     _ = &result;
                    //     push(Value{
                    //         .type = .VAL_OBJ,
                    //         .as = .{
                    //             .obj = @as([*c]Obj, @ptrCast(@alignCast(result))),
                    //         },
                    //     });
                    // }
                    else {
                        const b = pop();
                        const a = pop();
                        push(a.sub(b));
                    }
                },
                @as(c_int, 22) => {
                    if ((isObjType(peek(0), .OBJ_MATRIX)) and (isObjType(peek(1), .OBJ_MATRIX))) {
                        const b = @as([*c]ObjMatrix, @ptrCast(@alignCast(pop().as.obj)));
                        const a = @as([*c]ObjMatrix, @ptrCast(@alignCast(pop().as.obj)));
                        const result = mulMatrix(a, b);
                        push(Value.init_obj(@ptrCast(result)));
                    } else if ((isObjType(peek(0), .OBJ_ARRAY)) and (isObjType(peek(1), .OBJ_ARRAY))) {
                        const b = @as([*c]ObjArray, @ptrCast(@alignCast(pop().as.obj)));
                        const a = @as([*c]ObjArray, @ptrCast(@alignCast(pop().as.obj)));
                        const result = mulArray(a, b);
                        push(Value.init_obj(@ptrCast(result)));
                    } else if ((isObjType(peek(0), .OBJ_FVECTOR)) and (isObjType(peek(1), .OBJ_FVECTOR))) {
                        const b = @as([*c]FloatVector, @ptrCast(@alignCast(pop().as.obj)));
                        const a = @as([*c]FloatVector, @ptrCast(@alignCast(pop().as.obj)));
                        const result = mulFloatVector(a, b);
                        push(Value.init_obj(@ptrCast(result)));
                    }
                    // else if ((isObjType(peek(1), .OBJ_FVECTOR)) and (peek(0).type == .VAL_DOUBLE)) {
                    //     var b: f64 = pop().as.num_double;
                    //     _ = &b;
                    //     var a = @as([*c]FloatVector, @ptrCast(@alignCast(pop().as.obj)));
                    //     _ = &a;
                    //     var result = scaleFloatVector(a, b);
                    //     _ = &result;
                    //     push(Value{
                    //         .type = .VAL_OBJ,
                    //         .as = .{
                    //             .obj = @as([*c]Obj, @ptrCast(@alignCast(result))),
                    //         },
                    //     });
                    // } else if ((peek(1).type == .VAL_DOUBLE) and (isObjType(peek(0), .OBJ_FVECTOR))) {
                    //     var b = @as([*c]FloatVector, @ptrCast(@alignCast(pop().as.obj)));
                    //     _ = &b;
                    //     var a: f64 = pop().as.num_double;
                    //     _ = &a;
                    //     var result = scaleFloatVector(b, a);
                    //     _ = &result;
                    //     push(Value{
                    //         .type = .VAL_OBJ,
                    //         .as = .{
                    //             .obj = @as([*c]Obj, @ptrCast(@alignCast(result))),
                    //         },
                    //     });
                    // }
                    else {
                        const b = pop();
                        const a = pop();
                        push(a.mul(b));
                    }
                },
                @as(c_int, 23) => {
                    if ((isObjType(peek(0), .OBJ_MATRIX)) and (isObjType(peek(1), .OBJ_MATRIX))) {
                        const b = @as([*c]ObjMatrix, @ptrCast(@alignCast(pop().as.obj)));
                        const a = @as([*c]ObjMatrix, @ptrCast(@alignCast(pop().as.obj)));
                        const result = divMatrix(a, b);
                        push(Value.init_obj(@ptrCast(result)));
                    } else if ((isObjType(peek(0), .OBJ_ARRAY)) and (isObjType(peek(1), .OBJ_ARRAY))) {
                        const b = @as([*c]ObjArray, @ptrCast(@alignCast(pop().as.obj)));
                        const a = @as([*c]ObjArray, @ptrCast(@alignCast(pop().as.obj)));
                        const result = divArray(a, b);
                        push(Value.init_obj(@ptrCast(result)));
                    } else if ((isObjType(peek(0), .OBJ_FVECTOR)) and (isObjType(peek(1), .OBJ_FVECTOR))) {
                        const b = @as([*c]FloatVector, @ptrCast(@alignCast(pop().as.obj)));
                        const a = @as([*c]FloatVector, @ptrCast(@alignCast(pop().as.obj)));
                        const result = divFloatVector(a, b);
                        push(Value.init_obj(@ptrCast(result)));
                    }
                    //  else if ((isObjType(peek(1), .OBJ_FVECTOR)) and (peek(0).type == .VAL_DOUBLE)) {
                    //     var b: f64 = pop().as.num_double;
                    //     _ = &b;
                    //     var a = @as([*c]FloatVector, @ptrCast(@alignCast(pop().as.obj)));
                    //     _ = &a;
                    //     var result = singleDivFloatVector(a, b);
                    //     _ = &result;
                    //     push(Value{
                    //         .type = .VAL_OBJ,
                    //         .as = .{
                    //             .obj = @as([*c]Obj, @ptrCast(@alignCast(result))),
                    //         },
                    //     });
                    // } else if ((peek(1).type == .VAL_DOUBLE) and (isObjType(peek(0), .OBJ_FVECTOR))) {
                    //     var b = @as([*c]FloatVector, @ptrCast(@alignCast(pop().as.obj)));
                    //     _ = &b;
                    //     var a: f64 = pop().as.num_double;
                    //     _ = &a;
                    //     var result = singleDivFloatVector(b, a);
                    //     _ = &result;
                    //     push(Value{
                    //         .type = .VAL_OBJ,
                    //         .as = .{
                    //             .obj = @as([*c]Obj, @ptrCast(@alignCast(result))),
                    //         },
                    //     });
                    // }
                    else {
                        const b = pop();
                        const a = pop();
                        push(a.div(b));
                    }
                },
                @as(c_int, 24) => {
                    {
                        if ((peek(0).type == .VAL_INT) and (peek(1).type == .VAL_INT)) {
                            var b: c_int = pop().as.num_int;
                            _ = &b;
                            var a: c_int = pop().as.num_int;
                            _ = &a;
                            push(Value{
                                .type = .VAL_INT,
                                .as = .{
                                    .num_int = @import("std").zig.c_translation.signedRemainder(a, b),
                                },
                            });
                        } else {
                            runtimeError("Operands must be integers.", .{});
                            return .INTERPRET_RUNTIME_ERROR;
                        }
                        break;
                    }
                },
                @as(c_int, 25) => {
                    {
                        if ((peek(0).type == .VAL_INT) and (peek(1).type == .VAL_INT)) {
                            var b: c_int = pop().as.num_int;
                            _ = &b;
                            var a: c_int = pop().as.num_int;
                            _ = &a;
                            push(Value{
                                .type = .VAL_INT,
                                .as = .{
                                    .num_int = @as(c_int, @intFromFloat(pow(@as(f64, @floatFromInt(a)), @as(f64, @floatFromInt(b))))),
                                },
                            });
                        } else if ((peek(0).type == .VAL_DOUBLE) and (peek(1).type == .VAL_DOUBLE)) {
                            var b: f64 = pop().as.num_double;
                            _ = &b;
                            var a: f64 = pop().as.num_double;
                            _ = &a;
                            push(Value{
                                .type = .VAL_DOUBLE,
                                .as = .{
                                    .num_double = pow(a, b),
                                },
                            });
                        } else if ((peek(0).type == .VAL_COMPLEX) and (peek(1).type == .VAL_DOUBLE)) {
                            var b: f64 = pop().as.num_double;
                            _ = &b;
                            var a: Complex = pop().as.complex;
                            _ = &a;
                            var result: Complex = undefined;
                            _ = &result;
                            var r: f64 = sqrt((a.r * a.r) + (a.i * a.i));
                            _ = &r;
                            var theta: f64 = atan2(a.i, a.r);
                            _ = &theta;
                            result.r = pow(r, b) * cos(b * theta);
                            result.i = pow(r, b) * sin(b * theta);
                            push(Value{
                                .type = .VAL_COMPLEX,
                                .as = .{
                                    .complex = result,
                                },
                            });
                        } else {
                            runtimeError("Operands must be numeric type.", .{});
                            return .INTERPRET_RUNTIME_ERROR;
                        }
                        break;
                    }
                },
                @as(c_int, 26) => {
                    push(Value{
                        .type = .VAL_BOOL,
                        .as = .{
                            .boolean = isFalsey(pop()),
                        },
                    });
                    break;
                },
                @as(c_int, 27) => {
                    if ((!(peek(0).type == .VAL_INT) and !(peek(0).type == .VAL_DOUBLE)) and !(peek(0).type == .VAL_COMPLEX)) {
                        runtimeError("Operand must be a number (int/double).", .{});
                        return .INTERPRET_RUNTIME_ERROR;
                    }
                    if (peek(0).type == .VAL_INT) {
                        push(Value{
                            .type = .VAL_INT,
                            .as = .{
                                .num_int = -pop().as.num_int,
                            },
                        });
                    } else if (peek(0).type == .VAL_COMPLEX) {
                        var c: Complex = pop().as.complex;
                        _ = &c;
                        c.r *= @as(f64, @floatFromInt(-1));
                        c.i *= @as(f64, @floatFromInt(-1));
                        push(Value{
                            .type = .VAL_COMPLEX,
                            .as = .{
                                .complex = c,
                            },
                        });
                    } else {
                        push(Value{
                            .type = .VAL_DOUBLE,
                            .as = .{
                                .num_double = -pop().as.num_double,
                            },
                        });
                    }
                    break;
                },
                @as(c_int, 28) => {
                    {
                        printValue(pop());
                        _ = printf("\n");
                        break;
                    }
                },
                @as(c_int, 29) => {
                    {
                        var offset: u16 = blk: {
                            frame.*.ip += @as(usize, @bitCast(@as(isize, @intCast(@as(c_int, 2)))));
                            break :blk @as(u16, @bitCast(@as(c_short, @truncate((@as(c_int, @bitCast(@as(c_uint, (blk_1: {
                                const tmp = -@as(c_int, 2);
                                if (tmp >= 0) break :blk_1 frame.*.ip + @as(usize, @intCast(tmp)) else break :blk_1 frame.*.ip - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                            }).*))) << @intCast(8)) | @as(c_int, @bitCast(@as(c_uint, (blk_1: {
                                const tmp = -1;
                                if (tmp >= 0) break :blk_1 frame.*.ip + @as(usize, @intCast(tmp)) else break :blk_1 frame.*.ip - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                            }).*)))))));
                        };
                        _ = &offset;
                        frame.*.ip += @as(usize, @bitCast(@as(isize, @intCast(@as(c_int, @bitCast(@as(c_uint, offset)))))));
                        break;
                    }
                },
                @as(c_int, 30) => {
                    {
                        var offset: u16 = blk: {
                            frame.*.ip += @as(usize, @bitCast(@as(isize, @intCast(@as(c_int, 2)))));
                            break :blk @as(u16, @bitCast(@as(c_short, @truncate((@as(c_int, @bitCast(@as(c_uint, (blk_1: {
                                const tmp = -@as(c_int, 2);
                                if (tmp >= 0) break :blk_1 frame.*.ip + @as(usize, @intCast(tmp)) else break :blk_1 frame.*.ip - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                            }).*))) << @intCast(8)) | @as(c_int, @bitCast(@as(c_uint, (blk_1: {
                                const tmp = -1;
                                if (tmp >= 0) break :blk_1 frame.*.ip + @as(usize, @intCast(tmp)) else break :blk_1 frame.*.ip - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                            }).*)))))));
                        };
                        _ = &offset;
                        if (isFalsey(peek(0))) {
                            frame.*.ip += @as(usize, @bitCast(@as(isize, @intCast(@as(c_int, @bitCast(@as(c_uint, offset)))))));
                        }
                        break;
                    }
                },
                @as(c_int, 31) => {
                    {
                        var offset: u16 = blk: {
                            frame.*.ip += @as(usize, @bitCast(@as(isize, @intCast(@as(c_int, 2)))));
                            break :blk @as(u16, @bitCast(@as(c_short, @truncate((@as(c_int, @bitCast(@as(c_uint, (blk_1: {
                                const tmp = -@as(c_int, 2);
                                if (tmp >= 0) break :blk_1 frame.*.ip + @as(usize, @intCast(tmp)) else break :blk_1 frame.*.ip - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                            }).*))) << @intCast(8)) | @as(c_int, @bitCast(@as(c_uint, (blk_1: {
                                const tmp = -1;
                                if (tmp >= 0) break :blk_1 frame.*.ip + @as(usize, @intCast(tmp)) else break :blk_1 frame.*.ip - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                            }).*)))))));
                        };
                        _ = &offset;
                        var val: Value = peek(0);
                        _ = &val;
                        if (!isObjType(val, .OBJ_ARRAY) and !isObjType(val, .OBJ_FVECTOR)) {
                            runtimeError("Operand must be an array or a vector.", .{});
                            return .INTERPRET_RUNTIME_ERROR;
                        }
                        if (isObjType(val, .OBJ_ARRAY)) {
                            var array = @as([*c]ObjArray, @ptrCast(@alignCast(val.as.obj)));
                            _ = &array;
                            if (!object_h.hasNextObjectArray(array)) {
                                frame.*.ip += @as(usize, @bitCast(@as(isize, @intCast(@as(c_int, @bitCast(@as(c_uint, offset)))))));
                            } else {
                                push(object_h.nextObjectArray(array));
                            }
                        } else {
                            var fvector = @as([*c]FloatVector, @ptrCast(@alignCast(val.as.obj)));
                            _ = &fvector;
                            if (!object_h.hasNextFloatVector(fvector)) {
                                frame.*.ip += @as(usize, @bitCast(@as(isize, @intCast(@as(c_int, @bitCast(@as(c_uint, offset)))))));
                            } else {
                                push(Value{
                                    .type = .VAL_DOUBLE,
                                    .as = .{
                                        .num_double = object_h.nextFloatVector(fvector),
                                    },
                                });
                            }
                        }
                        break;
                    }
                },
                @as(c_int, 45) => {
                    {}
                    {
                        var offset: u16 = blk: {
                            frame.*.ip += @as(usize, @bitCast(@as(isize, @intCast(@as(c_int, 2)))));
                            break :blk @as(u16, @bitCast(@as(c_short, @truncate((@as(c_int, @bitCast(@as(c_uint, (blk_1: {
                                const tmp = -@as(c_int, 2);
                                if (tmp >= 0) break :blk_1 frame.*.ip + @as(usize, @intCast(tmp)) else break :blk_1 frame.*.ip - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                            }).*))) << @intCast(8)) | @as(c_int, @bitCast(@as(c_uint, (blk_1: {
                                const tmp = -1;
                                if (tmp >= 0) break :blk_1 frame.*.ip + @as(usize, @intCast(tmp)) else break :blk_1 frame.*.ip - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                            }).*)))))));
                        };
                        _ = &offset;
                        frame.*.ip -= @as(usize, @bitCast(@as(isize, @intCast(@as(c_int, @bitCast(@as(c_uint, offset)))))));
                        break;
                    }
                },
                @as(c_int, 32) => {
                    {
                        var offset: u16 = blk: {
                            frame.*.ip += @as(usize, @bitCast(@as(isize, @intCast(@as(c_int, 2)))));
                            break :blk @as(u16, @bitCast(@as(c_short, @truncate((@as(c_int, @bitCast(@as(c_uint, (blk_1: {
                                const tmp = -@as(c_int, 2);
                                if (tmp >= 0) break :blk_1 frame.*.ip + @as(usize, @intCast(tmp)) else break :blk_1 frame.*.ip - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                            }).*))) << @intCast(8)) | @as(c_int, @bitCast(@as(c_uint, (blk_1: {
                                const tmp = -1;
                                if (tmp >= 0) break :blk_1 frame.*.ip + @as(usize, @intCast(tmp)) else break :blk_1 frame.*.ip - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                            }).*)))))));
                        };
                        _ = &offset;
                        frame.*.ip -= @as(usize, @bitCast(@as(isize, @intCast(@as(c_int, @bitCast(@as(c_uint, offset)))))));
                        break;
                    }
                },
                @as(c_int, 33) => {
                    {
                        var argCount: c_int = @as(c_int, @bitCast(@as(c_uint, (blk: {
                            const ref = &frame.*.ip;
                            const tmp = ref.*;
                            ref.* += 1;
                            break :blk tmp;
                        }).*)));
                        _ = &argCount;
                        if (!callValue(peek(argCount), argCount)) {
                            return .INTERPRET_RUNTIME_ERROR;
                        }
                        if (vm.frameCount - 1 < 0) return .INTERPRET_RUNTIME_ERROR;
                        frame = &vm.frames[@intCast(vm.frameCount - 1)];
                        break;
                    }
                },
                @as(c_int, 34) => {
                    {
                        var method: [*c]ObjString = @as([*c]ObjString, @ptrCast(@alignCast(frame.*.closure.*.function.*.chunk.constants.values[
                            (blk: {
                                const ref = &frame.*.ip;
                                const tmp = ref.*;
                                ref.* += 1;
                                break :blk tmp;
                            }).*
                        ].as.obj)));
                        _ = &method;
                        var argCount: c_int = @as(c_int, @bitCast(@as(c_uint, (blk: {
                            const ref = &frame.*.ip;
                            const tmp = ref.*;
                            ref.* += 1;
                            break :blk tmp;
                        }).*)));
                        _ = &argCount;
                        if (!invoke(method, argCount)) {
                            return .INTERPRET_RUNTIME_ERROR;
                        }
                        frame = &vm.frames[@as(c_uint, @intCast(vm.frameCount - 1))];
                        break;
                    }
                },
                @as(c_int, 35) => {
                    {
                        var method: [*c]ObjString = @as([*c]ObjString, @ptrCast(@alignCast(frame.*.closure.*.function.*.chunk.constants.values[
                            (blk: {
                                const ref = &frame.*.ip;
                                const tmp = ref.*;
                                ref.* += 1;
                                break :blk tmp;
                            }).*
                        ].as.obj)));
                        _ = &method;
                        var argCount: c_int = @as(c_int, @bitCast(@as(c_uint, (blk: {
                            const ref = &frame.*.ip;
                            const tmp = ref.*;
                            ref.* += 1;
                            break :blk tmp;
                        }).*)));
                        _ = &argCount;
                        var superclass: [*c]ObjClass = @as([*c]ObjClass, @ptrCast(@alignCast(pop().as.obj)));
                        _ = &superclass;
                        if (!invokeFromClass(superclass, method, argCount)) {
                            return .INTERPRET_RUNTIME_ERROR;
                        }
                        frame = &vm.frames[@as(c_uint, @intCast(vm.frameCount - 1))];
                        break;
                    }
                },
                @as(c_int, 36) => {
                    {
                        var function: [*c]ObjFunction = @as([*c]ObjFunction, @ptrCast(@alignCast(frame.*.closure.*.function.*.chunk.constants.values[
                            (blk: {
                                const ref = &frame.*.ip;
                                const tmp = ref.*;
                                ref.* += 1;
                                break :blk tmp;
                            }).*
                        ].as.obj)));
                        _ = &function;
                        var closure: [*c]ObjClosure = object_h.newClosure(function);
                        _ = &closure;
                        push(Value{
                            .type = .VAL_OBJ,
                            .as = .{
                                .obj = @as([*c]Obj, @ptrCast(@alignCast(closure))),
                            },
                        });
                        {
                            var i: c_int = 0;
                            _ = &i;
                            while (i < closure.*.upvalueCount) : (i += 1) {
                                var isLocal: u8 = (blk: {
                                    const ref = &frame.*.ip;
                                    const tmp = ref.*;
                                    ref.* += 1;
                                    break :blk tmp;
                                }).*;
                                _ = &isLocal;
                                var index_1: u8 = (blk: {
                                    const ref = &frame.*.ip;
                                    const tmp = ref.*;
                                    ref.* += 1;
                                    break :blk tmp;
                                }).*;
                                _ = &index_1;
                                if (isLocal != 0) {
                                    (blk: {
                                        const tmp = i;
                                        if (tmp >= 0) break :blk closure.*.upvalues + @as(usize, @intCast(tmp)) else break :blk closure.*.upvalues - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                                    }).* = captureUpvalue(frame.*.slots + @as(usize, @bitCast(@as(isize, @intCast(@as(c_int, @bitCast(@as(c_uint, index_1))))))));
                                } else {
                                    (blk: {
                                        const tmp = i;
                                        if (tmp >= 0) break :blk closure.*.upvalues + @as(usize, @intCast(tmp)) else break :blk closure.*.upvalues - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                                    }).* = frame.*.closure.*.upvalues[index_1];
                                }
                            }
                        }
                        break;
                    }
                },
                @as(c_int, 37) => {
                    {
                        closeUpvalues(vm.stackTop - @as(usize, @bitCast(@as(isize, @intCast(1)))));
                        _ = pop();
                        break;
                    }
                },
                @as(c_int, 38) => {
                    {
                        var result: Value = pop();
                        _ = &result;
                        closeUpvalues(frame.*.slots);
                        vm.frameCount -= 1;
                        if (vm.frameCount == 0) {
                            _ = pop();
                            return .INTERPRET_OK;
                        }
                        vm.stackTop = frame.*.slots;
                        push(result);
                        frame = &vm.frames[@as(c_uint, @intCast(vm.frameCount - 1))];
                        break;
                    }
                },
                @as(c_int, 39) => {
                    {
                        push(Value{
                            .type = .VAL_OBJ,
                            .as = .{
                                .obj = @as([*c]Obj, @ptrCast(@alignCast(object_h.newClass(@as([*c]ObjString, @ptrCast(@alignCast(frame.*.closure.*.function.*.chunk.constants.values[
                                    (blk: {
                                        const ref = &frame.*.ip;
                                        const tmp = ref.*;
                                        ref.* += 1;
                                        break :blk tmp;
                                    }).*
                                ].as.obj))))))),
                            },
                        });
                        break;
                    }
                },
                @as(c_int, 40) => {
                    {
                        var superclass: Value = peek(1);
                        _ = &superclass;
                        if (!isObjType(superclass, .OBJ_CLASS)) {
                            runtimeError("Superclass must be a class.", .{});
                            return .INTERPRET_RUNTIME_ERROR;
                        }
                        var subclass: [*c]ObjClass = @as([*c]ObjClass, @ptrCast(@alignCast(peek(0).as.obj)));
                        _ = &subclass;
                        table_h.tableAddAll(&@as([*c]ObjClass, @ptrCast(@alignCast(superclass.as.obj))).*.methods, &subclass.*.methods);
                        _ = pop();
                        break;
                    }
                },
                @as(c_int, 41) => {
                    {
                        defineMethod(@as([*c]ObjString, @ptrCast(@alignCast(frame.*.closure.*.function.*.chunk.constants.values[
                            (blk: {
                                const ref = &frame.*.ip;
                                const tmp = ref.*;
                                ref.* += 1;
                                break :blk tmp;
                            }).*
                        ].as.obj))));
                        break;
                    }
                },
                else => {},
            }
            break;
        }
    }
    return @import("std").mem.zeroes(InterpretResult);
}
