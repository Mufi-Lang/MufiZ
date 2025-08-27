const std = @import("std");
const print = std.debug.print;

const debug_opts = @import("debug");

const chunk_h = @import("chunk.zig");
const Chunk = chunk_h.Chunk;
const memcpy = @import("mem_utils.zig").memcpyFast;
const memory_h = @import("memory.zig");
const reallocate = memory_h.reallocate;
pub const Class = @import("objects/class.zig").Class;
pub const ObjClass = Class;
pub const FloatVector = @import("objects/fvec.zig").FloatVector;
pub const HashTable = @import("objects/hash_table.zig").HashTable;
pub const ObjHashTable = HashTable;
pub const Instance = @import("objects/instance.zig").Instance;
pub const ObjInstance = Instance;
pub const LinkedList = @import("objects/linked_list.zig").LinkedList;
pub const Node = @import("objects/linked_list.zig").Node;
pub const ObjLinkedList = LinkedList;
const __obj = @import("objects/obj.zig");
pub const Obj = __obj.Obj;
pub const ObjType = __obj.ObjType;
pub const ObjPair = @import("objects/pair.zig").ObjPair;
pub const ObjRange = @import("objects/range.zig").ObjRange;
pub const String = @import("objects/string.zig").String;
pub const ObjString = String;
const scanner_h = @import("scanner.zig");
const table_h = @import("table.zig");
const Table = table_h.Table;
const value_h = @import("value.zig");
const Value = value_h.Value;
const AS_OBJ = value_h.AS_OBJ;
const valuesEqual = value_h.valuesEqual;
const vm_h = @import("vm.zig");
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
    const mem = reallocate(null, 0, size);
    if (mem == null) {
        @panic("Failed to allocate object memory");
    }

    // Zero out the allocated memory to prevent uninitialized data issues
    @memset(@as([*]u8, @ptrCast(mem))[0..size], 0);

    const object: *Obj = @ptrCast(@alignCast(mem));
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
        const upvalue_mem = reallocate(null, 0, @intCast(@sizeOf(?*ObjUpvalue) * @as(usize, @intCast(upvalueCount))));
        if (upvalue_mem == null) {
            @panic("Failed to allocate upvalues memory");
        }

        closure.*.upvalues = @ptrCast(@alignCast(upvalue_mem));

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
    const FNV_OFFSET_BASIS: u64 = 0xcbf29ce484222325;
    const FNV_PRIME: u64 = 0x100000001b3;

    var hash = FNV_OFFSET_BASIS;
    if (length > 0) {
        for (0..@intCast(@as(u32, @intCast(length)))) |i| {
            hash ^= @intCast(key[i]);
            hash = hash *% FNV_PRIME;
        }
    }
    return hash;
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

pub fn newUpvalue(slot: [*]Value) *ObjUpvalue {
    const upvalue: *ObjUpvalue = @as(*ObjUpvalue, @ptrCast(@alignCast(allocateObject(@sizeOf(ObjUpvalue), .OBJ_UPVALUE))));
    upvalue.*.location = slot;
    upvalue.*.closed = Value.init_nil();
    upvalue.*.next = null;
    return upvalue;
}

pub fn split(list: *ObjLinkedList, left: *ObjLinkedList, right: *ObjLinkedList) void {
    // Safety checks
    if (list.head == null or list.count <= 1) {
        // Handle empty or single-element lists
        left.head = list.head;
        left.tail = list.tail;
        left.count = list.count;
        right.head = null;
        right.tail = null;
        right.count = 0;
        return;
    }

    const count = list.count;
    const middle = @divTrunc(count, 2);

    // Set up left half
    left.head = list.head;
    left.count = middle;

    // Set up right half
    right.count = count - middle;

    // Find the middle node
    var current = list.head;
    for (0..@intCast(middle - 1)) |_| {
        if (current.?.next == null) break;
        current = current.?.next;
    }

    // Split the list at the middle
    left.tail = current;
    right.head = current.?.next;

    // Break the connection between halves
    if (current.?.next) |next_node| {
        next_node.prev = null;
        current.?.next = null;
    }

    // Set right tail (use original list's tail since right half goes to the end)
    right.tail = list.tail;
}
pub fn merge(left: ?*Node, right: ?*Node) ?*Node {
    // Base cases: if one list is empty, return the other
    if (left == null) return right;
    if (right == null) return left;

    // Use separate variables to avoid modifying const parameters
    var leftPtr = left;
    var rightPtr = right;

    // Determine the head of the merged list
    var head: ?*Node = undefined;
    var current: ?*Node = undefined;

    if (value_h.valueCompare(leftPtr.?.data, rightPtr.?.data) < 0) {
        head = leftPtr;
        current = leftPtr;
        leftPtr = leftPtr.?.next;
    } else {
        head = rightPtr;
        current = rightPtr;
        rightPtr = rightPtr.?.next;
    }

    // Set head's prev to null
    head.?.prev = null;

    // Iteratively merge the remaining nodes
    while (leftPtr != null and rightPtr != null) {
        if (value_h.valueCompare(leftPtr.?.data, rightPtr.?.data) < 0) {
            current.?.next = leftPtr;
            leftPtr.?.prev = current;
            current = leftPtr;
            leftPtr = leftPtr.?.next;
        } else {
            current.?.next = rightPtr;
            rightPtr.?.prev = current;
            current = rightPtr;
            rightPtr = rightPtr.?.next;
        }
    }

    // Append remaining nodes
    if (leftPtr) |left_node| {
        current.?.next = left_node;
        left_node.prev = current;
    } else if (rightPtr) |right_node| {
        current.?.next = right_node;
        right_node.prev = current;
    }

    return head;
}

