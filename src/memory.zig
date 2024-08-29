const obj_h = @import("object.zig");
const Obj = obj_h.Obj;
const vm_h = @import("vm.zig");
const value_h = @import("value.zig");
const Value = value_h.Value;
const table_h = @import("table.zig");
const chunk_h = @import("chunk.zig");
const Node = obj_h.Node;
const ObjHashTable = obj_h.ObjHashTable;
const ObjMatrix = obj_h.ObjMatrix;
const markTable = table_h.markTable;
const freeTable = table_h.freeTable;

pub const GC_HEAP_GROW_FACTOR = @as(c_int, 2);
pub const GC_IDLE: c_int = 0;
pub const GC_MARK_ROOTS: c_int = 1;
pub const GC_TRACING: c_int = 2;
pub const GC_SWEEPING: c_int = 3;
pub const GCState = c_uint;

pub const GCData = struct {
    state: GCState = GC_IDLE,
    rootIndex: usize = 0,
    sweepingObject: [*c]Obj = null,
};

pub var gcData: GCData = .{};
const std = @import("std");
const stdio = @cImport(@cInclude("stdio.h"));
const stdlib = @cImport(@cInclude("stdlib.h"));
const exit = std.process.exit;
const fprintf = stdio.fprintf;
const realloc = stdlib.realloc;
const free = stdlib.free;

//todo: fix collect garbage debugging
pub fn reallocate(pointer: ?*anyopaque, oldSize: usize, newSize: usize) ?*anyopaque {
    vm_h.vm.bytesAllocated += newSize - oldSize;
    if (vm_h.vm.bytesAllocated > vm_h.vm.nextGC) {
        collectGarbage();
    }
    if (newSize == 0) {
        free(pointer);
        return null;
    }
    var result: ?*anyopaque = realloc(pointer, newSize);
    if (result == null and newSize > 0) {
        _ = fprintf(stdio.stderr, "Memory allocation failed. Attempted to allocate %zu bytes.\n", newSize);
        collectGarbage();
        result = realloc(pointer, newSize);
        if (result == null) {
            _ = fprintf(stdio.stderr, "Critical error: Memory allocation failed after garbage collection attempt\n");
            exit(1);
        }
    }
    return result;
}

