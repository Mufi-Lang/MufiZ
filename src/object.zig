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

pub const ObjString = struct {
    obj: Obj,
    length: usize,
    chars: []u8,
    hash: u64,
};

pub const Node = struct {
    data: Value,
    prev: ?*Node,
    next: ?*Node,
};

pub const ObjLinkedList = struct {
    obj: Obj,
    head: ?*Node,
    tail: ?*Node,
    count: i32,
};

pub const ObjHashTable = struct {
    obj: Obj,
    table: Table,
};

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
pub const ObjClass = struct {
    obj: Obj,
    name: ?*ObjString,
    methods: Table,
    superclass: ?*ObjClass,
};
pub const ObjInstance = struct {
    obj: Obj,
    klass: *ObjClass,
    fields: Table,
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
    const klass: *ObjClass = @as(*ObjClass, @ptrCast(@alignCast(allocateObject(@sizeOf(ObjClass), .OBJ_CLASS))));
    klass.*.name = name;
    klass.*.superclass = @ptrFromInt(0);
    table_h.initTable(&klass.*.methods);
    return klass;
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
    const instance: *ObjInstance = @as(*ObjInstance, @ptrCast(@alignCast(allocateObject(@sizeOf(ObjInstance), .OBJ_INSTANCE))));
    instance.*.klass = klass;
    table_h.initTable(&instance.*.fields);
    return instance;
}

pub fn newNative(function: NativeFn) *ObjNative {
    const native: *ObjNative = @as(*ObjNative, @ptrCast(@alignCast(allocateObject(@sizeOf(ObjNative), .OBJ_NATIVE))));
    native.*.function = function;
    return native;
}

pub const AllocStringParams = struct {
    chars: [*]u8,
    length: usize,
    hash: u64,
};

pub fn allocateString(params: AllocStringParams) *ObjString {
    // Create a new ObjString
    const string = @as(*ObjString, @ptrCast(@alignCast(allocateObject(@sizeOf(ObjString), .OBJ_STRING))));

    // Initialize string properties
    string.length = params.length;
    string.chars = params.chars[0..@intCast(params.length)];
    string.hash = params.hash;

    // Add to VM string table to enable string interning
    push(Value{
        .type = .VAL_OBJ,
        .as = .{ .obj = @as(*Obj, @ptrCast(string)) },
    });
    _ = table_h.tableSet(&vm_h.vm.strings, string, Value.init_nil());
    _ = pop();

    return string;
}

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
    // Compute the hash of the string
    const hash = hashString(chars, length);

    // Check if the string is already interned
    const interned = table_h.tableFindString(&vm_h.vm.strings, chars, length, hash);
    if (interned != null) {
        // Free the passed-in memory as we'll use the interned version
        _ = reallocate(@as(?*anyopaque, @ptrCast(chars)), @intCast(@sizeOf(u8) *% length + 1), 0);
        return interned.?;
    }

    // String isn't interned, so create a new one with the given chars
    return allocateString(AllocStringParams{
        .chars = chars,
        .length = length,
        .hash = hash,
    });
}

