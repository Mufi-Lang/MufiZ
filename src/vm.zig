/// MufiZ Virtual Machine Module
/// This module implements the bytecode interpreter for the MufiZ language.
/// It executes compiled bytecode using a stack-based virtual machine architecture.
/// Features include:
/// - Stack-based execution model
/// - Garbage collection with generational GC
/// - Native function integration
/// - REPL mode with echo control
/// - Complex number support
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
const String = @import("objects/string.zig").String;
const conv = @import("conv.zig");
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
const utils = @import("stdlib/utils.zig");
const table_h = @import("table.zig");
const tableGet = table_h.tableGet;
const tableSet = table_h.tableSet;
const tableSetProtected = table_h.tableSetProtected;
const tableDelete = table_h.tableDelete;
const Table = table_h.Table;
const initTable = table_h.initTable;
const freeTable = table_h.freeTable;
const value_h = @import("value.zig");
const printValue = value_h.printValue;
const valuesEqual = value_h.valuesEqual;
const Value = value_h.Value;
const Complex = value_h.Complex;

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
    frames: []CallFrame,
    frameCapacity: i32 = 64,
    frameCount: i32 = 0,
    currentFrame: ?*CallFrame = null,
    chunk: ?*Chunk = null,
    ip: [*]u8,
    stack: [16384]Value,
    stackTop: usize = 0,
    globals: Table,
    globalConstants: Table,
    publicGlobals: Table,
    
    // Slot-based globals (Phase 1 Optimization)
    globalValues: []Value,
    globalNames: Table, // Mapping from name string to index (Value.num_int)
    globalCount: u32 = 0,

    strings: Table,
    initString: ?*ObjString = null,
    openUpvalues: ?*ObjUpvalue = null,
    bytesAllocated: u128 = 0,
    nextGC: u128 = 1024 * 1024,
    objects: ?*Obj = null,
    grayCount: i32 = 0,
    grayCapacity: i32 = 0,
    grayStack: ?[*][*]Obj = null,
    source_code: []const u8 = "",
    source_file: []const u8 = "script",
};

pub fn initVM() void {
    // Clear the entire VM structure to avoid undefined behavior
    @memset(@as([*]u8, @ptrCast(&vm))[0..@sizeOf(VM)], 0);

    // Initialize dynamic frame stack
    const allocator = mem_utils.getAllocator();
    vm.frames = allocator.alloc(CallFrame, 64) catch {
        @panic("Failed to allocate initial frame stack");
    };
    vm.frameCapacity = 64;

    resetStack();
    vm.objects = null;
    vm.bytesAllocated = 0;
    vm.nextGC = 1024 * 1024;

    vm.grayCount = 0;
    vm.grayCapacity = 0;
    vm.grayStack = null;

    initTable(&vm.globals);
    initTable(&vm.globalConstants);
    initTable(&vm.publicGlobals);
    initTable(&vm.globalNames);
    initTable(&vm.strings);

    // Allocate global value slots
    vm.globalValues = allocator.alloc(Value, 1024) catch @panic("Failed to allocate global slots");
    @memset(vm.globalValues, Value.init_nil());
    vm.globalCount = 0;

    vm.initString = copyString(@ptrCast("init"), 4);
    if (vm.initString == null) {
        @panic("Failed to create initString during VM initialization");
    }

    // Define SIMD-optimized native functions
    defineSIMDNatives();
}

