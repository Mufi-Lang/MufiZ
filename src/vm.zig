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
const cstd_h = @import("cstd.zig");
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
const newInstance = object_h.newInstance;
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

// pub fn importCollections() void {
//     defineNative("assert", cstd_h.assert_nf);
//     // defineNative("array", &cstd_h.array_nf);
//     defineNative("linked_list", cstd_h.linkedlist_nf);
//     defineNative("hash_table", cstd_h.hashtable_nf);
//     // defineNative("matrix", &cstd_h.matrix_nf);
//     defineNative("fvec", cstd_h.fvector_nf);
//     // defineNative("range", &cstd_h.range_nf);
//     defineNative("linspace", cstd_h.linspace_nf);
//     defineNative("slice", &cstd_h.slice_nf);
//     defineNative("splice", &cstd_h.splice_nf);
//     defineNative("push", &cstd_h.push_nf);
//     defineNative("pop", &cstd_h.pop_nf);
//     defineNative("push_front", &cstd_h.push_front_nf);
//     defineNative("pop_front", &cstd_h.pop_front_nf);
//     defineNative("nth", &cstd_h.nth_nf);
//     defineNative("sort", &cstd_h.sort_nf);
//     defineNative("contains", &cstd_h.contains_nf);
//     defineNative("insert", &cstd_h.insert_nf);
//     defineNative("len", &cstd_h.len_nf);
//     defineNative("search", &cstd_h.search_nf);
//     defineNative("is_empty", &cstd_h.is_empty_nf);
//     defineNative("equal_list", &cstd_h.equal_list_nf);
//     defineNative("reverse", &cstd_h.reverse_nf);
//     defineNative("merge", &cstd_h.merge_nf);
//     defineNative("clone", &cstd_h.clone_nf);
//     defineNative("clear", &cstd_h.clear_nf);
//     defineNative("next", &cstd_h.next_nf);
//     defineNative("has_next", &cstd_h.hasNext_nf);
//     defineNative("reset", &cstd_h.reset_nf);
//     defineNative("skip", &cstd_h.skip_nf);
//     defineNative("put", &cstd_h.put_nf);
//     defineNative("get", &cstd_h.get_nf);
//     defineNative("remove", &cstd_h.remove_nf);
//     // defineNative("set_row", &cstd_h.set_row_nf);
//     // defineNative("set_col", &cstd_h.set_col_nf);
//     // defineNative("set", &cstd_h.set_nf);
//     // defineNative("kolasa", &cstd_h.kolasa_nf);
//     // defineNative("rref", &cstd_h.rref_nf);
//     // defineNative("rank", &cstd_h.rank_nf);
//     // defineNative("transpose", &cstd_h.transpose_nf);
//     // defineNative("det", &cstd_h.determinant_nf);
//     // defineNative("lu", &cstd_h.lu_nf);
//     defineNative("workspace", &cstd_h.workspace_nf);
//     defineNative("interp1", &cstd_h.interp1_nf);
//     defineNative("sum", &cstd_h.sum_nf);
//     defineNative("mean", &cstd_h.mean_nf);
//     defineNative("std", &cstd_h.std_nf);
//     defineNative("vari", &cstd_h.var_nf);
//     defineNative("maxl", &cstd_h.maxl_nf);
//     defineNative("minl", &cstd_h.minl_nf);
//     defineNative("dot", &cstd_h.dot_nf);
//     defineNative("cross", &cstd_h.cross_nf);
//     defineNative("norm", &cstd_h.norm_nf);
//     defineNative("angle", &cstd_h.angle_nf);
//     defineNative("proj", &cstd_h.proj_nf);
//     defineNative("reflect", &cstd_h.reflect_nf);
//     defineNative("reject", &cstd_h.reject_nf);
//     defineNative("refract", &cstd_h.refract_nf);
// }

inline fn zstr(s: ?*ObjString) []u8 {
    if (s) |str| {
        const len: usize = @intCast(str.length);
        return str.chars[0..len];
    } else {
        return @constCast("null");
    }
}