pub fn copyString(chars: ?[*]const u8, length: usize) *ObjString {
    // Safety check: ensure valid inputs
    if (chars == null or length < 0) {
        // Handle invalid inputs by creating empty string directly
        const emptyChars = @as([*]u8, @ptrCast(@alignCast(reallocate(null, 0, 1))));
        emptyChars[0] = 0;
        return allocateString(AllocStringParams{
            .chars = emptyChars,
            .length = 0,
            .hash = hashString(emptyChars, 0),
        });
    }

    // Compute the hash of the string
    const hash = hashString(chars.?, length);

    // Check if the string is already interned
    const interned = table_h.tableFindString(&vm_h.vm.strings, chars.?, length, hash);
    if (interned != null) return interned.?;

    // Allocate space for the new string (including null terminator)
    const size = @as(usize, @intCast(length)) + 1;
    const heapChars = @as([*]u8, @ptrCast(@alignCast(reallocate(null, 0, size))));

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

pub fn newLinkedList() *ObjLinkedList {
    const list: *ObjLinkedList = @as(*ObjLinkedList, @ptrCast(@alignCast(allocateObject(@sizeOf(ObjLinkedList), .OBJ_LINKED_LIST))));
    list.head = null;
    list.tail = null;
    list.count = 0;
    return list;
}
pub fn cloneLinkedList(list: *ObjLinkedList) *ObjLinkedList {
    const newList: *ObjLinkedList = newLinkedList();
    var current: ?*Node = list.head;
    while (current) |node| {
        pushBack(newList, node.data);
        current = node.next;
    }
    return newList;
}

pub fn clearLinkedList(list: *ObjLinkedList) void {
    var current: ?*Node = list.head;
    while (current) |node| {
        const next: ?*Node = node.next;
        _ = reallocate(@as(?*anyopaque, @ptrCast(node)), @sizeOf(Node), 0);
        current = next;
    }
    list.head = null;
    list.tail = null;
    list.count = 0;
}

pub fn pushFront(list: *ObjLinkedList, value: Value) void {
    const node: *Node = @as(*Node, @ptrCast(@alignCast(reallocate(null, 0, @sizeOf(Node) *% 1))));
    node.data = value;
    node.prev = null;
    node.next = list.head;
    if (list.head) |head| {
        head.prev = node;
    }
    list.head = node;
    if (list.tail == null) {
        list.tail = node;
    }
    list.count += 1;
}

pub fn pushBack(list: *ObjLinkedList, value: Value) void {
    const node: *Node = @as(*Node, @ptrCast(@alignCast(reallocate(null, 0, @sizeOf(Node) *% 1))));
    node.data = value;
    node.prev = list.tail;
    node.next = null;
    if (list.tail) |tail| {
        tail.next = node;
    }
    list.tail = node;
    if (list.head == null) {
        list.head = node;
    }
    list.count += 1;
}

pub fn popFront(list: *ObjLinkedList) Value {
    const node = list.head orelse return Value.init_nil();
    const data: Value = node.data;
    list.head = node.next;
    if (list.head) |head| {
        head.prev = null;
    }
    if (list.tail == node) {
        list.tail = null;
    }
    list.count -= 1;
    _ = reallocate(@as(?*anyopaque, @ptrCast(node)), @sizeOf(Node), 0);
    return data;
}

pub fn popBack(list: *ObjLinkedList) Value {
    const node = list.tail orelse return Value.init_nil();
    const data: Value = node.data;

    list.tail = node.prev;
    if (list.tail) |tail| {
        tail.next = null;
    }
    if (list.head == node) {
        list.head = null;
    }
    list.count -= 1;
    _ = reallocate(@as(?*anyopaque, @ptrCast(node)), @sizeOf(Node), 0);
    return data;
}

pub fn equalLinkedList(a: *ObjLinkedList, b: *ObjLinkedList) bool {
    // Quick check: if counts differ, lists can't be equal
    if (a.count != b.count) {
        return false;
    }

    // Compare each element
    var currentA = a.head;
    var currentB = b.head;

    while (currentA != null and currentB != null) {
        if (!valuesEqual(currentA.?.data, currentB.?.data)) {
            return false;
        }
        currentA = currentA.?.next;
        currentB = currentB.?.next;
    }

    // If we've traversed all elements without finding differences, lists are equal
    // (We already verified counts are equal, so if one is null, both should be null)
    return true;
}

pub fn freeObjectLinkedList(list: *ObjLinkedList) void {
    var current: ?*Node = list.head;
    while (current) |node| {
        const next: ?*Node = node.next;
        _ = reallocate(@as(?*anyopaque, @ptrCast(node)), @sizeOf(Node), 0);
        current = next;
    }
}

pub fn mergeSort(list: *ObjLinkedList) void {
    // Safety check and base case
    if (list.count < 2) {
        return;
    }

    // Create temporary list structures for splitting
    var left: ObjLinkedList = undefined;
    var right: ObjLinkedList = undefined;

    // Split the list into two halves
    split(list, &left, &right);

    // Recursively sort both halves
    mergeSort(&left);
    mergeSort(&right);

    // Merge the sorted halves back together
    list.head = merge(left.head, right.head);

    // Find and update the tail pointer
    if (list.head) |head| {
        var current = head;
        while (current.next) |next| {
            current = next;
        }
        list.tail = current;
    } else {
        list.tail = null;
    }
}

pub fn searchLinkedList(list: *ObjLinkedList, value: Value) i32 {
    // Safety check
    if (list.head == null) {
        return -1;
    }

    // Search through the list
    var current = list.head;
    var index: i32 = 0;

    while (current) |node| {
        if (valuesEqual(node.data, value)) {
            return index;
        }
        current = node.next;
        index += 1;
    }

    // Value not found
    return -1;
}

pub fn reverseLinkedList(list: *ObjLinkedList) void {
    // Safety checks
    if (list.head == null) {
        return;
    }

    // Reverse the direction of all pointers
    var current = list.head;
    while (current) |node| {
        // Swap next and prev pointers
        const temp = node.next;
        node.next = node.prev;
        node.prev = temp;
        current = temp;
    }

    // Swap head and tail pointers
    const temp = list.head;
    list.head = list.tail;
    list.tail = temp;
}

pub fn mergeLinkedList(a: *ObjLinkedList, b: *ObjLinkedList) *ObjLinkedList {
    const result = newLinkedList();
    var currentA = a.head;
    var currentB = b.head;

    // Merge elements in sorted order
    while (currentA != null and currentB != null) {
        if (value_h.valueCompare(currentA.?.data, currentB.?.data) < 0) {
            pushBack(result, currentA.?.data);
            currentA = currentA.?.next;
        } else {
            pushBack(result, currentB.?.data);
            currentB = currentB.?.next;
        }
    }

    // Add remaining elements from list A
    while (currentA) |nodeA| {
        pushBack(result, nodeA.data);
        currentA = nodeA.next;
    }

    // Add remaining elements from list B
    while (currentB) |nodeB| {
        pushBack(result, nodeB.data);
        currentB = nodeB.next;
    }

    return result;
}
pub fn sliceLinkedList(list: *ObjLinkedList, start: i32, end: i32) *ObjLinkedList {
    const sliced = newLinkedList();
    var current = list.head;
    var index: i32 = 0;

    while (current) |node| {
        if (index >= start and index < end) {
            pushBack(sliced, node.data);
        }
        current = node.next;
        index += 1;
    }

    return sliced;
}
pub fn spliceLinkedList(list: *ObjLinkedList, start: i32, end: i32) *ObjLinkedList {
    const spliced = newLinkedList();
    var current = list.head;
    var index: i32 = 0;

    while (current) |node| {
        const next = node.next;

        if (index >= start and index < end) {
            // Add to spliced list
            pushBack(spliced, node.data);

            // Remove from original list
            if (node.prev) |prev| {
                prev.next = node.next;
            } else {
                list.head = node.next;
            }

            if (node.next) |next_node| {
                next_node.prev = node.prev;
            } else {
                list.tail = node.prev;
            }

            list.count -= 1;
            _ = reallocate(@as(?*anyopaque, @ptrCast(node)), @sizeOf(Node), 0);
        }

        current = next;
        index += 1;
    }

    return spliced;
}
pub fn newHashTable() *ObjHashTable {
    const htable: *ObjHashTable = @as(*ObjHashTable, @ptrCast(@alignCast(allocateObject(@sizeOf(ObjHashTable), .OBJ_HASH_TABLE))));
    table_h.initTable(&htable.*.table);
    return htable;
}
pub fn cloneHashTable(table: *ObjHashTable) *ObjHashTable {
    var newTable: *ObjHashTable = newHashTable();
    _ = &newTable;
    table_h.tableAddAll(&table.*.table, &newTable.*.table);
    return newTable;
}
pub fn clearHashTable(table: *ObjHashTable) void {
    table_h.freeTable(&table.*.table);
    table_h.initTable(&table.*.table);
}
pub fn putHashTable(table: *ObjHashTable, key: *ObjString, value: Value) bool {
    return table_h.tableSet(&table.*.table, key, value);
}
pub fn getHashTable(table: *ObjHashTable, key: *ObjString) Value {
    var value: Value = undefined;

    if (table_h.tableGet(&table.*.table, key, &value)) {
        return value;
    } else {
        return Value.init_nil();
    }
    return @import("std").mem.zeroes(Value);
}
pub fn removeHashTable(table: *ObjHashTable, key: *ObjString) bool {
    return table_h.tableDelete(&table.*.table, key);
}
pub fn freeObjectHashTable(table: *ObjHashTable) void {
    table_h.freeTable(&table.*.table);
    _ = reallocate(@as(?*anyopaque, @ptrCast(table)), @sizeOf(ObjHashTable), 0);
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
            const bound_method = @as(*ObjBoundMethod, @ptrCast(value.as.obj));
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
    }
}
pub fn isObjType(value: Value, type_: ObjType) bool {
    return (value.type == .VAL_OBJ) and (value.as.obj.?.type == type_);
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
