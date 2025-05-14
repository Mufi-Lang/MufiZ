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
    length: c_int,
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
    count: c_int,
};

pub const ObjHashTable = extern struct {
    obj: Obj,
    table: Table,
};

pub const ObjFunction = extern struct {
    obj: Obj,
    arity: c_int,
    upvalueCount: c_int,
    chunk: Chunk,
    name: [*c]ObjString,
};

pub const NativeFn = ?*const fn (c_int, [*c]Value) Value;
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
    upvalueCount: c_int,
};
pub const ObjClass = extern struct {
    obj: Obj,
    name: [*c]ObjString,
    methods: Table,
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

pub inline fn OBJ_TYPE(value: anytype) @TypeOf(AS_OBJ(value).*.type) {
    _ = &value;
    return AS_OBJ(value).*.type;
}
pub inline fn IS_BOUND_METHOD(value: anytype) @TypeOf(isObjType(value, .OBJ_BOUND_METHOD)) {
    _ = &value;
    return isObjType(value, .OBJ_BOUND_METHOD);
}
pub inline fn IS_CLASS(value: anytype) @TypeOf(isObjType(value, .OBJ_CLASS)) {
    _ = &value;
    return isObjType(value, .OBJ_CLASS);
}
pub inline fn IS_CLOSURE(value: anytype) @TypeOf(isObjType(value, .OBJ_CLOSURE)) {
    _ = &value;
    return isObjType(value, .OBJ_CLOSURE);
}
pub inline fn IS_FUNCTION(value: anytype) @TypeOf(isObjType(value, .OBJ_FUNCTION)) {
    _ = &value;
    return isObjType(value, .OBJ_FUNCTION);
}
pub inline fn IS_INSTANCE(value: anytype) @TypeOf(isObjType(value, .OBJ_INSTANCE)) {
    _ = &value;
    return isObjType(value, .OBJ_INSTANCE);
}
pub inline fn IS_NATIVE(value: anytype) @TypeOf(isObjType(value, .OBJ_NATIVE)) {
    _ = &value;
    return isObjType(value, .OBJ_NATIVE);
}
pub inline fn IS_STRING(value: anytype) @TypeOf(isObjType(value, .OBJ_STRING)) {
    _ = &value;
    return isObjType(value, .OBJ_STRING);
}

pub inline fn IS_LINKED_LIST(value: anytype) @TypeOf(isObjType(value, .OBJ_LINKED_LIST)) {
    _ = &value;
    return isObjType(value, .OBJ_LINKED_LIST);
}
pub inline fn IS_HASH_TABLE(value: anytype) @TypeOf(isObjType(value, .OBJ_HASH_TABLE)) {
    _ = &value;
    return isObjType(value, .OBJ_HASH_TABLE);
}

pub inline fn IS_FVECTOR(value: anytype) @TypeOf(isObjType(value, .OBJ_FVECTOR)) {
    _ = &value;
    return isObjType(value, .OBJ_FVECTOR);
}

pub inline fn NOT_LIST_TYPES(values: anytype, n: anytype) bool {
    return (notObjTypes(.{ values, .OBJ_LINKED_LIST, n }) and notObjTypes(.{ values, .OBJ_FVECTOR, n }));
}
pub inline fn NOT_COLLECTION_TYPES(values: anytype, n: anytype) bool {
    return notObjTypes(.{ values, .OBJ_HASH_TABLE, n }) and NOT_LIST_TYPES(values, n);
}
pub inline fn AS_BOUND_METHOD(value: anytype) [*c]ObjBoundMethod {
    _ = &value;
    return @import("std").zig.c_translation.cast([*c]ObjBoundMethod, AS_OBJ(value));
}
pub inline fn AS_CLASS(value: anytype) [*c]ObjClass {
    _ = &value;
    return @import("std").zig.c_translation.cast([*c]ObjClass, AS_OBJ(value));
}
pub inline fn AS_CLOSURE(value: anytype) [*c]ObjClosure {
    _ = &value;
    return @import("std").zig.c_translation.cast([*c]ObjClosure, AS_OBJ(value));
}
pub inline fn AS_FUNCTION(value: anytype) [*c]ObjFunction {
    _ = &value;
    return @import("std").zig.c_translation.cast([*c]ObjFunction, AS_OBJ(value));
}
pub inline fn AS_INSTANCE(value: anytype) [*c]ObjInstance {
    _ = &value;
    return @import("std").zig.c_translation.cast([*c]ObjInstance, AS_OBJ(value));
}
pub inline fn AS_NATIVE(value: anytype) @TypeOf(@import("std").zig.c_translation.cast([*c]ObjNative, AS_OBJ(value)).*.function) {
    _ = &value;
    return @import("std").zig.c_translation.cast([*c]ObjNative, AS_OBJ(value)).*.function;
}
pub inline fn AS_STRING(value: anytype) [*c]ObjString {
    _ = &value;
    return @import("std").zig.c_translation.cast([*c]ObjString, AS_OBJ(value));
}
pub inline fn AS_CSTRING(value: anytype) @TypeOf(@import("std").zig.c_translation.cast([*c]ObjString, AS_OBJ(value)).*.chars) {
    _ = &value;
    return @import("std").zig.c_translation.cast([*c]ObjString, AS_OBJ(value)).*.chars;
}

pub inline fn AS_LINKED_LIST(value: anytype) [*c]ObjLinkedList {
    _ = &value;
    return @import("std").zig.c_translation.cast([*c]ObjLinkedList, AS_OBJ(value));
}
pub inline fn AS_HASH_TABLE(value: anytype) [*c]ObjHashTable {
    _ = &value;
    return @import("std").zig.c_translation.cast([*c]ObjHashTable, AS_OBJ(value));
}

pub inline fn AS_FVECTOR(value: anytype) [*c]FloatVector {
    _ = &value;
    return @import("std").zig.c_translation.cast([*c]FloatVector, AS_OBJ(value));
}

pub fn newBoundMethod(arg_receiver: Value, arg_method: [*c]ObjClosure) [*c]ObjBoundMethod {
    var receiver = arg_receiver;
    _ = &receiver;
    var method = arg_method;
    _ = &method;
    var bound: [*c]ObjBoundMethod = @as([*c]ObjBoundMethod, @ptrCast(@alignCast(allocateObject(@sizeOf(ObjBoundMethod), .OBJ_BOUND_METHOD))));
    _ = &bound;
    bound.*.receiver = receiver;
    bound.*.method = method;
    return bound;
}
pub fn newClass(arg_name: [*c]ObjString) [*c]ObjClass {
    var name = arg_name;
    _ = &name;
    var klass: [*c]ObjClass = @as([*c]ObjClass, @ptrCast(@alignCast(allocateObject(@sizeOf(ObjClass), .OBJ_CLASS))));
    _ = &klass;
    klass.*.name = name;
    table_h.initTable(&klass.*.methods);
    return klass;
}
pub fn newClosure(arg_function: [*c]ObjFunction) [*c]ObjClosure {
    var function = arg_function;
    _ = &function;
    var upvalues: [*c][*c]ObjUpvalue = @as([*c][*c]ObjUpvalue, @ptrCast(@alignCast(reallocate(null, 0, @intCast(@sizeOf([*c]ObjUpvalue) *% function.*.upvalueCount)))));
    _ = &upvalues;
    {
        var i: c_int = 0;
        _ = &i;
        while (i < function.*.upvalueCount) : (i += 1) {
            (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk upvalues + @as(usize, @intCast(tmp)) else break :blk upvalues - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).* = null;
        }
    }
    var closure: [*c]ObjClosure = @as([*c]ObjClosure, @ptrCast(@alignCast(allocateObject(@sizeOf(ObjClosure), .OBJ_CLOSURE))));
    _ = &closure;
    closure.*.function = function;
    closure.*.upvalues = upvalues;
    closure.*.upvalueCount = function.*.upvalueCount;
    return closure;
}

pub fn newFunction() [*c]ObjFunction {
    var function: [*c]ObjFunction = @as([*c]ObjFunction, @ptrCast(@alignCast(allocateObject(@sizeOf(ObjFunction), .OBJ_FUNCTION))));
    _ = &function;
    function.*.arity = 0;
    function.*.upvalueCount = 0;
    function.*.name = null;
    chunk_h.initChunk(&function.*.chunk);
    return function;
}

pub fn newInstance(arg_klass: [*c]ObjClass) [*c]ObjInstance {
    var klass = arg_klass;
    _ = &klass;
    var instance: [*c]ObjInstance = @as([*c]ObjInstance, @ptrCast(@alignCast(allocateObject(@sizeOf(ObjInstance), .OBJ_INSTANCE))));
    _ = &instance;
    instance.*.klass = klass;
    table_h.initTable(&instance.*.fields);
    return instance;
}

pub fn newNative(arg_function: NativeFn) [*c]ObjNative {
    var function = arg_function;
    _ = &function;
    var native: [*c]ObjNative = @as([*c]ObjNative, @ptrCast(@alignCast(allocateObject(@sizeOf(ObjNative), .OBJ_NATIVE))));
    _ = &native;
    native.*.function = function;
    return native;
}

pub const AllocStringParams = extern struct {
    chars: [*c]u8 = @import("std").mem.zeroes([*c]u8),
    length: c_int,
    hash: u64 = @import("std").mem.zeroes(u64),
};

pub fn allocateString(arg_params: AllocStringParams) [*c]ObjString {
    var params = arg_params;
    _ = &params;
    var string: [*c]ObjString = @as([*c]ObjString, @ptrCast(@alignCast(allocateObject(@sizeOf(ObjString), .OBJ_STRING))));
    _ = &string;
    string.*.length = params.length;
    string.*.chars = params.chars;
    string.*.hash = params.hash;
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

pub fn hashString(key: [*c]const u8, length: c_int) u64 {
    const FNV_OFFSET_BASIS: u64 = 0xcbf29ce484222325;
    const FNV_PRIME: u64 = 0x100000001b3;

    var hash = FNV_OFFSET_BASIS;
    for (0..@intCast(length)) |i| {
        hash ^= @intCast(key[i]);
        hash = hash *% FNV_PRIME;
    }
    return hash;
}

pub fn takeString(arg_chars: [*c]u8, arg_length: c_int) [*c]ObjString {
    var chars = arg_chars;
    _ = &chars;
    var length = arg_length;
    _ = &length;
    var hash: u64 = hashString(chars, length);
    _ = &hash;
    var interned: [*c]ObjString = table_h.tableFindString(&vm_h.vm.strings, chars, length, hash);
    _ = &interned;
    if (interned != null) {
        _ = reallocate(@as(?*anyopaque, @ptrCast(chars)), @intCast(@sizeOf(u8) *% length + 1), 0);
        return interned;
    }
    return allocateString(AllocStringParams{
        .chars = chars,
        .length = length,
        .hash = hash,
    });
}

pub fn copyString(arg_chars: [*c]const u8, arg_length: c_int) [*c]ObjString {
    var chars = arg_chars;
    _ = &chars;
    var length = arg_length;
    _ = &length;
    var hash: u64 = hashString(chars, length);
    _ = &hash;
    var interned: [*c]ObjString = table_h.tableFindString(&vm_h.vm.strings, chars, length, hash);
    _ = &interned;
    if (interned != null) return interned;
    var heapChars: [*c]u8 = @as([*c]u8, @ptrCast(@alignCast(reallocate(null, 0, @intCast(@sizeOf(u8) *% length + 1)))));
    _ = &heapChars;
    _ = memcpy(@as(?*anyopaque, @ptrCast(heapChars)), @as(?*const anyopaque, @ptrCast(chars)), @intCast(length));
    (blk: {
        const tmp = length;
        if (tmp >= 0) break :blk heapChars + @as(usize, @intCast(tmp)) else break :blk heapChars - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).* = '\x00';
    return allocateString(AllocStringParams{
        .chars = heapChars,
        .length = length,
        .hash = hash,
    });
}

pub fn newUpvalue(arg_slot: [*c]Value) [*c]ObjUpvalue {
    var slot = arg_slot;
    _ = &slot;
    var upvalue: [*c]ObjUpvalue = @as([*c]ObjUpvalue, @ptrCast(@alignCast(allocateObject(@sizeOf(ObjUpvalue), .OBJ_UPVALUE))));
    _ = &upvalue;
    upvalue.*.location = slot;
    upvalue.*.closed = Value.init_nil();
    upvalue.*.next = null;
    return upvalue;
}

pub fn split(arg_list: [*c]ObjLinkedList, arg_left: [*c]ObjLinkedList, arg_right: [*c]ObjLinkedList) void {
    var list = arg_list;
    _ = &list;
    var left = arg_left;
    _ = &left;
    var right = arg_right;
    _ = &right;
    var count: c_int = list.*.count;
    _ = &count;
    var middle: c_int = @divTrunc(count, @as(c_int, 2));
    _ = &middle;
    left.*.head = list.*.head;
    left.*.count = middle;
    right.*.count = count - middle;
    var current: [*c]Node = list.*.head;
    _ = &current;
    {
        var i: c_int = 0;
        _ = &i;
        while (i < (middle - 1)) : (i += 1) {
            current = current.*.next;
        }
    }
    left.*.tail = current;
    right.*.head = current.*.next;
    current.*.next = null;
    right.*.head.*.prev = null;
}
pub fn merge(arg_left: [*c]Node, arg_right: [*c]Node) [*c]Node {
    var left = arg_left;
    _ = &left;
    var right = arg_right;
    _ = &right;
    if (left == null) return right;
    if (right == null) return left;
    if (value_h.valueCompare(left.*.data, right.*.data) < 0) {
        left.*.next = merge(left.*.next, right);
        left.*.next.*.prev = left;
        left.*.prev = null;
        return left;
    } else {
        right.*.next = merge(left, right.*.next);
        right.*.next.*.prev = right;
        right.*.prev = null;
        return right;
    }
    return null;
}

pub fn printFunction(arg_function: [*c]ObjFunction) void {
    var function = arg_function;
    _ = &function;
    if (function.*.name == null) {
        print("<script>", .{});
        return;
    }
    print("<fn {s}>", .{function.*.name.*.chars});
}

pub fn newLinkedList() [*c]ObjLinkedList {
    var list: [*c]ObjLinkedList = @as([*c]ObjLinkedList, @ptrCast(@alignCast(allocateObject(@sizeOf(ObjLinkedList), .OBJ_LINKED_LIST))));
    _ = &list;
    list.*.head = null;
    list.*.tail = null;
    list.*.count = 0;
    return list;
}
pub fn cloneLinkedList(arg_list: [*c]ObjLinkedList) [*c]ObjLinkedList {
    var list = arg_list;
    _ = &list;
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
pub fn clearLinkedList(arg_list: [*c]ObjLinkedList) void {
    var list = arg_list;
    _ = &list;
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
pub fn pushFront(arg_list: [*c]ObjLinkedList, arg_value: Value) void {
    var list = arg_list;
    _ = &list;
    var value = arg_value;
    _ = &value;
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
pub fn pushBack(arg_list: [*c]ObjLinkedList, arg_value: Value) void {
    var list = arg_list;
    _ = &list;
    var value = arg_value;
    _ = &value;
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
pub fn popFront(arg_list: [*c]ObjLinkedList) Value {
    var list = arg_list;
    _ = &list;
    if (list.*.head == null) {
        return Value.init_nil();
    }
    var node: [*c]Node = list.*.head;
    _ = &node;
    var data: Value = node.*.data;
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
pub fn popBack(arg_list: [*c]ObjLinkedList) Value {
    var list = arg_list;
    _ = &list;
    if (list.*.tail == null) {
        return Value.init_nil();
    }
    var node: [*c]Node = list.*.tail;
    _ = &node;
    var data: Value = node.*.data;
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
pub fn equalLinkedList(arg_a: [*c]ObjLinkedList, arg_b: [*c]ObjLinkedList) bool {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    if (a.*.count != b.*.count) {
        return false;
    }
    var currentA: [*c]Node = a.*.head;
    _ = &currentA;
    var currentB: [*c]Node = b.*.head;
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
pub fn freeObjectLinkedList(arg_list: [*c]ObjLinkedList) void {
    var list = arg_list;
    _ = &list;
    var current: [*c]Node = list.*.head;
    _ = &current;
    while (current != null) {
        var next: [*c]Node = current.*.next;
        _ = &next;
        _ = reallocate(@as(?*anyopaque, @ptrCast(current)), @sizeOf(Node), 0);
        current = next;
    }
    _ = reallocate(@as(?*anyopaque, @ptrCast(list)), @sizeOf(ObjLinkedList), 0);
}
pub fn mergeSort(arg_list: [*c]ObjLinkedList) void {
    var list = arg_list;
    _ = &list;
    if (list.*.count < @as(c_int, 2)) {
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
pub fn searchLinkedList(arg_list: [*c]ObjLinkedList, arg_value: Value) c_int {
    var list = arg_list;
    _ = &list;
    var value = arg_value;
    _ = &value;
    var current: [*c]Node = list.*.head;
    _ = &current;
    var index_1: c_int = 0;
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
pub fn reverseLinkedList(arg_list: [*c]ObjLinkedList) void {
    var list = arg_list;
    _ = &list;
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
pub fn mergeLinkedList(arg_a: [*c]ObjLinkedList, arg_b: [*c]ObjLinkedList) [*c]ObjLinkedList {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    var result: [*c]ObjLinkedList = newLinkedList();
    _ = &result;
    var currentA: [*c]Node = a.*.head;
    _ = &currentA;
    var currentB: [*c]Node = b.*.head;
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
pub fn sliceLinkedList(arg_list: [*c]ObjLinkedList, arg_start: c_int, arg_end: c_int) [*c]ObjLinkedList {
    var list = arg_list;
    _ = &list;
    var start = arg_start;
    _ = &start;
    var end = arg_end;
    _ = &end;
    var sliced: [*c]ObjLinkedList = newLinkedList();
    _ = &sliced;
    var current: [*c]Node = list.*.head;
    _ = &current;
    var index_1: c_int = 0;
    _ = &index_1;
    while (current != null) {
        if ((index_1 >= start) and (index_1 < end)) {
            pushBack(sliced, current.*.data);
        }
        current = current.*.next;
        index_1 += 1;
    }
    return sliced;
}
pub fn spliceLinkedList(arg_list: [*c]ObjLinkedList, arg_start: c_int, arg_end: c_int) [*c]ObjLinkedList {
    var list = arg_list;
    _ = &list;
    var start = arg_start;
    _ = &start;
    var end = arg_end;
    _ = &end;
    var spliced: [*c]ObjLinkedList = newLinkedList();
    _ = &spliced;
    var current: [*c]Node = list.*.head;
    _ = &current;
    var index_1: c_int = 0;
    _ = &index_1;
    while (current != null) {
        var next: [*c]Node = current.*.next;
        _ = &next;
        if ((index_1 >= start) and (index_1 < end)) {
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
    var htable: [*c]ObjHashTable = @as([*c]ObjHashTable, @ptrCast(@alignCast(allocateObject(@sizeOf(ObjHashTable), .OBJ_HASH_TABLE))));
    _ = &htable;
    table_h.initTable(&htable.*.table);
    return htable;
}
pub fn cloneHashTable(arg_table: [*c]ObjHashTable) [*c]ObjHashTable {
    var table = arg_table;
    _ = &table;
    var newTable: [*c]ObjHashTable = newHashTable();
    _ = &newTable;
    table_h.tableAddAll(&table.*.table, &newTable.*.table);
    return newTable;
}
pub fn clearHashTable(arg_table: [*c]ObjHashTable) void {
    var table = arg_table;
    _ = &table;
    table_h.freeTable(&table.*.table);
    table_h.initTable(&table.*.table);
}
pub fn putHashTable(arg_table: [*c]ObjHashTable, arg_key: [*c]ObjString, arg_value: Value) bool {
    var table = arg_table;
    _ = &table;
    var key = arg_key;
    _ = &key;
    var value = arg_value;
    _ = &value;
    return table_h.tableSet(&table.*.table, key, value);
}
pub fn getHashTable(arg_table: [*c]ObjHashTable, arg_key: [*c]ObjString) Value {
    var table = arg_table;
    _ = &table;
    var key = arg_key;
    _ = &key;
    var value: Value = undefined;
    _ = &value;
    if (table_h.tableGet(&table.*.table, key, &value)) {
        return value;
    } else {
        return Value.init_nil();
    }
    return @import("std").mem.zeroes(Value);
}
pub fn removeHashTable(arg_table: [*c]ObjHashTable, arg_key: [*c]ObjString) bool {
    var table = arg_table;
    _ = &table;
    var key = arg_key;
    _ = &key;
    return table_h.tableDelete(&table.*.table, key);
}
pub fn freeObjectHashTable(arg_table: [*c]ObjHashTable) void {
    var table = arg_table;
    _ = &table;
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
                var vector: [*c]FloatVector = @as([*c]FloatVector, @ptrCast(@alignCast(value.as.obj)));
                _ = &vector;
                print("[", .{});
                {
                    var i: c_int = 0;
                    _ = &i;
                    while (i < vector.*.count) : (i += 1) {
                        print("{d:.2}", .{(blk: {
                            const tmp = i;
                            if (tmp >= 0) break :blk vector.*.data + @as(usize, @intCast(tmp)) else break :blk vector.*.data - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                        }).* });
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
                var count: c_int = 0;
                _ = &count;
                {
                    var i: c_int = 0;
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
pub fn isObjType(arg_value: Value, arg_type: ObjType) bool {
    var value = arg_value;
    _ = &value;
    var @"type" = arg_type;
    _ = &@"type";
    return (value.type == .VAL_OBJ) and (value.as.obj.*.type == @"type");
}

pub const ObjTypeCheckParams = extern struct {
    values: [*c]Value,
    objType: ObjType,
    count: c_int,
};
pub fn notObjTypes(arg_params: ObjTypeCheckParams) bool {
    var params = arg_params;
    _ = &params;
    {
        var i: c_int = 0;
        _ = &i;
        while (i < params.count) : (i += 1) {
            if (isObjType((blk: {
                const tmp = i;
                if (tmp >= 0) break :blk params.values + @as(usize, @intCast(tmp)) else break :blk params.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*, params.objType)) {
                return false;
            }
        }
    }
    return false;
}
