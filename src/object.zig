const std = @import("std");
const print = std.debug.print;
const debug_opts = @import("debug");
const value_h = @import("value.zig");
const table_h = @import("table.zig");
const chunk_h = @import("chunk.zig");
const memory_h = @import("memory.zig");
const vm_h = @import("vm.zig");
const reallocate = memory_h.reallocate;
const Table = table_h.Table;
const Value = value_h.Value;
const Chunk = chunk_h.Chunk;
const AS_OBJ = value_h.AS_OBJ;
// printf replaced with print from std import
const push = vm_h.push;
const pop = vm_h.pop;
const scanner_h = @import("scanner.zig");
const memcpy = @import("mem_utils.zig").memcpyFast;
const valuesEqual = value_h.valuesEqual;

// Objects
const __obj = @import("objects/obj.zig");
pub const Obj = __obj.Obj;
pub const ObjType = __obj.ObjType;
pub const FloatVector = @import("objects/fvec.zig").FloatVector;

pub const ObjString = extern struct {
    obj: Obj,
    length: i32,
    chars: [*c]u8,
    hash: u64,
};

pub const Node = extern struct {
    data: Value,
    prev: [*c]Node,
    next: [*c]Node,
};

pub const ObjLinkedList = extern struct {
    obj: Obj,
    head: [*c]Node,
    tail: [*c]Node,
    count: i32,
};

pub const ObjHashTable = extern struct {
    obj: Obj,
    table: Table,
};

pub const ObjFunction = extern struct {
    obj: Obj,
    arity: i32,
    upvalueCount: i32,
    chunk: Chunk,
    name: [*c]ObjString,
};

pub const NativeFn = ?*const fn (i32, [*c]Value) Value;
pub const ObjNative = extern struct {
    obj: Obj,
    function: NativeFn,
};

pub const ObjUpvalue = extern struct {
    obj: Obj,
    location: [*c]Value,
    closed: Value,
    next: [*c]ObjUpvalue,
};

pub const ObjClosure = extern struct {
    obj: Obj,
    function: [*c]ObjFunction,
    upvalues: [*c][*c]ObjUpvalue,
    upvalueCount: i32,
};
pub const ObjClass = extern struct {
    obj: Obj,
    name: [*c]ObjString,
    methods: Table,
    superclass: [*c]ObjClass,
};
pub const ObjInstance = extern struct {
    obj: Obj,
    klass: [*c]ObjClass,
    fields: Table,
};
pub const ObjBoundMethod = extern struct {
    obj: Obj,
    receiver: Value,
    method: [*c]ObjClosure,
};

pub fn allocateObject(size: usize, type_: ObjType) [*c]Obj {
    const object: [*c]Obj = @ptrCast(@alignCast(reallocate(null, 0, size)));
    object.*.type = type_;
    object.*.isMarked = false;
    object.*.next = vm_h.vm.objects;
    vm_h.vm.objects = object;
    // if (debug_opts.log_gc) print("{*} allocate {d} for {d}\n", .{@as([*c]ObjArray, @ptrCast(@alignCast(object))), size, @intFromEnum(type_)});
    return object;
}

// pub inline fn OBJ_TYPE(value: Value) ObjType {
//     return AS_OBJ(value).*.type;
// }

// pub inline fn NOT_LIST_TYPES(values: [*c]Value, n: i32) bool {
//     return notObjTypes(ObjTypeCheckParams{
//         .values = values,
//         .objType = .OBJ_LINKED_LIST,
//         .count = n,
//     }) and notObjTypes(ObjTypeCheckParams{
//         .values = values,
//         .objType = .OBJ_FVECTOR,
//         .count = n,
//     });
// }

// pub inline fn NOT_COLLECTION_TYPES(values: [*c]Value, n: i32) bool {
//     return notObjTypes(ObjTypeCheckParams{
//         .values = values,
//         .objType = .OBJ_HASH_TABLE,
//         .count = n,
//     }) and NOT_LIST_TYPES(values, n);
// }