pub fn markObject(arg_object: [*c]Obj) void {
    var object = arg_object;
    _ = &object;
    if (object == @as([*c]Obj, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) return;
    if (object.*.isMarked) return;
    object.*.isMarked = @as(c_int, 1) != 0;
    if (vm_h.vm.grayCapacity < (vm_h.vm.grayCount + @as(c_int, 1))) {
        vm_h.vm.grayCapacity = if (vm_h.vm.grayCapacity < @as(c_int, 8)) @as(c_int, 8) else vm_h.vm.grayCapacity * @as(c_int, 2);
        vm_h.vm.grayStack = @as([*c][*c]Obj, @ptrCast(@alignCast(realloc(@as(?*anyopaque, @ptrCast(vm_h.vm.grayStack)), @sizeOf([*c]Obj) *% @as(c_ulong, @bitCast(@as(c_long, vm_h.vm.grayCapacity)))))));
    }
    (blk: {
        const tmp = blk_1: {
            const ref = &vm_h.vm.grayCount;
            const tmp_2 = ref.*;
            ref.* += 1;
            break :blk_1 tmp_2;
        };
        if (tmp >= 0) break :blk vm_h.vm.grayStack + @as(usize, @intCast(tmp)) else break :blk vm_h.vm.grayStack - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).* = object;
    if (vm_h.vm.grayStack == @as([*c][*c]Obj, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) {
        exit(1);
    }
}
pub export fn markValue(arg_value: Value) void {
    var value = arg_value;
    _ = &value;
    if (value.type == .VAL_OBJ) {
        markObject(value.as.obj);
    }
}
pub export fn collectGarbage() void {
    while (gcData.state != @as(c_uint, @bitCast(GC_IDLE))) {
        incrementalGC();
    }
}
pub export fn freeObjects() void {
    var object: [*c]Obj = vm_h.vm.objects;
    _ = &object;
    while (object != @as([*c]Obj, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) {
        var next: [*c]Obj = object.*.next;
        _ = &next;
        freeObject(object);
        object = next;
    }
    free(@as(?*anyopaque, @ptrCast(vm_h.vm.grayStack)));
}

pub fn freeObject(arg_object: [*c]Obj) callconv(.C) void {
    var object = arg_object;
    _ = &object;
    while (true) {
        switch (object.*.type) {
            .OBJ_BOUND_METHOD => {
                {
                    _ = reallocate(@as(?*anyopaque, @ptrCast(object)), @sizeOf(obj_h.ObjBoundMethod), @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))));
                    break;
                }
            },
            .OBJ_CLASS => {
                {
                    var klass: [*c]obj_h.ObjClass = @as([*c]obj_h.ObjClass, @ptrCast(@alignCast(object)));
                    _ = &klass;
                    freeTable(&klass.*.methods);
                    _ = reallocate(@as(?*anyopaque, @ptrCast(object)), @sizeOf(obj_h.ObjClass), @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))));
                    break;
                }
            },
            .OBJ_CLOSURE => {
                {
                    var closure: [*c]obj_h.ObjClosure = @as([*c]obj_h.ObjClosure, @ptrCast(@alignCast(object)));
                    _ = &closure;
                    _ = reallocate(@as(?*anyopaque, @ptrCast(closure.*.upvalues)), @sizeOf([*c]obj_h.ObjUpvalue) *% @as(c_ulong, @bitCast(@as(c_long, closure.*.upvalueCount))), @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))));
                    _ = reallocate(@as(?*anyopaque, @ptrCast(object)), @sizeOf(obj_h.ObjClosure), @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))));
                    break;
                }
            },
            .OBJ_FUNCTION => {
                {
                    var function: [*c]obj_h.ObjFunction = @as([*c]obj_h.ObjFunction, @ptrCast(@alignCast(object)));
                    _ = &function;
                    chunk_h.freeChunk(&function.*.chunk);
                    _ = reallocate(@as(?*anyopaque, @ptrCast(object)), @sizeOf(obj_h.ObjFunction), @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))));
                    break;
                }
            },
            .OBJ_INSTANCE => {
                {
                    var instance: [*c]obj_h.ObjInstance = @as([*c]obj_h.ObjInstance, @ptrCast(@alignCast(object)));
                    _ = &instance;
                    freeTable(&instance.*.fields);
                    _ = reallocate(@as(?*anyopaque, @ptrCast(object)), @sizeOf(obj_h.ObjInstance), @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))));
                    break;
                }
            },
            .OBJ_NATIVE => {
                _ = reallocate(@as(?*anyopaque, @ptrCast(object)), @sizeOf(obj_h.ObjNative), @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))));
                break;
            },
            .OBJ_STRING => {
                {
                    var string: [*c]obj_h.ObjString = @as([*c]obj_h.ObjString, @ptrCast(@alignCast(object)));
                    _ = &string;
                    _ = reallocate(@as(?*anyopaque, @ptrCast(string.*.chars)), @sizeOf(u8) *% @as(c_ulong, @bitCast(@as(c_long, string.*.length + @as(c_int, 1)))), @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))));
                    _ = reallocate(@as(?*anyopaque, @ptrCast(object)), @sizeOf(obj_h.ObjString), @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))));
                    break;
                }
            },
            .OBJ_UPVALUE => {
                {
                    _ = reallocate(@as(?*anyopaque, @ptrCast(object)), @sizeOf(obj_h.ObjUpvalue), @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))));
                    break;
                }
            },
            .OBJ_ARRAY => {
                {
                    var array: [*c]obj_h.ObjArray = @as([*c]obj_h.ObjArray, @ptrCast(@alignCast(object)));
                    _ = &array;
                    obj_h.freeObjectArray(array);
                    break;
                }
            },
            .OBJ_LINKED_LIST => {
                {
                    var linkedList: [*c]obj_h.ObjLinkedList = @as([*c]obj_h.ObjLinkedList, @ptrCast(@alignCast(object)));
                    _ = &linkedList;
                    obj_h.freeObjectLinkedList(linkedList);
                    break;
                }
            },
            .OBJ_HASH_TABLE => {
                {
                    var hashTable: [*c]obj_h.ObjHashTable = @as([*c]obj_h.ObjHashTable, @ptrCast(@alignCast(object)));
                    _ = &hashTable;
                    obj_h.freeObjectHashTable(hashTable);
                    break;
                }
            },
            .OBJ_FVECTOR => {
                {
                    var fvector: [*c]obj_h.FloatVector = @as([*c]obj_h.FloatVector, @ptrCast(@alignCast(object)));
                    _ = &fvector;
                    obj_h.freeFloatVector(fvector);
                    break;
                }
            },
            else => break,
        }
        break;
    }
}

