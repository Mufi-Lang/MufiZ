const std = @import("std");
const print = std.debug.print;

const debug_opts = @import("debug");

const chunk_h = @import("chunk.zig");
const Chunk = chunk_h.Chunk;
const memcpy = @import("mem_utils.zig").memcpyFast;
const mem_utils = @import("mem_utils.zig");
const vm_allocator = @import("vm_allocator.zig");

// Import string hash utilities for consistent hashing
const string_hash = @import("string_hash.zig");
pub const Class = @import("objects/class.zig").Class;
pub const ObjClass = Class;
pub const FloatVector = @import("objects/fvec.zig").FloatVector;
pub const HashTable = @import("objects/hash_table.zig").HashTable;
pub const ObjHashTable = HashTable;
pub const Instance = @import("objects/instance.zig").Instance;
pub const ObjInstance = Instance;
pub const LinkedList = @import("objects/linked_list.zig").LinkedList;
pub const Node = @import("objects/linked_list.zig").Node;
const __obj = @import("objects/obj.zig");
pub const Obj = __obj.Obj;
pub const ObjType = __obj.ObjType;
pub const Matrix = @import("objects/matrix.zig").Matrix;
pub const ObjMatrix = Matrix;
pub const MatrixRow = @import("objects/matrix_row.zig").MatrixRow;
pub const ObjMatrixRow = MatrixRow;
pub const ObjPair = @import("objects/pair.zig").ObjPair;
pub const ObjRange = @import("objects/range.zig").ObjRange;
pub const String = @import("objects/string.zig").String;
pub const ObjString = String;
const scanner_h = @import("scanner_optimized.zig");
const table_h = @import("table.zig");
const vm_h = @import("vm.zig");
const Table = table_h.Table;
const value_h = @import("value.zig");
const Value = value_h.Value;
const AS_OBJ = value_h.AS_OBJ;
const valuesEqual = value_h.valuesEqual;

const push = vm_h.push;
const pop = vm_h.pop;

// Object Types

pub const ObjFunction = struct {
    obj: Obj,
    arity: i32,
    upvalueCount: i32,
    chunk: Chunk,
    name: ?*ObjString,
};

pub const NativeFn = ?*const fn (i32, [*]Value) Value;
pub const ObjNative = struct {
    obj: Obj,
    function: NativeFn,
};

pub const ObjUpvalue = struct {
    obj: Obj,
    location: [*]Value,
    closed: Value,
    next: ?*ObjUpvalue,
};

pub const ObjClosure = struct {
    obj: Obj,
    function: *ObjFunction,
    upvalues: ?[*]?*ObjUpvalue,
    upvalueCount: i32,
};

pub const ObjBoundMethod = struct {
    obj: Obj,
    receiver: Value,
    method: *ObjClosure,
};

pub fn allocateObject(size: usize, type_: ObjType) *Obj {
    const allocator = mem_utils.getAllocator();
    const mem_slice = mem_utils.alloc(allocator, u8, size) catch {
        @panic("Failed to allocate object memory");
    };

    // Zero out the allocated memory to prevent uninitialized data issues
    @memset(mem_slice, 0);

    const object: *Obj = @ptrCast(@alignCast(mem_slice.ptr));
    object.*.type = type_;
    object.*.isMarked = false;
    object.*.next = vm_h.vm.objects;

    // Initialize hybrid GC fields
    object.*.refCount = 1;
    object.*.generation = .Young;
    object.*.age = 0;
    object.*.inCycleDetection = false;
    object.*.cycleColor = .White;

    // Add to young generation list for generational GC
    const memory_h = @import("memory.zig");
    memory_h.gcData.youngGen.add(object);

    vm_h.vm.objects = object;
    // if (debug_opts.log_gc) print("{*} allocate {d} for {d}\n", .{@as(*ObjArray, @ptrCast(object)), size, @intFromEnum(type_)});

    return object;
}

