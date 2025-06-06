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
// const memcpy = @cImport(@cInclude("string.h")).memcpy;
// const strlen = @cImport(@cInclude("string.h")).strlen
const mem_utils = @import("mem_utils.zig");
const memcpy = mem_utils.memcpyFast;
const strlen = mem_utils.strlen;
const ObjClosure = object_h.ObjClosure;
const ObjString = object_h.ObjString;
const ObjUpvalue = object_h.ObjUpvalue;
const ObjFunction = object_h.ObjFunction;
const ObjNative = object_h.ObjNative;
const fvec = @import("objects/fvec.zig");

const FloatVector = fvec.FloatVector;
// printf replaced with print from std import
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
const ObjLinkedList = object_h.ObjLinkedList;
const equalLinkedList = object_h.equalLinkedList;
const valuesEqual = value_h.valuesEqual;

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

pub const FRAMES_MAX = @as(i32, 64);
pub const STACK_MAX = FRAMES_MAX * UINT8_COUNT;
pub const UINT8_COUNT = UINT8_MAX + 1;
pub const UINT8_MAX: i32 = @intCast(std.math.maxInt(u8));

pub const CallFrame = struct {
    closure: *ObjClosure,
    ip: [*]u8,
    slots: [*]Value,
};

pub const VM = struct {
    frames: [64]CallFrame = std.mem.zeroes([64]CallFrame),
    frameCount: i32 = 0,
    chunk: ?*Chunk = null,
    ip: [*]u8,
    stack: [16384]Value,
    stackTop: [*]Value = undefined,
    globals: Table,
    strings: Table,
    initString: ?*ObjString = null,
    openUpvalues: ?*ObjUpvalue = null,
    bytesAllocated: u128 = 0,
    nextGC: u128 = 1024 * 1024,
    objects: ?*Obj = null,
    grayCount: i32 = 0,
    grayCapacity: i32 = 0,
    grayStack: ?[*][*]Obj = null,
};

pub fn initVM() void {
    resetStack();
    vm.objects = null;
    vm.bytesAllocated = 0;
    vm.nextGC = 1024 * 1024;

    vm.grayCount = 0;
    vm.grayCapacity = 0;
    vm.grayStack = null;

    initTable(&vm.globals);
    initTable(&vm.strings); // Initialize strings table first

    vm.initString = copyString(@ptrCast("init"), 4); // Create initString after tables are ready
}

pub const InterpretResult = enum(i32) {
    INTERPRET_OK = 0,
    INTERPRET_COMPILE_ERROR = 1,
    INTERPRET_RUNTIME_ERROR = 2,
};

inline fn pow(a: f64, b: f64) f64 {
    return std.math.pow(f64, a, b);
}

pub var vm: VM = undefined;

inline fn next_frame_count() i32 {
    const ref = &vm.frameCount;
    const tmp = ref.*;
    ref.* += 1;
    return tmp;
}