pub fn blackenObject(arg_object: [*c]Obj) callconv(.C) void {
    var object = arg_object;
    _ = &object;
    while (true) {
        switch (object.*.type) {
            .OBJ_BOUND_METHOD => {
                {
                    var bound: [*c]obj_h.ObjBoundMethod = @as([*c]obj_h.ObjBoundMethod, @ptrCast(@alignCast(object)));
                    _ = &bound;
                    markValue(bound.*.receiver);
                    markObject(@as([*c]Obj, @ptrCast(@alignCast(bound.*.method))));
                    break;
                }
            },
            .OBJ_CLASS => {
                {
                    var klass: [*c]obj_h.ObjClass = @as([*c]obj_h.ObjClass, @ptrCast(@alignCast(object)));
                    _ = &klass;
                    markObject(@as([*c]Obj, @ptrCast(@alignCast(klass.*.name))));
                    markTable(&klass.*.methods);
                    break;
                }
            },
            .OBJ_CLOSURE => {
                {
                    var closure: [*c]obj_h.ObjClosure = @as([*c]obj_h.ObjClosure, @ptrCast(@alignCast(object)));
                    _ = &closure;
                    markObject(@as([*c]Obj, @ptrCast(@alignCast(closure.*.function))));
                    {
                        var i: c_int = 0;
                        _ = &i;
                        while (i < closure.*.upvalueCount) : (i += 1) {
                            markObject(@as([*c]Obj, @ptrCast(@alignCast((blk: {
                                const tmp = i;
                                if (tmp >= 0) break :blk closure.*.upvalues + @as(usize, @intCast(tmp)) else break :blk closure.*.upvalues - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                            }).*))));
                        }
                    }
                    break;
                }
            },
            .OBJ_FUNCTION => {
                {
                    var function: [*c]obj_h.ObjFunction = @as([*c]obj_h.ObjFunction, @ptrCast(@alignCast(object)));
                    _ = &function;
                    markObject(@as([*c]Obj, @ptrCast(@alignCast(function.*.name))));
                    markArray(&function.*.chunk.constants);
                    break;
                }
            },
            .OBJ_INSTANCE => {
                {
                    var instance: [*c]obj_h.ObjInstance = @as([*c]obj_h.ObjInstance, @ptrCast(@alignCast(object)));
                    _ = &instance;
                    markObject(@as([*c]Obj, @ptrCast(@alignCast(instance.*.klass))));
                    markTable(&instance.*.fields);
                    break;
                }
            },
            .OBJ_UPVALUE => {
                markValue(@as([*c]obj_h.ObjUpvalue, @ptrCast(@alignCast(object))).*.closed);
                break;
            },
            .OBJ_ARRAY => {
                {
                    var array: [*c]obj_h.ObjArray = @as([*c]obj_h.ObjArray, @ptrCast(@alignCast(object)));
                    _ = &array;
                    {
                        var i: c_int = 0;
                        _ = &i;
                        while (i < array.*.count) : (i += 1) {
                            markValue((blk: {
                                const tmp = i;
                                if (tmp >= 0) break :blk array.*.values + @as(usize, @intCast(tmp)) else break :blk array.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                            }).*);
                        }
                    }
                    break;
                }
            },
            .OBJ_LINKED_LIST => {
                {
                    var linkedList: [*c]obj_h.ObjLinkedList = @as([*c]obj_h.ObjLinkedList, @ptrCast(@alignCast(object)));
                    _ = &linkedList;
                    var current: [*c]Node = linkedList.*.head;
                    _ = &current;
                    while (current != @as([*c]Node, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) {
                        markValue(current.*.data);
                        current = current.*.next;
                    }
                    break;
                }
            },
            .OBJ_HASH_TABLE => {
                {
                    var hashTable: [*c]ObjHashTable = @as([*c]ObjHashTable, @ptrCast(@alignCast(object)));
                    _ = &hashTable;
                    markTable(&hashTable.*.table);
                    break;
                }
            },
            .OBJ_MATRIX => {
                {
                    var matrix: [*c]ObjMatrix = @as([*c]ObjMatrix, @ptrCast(@alignCast(object)));
                    _ = &matrix;
                    {
                        var i: c_int = 0;
                        _ = &i;
                        while (i < matrix.*.len) : (i += 1) {
                            markValue((blk: {
                                const tmp = i;
                                if (tmp >= 0) break :blk matrix.*.data.*.values + @as(usize, @intCast(tmp)) else break :blk matrix.*.data.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                            }).*);
                        }
                    }
                    break;
                }
            },
            else => break,
        }
        break;
    }
}

pub fn markArray(arg_array: [*c]value_h.ValueArray) callconv(.C) void {
    var array = arg_array;
    _ = &array;
    {
        var i: c_int = 0;
        _ = &i;
        while (i < array.*.count) : (i += 1) {
            markValue((blk: {
                const tmp = i;
                if (tmp >= 0) break :blk array.*.values + @as(usize, @intCast(tmp)) else break :blk array.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*);
        }
    }
}

pub export fn incrementalGC() void {
    const INCREMENT_LIMIT: c_int = 500;
    _ = &INCREMENT_LIMIT;
    var workDone: c_int = 0;
    _ = &workDone;
    while (workDone < INCREMENT_LIMIT) {
        while (true) {
            switch (gcData.state) {
                @as(c_uint, @bitCast(@as(c_int, 0))) => {
                    gcData.state = @as(c_uint, @bitCast(GC_MARK_ROOTS));
                    gcData.rootIndex = 0;
                    gcData.sweepingObject = null;
                    break;
                },
                @as(c_uint, @bitCast(@as(c_int, 1))) => {
                    while ((gcData.rootIndex < @as(usize, @bitCast(@divExact(@as(c_long, @bitCast(@intFromPtr(vm_h.vm.stackTop) -% @intFromPtr(@as([*c]Value, @ptrCast(@alignCast(&vm_h.vm.stack)))))), @sizeOf(Value))))) and (workDone < INCREMENT_LIMIT)) : (gcData.rootIndex +%= 1) {
                        markValue(vm_h.vm.stack[gcData.rootIndex]);
                        workDone += 1;
                    }
                    if (gcData.rootIndex >= @as(usize, @bitCast(@divExact(@as(c_long, @bitCast(@intFromPtr(vm_h.vm.stackTop) -% @intFromPtr(@as([*c]Value, @ptrCast(@alignCast(&vm_h.vm.stack)))))), @sizeOf(Value))))) {
                        {
                            var i: c_int = 0;
                            _ = &i;
                            while (i < vm_h.vm.frameCount) : (i += 1) {
                                markObject(@as([*c]Obj, @ptrCast(@alignCast(vm_h.vm.frames[@as(c_uint, @intCast(i))].closure))));
                            }
                        }
                        markTable(&vm_h.vm.globals);
                        markTable(&vm_h.vm.strings);
                        markObject(@as([*c]Obj, @ptrCast(@alignCast(vm_h.vm.initString))));
                        {
                            var upvalue: [*c]obj_h.ObjUpvalue = vm_h.vm.openUpvalues;
                            _ = &upvalue;
                            while (upvalue != @as([*c]obj_h.ObjUpvalue, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) : (upvalue = upvalue.*.next) {
                                markObject(@as([*c]Obj, @ptrCast(@alignCast(upvalue))));
                            }
                        }
                        gcData.state = @as(c_uint, @bitCast(GC_TRACING));
                    }
                    break;
                },
                @as(c_uint, @bitCast(@as(c_int, 2))) => {
                    while ((vm_h.vm.grayCount > @as(c_int, 0)) and (workDone < INCREMENT_LIMIT)) {
                        var object: [*c]Obj = (blk: {
                            const tmp = blk_1: {
                                const ref = &vm_h.vm.grayCount;
                                ref.* -= 1;
                                break :blk_1 ref.*;
                            };
                            if (tmp >= 0) break :blk vm_h.vm.grayStack + @as(usize, @intCast(tmp)) else break :blk vm_h.vm.grayStack - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                        }).*;
                        _ = &object;
                        blackenObject(object);
                        workDone += 1;
                    }
                    if (vm_h.vm.grayCount == @as(c_int, 0)) {
                        gcData.state = @as(c_uint, @bitCast(GC_SWEEPING));
                        gcData.sweepingObject = vm_h.vm.objects;
                    }
                    break;
                },
                @as(c_uint, @bitCast(@as(c_int, 3))) => {
                    while ((gcData.sweepingObject != @as([*c]Obj, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) and (workDone < INCREMENT_LIMIT)) {
                        var next: [*c]Obj = gcData.sweepingObject.*.next;
                        _ = &next;
                        if (!gcData.sweepingObject.*.isMarked) {
                            freeObject(gcData.sweepingObject);
                            vm_h.vm.objects = next;
                        } else {
                            gcData.sweepingObject.*.isMarked = @as(c_int, 0) != 0;
                        }
                        gcData.sweepingObject = next;
                        workDone += 1;
                    }
                    if (gcData.sweepingObject == @as([*c]Obj, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) {
                        gcData.state = @as(c_uint, @bitCast(GC_IDLE));
                        vm_h.vm.nextGC = vm_h.vm.bytesAllocated *% 2;
                    }
                    break;
                },
                else => {},
            }
            break;
        }
        if (gcData.state == @as(c_uint, @bitCast(GC_IDLE))) {
            break;
        }
    }
}

pub inline fn FREE_ARRAY(@"type": anytype, pointer: *anyopaque, oldCount: usize) @TypeOf(reallocate(pointer, @import("std").zig.c_translation.sizeof(@"type") * oldCount, @as(c_int, 0))) {
    return reallocate(@ptrCast(@alignCast(pointer)), @import("std").zig.c_translation.sizeof(@"type") * oldCount, @as(c_int, 0));
}