pub fn newBoundMethod(receiver: Value, method: *ObjClosure) *ObjBoundMethod {
    const bound: *ObjBoundMethod = @as(*ObjBoundMethod, @ptrCast(@alignCast(allocateObject(@sizeOf(ObjBoundMethod), .OBJ_BOUND_METHOD))));
    bound.*.receiver = receiver;
    bound.*.method = method;
    return bound;
}
pub fn newClass(name: *ObjString) *ObjClass {
    return Class.init(name);
}
pub fn newClosure(function: *ObjFunction) *ObjClosure {
    // Allocate memory for upvalues array
    const upvalueCount = function.*.upvalueCount;

    // Create the closure object first
    const closure = @as(*ObjClosure, @ptrCast(@alignCast(allocateObject(@sizeOf(ObjClosure), .OBJ_CLOSURE))));

    // Then allocate upvalues if needed
    if (upvalueCount > 0) {
        const allocator = mem_utils.getAllocator();
        const upvalue_slice = mem_utils.alloc(allocator, ?*ObjUpvalue, @intCast(upvalueCount)) catch {
            @panic("Failed to allocate upvalues memory");
        };

        closure.*.upvalues = upvalue_slice.ptr;

        // Initialize upvalues to null
        var i: i32 = 0;
        while (i < upvalueCount) : (i += 1) {
            closure.*.upvalues.?[@intCast(i)] = null;
        }
    } else {
        closure.*.upvalues = null;
    }

    // Set closure properties
    closure.*.function = function;
    closure.*.upvalueCount = upvalueCount;
    return closure;
}

pub fn newFunction() *ObjFunction {
    const function: *ObjFunction = @as(*ObjFunction, @ptrCast(@alignCast(allocateObject(@sizeOf(ObjFunction), .OBJ_FUNCTION))));
    function.*.arity = 0;
    function.*.upvalueCount = 0;
    function.*.name = null;
    chunk_h.initChunk(&function.*.chunk);
    return function;
}

pub fn newInstance(klass: *ObjClass) *ObjInstance {
    return Instance.init(klass);
}

pub fn newNative(function: NativeFn) *ObjNative {
    const native: *ObjNative = @as(*ObjNative, @ptrCast(@alignCast(allocateObject(@sizeOf(ObjNative), .OBJ_NATIVE))));
    native.*.function = function;
    return native;
}

// String allocation is now handled internally by String bounded methods

pub fn hashString(key: [*]const u8, length: usize) u64 {
    if (length == 0) return 0;

    // Use same hash function as String.hashChars for consistency
    const slice = key[0..length];
    return string_hash.StringHash.hashFast(slice);
}

pub fn takeString(chars: [*]u8, length: usize) *ObjString {
    return String.take(chars[0..length], length);
}

pub fn copyString(chars: ?[*]const u8, length: usize) *ObjString {
    // Safety check: ensure valid inputs
    if (chars == null) {
        return String.copy(&[_]u8{}, 0);
    }

    return String.copy(chars.?[0..length], length);
}

/// Copy string for native function names (uses arena allocation)
pub fn copyNativeFunctionName(chars: ?[*]const u8, length: usize) *ObjString {
    if (chars == null) {
        return copyStringWithContext(&[_]u8{}, 0, .native_function_name);
    }
    return copyStringWithContext(chars.?[0..length], length, .native_function_name);
}

/// Copy string for string literals (uses arena allocation)
pub fn copyStringLiteral(chars: ?[*]const u8, length: usize) *ObjString {
    if (chars == null) {
        return copyStringWithContext(&[_]u8{}, 0, .string_literal);
    }
    return copyStringWithContext(chars.?[0..length], length, .string_literal);
}

/// Context-aware string copying
pub fn copyStringWithContext(chars: []const u8, length: usize, context: vm_allocator.StringContext) *ObjString {
    // For now, use the existing String.copy method
    // TODO: Enhance this to use arena allocation for appropriate contexts
    _ = context; // Suppress unused parameter warning for now
    return String.copy(chars, length);
}

pub fn newUpvalue(slot: [*]Value) *ObjUpvalue {
    const upvalue: *ObjUpvalue = @as(*ObjUpvalue, @ptrCast(@alignCast(allocateObject(@sizeOf(ObjUpvalue), .OBJ_UPVALUE))));
    upvalue.*.location = slot;
    upvalue.*.closed = Value.init_nil();
    upvalue.*.next = null;
    return upvalue;
}

