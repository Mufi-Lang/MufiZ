/// MufiZ Object System Module
///
/// This module implements the object model for the MufiZ language.
/// All heap-allocated values are represented as objects with reference counting
/// and garbage collection support.
///
/// ## Object Architecture
///
/// ### Base Object Structure (Obj)
/// All objects share a common header defined in objects/obj.zig:
/// - type: ObjType enum identifying the specific object kind
/// - refCount: Reference count for memory management
/// - next: Linked list pointer for GC tracking
/// - generation: Generational GC marker (Young/Middle/Old)
/// - age: Object age for promotion between generations
/// - isMarked: Mark bit for mark-and-sweep GC
/// - cycleColor: Color for cycle detection algorithm
/// - inCycleDetection: Flag for cycle detection in progress
///
/// Total size: 24 bytes (optimized from 48 bytes via field reordering)
/// See docs/memory_layout_optimization.md for details.
///
/// ### Object Types
/// 1. **Functions and Closures**
///    - ObjFunction: Compiled function with bytecode
///    - ObjClosure: Function + captured variables (upvalues)
///    - ObjNative: Native Zig function wrapper
///    - ObjBoundMethod: Method bound to an instance
///
/// 2. **Object-Oriented Programming**
///    - ObjClass: Class definition with methods
///    - ObjInstance: Class instance with fields
///
/// 3. **Strings**
///    - ObjString: Immutable string with hash caching and SIMD operations
///    - Uses string interning for memory efficiency
///    - Includes SIMD-optimized string operations (find, equals, compare, etc.)
///
/// 4. **Collections**
///    - LinkedList: Doubly-linked list
///    - FloatVector: SIMD-optimized numeric vector
///    - Matrix: 2D numeric matrix with SIMD operations
///    - HashTable: Key-value dictionary
///
/// 5. **Special Types**
///    - ObjRange: Integer range with inclusive/exclusive semantics
///    - ObjPair: Key-value pair (used in iteration)
///    - ObjMatrixRow: View into a matrix row
///    - ObjUpvalue: Captured variable for closures
///
/// ### Memory Management
/// - **Allocation**: All objects allocated via allocateObject()
/// - **Reference Counting**: Hybrid RC + tracing GC approach
/// - **Generational GC**: Young/Middle/Old generations for efficiency
/// - **Cycle Detection**: Purple marking algorithm for reference cycles
///
/// ### Extending the Object System
/// To add a new object type:
/// 1. Create a new file in objects/ directory (e.g., objects/myobject.zig)
/// 2. Define struct with Obj as first field (for casting)
/// 3. Add variant to ObjType enum in objects/obj.zig
/// 4. Import and re-export the type in object.zig
/// 5. Add constructor function in object.zig (e.g., newMyObject)
/// 6. Update printObject() for display
/// 7. Update freeObject() in memory.zig for cleanup
/// 8. Add type checking methods to Value (is_myobject, as_myobject)
/// 9. Update GC marking in memory.zig
/// 10. Add relevant operations as bounded methods in your object file
///
/// ### File Organization
/// - All object types are defined in separate files in the objects/ directory
/// - Each object file contains its struct definition and bounded methods
/// - SIMD implementations are integrated as methods within object files
/// - Factory functions remain in object.zig for centralized object creation
///
/// ### Performance Notes
/// - Object allocation is fast due to generational GC
/// - String interning reduces memory for duplicate strings
/// - SIMD optimizations integrated in String and FloatVector as bounded methods
/// - Field reordering minimizes cache misses (24-byte headers)
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
pub const Tensor = @import("objects/tensor.zig").Tensor;
pub const ObjTensor = Tensor;
pub const ObjPair = @import("objects/pair.zig").ObjPair;
pub const ObjRange = @import("objects/range.zig").ObjRange;
pub const String = @import("objects/string.zig").String;
pub const ObjString = String;
pub const Module = @import("objects/module.zig").Module;
pub const ObjModule = Module;

// Function-related objects
pub const ObjFunction = @import("objects/function.zig").ObjFunction;
pub const ObjNative = @import("objects/native.zig").ObjNative;
pub const NativeFn = @import("objects/native.zig").NativeFn;
pub const ObjUpvalue = @import("objects/upvalue.zig").ObjUpvalue;
pub const ObjClosure = @import("objects/closure.zig").ObjClosure;
pub const ObjBoundMethod = @import("objects/bound_method.zig").ObjBoundMethod;
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

// Object allocation and factory functions
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
    function.*.source_file = null;
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

pub fn newModule(name: *ObjString) *ObjModule {
    const module: *ObjModule = @as(*ObjModule, @ptrCast(@alignCast(allocateObject(@sizeOf(ObjModule), .OBJ_MODULE))));
    const allocator = mem_utils.getAllocator();
    module.*.name = name;
    module.*.members = std.StringHashMap(Value).init(allocator);
    module.*.allocator = allocator;
    return module;
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
        return String.copyLiteral(&[_]u8{}, 0);
    }
    return String.copyLiteral(chars.?[0..length], length);
}

/// Copy string for string literals (uses arena allocation)
pub fn copyStringLiteral(chars: ?[*]const u8, length: usize) *ObjString {
    if (chars == null) {
        return String.copyLiteral(&[_]u8{}, 0);
    }
    return String.copyLiteral(chars.?[0..length], length);
}

/// Context-aware string copying
pub fn copyStringWithContext(chars: []const u8, length: usize, context: vm_allocator.StringContext) *ObjString {
    return switch (context) {
        .string_literal, .native_function_name, .constant => String.copyLiteral(chars, length),
        .dynamic_runtime, .temporary => String.copy(chars, length),
    };
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
        .OBJ_MODULE => {
            const module = @as(*ObjModule, @ptrCast(@alignCast(value.as.obj)));
            const nameStr = zstr(module.*.name);
            print("<module {s}>", .{nameStr});
        },
        .OBJ_TENSOR => {
            const tensor = @as(*Tensor, @ptrCast(@alignCast(value.as.obj)));
            tensor.print();
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