inline fn set_stack_top(argc: i32, value: Value) void {
    const tmp = -argc - 1;
    // if (tmp >= 0) break :blk vm.stackTop + @as(usize, @intCast(tmp)) else break :blk vm.stackTop - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    var ref: [*]Value = undefined;
    if (tmp >= 0) {
        ref = vm.stackTop + @as(usize, @intCast(tmp));
    } else {
        ref = vm.stackTop - @as(usize, @intCast(-tmp - 1));
    }
    ref[0] = value;
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

        stderr.print("[line {d}] in ", .{function.*.chunk.lines.?[instruction]}) catch {};

        if (function.*.name == null) {
            stderr.writeAll("script\n") catch {};
        } else {
            const nameObj = function.*.name.?;
            const name = nameObj.chars;
            const len: usize = @intCast(nameObj.length);
            const nameSlice = name[0..len];
            stderr.print("{s}()\n", .{nameSlice}) catch {};
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
    // defineNative("array", &cstd_h.array_nf);
    defineNative("linked_list", cstd_h.linkedlist_nf);
    defineNative("hash_table", cstd_h.hashtable_nf);
    // defineNative("matrix", &cstd_h.matrix_nf);
    defineNative("fvec", cstd_h.fvector_nf);
    // defineNative("range", &cstd_h.range_nf);
    defineNative("linspace", cstd_h.linspace_nf);
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

inline fn zstr(s: ?*ObjString) []u8 {
    if (s) |str| {
        const len: usize = @intCast(str.length);
        return str.chars[0..len];
    } else {
        return @constCast("null");
    }
}

pub fn interpret(source: [*]const u8) InterpretResult {
    const function: ?*ObjFunction = compiler_h.compile(source);
    if (function == null) return .INTERPRET_COMPILE_ERROR;
    push(Value{
        .type = .VAL_OBJ,
        .as = .{ .obj = @ptrCast(@alignCast(function)) },
    });
    const closure: *ObjClosure = object_h.newClosure(@ptrCast(function));
    _ = pop();
    push(Value{
        .type = .VAL_OBJ,
        .as = .{ .obj = @ptrCast(@alignCast(closure)) },
    });
    _ = call(closure, 0);
    return run();
}
pub inline fn push(value: Value) void {
    vm.stackTop[0] = value;
    vm.stackTop += 1;
}
pub inline fn pop() Value {
    vm.stackTop -= 1;
    return vm.stackTop[0];
}
pub fn defineNative(name: [*]const u8, function: NativeFn) void {
    // Push the name string and the function object onto the stack
    // This ensures GC doesn't collect them during allocation
    push(Value.init_obj(@ptrCast(@alignCast(copyString(name, @intCast(strlen(name)))))));
    push(Value.init_obj(@ptrCast(@alignCast(object_h.newNative(function)))));

    // Store them in the global table
    _ = table_h.tableSet(&vm.globals, @ptrCast(@alignCast(vm.stack[0].as.obj)), vm.stack[1]);

    // Pop them now that they're stored safely
    _ = pop();
    _ = pop();
}

pub fn resetStack() void {
    vm.stackTop = @ptrCast(&vm.stack);
    vm.frameCount = 0;
    vm.openUpvalues = null;
}

pub inline fn peek(distance: i32) Value {
    const tmp = -1 - distance;
    if (tmp >= 0) {
        return (vm.stackTop + @as(usize, @intCast(tmp)))[0];
    } else {
        return (vm.stackTop - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1)))[0];
    }
}

