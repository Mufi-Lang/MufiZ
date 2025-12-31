const std = @import("std");
const print = std.debug.print;
const sqrt = std.math.sqrt;
const atan2 = std.math.atan2;
const cos = std.math.cos;
const sin = std.math.sin;
const tan = std.math.tan;

const debug_opts = @import("debug");

const chunk_h = @import("chunk.zig");
const Chunk = chunk_h.Chunk;
const OpCode = chunk_h.OpCode;
const compiler_h = @import("compiler.zig");
const debug_h = @import("debug.zig");
const errors = @import("errors.zig");
const mem_utils = @import("mem_utils.zig");
const memcpy = mem_utils.memcpyFast;
const strlen = mem_utils.strlen;
const memory_h = @import("memory.zig");
const freeObjects = memory_h.freeObjects;
const object_h = @import("object.zig");
const ObjClosure = object_h.ObjClosure;
const ObjString = object_h.ObjString;
const ObjUpvalue = object_h.ObjUpvalue;
const ObjFunction = object_h.ObjFunction;
const ObjNative = object_h.ObjNative;
const isObjType = object_h.isObjType;
const newUpvalue = object_h.newUpvalue;
const newBoundMethod = object_h.newBoundMethod;
const ObjInstance = object_h.ObjInstance;
const Instance = object_h.Instance;
const takeString = object_h.takeString;
const ObjLinkedList = object_h.LinkedList;
const equalLinkedList = object_h.equalLinkedList;
const Obj = object_h.Obj;
const NativeFn = object_h.NativeFn;
const ObjBoundMethod = object_h.ObjBoundMethod;
const ObjClass = object_h.ObjClass;
const copyString = object_h.copyString;
const fvec = @import("objects/fvec.zig");
const FloatVector = fvec.FloatVector;
const Matrix = object_h.Matrix;
const obj_range = @import("objects/range.zig");
const ObjRange = obj_range.ObjRange;
const simd_string = @import("simd_string.zig");
const SIMDString = simd_string.SIMDString;
const utils = @import("stdlib/utils.zig");
const table_h = @import("table.zig");
const tableGet = table_h.tableGet;
const tableSet = table_h.tableSet;
const tableDelete = table_h.tableDelete;
const Table = table_h.Table;
const initTable = table_h.initTable;
const freeTable = table_h.freeTable;
const value_h = @import("value.zig");
const printValue = value_h.printValue;
const valuesEqual = value_h.valuesEqual;
const Value = value_h.Value;
const Complex = value_h.Complex;

// const memcpy = @cImport(@cInclude("string.h")).memcpy;
// const strlen = @cImport(@cInclude("string.h")).strlen
// printf replaced with print from std import
var echo_enabled: bool = false; // Disable echo in REPL by default
var suppress_output: bool = false; // Don't suppress output - we want to see results
var repl_mode: bool = false; // Auto-detect REPL mode
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
    frames: [64]CallFrame = undefined,
    frameCount: i32 = 0,
    currentFrame: ?*CallFrame = null,
    chunk: ?*Chunk = null,
    ip: [*]u8,
    stack: [16384]Value,
    stackTop: usize = 0,
    globals: Table,
    globalConstants: Table,
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
    // Clear the entire VM structure to avoid undefined behavior
    @memset(@as([*]u8, @ptrCast(&vm))[0..@sizeOf(VM)], 0);

    resetStack();
    vm.objects = null;
    vm.bytesAllocated = 0;
    vm.nextGC = 1024 * 1024;

    vm.grayCount = 0;
    vm.grayCapacity = 0;
    vm.grayStack = null;

    initTable(&vm.globals);
    initTable(&vm.globalConstants);
    initTable(&vm.strings);

    vm.initString = copyString(@ptrCast("init"), 4);
    if (vm.initString == null) {
        @panic("Failed to create initString during VM initialization");
    }

    // Define SIMD-optimized native functions
    defineSIMDNatives();
}