pub fn printFunction(function: *ObjFunction) void {
    if (function.*.name == null) {
        print("<script>", .{});
        return;
    }
    const nameStr = zstr(function.*.name);
    print("<fn {s}>", .{nameStr});
}

inline fn zstr(s: ?*ObjString) []const u8 {
    if (s) |str| {
        return str.chars;
    } else {
        return "null";
    }
}

pub fn printObject(value: Value) void {
    const obj: *Obj = @ptrCast(value.as.obj);
    switch (obj.*.type) {
        .OBJ_BOUND_METHOD => {
            const bound_method = @as(*ObjBoundMethod, @ptrCast(@alignCast(value.as.obj)));
            printFunction(bound_method.*.method.*.function);
        },
        .OBJ_CLASS => {
            const class = @as(*ObjClass, @ptrCast(value.as.obj));
            const nameStr = zstr(class.*.name);
            print("{s}", .{nameStr});
        },
        .OBJ_CLOSURE => {
            const closure = @as(*ObjClosure, @ptrCast(@alignCast(value.as.obj)));
            printFunction(closure.*.function);
        },
        .OBJ_FUNCTION => {
            printFunction(@ptrCast(@alignCast(value.as.obj)));
        },
        .OBJ_INSTANCE => {
            const instance = @as(*ObjInstance, @ptrCast(@alignCast(value.as.obj)));
            const nameStr = zstr(instance.*.klass.*.name);
            print("{s} instance", .{nameStr});
        },
        .OBJ_NATIVE => {
            print("<native fn>", .{});
        },
        .OBJ_STRING => {
            const str = zstr(@ptrCast(@alignCast(value.as.obj)));
            print("{s}", .{str});
        },
        .OBJ_UPVALUE => {
            print("upvalue", .{});
        },

        .OBJ_FVECTOR => {
            const vector = @as(*FloatVector, @ptrCast(@alignCast(value.as.obj)));
            vector.print();
        },
        .OBJ_LINKED_LIST => {
            const list = @as(*LinkedList, @ptrCast(@alignCast(value.as.obj)));
            LinkedList.print(list);
        },
        .OBJ_HASH_TABLE => {
            const ht = @as(*ObjHashTable, @ptrCast(@alignCast(value.as.obj)));
            ObjHashTable.print(ht);
        },
        .OBJ_RANGE => {
            const range = @as(*ObjRange, @ptrCast(@alignCast(value.as.obj)));
            const operator = if (range.*.inclusive) "..=" else "..";
            print("{d}{s}{d}", .{ range.*.start, operator, range.*.end });
        },
        .OBJ_MATRIX => {
            const matrix = @as(*Matrix, @ptrCast(@alignCast(value.as.obj)));
            matrix.print();
        },
        .OBJ_MATRIX_ROW => {
            const matrix_row = @as(*MatrixRow, @ptrCast(@alignCast(value.as.obj)));
            print("MatrixRow[{}] from {}x{} matrix", .{ matrix_row.row_index + 1, matrix_row.matrix.rows, matrix_row.matrix.cols });
        },
        .OBJ_PAIR => {
            const pair = @as(*ObjPair, @ptrCast(@alignCast(value.as.obj)));
            print("(", .{});
            value_h.printValue(pair.key);
            print(", ", .{});
            value_h.printValue(pair.value);
            print(")", .{});
        },
    }
}
pub fn isObjType(value: Value, type_: ObjType) bool {
    return (value.type == .VAL_OBJ) and (value.as.obj.?.type == type_);
}

// Convert a hash table to a linked list of pairs for iteration
pub fn hashTableToPairs(hashTable: *ObjHashTable) *LinkedList {
    return hashTable.toPairs();
}

// Get the number of active entries in a hash table
pub fn hashTableLength(hashTable: *ObjHashTable) i32 {
    return @intCast(hashTable.len());
}

pub const ObjTypeCheckParams = struct {
    values: [*]Value,
    objType: ObjType,
    count: i32,
};
pub fn notObjTypes(params: ObjTypeCheckParams) bool {
    for (0..@intCast(params.count)) |i| {
        if (isObjType(params.values[i], params.objType)) return false;
    }
    return true;
}