pub const InterpretResult = enum(u8) {
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

/// Create a snapshot of currently defined global variable names
pub fn snapshotGlobals(allocator: std.mem.Allocator) !std.StringHashMap(void) {
    var snapshot = std.StringHashMap(void).init(allocator);
    if (vm.globals.entries) |entries| {
        var i: usize = 0;
        while (i < vm.globals.capacity) : (i += 1) {
            if (entries[i].key) |key| {
                if (!entries[i].deleted) {
                    const name = key.chars[0..key.length];
                    try snapshot.put(name, {});
                }
            }
        }
    }
    return snapshot;
}

/// Get all globals defined since the given snapshot
pub fn getGlobalsSince(allocator: std.mem.Allocator, snapshot: std.StringHashMap(void)) !std.StringHashMap(Value) {
    var new_globals = std.StringHashMap(Value).init(allocator);
    if (vm.globals.entries) |entries| {
        var i: usize = 0;
        while (i < vm.globals.capacity) : (i += 1) {
            if (entries[i].key) |key| {
                if (!entries[i].deleted) {
                    const name = key.chars[0..key.length];
                    if (!snapshot.contains(name)) {
                        try new_globals.put(name, entries[i].value);
                    }
                }
            }
        }
    }
    return new_globals;
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

pub fn runtimeErrorEnhanced(var_name: []const u8, line: u32, source: []const u8, file: []const u8) void {
    const base_allocator = mem_utils.getAllocator();

    // Use arena allocator for all error-related allocations
    var arena = std.heap.ArenaAllocator.init(base_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Collect available global variables
    var available_vars: std.ArrayList([]const u8) = .{};
    defer available_vars.deinit(allocator);

    if (vm.globals.entries) |entries| {
        var idx: usize = 0;
        while (idx < vm.globals.capacity) : (idx += 1) {
            if (entries[idx].key) |key| {
                const name = key.chars[0..key.length];
                available_vars.append(allocator, name) catch {};
            }
        }
    }

    // Create enhanced error
    const error_info = errors.EnhancedTemplates.undefinedVariable(
        var_name,
        line,
        1,
        @intCast(var_name.len),
        available_vars.items,
        source,
        file,
        allocator,
    ) catch {
        // Fallback to simple error
        std.debug.print("Undefined variable '{s}'.\n[line {d}] in script\n", .{ var_name, line });
        return;
    };
    // No need to call deinit - arena will free everything

    var printer = errors.EnhancedErrorPrinter.init(allocator);
    printer.printError(error_info);

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
    const nativeValue = Value{
        .type = .VAL_OBJ,
        .as = .{ .obj = @ptrCast(@alignCast(native)) },
    };
    push(nativeValue);
    
    // Store in hash table for OP_GET_GLOBAL
    _ = tableSetProtected(&vm.globals, @ptrCast(@alignCast(vm.stack[0].as.obj)), vm.stack[1], true);
    
    // ALSO store in globalValues array for OP_GET_GLOBAL_SLOT
    const slot = getGlobalSlot(nameString);
    vm.globalValues[slot] = nativeValue;
    
    _ = pop();
    _ = pop();
}

pub fn freeVM() void {
    freeTable(&vm.globals);
    freeTable(&vm.globalConstants);
    freeTable(&vm.publicGlobals);
    freeTable(&vm.globalNames);
    freeTable(&vm.strings);
    vm.initString = null;
    freeObjects();
    const allocator = mem_utils.getAllocator();
    allocator.free(vm.frames);
    allocator.free(vm.globalValues);
}

/// Get a pointer to the VM for external modules
pub fn getVM() *VM {
    return &vm;
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

pub fn setSourceFile(file_path: []const u8) void {
    vm.source_file = file_path;
}

pub fn interpret(source: [*]const u8) InterpretResult {
    // Store source code for error reporting
    var i: usize = 0;
    while (source[i] != 0) : (i += 1) {}
    vm.source_code = source[0..i];

    const function: ?*ObjFunction = compiler_h.compile(source, vm.source_file);
    if (function == null) {
        return .INTERPRET_COMPILE_ERROR;
    }

    // Only echo source in non-REPL mode when explicitly enabled
    if (echo_enabled and !repl_mode) {
        if (debug_opts.trace_exec) {
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

fn growFrameStack() bool {
    const newCapacity = vm.frameCapacity * 2;
    if (newCapacity > 1024) { // Reasonable upper limit
        return false;
    }

    const allocator = mem_utils.getAllocator();
    const newFrames = allocator.realloc(vm.frames, @intCast(newCapacity)) catch {
        return false;
    };

    vm.frames = newFrames;
    vm.frameCapacity = newCapacity;

    // Update current frame pointer if it exists
    if (vm.frameCount > 0) {
        vm.currentFrame = &vm.frames[@intCast(vm.frameCount - 1)];
    }

    return true;
}

pub fn call(closure: *ObjClosure, argCount: i32) bool {
    if (argCount != closure.*.function.*.arity) {
        runtimeError("Expected {d} arguments but got {d}.", .{ closure.*.function.*.arity, argCount });
        return false;
    }
    if (vm.frameCount >= vm.frameCapacity) {
        if (!growFrameStack()) {
            runtimeError("Stack overflow.", .{});
            return false;
        }
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

                // Safety check for stack underflow
                const popCount = @as(usize, @intCast(argCount + 1));
                if (vm.stackTop < popCount) {
                    runtimeError("Stack underflow in native function call. StackTop: {d}, PopCount: {d}", .{ vm.stackTop, popCount });
                    return false;
                }

                vm.stackTop -= popCount;
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

    // Handle module method invocation: module.func(args)
    if (isObjType(receiver, .OBJ_MODULE)) {
        const module = @as(*object_h.ObjModule, @ptrCast(@alignCast(receiver.as.obj)));
        const member_name = name.chars[0..@intCast(name.length)];

        if (module.getMember(member_name)) |member_value| {
            // Replace the module on the stack with the callable value
            vm.stack[vm.stackTop - @as(usize, @intCast(argCount + 1))] = member_value;
            return callValue(member_value, argCount);
        }

        runtimeError("Module '{s}' has no member '{s}'.", .{ module.name.chars[0..@intCast(module.name.length)], member_name });
        return false;
    }

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
    _ = args;
    if (argCount != 2) {
        runtimeError("simd_memcpy() takes exactly 2 arguments.", .{});
        return Value.init_nil();
    }

    // NOTE: Stub implementation - always returns true
    // Full implementation requires:
    // 1. Validating both arguments are appropriate types (arrays/vectors)
    // 2. Checking length compatibility
    // 3. Performing SIMD-accelerated memory copy
    // 4. Handling alignment and edge cases
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

    if (ObjString.findSIMD(haystack, needle)) |pos| {
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

    return Value.init_bool(ObjString.equalsSIMD(s1, s2));
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

    const result = ObjString.compareSIMD(s1, s2);
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

// Phase 2 Optimization: Small constant opcodes (67-82)
// These opcodes load constants 0-15 without needing an operand byte
// Saves 1 byte per constant load (from 2 bytes to 1 byte)

fn makeOpConstant(comptime n: u8) OpHandler {
    return struct {
        fn handler() InterpretResult {
            const frame = vm.currentFrame.?;
            const constant = getConstant(frame, n) orelse {
                runtimeError("Invalid constant index.", .{});
                return .INTERPRET_RUNTIME_ERROR;
            };
            push(constant);
            return .INTERPRET_OK;
        }
    }.handler;
}

fn makeOpGetLocal(comptime n: u8) OpHandler {
    return struct {
        fn handler() InterpretResult {
            const frame = vm.currentFrame.?;
            push(frame.slots[n]);
            return .INTERPRET_OK;
        }
    }.handler;
}

fn makeOpSetLocal(comptime n: u8) OpHandler {
    return struct {
        fn handler() InterpretResult {
            const frame = vm.currentFrame.?;
            frame.slots[n] = peek(0);
            return .INTERPRET_OK;
        }
    }.handler;
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
        // Get current source and file info
        const instruction: usize = @intFromPtr(frame.ip) - @intFromPtr(frame.closure.function.chunk.code) - 1;
        const line = frame.closure.function.chunk.lines.?[instruction];
        const var_name = name.chars[0..name.length];

        // Use enhanced error reporting with stored source
        runtimeErrorEnhanced(var_name, @intCast(line), vm.source_code, vm.source_file);
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
    const value = peek(0);
    _ = tableSet(&vm.globals, name, value);
    
    // Sync to slot
    const slot = getGlobalSlot(name);
    vm.globalValues[slot] = value;

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
    const value = peek(0);
    _ = tableSet(&vm.globals, name, value);
    _ = tableSet(&vm.globalConstants, name, Value.init_bool(true));
    
    // Sync to slot
    const slot = getGlobalSlot(name);
    vm.globalValues[slot] = value;

    _ = pop();
    return .INTERPRET_OK;
}

fn opDefinePublicGlobal() InterpretResult {
    const frame = vm.currentFrame.?;
    const constant_index = frame.ip[0];
    frame.ip += 1;
    const constant = getConstant(frame, constant_index) orelse {
        runtimeError("Invalid constant index.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    };
    const name = constant.as_string();
    const value = peek(0);
    _ = tableSet(&vm.globals, name, value);
    _ = tableSet(&vm.publicGlobals, name, Value.init_bool(true));
    
    // Sync to slot
    const slot = getGlobalSlot(name);
    vm.globalValues[slot] = value;

    _ = pop();
    return .INTERPRET_OK;
}

fn opDefinePublicConstGlobal() InterpretResult {
    const frame = vm.currentFrame.?;
    const constant_index = frame.ip[0];
    frame.ip += 1;
    const constant = getConstant(frame, constant_index) orelse {
        runtimeError("Invalid constant index.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    };
    const name = constant.as_string();
    const value = peek(0);
    _ = tableSet(&vm.globals, name, value);
    _ = tableSet(&vm.globalConstants, name, Value.init_bool(true));
    _ = tableSet(&vm.publicGlobals, name, Value.init_bool(true));
    
    // Sync to slot
    const slot = getGlobalSlot(name);
    vm.globalValues[slot] = value;

    _ = pop();
    return .INTERPRET_OK;
}

/// Check if a global variable is marked as public
pub fn isPublicGlobal(name: *ObjString) bool {
    var value: Value = undefined;
    return tableGet(&vm.publicGlobals, name, &value);
}

/// Get or allocate a slot for a global variable by name
pub fn getGlobalSlot(name: *ObjString) u8 {
    var slot_val: Value = undefined;
    if (tableGet(&vm.globalNames, name, &slot_val)) {
        return @intCast(slot_val.as.num_int);
    }

    const slot = @as(u8, @intCast(vm.globalCount));
    vm.globalCount += 1;
    _ = tableSet(&vm.globalNames, name, Value.init_int(@intCast(slot)));
    return slot;
}

/// Reset global slot mappings
pub fn resetGlobals() void {
    freeTable(&vm.globalNames);
    initTable(&vm.globalNames);
    vm.globalCount = 0;
    @memset(vm.globalValues, Value.init_nil());
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

    // Check if this is a constant (read-only) variable
    var unused_value: Value = undefined;
    if (tableGet(&vm.globalConstants, name, &unused_value)) {
        runtimeError("Cannot assign to constant variable '{s}'.", .{name.chars});
        return .INTERPRET_RUNTIME_ERROR;
    }

    const value = peek(0);
    if (tableSet(&vm.globals, name, value)) {
        _ = tableDelete(&vm.globals, name);
        runtimeError("Undefined variable '{s}'.", .{name.chars});
        return .INTERPRET_RUNTIME_ERROR;
    }

    // Sync to slot
    const slot = getGlobalSlot(name);
    vm.globalValues[slot] = value;

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

fn opGetModuleMember() InterpretResult {
    const frame = vm.currentFrame.?;
    const name_constant = frame.ip[0];
    frame.ip += 1;

    // Validate constant index
    if (name_constant >= frame.closure.function.chunk.constants.count) {
        runtimeError("Invalid constant index for member name", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }

    const name_value = frame.closure.function.chunk.constants.values[@intCast(name_constant)];

    // Validate that the value is an object string
    if (name_value.type != .VAL_OBJ or !isObjType(name_value, .OBJ_STRING)) {
        runtimeError("Member name must be a string", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }

    // Peek at the module on the stack
    const module_value = peek(0);
    if (!isObjType(module_value, .OBJ_MODULE)) {
        runtimeError("Can only access members of modules", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }

    const module = @as(*object_h.ObjModule, @ptrCast(@alignCast(module_value.as.obj)));
    const member_name_str = @as(*ObjString, @ptrCast(@alignCast(name_value.as.obj)));
    const member_name = member_name_str.chars[0..@intCast(member_name_str.length)];

    // Look up the member in the module
    if (module.getMember(member_name)) |member_value| {
        _ = pop(); // Pop the module
        push(member_value); // Push the member value
        return .INTERPRET_OK;
    }

    runtimeError("Module '{s}' has no member '{s}'", .{ module.name.chars[0..@intCast(module.name.length)], member_name });
    return .INTERPRET_RUNTIME_ERROR;
}

fn opGetProperty() InterpretResult {
    const frame = vm.currentFrame.?;
    const offset = @intFromPtr(frame.ip) - @intFromPtr(frame.closure.function.chunk.code) - 1;
    const constant_index = frame.ip[0];
    frame.ip += 1;
    const constant = getConstant(frame, constant_index) orelse {
        runtimeError("Invalid constant index.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    };
    const name = constant.as_string();
    const receiver = peek(0);

    // Handle module member access
    if (isObjType(receiver, .OBJ_MODULE)) {
        const module = @as(*object_h.ObjModule, @ptrCast(@alignCast(receiver.as.obj)));
        const member_name = name.chars[0..@intCast(name.length)];

        // Look up the member in the module
        if (module.getMember(member_name)) |member_value| {
            _ = pop(); // Pop the module
            push(member_value); // Push the member value
            return .INTERPRET_OK;
        }

        runtimeError("Module '{s}' has no member '{s}'", .{ module.name.chars[0..@intCast(module.name.length)], member_name });
        return .INTERPRET_RUNTIME_ERROR;
    }

    if (isObjType(receiver, .OBJ_INSTANCE)) {
        const instance: *ObjInstance = @ptrCast(@alignCast(receiver.as.obj));
        
        // Phase 2: Inline Cache lookup
        const chunk = &frame.closure.function.chunk;
        if (chunk.inline_caches) |caches| {
            if (caches.get(offset)) |cache_entry| {
                if (cache_entry.klass == @as(?*const anyopaque, @ptrCast(instance.klass))) {
                    // CACHE HIT: Fast table index access
                    const table = &instance.fields;
                    if (table.entries) |entries| {
                        if (cache_entry.offset < table.capacity) {
                            const entry = &entries[cache_entry.offset];
                            if (entry.key == name) {
                                _ = pop(); // Instance
                                push(entry.value);
                                return .INTERPRET_OK;
                            }
                        }
                    }
                }
            }
        }

        var value: Value = undefined;
        // Perform standard lookup
        if (table_h.tableGet(&instance.fields, name, &value)) {
            // Update Inline Cache on hit
            if (chunk.inline_caches == null) {
                const allocator = mem_utils.getAllocator();
                chunk.inline_caches = std.AutoHashMap(usize, chunk_h.InlineCache).init(allocator);
            }
            
            // Find the index in the table entries for caching
            if (instance.fields.entries) |entries| {
                var idx: usize = 0;
                while (idx < instance.fields.capacity) : (idx += 1) {
                    if (entries[idx].key == name) {
                        chunk.inline_caches.?.put(offset, .{
                            .klass = @as(?*const anyopaque, @ptrCast(instance.klass)),
                            .offset = idx,
                        }) catch {};
                        break;
                    }
                }
            }

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

const ArithmeticOp = enum { Add, Sub, Mul, Div };

fn performAddString(a: Value, b: Value) !Value {
    const a_str_ptr = stringify(a);
    if (a_str_ptr == null) return error.TypeMismatch;
    push(Value.init_obj(@ptrCast(a_str_ptr.?)));

    const b_str_ptr = stringify(b);
    if (b_str_ptr == null) {
        _ = pop();
        return error.TypeMismatch;
    }
    push(Value.init_obj(@ptrCast(b_str_ptr.?)));

    const b_str = peek(0).as_string();
    const a_str = peek(1).as_string();

    const length = a_str.length + b_str.length;
    const allocator = mem_utils.getAllocator();
    const chars_slice = mem_utils.alloc(allocator, u8, length + 1) catch {
        _ = pop();
        _ = pop();
        return error.OutOfMemory;
    };
    const chars_ptr: [*]u8 = chars_slice.ptr;
    @memcpy(chars_ptr[0..a_str.length], a_str.chars[0..a_str.length]);
    @memcpy(chars_ptr[a_str.length..length], b_str.chars[0..b_str.length]);
    chars_ptr[length] = 0;

    const result = String.takeWithAllocator(chars_slice, length, allocator);
    _ = pop();
    _ = pop();
    return Value.init_obj(@ptrCast(result));
}

fn performArithmetic(comptime op: ArithmeticOp, a: Value, b: Value) !Value {
    if (a.is_complex() or b.is_complex()) {
        const ca = if (a.is_complex()) a.as_complex() else Complex{ .r = if (a.is_int()) @floatFromInt(a.as_int()) else a.as_num_double(), .i = 0 };
        const cb = if (b.is_complex()) b.as_complex() else Complex{ .r = if (b.is_int()) @floatFromInt(b.as_int()) else b.as_num_double(), .i = 0 };

        const res = switch (op) {
            .Add => Complex{ .r = ca.r + cb.r, .i = ca.i + cb.i },
            .Sub => Complex{ .r = ca.r - cb.r, .i = ca.i - cb.i },
            .Mul => Complex{ .r = ca.r * cb.r - ca.i * cb.i, .i = ca.r * cb.i + ca.i * cb.r },
            .Div => blk: {
                const denom = cb.r * cb.r + cb.i * cb.i;
                if (denom == 0) return error.DivisionByZero;
                break :blk Complex{
                    .r = (ca.r * cb.r + ca.i * cb.i) / denom,
                    .i = (ca.i * cb.r - ca.r * cb.i) / denom,
                };
            },
        };
        return Value.init_complex(res);
    }

    if (op != .Div and (a.is_matrix() or b.is_matrix())) {
        if (a.is_matrix() and b.is_matrix()) {
            const mat_a: *Matrix = @ptrCast(@alignCast(a.as.obj));
            const mat_b: *Matrix = @ptrCast(@alignCast(b.as.obj));
            const res = switch (op) {
                .Add => mat_a.add(mat_b),
                .Sub => mat_a.sub(mat_b),
                .Mul => mat_a.mul(mat_b),
                else => unreachable,
            };
            if (res == null) return error.DimensionMismatch;
            return Value.init_obj(@ptrCast(res.?));
        } else if (a.is_matrix() and b.is_prim_num()) {
            const mat_a: *Matrix = @ptrCast(@alignCast(a.as.obj));
            const val_b = if (b.is_int()) @as(f64, @floatFromInt(b.as_int())) else b.as_num_double();
            const res = mat_a.scalarMul(1.0); // Clone
            const size = mat_a.rows * mat_a.cols;
            for (0..size) |i| {
                res.data[i] = switch (op) {
                    .Add => mat_a.data[i] + val_b,
                    .Sub => mat_a.data[i] - val_b,
                    .Mul => mat_a.data[i] * val_b,
                    else => unreachable,
                };
            }
            return Value.init_obj(@ptrCast(res));
        } else if (a.is_prim_num() and b.is_matrix()) {
            const val_a = if (a.is_int()) @as(f64, @floatFromInt(a.as_int())) else a.as_num_double();
            const mat_b: *Matrix = @ptrCast(@alignCast(b.as.obj));
            const res = mat_b.scalarMul(1.0); // Clone
            const size = mat_b.rows * mat_b.cols;
            for (0..size) |i| {
                res.data[i] = switch (op) {
                    .Add => mat_b.data[i] + val_a,
                    .Sub => val_a - mat_b.data[i],
                    .Mul => mat_b.data[i] * val_a, // Commutative
                    else => unreachable,
                };
            }
            return Value.init_obj(@ptrCast(res));
        }
        return error.TypeMismatch;
    }

    if (a.is_fvec() or b.is_fvec()) {
        if (a.is_fvec() and b.is_fvec()) {
            const vec_a: *FloatVector = @ptrCast(@alignCast(a.as.obj));
            const vec_b: *FloatVector = @ptrCast(@alignCast(b.as.obj));
            const res = switch (op) {
                .Add => vec_a.add(vec_b),
                .Sub => vec_a.sub(vec_b),
                .Mul => vec_a.mul(vec_b),
                .Div => vec_a.div(vec_b),
            };
            return Value.init_obj(@ptrCast(res));
        } else if (a.is_fvec() and b.is_prim_num()) {
            const vec_a: *FloatVector = @ptrCast(@alignCast(a.as.obj));
            const val_b = if (b.is_int()) @as(f64, @floatFromInt(b.as_int())) else b.as_num_double();
            const res = switch (op) {
                .Add => vec_a.single_add(val_b),
                .Sub => vec_a.single_sub(val_b),
                .Mul => vec_a.scale(val_b),
                .Div => vec_a.single_div(val_b),
            };
            return Value.init_obj(@ptrCast(res));
        } else if (a.is_prim_num() and b.is_fvec()) {
            const val_a = if (a.is_int()) @as(f64, @floatFromInt(a.as_int())) else a.as_num_double();
            const vec_b: *FloatVector = @ptrCast(@alignCast(b.as.obj));
            const res = switch (op) {
                .Add => vec_b.single_add(val_a),
                .Sub => blk: {
                    const neg_b = vec_b.scale(-1.0);
                    break :blk neg_b.single_add(val_a);
                },
                .Mul => vec_b.scale(val_a),
                .Div => blk: {
                    const res = FloatVector.init(vec_b.count);
                    res.count = vec_b.count;
                    var i: usize = 0;
                    while (i < vec_b.count) : (i += 1) {
                        res.data[i] = val_a / vec_b.data[i];
                    }
                    break :blk res;
                },
            };
            return Value.init_obj(@ptrCast(res));
        }
        return error.TypeMismatch;
    }

    if (a.is_prim_num() and b.is_prim_num()) {
        if (op == .Div or a.is_double() or b.is_double()) {
            const va = a.as_num_double();
            const vb = b.as_num_double();
            return Value.init_double(switch (op) {
                .Add => va + vb,
                .Sub => va - vb,
                .Mul => va * vb,
                .Div => va / vb,
            });
        } else {
            const ia = a.as_int();
            const ib = b.as_int();
            return Value.init_int(switch (op) {
                .Add => ia + ib,
                .Sub => ia - ib,
                .Mul => ia * ib,
                else => unreachable,
            });
        }
    }

    return error.TypeMismatch;
}

fn opAdd() InterpretResult {
    const b = pop();
    const a = pop();

    if (a.is_string() or b.is_string()) {
        const res = performAddString(a, b) catch |err| {
            switch (err) {
                error.OutOfMemory => runtimeError("Out of memory.", .{}),
                error.TypeMismatch => runtimeError("Operands must be two numbers or two strings.", .{}),
            }
            return .INTERPRET_RUNTIME_ERROR;
        };
        push(res);
        return .INTERPRET_OK;
    }

    const res = performArithmetic(.Add, a, b) catch |err| {
        switch (err) {
            error.DimensionMismatch => runtimeError("Matrix dimension mismatch for addition.", .{}),
            error.TypeMismatch => runtimeError("Operands must be two numbers, two strings, or involve a vector/matrix.", .{}),
        }
        return .INTERPRET_RUNTIME_ERROR;
    };
    push(res);
    return .INTERPRET_OK;
}

fn opSubtract() InterpretResult {
    const b = pop();
    const a = pop();

    const res = performArithmetic(.Sub, a, b) catch |err| {
        switch (err) {
            error.DimensionMismatch => runtimeError("Matrix dimension mismatch for subtraction.", .{}),
            error.TypeMismatch => runtimeError("Operands must be numbers or vectors/matrices.", .{}),
        }
        return .INTERPRET_RUNTIME_ERROR;
    };
    push(res);
    return .INTERPRET_OK;
}

fn opMultiply() InterpretResult {
    const b = pop();
    const a = pop();

    const res = performArithmetic(.Mul, a, b) catch |err| {
        switch (err) {
            error.DimensionMismatch => runtimeError("Matrix dimension mismatch for multiplication.", .{}),
            error.TypeMismatch => runtimeError("Operands must be numbers or vectors/matrices.", .{}),
        }
        return .INTERPRET_RUNTIME_ERROR;
    };
    push(res);
    return .INTERPRET_OK;
}

fn opDivide() InterpretResult {
    const b = pop();
    const a = pop();

    const res = performArithmetic(.Div, a, b) catch |err| {
        switch (err) {
            error.DivisionByZero => runtimeError("Division by zero.", .{}),
            error.TypeMismatch => runtimeError("Operands must be numbers or vectors.", .{}),
        }
        return .INTERPRET_RUNTIME_ERROR;
    };
    push(res);
    return .INTERPRET_OK;
}

fn opModulo() InterpretResult {
    if (!peek(0).is_prim_num() or !peek(1).is_prim_num()) {
        runtimeError("Operands must be numbers.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }

    // Preserve integer type when both operands are integers
    if (peek(0).is_int() and peek(1).is_int()) {
        const b = pop().as_int();
        const a = pop().as_int();
        push(Value.init_int(@mod(a, b)));
    } else {
        const b = pop().as_num_double();
        const a = pop().as_num_double();
        push(Value.init_double(@mod(a, b)));
    }
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

fn opBand() InterpretResult {
    if (!peek(0).is_int() or !peek(1).is_int()) {
        runtimeError("Bitwise AND requires integer operands.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }
    const b = pop().as.num_int;
    const a = pop().as.num_int;
    push(Value.init_int(a & b));
    return .INTERPRET_OK;
}

fn opBor() InterpretResult {
    if (!peek(0).is_int() or !peek(1).is_int()) {
        runtimeError("Bitwise OR requires integer operands.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }
    const b = pop().as.num_int;
    const a = pop().as.num_int;
    push(Value.init_int(a | b));
    return .INTERPRET_OK;
}

fn opBxor() InterpretResult {
    if (!peek(0).is_int() or !peek(1).is_int()) {
        runtimeError("Bitwise XOR requires integer operands.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }
    const b = pop().as.num_int;
    const a = pop().as.num_int;
    push(Value.init_int(a ^ b));
    return .INTERPRET_OK;
}

fn opBnot() InterpretResult {
    if (!peek(0).is_int()) {
        runtimeError("Bitwise NOT requires an integer operand.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }
    const a = pop().as.num_int;
    push(Value.init_int(~a));
    return .INTERPRET_OK;
}

fn opShl() InterpretResult {
    if (!peek(0).is_int() or !peek(1).is_int()) {
        runtimeError("Bit shift requires integer operands.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }
    const b = pop().as.num_int;
    const a = pop().as.num_int;
    if (b < 0 or b >= 32) {
        runtimeError("Shift amount must be between 0 and 31.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }
    push(Value.init_int(a << @intCast(b)));
    return .INTERPRET_OK;
}

fn opShr() InterpretResult {
    if (!peek(0).is_int() or !peek(1).is_int()) {
        runtimeError("Bit shift requires integer operands.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }
    const b = pop().as.num_int;
    const a = pop().as.num_int;
    if (b < 0 or b >= 32) {
        runtimeError("Shift amount must be between 0 and 31.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }
    push(Value.init_int(a >> @intCast(b)));
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

// Phase 2.3 Optimization: Short jump opcodes (91-93)
// These opcodes use i8 offset instead of u16, saving 1 byte per jump
// Suitable for jumps within ±127 bytes

fn opJumpShort() InterpretResult {
    const frame = vm.currentFrame.?;
    const offset: i8 = @bitCast(frame.ip[0]);
    frame.ip += 1;
    if (offset >= 0) {
        frame.ip += @as(usize, @intCast(offset));
    } else {
        frame.ip -= @as(usize, @intCast(-offset));
    }
    return .INTERPRET_OK;
}

fn opJumpIfFalseShort() InterpretResult {
    const frame = vm.currentFrame.?;
    const offset: i8 = @bitCast(frame.ip[0]);
    frame.ip += 1;
    if (isFalsey(peek(0))) {
        if (offset >= 0) {
            frame.ip += @as(usize, @intCast(offset));
        } else {
            frame.ip -= @as(usize, @intCast(-offset));
        }
    }
    return .INTERPRET_OK;
}

fn opLoopShort() InterpretResult {
    const frame = vm.currentFrame.?;
    const offset: i8 = @bitCast(frame.ip[0]);
    frame.ip += 1;
    // Loop offsets are always positive (backward jump)
    frame.ip -= @as(usize, @intCast(offset));
    return .INTERPRET_OK;
}

// ============================================================
// PHASE 3 HANDLERS: Superinstructions (100-191)
// ============================================================

/// OP_DEFINE_GLOBAL_CONST handler
/// Fuses: OP_CONSTANT + OP_DEFINE_GLOBAL
/// Format: [opcode] [global_name_idx:u8] [value_const_idx:u8]
fn opDefineGlobalConst() InterpretResult {
    const frame = vm.currentFrame.?;
    const global_name_idx = frame.ip[0];
    const value_const_idx = frame.ip[1];
    frame.ip += 2;

    const name_constant = getConstant(frame, global_name_idx) orelse {
        runtimeError("Invalid constant index for global name.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    };
    const value_constant = getConstant(frame, value_const_idx) orelse {
        runtimeError("Invalid constant index for value.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    };

    const name = name_constant.as_string();
    _ = tableSet(&vm.globals, name, value_constant);
    return .INTERPRET_OK;
}

/// OP_SET_GLOBAL_CONST handler
/// Fuses: OP_CONSTANT + OP_SET_GLOBAL
fn opSetGlobalConst() InterpretResult {
    const frame = vm.currentFrame.?;
    const global_name_idx = frame.ip[0];
    const value_const_idx = frame.ip[1];
    frame.ip += 2;

    const name_constant = getConstant(frame, global_name_idx) orelse {
        runtimeError("Invalid constant index for global name.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    };
    const value_constant = getConstant(frame, value_const_idx) orelse {
        runtimeError("Invalid constant index for value.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    };

    const name = name_constant.as_string();
    if (!tableSet(&vm.globals, name, value_constant)) {
        runtimeError("Undefined variable '{s}'.", .{name.chars[0..@intCast(name.length)]});
        return .INTERPRET_RUNTIME_ERROR;
    }
    return .INTERPRET_OK;
}

/// OP_GET_GLOBAL_ADD handler
/// Fuses: OP_GET_GLOBAL + OP_ADD
/// Assumes second operand is already on stack
fn opGetGlobalAdd() InterpretResult {
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
        runtimeError("Undefined variable '{s}'.", .{name.chars[0..@intCast(name.length)]});
        return .INTERPRET_RUNTIME_ERROR;
    }

    // Now perform ADD with value and top of stack
    const b = pop();
    const a = value;

    if (a.is_string() or b.is_string()) {
        const res = performAddString(a, b) catch |err| {
            switch (err) {
                error.OutOfMemory => runtimeError("Out of memory.", .{}),
                error.TypeMismatch => runtimeError("Operands must be two numbers or two strings.", .{}),
            }
            return .INTERPRET_RUNTIME_ERROR;
        };
        push(res);
        return .INTERPRET_OK;
    }

    const res = performArithmetic(.Add, a, b) catch |err| {
        switch (err) {
            error.DimensionMismatch => runtimeError("Matrix dimension mismatch for addition.", .{}),
            error.TypeMismatch => runtimeError("Operands must be two numbers, two strings, or involve a vector/matrix.", .{}),
        }
        return .INTERPRET_RUNTIME_ERROR;
    };
    push(res);
    return .INTERPRET_OK;
}

/// OP_GET_GLOBAL_SUBTRACT handler
fn opGetGlobalSubtract() InterpretResult {
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
        runtimeError("Undefined variable '{s}'.", .{name.chars[0..@intCast(name.length)]});
        return .INTERPRET_RUNTIME_ERROR;
    }

    const b = pop();
    const a = value;

    const res = performArithmetic(.Sub, a, b) catch |err| {
        switch (err) {
            error.DimensionMismatch => runtimeError("Matrix dimension mismatch for subtraction.", .{}),
            error.TypeMismatch => runtimeError("Operands must be numbers or vectors/matrices.", .{}),
        }
        return .INTERPRET_RUNTIME_ERROR;
    };
    push(res);
    return .INTERPRET_OK;
}

/// OP_GET_GLOBAL_MULTIPLY handler
fn opGetGlobalMultiply() InterpretResult {
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
        runtimeError("Undefined variable '{s}'.", .{name.chars[0..@intCast(name.length)]});
        return .INTERPRET_RUNTIME_ERROR;
    }

    const b = pop();
    const a = value;

    const res = performArithmetic(.Mul, a, b) catch |err| {
        switch (err) {
            error.DimensionMismatch => runtimeError("Matrix dimension mismatch for multiplication.", .{}),
            error.TypeMismatch => runtimeError("Operands must be numbers or vectors/matrices.", .{}),
        }
        return .INTERPRET_RUNTIME_ERROR;
    };
    push(res);
    return .INTERPRET_OK;
}

/// OP_GET_GLOBAL_DIVIDE handler
fn opGetGlobalDivide() InterpretResult {
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
        runtimeError("Undefined variable '{s}'.", .{name.chars[0..@intCast(name.length)]});
        return .INTERPRET_RUNTIME_ERROR;
    }

    const b = pop();
    const a = value;

    const res = performArithmetic(.Div, a, b) catch |err| {
        switch (err) {
            error.DivisionByZero => runtimeError("Division by zero.", .{}),
            error.TypeMismatch => runtimeError("Operands must be numbers or vectors.", .{}),
        }
        return .INTERPRET_RUNTIME_ERROR;
    };
    push(res);
    return .INTERPRET_OK;
}

/// OP_GET_LOCAL_ADD handler
fn opGetLocalAdd() InterpretResult {
    const frame = vm.currentFrame.?;
    const slot = frame.ip[0];
    frame.ip += 1;

    const value = frame.slots[slot];
    const b = pop();
    const a = value;

    if (a.is_string() or b.is_string()) {
        const res = performAddString(a, b) catch |err| {
            switch (err) {
                error.OutOfMemory => runtimeError("Out of memory.", .{}),
                error.TypeMismatch => runtimeError("Operands must be two numbers or two strings.", .{}),
            }
            return .INTERPRET_RUNTIME_ERROR;
        };
        push(res);
        return .INTERPRET_OK;
    }

    const res = performArithmetic(.Add, a, b) catch |err| {
        switch (err) {
            error.DimensionMismatch => runtimeError("Matrix dimension mismatch for addition.", .{}),
            error.TypeMismatch => runtimeError("Operands must be two numbers, two strings, or involve a vector/matrix.", .{}),
        }
        return .INTERPRET_RUNTIME_ERROR;
    };
    push(res);
    return .INTERPRET_OK;
}

/// OP_GET_GLOBAL_GLOBAL handler
/// Fuses: OP_GET_GLOBAL + OP_GET_GLOBAL
fn opGetGlobalGlobal() InterpretResult {
    const frame = vm.currentFrame.?;
    const constant_index1 = frame.ip[0];
    const constant_index2 = frame.ip[1];
    frame.ip += 2;

    // Get first global
    const constant1 = getConstant(frame, constant_index1) orelse {
        runtimeError("Invalid constant index.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    };
    const name1 = constant1.as_string();
    var value1: Value = undefined;
    if (!tableGet(&vm.globals, name1, &value1)) {
        runtimeError("Undefined variable '{s}'.", .{name1.chars[0..@intCast(name1.length)]});
        return .INTERPRET_RUNTIME_ERROR;
    }
    push(value1);

    // Get second global
    const constant2 = getConstant(frame, constant_index2) orelse {
        runtimeError("Invalid constant index.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    };
    const name2 = constant2.as_string();
    var value2: Value = undefined;
    if (!tableGet(&vm.globals, name2, &value2)) {
        runtimeError("Undefined variable '{s}'.", .{name2.chars[0..@intCast(name2.length)]});
        return .INTERPRET_RUNTIME_ERROR;
    }
    push(value2);

    return .INTERPRET_OK;
}

/// OP_GET_LOCAL_LOCAL handler
fn opGetLocalLocal() InterpretResult {
    const frame = vm.currentFrame.?;
    const slot1 = frame.ip[0];
    const slot2 = frame.ip[1];
    frame.ip += 2;

    push(frame.slots[slot1]);
    push(frame.slots[slot2]);
    return .INTERPRET_OK;
}

/// OP_GET_GLOBAL_LOCAL handler
fn opGetGlobalLocal() InterpretResult {
    const frame = vm.currentFrame.?;
    const global_idx = frame.ip[0];
    const local_idx = frame.ip[1];
    frame.ip += 2;

    // Get global
    const constant = getConstant(frame, global_idx) orelse {
        runtimeError("Invalid constant index.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    };
    const name = constant.as_string();
    var value: Value = undefined;
    if (!tableGet(&vm.globals, name, &value)) {
        runtimeError("Undefined variable '{s}'.", .{name.chars[0..@intCast(name.length)]});
        return .INTERPRET_RUNTIME_ERROR;
    }
    push(value);

    // Get local
    push(frame.slots[local_idx]);
    return .INTERPRET_OK;
}

/// OP_GET_LOCAL_GLOBAL handler
fn opGetLocalGlobal() InterpretResult {
    const frame = vm.currentFrame.?;
    const local_idx = frame.ip[0];
    const global_idx = frame.ip[1];
    frame.ip += 2;

    // Get local
    push(frame.slots[local_idx]);

    // Get global
    const constant = getConstant(frame, global_idx) orelse {
        runtimeError("Invalid constant index.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    };
    const name = constant.as_string();
    var value: Value = undefined;
    if (!tableGet(&vm.globals, name, &value)) {
        runtimeError("Undefined variable '{s}'.", .{name.chars[0..@intCast(name.length)]});
        return .INTERPRET_RUNTIME_ERROR;
    }
    push(value);

    return .INTERPRET_OK;
}

/// OP_CONSTANT_CONSTANT handler
fn opConstantConstant() InterpretResult {
    const frame = vm.currentFrame.?;
    const constant_index1 = frame.ip[0];
    const constant_index2 = frame.ip[1];
    frame.ip += 2;

    const constant1 = getConstant(frame, constant_index1) orelse {
        runtimeError("Invalid constant index.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    };
    push(constant1);

    const constant2 = getConstant(frame, constant_index2) orelse {
        runtimeError("Invalid constant index.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    };
    push(constant2);

    return .INTERPRET_OK;
}

/// OP_CONSTANT_ADD handler
fn opConstantAdd() InterpretResult {
    const frame = vm.currentFrame.?;
    const constant_index = frame.ip[0];
    frame.ip += 1;

    const constant = getConstant(frame, constant_index) orelse {
        runtimeError("Invalid constant index.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    };

    const b = pop();
    const a = constant;

    if (a.is_string() or b.is_string()) {
        const res = performAddString(a, b) catch |err| {
            switch (err) {
                error.OutOfMemory => runtimeError("Out of memory.", .{}),
                error.TypeMismatch => runtimeError("Operands must be two numbers or two strings.", .{}),
            }
            return .INTERPRET_RUNTIME_ERROR;
        };
        push(res);
        return .INTERPRET_OK;
    }

    const res = performArithmetic(.Add, a, b) catch |err| {
        switch (err) {
            error.DimensionMismatch => runtimeError("Matrix dimension mismatch for addition.", .{}),
            error.TypeMismatch => runtimeError("Operands must be two numbers, two strings, or involve a vector/matrix.", .{}),
        }
        return .INTERPRET_RUNTIME_ERROR;
    };
    push(res);
    return .INTERPRET_OK;
}

/// OP_CONSTANT_MULTIPLY handler
fn opConstantMultiply() InterpretResult {
    const frame = vm.currentFrame.?;
    const constant_index = frame.ip[0];
    frame.ip += 1;

    const constant = getConstant(frame, constant_index) orelse {
        runtimeError("Invalid constant index.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    };

    const b = pop();
    const a = constant;

    const res = performArithmetic(.Mul, a, b) catch |err| {
        switch (err) {
            error.DimensionMismatch => runtimeError("Matrix dimension mismatch for multiplication.", .{}),
            error.TypeMismatch => runtimeError("Operands must be numbers or vectors/matrices.", .{}),
        }
        return .INTERPRET_RUNTIME_ERROR;
    };
    push(res);
    return .INTERPRET_OK;
}

fn opLessJumpIfFalse() InterpretResult {
    const frame = vm.currentFrame.?;
    if (!peek(0).is_prim_num() or !peek(1).is_prim_num()) {
        runtimeError("Operands must be numbers.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }
    const b = pop().as_num_double();
    const a = pop().as_num_double();
    const result = a < b;
    
    const offset = readOffset(frame);
    if (!result) {
        frame.ip += offset;
    }
    return .INTERPRET_OK;
}

fn opGetLocalConstant() InterpretResult {
    const frame = vm.currentFrame.?;
    const slot = frame.ip[0];
    const constant_index = frame.ip[1];
    frame.ip += 2;

    push(frame.slots[slot]);
    
    const constant = getConstant(frame, constant_index) orelse {
        runtimeError("Invalid constant index.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    };
    push(constant);
    
    return .INTERPRET_OK;
}

fn opAddSetLocal() InterpretResult {
    const frame = vm.currentFrame.?;
    const slot = frame.ip[0];
    frame.ip += 1;

    const b = pop();
    const a = pop();

    const res = if (a.is_string() or b.is_string())
        performAddString(a, b) catch return .INTERPRET_RUNTIME_ERROR
    else
        performArithmetic(.Add, a, b) catch return .INTERPRET_RUNTIME_ERROR;

    frame.slots[slot] = res;
    push(res);
    return .INTERPRET_OK;
}

fn opSetLocalPop() InterpretResult {
    const frame = vm.currentFrame.?;
    const slot = frame.ip[0];
    frame.ip += 1;

    frame.slots[slot] = pop();
    return .INTERPRET_OK;
}

fn opAddReg() InterpretResult {
    const frame = vm.currentFrame.?;
    const dest = frame.ip[0];
    const src1 = frame.ip[1];
    const src2 = frame.ip[2];
    frame.ip += 3;

    const a = frame.slots[src1];
    const b = frame.slots[src2];

    const res = if (a.is_string() or b.is_string())
        performAddString(a, b) catch return .INTERPRET_RUNTIME_ERROR
    else
        performArithmetic(.Add, a, b) catch return .INTERPRET_RUNTIME_ERROR;

    frame.slots[dest] = res;
    return .INTERPRET_OK;
}

fn opSubReg() InterpretResult {
    const frame = vm.currentFrame.?;
    const dest = frame.ip[0];
    const src1 = frame.ip[1];
    const src2 = frame.ip[2];
    frame.ip += 3;

    const a = frame.slots[src1];
    const b = frame.slots[src2];

    const res = performArithmetic(.Sub, a, b) catch return .INTERPRET_RUNTIME_ERROR;
    frame.slots[dest] = res;
    return .INTERPRET_OK;
}

fn opMulReg() InterpretResult {
    const frame = vm.currentFrame.?;
    const dest = frame.ip[0];
    const src1 = frame.ip[1];
    const src2 = frame.ip[2];
    frame.ip += 3;

    const a = frame.slots[src1];
    const b = frame.slots[src2];

    const res = performArithmetic(.Mul, a, b) catch return .INTERPRET_RUNTIME_ERROR;
    frame.slots[dest] = res;
    return .INTERPRET_OK;
}

fn opDivReg() InterpretResult {
    const frame = vm.currentFrame.?;
    const dest = frame.ip[0];
    const src1 = frame.ip[1];
    const src2 = frame.ip[2];
    frame.ip += 3;

    const a = frame.slots[src1];
    const b = frame.slots[src2];

    const res = performArithmetic(.Div, a, b) catch return .INTERPRET_RUNTIME_ERROR;
    frame.slots[dest] = res;
    return .INTERPRET_OK;
}

fn opGetGlobalSlot() InterpretResult {
    const frame = vm.currentFrame.?;
    const slot = frame.ip[0];
    frame.ip += 1;
    push(vm.globalValues[slot]);
    return .INTERPRET_OK;
}

fn opSetGlobalSlot() InterpretResult {
    const frame = vm.currentFrame.?;
    const slot = frame.ip[0];
    frame.ip += 1;
    vm.globalValues[slot] = pop();
    return .INTERPRET_OK;
}

fn opSetGlobalSlotKeep() InterpretResult {
    const frame = vm.currentFrame.?;
    const slot = frame.ip[0];
    frame.ip += 1;
    vm.globalValues[slot] = peek(0);
    return .INTERPRET_OK;
}

fn opLoopCount() InterpretResult {
    const frame = vm.currentFrame.?;
    const slot = frame.ip[0];
    const offset = readOffset(frame);

    // Assume double for loop counter for simplicity in this fused op
    const val = frame.slots[slot].as_num_double();
    const limit = peek(0).as_num_double();

    if (val < limit) {
        frame.ip -= offset;
        // The increment is expected to happen before this op in the current compiler logic
        // but a true register loop would do it here. 
        // For now, this is just a fused JUMP_IF_LESS + LOOP
    }
    return .INTERPRET_OK;
}

fn opGetLocalLess() InterpretResult {
    const frame = vm.currentFrame.?;
    const slot = frame.ip[0];
    const constant_index = frame.ip[1];
    frame.ip += 2;

    const a = frame.slots[slot];
    const b = getConstant(frame, constant_index) orelse {
        runtimeError("Invalid constant index.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    };

    if (!a.is_prim_num() or !b.is_prim_num()) {
        runtimeError("Operands must be numbers.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }

    push(Value.init_bool(a.as_num_double() < b.as_num_double()));
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

fn opTailCall() InterpretResult {
    const frame = vm.currentFrame.?;
    const argCount = frame.ip[0];
    frame.ip += 1;

    const callee = peek(argCount);

    // For tail calls, we reuse the current frame instead of creating a new one
    if (callee.type == .VAL_OBJ and callee.as.obj.?.type == .OBJ_CLOSURE) {
        const closure: *ObjClosure = @ptrCast(@alignCast(callee.as.obj));

        // Check arity
        if (argCount != closure.function.arity) {
            runtimeError("Expected {d} arguments but got {d}.", .{ closure.function.arity, argCount });
            return .INTERPRET_RUNTIME_ERROR;
        }

        // Close upvalues from the current frame
        closeUpvalues(@ptrCast(&frame.slots[0]));

        // Copy arguments to the beginning of the current frame's slot area
        // The callee function is at stack position [stackTop - argCount - 1]
        // Arguments are at positions [stackTop - argCount] through [stackTop - 1]
        const stackBase = @intFromPtr(&vm.stack[0]);
        const currentSlots = @intFromPtr(frame.slots);
        const slotsOffset = (currentSlots - stackBase) / @sizeOf(Value);

        // Move arguments to the start of the current frame
        for (0..@intCast(argCount + 1)) |i| {
            vm.stack[slotsOffset + i] = vm.stack[vm.stackTop - @as(usize, @intCast(argCount + 1)) + i];
        }

        // Update stack top to reflect the new argument layout
        vm.stackTop = slotsOffset + @as(usize, @intCast(argCount + 1));

        // Replace the current frame's closure and reset IP
        frame.closure = closure;
        frame.ip = closure.function.chunk.code.?;

        return .INTERPRET_OK;
    } else {
        // For non-closure callees, fall back to regular call
        if (!callValue(callee, argCount)) {
            return .INTERPRET_RUNTIME_ERROR;
        }
        vm.currentFrame = &vm.frames[@intCast(vm.frameCount - 1)];
        return .INTERPRET_OK;
    }
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

                var key_str: *object_h.ObjString = undefined;
                if (index.is_string()) {
                    key_str = index.as_string();
                } else if (index.is_int()) {
                    // Convert integer index to string for JSON array-like behavior
                    var index_buf: [16]u8 = undefined;
                    const index_str_slice = std.fmt.bufPrint(&index_buf, "{d}", .{index.as_int()}) catch {
                        runtimeError("Failed to convert index to string.", .{});
                        return .INTERPRET_RUNTIME_ERROR;
                    };
                    key_str = object_h.copyString(index_str_slice.ptr, index_str_slice.len);
                } else {
                    runtimeError("Hash table key must be a string or integer.", .{});
                    return .INTERPRET_RUNTIME_ERROR;
                }

                if (table.get(key_str)) |val| {
                    push(val);
                } else {
                    push(Value.init_nil());
                }
            },
            .OBJ_MATRIX => {
                const matrix: *object_h.Matrix = @ptrCast(@alignCast(target.as.obj));
                if (!index.is_int()) {
                    runtimeError("Matrix row index must be an integer.", .{});
                    return .INTERPRET_RUNTIME_ERROR;
                }
                var row = index.as_int();

                // MufiZ now uses 0-based indexing (like most programming languages)
                // row is already 0-based, no conversion needed

                // Handle negative indices (from end)
                if (row < 0) row += @intCast(matrix.rows);

                if (row < 0 or row >= @as(i32, @intCast(matrix.rows))) {
                    runtimeError("Matrix row index out of bounds.", .{});
                    return .INTERPRET_RUNTIME_ERROR;
                }

                // Create and return a matrix row object
                const matrix_row = object_h.MatrixRow.init(matrix, @intCast(row));
                push(Value.init_obj(@ptrCast(matrix_row)));
            },
            .OBJ_MATRIX_ROW => {
                const matrix_row: *object_h.MatrixRow = @ptrCast(@alignCast(target.as.obj));
                if (!index.is_int()) {
                    runtimeError("Matrix column index must be an integer.", .{});
                    return .INTERPRET_RUNTIME_ERROR;
                }
                var col = index.as_int();

                // MufiZ now uses 0-based indexing (like most programming languages)
                // col is already 0-based, no conversion needed

                // Handle negative indices (from end)
                if (col < 0) col += @intCast(matrix_row.matrix.cols);

                if (col < 0 or col >= @as(i32, @intCast(matrix_row.matrix.cols))) {
                    runtimeError("Matrix column index out of bounds.", .{});
                    return .INTERPRET_RUNTIME_ERROR;
                }

                const element = matrix_row.get(@intCast(col));
                push(Value.init_double(element));
            },
            else => {
                runtimeError("Operand must be a string, range, array, pair, or matrix (got {any}).", .{target.as.obj.?.type});
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

                var key_str: *object_h.ObjString = undefined;
                if (index.is_string()) {
                    key_str = index.as_string();
                } else if (index.is_int()) {
                    // Convert integer index to string for JSON array-like behavior
                    var index_buf: [16]u8 = undefined;
                    const index_str_slice = std.fmt.bufPrint(&index_buf, "{d}", .{index.as_int()}) catch {
                        runtimeError("Failed to convert index to string.", .{});
                        return .INTERPRET_RUNTIME_ERROR;
                    };
                    key_str = object_h.copyString(index_str_slice.ptr, index_str_slice.len);
                } else {
                    runtimeError("Hash table key must be a string or integer.", .{});
                    return .INTERPRET_RUNTIME_ERROR;
                }

                _ = table.put(key_str, value);
                push(value);
            },
            .OBJ_MATRIX_ROW => {
                const matrix_row: *object_h.MatrixRow = @ptrCast(@alignCast(target.as.obj));
                if (!index.is_int()) {
                    runtimeError("Matrix column index must be an integer.", .{});
                    return .INTERPRET_RUNTIME_ERROR;
                }
                if (!value.is_prim_num()) {
                    runtimeError("Matrix elements must be numbers.", .{});
                    return .INTERPRET_RUNTIME_ERROR;
                }
                var col = index.as_int();

                // MufiZ now uses 0-based indexing (like most programming languages)
                // col is already 0-based, no conversion needed

                // Handle negative indices (from end)
                if (col < 0) col += @intCast(matrix_row.matrix.cols);

                if (col < 0 or col >= @as(i32, @intCast(matrix_row.matrix.cols))) {
                    runtimeError("Matrix column index out of bounds.", .{});
                    return .INTERPRET_RUNTIME_ERROR;
                }

                const val = @as(f64, @floatCast(value.as_num_double()));
                matrix_row.set(@intCast(col), val);
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

fn opUnknown() InterpretResult {
    const frame = vm.currentFrame.?;
    const instruction = (frame.ip - 1)[0];
    runtimeError("Unknown opcode: {d}", .{instruction});
    return .INTERPRET_RUNTIME_ERROR;
}

// Import opcode handlers
fn opImportModule() InterpretResult {
    const frame = vm.currentFrame.?;
    const name_constant = frame.ip[0];
    frame.ip += 1;

    // Validate constant index
    if (name_constant >= frame.closure.function.chunk.constants.count) {
        runtimeError("Invalid constant index for module name", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }

    const name_value = frame.closure.function.chunk.constants.values[@intCast(name_constant)];

    // Validate that the value is an object string
    if (name_value.type != .VAL_OBJ) {
        runtimeError("Module name must be a string", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }

    const name_obj = name_value.as.obj;
    if (!isObjType(name_value, .OBJ_STRING)) {
        runtimeError("Module name must be a string", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }

    const name_str = @as(*ObjString, @ptrCast(@alignCast(name_obj)));
    const module_name = name_str.chars[0..@intCast(name_str.length)];

    const registry = @import("module_registry.zig");
    
    // Determine if it's a builtin or user module for snapshotting
    const is_builtin = registry.isBuiltInModule(module_name);
    
    // Use GPA for temporary snapshot structures
    const allocator = mem_utils.getAllocator();
    
    var snapshot: ?std.StringHashMap(void) = null;
    if (!is_builtin) {
        snapshot = snapshotGlobals(allocator) catch null;
    }
    defer if (snapshot) |*s| s.deinit();

    registry.loadModule(module_name) catch {
        runtimeError("Failed to load module '{s}'", .{module_name});
        return .INTERPRET_RUNTIME_ERROR;
    };

    // Create a module object and register it as a global
    const module_obj = object_h.newModule(name_str);

    var new_globals: ?std.StringHashMap(Value) = null;
    if (snapshot) |s| {
        new_globals = getGlobalsSince(allocator, s) catch null;
    }
    defer if (new_globals) |*ng| {
        // Only free the map structure, not the values (they are in VM)
        ng.deinit();
    };

    // Populate the module with its members (constants and functions)
    registry.populateModuleMembers(module_obj, module_name, new_globals) catch {
        runtimeError("Failed to populate module '{s}'", .{module_name});
        return .INTERPRET_RUNTIME_ERROR;
    };

    // Define the module as a global variable with the module name
    const module_value = Value{
        .type = .VAL_OBJ,
        .as = .{ .obj = @ptrCast(@alignCast(module_obj)) },
    };
    _ = table_h.tableSetProtected(&vm.globals, name_str, module_value, true);

    return .INTERPRET_OK;
}

fn opImportFile() InterpretResult {
    const frame = vm.currentFrame.?;
    const path_constant = frame.ip[0];
    frame.ip += 1;

    // Validate constant index
    if (path_constant >= frame.closure.function.chunk.constants.count) {
        runtimeError("Invalid constant index for file path", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }

    const path_value = frame.closure.function.chunk.constants.values[@intCast(path_constant)];

    // Validate that the value is an object string
    if (path_value.type != .VAL_OBJ) {
        runtimeError("File path must be a string", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }

    const path_obj = path_value.as.obj;
    if (!isObjType(path_value, .OBJ_STRING)) {
        runtimeError("File path must be a string", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }

    const path_str = @as(*ObjString, @ptrCast(@alignCast(path_obj)));
    const file_path = path_str.chars[0..@intCast(path_str.length)];

    // Get current function's source file to use as base for relative imports
    const current_file_obj = frame.closure.function.source_file;
    const base_path = if (current_file_obj) |obj| obj.chars[0..obj.length] else null;

    const registry = @import("module_registry.zig");
    registry.loadFileWithBase(file_path, base_path) catch {
        runtimeError("Failed to load file '{s}'", .{file_path});
        return .INTERPRET_RUNTIME_ERROR;
    };

    return .INTERPRET_OK;
}

fn opImportFileAs() InterpretResult {
    const frame = vm.currentFrame.?;
    const path_constant = frame.ip[0];
    const alias_constant = frame.ip[1];
    frame.ip += 2;

    // Validate constant indices
    if (path_constant >= frame.closure.function.chunk.constants.count or
        alias_constant >= frame.closure.function.chunk.constants.count)
    {
        runtimeError("Invalid constant index for file import", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }

    const path_value = frame.closure.function.chunk.constants.values[@intCast(path_constant)];
    const alias_value = frame.closure.function.chunk.constants.values[@intCast(alias_constant)];

    // Validate path is a string
    if (path_value.type != .VAL_OBJ or !isObjType(path_value, .OBJ_STRING)) {
        runtimeError("File path must be a string", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }

    // Validate alias is a string
    if (alias_value.type != .VAL_OBJ or !isObjType(alias_value, .OBJ_STRING)) {
        runtimeError("Module alias must be a string", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }

    const path_str = @as(*ObjString, @ptrCast(@alignCast(path_value.as.obj)));
    const alias_str = @as(*ObjString, @ptrCast(@alignCast(alias_value.as.obj)));

    const registry = @import("module_registry.zig");

    // Create a module object and populate it with only public globals from the last import
    const module_obj = object_h.newModule(path_str);

    if (registry.last_import_globals) |globals| {
        var iter = globals.iterator();
        while (iter.next()) |entry| {
            const name = entry.key_ptr.*;
            const value = entry.value_ptr.*;
            
            // Convert name to ObjString for public check
            const name_obj = object_h.copyString(name.ptr, name.len);
            if (isPublicGlobal(name_obj)) {
                module_obj.setMember(name, value) catch {
                    runtimeError("Failed to populate module member '{s}'", .{name});
                    return .INTERPRET_RUNTIME_ERROR;
                };
            }
        }
    }

    // Register the module under the alias name
    const module_value = Value{
        .type = .VAL_OBJ,
        .as = .{ .obj = @ptrCast(@alignCast(module_obj)) },
    };
    _ = table_h.tableSetProtected(&vm.globals, alias_str, module_value, true);

    return .INTERPRET_OK;
}

fn opFromImportFile() InterpretResult {
    const frame = vm.currentFrame.?;
    const path_constant = frame.ip[0];
    const func_constant = frame.ip[1];
    frame.ip += 2;

    // Validate constant indices
    if (path_constant >= frame.closure.function.chunk.constants.count or
        func_constant >= frame.closure.function.chunk.constants.count)
    {
        runtimeError("Invalid constant index for import", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }

    const path_value = frame.closure.function.chunk.constants.values[@intCast(path_constant)];
    if (path_value.type != .VAL_OBJ or !isObjType(path_value, .OBJ_STRING)) {
        runtimeError("File path must be a string", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }

    const func_value = frame.closure.function.chunk.constants.values[@intCast(func_constant)];
    if (func_value.type != .VAL_OBJ or !isObjType(func_value, .OBJ_STRING)) {
        runtimeError("Function name must be a string", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }

    const func_str = @as(*ObjString, @ptrCast(@alignCast(func_value.as.obj)));
    const func_name = func_str.chars[0..@intCast(func_str.length)];

    const registry = @import("module_registry.zig");

    // Check if the requested name exists in the last imported symbols and is public
    var found = false;
    if (registry.last_import_globals) |globals| {
        if (globals.get(func_name)) |_| {
            found = true;
            if (!isPublicGlobal(func_str)) {
                const path_str = @as(*ObjString, @ptrCast(@alignCast(path_value.as.obj)));
                const file_path = path_str.chars[0..@intCast(path_str.length)];
                runtimeError("'{s}' is not a public export of '{s}'", .{ func_name, file_path });
                return .INTERPRET_RUNTIME_ERROR;
            }
        }
    }

    if (!found) {
        const path_str = @as(*ObjString, @ptrCast(@alignCast(path_value.as.obj)));
        const file_path = path_str.chars[0..@intCast(path_str.length)];
        runtimeError("'{s}' not found in '{s}'", .{ func_name, file_path });
        return .INTERPRET_RUNTIME_ERROR;
    }

    return .INTERPRET_OK;
}

fn opImportSpecific() InterpretResult {
    const frame = vm.currentFrame.?;
    const module_constant = frame.ip[0];
    const func_constant = frame.ip[1];
    frame.ip += 2;

    // Validate constant indices
    if (module_constant >= frame.closure.function.chunk.constants.count or
        func_constant >= frame.closure.function.chunk.constants.count)
    {
        runtimeError("Invalid constant index for import", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }

    const module_value = frame.closure.function.chunk.constants.values[@intCast(module_constant)];

    // Validate module name is a string
    if (module_value.type != .VAL_OBJ or !isObjType(module_value, .OBJ_STRING)) {
        runtimeError("Module name must be a string", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }

    const module_obj = module_value.as.obj;
    const module_str = @as(*ObjString, @ptrCast(@alignCast(module_obj)));
    const module_name = module_str.chars[0..@intCast(module_str.length)];

    const func_value = frame.closure.function.chunk.constants.values[@intCast(func_constant)];

    // Validate function name is a string
    if (func_value.type != .VAL_OBJ or !isObjType(func_value, .OBJ_STRING)) {
        runtimeError("Function name must be a string", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }

    const func_obj = func_value.as.obj;
    const func_str = @as(*ObjString, @ptrCast(@alignCast(func_obj)));
    const func_name = func_str.chars[0..@intCast(func_str.length)];

    const registry = @import("module_registry.zig");
    registry.loadSpecificFunction(module_name, func_name) catch {
        runtimeError("Failed to import '{s}' from '{s}'", .{ func_name, module_name });
        return .INTERPRET_RUNTIME_ERROR;
    };

    return .INTERPRET_OK;
}

fn opImportModuleAs() InterpretResult {
    const frame = vm.currentFrame.?;
    const name_constant = frame.ip[0];
    const alias_constant = frame.ip[1];
    frame.ip += 2;

    // Validate constant indices
    if (name_constant >= frame.closure.function.chunk.constants.count or
        alias_constant >= frame.closure.function.chunk.constants.count)
    {
        runtimeError("Invalid constant index for module import", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }

    const name_value = frame.closure.function.chunk.constants.values[@intCast(name_constant)];
    const alias_value = frame.closure.function.chunk.constants.values[@intCast(alias_constant)];

    // Validate that both values are object strings
    if (name_value.type != .VAL_OBJ or !isObjType(name_value, .OBJ_STRING)) {
        runtimeError("Module name must be a string", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }

    if (alias_value.type != .VAL_OBJ or !isObjType(alias_value, .OBJ_STRING)) {
        runtimeError("Module alias must be a string", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }

    const name_str = @as(*ObjString, @ptrCast(@alignCast(name_value.as.obj)));
    const alias_str = @as(*ObjString, @ptrCast(@alignCast(alias_value.as.obj)));
    const module_name = name_str.chars[0..@intCast(name_str.length)];

    const registry = @import("module_registry.zig");
    registry.loadModule(module_name) catch {
        runtimeError("Failed to load module '{s}'", .{module_name});
        return .INTERPRET_RUNTIME_ERROR;
    };

    // Create a module object and register it with the alias name
    const module_obj = object_h.newModule(name_str);

    // Populate the module with its members (constants and functions)
    registry.populateModuleMembers(module_obj, module_name, null) catch {
        runtimeError("Failed to populate module '{s}'", .{module_name});
        return .INTERPRET_RUNTIME_ERROR;
    };

    // Define the module as a global variable with the alias name
    const module_value = Value{
        .type = .VAL_OBJ,
        .as = .{ .obj = @ptrCast(@alignCast(module_obj)) },
    };
    _ = table_h.tableSetProtected(&vm.globals, alias_str, module_value, true);

    return .INTERPRET_OK;
}

const jumpTable = blk: {
    var table: [256]OpHandler = undefined;
    for (0..256) |i| {
        table[i] = opUnknown;
    }
    // Visibility opcodes (94-97)
    table[@intFromEnum(OpCode.OP_DEFINE_PUBLIC_GLOBAL)] = opDefinePublicGlobal;
    table[@intFromEnum(OpCode.OP_DEFINE_PUBLIC_CONST_GLOBAL)] = opDefinePublicConstGlobal;
    table[@intFromEnum(OpCode.OP_IMPORT_FILE_AS)] = opImportFileAs;
    table[@intFromEnum(OpCode.OP_FROM_IMPORT_FILE)] = opFromImportFile;

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
    table[@intFromEnum(OpCode.OP_BAND)] = opBand;
    table[@intFromEnum(OpCode.OP_BOR)] = opBor;
    table[@intFromEnum(OpCode.OP_BXOR)] = opBxor;
    table[@intFromEnum(OpCode.OP_BNOT)] = opBnot;
    table[@intFromEnum(OpCode.OP_SHL)] = opShl;
    table[@intFromEnum(OpCode.OP_SHR)] = opShr;
    table[@intFromEnum(OpCode.OP_NOT)] = opNot;
    table[@intFromEnum(OpCode.OP_NEGATE)] = opNegate;
    table[@intFromEnum(OpCode.OP_PRINT)] = opPrint;
    table[@intFromEnum(OpCode.OP_JUMP)] = opJump;
    table[@intFromEnum(OpCode.OP_JUMP_IF_FALSE)] = opJumpIfFalse;
    table[@intFromEnum(OpCode.OP_LOOP)] = opLoop;
    table[@intFromEnum(OpCode.OP_CALL)] = opCall;
    table[@intFromEnum(OpCode.OP_TAIL_CALL)] = opTailCall;
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
    table[@intFromEnum(OpCode.OP_GET_MATRIX_FLAT)] = opGetMatrixFlat;
    // Import opcodes
    table[@intFromEnum(OpCode.OP_IMPORT_MODULE)] = opImportModule;
    table[@intFromEnum(OpCode.OP_IMPORT_FILE)] = opImportFile;
    table[@intFromEnum(OpCode.OP_IMPORT_SPECIFIC)] = opImportSpecific;
    table[@intFromEnum(OpCode.OP_IMPORT_MODULE_AS)] = opImportModuleAs;
    table[@intFromEnum(OpCode.OP_GET_MODULE_MEMBER)] = opGetModuleMember;

    // Phase 2.1: Small constant opcodes (67-82)
    for (0..16) |i| {
        table[@intFromEnum(OpCode.OP_CONSTANT_0) + i] = makeOpConstant(i);
    }

    // Phase 2.2: Small local opcodes (83-90)
    for (0..4) |i| {
        table[@intFromEnum(OpCode.OP_GET_LOCAL_0) + i] = makeOpGetLocal(i);
        table[@intFromEnum(OpCode.OP_SET_LOCAL_0) + i] = makeOpSetLocal(i);
    }

    // Phase 2.3: Short jump opcodes (91-93)
    table[@intFromEnum(OpCode.OP_JUMP_SHORT)] = opJumpShort;
    table[@intFromEnum(OpCode.OP_JUMP_IF_FALSE_SHORT)] = opJumpIfFalseShort;
    table[@intFromEnum(OpCode.OP_LOOP_SHORT)] = opLoopShort;

    // Phase 3: Superinstructions (100-191)
    table[@intFromEnum(OpCode.OP_DEFINE_GLOBAL_CONST)] = opDefineGlobalConst;
    table[@intFromEnum(OpCode.OP_SET_GLOBAL_CONST)] = opSetGlobalConst;
    table[@intFromEnum(OpCode.OP_GET_GLOBAL_ADD)] = opGetGlobalAdd;
    table[@intFromEnum(OpCode.OP_GET_GLOBAL_SUBTRACT)] = opGetGlobalSubtract;
    table[@intFromEnum(OpCode.OP_GET_GLOBAL_MULTIPLY)] = opGetGlobalMultiply;
    table[@intFromEnum(OpCode.OP_GET_GLOBAL_DIVIDE)] = opGetGlobalDivide;
    table[@intFromEnum(OpCode.OP_GET_LOCAL_ADD)] = opGetLocalAdd;
    table[@intFromEnum(OpCode.OP_GET_GLOBAL_GLOBAL)] = opGetGlobalGlobal;
    table[@intFromEnum(OpCode.OP_GET_LOCAL_LOCAL)] = opGetLocalLocal;
    table[@intFromEnum(OpCode.OP_GET_GLOBAL_LOCAL)] = opGetGlobalLocal;
    table[@intFromEnum(OpCode.OP_GET_LOCAL_GLOBAL)] = opGetLocalGlobal;
    table[@intFromEnum(OpCode.OP_CONSTANT_CONSTANT)] = opConstantConstant;
    table[@intFromEnum(OpCode.OP_CONSTANT_ADD)] = opConstantAdd;
    table[@intFromEnum(OpCode.OP_CONSTANT_MULTIPLY)] = opConstantMultiply;
    table[@intFromEnum(OpCode.OP_LESS_JUMP_IF_FALSE)] = opLessJumpIfFalse;
    table[@intFromEnum(OpCode.OP_GET_LOCAL_CONSTANT)] = opGetLocalConstant;
    table[@intFromEnum(OpCode.OP_ADD_SET_LOCAL)] = opAddSetLocal;
    table[@intFromEnum(OpCode.OP_SET_LOCAL_POP)] = opSetLocalPop;
    table[@intFromEnum(OpCode.OP_ADD_REG)] = opAddReg;
    table[@intFromEnum(OpCode.OP_SUB_REG)] = opSubReg;
    table[@intFromEnum(OpCode.OP_MUL_REG)] = opMulReg;
    table[@intFromEnum(OpCode.OP_DIV_REG)] = opDivReg;
    table[@intFromEnum(OpCode.OP_GET_GLOBAL_SLOT)] = opGetGlobalSlot;
    table[@intFromEnum(OpCode.OP_SET_GLOBAL_SLOT)] = opSetGlobalSlot;
    table[@intFromEnum(OpCode.OP_SET_GLOBAL_SLOT_KEEP)] = opSetGlobalSlotKeep;
    table[@intFromEnum(OpCode.OP_LOOP_COUNT)] = opLoopCount;
    table[@intFromEnum(OpCode.OP_GET_LOCAL_LESS)] = opGetLocalLess;

    break :blk table;
};

fn opGetMatrixFlat() InterpretResult {
    const index = pop();
    const target = pop();

    if (!target.is_obj() or !object_h.isObjType(target, .OBJ_MATRIX)) {
        runtimeError("Operand must be a matrix.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }

    if (!index.is_int()) {
        runtimeError("Matrix flat index must be an integer.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }

    const matrix: *object_h.Matrix = @ptrCast(@alignCast(target.as.obj));
    const idx = index.as_int();
    const total_elements = @as(i32, @intCast(matrix.rows * matrix.cols));

    if (idx < 0 or idx >= total_elements) {
        runtimeError("Matrix flat index out of bounds.", .{});
        return .INTERPRET_RUNTIME_ERROR;
    }

    const element = matrix.getFlat(@intCast(idx));
    push(Value.init_double(element));
    return .INTERPRET_OK;
}

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

        // Instrumentation for optimization analysis
        const vm_trace = @import("vm_trace.zig");
        if (vm_trace.isEnabled()) {
            vm_trace.recordQuick(instruction, vm.stackTop);
        }

        const result = jumpTable[instruction]();
        if (result != .INTERPRET_OK) {
            if (result == .INTERPRET_FINISHED) return .INTERPRET_OK;
            return result;
        }
    }
}

/// Execute bytecode until the frame count returns to target_depth
pub fn runUntil(target_depth: i32) InterpretResult {
    // Ensure currentFrame is up to date
    if (vm.frameCount > 0) {
        vm.currentFrame = &vm.frames[@intCast(vm.frameCount - 1)];
    }

    while (vm.frameCount > target_depth) {
        const frame = vm.currentFrame.?;
        const instruction = frame.ip[0];
        frame.ip += 1;

        // Instrumentation for optimization analysis
        const vm_trace = @import("vm_trace.zig");
        if (vm_trace.isEnabled()) {
            vm_trace.recordQuick(instruction, vm.stackTop);
        }

        const result = jumpTable[instruction]();
        if (result != .INTERPRET_OK) {
            if (result == .INTERPRET_FINISHED) {
                if (vm.frameCount <= target_depth) return .INTERPRET_OK;
                continue; // Should not happen if target_depth >= 0
            }
            return result;
        }
    }
    return .INTERPRET_OK;
}

inline fn peek(distance: u32) Value {
    return vm.stack[vm.stackTop - 1 - distance];
}