pub fn newBoundMethod(receiver: Value, method: [*c]ObjClosure) [*c]ObjBoundMethod {
    const bound: [*c]ObjBoundMethod = @as([*c]ObjBoundMethod, @ptrCast(@alignCast(allocateObject(@sizeOf(ObjBoundMethod), .OBJ_BOUND_METHOD))));
    bound.*.receiver = receiver;
    bound.*.method = method;
    return bound;
}
pub fn newClass(name: [*c]ObjString) [*c]ObjClass {
    const klass: [*c]ObjClass = @as([*c]ObjClass, @ptrCast(@alignCast(allocateObject(@sizeOf(ObjClass), .OBJ_CLASS))));
    klass.*.name = name;
    klass.*.superclass = @ptrFromInt(0);
    table_h.initTable(&klass.*.methods);
    return klass;
}
pub fn newClosure(function: [*c]ObjFunction) [*c]ObjClosure {
    // Allocate memory for upvalues array
    const upvalueCount = function.*.upvalueCount;
    var upvalues = @as([*c][*c]ObjUpvalue, @ptrCast(@alignCast(reallocate(null, 0, @intCast(@sizeOf([*c]ObjUpvalue) *% upvalueCount)))));

    // Initialize upvalues to null
    var i: i32 = 0;
    while (i < upvalueCount) : (i += 1) {
        upvalues[@intCast(i)] = null;
    }

    // Create the closure object
    const closure = @as([*c]ObjClosure, @ptrCast(@alignCast(allocateObject(@sizeOf(ObjClosure), .OBJ_CLOSURE))));

    // Set closure properties
    closure.*.function = function;
    closure.*.upvalues = upvalues;
    closure.*.upvalueCount = upvalueCount;

    return closure;
}

pub fn newFunction() [*c]ObjFunction {
    const function: [*c]ObjFunction = @as([*c]ObjFunction, @ptrCast(@alignCast(allocateObject(@sizeOf(ObjFunction), .OBJ_FUNCTION))));
    function.*.arity = 0;
    function.*.upvalueCount = 0;
    function.*.name = null;
    chunk_h.initChunk(&function.*.chunk);
    return function;
}

pub fn newInstance(klass: [*c]ObjClass) [*c]ObjInstance {
    const instance: [*c]ObjInstance = @as([*c]ObjInstance, @ptrCast(@alignCast(allocateObject(@sizeOf(ObjInstance), .OBJ_INSTANCE))));
    instance.*.klass = klass;
    table_h.initTable(&instance.*.fields);
    return instance;
}

pub fn newNative(function: NativeFn) [*c]ObjNative {
    const native: [*c]ObjNative = @as([*c]ObjNative, @ptrCast(@alignCast(allocateObject(@sizeOf(ObjNative), .OBJ_NATIVE))));
    native.*.function = function;
    return native;
}

pub const AllocStringParams = extern struct {
    chars: [*c]u8,
    length: i32,
    hash: u64,
};

pub fn allocateString(params: AllocStringParams) [*c]ObjString {
    // Create a new ObjString
    const string = @as([*c]ObjString, @ptrCast(@alignCast(allocateObject(@sizeOf(ObjString), .OBJ_STRING))));

    // Initialize string properties
    string.*.length = params.length;
    string.*.chars = params.chars;
    string.*.hash = params.hash;

    // Add to VM string table to enable string interning
    push(Value{
        .type = .VAL_OBJ,
        .as = .{
            .obj = @as([*c]Obj, @ptrCast(@alignCast(string))),
        },
    });
    _ = table_h.tableSet(&vm_h.vm.strings, string, Value.init_nil());
    _ = pop();

    return string;
}

