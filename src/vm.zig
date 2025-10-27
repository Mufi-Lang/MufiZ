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
const compiler_h = @import("compiler.zig");
const debug_h = @import("debug.zig");
const errors = @import("errors.zig");
const mem_utils = @import("mem_utils.zig");
const memcpy = mem_utils.memcpyFast;
const strlen = mem_utils.strlen;
const memory_h = @import("memory.zig");
const reallocate = memory_h.reallocate;
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
const ObjLinkedList = object_h.ObjLinkedList;
const equalLinkedList = object_h.equalLinkedList;
const Obj = object_h.Obj;
const NativeFn = object_h.NativeFn;
const ObjBoundMethod = object_h.ObjBoundMethod;
const ObjClass = object_h.ObjClass;
const copyString = object_h.copyString;
const fvec = @import("objects/fvec.zig");
const FloatVector = fvec.FloatVector;
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
var echo_enabled: bool = false; // Always disable echo in REPL
var suppress_output: bool = false; // Don't suppress output - we want to see results
var repl_mode: bool = true; // Default to REPL mode
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
    chunk: ?*Chunk = null,
    ip: [*]u8,
    stack: [16384]Value,
    stackTop: [*]Value = undefined,
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
    // Clear the entire VM structure to avoid undefined behavior in debug mode
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
    const nameString = copyString(@ptrCast(nameSlice.ptr), @intCast(nameSlice.len));
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
    std.debug.print("DEBUG: Entering interpret()\n", .{});
    const function: ?*ObjFunction = compiler_h.compile(source);
    if (function == null) {
        std.debug.print("DEBUG: Compilation failed\n", .{});
        return .INTERPRET_COMPILE_ERROR;
    }
    std.debug.print("DEBUG: Compilation successful\n", .{});

    // Only echo in non-REPL mode or when explicitly enabled
    if (echo_enabled and !repl_mode) {
        var i: usize = 0;
        while (source[i] != 0) : (i += 1) {}
        print("{s}\n", .{source[0..i]});
    }

    std.debug.print("DEBUG: About to push function\n", .{});
    push(Value{
        .type = .VAL_OBJ,
        .as = .{ .obj = @ptrCast(@alignCast(function)) },
    });
    std.debug.print("DEBUG: About to create closure\n", .{});
    const closure: *ObjClosure = object_h.newClosure(@ptrCast(function));
    _ = pop();
    std.debug.print("DEBUG: About to push closure\n", .{});
    push(Value{
        .type = .VAL_OBJ,
        .as = .{ .obj = @ptrCast(@alignCast(closure)) },
    });
    std.debug.print("DEBUG: About to call closure\n", .{});
    if (!call(closure, 0)) {
        std.debug.print("DEBUG: Call failed\n", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }
    std.debug.print("DEBUG: Call succeeded, about to run\n", .{});
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

fn get_slot(frame: *CallFrame) u8 {
    const result = frame.*.ip[0];
    frame.*.ip += 1;
    return result;
}

inline fn next_ip(frame: *CallFrame) void {
    frame.*.ip += 1;
}

pub fn resetStack() void {
    vm.stackTop = @ptrCast(&vm.stack);
    vm.frameCount = 0;
    vm.openUpvalues = null;
}

pub inline fn peek(distance: i32) Value {
    return (vm.stackTop - @as(usize, @intCast(distance + 1)))[0];
}

pub fn call(closure: *ObjClosure, argCount: i32) bool {
    std.debug.print("DEBUG: Entering call() with argCount = {}\n", .{argCount});
    if (argCount != closure.*.function.*.arity) {
        runtimeError("Expected {d} arguments but got {d}.", .{ closure.*.function.*.arity, argCount });
        return false;
    }
    if (vm.frameCount == @as(i32, 64)) {
        runtimeError("Stack overflow.", .{});
        return false;
    }
    std.debug.print("DEBUG: About to get frame, frameCount before = {}\n", .{vm.frameCount});
    const frame: *CallFrame = &vm.frames[@intCast(next_frame_count())];
    std.debug.print("DEBUG: Got frame, frameCount after = {}\n", .{vm.frameCount});

    std.debug.print("DEBUG: Validating closure data...\n", .{});
    std.debug.print("DEBUG: closure ptr = {*}\n", .{closure});
    std.debug.print("DEBUG: closure.function ptr = {*}\n", .{closure.*.function});
    std.debug.print("DEBUG: closure.function.chunk.code ptr = {*}\n", .{closure.*.function.*.chunk.code});

    frame.*.closure = closure;
    std.debug.print("DEBUG: Set closure\n", .{});
    frame.*.ip = closure.*.function.*.chunk.code.?;
    std.debug.print("DEBUG: Set IP\n", .{});

    // The slots pointer should point to the first argument, which is 'self' for methods
    frame.*.slots = @ptrFromInt(@intFromPtr(vm.stackTop) - @sizeOf(Value) * @as(usize, @intCast(argCount + 1)));
    std.debug.print("DEBUG: Set slots to {*}\n", .{frame.*.slots});

    return true;
}

pub fn callValue(callee: Value, argCount: i32) bool {
    if (callee.type == .VAL_OBJ) {
        switch (callee.as.obj.?.type) {
            .OBJ_BOUND_METHOD => {
                const bound: *ObjBoundMethod = @as(*ObjBoundMethod, @ptrCast(@alignCast(callee.as.obj)));
                // Replace the receiver with the bound instance
                (vm.stackTop - @as(usize, @intCast(argCount + 1)))[0] = bound.*.receiver;
                return call(bound.*.method, argCount);
            },
            .OBJ_CLASS => {
                const klass: *ObjClass = @as(*ObjClass, @ptrCast(@alignCast(callee.as.obj)));
                (vm.stackTop - @as(usize, @intCast(argCount + 1)))[0] = Value.init_obj(@ptrCast(@alignCast(Instance.newInstance(klass))));
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
                const result: Value = native(argCount, vm.stackTop - @as(usize, @intCast(argCount)));
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
    const receiver: Value = peek(argCount);

    if (!isObjType(receiver, .OBJ_INSTANCE)) {
        runtimeError("Only instances have methods.", .{});
        return false;
    }

    const instance: *ObjInstance = @as(*ObjInstance, @ptrCast(@alignCast(receiver.as.obj)));

    var value: Value = undefined;
    if (tableGet(&instance.*.fields, name, &value)) {
        (vm.stackTop - @as(usize, @intCast(argCount + 1)))[0] = value;
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

fn getConstant(frame: *CallFrame, index: u8) ?Value {
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

// now work on this
pub fn run() InterpretResult {
    print("Hello\n", .{});
    return .INTERPRET_OK;
}
