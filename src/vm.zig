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
const fvec = @import("objects/fvec.zig");

const FloatVector = fvec.FloatVector;
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
const takeString = object_h.takeString;
// const newFloatVector = fvec.newFloatVector;
const pushFloatVector = fvec.FloatVector.push;
const ObjLinkedList = object_h.ObjLinkedList;
const equalLinkedList = object_h.equalLinkedList;
const valuesEqual = value_h.valuesEqual;
const addFloatVector = fvec.addFloatVector;
const singleAddFloatVector = fvec.singleAddFloatVector;
const subFloatVector = fvec.subFloatVector;
const singleSubFloatVector = fvec.singleSubFloatVector;
const mulFloatVector = fvec.mulFloatVector;
const scaleFloatVector = fvec.scaleFloatVector;
const divFloatVector = fvec.divFloatVector;
const singleDivFloatVector = fvec.singleDivFloatVector;
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

pub fn initVM() void {
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

inline fn next_frame_count() c_int {
    const ref = &vm.frameCount;
    const tmp = ref.*;
    ref.* += 1;
    return tmp;
}

inline fn set_stack_top(argc: c_int, value: Value) void {
    const tmp = -argc - 1;
    // if (tmp >= 0) break :blk vm.stackTop + @as(usize, @intCast(tmp)) else break :blk vm.stackTop - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    var ref: [*c]Value = null;
    if (tmp >= 0) {
        ref = vm.stackTop + @as(usize, @intCast(tmp));
    } else {
        ref = vm.stackTop - @as(usize, @intCast(tmp - 1));
    }
    ref.* = value;
}

const initTable = table_h.initTable;
const freeTable = table_h.freeTable;
const copyString = object_h.copyString;
const freeObjects = memory_h.freeObjects;

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

pub fn freeVM() void {
    freeTable(&vm.globals);
    freeTable(&vm.strings);
    vm.initString = null;
    freeObjects();
}
pub fn importCollections() void {
    defineNative("assert", cstd_h.assert_nf);
    defineNative("simd_stat", &cstd_h.simd_stat_nf);
    // defineNative("array", &cstd_h.array_nf);
    defineNative("linked_list", &cstd_h.linkedlist_nf);
    defineNative("hash_table", &cstd_h.hashtable_nf);
    // defineNative("matrix", &cstd_h.matrix_nf);
    defineNative("fvec", &cstd_h.fvector_nf);
    // defineNative("range", &cstd_h.range_nf);
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
    // defineNative("set_row", &cstd_h.set_row_nf);
    // defineNative("set_col", &cstd_h.set_col_nf);
    // defineNative("set", &cstd_h.set_nf);
    // defineNative("kolasa", &cstd_h.kolasa_nf);
    // defineNative("rref", &cstd_h.rref_nf);
    // defineNative("rank", &cstd_h.rank_nf);
    // defineNative("transpose", &cstd_h.transpose_nf);
    // defineNative("det", &cstd_h.determinant_nf);
    // defineNative("lu", &cstd_h.lu_nf);
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

pub fn interpret(source: [*c]const u8) InterpretResult {
    const function: [*c]ObjFunction = compiler_h.compile(source);
    if (function == null) return .INTERPRET_COMPILE_ERROR;
    push(Value.init_obj(@ptrCast(@alignCast(function))));
    const closure: [*c]ObjClosure = object_h.newClosure(function);
    _ = pop();
    push(Value.init_obj(@ptrCast(@alignCast(closure))));
    _ = call(closure, 0);
    return run();
}
pub fn push(value: Value) void {
    vm.stackTop.* = value;
    vm.stackTop += 1;
}
pub fn pop() Value {
    vm.stackTop -= 1;
    return vm.stackTop.*;
}
pub fn defineNative(name: [*c]const u8, function: NativeFn) void {
    push(
        Value.init_obj(@ptrCast(@alignCast(copyString(name, @intCast(strlen(name)))))),
    );
    push(Value.init_obj(@ptrCast(@alignCast(object_h.newNative(function)))));
    _ = table_h.tableSet(&vm.globals, @ptrCast(@alignCast(vm.stack[0].as.obj)), vm.stack[1]);
    _ = pop();
    _ = pop();
}

pub fn resetStack() void {
    vm.stackTop = @as([*c]Value, @ptrCast(@alignCast(&vm.stack)));
    vm.frameCount = 0;
    vm.openUpvalues = null;
}

pub fn peek(distance: c_int) Value {
    const tmp = -1 - distance;
    if (tmp >= 0) {
        return (vm.stackTop + @as(usize, @intCast(tmp))).*;
    } else {
        return (vm.stackTop - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1))).*;
    }
}