pub fn hashString(key: [*c]const u8, length: i32) u64 {
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

pub fn takeString(chars: [*c]u8, length: i32) [*c]ObjString {
    // Compute the hash of the string
    const hash = hashString(chars, length);

    // Check if the string is already interned
    const interned = table_h.tableFindString(&vm_h.vm.strings, chars, length, hash);
    if (interned != null) {
        // Free the passed-in memory as we'll use the interned version
        _ = reallocate(@as(?*anyopaque, @ptrCast(chars)), @intCast(@sizeOf(u8) *% length + 1), 0);
        return interned;
    }

    // Create a new string object with the passed-in characters
    return allocateString(AllocStringParams{
        .chars = chars,
        .length = length,
        .hash = hash,
    });
}

pub fn copyString(chars: [*c]const u8, length: i32) [*c]ObjString {
    // Safety check: ensure valid inputs
    if (chars == null or length < 0) {
        // Handle invalid inputs by creating empty string directly
        const emptyChars = @as([*c]u8, @ptrCast(@alignCast(reallocate(null, 0, 1))));
        emptyChars[0] = 0;
        return allocateString(AllocStringParams{
            .chars = emptyChars,
            .length = 0,
            .hash = hashString(emptyChars, 0),
        });
    }

    // Compute the hash of the string
    const hash = hashString(chars, length);

    // Check if the string is already interned
    const interned = table_h.tableFindString(&vm_h.vm.strings, chars, length, hash);
    if (interned != null) return interned;

    // Allocate space for the new string (including null terminator)
    const size = @as(usize, @intCast(length)) + 1;
    const heapChars = @as([*c]u8, @ptrCast(@alignCast(reallocate(null, 0, size))));

    // Copy the string contents
    if (length > 0) {
        _ = memcpy(@ptrCast(heapChars), @ptrCast(chars), @intCast(length));
    }

    // Add null terminator
    heapChars[@intCast(length)] = 0;

    // Create a new string object
    return allocateString(AllocStringParams{
        .chars = heapChars,
        .length = length,
        .hash = hash,
    });
}

pub fn newUpvalue(slot: [*c]Value) [*c]ObjUpvalue {
    const upvalue: [*c]ObjUpvalue = @as([*c]ObjUpvalue, @ptrCast(@alignCast(allocateObject(@sizeOf(ObjUpvalue), .OBJ_UPVALUE))));
    upvalue.*.location = slot;
    upvalue.*.closed = Value.init_nil();
    upvalue.*.next = null;
    return upvalue;
}

pub fn split(list: [*c]ObjLinkedList, left: [*c]ObjLinkedList, right: [*c]ObjLinkedList) void {
    // Safety checks
    if (list == null or left == null or right == null) return;
    if (list.*.head == null or list.*.count <= 1) {
        // Handle empty or single-element lists
        left.*.head = list.*.head;
        left.*.tail = list.*.tail;
        left.*.count = list.*.count;
        right.*.head = null;
        right.*.tail = null;
        right.*.count = 0;
        return;
    }

    const count = list.*.count;
    const middle = @divTrunc(count, 2);

    // Set up left half
    left.*.head = list.*.head;
    left.*.count = middle;

    // Set up right half
    right.*.count = count - middle;

    // Find the middle node
    var current = list.*.head;
    for (0..@intCast(middle - 1)) |_| {
        if (current.*.next == null) break;
        current = current.*.next;
    }

    // Split the list at the middle
    left.*.tail = current;
    right.*.head = current.*.next;

    // Break the connection between halves
    if (current.*.next != null) {
        current.*.next.*.prev = null;
        current.*.next = null;
    }

    // Set right tail (use original list's tail since right half goes to the end)
    right.*.tail = list.*.tail;
}
pub fn merge(left: [*c]Node, right: [*c]Node) [*c]Node {
    // Base cases: if one list is empty, return the other
    if (left == null) return right;
    if (right == null) return left;

    // Use separate variables to avoid modifying const parameters
    var leftPtr = left;
    var rightPtr = right;

    // Determine the head of the merged list
    var head: [*c]Node = undefined;
    var current: [*c]Node = undefined;
    
    if (value_h.valueCompare(leftPtr.*.data, rightPtr.*.data) < 0) {
        head = leftPtr;
        current = leftPtr;
        leftPtr = leftPtr.*.next;
    } else {
        head = rightPtr;
        current = rightPtr;
        rightPtr = rightPtr.*.next;
    }
    
    // Set head's prev to null
    head.*.prev = null;
    
    // Iteratively merge the remaining nodes
    while (leftPtr != null and rightPtr != null) {
        if (value_h.valueCompare(leftPtr.*.data, rightPtr.*.data) < 0) {
            current.*.next = leftPtr;
            leftPtr.*.prev = current;
            current = leftPtr;
            leftPtr = leftPtr.*.next;
        } else {
            current.*.next = rightPtr;
            rightPtr.*.prev = current;
            current = rightPtr;
            rightPtr = rightPtr.*.next;
        }
    }
    
    // Append remaining nodes
    if (leftPtr != null) {
        current.*.next = leftPtr;
        leftPtr.*.prev = current;
    } else if (rightPtr != null) {
        current.*.next = rightPtr;
        rightPtr.*.prev = current;
    }
    
    return head;
}

pub fn printFunction(function: [*c]ObjFunction) void {
    if (function.*.name == null) {
        print("<script>", .{});
        return;
    }
    print("<fn {s}>", .{function.*.name.*.chars});
}

pub fn newLinkedList() [*c]ObjLinkedList {
    const list: [*c]ObjLinkedList = @as([*c]ObjLinkedList, @ptrCast(@alignCast(allocateObject(@sizeOf(ObjLinkedList), .OBJ_LINKED_LIST))));
    list.*.head = null;
    list.*.tail = null;
    list.*.count = 0;
    return list;
}
pub fn cloneLinkedList(list: [*c]ObjLinkedList) [*c]ObjLinkedList {
    var newList: [*c]ObjLinkedList = newLinkedList();
    _ = &newList;
    var current: [*c]Node = list.*.head;
    _ = &current;
    while (current != null) {
        pushBack(newList, current.*.data);
        current = current.*.next;
    }
    return newList;
}

pub fn clearLinkedList(list: [*c]ObjLinkedList) void {
    var current: [*c]Node = list.*.head;
    _ = &current;
    while (current != null) {
        var next: [*c]Node = current.*.next;
        _ = &next;
        _ = reallocate(@as(?*anyopaque, @ptrCast(current)), @sizeOf(Node), 0);
        current = next;
    }
    list.*.head = null;
    list.*.tail = null;
    list.*.count = 0;
}

pub fn pushFront(list: [*c]ObjLinkedList, value: Value) void {
    var node: [*c]Node = @as([*c]Node, @ptrCast(@alignCast(reallocate(null, 0, @sizeOf(Node) *% 1))));
    _ = &node;
    node.*.data = value;
    node.*.prev = null;
    node.*.next = list.*.head;
    if (list.*.head != null) {
        list.*.head.*.prev = node;
    }
    list.*.head = node;
    if (list.*.tail == null) {
        list.*.tail = node;
    }
    list.*.count += 1;
}
pub fn pushBack(list: [*c]ObjLinkedList, value: Value) void {
    var node: [*c]Node = @as([*c]Node, @ptrCast(@alignCast(reallocate(null, 0, @sizeOf(Node) *% 1))));
    _ = &node;
    node.*.data = value;
    node.*.prev = list.*.tail;
    node.*.next = null;
    if (list.*.tail != null) {
        list.*.tail.*.next = node;
    }
    list.*.tail = node;
    if (list.*.head == null) {
        list.*.head = node;
    }
    list.*.count += 1;
}
pub fn popFront(list: [*c]ObjLinkedList) Value {
    if (list.*.head == null) {
        return Value.init_nil();
    }
    var node: [*c]Node = list.*.head;
    _ = &node;
    const data: Value = node.*.data;
    _ = &data;
    list.*.head = node.*.next;
    if (list.*.head != null) {
        list.*.head.*.prev = null;
    }
    if (list.*.tail == node) {
        list.*.tail = null;
    }
    list.*.count -= 1;
    _ = reallocate(@as(?*anyopaque, @ptrCast(node)), @sizeOf(Node), 0);
    return data;
}
pub fn popBack(list: [*c]ObjLinkedList) Value {
    if (list.*.tail == null) {
        return Value.init_nil();
    }
    var node: [*c]Node = list.*.tail;
    _ = &node;
    const data: Value = node.*.data;
    _ = &data;
    list.*.tail = node.*.prev;
    if (list.*.tail != null) {
        list.*.tail.*.next = null;
    }
    if (list.*.head == node) {
        list.*.head = null;
    }
    list.*.count -= 1;
    _ = reallocate(@as(?*anyopaque, @ptrCast(node)), @sizeOf(Node), 0);
    return data;
}
pub fn equalLinkedList(a: [*c]ObjLinkedList, b: [*c]ObjLinkedList) bool {
    const aArg = a;
    _ = &aArg;
    const bArg = b;
    _ = &bArg;
    if (aArg.*.count != bArg.*.count) {
        return false;
    }
    var currentA: [*c]Node = aArg.*.head;
    _ = &currentA;
    var currentB: [*c]Node = bArg.*.head;
    _ = &currentB;
    while (currentA != null) {
        if (!valuesEqual(currentA.*.data, currentB.*.data)) {
            return false;
        }
        currentA = currentA.*.next;
        currentB = currentB.*.next;
    }
    return false;
}
pub fn freeObjectLinkedList(list: [*c]ObjLinkedList) void {
    var current: [*c]Node = list.*.head;

    while (current != null) {
        var next: [*c]Node = current.*.next;
        _ = &next;
        _ = reallocate(@as(?*anyopaque, @ptrCast(current)), @sizeOf(Node), 0);
        current = next;
    }
    _ = reallocate(@as(?*anyopaque, @ptrCast(list)), @sizeOf(ObjLinkedList), 0);
}
pub fn mergeSort(list: [*c]ObjLinkedList) void {
    if (list.*.count < @as(i32, 2)) {
        return;
    }
    var left: ObjLinkedList = undefined;
    _ = &left;
    var right: ObjLinkedList = undefined;
    _ = &right;
    split(list, &left, &right);
    mergeSort(&left);
    mergeSort(&right);
    list.*.head = merge(left.head, right.head);
    var current: [*c]Node = list.*.head;
    _ = &current;
    while (current.*.next != null) {
        current = current.*.next;
    }
    list.*.tail = current;
}
pub fn searchLinkedList(list: [*c]ObjLinkedList, value: Value) i32 {
    var current: [*c]Node = list.*.head;
    _ = &current;
    var index_1: i32 = 0;
    _ = &index_1;
    while (current != null) {
        if (valuesEqual(current.*.data, value)) {
            return index_1;
        }
        current = current.*.next;
        index_1 += 1;
    }
    return -1;
}
pub fn reverseLinkedList(list: [*c]ObjLinkedList) void {
    var current: [*c]Node = list.*.head;
    _ = &current;
    while (current != null) {
        var temp: [*c]Node = current.*.next;
        _ = &temp;
        current.*.next = current.*.prev;
        current.*.prev = temp;
        current = temp;
    }
    var temp: [*c]Node = list.*.head;
    _ = &temp;
    list.*.head = list.*.tail;
    list.*.tail = temp;
}
pub fn mergeLinkedList(a: [*c]ObjLinkedList, b: [*c]ObjLinkedList) [*c]ObjLinkedList {
    const aArg = a;
    _ = &aArg;
    const bArg = b;
    _ = &bArg;
    var result: [*c]ObjLinkedList = newLinkedList();
    _ = &result;
    var currentA: [*c]Node = aArg.*.head;
    _ = &currentA;
    var currentB: [*c]Node = bArg.*.head;
    _ = &currentB;
    while ((currentA != null) and (currentB != null)) {
        if (value_h.valueCompare(currentA.*.data, currentB.*.data) < 0) {
            pushBack(result, currentA.*.data);
            currentA = currentA.*.next;
        } else {
            pushBack(result, currentB.*.data);
            currentB = currentB.*.next;
        }
    }
    while (currentA != null) {
        pushBack(result, currentA.*.data);
        currentA = currentA.*.next;
    }
    while (currentB != null) {
        pushBack(result, currentB.*.data);
        currentB = currentB.*.next;
    }
    return result;
}
pub fn sliceLinkedList(list: [*c]ObjLinkedList, start: i32, end: i32) [*c]ObjLinkedList {
    const startArg = start;
    _ = &startArg;
    const endArg = end;
    _ = &endArg;
    var sliced: [*c]ObjLinkedList = newLinkedList();
    _ = &sliced;
    var current: [*c]Node = list.*.head;
    _ = &current;
    var index_1: i32 = 0;
    _ = &index_1;
    while (current != null) {
        if ((index_1 >= startArg) and (index_1 < endArg)) {
            pushBack(sliced, current.*.data);
        }
        current = current.*.next;
        index_1 += 1;
    }
    return sliced;
}
pub fn spliceLinkedList(list: [*c]ObjLinkedList, start: i32, end: i32) [*c]ObjLinkedList {
    const startArg = start;
    _ = &startArg;
    const endArg = end;
    _ = &endArg;
    var spliced: [*c]ObjLinkedList = newLinkedList();
    _ = &spliced;
    var current: [*c]Node = list.*.head;
    _ = &current;
    var index_1: i32 = 0;
    _ = &index_1;
    while (current != null) {
        var next: [*c]Node = current.*.next;
        _ = &next;
        if ((index_1 >= startArg) and (index_1 < endArg)) {
            pushBack(spliced, current.*.data);
            if (current.*.prev != null) {
                current.*.prev.*.next = current.*.next;
            }
            if (current.*.next != null) {
                current.*.next.*.prev = current.*.prev;
            }
            _ = reallocate(@as(?*anyopaque, @ptrCast(current)), @sizeOf(Node), 0);
        }
        current = next;
        index_1 += 1;
    }
    return spliced;
}
pub fn newHashTable() [*c]ObjHashTable {
    const htable: [*c]ObjHashTable = @as([*c]ObjHashTable, @ptrCast(@alignCast(allocateObject(@sizeOf(ObjHashTable), .OBJ_HASH_TABLE))));
    table_h.initTable(&htable.*.table);
    return htable;
}
pub fn cloneHashTable(table: [*c]ObjHashTable) [*c]ObjHashTable {
    var newTable: [*c]ObjHashTable = newHashTable();
    _ = &newTable;
    table_h.tableAddAll(&table.*.table, &newTable.*.table);
    return newTable;
}
pub fn clearHashTable(table: [*c]ObjHashTable) void {
    table_h.freeTable(&table.*.table);
    table_h.initTable(&table.*.table);
}
pub fn putHashTable(table: [*c]ObjHashTable, key: [*c]ObjString, value: Value) bool {
    return table_h.tableSet(&table.*.table, key, value);
}
pub fn getHashTable(table: [*c]ObjHashTable, key: [*c]ObjString) Value {
    var value: Value = undefined;

    if (table_h.tableGet(&table.*.table, key, &value)) {
        return value;
    } else {
        return Value.init_nil();
    }
    return @import("std").mem.zeroes(Value);
}
pub fn removeHashTable(table: [*c]ObjHashTable, key: [*c]ObjString) bool {
    return table_h.tableDelete(&table.*.table, key);
}
pub fn freeObjectHashTable(table: [*c]ObjHashTable) void {
    table_h.freeTable(&table.*.table);
    _ = reallocate(@as(?*anyopaque, @ptrCast(table)), @sizeOf(ObjHashTable), 0);
}
// pub extern fn mergeHashTable(a: [*c]ObjHashTable, b: [*c]ObjHashTable) [*c]ObjHashTable;
// pub extern fn keysHashTable(table: [*c]ObjHashTable) [*c]ObjArray;
// pub extern fn valuesHashTable(table: [*c]ObjHashTable) [*c]ObjArray;

inline fn zstr(s: [*c]ObjString) []u8 {
    const len: usize = @intCast(s.*.length);
    return @ptrCast(@alignCast(s.*.chars[0..len]));
}

pub fn printObject(value: Value) void {
    const obj: [*c]Obj = @ptrCast(@alignCast(value.as.obj));
    switch (obj.*.type) {
        .OBJ_BOUND_METHOD => {
            printFunction(@as([*c]ObjBoundMethod, @ptrCast(@alignCast(value.as.obj))).*.method.*.function);
        },
        .OBJ_CLASS => {
            print("{s}", .{zstr(@as([*c]ObjClass, @ptrCast(@alignCast(value.as.obj))).*.name)});
        },
        .OBJ_CLOSURE => {
            printFunction(@as([*c]ObjClosure, @ptrCast(@alignCast(value.as.obj))).*.function);
        },
        .OBJ_FUNCTION => {
            printFunction(@ptrCast(@alignCast(value.as.obj)));
        },
        .OBJ_INSTANCE => {
            print("{s} instance", .{zstr(@as([*c]ObjInstance, @ptrCast(@alignCast(value.as.obj))).*.klass.*.name)});
        },
        .OBJ_NATIVE => {
            print("<native fn>", .{});
        },
        .OBJ_STRING => {
            print("{s}", .{zstr(@ptrCast(@alignCast(value.as.obj)))});
        },
        .OBJ_UPVALUE => {
            print("upvalue", .{});
        },

        .OBJ_FVECTOR => {
            {
                var vector: *FloatVector = @as(*FloatVector, @ptrCast(@alignCast(value.as.obj)));
                _ = &vector;
                print("[", .{});
                {
                    var i: i32 = 0;
                    _ = &i;
                    while (i < vector.*.count) : (i += 1) {
                        print("{d:.2}", .{vector.*.data[@intCast(i)]});
                        if (i != (vector.*.count - 1)) {
                            print(", ", .{});
                        }
                    }
                }
                print("]", .{});
            }
        },
        .OBJ_LINKED_LIST => {
            {
                print("[", .{});
                var current: [*c]Node = @as([*c]ObjLinkedList, @ptrCast(@alignCast(value.as.obj))).*.head;
                _ = &current;
                while (current != null) {
                    value_h.printValue(current.*.data);
                    if (current.*.next != null) {
                        print(", ", .{});
                    }
                    current = current.*.next;
                }
                print("]", .{});
            }
        },
        .OBJ_HASH_TABLE => {
            {
                var hashtable: [*c]ObjHashTable = @as([*c]ObjHashTable, @ptrCast(@alignCast(value.as.obj)));
                _ = &hashtable;
                print("{{", .{});
                var entries: [*c]table_h.Entry = hashtable.*.table.entries;
                _ = &entries;
                var count: i32 = 0;
                _ = &count;
                {
                    var i: i32 = 0;
                    _ = &i;
                    while (i < hashtable.*.table.capacity) : (i += 1) {
                        if ((blk: {
                            const tmp = i;
                            if (tmp >= 0) break :blk entries + @as(usize, @intCast(tmp)) else break :blk entries - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                        }).*.key != null) {
                            if (count > 0) {
                                print(", ", .{});
                            }
                            value_h.printValue(Value{
                                .type = .VAL_OBJ,
                                .as = .{
                                    .obj = @as([*c]Obj, @ptrCast(@alignCast((blk: {
                                        const tmp = i;
                                        if (tmp >= 0) break :blk entries + @as(usize, @intCast(tmp)) else break :blk entries - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                                    }).*.key))),
                                },
                            });
                            print(": ", .{});
                            value_h.printValue((blk: {
                                const tmp = i;
                                if (tmp >= 0) break :blk entries + @as(usize, @intCast(tmp)) else break :blk entries - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                            }).*.value);
                            count += 1;
                        }
                    }
                }
                print("}}", .{});
            }
        },
    }
}
pub fn isObjType(value: Value, type_: ObjType) bool {
    return (value.type == .VAL_OBJ) and (value.as.obj.*.type == type_);
}

pub const ObjTypeCheckParams = extern struct {
    values: [*c]Value,
    objType: ObjType,
    count: i32,
};
pub fn notObjTypes(params: ObjTypeCheckParams) bool {
    for (0..@intCast(params.count)) |i| {
        if (isObjType(params.values[i], params.objType)) return false;
    }
    return true;
}