pub fn printFunction(function: *ObjFunction) void {
    if (function.*.name == null) {
        print("<script>", .{});
        return;
    }
    const nameStr = zstr(function.*.name);
    print("<fn {s}>", .{nameStr});
}

pub fn newLinkedList() *LinkedList {
    return LinkedList.init();
}
pub fn cloneLinkedList(list: *LinkedList) *LinkedList {
    return list.clone();
}

pub fn clearLinkedList(list: *LinkedList) void {
    list.clear();
}

pub fn pushFront(list: *LinkedList, value: Value) void {
    list.push_front(value);
}

pub fn pushBack(list: *LinkedList, value: Value) void {
    list.push(value);
}

pub fn popFront(list: *LinkedList) Value {
    return list.pop_front();
}

pub fn popBack(list: *LinkedList) Value {
    return list.pop();
}

pub fn equalLinkedList(a: *LinkedList, b: *LinkedList) bool {
    return a.equal(b);
}

pub fn freeObjectLinkedList(list: *LinkedList) void {
    list.clear();
}

pub fn mergeSort(list: *ObjLinkedList) void {
    list.sort();
}

pub fn searchLinkedList(list: *ObjLinkedList, value: Value) i32 {
    return list.search(value);
}

pub fn reverseLinkedList(list: *ObjLinkedList) void {
    list.reverse();
}

pub fn mergeLinkedList(a: *ObjLinkedList, b: *ObjLinkedList) *ObjLinkedList {
    const result = newLinkedList();
    // Copy all elements from a
    var currentA = a.head;
    while (currentA) |node| {
        result.push(node.data);
        currentA = node.next;
    }
    // Copy all elements from b
    var currentB = b.head;
    while (currentB) |node| {
        result.push(node.data);
        currentB = node.next;
    }
    return result;
}
pub fn sliceLinkedList(list: *ObjLinkedList, start: i32, end: i32) *ObjLinkedList {
    return list.slice(start, end);
}
pub fn spliceLinkedList(list: *ObjLinkedList, start: i32, end: i32) *ObjLinkedList {
    return list.splice(start, end);
}
pub fn newHashTable() *ObjHashTable {
    return HashTable.init();
}
pub fn cloneHashTable(table: *ObjHashTable) *ObjHashTable {
    return table.clone();
}
pub fn clearHashTable(table: *ObjHashTable) void {
    table.clear();
}
pub fn putHashTable(table: *ObjHashTable, key: *ObjString, value: Value) bool {
    return table.put(key, value);
}
pub fn getHashTable(table: *ObjHashTable, key: *ObjString) Value {
    if (table.get(key)) |value| {
        return value;
    } else {
        return Value.init_nil();
    }
}
pub fn removeHashTable(table: *ObjHashTable, key: *ObjString) bool {
    return table.remove(key);
}
pub fn freeObjectHashTable(table: *ObjHashTable) void {
    table.deinit();
}
// pub  fn mergeHashTable(a: *ObjHashTable, b: *ObjHashTable) *ObjHashTable;
// pub  fn keysHashTable(table: *ObjHashTable) *ObjArray;
// pub  fn valuesHashTable(table: *ObjHashTable) *ObjArray;

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
            // print("{", .{});
            // for (0..@intCast(vector.*.count)) |i| {
            //     print("{d:.2}", .{vector.*.data[i]});
            //     if (i != @as(usize, @intCast(vector.*.count - 1))) {
            //         print(", ", .{});
            //     }
            // }
            // print("}", .{});
        },
        .OBJ_LINKED_LIST => {
            const list = @as(*ObjLinkedList, @ptrCast(@alignCast(value.as.obj)));
            print("[", .{});
            var current = list.head;
            while (current) |node| {
                value_h.printValue(node.data);
                if (node.next != null) {
                    print(", ", .{});
                }
                current = node.next;
            }
            print("]", .{});
        },
        .OBJ_HASH_TABLE => {
            const ht = @as(*ObjHashTable, @ptrCast(@alignCast(value.as.obj)));
            print("{{", .{});
            if (ht.*.table.entries) |entries| {
                var count: i32 = 0;

                for (0..@intCast(ht.*.table.capacity)) |i| {
                    if (entries[i].key != null) {
                        if (count > 0) {
                            print(", ", .{});
                        }
                        value_h.printValue(Value{
                            .type = .VAL_OBJ,
                            .as = .{
                                .obj = @ptrCast(entries[i].key),
                            },
                        });
                        print(": ", .{});
                        value_h.printValue(entries[i].value);
                        count += 1;
                    }
                }
            }
            print("}}", .{});
        },
        .OBJ_RANGE => {
            const range = @as(*ObjRange, @ptrCast(@alignCast(value.as.obj)));
            const operator = if (range.*.inclusive) "..=" else "..";
            print("{d}{s}{d}", .{ range.*.start, operator, range.*.end });
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
pub fn hashTableToPairs(hashTable: *ObjHashTable) *ObjLinkedList {
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