pub fn call(closure: *ObjClosure, argCount: i32) bool {
    if (argCount != closure.*.function.*.arity) {
        runtimeError("Expected {d} arguments but got {d}.", .{ closure.*.function.*.arity, argCount });
        return false;
    }
    if (vm.frameCount == @as(i32, 64)) {
        runtimeError("Stack overflow.", .{});
        return false;
    }
    const frame: *CallFrame = &vm.frames[@intCast(next_frame_count())];
    frame.*.closure = closure;
    frame.*.ip = closure.*.function.*.chunk.code.?;

    // The slots pointer should point to the first argument, which is 'self' for methods
    frame.*.slots = @ptrFromInt(@intFromPtr(vm.stackTop) - @sizeOf(Value) * @as(usize, @intCast(argCount + 1)));

    return true;
}
pub fn callValue(callee: Value, argCount: i32) bool {
    if (callee.type == .VAL_OBJ) {
        switch (callee.as.obj.?.type) {
            .OBJ_BOUND_METHOD => {
                const bound: *ObjBoundMethod = @as(*ObjBoundMethod, @ptrCast(@alignCast(callee.as.obj)));

                set_stack_top(argCount, bound.*.receiver);
                return call(bound.*.method, argCount);
            },
            .OBJ_CLASS => {
                const klass: *ObjClass = @ptrCast(@alignCast(callee.as.obj));

                // Create instance
                const instance = object_h.newInstance(klass);

                // Create the instance value
                const instanceValue = Value.init_obj(@ptrCast(@alignCast(instance)));

                // Calculate where 'self' should go on the stack (below the arguments)
                const selfSlot = vm.stackTop - @as(usize, @intCast(argCount + 1));

                // Set the selfSlot to the instance value - this ensures 'self' is available in methods
                selfSlot[0] = instanceValue;

                // Call initializer if it exists
                if (vm.initString != null) {
                    var initializer: Value = undefined;
                    if (tableGet(&klass.*.methods, vm.initString, &initializer)) {
                        // Validate the initializer is a closure
                        if (initializer.type != .VAL_OBJ or !isObjType(initializer, .OBJ_CLOSURE)) {
                            runtimeError("Class initializer must be a function.", .{});
                            return false;
                        }

                        return call(@as(*ObjClosure, @ptrCast(@alignCast(initializer.as.obj))), argCount);
                    } else if (argCount != 0) {
                        runtimeError("Expected 0 arguments but got {d}.", .{argCount});
                        return false;
                    }
                }

                return true;
            },
            .OBJ_CLOSURE => return call(@as(*ObjClosure, @ptrCast(@alignCast(callee.as.obj))), argCount),
            .OBJ_INSTANCE => {
                const klass: *ObjClass = @ptrCast(@alignCast(callee.as.obj));
                set_stack_top(argCount, Value.init_obj(@ptrCast(@alignCast(object_h.newInstance(klass)))));

                return true;
            },
            .OBJ_NATIVE => {
                const native: NativeFn = @as(*ObjNative, @ptrCast(@alignCast(callee.as.obj))).*.function;
                if (native == null) {
                    runtimeError("Native function is null.", .{});
                    return false;
                }
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

pub fn invokeFromClass(klass: ?*ObjClass, name: *ObjString, argCount: i32) bool {
    // Validate input parameters
    if (klass == null) {
        runtimeError("Cannot invoke methods on null class.", .{});
        return false;
    }

    var method: Value = undefined;
    if (!tableGet(&klass.?.methods, name, &method)) {
        const len: usize = @intCast(name.*.length);
        runtimeError("Undefined property '{s}'.", .{name.*.chars[0..len]});
        return false;
    }

    // Make sure we're calling a method
    if (method.type != .VAL_OBJ or !isObjType(method, .OBJ_CLOSURE)) {
        runtimeError("Can only call functions and classes.", .{});
        return false;
    }

    return call(@ptrCast(@alignCast(method.as.obj)), argCount);
}

pub fn invoke(name: *ObjString, argCount: i32) bool {
    const receiver: Value = peek(argCount);
    // First check if we're dealing with an instance
    if (!object_h.isObjType(receiver, .OBJ_INSTANCE)) {
        runtimeError("Only instances have methods.", .{});
        return false;
    }

    const instance: *ObjInstance = @as(*ObjInstance, @ptrCast(@alignCast(receiver.as.obj)));

    var value: Value = undefined;

    // Check fields first
    if (tableGet(&instance.*.fields, name, &value)) {
        set_stack_top(argCount, value);
        return callValue(value, argCount);
    }

    // Then try methods from the class
    return invokeFromClass(instance.*.klass, name, argCount);
}

pub fn bindMethod(klass: *ObjClass, name: *ObjString) bool {
    var method: Value = undefined;

    if (!tableGet(&klass.*.methods, name, &method)) {
        runtimeError("Undefined property '{s}'.", .{zstr(name)});
        return false;
    }
    const bound: *ObjBoundMethod = object_h.newBoundMethod(peek(0), @ptrCast(@alignCast(method.as.obj)));
    _ = pop();
    push(Value.init_obj(@ptrCast(@alignCast(bound))));
    return true;
}

pub fn captureUpvalue(local: [*]Value) *ObjUpvalue {
    var prevUpvalue: ?*ObjUpvalue = null;

    var upvalue: ?*ObjUpvalue = vm.openUpvalues;

    while ((upvalue != null) and (@intFromPtr(upvalue.?.location) > @intFromPtr(local))) {
        prevUpvalue = upvalue;
        upvalue = upvalue.?.next;
    }
    while ((upvalue != null) and (upvalue.?.location == local)) {
        return upvalue.?;
    }
    const createdUpvalue: *ObjUpvalue = object_h.newUpvalue(local);
    createdUpvalue.*.next = upvalue;
    if (prevUpvalue == null) {
        vm.openUpvalues = createdUpvalue;
    } else {
        prevUpvalue.?.next = createdUpvalue;
    }
    return createdUpvalue;
}

pub fn closeUpvalues(last: [*]Value) void {
    while ((vm.openUpvalues != null) and (@intFromPtr(vm.openUpvalues.?.location) >= @intFromPtr(last))) {
        var upvalue: *ObjUpvalue = vm.openUpvalues.?;
        _ = &upvalue;
        upvalue.*.closed = upvalue.*.location[0];
        upvalue.*.location = @as([*]Value, @ptrCast(&upvalue.*.closed));
        vm.openUpvalues = upvalue.*.next;
    }
}

pub fn defineMethod(name: *ObjString) void {
    const method: Value = peek(0);

    const klass: *ObjClass = @ptrCast(@alignCast(peek(1).as.obj));
    _ = tableSet(&klass.*.methods, name, method);
    _ = pop();
}

pub fn isFalsey(value: Value) bool {
    return (value.type == .VAL_NIL) or ((value.type == .VAL_BOOL) and !value.as.boolean);
}

pub fn setFloatVector(f: *FloatVector, index: i32, value: f64) void {
    if (index >= fvec._count(f)) {
        runtimeError("Index out of bounds.", .{});
        return;
    }
    fvec._write(f, index, value);
}

fn get_slot(frame: *CallFrame) u8 {
    // const ref = &frame.*.ip;
    // const tmp = ref.*;
    // ref.* += 1;
    // return tmp.*;
    const result = frame.ip[0];
    frame.ip += 1;
    return result;
}

/// Reads a 16-bit big-endian value from bytecode at the current instruction pointer
/// and advances the instruction pointer by 2 bytes.
///
/// Returns: The 16-bit value read from bytecode
fn readOffset(frame: *CallFrame) u16 {
    // Move instruction pointer forward by 2 bytes
    frame.*.ip += 2;

    // Read the 2 bytes we just passed (at IP-2 and IP-1)
    const high_byte = @as(*u8, @ptrCast(frame.*.ip - 2)).*;
    const low_byte = @as(*u8, @ptrCast(frame.*.ip - 1)).*;

    // Combine into a 16-bit value with explicit casts
    return (@as(u16, high_byte) << @as(u4, 8)) | @as(u16, low_byte);
}

// now work on this
pub fn run() InterpretResult {
    var frame: *CallFrame = &vm.frames[@intCast(vm.frameCount - 1)];
    if (debug_opts.trace_exec) {
        print("         ", .{});

        var slot: [*]Value = @ptrCast(@alignCast(&vm.stack));
        while (slot < vm.stackTop) : (slot += 1) {
            print("[ ", .{});
            printValue(slot.*);
            print(" ]", .{});
        }

        print("\n", .{});
        const chunk = &frame.*.closure.*.function.*.chunk;
        const offset = @intFromPtr(frame.*.ip) - @intFromPtr(frame.*.closure.*.function.*.chunk.code);
        const instruction_index = @divExact(offset, @sizeOf(u8));
        const c_instruction_index = @as(i32, @intCast(@as(u32, @truncate(instruction_index))));
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
                    continue;
                },
                .OP_NIL => {
                    push(Value.init_nil());
                    continue;
                },
                .OP_TRUE => {
                    push(Value.init_bool(true));
                    continue;
                },
                .OP_FALSE => {
                    push(Value.init_bool(false));
                    continue;
                },
                .OP_POP => {
                    _ = pop();
                    continue;
                },
                .OP_GET_LOCAL => {
                    const slot = get_slot(frame);
                    push(frame.*.slots[slot]);
                    continue;
                },
                .OP_SET_LOCAL => {
                    const slot = get_slot(frame);
                    frame.*.slots[slot] = peek(0);
                    continue;
                },
                .OP_GET_GLOBAL => {
                    const name: *ObjString = @ptrCast(@alignCast(frame.*.closure.*.function.*.chunk.constants.values[
                        get_slot(frame)
                    ].as.obj));
                    var value: Value = undefined;
                    if (!tableGet(&vm.globals, name, &value)) {
                        runtimeError("Undefined variable '{s}'.", .{zstr(name)});
                        return .INTERPRET_RUNTIME_ERROR;
                    }
                    push(value);
                    continue;
                },
                .OP_DEFINE_GLOBAL => {
                    const name: *ObjString = @ptrCast(@alignCast(frame.*.closure.*.function.*.chunk.constants.values[
                        get_slot(frame)
                    ].as.obj));
                    _ = tableSet(&vm.globals, name, peek(0));
                    _ = pop();
                    continue;
                },
                .OP_SET_GLOBAL => {
                    const name: *ObjString = @ptrCast(@alignCast(frame.*.closure.*.function.*.chunk.constants.values[
                        get_slot(frame)
                    ].as.obj));
                    if (tableSet(&vm.globals, name, peek(0))) {
                        _ = tableDelete(&vm.globals, name);
                        runtimeError("Undefined variable '{s}'.", .{zstr(name)});
                        return .INTERPRET_RUNTIME_ERROR;
                    }
                    continue;
                },
                .OP_GET_UPVALUE => {
                    const slot = get_slot(frame);
                    if (frame.*.closure.upvalues.?[slot]) |upvalue| {
                        push(upvalue.*.location[0]);
                    }
                    continue;
                },
                .OP_SET_UPVALUE => {
                    const slot = get_slot(frame);
                    if (frame.*.closure.*.upvalues.?[slot]) |upvalue| {
                        upvalue.*.location[0] = peek(0);
                    }
                    continue;
                },
                .OP_GET_PROPERTY => {
                    if (!isObjType(peek(0), .OBJ_INSTANCE)) {
                        runtimeError("Only instances have properties.", .{});
                        return .INTERPRET_RUNTIME_ERROR;
                    }
                    const instance: *ObjInstance = @as(*ObjInstance, @ptrCast(@alignCast(peek(0).as.obj)));
                    const name: *ObjString = @ptrCast(@alignCast(frame.*.closure.*.function.*.chunk.constants.values[
                        get_slot(frame)
                    ].as.obj));
                    var value: Value = undefined;
                    if (tableGet(&instance.*.fields, name, &value)) {
                        _ = pop();
                        push(value);
                        continue;
                    }
                    if (!bindMethod(instance.*.klass, name)) {
                        return .INTERPRET_RUNTIME_ERROR;
                    }
                    continue;
                },
                .OP_SET_PROPERTY => {
                    if (!isObjType(peek(1), .OBJ_INSTANCE)) {
                        runtimeError("Only instances have fields.", .{});
                        return .INTERPRET_RUNTIME_ERROR;
                    }
                    const instance: *ObjInstance = @as(*ObjInstance, @ptrCast(@alignCast(peek(1).as.obj)));
                    _ = tableSet(&instance.*.fields, @ptrCast(@alignCast(frame.*.closure.*.function.*.chunk.constants.values[
                        get_slot(frame)
                    ].as.obj)), peek(0));
                    const value: Value = pop();
                    _ = pop();
                    push(value);
                    continue;
                },
                .OP_GET_SUPER => {
                    const name: *ObjString = @ptrCast(@alignCast(frame.*.closure.*.function.*.chunk.constants.values[
                        get_slot(frame)
                    ].as.obj));

                    // Pop the superclass reference from stack (just removed, not used)
                    _ = pop();

                    // Get the instance (self) which should be on the stack
                    const instance = peek(0);
                    if (!isObjType(instance, .OBJ_INSTANCE)) {
                        runtimeError("Only instances have superclasses.", .{});
                        return .INTERPRET_RUNTIME_ERROR;
                    }

                    // Get the superclass from the instance's class
                    const instance_obj: *ObjInstance = @ptrCast(@alignCast(instance.as.obj));
                    const superclass = instance_obj.*.klass.*.superclass;

                    if (@intFromPtr(superclass) == 0) {
                        runtimeError("Object has no superclass.", .{});
                        return .INTERPRET_RUNTIME_ERROR;
                    }

                    const superName = zstr(superclass.?.name);
                    print("OP_GET_SUPER: Using superclass: {s}\n", .{superName});

                    // Look up the method in the superclass
                    var method_value: Value = undefined;
                    if (!tableGet(&superclass.?.methods, name, &method_value)) {
                        runtimeError("Undefined property '{s}'.", .{zstr(name)});
                        return .INTERPRET_RUNTIME_ERROR;
                    }

                    // Create a bound method using the instance and method
                    const bound = newBoundMethod(instance, @ptrCast(@alignCast(method_value.as.obj)));
                    _ = pop(); // Pop the instance
                    push(Value.init_obj(@ptrCast(@alignCast(bound))));

                    const nameStr = zstr(name);
                    print("OP_GET_SUPER: Found and bound method '{s}' in superclass\n", .{nameStr});
                    continue;
                },

                .OP_FVECTOR => {
                    const count: i32 = @as(i32, @bitCast(@as(c_uint, get_slot(frame))));
                    const f = fvec.FloatVector.init(@intCast(count));
                    for (0..@intCast(count)) |i| {
                        FloatVector.push(f, peek((count - @as(i32, @intCast(i))) - 1).as_num_double());
                    }
                    for (0..@intCast(count)) |_| {
                        _ = pop();
                    }
                    push(Value.init_obj(@ptrCast(@alignCast(f))));
                    continue;
                },
                .OP_EQUAL => {
                    const b: Value = pop();
                    const a: Value = pop();
                    push(Value.init_bool(valuesEqual(a, b)));
                    continue;
                },
                .OP_GREATER => {
                    const b = pop();
                    const a = pop();
                    const result = value_h.valueCompare(a, b);
                    push(Value.init_bool(result == 1));
                    continue;
                },
                .OP_LESS => {
                    const b = pop();
                    const a = pop();
                    const result = value_h.valueCompare(a, b);
                    push(Value.init_bool(result == -1));
                    continue;
                },
                .OP_ADD => {
                    const b = pop();
                    const a = pop();
                    if (a.is_nil()) {
                        runtimeError("Invalid Binary Operation.", .{});
                        return .INTERPRET_RUNTIME_ERROR;
                    }
                    push(a.add(b));
                    continue;
                },
                .OP_SUBTRACT => {
                    const b = pop();
                    const a = pop();

                    if (a.is_nil() or a.is_string()) {
                        runtimeError("Invalid Binary Operation.", .{});
                        return .INTERPRET_RUNTIME_ERROR;
                    }

                    push(a.sub(b));
                    continue;
                },
                .OP_MULTIPLY => {
                    const b = pop();
                    const a = pop();

                    if (a.is_nil() or a.is_string()) {
                        runtimeError("Invalid Binary Operation.", .{});
                        return .INTERPRET_RUNTIME_ERROR;
                    }

                    push(a.mul(b));
                    continue;
                },
                .OP_DIVIDE => {
                    const b = pop();
                    const a = pop();

                    if (a.is_nil() or a.is_string()) {
                        runtimeError("Invalid Binary Operation.", .{});
                        return .INTERPRET_RUNTIME_ERROR;
                    }

                    push(a.div(b));
                    continue;
                },
                .OP_MODULO => {
                    if (peek(0).is_int() and peek(1).is_int()) {
                        const b = pop().as_int();
                        const a = pop().as_int();
                        push(Value.init_int(@rem(a, b)));
                    } else {
                        runtimeError("Operands must be integers.", .{});
                        return .INTERPRET_RUNTIME_ERROR;
                    }
                    continue;
                },
                .OP_EXPONENT => {
                    if (peek(0).is_prim_num() and peek(1).is_prim_num()) {
                        const b = pop();
                        const a = pop();
                        push(Value.init_double(pow(a.as_num_double(), b.as_num_double())));
                    } else if (peek(0).is_complex() and peek(1).is_double()) {
                        // Complex number raised to real power
                        const b = pop().as_num_double();
                        const a = pop().as_complex();

                        // Calculate using polar form: r^b * e^(i*b*theta)
                        const r = sqrt((a.r * a.r) + (a.i * a.i));
                        const theta = atan2(a.i, a.r);

                        // Create result directly without temporary variable
                        push(Value.init_complex(Complex{
                            .r = pow(r, b) * cos(b * theta),
                            .i = pow(r, b) * sin(b * theta),
                        }));
                    } else {
                        runtimeError("Operands must be numeric type.", .{});
                        return .INTERPRET_RUNTIME_ERROR;
                    }
                    continue;
                },
                .OP_NOT => {
                    push(Value.init_bool(isFalsey(pop())));
                    continue;
                },
                .OP_NEGATE => {
                    push(pop().negate());
                    continue;
                },
                .OP_PRINT => {
                    printValue(pop());
                    print("\n", .{});
                    continue;
                },
                .OP_JUMP => {
                    const offset = readOffset(frame);
                    frame.*.ip += @as(usize, @intCast(offset));
                    continue;
                },
                .OP_JUMP_IF_FALSE => {
                    const offset = readOffset(frame);
                    if (isFalsey(peek(0))) {
                        frame.*.ip += @as(usize, @intCast(offset));
                    }
                    continue;
                },

                .OP_LOOP => {

                    // Read a 16-bit offset from bytecode and jump backward
                    const offset: u16 = blk: {
                        // Move instruction pointer forward by 2 bytes
                        frame.*.ip += 2;

                        // Read the 2 bytes we just passed (at IP-2 and IP-1)
                        const high_byte = @as(*u8, @ptrCast(frame.*.ip - 2)).*;
                        const low_byte = @as(*u8, @ptrCast(frame.*.ip - 1)).*;

                        // Combine into a 16-bit value with explicit casts
                        break :blk (@as(u16, high_byte) << @as(u4, 8)) | @as(u16, low_byte);
                    };

                    // Jump backward by the offset amount
                    frame.*.ip -= offset;
                    continue;
                },
                .OP_CALL => {
                    const argCount: i32 = @as(i32, @bitCast(@as(c_uint, get_slot(frame))));

                    if (!callValue(peek(argCount), argCount)) {
                        return .INTERPRET_RUNTIME_ERROR;
                    }
                    if (vm.frameCount - 1 < 0) return .INTERPRET_RUNTIME_ERROR;
                    frame = &vm.frames[@intCast(vm.frameCount - 1)];
                    continue;
                },
                .OP_INVOKE => {
                    const method: *ObjString = @ptrCast(@alignCast(frame.*.closure.*.function.*.chunk.constants.values[
                        get_slot(frame)
                    ].as.obj));

                    const count: i32 = @as(i32, @bitCast(@as(c_uint, get_slot(frame))));

                    if (!invoke(method, count)) {
                        return .INTERPRET_RUNTIME_ERROR;
                    }
                    frame = &vm.frames[@as(c_uint, @intCast(vm.frameCount - 1))];
                    continue;
                },
                .OP_SUPER_INVOKE => {
                    const method: *ObjString = @ptrCast(@alignCast(frame.*.closure.*.function.*.chunk.constants.values[
                        get_slot(frame)
                    ].as.obj));

                    const argCount: i32 = @as(i32, @bitCast(@as(c_uint, get_slot(frame))));

                    // Pop the superclass reference from stack
                    _ = pop();

                    // Get the instance (self)
                    const instance = peek(argCount);
                    if (!isObjType(instance, .OBJ_INSTANCE)) {
                        runtimeError("Only instances have superclasses.", .{});
                        return .INTERPRET_RUNTIME_ERROR;
                    }

                    // Get the superclass from the instance's class
                    const instance_obj: *ObjInstance = @ptrCast(@alignCast(instance.as.obj));
                    const superclass = instance_obj.*.klass.*.superclass;

                    if (@intFromPtr(superclass) == 0) {
                        runtimeError("Object has no superclass.", .{});
                        return .INTERPRET_RUNTIME_ERROR;
                    }

                    const superName = zstr(superclass.?.name);
                    print("OP_SUPER_INVOKE: Using superclass: {s}\n", .{superName});

                    // Get the method from the superclass
                    var method_value: Value = undefined;
                    if (!tableGet(&superclass.?.methods, method, &method_value)) {
                        runtimeError("Undefined method '{s}'.", .{zstr(method)});
                        return .INTERPRET_RUNTIME_ERROR;
                    }

                    const methodName = zstr(method);
                    print("OP_SUPER_INVOKE: Found method '{s}' in superclass\n", .{methodName});

                    // Call the method directly to avoid recursion
                    if (!invokeFromClass(superclass, method, argCount)) {
                        return .INTERPRET_RUNTIME_ERROR;
                    }

                    frame = &vm.frames[@as(c_uint, @intCast(vm.frameCount - 1))];
                    continue;
                },
                .OP_CLOSURE => {
                    const function: *ObjFunction = @as(*ObjFunction, @ptrCast(@alignCast(frame.*.closure.*.function.*.chunk.constants.values[
                        get_slot(frame)
                    ].as.obj)));

                    const closure: *ObjClosure = object_h.newClosure(function);

                    push(Value.init_obj(@ptrCast(@alignCast(closure))));

                    for (0..@intCast(closure.*.upvalueCount)) |i| {
                        const isLocal: u8 = get_slot(frame);
                        const index: u8 = get_slot(frame);

                        if (isLocal != 0) {
                            // Local variable being captured
                            closure.upvalues.?[i] = captureUpvalue(frame.*.slots + @as(usize, @intCast(index)));
                        } else {
                            // Upvalue from enclosing function
                            closure.upvalues.?[i] = frame.*.closure.upvalues.?[index];
                        }
                    }

                    continue;
                },
                .OP_CLOSE_UPVALUE => {
                    closeUpvalues(@ptrFromInt(@intFromPtr(vm.stackTop) - @sizeOf(Value)));
                    _ = pop();
                    continue;
                },
                .OP_RETURN => {
                    const result: Value = pop();
                    closeUpvalues(frame.*.slots);
                    vm.frameCount -= 1;
                    if (vm.frameCount == 0) {
                        _ = pop();
                        return .INTERPRET_OK;
                    }
                    vm.stackTop = frame.*.slots;
                    push(result);
                    frame = &vm.frames[@as(c_uint, @intCast(vm.frameCount - 1))];
                    continue;
                },
                .OP_CLASS => {
                    push(Value.init_obj(@ptrCast(@alignCast(object_h.newClass(@ptrCast(@alignCast(frame.*.closure.*.function.*.chunk.constants.values[
                        get_slot(frame)
                    ].as.obj)))))));
                    continue;
                },
                .OP_INHERIT => {
                    const superclass: Value = peek(1);
                    if (!isObjType(superclass, .OBJ_CLASS)) {
                        runtimeError("Superclass must be a class.", .{});
                        return .INTERPRET_RUNTIME_ERROR;
                    }
                    const subclass: *ObjClass = @ptrCast(@alignCast(peek(0).as.obj));

                    // Copy all methods from superclass to subclass
                    const superclassPtr = @as(*ObjClass, @ptrCast(@alignCast(superclass.as.obj)));
                    table_h.tableAddAll(&superclassPtr.*.methods, &subclass.*.methods);

                    // Store the superclass reference directly in the subclass
                    subclass.*.superclass = superclassPtr;

                    // Pop the superclass after storing it in the subclass field
                    _ = pop();
                    continue;
                },
                .OP_METHOD => {
                    defineMethod(@ptrCast(@alignCast(frame.*.closure.*.function.*.chunk.constants.values[
                        get_slot(frame)
                    ].as.obj)));
                    continue;
                },
                .OP_GET_INDEX => {
                    const index = pop();
                    const object = pop();

                    if (object.type == .VAL_OBJ and object.as.obj != null) {
                        switch (object.as.obj.?.type) {
                            .OBJ_FVECTOR => {
                                if (!index.is_int()) {
                                    runtimeError("Index must be an integer.", .{});
                                    return .INTERPRET_RUNTIME_ERROR;
                                }
                                const vector = @as(*fvec.FloatVector, @ptrCast(@alignCast(object.as.obj.?)));
                                const idx = index.as_num_int();
                                if (idx < 0 or idx >= vector.count) {
                                    runtimeError("Index out of bounds.", .{});
                                    return .INTERPRET_RUNTIME_ERROR;
                                }
                                const value = vector.get(@intCast(idx));
                                push(Value.init_double(value));
                            },
                            .OBJ_STRING => {
                                if (!index.is_int()) {
                                    runtimeError("Index must be an integer.", .{});
                                    return .INTERPRET_RUNTIME_ERROR;
                                }
                                const string = @as(*ObjString, @ptrCast(@alignCast(object.as.obj.?)));
                                const idx = index.as_num_int();
                                if (idx < 0 or idx >= string.length) {
                                    runtimeError("Index out of bounds.", .{});
                                    return .INTERPRET_RUNTIME_ERROR;
                                }
                                const char = string.chars[@intCast(idx)];
                                const char_str = object_h.copyString(@ptrCast(&char), 1);
                                push(Value.init_obj(@ptrCast(@alignCast(char_str))));
                            },
                            else => {
                                runtimeError("Object is not indexable.", .{});
                                return .INTERPRET_RUNTIME_ERROR;
                            },
                        }
                    } else {
                        runtimeError("Only objects can be indexed.", .{});
                        return .INTERPRET_RUNTIME_ERROR;
                    }
                    continue;
                },
                .OP_SET_INDEX => {
                    const value = pop();
                    const index = pop();
                    const object = peek(0); // Keep object on stack for assignment result

                    if (object.type == .VAL_OBJ and object.as.obj != null) {
                        switch (object.as.obj.?.type) {
                            .OBJ_FVECTOR => {
                                if (!index.is_int()) {
                                    runtimeError("Index must be an integer.", .{});
                                    return .INTERPRET_RUNTIME_ERROR;
                                }
                                if (!value.is_double() and !value.is_int()) {
                                    runtimeError("Value must be a number.", .{});
                                    return .INTERPRET_RUNTIME_ERROR;
                                }
                                const vector = @as(*fvec.FloatVector, @ptrCast(@alignCast(object.as.obj.?)));
                                const idx = index.as_num_int();
                                if (idx < 0 or idx >= vector.count) {
                                    runtimeError("Index out of bounds.", .{});
                                    return .INTERPRET_RUNTIME_ERROR;
                                }
                                vector.set(@intCast(idx), value.as_num_double());
                                // Leave the assigned value on stack
                                _ = pop(); // Remove object
                                push(value);
                            },
                            else => {
                                runtimeError("Object is not mutable or indexable.", .{});
                                return .INTERPRET_RUNTIME_ERROR;
                            },
                        }
                    } else {
                        runtimeError("Only objects can be indexed.", .{});
                        return .INTERPRET_RUNTIME_ERROR;
                    }
                    continue;
                },
            }
        }
    }
    return .INTERPRET_RUNTIME_ERROR;
}