/// Set whether the VM should echo input commands and control result printing
/// Returns the previous value of echo_enabled
/// Note: Terminal echo is now controlled by the SimpleLineEditor
pub fn setEchoHook(echo: bool) bool {
    const old_value = echo_enabled;
    echo_enabled = echo;
    // We no longer suppress output when echo is disabled
    // The REPL should show results regardless of echo state
    repl_mode = !echo;
    return old_value;
}

pub fn interpret(source: [*]const u8) InterpretResult {
    const function: ?*ObjFunction = compiler_h.compile(source);
    if (function == null) return .INTERPRET_COMPILE_ERROR;

    // Only echo in non-REPL mode or when explicitly enabled
    if (echo_enabled and !repl_mode) {
        var i: usize = 0;
        while (source[i] != 0) : (i += 1) {}
        print("{s}\n", .{source[0..i]});
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

// Helper function to append a value's string representation to a buffer
fn valueToString(value: Value, buffer: *std.ArrayList(u8)) void {
    switch (value.type) {
        .VAL_BOOL => {
            if (value.as.boolean) {
                buffer.appendSlice("true") catch return;
            } else {
                buffer.appendSlice("false") catch return;
            }
        },
        .VAL_NIL => {
            buffer.appendSlice("nil") catch return;
        },
        .VAL_DOUBLE => {
            const str = std.fmt.allocPrint(std.heap.page_allocator, "{d}", .{value.as.num_double}) catch return;
            defer std.heap.page_allocator.free(str);
            buffer.appendSlice(str) catch return;
        },
        .VAL_INT => {
            const str = std.fmt.allocPrint(std.heap.page_allocator, "{d}", .{value.as.num_int}) catch return;
            defer std.heap.page_allocator.free(str);
            buffer.appendSlice(str) catch return;
        },
        .VAL_OBJ => {
            if (value.as.obj) |obj| {
                switch (obj.type) {
                    .OBJ_STRING => {
                        const string = @as(*ObjString, @ptrCast(@alignCast(obj)));
                        buffer.appendSlice(string.*.chars[0..string.*.length]) catch return;
                    },
                    else => {
                        const str = std.fmt.allocPrint(std.heap.page_allocator, "[object]", .{}) catch return;
                        defer std.heap.page_allocator.free(str);
                        buffer.appendSlice(str) catch return;
                    },
                }
            }
        },
        .VAL_COMPLEX => {
            const str = std.fmt.allocPrint(std.heap.page_allocator, "{d}{s}{d}i", .{ value.as.complex.r, if (value.as.complex.i >= 0) "+" else "", value.as.complex.i }) catch return;
            defer std.heap.page_allocator.free(str);
            buffer.appendSlice(str) catch return;
        },
    }
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

                // Replace that slot with the instance
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
            .OBJ_STRING => {
                // Format a string with placeholders
                if (argCount < 1) {
                    runtimeError("String format requires at least one argument.", .{});
                    return false;
                }

                // Get the string to be formatted
                const formatStr = @as(*ObjString, @ptrCast(@alignCast(callee.as.obj)));
                const format = formatStr.*.chars[0..formatStr.*.length];

                // Allocate a buffer for the result
                var result = std.ArrayList(u8).init(std.heap.page_allocator);
                defer result.deinit();

                // Process format string looking for {} placeholders
                var i: usize = 0;
                var arg_index: i32 = 0;

                while (i < format.len) {
                    // Look for opening brace
                    if (i + 1 < format.len and format[i] == '{' and format[i + 1] == '}') {
                        // Found a placeholder
                        if (arg_index < argCount) {
                            // Get the argument from stack
                            const arg = peek(argCount - arg_index - 1);

                            // Convert the argument to string and append it
                            valueToString(arg, &result);
                            arg_index += 1;
                            i += 2; // Skip over {}
                        } else {
                            // More placeholders than arguments
                            runtimeError("Not enough arguments for format string.", .{});
                            return false;
                        }
                    } else {
                        // Regular character, just append it
                        result.append(format[i]) catch {
                            runtimeError("Failed to format string.", .{});
                            return false;
                        };
                        i += 1;
                    }
                }

                // Create a new string with the result
                const resultString = object_h.copyString(result.items.ptr, @intCast(result.items.len));

                // Replace the callee and arguments with the result
                vm.stackTop -= @as(usize, @intCast(argCount + 1));
                push(Value.init_obj(@ptrCast(@alignCast(resultString))));

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
        const propName = name.*.chars[0..len];

        // Enhanced error reporting for undefined properties
        if (@import("compiler.zig").errorManagerInitialized) {
            const errorInfo = errors.ErrorTemplates.undefinedMethod("class", propName, &[_][]const u8{});
            @import("compiler.zig").globalErrorManager.reportError(errorInfo);
        }
        runtimeError("Undefined property '{s}'.", .{propName});
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
        const propName = zstr(name);
        // Enhanced error reporting for undefined properties in method binding
        if (@import("compiler.zig").errorManagerInitialized) {
            const errorInfo = errors.ErrorTemplates.undefinedMethod("class", propName, &[_][]const u8{});
            @import("compiler.zig").globalErrorManager.reportError(errorInfo);
        }
        runtimeError("Undefined property '{s}'.", .{propName});
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
        while (@intFromPtr(slot) < @intFromPtr(vm.stackTop)) : (slot += 1) {
            print("[ ", .{});
            printValue(slot[0]);
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
                        const varName = zstr(name);
                        // Enhanced error reporting for undefined variables
                        if (@import("compiler.zig").errorManagerInitialized) {
                            @import("compiler.zig").populateKnownVariablesFromGlobals();
                            const similar = @import("compiler.zig").findSimilarVariables(varName, std.heap.page_allocator);
                            const errorInfo = errors.ErrorTemplates.undefinedVariable(varName, similar);
                            @import("compiler.zig").globalErrorManager.reportError(errorInfo);
                        }
                        runtimeError("Undefined variable '{s}'.", .{varName});
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
                        const varName = zstr(name);
                        // Enhanced error reporting for undefined variables during assignment
                        if (@import("compiler.zig").errorManagerInitialized) {
                            @import("compiler.zig").populateKnownVariablesFromGlobals();
                            const similar = @import("compiler.zig").findSimilarVariables(varName, std.heap.page_allocator);
                            const errorInfo = errors.ErrorTemplates.undefinedVariable(varName, similar);
                            @import("compiler.zig").globalErrorManager.reportError(errorInfo);
                        }
                        runtimeError("Undefined variable '{s}'.", .{varName});
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
                    // Initialize with exact size needed
                    const f = fvec.FloatVector.init(@intCast(count));

                    // First collect all values from the stack
                    var values: [255]f64 = undefined;
                    for (0..@intCast(count)) |i| {
                        values[i] = peek((count - @as(i32, @intCast(i))) - 1).as_num_double();
                    }

                    // Pop the values from the stack
                    for (0..@intCast(count)) |_| {
                        _ = pop();
                    }

                    // Set values directly in the vector
                    for (0..@intCast(count)) |i| {
                        f.*.data[i] = values[i];
                    }
                    // Set count manually to ensure it matches
                    f.*.count = @intCast(count);

                    // Push the vector object
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
                    if (repl_mode) {
                        // In REPL mode, always print values from print statements
                        // This ensures "print x;" works as expected
                        printValue(pop());
                        print("\n", .{});
                    } else if (!suppress_output) {
                        printValue(pop());
                        print("\n", .{});
                    } else {
                        _ = pop(); // Still pop the value but don't print it
                    }
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
                .OP_LENGTH => {
                    const object = pop();

                    if (object.type == .VAL_OBJ and object.as.obj != null) {
                        switch (object.as.obj.?.type) {
                            .OBJ_FVECTOR => {
                                const vector = @as(*fvec.FloatVector, @ptrCast(@alignCast(object.as.obj.?)));
                                // Get object's count and keep object alive
                                object.retain();
                                push(Value.init_int(@intCast(vector.count)));
                                object.release();
                            },
                            .OBJ_STRING => {
                                const string = @as(*ObjString, @ptrCast(@alignCast(object.as.obj.?)));
                                push(Value.init_int(@intCast(string.length)));
                            },
                            // Add other collection types here as they get implemented
                            else => {
                                push(Value.init_int(0));
                            },
                        }
                    } else {
                        push(Value.init_int(0));
                    }

                    continue;
                },
                .OP_GET_INDEX => {
                    const index = pop();
                    const object = pop();

                    // For non-objects, return an error
                    if (object.type != .VAL_OBJ or object.as.obj == null) {
                        runtimeError("Cannot index non-object value.", .{});
                        return .INTERPRET_RUNTIME_ERROR;
                    }

                    switch (object.as.obj.?.type) {
                        .OBJ_HASH_TABLE => {
                            // Hash table lookup requires a string key
                            if (!index.is_string()) {
                                runtimeError("Hash table key must be a string.", .{});
                                return .INTERPRET_RUNTIME_ERROR;
                            }

                            const hashTable = @as(*object_h.ObjHashTable, @ptrCast(@alignCast(object.as.obj.?)));
                            const key = @as(*ObjString, @ptrCast(@alignCast(index.as.obj.?)));
                            const value = object_h.getHashTable(hashTable, key);
                            push(value);
                        },
                        .OBJ_FVECTOR => {
                            // Convert index to integer if possible
                            var idx: i32 = 0;
                            if (index.is_int()) {
                                idx = index.as_num_int();
                            } else if (index.is_double()) {
                                idx = @as(i32, @intFromFloat(index.as_num_double()));
                            } else {
                                runtimeError("Index must be a number.", .{});
                                return .INTERPRET_RUNTIME_ERROR;
                            }

                            const vector = @as(*fvec.FloatVector, @ptrCast(@alignCast(object.as.obj.?)));

                            // Handle 'end' keyword (represented by -1)
                            if (idx == -1) {
                                idx = @as(i32, @intCast(vector.count)) - 1;
                            } else if (idx < -1) {
                                // Handle 'end-n' expressions (idx = -1 - n, so actual_idx = count + idx + 1)
                                idx = @as(i32, @intCast(vector.count)) + idx;
                            }

                            if (idx < 0 or idx >= vector.count) {
                                runtimeError("Index out of bounds: {} (count: {})", .{ idx, vector.count });
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
                            var idx = index.as_num_int();

                            // Handle 'end' keyword (represented by -1)
                            if (idx == -1) {
                                idx = @as(i32, @intCast(string.length)) - 1;
                            } else if (idx < -1) {
                                // Handle 'end-n' expressions
                                idx = @as(i32, @intCast(string.length)) + idx;
                            }

                            if (idx < 0 or idx >= string.length) {
                                runtimeError("Index out of bounds.", .{});
                                return .INTERPRET_RUNTIME_ERROR;
                            }
                            const char = string.chars[@intCast(idx)];
                            const char_str = object_h.copyString(@ptrCast(&char), 1);
                            push(Value.init_obj(@ptrCast(@alignCast(char_str))));
                        },
                        .OBJ_LINKED_LIST => {
                            if (!index.is_int()) {
                                runtimeError("Index must be an integer.", .{});
                                return .INTERPRET_RUNTIME_ERROR;
                            }
                            const list = @as(*ObjLinkedList, @ptrCast(@alignCast(object.as.obj.?)));
                            var idx = index.as_num_int();

                            // Handle 'end' keyword (represented by -1)
                            if (idx == -1) {
                                idx = list.count - 1;
                            } else if (idx < -1) {
                                // Handle 'end-n' expressions
                                idx = list.count + idx;
                            }

                            if (idx < 0 or idx >= list.count) {
                                runtimeError("Index out of bounds.", .{});
                                return .INTERPRET_RUNTIME_ERROR;
                            }

                            // Traverse the linked list to find the element at index
                            var current = list.head;
                            var i: i32 = 0;
                            while (current != null and i < idx) {
                                current = current.?.next;
                                i += 1;
                            }

                            if (current != null) {
                                push(current.?.data);
                            } else {
                                runtimeError("Index out of bounds.", .{});
                                return .INTERPRET_RUNTIME_ERROR;
                            }
                        },
                        else => {
                            runtimeError("Cannot index this type of object.", .{});
                            return .INTERPRET_RUNTIME_ERROR;
                        },
                    }
                    continue;
                },
                .OP_SET_INDEX => {
                    const value = pop();
                    const index = pop();
                    const object = peek(0); // Keep object on stack for assignment result

                    if (object.type == .VAL_OBJ and object.as.obj != null) {
                        switch (object.as.obj.?.type) {
                            .OBJ_HASH_TABLE => {
                                if (!index.is_string()) {
                                    runtimeError("Hash table key must be a string.", .{});
                                    return .INTERPRET_RUNTIME_ERROR;
                                }

                                const hashTable = @as(*object_h.ObjHashTable, @ptrCast(@alignCast(object.as.obj.?)));
                                const key = @as(*ObjString, @ptrCast(@alignCast(index.as.obj.?)));
                                _ = object_h.putHashTable(hashTable, key, value);

                                // Leave object on stack (it's the result of assignment)
                                _ = pop(); // Remove object
                                push(value); // Put value back on stack as the result
                            },
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
                                var idx = index.as_num_int();

                                // Handle 'end' keyword (represented by -1)
                                if (idx == -1) {
                                    idx = @as(i32, @intCast(vector.count)) - 1;
                                } else if (idx < -1) {
                                    // Handle 'end-n' expressions
                                    idx = @as(i32, @intCast(vector.count)) + idx;
                                }
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
                .OP_DUP => {
                    const value = peek(0);
                    push(value);
                    continue;
                },
                .OP_INT => {
                    const value = pop();
                    if (value.is_int()) {
                        // Already an int, just push it back
                        push(value);
                    } else if (value.is_double()) {
                        // Convert double to int
                        const intValue = @as(i32, @intFromFloat(value.as_num_double()));
                        push(Value.init_int(intValue));
                    } else if (value.is_bool()) {
                        // Convert boolean to int (true=1, false=0)
                        const intValue: i32 = if (value.as.boolean) 1 else 0;
                        push(Value.init_int(intValue));
                    } else if (value.is_obj()) {
                        // Try to get length for objects
                        if (value.as.obj != null and value.as.obj.?.type == .OBJ_FVECTOR) {
                            const vector = @as(*fvec.FloatVector, @ptrCast(@alignCast(value.as.obj.?)));
                            push(Value.init_int(@intCast(vector.count)));
                        } else if (value.as.obj != null and value.as.obj.?.type == .OBJ_HASH_TABLE) {
                            const hashTable = @as(*object_h.ObjHashTable, @ptrCast(@alignCast(value.as.obj.?)));
                            push(Value.init_int(@intCast(hashTable.*.table.count)));
                        } else {
                            push(Value.init_int(0));
                        }
                    } else {
                        push(Value.init_int(0));
                    }
                    continue;
                },
                .OP_HASH_TABLE => {
                    // Create a new hash table
                    const hashTable = object_h.newHashTable();
                    push(Value.init_obj(@ptrCast(hashTable)));
                    continue;
                },
                .OP_ADD_ENTRY => {
                    // Stack has: value, key, hash table
                    const value = pop();
                    const key = pop();
                    const table = peek(0); // Leave on stack

                    if (table.type != .VAL_OBJ or table.as.obj == null or table.as.obj.?.type != .OBJ_HASH_TABLE) {
                        runtimeError("Expected hash table for dictionary entry.", .{});
                        return .INTERPRET_RUNTIME_ERROR;
                    }

                    if (!key.is_string()) {
                        runtimeError("Hash table key must be a string.", .{});
                        return .INTERPRET_RUNTIME_ERROR;
                    }

                    const hashTable = @as(*object_h.ObjHashTable, @ptrCast(@alignCast(table.as.obj.?)));
                    const keyString = @as(*ObjString, @ptrCast(@alignCast(key.as.obj.?)));
                    _ = object_h.putHashTable(hashTable, keyString, value);
                    continue;
                },
                .OP_TO_STRING => {
                    const value = pop();
                    var result: ?*ObjString = null;

                    if (value.is_string()) {
                        // Already a string, just push it back
                        push(value);
                    } else if (value.is_int()) {
                        // Convert int to string
                        const str = std.fmt.allocPrint(std.heap.page_allocator, "{d}", .{value.as_int()}) catch "";
                        result = object_h.copyString(str.ptr, @intCast(str.len));
                        push(Value.init_obj(@ptrCast(result)));
                    } else if (value.is_double()) {
                        // Convert double to string
                        const str = std.fmt.allocPrint(std.heap.page_allocator, "{d}", .{value.as_double()}) catch "";
                        result = object_h.copyString(str.ptr, @intCast(str.len));
                        push(Value.init_obj(@ptrCast(result)));
                    } else if (value.is_bool()) {
                        // Convert bool to string
                        const str = if (value.as_bool()) "true" else "false";
                        result = object_h.copyString(str.ptr, @intCast(str.len));
                        push(Value.init_obj(@ptrCast(result)));
                    } else if (value.is_nil()) {
                        // Convert nil to string "nil"
                        result = object_h.copyString("nil".ptr, 3);
                        push(Value.init_obj(@ptrCast(result)));
                    } else if (value.is_complex()) {
                        // Convert complex to string
                        const c = value.as_complex();
                        const str = std.fmt.allocPrint(std.heap.page_allocator, "{d} + {d}i", .{ c.r, c.i }) catch "";
                        result = object_h.copyString(str.ptr, @intCast(str.len));
                        push(Value.init_obj(@ptrCast(result)));
                    } else if (value.is_obj()) {
                        if (value.as.obj != null) {
                            // Handle different object types
                            switch (value.as.obj.?.type) {
                                .OBJ_STRING => {
                                    // Already a string
                                    push(value);
                                    continue;
                                },
                                .OBJ_LINKED_LIST => {
                                    // Handle linked list as array
                                    const list = @as(*object_h.ObjLinkedList, @ptrCast(@alignCast(value.as.obj)));
                                    const str = std.fmt.allocPrint(std.heap.page_allocator, "[List with {d} items]", .{list.count}) catch "";
                                    result = object_h.copyString(str.ptr, @intCast(str.len));
                                },
                                .OBJ_FVECTOR => {
                                    const vector = @as(*fvec.FloatVector, @ptrCast(@alignCast(value.as.obj)));
                                    const str = std.fmt.allocPrint(std.heap.page_allocator, "FloatVector[{d}]", .{vector.count}) catch "";
                                    result = object_h.copyString(str.ptr, @intCast(str.len));
                                },
                                .OBJ_FUNCTION => {
                                    const function = @as(*ObjFunction, @ptrCast(@alignCast(value.as.obj)));
                                    const str = std.fmt.allocPrint(std.heap.page_allocator, "<fn {s}>", .{
                                        if (function.*.name) |name| zstr(name) else "script",
                                    }) catch "";
                                    result = object_h.copyString(str.ptr, @intCast(str.len));
                                },
                                else => {
                                    // Generic representation for other object types
                                    const str = std.fmt.allocPrint(std.heap.page_allocator, "<{s}>", .{
                                        @tagName(value.as.obj.?.type),
                                    }) catch "";
                                    result = object_h.copyString(str.ptr, @intCast(str.len));
                                },
                            }
                            push(Value.init_obj(@ptrCast(result)));
                        } else {
                            // Handle null object
                            result = object_h.copyString("null", 4);
                            push(Value.init_obj(@ptrCast(result)));
                        }
                    } else {
                        // For any other type we missed
                        const str = "unknown";
                        result = object_h.copyString(str.ptr, @intCast(str.len));
                        push(Value.init_obj(@ptrCast(result)));
                    }
                    continue;
                },
            }
        }
    }
    return .INTERPRET_RUNTIME_ERROR;
}