pub const InterpretResult = enum(i32) {
    INTERPRET_OK = 0,
    INTERPRET_COMPILE_ERROR = 1,
    INTERPRET_RUNTIME_ERROR = 2,
    INTERPRET_FINISHED,
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

pub fn runtimeError(comptime format: []const u8, args: anytype) void {
    std.debug.print(format, args);
    std.debug.print("\n", .{});

    var i: i32 = @intCast(vm.frameCount - 1);
    while (i >= 0) : (i -= 1) {
        const frame = &vm.frames[@intCast(i)];
        const function = frame.*.closure.*.function;
        const instruction: usize = @intFromPtr(frame.ip) - @intFromPtr(function.*.chunk.code) - 1;

        std.debug.print("[line {d}] in ", .{function.*.chunk.lines.?[instruction]});
        if (function.*.name) |fn_name| {
            std.debug.print("{s}()\n", .{zstr(fn_name)});
        } else {
            std.debug.print("script\n", .{});
        }
    }

    resetStack();
}

pub fn defineNative(name: [*]const u8, function: NativeFn) void {
    const nameSlice = std.mem.span(@as([*:0]const u8, @ptrCast(name)));
    const nameString = object_h.copyNativeFunctionName(@ptrCast(nameSlice.ptr), @intCast(nameSlice.len));
    push(Value{
        .type = .VAL_OBJ,
        .as = .{ .obj = @ptrCast(@alignCast(nameString)) },
    });
    const native = object_h.newNative(function);
    push(Value{
        .type = .VAL_OBJ,
        .as = .{ .obj = @ptrCast(@alignCast(native)) },
    });
    _ = tableSet(&vm.globals, @ptrCast(@alignCast(vm.stack[0].as.obj)), vm.stack[1]);
    _ = pop();
    _ = pop();
}

pub fn freeVM() void {
    freeTable(&vm.globals);
    freeTable(&vm.globalConstants);
    freeTable(&vm.strings);
    vm.initString = null;
    freeObjects();
}

pub fn ZSTR(s: ?*ObjString) []const u8 {
    if (s) |str| {
        return str.chars[0..str.length];
    }
    return "";
}

pub fn zstr(s: ?*ObjString) []const u8 {
    return ZSTR(s);
}

pub fn interpret(source: [*]const u8) InterpretResult {
    const function: ?*ObjFunction = compiler_h.compile(source);
    if (function == null) {
        return .INTERPRET_COMPILE_ERROR;
    }

    // Only echo source in non-REPL mode when explicitly enabled
    if (echo_enabled and !repl_mode) {
        if (debug_opts.trace_exec) {
            var i: usize = 0;
            while (source[i] != 0) : (i += 1) {}
            print("Executing: {s}\n", .{source[0..i]});
        }
    }

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
    if (!call(closure, 0)) {
        return .INTERPRET_RUNTIME_ERROR;
    }
    return run();
}
pub inline fn push(value: Value) void {
    vm.stack[vm.stackTop] = value;
    vm.stackTop += 1;
}

pub inline fn pop() Value {
    vm.stackTop -= 1;
    return vm.stack[vm.stackTop];
}

fn get_slot(frame: *CallFrame) u8 {
    const result = frame.*.ip[0];
    frame.*.ip += 1;
    return result;
}

inline fn next_ip(frame: *CallFrame) void {
    frame.*.ip += 1;
}

pub fn resetStack() void {
    vm.stackTop = 0;
    vm.frameCount = 0;
    vm.currentFrame = null;
    vm.openUpvalues = null;
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
    frame.*.slots = @ptrCast(&vm.stack[vm.stackTop - @as(usize, @intCast(argCount + 1))]);

    return true;
}

pub fn callValue(callee: Value, argCount: i32) bool {
    if (callee.type == .VAL_OBJ) {
        switch (callee.as.obj.?.type) {
            .OBJ_BOUND_METHOD => {
                const bound: *ObjBoundMethod = @as(*ObjBoundMethod, @ptrCast(@alignCast(callee.as.obj)));
                // Replace the receiver with the bound instance
                vm.stack[vm.stackTop - @as(usize, @intCast(argCount + 1))] = bound.*.receiver;
                return call(bound.*.method, argCount);
            },
            .OBJ_CLASS => {
                const klass: *ObjClass = @as(*ObjClass, @ptrCast(@alignCast(callee.as.obj)));
                vm.stack[vm.stackTop - @as(usize, @intCast(argCount + 1))] = Value.init_obj(@ptrCast(@alignCast(object_h.newInstance(klass))));
                var initializer: Value = undefined;
                if (tableGet(&klass.*.methods, vm.initString.?, &initializer)) {
                    return call(@as(*ObjClosure, @ptrCast(@alignCast(initializer.as.obj))), argCount);
                } else if (argCount != 0) {
                    runtimeError("Expected 0 arguments but got {d}.", .{argCount});
                    return false;
                }
                return true;
            },
            .OBJ_CLOSURE => return call(@as(*ObjClosure, @ptrCast(@alignCast(callee.as.obj))), argCount),
            .OBJ_FUNCTION => {
                const function: *ObjFunction = @as(*ObjFunction, @ptrCast(@alignCast(callee.as.obj)));
                const closure: *ObjClosure = object_h.newClosure(function);
                return call(closure, argCount);
            },
            .OBJ_NATIVE => {
                const native: NativeFn = (@as(*ObjNative, @ptrCast(@alignCast(callee.as.obj)))).*.function;
                const result: Value = native.?(argCount, @ptrCast(&vm.stack[vm.stackTop - @as(usize, @intCast(argCount))]));
                vm.stackTop -= @as(usize, @intCast(argCount + 1));
                push(result);
                return true;
            },
            else => {}, // Non-callable object type
        }
    }
    runtimeError("Can only call functions and classes.", .{});
    return false;
}

fn captureUpvalue(local: [*]Value) *ObjUpvalue {
    var prevUpvalue: ?*ObjUpvalue = null;
    var upvalue: ?*ObjUpvalue = vm.openUpvalues;

    while (upvalue != null and @intFromPtr(upvalue.?.*.location) > @intFromPtr(local)) {
        prevUpvalue = upvalue;
        upvalue = upvalue.?.*.next;
    }

    if (upvalue != null and upvalue.?.*.location == local) {
        return upvalue.?;
    }

    const createdUpvalue: *ObjUpvalue = newUpvalue(local);
    createdUpvalue.*.next = upvalue;

    if (prevUpvalue == null) {
        vm.openUpvalues = createdUpvalue;
    } else {
        prevUpvalue.?.*.next = createdUpvalue;
    }

    return createdUpvalue;
}

fn closeUpvalues(last: [*]Value) void {
    while (vm.openUpvalues != null and @intFromPtr(vm.openUpvalues.?.*.location) >= @intFromPtr(last)) {
        const upvalue: *ObjUpvalue = vm.openUpvalues.?;
        upvalue.*.closed = upvalue.*.location[0];
        upvalue.*.location = @ptrCast(&upvalue.*.closed);
        vm.openUpvalues = upvalue.*.next;
    }
}

fn defineMethod(name: *ObjString) void {
    const method: Value = peek(0);
    const klass: *ObjClass = @as(*ObjClass, @ptrCast(@alignCast(peek(1).as.obj)));
    _ = tableSet(&klass.*.methods, name, method);
    _ = pop();
}

fn bindMethod(klass: *ObjClass, name: *ObjString) bool {
    var method: Value = undefined;
    if (!tableGet(&klass.*.methods, name, &method)) {
        runtimeError("Undefined property '{s}'.", .{zstr(name)});
        return false;
    }

    const bound: *ObjBoundMethod = newBoundMethod(peek(0), @as(*ObjClosure, @ptrCast(@alignCast(method.as.obj))));
    _ = pop();
    push(Value.init_obj(@ptrCast(@alignCast(bound))));
    return true;
}

fn invoke(name: *ObjString, argCount: i32) bool {
    const receiver: Value = peek(@intCast(argCount));

    if (!isObjType(receiver, .OBJ_INSTANCE)) {
        runtimeError("Only instances have methods.", .{});
        return false;
    }

    const instance: *ObjInstance = @as(*ObjInstance, @ptrCast(@alignCast(receiver.as.obj)));

    var value: Value = undefined;
    if (tableGet(&instance.*.fields, name, &value)) {
        vm.stack[vm.stackTop - @as(usize, @intCast(argCount + 1))] = value;
        return callValue(value, argCount);
    }

    return invokeFromClass(instance.*.klass, name, argCount);
}

fn invokeFromClass(klass: ?*ObjClass, name: *ObjString, argCount: i32) bool {
    var method: Value = undefined;
    if (!tableGet(&klass.?.methods, name, &method)) {
        runtimeError("Undefined method '{s}'.", .{zstr(name)});
        return false;
    }
    return call(@as(*ObjClosure, @ptrCast(@alignCast(method.as.obj))), argCount);
}

fn isFalsey(value: Value) bool {
    return value.type == .VAL_NIL or (value.type == .VAL_BOOL and !value.as.boolean);
}

inline fn getConstant(frame: *CallFrame, index: u8) ?Value {
    if (index >= frame.*.closure.*.function.*.chunk.constants.count) {
        return null;
    }
    return frame.*.closure.*.function.*.chunk.constants.values[index];
}

fn readOffset(frame: *CallFrame) u16 {
    const byte1: u8 = frame.*.ip[0];
    frame.*.ip += 1;
    const byte2: u8 = frame.*.ip[0];
    frame.*.ip += 1;
    return (@as(u16, byte1) << 8) | byte2;
}

// Set REPL mode for better user experience
pub fn setReplMode(enabled: bool) void {
    repl_mode = enabled;
    // In REPL mode, suppress echo and provide cleaner output
    if (enabled) {
        echo_enabled = false;
        suppress_output = false;
    }
}

// Enable or disable debug echo
pub fn setEcho(enabled: bool) void {
    echo_enabled = enabled;
}

// SIMD-optimized native function definitions (replacing regular versions)
pub fn defineSIMDNatives() void {
    // String functions use SIMD by default
    defineNative("find", simdFindNative);
    defineNative("equals", simdEqualsNative);
    defineNative("compare", simdCompareNative);

    // Vector math functions use SIMD by default
    defineNative("sin", vecSinNative);
    defineNative("cos", vecCosNative);
    defineNative("sqrt", vecSqrtNative);
    defineNative("abs", vecAbsNative);

    // Keep explicit SIMD names for advanced users
    defineNative("simd_find", simdFindNative);
    defineNative("simd_equals", simdEqualsNative);
    defineNative("simd_compare", simdCompareNative);
    defineNative("vec_sin", vecSinNative);
    defineNative("vec_cos", vecCosNative);
    defineNative("vec_sqrt", vecSqrtNative);
    defineNative("vec_abs", vecAbsNative);
}

// Native function wrappers for SIMD operations
pub fn simdMemcpyNative(argCount: i32, args: [*]Value) Value {
    _ = args; // autofix
    if (argCount != 2) {
        runtimeError("simd_memcpy() takes exactly 2 arguments.", .{});
        return Value.init_nil();
    }

    // Implementation would need proper object handling
    // This is a placeholder for the actual implementation
    return Value.init_bool(true);
}

pub fn simdFindNative(argCount: i32, args: [*]Value) Value {
    if (argCount != 2) {
        runtimeError("find() takes exactly 2 arguments.", .{});
        return Value.init_nil();
    }

    if (!args[0].is_string() or !args[1].is_string()) {
        runtimeError("find() requires string arguments.", .{});
        return Value.init_nil();
    }

    const haystack_str = args[0].as_string();
    const needle_str = args[1].as_string();

    const haystack = haystack_str.chars[0..haystack_str.length];
    const needle = needle_str.chars[0..needle_str.length];

    if (SIMDString.findSIMD(haystack, needle)) |pos| {
        return Value.init_int(@intCast(pos));
    } else {
        return Value.init_int(-1);
    }
}

pub fn simdEqualsNative(argCount: i32, args: [*]Value) Value {
    if (argCount != 2) {
        runtimeError("equals() takes exactly 2 arguments.", .{});
        return Value.init_nil();
    }

    if (!args[0].is_string() or !args[1].is_string()) {
        runtimeError("equals() requires string arguments.", .{});
        return Value.init_nil();
    }

    const str1 = args[0].as_string();
    const str2 = args[1].as_string();

    const s1 = str1.chars[0..str1.length];
    const s2 = str2.chars[0..str2.length];

    return Value.init_bool(SIMDString.equalsSIMD(s1, s2));
}

pub fn simdCompareNative(argCount: i32, args: [*]Value) Value {
    if (argCount != 2) {
        runtimeError("compare() takes exactly 2 arguments.", .{});
        return Value.init_nil();
    }

    if (!args[0].is_string() or !args[1].is_string()) {
        runtimeError("compare() requires string arguments.", .{});
        return Value.init_nil();
    }

    const str1 = args[0].as_string();
    const str2 = args[1].as_string();

    const s1 = str1.chars[0..str1.length];
    const s2 = str2.chars[0..str2.length];

    const result = SIMDString.compareSIMD(s1, s2);
    return Value.init_int(result);
}

pub fn vecSinNative(argCount: i32, args: [*]Value) Value {
    if (argCount != 1) {
        runtimeError("sin() takes exactly 1 argument.", .{});
        return Value.init_nil();
    }

    if (!args[0].is_fvec()) {
        runtimeError("sin() requires a FloatVector argument.", .{});
        return Value.init_nil();
    }

    const input_vec = args[0].as_fvec();
    const result = input_vec.sin_vec();
    return Value.init_obj(@ptrCast(result));
}

pub fn vecCosNative(argCount: i32, args: [*]Value) Value {
    if (argCount != 1) {
        runtimeError("cos() takes exactly 1 argument.", .{});
        return Value.init_nil();
    }

    if (!args[0].is_fvec()) {
        runtimeError("cos() requires a FloatVector argument.", .{});
        return Value.init_nil();
    }

    const input_vec = args[0].as_fvec();
    const result = input_vec.cos_vec();
    return Value.init_obj(@ptrCast(result));
}

pub fn vecSqrtNative(argCount: i32, args: [*]Value) Value {
    if (argCount != 1) {
        runtimeError("sqrt() takes exactly 1 argument.", .{});
        return Value.init_nil();
    }

    if (!args[0].is_fvec()) {
        runtimeError("sqrt() requires a FloatVector argument.", .{});
        return Value.init_nil();
    }

    const input_vec = args[0].as_fvec();
    const result = input_vec.sqrt_vec();
    return Value.init_obj(@ptrCast(result));
}

pub fn vecAbsNative(argCount: i32, args: [*]Value) Value {
    if (argCount != 1) {
        runtimeError("abs() takes exactly 1 argument.", .{});
        return Value.init_nil();
    }

    if (!args[0].is_fvec()) {
        runtimeError("abs() requires a FloatVector argument.", .{});
        return Value.init_nil();
    }

    const input_vec = args[0].as_fvec();
    const result = input_vec.abs_vec();
    return Value.init_obj(@ptrCast(result));
}

const OpHandler = *const fn () InterpretResult;

fn opConstant() InterpretResult {
    const frame = vm.currentFrame.?;
    const constant_index = frame.ip[0];
    frame.ip += 1;
    const constant = getConstant(frame, constant_index) orelse {
        runtimeError("Invalid constant index.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    };
    push(constant);
    return .INTERPRET_OK;
}

fn opNil() InterpretResult {
    push(Value.init_nil());
    return .INTERPRET_OK;
}

fn opTrue() InterpretResult {
    push(Value.init_bool(true));
    return .INTERPRET_OK;
}

fn opFalse() InterpretResult {
    push(Value.init_bool(false));
    return .INTERPRET_OK;
}

fn opPop() InterpretResult {
    _ = pop();
    return .INTERPRET_OK;
}

fn opGetLocal() InterpretResult {
    const frame = vm.currentFrame.?;
    const slot = frame.ip[0];
    frame.ip += 1;
    push(frame.slots[slot]);
    return .INTERPRET_OK;
}

fn opSetLocal() InterpretResult {
    const frame = vm.currentFrame.?;
    const slot = frame.ip[0];
    frame.ip += 1;
    frame.slots[slot] = peek(0);
    return .INTERPRET_OK;
}

fn opGetGlobal() InterpretResult {
    const frame = vm.currentFrame.?;
    const constant_index = frame.ip[0];
    frame.ip += 1;
    const constant = getConstant(frame, constant_index) orelse {
        runtimeError("Invalid constant index.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    };
    const name = constant.as_string();
    var value: Value = undefined;
    if (!tableGet(&vm.globals, name, &value)) {
        runtimeError("Undefined variable '{s}'.", .{name.chars});
        return .INTERPRET_RUNTIME_ERROR;
    }
    push(value);
    return .INTERPRET_OK;
}

fn opDefineGlobal() InterpretResult {
    const frame = vm.currentFrame.?;
    const constant_index = frame.ip[0];
    frame.ip += 1;
    const constant = getConstant(frame, constant_index) orelse {
        runtimeError("Invalid constant index.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    };
    const name = constant.as_string();
    _ = tableSet(&vm.globals, name, peek(0));
    _ = pop();
    return .INTERPRET_OK;
}

fn opDefineConstGlobal() InterpretResult {
    const frame = vm.currentFrame.?;
    const constant_index = frame.ip[0];
    frame.ip += 1;
    const constant = getConstant(frame, constant_index) orelse {
        runtimeError("Invalid constant index.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    };
    const name = constant.as_string();
    _ = tableSet(&vm.globals, name, peek(0));
    _ = tableSet(&vm.globalConstants, name, Value.init_bool(true));
    _ = pop();
    return .INTERPRET_OK;
}

fn opSetGlobal() InterpretResult {
    const frame = vm.currentFrame.?;
    const constant_index = frame.ip[0];
    frame.ip += 1;
    const constant = getConstant(frame, constant_index) orelse {
        runtimeError("Invalid constant index.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    };
    const name = constant.as_string();

    var dummy: Value = undefined;
    if (tableGet(&vm.globalConstants, name, &dummy)) {
        runtimeError("Cannot assign to constant variable '{s}'.", .{name.chars});
        return .INTERPRET_RUNTIME_ERROR;
    }

    if (tableSet(&vm.globals, name, peek(0))) {
        _ = tableDelete(&vm.globals, name);
        runtimeError("Undefined variable '{s}'.", .{name.chars});
        return .INTERPRET_RUNTIME_ERROR;
    }
    return .INTERPRET_OK;
}

fn opGetUpvalue() InterpretResult {
    const frame = vm.currentFrame.?;
    const slot = frame.ip[0];
    frame.ip += 1;
    push(frame.closure.upvalues.?[slot].?.location[0]);
    return .INTERPRET_OK;
}

fn opSetUpvalue() InterpretResult {
    const frame = vm.currentFrame.?;
    const slot = frame.ip[0];
    frame.ip += 1;
    frame.closure.upvalues.?[slot].?.location[0] = peek(0);
    return .INTERPRET_OK;
}

fn opGetProperty() InterpretResult {
    const frame = vm.currentFrame.?;
    const constant_index = frame.ip[0];
    frame.ip += 1;
    const constant = getConstant(frame, constant_index) orelse {
        runtimeError("Invalid constant index.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    };
    const name = constant.as_string();
    const receiver = peek(0);

    if (isObjType(receiver, .OBJ_INSTANCE)) {
        const instance: *ObjInstance = @ptrCast(@alignCast(receiver.as.obj));
        var value: Value = undefined;
        if (tableGet(&instance.fields, name, &value)) {
            _ = pop(); // Instance
            push(value);
            return .INTERPRET_OK;
        }

        if (!bindMethod(instance.klass, name)) {
            return .INTERPRET_RUNTIME_ERROR;
        }
        return .INTERPRET_OK;
    }

    runtimeError("Only instances have properties.", .{});
    return .INTERPRET_RUNTIME_ERROR;
}

fn opSetProperty() InterpretResult {
    const frame = vm.currentFrame.?;
    const constant_index = frame.ip[0];
    frame.ip += 1;
    const constant = getConstant(frame, constant_index) orelse {
        runtimeError("Invalid constant index.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    };
    const name = constant.as_string();
    const receiver = peek(1);

    if (isObjType(receiver, .OBJ_INSTANCE)) {
        const instance: *ObjInstance = @ptrCast(@alignCast(receiver.as.obj));
        _ = tableSet(&instance.fields, name, peek(0));
        const value = pop();
        _ = pop(); // Instance
        push(value);
        return .INTERPRET_OK;
    }

    runtimeError("Only instances have fields.", .{});
    return .INTERPRET_RUNTIME_ERROR;
}

fn opGetSuper() InterpretResult {
    const frame = vm.currentFrame.?;
    const constant_index = frame.ip[0];
    frame.ip += 1;
    const constant = getConstant(frame, constant_index) orelse {
        runtimeError("Invalid constant index.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    };
    const name = constant.as_string();
    const superclass: *ObjClass = @ptrCast(@alignCast(pop().as.obj));

    if (!bindMethod(superclass, name)) {
        return .INTERPRET_RUNTIME_ERROR;
    }
    return .INTERPRET_OK;
}

fn opEqual() InterpretResult {
    const b = pop();
    const a = pop();
    push(Value.init_bool(valuesEqual(a, b)));
    return .INTERPRET_OK;
}

fn opGreater() InterpretResult {
    if (!peek(0).is_prim_num() or !peek(1).is_prim_num()) {
        runtimeError("Operands must be numbers.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }
    const b = pop().as_num_double();
    const a = pop().as_num_double();
    push(Value.init_bool(a > b));
    return .INTERPRET_OK;
}

fn opLess() InterpretResult {
    if (!peek(0).is_prim_num() or !peek(1).is_prim_num()) {
        runtimeError("Operands must be numbers.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }
    const b = pop().as_num_double();
    const a = pop().as_num_double();
    push(Value.init_bool(a < b));
    return .INTERPRET_OK;
}

fn opGreaterEqual() InterpretResult {
    if (!peek(0).is_prim_num() or !peek(1).is_prim_num()) {
        runtimeError("Operands must be numbers.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }
    const b = pop().as_num_double();
    const a = pop().as_num_double();
    push(Value.init_bool(a >= b));
    return .INTERPRET_OK;
}

fn stringify(value: Value) ?*ObjString {
    if (value.is_string()) return value.as_string();
    if (value.is_int()) {
        var buffer: [32]u8 = undefined;
        const slice = std.fmt.bufPrint(&buffer, "{d}", .{value.as_int()}) catch return null;
        return object_h.copyString(slice.ptr, slice.len);
    }
    if (value.is_double()) {
        var buffer: [32]u8 = undefined;
        const slice = std.fmt.bufPrint(&buffer, "{d}", .{value.as_num_double()}) catch return null;
        return object_h.copyString(slice.ptr, slice.len);
    }
    if (value.is_bool()) {
        const str = if (value.as_bool()) "true" else "false";
        return object_h.copyString(str.ptr, str.len);
    }
    if (value.is_nil()) {
        return object_h.copyString("nil", 3);
    }

    const str = value_h.valueToString(value);
    return object_h.copyString(str.ptr, str.len);
}

fn opAdd() InterpretResult {
    if (peek(0).is_string() or peek(1).is_string()) {
        const b_val = peek(0);
        const a_val = peek(1);

        const a_str_ptr = stringify(a_val);
        if (a_str_ptr == null) {
            runtimeError("Operands must be two numbers or two strings.", .{});
            return .INTERPRET_RUNTIME_ERROR;
        }
        push(Value.init_obj(@ptrCast(a_str_ptr.?)));

        const b_str_ptr = stringify(b_val);
        if (b_str_ptr == null) {
            _ = pop();
            runtimeError("Operands must be two numbers or two strings.", .{});
            return .INTERPRET_RUNTIME_ERROR;
        }
        push(Value.init_obj(@ptrCast(b_str_ptr.?)));

        const b_str = peek(0).as_string();
        const a_str = peek(1).as_string();

        const length = a_str.length + b_str.length;
        const allocator = mem_utils.getAllocator();
        const chars_slice = mem_utils.alloc(allocator, u8, length + 1) catch {
            _ = pop();
            _ = pop();
            runtimeError("Out of memory.", .{});
            return .INTERPRET_RUNTIME_ERROR;
        };
        const chars_ptr: [*]u8 = chars_slice.ptr;
        @memcpy(chars_ptr[0..a_str.length], a_str.chars[0..a_str.length]);
        @memcpy(chars_ptr[a_str.length..length], b_str.chars[0..b_str.length]);
        chars_ptr[length] = 0;

        const result = object_h.takeString(chars_ptr, length);
        _ = pop();
        _ = pop();
        _ = pop();
        _ = pop();
        push(Value.init_obj(@ptrCast(result)));
    } else if (peek(0).is_complex() or peek(1).is_complex()) {
        const b = pop();
        const a = pop();

        const ca = if (a.is_complex()) a.as_complex() else Complex{ .r = if (a.is_int()) @floatFromInt(a.as_int()) else a.as_num_double(), .i = 0 };
        const cb = if (b.is_complex()) b.as_complex() else Complex{ .r = if (b.is_int()) @floatFromInt(b.as_int()) else b.as_num_double(), .i = 0 };

        push(Value.init_complex(Complex{ .r = ca.r + cb.r, .i = ca.i + cb.i }));
    } else if (peek(0).is_matrix() or peek(1).is_matrix()) {
        const b = pop();
        const a = pop();

        if (a.is_matrix() and b.is_matrix()) {
            const mat_a: *Matrix = @ptrCast(@alignCast(a.as.obj));
            const mat_b: *Matrix = @ptrCast(@alignCast(b.as.obj));
            const res = mat_a.add(mat_b);
            if (res == null) {
                runtimeError("Matrix dimension mismatch for addition.", .{});
                return .INTERPRET_RUNTIME_ERROR;
            }
            push(Value.init_obj(@ptrCast(res.?)));
        } else if (a.is_matrix() and b.is_prim_num()) {
            const mat_a: *Matrix = @ptrCast(@alignCast(a.as.obj));
            const val_b = if (b.is_int()) @as(f64, @floatFromInt(b.as_int())) else b.as_num_double();
            const res = mat_a.scalarMul(1.0); // Clone first
            const size = mat_a.rows * mat_a.cols;
            for (0..size) |i| {
                res.data[i] = mat_a.data[i] + val_b;
            }
            push(Value.init_obj(@ptrCast(res)));
        } else if (a.is_prim_num() and b.is_matrix()) {
            const val_a = if (a.is_int()) @as(f64, @floatFromInt(a.as_int())) else a.as_num_double();
            const mat_b: *Matrix = @ptrCast(@alignCast(b.as.obj));
            const res = mat_b.scalarMul(1.0); // Clone first
            const size = mat_b.rows * mat_b.cols;
            for (0..size) |i| {
                res.data[i] = mat_b.data[i] + val_a;
            }
            push(Value.init_obj(@ptrCast(res)));
        } else {
            runtimeError("Operands must be two numbers, two strings, or involve a vector/matrix.", .{});
            return .INTERPRET_RUNTIME_ERROR;
        }
    } else if (peek(0).is_fvec() or peek(1).is_fvec()) {
        const b = pop();
        const a = pop();

        if (a.is_fvec() and b.is_fvec()) {
            const vec_a: *FloatVector = @ptrCast(@alignCast(a.as.obj));
            const vec_b: *FloatVector = @ptrCast(@alignCast(b.as.obj));
            const res = vec_a.add(vec_b);
            push(Value.init_obj(@ptrCast(res)));
        } else if (a.is_fvec() and b.is_prim_num()) {
            const vec_a: *FloatVector = @ptrCast(@alignCast(a.as.obj));
            const val_b = if (b.is_int()) @as(f64, @floatFromInt(b.as_int())) else b.as_num_double();
            const res = vec_a.single_add(val_b);
            push(Value.init_obj(@ptrCast(res)));
        } else if (a.is_prim_num() and b.is_fvec()) {
            const val_a = if (a.is_int()) @as(f64, @floatFromInt(a.as_int())) else a.as_num_double();
            const vec_b: *FloatVector = @ptrCast(@alignCast(b.as.obj));
            const res = vec_b.single_add(val_a);
            push(Value.init_obj(@ptrCast(res)));
        } else {
            runtimeError("Operands must be two numbers, two strings, or involve a vector/matrix.", .{});
            return .INTERPRET_RUNTIME_ERROR;
        }
    } else if (peek(0).is_prim_num() and peek(1).is_prim_num()) {
        if (peek(0).is_double() or peek(1).is_double()) {
            const b = pop().as_num_double();
            const a = pop().as_num_double();
            push(Value.init_double(a + b));
        } else {
            const b = pop().as_int();
            const a = pop().as_int();
            push(Value.init_int(a + b));
        }
    } else {
        runtimeError("Operands must be two numbers or two strings.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }
    return .INTERPRET_OK;
}

fn opSubtract() InterpretResult {
    if (peek(0).is_complex() or peek(1).is_complex()) {
        const b = pop();
        const a = pop();

        const ca = if (a.is_complex()) a.as_complex() else Complex{ .r = if (a.is_int()) @floatFromInt(a.as_int()) else a.as_num_double(), .i = 0 };
        const cb = if (b.is_complex()) b.as_complex() else Complex{ .r = if (b.is_int()) @floatFromInt(b.as_int()) else b.as_num_double(), .i = 0 };

        push(Value.init_complex(Complex{ .r = ca.r - cb.r, .i = ca.i - cb.i }));
        return .INTERPRET_OK;
    }

    if (peek(0).is_matrix() or peek(1).is_matrix()) {
        const b = pop();
        const a = pop();

        if (a.is_matrix() and b.is_matrix()) {
            const mat_a: *Matrix = @ptrCast(@alignCast(a.as.obj));
            const mat_b: *Matrix = @ptrCast(@alignCast(b.as.obj));
            const res = mat_a.sub(mat_b);
            if (res == null) {
                runtimeError("Matrix dimension mismatch for subtraction.", .{});
                return .INTERPRET_RUNTIME_ERROR;
            }
            push(Value.init_obj(@ptrCast(res.?)));
        } else if (a.is_matrix() and b.is_prim_num()) {
            const mat_a: *Matrix = @ptrCast(@alignCast(a.as.obj));
            const val_b = if (b.is_int()) @as(f64, @floatFromInt(b.as_int())) else b.as_num_double();
            const res = mat_a.scalarMul(1.0); // Clone first
            const size = mat_a.rows * mat_a.cols;
            for (0..size) |i| {
                res.data[i] = mat_a.data[i] - val_b;
            }
            push(Value.init_obj(@ptrCast(res)));
        } else if (a.is_prim_num() and b.is_matrix()) {
            const val_a = if (a.is_int()) @as(f64, @floatFromInt(a.as_int())) else a.as_num_double();
            const mat_b: *Matrix = @ptrCast(@alignCast(b.as.obj));
            const res = mat_b.scalarMul(1.0); // Clone first
            const size = mat_b.rows * mat_b.cols;
            for (0..size) |i| {
                res.data[i] = val_a - mat_b.data[i];
            }
            push(Value.init_obj(@ptrCast(res)));
        } else {
            runtimeError("Operands must be numbers or vectors/matrices.", .{});
            return .INTERPRET_RUNTIME_ERROR;
        }
        return .INTERPRET_OK;
    }

    if (peek(0).is_fvec() or peek(1).is_fvec()) {
        const b = pop();
        const a = pop();

        if (a.is_fvec() and b.is_fvec()) {
            const vec_a: *FloatVector = @ptrCast(@alignCast(a.as.obj));
            const vec_b: *FloatVector = @ptrCast(@alignCast(b.as.obj));
            const res = vec_a.sub(vec_b);
            push(Value.init_obj(@ptrCast(res)));
        } else if (a.is_fvec() and b.is_prim_num()) {
            const vec_a: *FloatVector = @ptrCast(@alignCast(a.as.obj));
            const val_b = if (b.is_int()) @as(f64, @floatFromInt(b.as_int())) else b.as_num_double();
            const res = vec_a.single_sub(val_b);
            push(Value.init_obj(@ptrCast(res)));
        } else if (a.is_prim_num() and b.is_fvec()) {
            // Scalar - Vector -> Vector (element-wise: scalar - element)
            // Note: single_sub usually does vector - scalar.
            // We need to check if FloatVector supports scalar - vector or if we need to implement it.
            // Assuming single_sub is vector - scalar.
            // For scalar - vector, we might need to create a new vector where each element is scalar - vec[i].
            // Let's check if we can use scale(-1) then add scalar?
            // scalar - vec = scalar + (-vec)
            const val_a = if (a.is_int()) @as(f64, @floatFromInt(a.as_int())) else a.as_num_double();
            const vec_b: *FloatVector = @ptrCast(@alignCast(b.as.obj));
            // Create a new vector with val_a
            // This is inefficient but correct without modifying FloatVector
            // Better: implement scalar_sub in FloatVector, but I can't modify it right now easily without seeing it.
            // Let's try to use existing methods.
            // vec_b.scale(-1) -> -vec_b
            // then add val_a -> -vec_b + val_a = val_a - vec_b
            const neg_b = vec_b.scale(-1.0);
            const res = neg_b.single_add(val_a);
            // neg_b is a new object, res is a new object. We should free neg_b if it's not used.
            // But GC handles it.
            push(Value.init_obj(@ptrCast(res)));
        } else {
            runtimeError("Operands must be numbers or vectors/matrices.", .{});
            return .INTERPRET_RUNTIME_ERROR;
        }
        return .INTERPRET_OK;
    }

    if (!peek(0).is_prim_num() or !peek(1).is_prim_num()) {
        runtimeError("Operands must be numbers.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }
    if (peek(0).is_double() or peek(1).is_double()) {
        const b = pop().as_num_double();
        const a = pop().as_num_double();
        push(Value.init_double(a - b));
    } else {
        const b = pop().as_int();
        const a = pop().as_int();
        push(Value.init_int(a - b));
    }
    return .INTERPRET_OK;
}

fn opMultiply() InterpretResult {
    if (peek(0).is_complex() or peek(1).is_complex()) {
        const b = pop();
        const a = pop();

        const ca = if (a.is_complex()) a.as_complex() else Complex{ .r = if (a.is_int()) @floatFromInt(a.as_int()) else a.as_num_double(), .i = 0 };
        const cb = if (b.is_complex()) b.as_complex() else Complex{ .r = if (b.is_int()) @floatFromInt(b.as_int()) else b.as_num_double(), .i = 0 };

        // (a + bi) * (c + di) = (ac - bd) + (ad + bc)i
        push(Value.init_complex(Complex{
            .r = ca.r * cb.r - ca.i * cb.i,
            .i = ca.r * cb.i + ca.i * cb.r,
        }));
        return .INTERPRET_OK;
    }

    if (peek(0).is_matrix() or peek(1).is_matrix()) {
        const b = pop();
        const a = pop();

        if (a.is_matrix() and b.is_matrix()) {
            const mat_a: *Matrix = @ptrCast(@alignCast(a.as.obj));
            const mat_b: *Matrix = @ptrCast(@alignCast(b.as.obj));
            const res = mat_a.mul(mat_b);
            if (res == null) {
                runtimeError("Matrix dimension mismatch for multiplication.", .{});
                return .INTERPRET_RUNTIME_ERROR;
            }
            push(Value.init_obj(@ptrCast(res.?)));
        } else if (a.is_matrix() and b.is_prim_num()) {
            const mat_a: *Matrix = @ptrCast(@alignCast(a.as.obj));
            const val_b = if (b.is_int()) @as(f64, @floatFromInt(b.as_int())) else b.as_num_double();
            const res = mat_a.scalarMul(val_b);
            push(Value.init_obj(@ptrCast(res)));
        } else if (a.is_prim_num() and b.is_matrix()) {
            const val_a = if (a.is_int()) @as(f64, @floatFromInt(a.as_int())) else a.as_num_double();
            const mat_b: *Matrix = @ptrCast(@alignCast(b.as.obj));
            const res = mat_b.scalarMul(val_a);
            push(Value.init_obj(@ptrCast(res)));
        } else {
            runtimeError("Operands must be numbers or vectors/matrices.", .{});
            return .INTERPRET_RUNTIME_ERROR;
        }
        return .INTERPRET_OK;
    }

    if (peek(0).is_fvec() or peek(1).is_fvec()) {
        const b = pop();
        const a = pop();

        if (a.is_fvec() and b.is_fvec()) {
            const vec_a: *FloatVector = @ptrCast(@alignCast(a.as.obj));
            const vec_b: *FloatVector = @ptrCast(@alignCast(b.as.obj));
            const res = vec_a.mul(vec_b);
            push(Value.init_obj(@ptrCast(res)));
        } else if (a.is_fvec() and b.is_prim_num()) {
            const vec_a: *FloatVector = @ptrCast(@alignCast(a.as.obj));
            const val_b = if (b.is_int()) @as(f64, @floatFromInt(b.as_int())) else b.as_num_double();
            const res = vec_a.scale(val_b);
            push(Value.init_obj(@ptrCast(res)));
        } else if (a.is_prim_num() and b.is_fvec()) {
            const val_a = if (a.is_int()) @as(f64, @floatFromInt(a.as_int())) else a.as_num_double();
            const vec_b: *FloatVector = @ptrCast(@alignCast(b.as.obj));
            const res = vec_b.scale(val_a);
            push(Value.init_obj(@ptrCast(res)));
        } else {
            runtimeError("Operands must be numbers or vectors/matrices.", .{});
            return .INTERPRET_RUNTIME_ERROR;
        }
        return .INTERPRET_OK;
    }

    if (!peek(0).is_prim_num() or !peek(1).is_prim_num()) {
        runtimeError("Operands must be numbers.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }
    if (peek(0).is_double() or peek(1).is_double()) {
        const b = pop().as_num_double();
        const a = pop().as_num_double();
        push(Value.init_double(a * b));
    } else {
        const b = pop().as_int();
        const a = pop().as_int();
        push(Value.init_int(a * b));
    }
    return .INTERPRET_OK;
}

fn opDivide() InterpretResult {
    if (peek(0).is_complex() or peek(1).is_complex()) {
        const b = pop();
        const a = pop();

        const ca = if (a.is_complex()) a.as_complex() else Complex{ .r = if (a.is_int()) @floatFromInt(a.as_int()) else a.as_num_double(), .i = 0 };
        const cb = if (b.is_complex()) b.as_complex() else Complex{ .r = if (b.is_int()) @floatFromInt(b.as_int()) else b.as_num_double(), .i = 0 };

        // (a + bi) / (c + di) = ((ac + bd) / (c^2 + d^2)) + ((bc - ad) / (c^2 + d^2))i
        const denom = cb.r * cb.r + cb.i * cb.i;
        if (denom == 0) {
            runtimeError("Division by zero.", .{});
            return .INTERPRET_RUNTIME_ERROR;
        }

        push(Value.init_complex(Complex{
            .r = (ca.r * cb.r + ca.i * cb.i) / denom,
            .i = (ca.i * cb.r - ca.r * cb.i) / denom,
        }));
        return .INTERPRET_OK;
    }

    if (peek(0).is_fvec() or peek(1).is_fvec()) {
        const b = pop();
        const a = pop();

        if (a.is_fvec() and b.is_fvec()) {
            const vec_a: *FloatVector = @ptrCast(@alignCast(a.as.obj));
            const vec_b: *FloatVector = @ptrCast(@alignCast(b.as.obj));
            const res = vec_a.div(vec_b);
            push(Value.init_obj(@ptrCast(res)));
        } else if (a.is_fvec() and b.is_prim_num()) {
            const vec_a: *FloatVector = @ptrCast(@alignCast(a.as.obj));
            const val_b = if (b.is_int()) @as(f64, @floatFromInt(b.as_int())) else b.as_num_double();
            const res = vec_a.single_div(val_b);
            push(Value.init_obj(@ptrCast(res)));
        } else if (a.is_prim_num() and b.is_fvec()) {
            // Scalar / Vector -> Vector (element-wise: scalar / element)
            // We need to implement this.
            // Let's create a new vector where each element is scalar / vec[i]
            // Since we don't have a direct method, we can iterate.
            // But we can't easily iterate here without exposing internals or adding a method.
            // However, we can use map-like behavior if available, or just loop manually.
            // FloatVector has `data` field which is a slice.
            const val_a = if (a.is_int()) @as(f64, @floatFromInt(a.as_int())) else a.as_num_double();
            const vec_b: *FloatVector = @ptrCast(@alignCast(b.as.obj));

            const res = FloatVector.init(vec_b.count);
            res.count = vec_b.count;
            var i: usize = 0;
            while (i < vec_b.count) : (i += 1) {
                res.data[i] = val_a / vec_b.data[i];
            }
            push(Value.init_obj(@ptrCast(res)));
        } else {
            runtimeError("Operands must be numbers or vectors.", .{});
            return .INTERPRET_RUNTIME_ERROR;
        }
        return .INTERPRET_OK;
    }

    if (!peek(0).is_prim_num() or !peek(1).is_prim_num()) {
        runtimeError("Operands must be numbers.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }
    const b = pop().as_num_double();
    const a = pop().as_num_double();
    push(Value.init_double(a / b));
    return .INTERPRET_OK;
}

fn opModulo() InterpretResult {
    if (!peek(0).is_prim_num() or !peek(1).is_prim_num()) {
        runtimeError("Operands must be numbers.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }
    const b = pop().as_num_double();
    const a = pop().as_num_double();
    push(Value.init_double(@mod(a, b)));
    return .INTERPRET_OK;
}

fn opExponent() InterpretResult {
    if (!peek(0).is_prim_num() or !peek(1).is_prim_num()) {
        runtimeError("Operands must be numbers.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }
    const b = pop().as_num_double();
    const a = pop().as_num_double();
    push(Value.init_double(pow(a, b)));
    return .INTERPRET_OK;
}

fn opNot() InterpretResult {
    push(Value.init_bool(isFalsey(pop())));
    return .INTERPRET_OK;
}

fn opNegate() InterpretResult {
    if (!peek(0).is_prim_num()) {
        runtimeError("Operand must be a number.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }
    if (peek(0).is_int()) {
        push(Value.init_int(-pop().as_int()));
    } else {
        push(Value.init_double(-pop().as_num_double()));
    }
    return .INTERPRET_OK;
}

fn opPrint() InterpretResult {
    printValue(pop());
    print("\n", .{});
    return .INTERPRET_OK;
}

fn opJump() InterpretResult {
    const frame = vm.currentFrame.?;
    const offset = readOffset(frame);
    frame.ip += offset;
    return .INTERPRET_OK;
}

fn opJumpIfFalse() InterpretResult {
    const frame = vm.currentFrame.?;
    const offset = readOffset(frame);
    if (isFalsey(peek(0))) {
        frame.ip += offset;
    }
    return .INTERPRET_OK;
}

fn opLoop() InterpretResult {
    const frame = vm.currentFrame.?;
    const offset = readOffset(frame);
    frame.ip -= offset;
    return .INTERPRET_OK;
}

fn opCall() InterpretResult {
    const frame = vm.currentFrame.?;
    const argCount = frame.ip[0];
    frame.ip += 1;
    if (!callValue(peek(argCount), argCount)) {
        return .INTERPRET_RUNTIME_ERROR;
    }
    vm.currentFrame = &vm.frames[@intCast(vm.frameCount - 1)];
    return .INTERPRET_OK;
}

fn opInvoke() InterpretResult {
    const frame = vm.currentFrame.?;
    const constant_index = frame.ip[0];
    frame.ip += 1;
    const constant = getConstant(frame, constant_index) orelse {
        runtimeError("Invalid constant index.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    };
    const method = constant.as_string();
    const argCount = frame.ip[0];
    frame.ip += 1;
    if (!invoke(method, argCount)) {
        return .INTERPRET_RUNTIME_ERROR;
    }
    vm.currentFrame = &vm.frames[@intCast(vm.frameCount - 1)];
    return .INTERPRET_OK;
}

fn opSuperInvoke() InterpretResult {
    const frame = vm.currentFrame.?;
    const constant_index = frame.ip[0];
    frame.ip += 1;
    const constant = getConstant(frame, constant_index) orelse {
        runtimeError("Invalid constant index.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    };
    const method = constant.as_string();
    const argCount = frame.ip[0];
    frame.ip += 1;
    const superclass: *ObjClass = @ptrCast(@alignCast(pop().as.obj));
    if (!invokeFromClass(superclass, method, argCount)) {
        return .INTERPRET_RUNTIME_ERROR;
    }
    vm.currentFrame = &vm.frames[@intCast(vm.frameCount - 1)];
    return .INTERPRET_OK;
}

fn opClosure() InterpretResult {
    const frame = vm.currentFrame.?;
    const constant_index = frame.ip[0];
    frame.ip += 1;
    const constant = getConstant(frame, constant_index) orelse {
        runtimeError("Invalid constant index.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    };
    const function: *ObjFunction = @ptrCast(@alignCast(constant.as.obj));
    const closure = object_h.newClosure(function);
    push(Value.init_obj(@ptrCast(closure)));

    var i: i32 = 0;
    while (i < closure.upvalueCount) : (i += 1) {
        const isLocal = frame.ip[0];
        frame.ip += 1;
        const index = frame.ip[0];
        frame.ip += 1;
        if (isLocal == 1) {
            closure.upvalues.?[@intCast(i)] = captureUpvalue(@ptrCast(&frame.slots[index]));
        } else {
            closure.upvalues.?[@intCast(i)] = frame.closure.upvalues.?[index];
        }
    }
    return .INTERPRET_OK;
}

fn opCloseUpvalue() InterpretResult {
    closeUpvalues(@ptrCast(&vm.stack[vm.stackTop - 1]));
    _ = pop();
    return .INTERPRET_OK;
}

fn opReturn() InterpretResult {
    const result = pop();
    closeUpvalues(@ptrCast(&vm.currentFrame.?.slots[0]));
    vm.frameCount -= 1;
    if (vm.frameCount == 0) {
        _ = pop();
        return .INTERPRET_FINISHED;
    }

    vm.stackTop = (@intFromPtr(vm.currentFrame.?.slots) - @intFromPtr(&vm.stack)) / @sizeOf(Value);
    push(result);
    vm.currentFrame = &vm.frames[@intCast(vm.frameCount - 1)];
    return .INTERPRET_OK;
}

fn opClass() InterpretResult {
    const frame = vm.currentFrame.?;
    const constant_index = frame.ip[0];
    frame.ip += 1;
    const constant = getConstant(frame, constant_index) orelse {
        runtimeError("Invalid constant index.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    };
    const name = constant.as_string();
    const klass = object_h.newClass(name);
    push(Value.init_obj(@ptrCast(klass)));
    return .INTERPRET_OK;
}

fn opInherit() InterpretResult {
    const superclass = peek(1);
    if (!isObjType(superclass, .OBJ_CLASS)) {
        runtimeError("Superclass must be a class.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }
    const subclass: *ObjClass = @ptrCast(@alignCast(peek(0).as.obj));
    const super_klass: *ObjClass = @ptrCast(@alignCast(superclass.as.obj));
    table_h.tableAddAll(&super_klass.methods, &subclass.methods);
    _ = pop(); // Subclass
    return .INTERPRET_OK;
}

fn opMethod() InterpretResult {
    const frame = vm.currentFrame.?;
    const constant_index = frame.ip[0];
    frame.ip += 1;
    const constant = getConstant(frame, constant_index) orelse {
        runtimeError("Invalid constant index.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    };
    const name = constant.as_string();
    defineMethod(name);
    return .INTERPRET_OK;
}

fn opLength() InterpretResult {
    const value = pop();
    if (value.is_string()) {
        push(Value.init_int(@intCast(value.as_string().length)));
    } else if (value.is_obj()) {
        switch (value.as.obj.?.type) {
            .OBJ_RANGE => {
                const range: *ObjRange = @ptrCast(@alignCast(value.as.obj));
                push(range.get_length());
            },
            .OBJ_FVECTOR => {
                const vec: *FloatVector = @ptrCast(@alignCast(value.as.obj));
                push(Value.init_int(@intCast(vec.count)));
            },
            .OBJ_HASH_TABLE => {
                const table: *object_h.ObjHashTable = @ptrCast(@alignCast(value.as.obj));
                push(Value.init_int(@intCast(table.len())));
            },
            .OBJ_LINKED_LIST => {
                const list: *ObjLinkedList = @ptrCast(@alignCast(value.as.obj));
                push(Value.init_int(@intCast(list.count)));
            },
            .OBJ_PAIR => {
                push(Value.init_int(2));
            },
            else => {
                runtimeError("Object does not support length.", .{});
                return .INTERPRET_RUNTIME_ERROR;
            },
        }
    } else {
        runtimeError("Operand must be a string or range.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }
    return .INTERPRET_OK;
}

fn opGetIndex() InterpretResult {
    const index = pop();
    const target = pop();

    if (target.is_string()) {
        if (!index.is_int()) {
            runtimeError("Index must be an integer.", .{});
            return .INTERPRET_RUNTIME_ERROR;
        }
        const str = target.as_string();
        const idx = index.as_int();
        if (idx < 0 or idx >= str.length) {
            runtimeError("Index out of bounds.", .{});
            return .INTERPRET_RUNTIME_ERROR;
        }
        const char_str = copyString(@ptrCast(&str.chars[@intCast(idx)]), 1);
        push(Value.init_obj(@ptrCast(char_str)));
    } else if (target.is_obj()) {
        switch (target.as.obj.?.type) {
            .OBJ_RANGE => {
                const range: *ObjRange = @ptrCast(@alignCast(target.as.obj));
                if (!index.is_int()) {
                    runtimeError("Index must be an integer.", .{});
                    return .INTERPRET_RUNTIME_ERROR;
                }
                push(range.index(@intCast(index.as_int())));
            },
            .OBJ_FVECTOR => {
                const vec: *FloatVector = @ptrCast(@alignCast(target.as.obj));
                if (!index.is_int()) {
                    runtimeError("Index must be an integer.", .{});
                    return .INTERPRET_RUNTIME_ERROR;
                }
                var idx = index.as_int();
                if (idx < 0) {
                    idx += @as(i32, @intCast(vec.count));
                }
                if (idx < 0 or idx >= vec.count) {
                    runtimeError("Index out of bounds.", .{});
                    return .INTERPRET_RUNTIME_ERROR;
                }
                push(Value.init_double(vec.get(@intCast(idx))));
            },
            .OBJ_PAIR => {
                const pair: *object_h.ObjPair = @ptrCast(@alignCast(target.as.obj));
                if (!index.is_int()) {
                    runtimeError("Index must be an integer.", .{});
                    return .INTERPRET_RUNTIME_ERROR;
                }
                const idx = index.as_int();
                if (idx == 0) {
                    push(pair.key);
                } else if (idx == 1) {
                    push(pair.value);
                } else {
                    runtimeError("Pair index out of bounds (must be 0 or 1).", .{});
                    return .INTERPRET_RUNTIME_ERROR;
                }
            },
            .OBJ_HASH_TABLE => {
                const table: *object_h.ObjHashTable = @ptrCast(@alignCast(target.as.obj));
                if (!index.is_string()) {
                    runtimeError("Hash table key must be a string.", .{});
                    return .INTERPRET_RUNTIME_ERROR;
                }
                if (table.get(index.as_string())) |val| {
                    push(val);
                } else {
                    push(Value.init_nil());
                }
            },
            else => {
                runtimeError("Operand must be a string, range, array, or pair (got {any}).", .{target.as.obj.?.type});
                return .INTERPRET_RUNTIME_ERROR;
            },
        }
    } else {
        runtimeError("Operand must be a string or range (got {any}).", .{target.type});
        return .INTERPRET_RUNTIME_ERROR;
    }
    return .INTERPRET_OK;
}

fn opSlice() InterpretResult {
    const end = pop();
    const start = pop();
    const target = pop();

    if (target.is_string()) {
        if (!start.is_int() or !end.is_int()) {
            runtimeError("Slice indices must be integers.", .{});
            return .INTERPRET_RUNTIME_ERROR;
        }
        const str = target.as_string();
        const s = start.as_int();
        const e = end.as_int();

        if (s < 0 or e > str.length or s > e) {
            runtimeError("Invalid slice indices.", .{});
            return .INTERPRET_RUNTIME_ERROR;
        }

        const char_str = copyString(@ptrCast(&str.chars[@intCast(s)]), @intCast(e - s));
        push(Value.init_obj(@ptrCast(char_str)));
    } else if (target.is_obj() and target.as.obj.?.type == .OBJ_FVECTOR) {
        const vec: *FloatVector = @ptrCast(@alignCast(target.as.obj));
        if (!start.is_int() or !end.is_int()) {
            runtimeError("Slice indices must be integers.", .{});
            return .INTERPRET_RUNTIME_ERROR;
        }
        var s = start.as_int();
        var e = end.as_int();

        if (s < 0) s += @as(i32, @intCast(vec.count));
        if (e < 0) e += @as(i32, @intCast(vec.count));

        if (s < 0 or e >= vec.count or s > e) {
            runtimeError("Invalid slice indices.", .{});
            return .INTERPRET_RUNTIME_ERROR;
        }
        const new_vec = vec.slice(@intCast(s), @intCast(e));
        push(Value.init_obj(@ptrCast(new_vec)));
    } else {
        runtimeError("Operand must be a string or vector.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }
    return .INTERPRET_OK;
}

fn opRange() InterpretResult {
    const end = pop();
    const start = pop();

    if (!start.is_int() or !end.is_int()) {
        runtimeError("Range operands must be integers.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }

    const range = ObjRange.init(@intCast(start.as_int()), @intCast(end.as_int()), false);
    push(Value.init_obj(@ptrCast(range)));
    return .INTERPRET_OK;
}

fn opRangeInclusive() InterpretResult {
    const end = pop();
    const start = pop();

    if (!start.is_int() or !end.is_int()) {
        runtimeError("Range operands must be integers.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }

    const range = ObjRange.init(@intCast(start.as_int()), @intCast(end.as_int()), true);
    push(Value.init_obj(@ptrCast(range)));
    return .INTERPRET_OK;
}

fn opPair() InterpretResult {
    const value = pop();
    const key = pop();
    const pair = object_h.ObjPair.create(key, value);
    push(Value.init_obj(@ptrCast(pair)));
    return .INTERPRET_OK;
}

fn opCheckRange() InterpretResult {
    const value = pop();
    const range_val = pop();

    if (!range_val.is_obj() or range_val.as.obj.?.type != .OBJ_RANGE) {
        runtimeError("Expected range operand.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }

    const range: *ObjRange = @ptrCast(@alignCast(range_val.as.obj));
    push(Value.init_bool(range.equals(value)));
    return .INTERPRET_OK;
}

fn opIsRange() InterpretResult {
    const value = peek(0);
    push(Value.init_bool(value.is_obj() and value.as.obj.?.type == .OBJ_RANGE));
    return .INTERPRET_OK;
}

fn opGetRangeLength() InterpretResult {
    const value = pop();
    if (!value.is_obj() or value.as.obj.?.type != .OBJ_RANGE) {
        runtimeError("Expected range operand.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }
    const range: *ObjRange = @ptrCast(@alignCast(value.as.obj));
    push(range.get_length());
    return .INTERPRET_OK;
}

fn opSetIndex() InterpretResult {
    const value = pop();
    const index = pop();
    const target = pop();

    if (target.is_obj()) {
        switch (target.as.obj.?.type) {
            .OBJ_FVECTOR => {
                const vec: *FloatVector = @ptrCast(@alignCast(target.as.obj));
                if (!index.is_int()) {
                    runtimeError("Index must be an integer.", .{});
                    return .INTERPRET_RUNTIME_ERROR;
                }
                var idx = index.as_int();
                if (idx < 0) {
                    idx += @as(i32, @intCast(vec.count));
                }
                if (idx < 0 or idx >= vec.count) {
                    runtimeError("Index out of bounds.", .{});
                    return .INTERPRET_RUNTIME_ERROR;
                }
                if (!value.is_prim_num()) {
                    runtimeError("Value must be a number.", .{});
                    return .INTERPRET_RUNTIME_ERROR;
                }
                vec.set(@intCast(idx), value.as_num_double());
                push(value);
            },
            .OBJ_HASH_TABLE => {
                const table: *object_h.ObjHashTable = @ptrCast(@alignCast(target.as.obj));
                if (!index.is_string()) {
                    runtimeError("Hash table key must be a string.", .{});
                    return .INTERPRET_RUNTIME_ERROR;
                }
                _ = table.put(index.as_string(), value);
                push(value);
            },
            else => {
                runtimeError("Object does not support index assignment.", .{});
                return .INTERPRET_RUNTIME_ERROR;
            },
        }
    } else {
        runtimeError("Operand must be an object.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }
    return .INTERPRET_OK;
}

fn opDup() InterpretResult {
    push(peek(0));
    return .INTERPRET_OK;
}

fn opInt() InterpretResult {
    const frame = vm.currentFrame.?;
    const constant_index = frame.ip[0];
    frame.ip += 1;
    const constant = getConstant(frame, constant_index) orelse {
        runtimeError("Invalid constant index.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    };
    push(constant);
    return .INTERPRET_OK;
}

fn opHashTable() InterpretResult {
    const table = object_h.ObjHashTable.init();
    push(Value.init_obj(@ptrCast(table)));
    return .INTERPRET_OK;
}

fn opAddEntry() InterpretResult {
    const value = pop();
    const key = pop();
    const table_val = peek(0);

    if (!table_val.is_obj() or table_val.as.obj.?.type != .OBJ_HASH_TABLE) {
        runtimeError("Expected hash table.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }

    const table: *object_h.ObjHashTable = @ptrCast(@alignCast(table_val.as.obj));
    if (key.is_string()) {
        _ = table.put(key.as_string(), value);
    } else {
        runtimeError("Hash table keys must be strings.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }
    return .INTERPRET_OK;
}

fn opToString() InterpretResult {
    const value = pop();
    if (value.is_string()) {
        push(value);
    } else if (value.is_obj() and value.as.obj.?.type == .OBJ_RANGE) {
        const range: *ObjRange = @ptrCast(@alignCast(value.as.obj));
        push(range.toString());
    } else {
        // Fallback for other types if needed, or error
        runtimeError("Cannot convert to string.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }
    return .INTERPRET_OK;
}

fn opBreak() InterpretResult {
    // Should be handled by compiler emitting jumps
    return .INTERPRET_OK;
}

fn opContinue() InterpretResult {
    // Should be handled by compiler emitting jumps
    return .INTERPRET_OK;
}

fn opFVector() InterpretResult {
    const frame = vm.currentFrame.?;
    const count = frame.ip[0];
    frame.ip += 1;

    const vector = FloatVector.init(count);
    var i: i32 = @intCast(count);
    while (i > 0) : (i -= 1) {
        const val = peek(@intCast(i - 1));
        if (val.is_prim_num()) {
            vector.push(@floatCast(val.as_num_double()));
        } else {
            vector.push(0.0);
        }
    }
    vm.stackTop -= @intCast(count);
    push(Value.init_obj(@ptrCast(vector)));
    return .INTERPRET_OK;
}

fn opMatrix() InterpretResult {
    const frame = vm.currentFrame.?;
    const rows = frame.ip[0];
    const cols = frame.ip[1];
    frame.ip += 2;

    const matrix = Matrix.init(rows, cols);

    // Pop values from stack in reverse order (last pushed = first row)
    const total_elements = rows * cols;
    var i: usize = 0;
    while (i < total_elements) {
        const val = peek(@intCast(total_elements - 1 - i));
        if (val.is_prim_num()) {
            const row = i / cols;
            const col = i % cols;
            matrix.set(row, col, @floatCast(val.as_num_double()));
        } else {
            const row = i / cols;
            const col = i % cols;
            matrix.set(row, col, 0.0);
        }
        i += 1;
    }

    vm.stackTop -= total_elements;
    push(Value.init_obj(@ptrCast(matrix)));
    return .INTERPRET_OK;
}

fn opGetMatrixIndex() InterpretResult {
    const col_val = peek(0); // Column index (j)
    const row_val = peek(1); // Row index (i)
    const matrix_val = peek(2); // Matrix

    if (!matrix_val.is_matrix()) {
        runtimeError("Can only index matrices.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }

    if (!row_val.is_int() or !col_val.is_int()) {
        runtimeError("Matrix indices must be integers.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }

    const matrix = matrix_val.as_matrix();
    var row = row_val.as_int();
    var col = col_val.as_int();

    // Convert to 0-based indexing (MufiZ uses 1-based)
    row -= 1;
    col -= 1;

    // Handle negative indices (from end)
    if (row < 0) row += @intCast(matrix.rows);
    if (col < 0) col += @intCast(matrix.cols);

    if (row < 0 or row >= @as(i32, @intCast(matrix.rows)) or col < 0 or col >= @as(i32, @intCast(matrix.cols))) {
        runtimeError("Matrix index out of bounds.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }

    const element = matrix.get(@intCast(row), @intCast(col));

    // Pop the three values and push result
    vm.stackTop -= 3;
    push(Value.init_double(element));
    return .INTERPRET_OK;
}

fn opSetMatrixIndex() InterpretResult {
    const value_val = peek(0); // Value to set
    const col_val = peek(1); // Column index (j)
    const row_val = peek(2); // Row index (i)
    const matrix_val = peek(3); // Matrix

    if (!matrix_val.is_matrix()) {
        runtimeError("Can only index matrices.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }

    if (!row_val.is_int() or !col_val.is_int()) {
        runtimeError("Matrix indices must be integers.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }

    if (!value_val.is_prim_num()) {
        runtimeError("Matrix elements must be numbers.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }

    const matrix = matrix_val.as_matrix();
    var row = row_val.as_int();
    var col = col_val.as_int();

    // Convert to 0-based indexing (MufiZ uses 1-based)
    row -= 1;
    col -= 1;

    // Handle negative indices (from end)
    if (row < 0) row += @intCast(matrix.rows);
    if (col < 0) col += @intCast(matrix.cols);

    if (row < 0 or row >= @as(i32, @intCast(matrix.rows)) or col < 0 or col >= @as(i32, @intCast(matrix.cols))) {
        runtimeError("Matrix index out of bounds.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }

    const value = @as(f64, @floatCast(value_val.as_num_double()));
    matrix.set(@intCast(row), @intCast(col), value);

    // Pop the four values and push the matrix back
    vm.stackTop -= 4;
    push(matrix_val);
    return .INTERPRET_OK;
}

fn opUnknown() InterpretResult {
    const frame = vm.currentFrame.?;
    const instruction = (frame.ip - 1)[0];
    runtimeError("Unknown opcode: {d}", .{instruction});
    return .INTERPRET_RUNTIME_ERROR;
}

const jumpTable = blk: {
    var table: [256]OpHandler = undefined;
    for (0..256) |i| {
        table[i] = opUnknown;
    }
    table[@intFromEnum(OpCode.OP_CONSTANT)] = opConstant;
    table[@intFromEnum(OpCode.OP_NIL)] = opNil;
    table[@intFromEnum(OpCode.OP_TRUE)] = opTrue;
    table[@intFromEnum(OpCode.OP_FALSE)] = opFalse;
    table[@intFromEnum(OpCode.OP_POP)] = opPop;
    table[@intFromEnum(OpCode.OP_GET_LOCAL)] = opGetLocal;
    table[@intFromEnum(OpCode.OP_SET_LOCAL)] = opSetLocal;
    table[@intFromEnum(OpCode.OP_GET_GLOBAL)] = opGetGlobal;
    table[@intFromEnum(OpCode.OP_DEFINE_GLOBAL)] = opDefineGlobal;
    table[@intFromEnum(OpCode.OP_DEFINE_CONST_GLOBAL)] = opDefineConstGlobal;
    table[@intFromEnum(OpCode.OP_SET_GLOBAL)] = opSetGlobal;
    table[@intFromEnum(OpCode.OP_GET_UPVALUE)] = opGetUpvalue;
    table[@intFromEnum(OpCode.OP_SET_UPVALUE)] = opSetUpvalue;
    table[@intFromEnum(OpCode.OP_GET_PROPERTY)] = opGetProperty;
    table[@intFromEnum(OpCode.OP_SET_PROPERTY)] = opSetProperty;
    table[@intFromEnum(OpCode.OP_GET_SUPER)] = opGetSuper;
    table[@intFromEnum(OpCode.OP_EQUAL)] = opEqual;
    table[@intFromEnum(OpCode.OP_GREATER)] = opGreater;
    table[@intFromEnum(OpCode.OP_LESS)] = opLess;
    table[@intFromEnum(OpCode.OP_GREATER_EQUAL)] = opGreaterEqual;
    table[@intFromEnum(OpCode.OP_ADD)] = opAdd;
    table[@intFromEnum(OpCode.OP_SUBTRACT)] = opSubtract;
    table[@intFromEnum(OpCode.OP_MULTIPLY)] = opMultiply;
    table[@intFromEnum(OpCode.OP_DIVIDE)] = opDivide;
    table[@intFromEnum(OpCode.OP_MODULO)] = opModulo;
    table[@intFromEnum(OpCode.OP_EXPONENT)] = opExponent;
    table[@intFromEnum(OpCode.OP_NOT)] = opNot;
    table[@intFromEnum(OpCode.OP_NEGATE)] = opNegate;
    table[@intFromEnum(OpCode.OP_PRINT)] = opPrint;
    table[@intFromEnum(OpCode.OP_JUMP)] = opJump;
    table[@intFromEnum(OpCode.OP_JUMP_IF_FALSE)] = opJumpIfFalse;
    table[@intFromEnum(OpCode.OP_LOOP)] = opLoop;
    table[@intFromEnum(OpCode.OP_CALL)] = opCall;
    table[@intFromEnum(OpCode.OP_INVOKE)] = opInvoke;
    table[@intFromEnum(OpCode.OP_SUPER_INVOKE)] = opSuperInvoke;
    table[@intFromEnum(OpCode.OP_CLOSURE)] = opClosure;
    table[@intFromEnum(OpCode.OP_CLOSE_UPVALUE)] = opCloseUpvalue;
    table[@intFromEnum(OpCode.OP_RETURN)] = opReturn;
    table[@intFromEnum(OpCode.OP_CLASS)] = opClass;
    table[@intFromEnum(OpCode.OP_INHERIT)] = opInherit;
    table[@intFromEnum(OpCode.OP_METHOD)] = opMethod;
    table[@intFromEnum(OpCode.OP_LENGTH)] = opLength;
    table[@intFromEnum(OpCode.OP_GET_INDEX)] = opGetIndex;
    table[@intFromEnum(OpCode.OP_SLICE)] = opSlice;
    table[@intFromEnum(OpCode.OP_RANGE)] = opRange;
    table[@intFromEnum(OpCode.OP_RANGE_INCLUSIVE)] = opRangeInclusive;
    table[@intFromEnum(OpCode.OP_PAIR)] = opPair;
    table[@intFromEnum(OpCode.OP_CHECK_RANGE)] = opCheckRange;
    table[@intFromEnum(OpCode.OP_IS_RANGE)] = opIsRange;
    table[@intFromEnum(OpCode.OP_GET_RANGE_LENGTH)] = opGetRangeLength;
    table[@intFromEnum(OpCode.OP_SET_INDEX)] = opSetIndex;
    table[@intFromEnum(OpCode.OP_DUP)] = opDup;
    table[@intFromEnum(OpCode.OP_INT)] = opInt;
    table[@intFromEnum(OpCode.OP_HASH_TABLE)] = opHashTable;
    table[@intFromEnum(OpCode.OP_ADD_ENTRY)] = opAddEntry;
    table[@intFromEnum(OpCode.OP_TO_STRING)] = opToString;
    table[@intFromEnum(OpCode.OP_BREAK)] = opBreak;
    table[@intFromEnum(OpCode.OP_CONTINUE)] = opContinue;
    table[@intFromEnum(OpCode.OP_FVECTOR)] = opFVector;
    table[@intFromEnum(OpCode.OP_MATRIX)] = opMatrix;
    table[@intFromEnum(OpCode.OP_GET_MATRIX_INDEX)] = opGetMatrixIndex;
    table[@intFromEnum(OpCode.OP_SET_MATRIX_INDEX)] = opSetMatrixIndex;
    break :blk table;
};

pub fn run() InterpretResult {
    vm.currentFrame = &vm.frames[@intCast(vm.frameCount - 1)];

    while (true) {
        const frame = vm.currentFrame.?;
        if (debug_opts.trace_exec) {
            std.debug.print("          ", .{});
            var i: usize = 0;
            while (i < vm.stackTop) : (i += 1) {
                std.debug.print("[ ", .{});
                printValue(vm.stack[i]);
                std.debug.print(" ]", .{});
            }
            std.debug.print("\n", .{});
            const offset = @intFromPtr(frame.ip) - @intFromPtr(frame.closure.function.chunk.code);
            _ = debug_h.disassembleInstruction(&frame.closure.function.chunk, @intCast(offset));
        }
        const instruction = frame.ip[0];
        frame.ip += 1;

        const result = jumpTable[instruction]();
        if (result != .INTERPRET_OK) {
            if (result == .INTERPRET_FINISHED) return .INTERPRET_OK;
            return result;
        }
    }
}

inline fn peek(distance: u32) Value {
    return vm.stack[vm.stackTop - 1 - distance];
}