pub fn call(closure: [*c]ObjClosure, argCount: c_int) bool {
    if (argCount != closure.*.function.*.arity) {
        runtimeError("Expected {d} arguments but got {d}.", .{ closure.*.function.*.arity, argCount });
        return false;
    }
    if (vm.frameCount == @as(c_int, 64)) {
        runtimeError("Stack overflow.", .{});
        return false;
    }
    const frame: [*c]CallFrame = &vm.frames[@intCast(next_frame_count())];
    frame.*.closure = closure;
    frame.*.ip = closure.*.function.*.chunk.code;
    frame.*.slots = (vm.stackTop - @as(usize, @bitCast(@as(isize, @intCast(argCount))))) - @as(usize, @bitCast(@as(isize, @intCast(1))));
    return true;
}
pub fn callValue(callee: Value, argCount: c_int) bool {
    if (callee.type == .VAL_OBJ) {
        switch (callee.as.obj.*.type) {
            .OBJ_BOUND_METHOD => {
                const bound: [*c]ObjBoundMethod = @as([*c]ObjBoundMethod, @ptrCast(@alignCast(callee.as.obj)));
                // (blk: {
                //     const tmp = -argCount - 1;
                //     if (tmp >= 0) break :blk vm.stackTop + @as(usize, @intCast(tmp)) else break :blk vm.stackTop - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                // }).* = bound.*.receiver;
                set_stack_top(argCount, bound.*.receiver);
                return call(bound.*.method, argCount);
            },
            .OBJ_CLASS => {
                {
                    const klass: [*c]ObjClass = @ptrCast(@alignCast(callee.as.obj));

                    // (blk: {
                    //     const tmp = -argCount - 1;
                    //     if (tmp >= 0) break :blk vm.stackTop + @as(usize, @intCast(tmp)) else break :blk vm.stackTop - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                    // }).* = Value{
                    //     .type = .VAL_OBJ,
                    //     .as = .{
                    //         .obj = @as([*c]Obj, @ptrCast(@alignCast(object_h.newInstance(klass)))),
                    //     },
                    // };
                    set_stack_top(argCount, Value.init_obj(@ptrCast(@alignCast(object_h.newInstance(klass)))));
                    var initializer: Value = undefined;
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
                const klass: [*c]ObjClass = @ptrCast(@alignCast(callee.as.obj));

                // (blk: {
                //     const tmp = -argCount - 1;
                //     if (tmp >= 0) break :blk vm.stackTop + @as(usize, @intCast(tmp)) else break :blk vm.stackTop - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                // }).* = Value{
                //     .type = .VAL_OBJ,
                //     .as = .{
                //         .obj = @as([*c]Obj, @ptrCast(@alignCast(object_h.newInstance(klass)))),
                //     },
                // };
                set_stack_top(argCount, Value.init_obj(@ptrCast(@alignCast(object_h.newInstance(klass)))));

                return true;
            },
            .OBJ_NATIVE => {
                const native: NativeFn = @as([*c]ObjNative, @ptrCast(@alignCast(callee.as.obj))).*.function;
                const result: Value = native.?(argCount, vm.stackTop - @as(usize, @intCast(argCount)));
                vm.stackTop -= @as(usize, @intCast(argCount + 1));
                push(result);
                return true;
            },
            else => {},
        }
    }
    runtimeError("Can only call functions and classes.", .{});
    return false;
}
pub fn invokeFromClass(klass: [*c]ObjClass, name: [*c]ObjString, argCount: c_int) bool {
    var method: Value = undefined;
    if (!tableGet(&klass.*.methods, name, &method)) {
        const len: usize = @intCast(name.*.length);
        runtimeError("Undefined property '{s}'.", .{name.*.chars[0..len]});
        return false;
    }
    return call(@as([*c]ObjClosure, @ptrCast(@alignCast(method.as.obj))), argCount);
}
pub fn invoke(name: [*c]ObjString, argCount: c_int) bool {
    const receiver: Value = peek(argCount);
    if (!object_h.isObjType(receiver, .OBJ_INSTANCE)) {
        runtimeError("Only instances have methods.", .{});
        return false;
    }
    const instance: [*c]ObjInstance = @as([*c]ObjInstance, @ptrCast(@alignCast(receiver.as.obj)));
    var value: Value = undefined;

    if (tableGet(&instance.*.fields, name, &value)) {
        // (blk: {
        //     const tmp = -argCount - 1;
        //     if (tmp >= 0) break :blk vm.stackTop + @as(usize, @intCast(tmp)) else break :blk vm.stackTop - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
        // }).* = value;
        set_stack_top(argCount, value);
        return callValue(value, argCount);
    }
    return invokeFromClass(instance.*.klass, name, argCount);
}
pub fn bindMethod(klass: [*c]ObjClass, name: [*c]ObjString) bool {
    var method: Value = undefined;

    if (!tableGet(&klass.*.methods, name, &method)) {
        runtimeError("Undefined property '{s}'.", .{@as([]u8, @ptrCast(@alignCast(name.*.chars[0..@intCast(name.*.length)])))});
        return false;
    }
    const bound: [*c]ObjBoundMethod = object_h.newBoundMethod(peek(0), @as([*c]ObjClosure, @ptrCast(@alignCast(method.as.obj))));
    _ = pop();
    push(Value.init_obj(@ptrCast(@alignCast(bound))));
    return true;
}
pub fn captureUpvalue(local: [*c]Value) [*c]ObjUpvalue {
    var prevUpvalue: [*c]ObjUpvalue = null;

    var upvalue: [*c]ObjUpvalue = vm.openUpvalues;

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
pub fn closeUpvalues(last: [*c]Value) void {
    while ((vm.openUpvalues != null) and (vm.openUpvalues.*.location >= last)) {
        var upvalue: [*c]ObjUpvalue = vm.openUpvalues;
        _ = &upvalue;
        upvalue.*.closed = upvalue.*.location.*;
        upvalue.*.location = &upvalue.*.closed;
        vm.openUpvalues = upvalue.*.next;
    }
}
pub fn defineMethod(name: [*c]ObjString) void {
    const method: Value = peek(0);

    const klass: [*c]ObjClass = @ptrCast(@alignCast(peek(1).as.obj));
    _ = tableSet(&klass.*.methods, name, method);
    _ = pop();
}
pub fn isFalsey(value: Value) bool {
    return (value.type == .VAL_NIL) or ((value.type == .VAL_BOOL) and !value.as.boolean);
}

pub fn concatenate() void {
    var b: [*c]ObjString = @ptrCast(@alignCast(peek(0).as.obj));
    _ = &b;
    var a: [*c]ObjString = @ptrCast(@alignCast(peek(1).as.obj));
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

// pub fn setArray(array: [*c]ObjArray, index_1: c_int, value: Value)  void {
//     if (index_1 >= array.*.count) {
//         runtimeError("Index out of bounds.", .{});
//         return;
//     }
//     (blk: {
//         const tmp = index_1;
//         if (tmp >= 0) break :blk array.*.values + @as(usize, @intCast(tmp)) else break :blk array.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
//     }).* = value;
// }
pub fn setFloatVector(f: [*c]FloatVector, index_1: c_int, value: f64) void {
    if (index_1 >= f.*.count) {
        runtimeError("Index out of bounds.", .{});
        return;
    }
    (blk: {
        const tmp = index_1;
        if (tmp >= 0) break :blk f.*.data + @as(usize, @intCast(tmp)) else break :blk f.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).* = value;
}

inline fn get_slot(frame: [*c]CallFrame) u8 {
    // const slot: u8 = (blk: {
    //     const ref = &frame.*.ip;
    //     const tmp = ref.*;
    //     ref.* += 1;
    //     break :blk tmp;
    // }).*;
    const ref = &frame.*.ip;
    const tmp = ref.*;
    ref.* += 1;
    return tmp.*;
}

pub fn run() InterpretResult {
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
        const c_instruction_index = @as(c_int, @intCast(@as(u32, @truncate(instruction_index))));
        _ = debug_h.disassembleInstruction(chunk, c_instruction_index);
    }
    while (true) {
        while (true) {
            const instruction = frame.*.ip[0];
            frame.*.ip += 1;
            switch (@as(chunk_h.OpCode, @enumFromInt(instruction))) {
                .OP_CONSTANT => {
                    // C: (frame->closure->function->chunk.constants.values[(*frame->ip++)])
                    const constant = frame.*.closure.*.function.*.chunk.constants.values[frame.*.ip[0]];
                    frame.*.ip += 1;
                    push(constant);
                    break;
                },
                .OP_NIL => {
                    push(Value.init_nil());
                    break;
                },
                .OP_TRUE => {
                    push(Value.init_bool(true));
                    break;
                },
                .OP_FALSE => {
                    push(Value.init_bool(false));
                    break;
                },
                .OP_POP => {
                    _ = pop();
                    break;
                },
                .OP_GET_LOCAL => {
                    const slot: u8 = (blk: {
                        const ref = &frame.*.ip;
                        const tmp = ref.*;
                        ref.* += 1;
                        break :blk tmp;
                    }).*;
                    push(frame.*.slots[slot]);
                    break;
                },
                .OP_SET_LOCAL => {
                    // const slot: u8 = (blk: {
                    //     const ref = &frame.*.ip;
                    //     const tmp = ref.*;
                    //     ref.* += 1;
                    //     break :blk tmp;
                    // }).*;
                    const slot = get_slot(frame);
                    frame.*.slots[slot] = peek(0);
                    break;
                },
                .OP_GET_GLOBAL => {
                    const name: [*c]ObjString = @ptrCast(@alignCast(frame.*.closure.*.function.*.chunk.constants.values[
                        // (blk: {
                        //     const ref = &frame.*.ip;
                        //     const tmp = ref.*;
                        //     ref.* += 1;
                        //     break :blk tmp;
                        // }).*
                        get_slot(frame)
                    ].as.obj));
                    var value: Value = undefined;
                    if (!tableGet(&vm.globals, name, &value)) {
                        runtimeError("Undefined variable '{s}'.", .{zstr(name)});
                        return .INTERPRET_RUNTIME_ERROR;
                    }
                    push(value);
                    break;
                },
                .OP_DEFINE_GLOBAL => {
                    const name: [*c]ObjString = @ptrCast(@alignCast(frame.*.closure.*.function.*.chunk.constants.values[
                        (blk: {
                            const ref = &frame.*.ip;
                            const tmp = ref.*;
                            ref.* += 1;
                            break :blk tmp;
                        }).*
                    ].as.obj));
                    _ = tableSet(&vm.globals, name, peek(0));
                    _ = pop();
                    break;
                },
                .OP_SET_GLOBAL => {
                    const name: [*c]ObjString = @ptrCast(@alignCast(frame.*.closure.*.function.*.chunk.constants.values[
                        (blk: {
                            const ref = &frame.*.ip;
                            const tmp = ref.*;
                            ref.* += 1;
                            break :blk tmp;
                        }).*
                    ].as.obj));
                    if (tableSet(&vm.globals, name, peek(0))) {
                        _ = tableDelete(&vm.globals, name);
                        runtimeError("Undefined variable '{s}'.", .{zstr(name)});
                        return .INTERPRET_RUNTIME_ERROR;
                    }
                    break;
                },
                .OP_GET_UPVALUE => {
                    const slot: u8 = (blk: {
                        const ref = &frame.*.ip;
                        const tmp = ref.*;
                        ref.* += 1;
                        break :blk tmp;
                    }).*;
                    push(frame.*.closure.*.upvalues[slot].*.location.*);
                    break;
                },
                .OP_SET_UPVALUE => {
                    const slot: u8 = (blk: {
                        const ref = &frame.*.ip;
                        const tmp = ref.*;
                        ref.* += 1;
                        break :blk tmp;
                    }).*;
                    frame.*.closure.*.upvalues[slot].*.location.* = peek(0);
                    break;
                },
                .OP_GET_PROPERTY => {
                    if (!isObjType(peek(0), .OBJ_INSTANCE)) {
                        runtimeError("Only instances have properties.", .{});
                        return .INTERPRET_RUNTIME_ERROR;
                    }
                    const instance: [*c]ObjInstance = @as([*c]ObjInstance, @ptrCast(@alignCast(peek(0).as.obj)));
                    const name: [*c]ObjString = @ptrCast(@alignCast(frame.*.closure.*.function.*.chunk.constants.values[
                        (blk: {
                            const ref = &frame.*.ip;
                            const tmp = ref.*;
                            ref.* += 1;
                            break :blk tmp;
                        }).*
                    ].as.obj));
                    var value: Value = undefined;
                    if (tableGet(&instance.*.fields, name, &value)) {
                        _ = pop();
                        push(value);
                        break;
                    }
                    if (!bindMethod(instance.*.klass, name)) {
                        return .INTERPRET_RUNTIME_ERROR;
                    }
                    break;
                },
                .OP_SET_PROPERTY => {
                    if (!isObjType(peek(1), .OBJ_INSTANCE)) {
                        runtimeError("Only instances have fields.", .{});
                        return .INTERPRET_RUNTIME_ERROR;
                    }
                    const instance: [*c]ObjInstance = @as([*c]ObjInstance, @ptrCast(@alignCast(peek(1).as.obj)));
                    _ = tableSet(&instance.*.fields, @ptrCast(@alignCast(frame.*.closure.*.function.*.chunk.constants.values[
                        (blk: {
                            const ref = &frame.*.ip;
                            const tmp = ref.*;
                            ref.* += 1;
                            break :blk tmp;
                        }).*
                    ].as.obj)), peek(0));
                    const value: Value = pop();
                    _ = pop();
                    push(value);
                    break;
                },
                .OP_GET_SUPER => {
                    const name: [*c]ObjString = @ptrCast(@alignCast(frame.*.closure.*.function.*.chunk.constants.values[
                        (blk: {
                            const ref = &frame.*.ip;
                            const tmp = ref.*;
                            ref.* += 1;
                            break :blk tmp;
                        }).*
                    ].as.obj));
                    const superclass: [*c]ObjClass = @ptrCast(@alignCast(pop().as.obj));
                    if (!bindMethod(superclass, name)) {
                        return .INTERPRET_RUNTIME_ERROR;
                    }
                    break;
                },
                .OP_GET_ITERATOR => {
                    // {
                    //     _ = printf("Index get\n");
                    //     var idx: c_int = @as(c_int, @bitCast(@as(c_uint, (blk: {
                    //         const ref = &frame.*.ip;
                    //         const tmp = ref.*;
                    //         ref.* += 1;
                    //         break :blk tmp;
                    //     }).*)));
                    //     _ = &idx;
                    //     var array: Value = frame.*.closure.*.function.*.chunk.constants.values[
                    //         (blk: {
                    //             const ref = &frame.*.ip;
                    //             const tmp = ref.*;
                    //             ref.* += 1;
                    //             break :blk tmp;
                    //         }).*
                    //     ];
                    //     _ = &array;
                    //     printValue(array);
                    //     if (!isObjType(array, .OBJ_ARRAY)) {
                    //         runtimeError("Only arrays support indexing.", .{});
                    //         return .INTERPRET_RUNTIME_ERROR;
                    //     }
                    //     var arrObj = @as([*c]ObjArray, @ptrCast(@alignCast(array.as.obj)));
                    //     _ = &arrObj;
                    //     if ((idx < 0) or (idx >= arrObj.*.count)) {
                    //         runtimeError("Index out of bounds.", .{});
                    //         return .INTERPRET_RUNTIME_ERROR;
                    //     }
                    //     push((blk: {
                    //         const tmp = idx;
                    //         if (tmp >= 0) break :blk arrObj.*.values + @as(usize, @intCast(tmp)) else break :blk arrObj.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                    //     }).*);
                    //     break;
                    // }
                },
                .OP_INDEX_GET => {

                    // _ = printf("Index get\n");
                    // var idx: c_int = @as(c_int, @bitCast(@as(c_uint, (blk: {
                    //     const ref = &frame.*.ip;
                    //     const tmp = ref.*;
                    //     ref.* += 1;
                    //     break :blk tmp;
                    // }).*)));
                    // _ = &idx;
                    // var array: Value = frame.*.closure.*.function.*.chunk.constants.values[
                    //     (blk: {
                    //         const ref = &frame.*.ip;
                    //         const tmp = ref.*;
                    //         ref.* += 1;
                    //         break :blk tmp;
                    //     }).*
                    // ];
                    // _ = &array;
                    // printValue(array);
                    // if (!isObjType(array, .OBJ_ARRAY)) {
                    //     runtimeError("Only arrays support indexing.", .{});
                    //     return .INTERPRET_RUNTIME_ERROR;
                    // }
                    // var arrObj = @as([*c]ObjArray, @ptrCast(@alignCast(array.as.obj)));
                    // _ = &arrObj;
                    // if ((idx < 0) or (idx >= arrObj.*.count)) {
                    //     runtimeError("Index out of bounds.", .{});
                    //     return .INTERPRET_RUNTIME_ERROR;
                    // }
                    // push((blk: {
                    //     const tmp = idx;
                    //     if (tmp >= 0) break :blk arrObj.*.values + @as(usize, @intCast(tmp)) else break :blk arrObj.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                    // }).*);
                    // break;

                },
                .OP_INDEX_SET => {

                    // var value: Value = pop();
                    //
                    // const index_1: Value = pop();
                    //
                    // var array: Value = peek(@as(c_int, 2));
                    // _ = &array;
                    // if (!isObjType(array, .OBJ_ARRAY)) {
                    //     runtimeError("Only arrays support indexing.", .{});
                    //     return .INTERPRET_RUNTIME_ERROR;
                    // }
                    // if (!(index_1.type == .VAL_INT)) {
                    //     runtimeError("Array index must be an integer.", .{});
                    //     return .INTERPRET_RUNTIME_ERROR;
                    // }
                    // var idx: c_int = index_1.as.num_int;
                    // _ = &idx;
                    // var arrObj = @as([*c]ObjArray, @ptrCast(@alignCast(array.as.obj)));
                    // _ = &arrObj;
                    // if ((idx < 0) or (idx >= arrObj.*.count)) {
                    //     runtimeError("Index out of bounds.", .{});
                    //     return .INTERPRET_RUNTIME_ERROR;
                    // }
                    // (blk: {
                    //     const tmp = idx;
                    //     if (tmp >= 0) break :blk arrObj.*.values + @as(usize, @intCast(tmp)) else break :blk arrObj.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                    // }).* = value;
                    // break;

                },
                // .OP_ARRAY => {
                //     const count: c_int = @intCast((blk: {
                //         const ref = &frame.*.ip;
                //         const tmp = ref.*;
                //         ref.* += 1;
                //         break :blk tmp;
                //     }).*);
                //     const array = object_h.newArrayWithCap(count, 1 != 0);

                //     for (0..@intCast(count)) |i| {
                //         pushArray(array, peek(count - @as(u8, @intCast(i)) - 1));
                //     }

                //     for (0..@intCast(count)) |_| {
                //         _ = pop();
                //     }

                //     push(Value.init_obj(@ptrCast(@alignCast(array))));
                //     break;
                // },
                .OP_FVECTOR => {
                    const count: c_int = @as(c_int, @bitCast(@as(c_uint, (blk: {
                        const ref = &frame.*.ip;
                        const tmp = ref.*;
                        ref.* += 1;
                        break :blk tmp;
                    }).*)));
                    const f = fvec.FloatVector.init(count);
                    for (0..@intCast(count)) |i| {
                        FloatVector.push(f, peek((count - @as(c_int, @intCast(i))) - 1).as_num_double());
                    }
                    for (0..@intCast(count)) |_| {
                        _ = pop();
                    }
                    push(Value.init_obj(@ptrCast(@alignCast(f))));
                    break;
                },
                .OP_EQUAL => {
                    const b: Value = pop();
                    const a: Value = pop();
                    push(Value.init_bool(valuesEqual(a, b)));
                    break;
                },
                .OP_GREATER => {
                    const b = pop();
                    const a = pop();
                    const result = value_h.valueCompare(a, b);
                    push(Value.init_bool(result == 1));
                    break;
                },
                .OP_LESS => {
                    const b = pop();
                    const a = pop();
                    const result = value_h.valueCompare(a, b);
                    push(Value.init_bool(result == -1));
                    break;
                },
                .OP_ADD => {
                    if (isObjType(peek(0), .OBJ_STRING) and (isObjType(peek(1), .OBJ_STRING))) {
                        concatenate();
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

                    break;
                },
                .OP_SUBTRACT => {
                    if ((isObjType(peek(0), .OBJ_FVECTOR)) and (isObjType(peek(1), .OBJ_FVECTOR))) {
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
                .OP_MULTIPLY => {
                    if ((isObjType(peek(0), .OBJ_FVECTOR)) and (isObjType(peek(1), .OBJ_FVECTOR))) {
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
                .OP_DIVIDE => {
                    if ((isObjType(peek(0), .OBJ_FVECTOR)) and (isObjType(peek(1), .OBJ_FVECTOR))) {
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
                .OP_MODULO => {
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
                .OP_EXPONENT => {
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
                .OP_NOT => {
                    push(Value{
                        .type = .VAL_BOOL,
                        .as = .{
                            .boolean = isFalsey(pop()),
                        },
                    });
                    break;
                },
                .OP_NEGATE => {
                    push(pop().negate());
                    break;
                },
                .OP_PRINT => {
                    {
                        printValue(pop());
                        _ = printf("\n");
                        break;
                    }
                },
                .OP_JUMP => {
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
                .OP_JUMP_IF_FALSE => {
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
                .OP_JUMP_IF_DONE => {
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
                        if (!isObjType(val, .OBJ_FVECTOR)) {
                            runtimeError("Operand must be a vector.", .{});
                            return .INTERPRET_RUNTIME_ERROR;
                        } else {
                            var fvector = @as([*c]FloatVector, @ptrCast(@alignCast(val.as.obj)));
                            _ = &fvector;
                            if (!fvec.hasNextFloatVector(fvector)) {
                                frame.*.ip += @as(usize, @bitCast(@as(isize, @intCast(@as(c_int, @bitCast(@as(c_uint, offset)))))));
                            } else {
                                push(Value{
                                    .type = .VAL_DOUBLE,
                                    .as = .{
                                        .num_double = fvec.nextFloatVector(fvector),
                                    },
                                });
                            }
                        }
                        break;
                    }
                },
                .OP_ITERATOR_NEXT => {
                    // var offset: u16 = blk: {
                    //     frame.*.ip += @as(usize, @bitCast(@as(isize, @intCast(@as(c_int, 2)))));
                    //     break :blk @as(u16, @bitCast(@as(c_short, @truncate((@as(c_int, @bitCast(@as(c_uint, (blk_1: {
                    //         const tmp = -@as(c_int, 2);
                    //         if (tmp >= 0) break :blk_1 frame.*.ip + @as(usize, @intCast(tmp)) else break :blk_1 frame.*.ip - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                    //     }).*))) << @intCast(8)) | @as(c_int, @bitCast(@as(c_uint, (blk_1: {
                    //         const tmp = -1;
                    //         if (tmp >= 0) break :blk_1 frame.*.ip + @as(usize, @intCast(tmp)) else break :blk_1 frame.*.ip - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                    //     }).*)))))));
                    // };
                    // _ = &offset;
                    // frame.*.ip -= @as(usize, @bitCast(@as(isize, @intCast(@as(c_int, @bitCast(@as(c_uint, offset)))))));
                    // break;
                },
                .OP_LOOP => {
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
                },
                .OP_CALL => {
                    const argCount: c_int = @as(c_int, @bitCast(@as(c_uint, (blk: {
                        const ref = &frame.*.ip;
                        const tmp = ref.*;
                        ref.* += 1;
                        break :blk tmp;
                    }).*)));

                    if (!callValue(peek(argCount), argCount)) {
                        return .INTERPRET_RUNTIME_ERROR;
                    }
                    if (vm.frameCount - 1 < 0) return .INTERPRET_RUNTIME_ERROR;
                    frame = &vm.frames[@intCast(vm.frameCount - 1)];
                    break;
                },
                .OP_INVOKE => {
                    const method: [*c]ObjString = @ptrCast(@alignCast(frame.*.closure.*.function.*.chunk.constants.values[
                        (blk: {
                            const ref = &frame.*.ip;
                            const tmp = ref.*;
                            ref.* += 1;
                            break :blk tmp;
                        }).*
                    ].as.obj));

                    const argCount: c_int = @as(c_int, @bitCast(@as(c_uint, (blk: {
                        const ref = &frame.*.ip;
                        const tmp = ref.*;
                        ref.* += 1;
                        break :blk tmp;
                    }).*)));

                    if (!invoke(method, argCount)) {
                        return .INTERPRET_RUNTIME_ERROR;
                    }
                    frame = &vm.frames[@as(c_uint, @intCast(vm.frameCount - 1))];
                    break;
                },
                .OP_SUPER_INVOKE => {
                    const method: [*c]ObjString = @ptrCast(@alignCast(frame.*.closure.*.function.*.chunk.constants.values[
                        (blk: {
                            const ref = &frame.*.ip;
                            const tmp = ref.*;
                            ref.* += 1;
                            break :blk tmp;
                        }).*
                    ].as.obj));

                    const argCount: c_int = @as(c_int, @bitCast(@as(c_uint, (blk: {
                        const ref = &frame.*.ip;
                        const tmp = ref.*;
                        ref.* += 1;
                        break :blk tmp;
                    }).*)));

                    var superclass: [*c]ObjClass = @ptrCast(@alignCast(pop().as.obj));
                    _ = &superclass;
                    if (!invokeFromClass(superclass, method, argCount)) {
                        return .INTERPRET_RUNTIME_ERROR;
                    }
                    frame = &vm.frames[@as(c_uint, @intCast(vm.frameCount - 1))];
                    break;
                },
                .OP_CLOSURE => {
                    const function: [*c]ObjFunction = @as([*c]ObjFunction, @ptrCast(@alignCast(frame.*.closure.*.function.*.chunk.constants.values[
                        (blk: {
                            const ref = &frame.*.ip;
                            const tmp = ref.*;
                            ref.* += 1;
                            break :blk tmp;
                        }).*
                    ].as.obj)));

                    const closure: [*c]ObjClosure = object_h.newClosure(function);

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
                            const index_1: u8 = (blk: {
                                const ref = &frame.*.ip;
                                const tmp = ref.*;
                                ref.* += 1;
                                break :blk tmp;
                            }).*;

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
                },
                .OP_CLOSE_UPVALUE => {
                    closeUpvalues(vm.stackTop - @as(usize, @bitCast(@as(isize, @intCast(1)))));
                    _ = pop();
                    break;
                },
                .OP_RETURN => {
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
                },
                .OP_CLASS => {
                    push(Value{
                        .type = .VAL_OBJ,
                        .as = .{
                            .obj = @as([*c]Obj, @ptrCast(@alignCast(object_h.newClass(@ptrCast(@alignCast(frame.*.closure.*.function.*.chunk.constants.values[
                                (blk: {
                                    const ref = &frame.*.ip;
                                    const tmp = ref.*;
                                    ref.* += 1;
                                    break :blk tmp;
                                }).*
                            ].as.obj)))))),
                        },
                    });
                    break;
                },
                .OP_INHERIT => {
                    var superclass: Value = peek(1);
                    _ = &superclass;
                    if (!isObjType(superclass, .OBJ_CLASS)) {
                        runtimeError("Superclass must be a class.", .{});
                        return .INTERPRET_RUNTIME_ERROR;
                    }
                    var subclass: [*c]ObjClass = @ptrCast(@alignCast(peek(0).as.obj));
                    _ = &subclass;
                    table_h.tableAddAll(&@as([*c]ObjClass, @ptrCast(@alignCast(superclass.as.obj))).*.methods, &subclass.*.methods);
                    _ = pop();
                    break;
                },
                .OP_METHOD => {
                    defineMethod(@ptrCast(@alignCast(frame.*.closure.*.function.*.chunk.constants.values[
                        (blk: {
                            const ref = &frame.*.ip;
                            const tmp = ref.*;
                            ref.* += 1;
                            break :blk tmp;
                        }).*
                    ].as.obj)));
                    break;
                },
                .OP_ITERATOR_HAS_NEXT => {},
            }
            break;
        }
    }
    return @import("std").mem.zeroes(InterpretResult);
}
