const obj_h = @import("object.zig");
const Obj = obj_h.Obj;
const vm_h = @import("vm.zig");
const value_h = @import("value.zig");
const Value = value_h.Value;
const vm = vm_h.vm;
const table_h = @import("table.zig");
const chunk_h = @import("chunk.zig");
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
var allocator = std.heap.c_allocator;

const realloc = allocator.realloc;
const free = allocator.free;
const stdio = @cImport(@cInclude("stdio.h"));
const exit = std.process.exit;

const fprintf = stdio.fprintf;
const stderr = stdio.stderr;

//todo: fix collect garbage debugging
pub fn reallocate(arg_pointer: ?*anyopaque, arg_oldSize: usize, arg_newSize: usize) ?*anyopaque {
    var pointer = arg_pointer;
    _ = &pointer;
    var oldSize = arg_oldSize;
    _ = &oldSize;
    var newSize = arg_newSize;
    _ = &newSize;
    vm.bytesAllocated +%= newSize -% oldSize;
    if (newSize > oldSize) {}
    if (vm.bytesAllocated > vm.nextGC) {
        collectGarbage();
    }
    if (newSize == @as(usize, @bitCast(@as(c_long, @as(c_int, 0))))) {
        free(pointer);
        return @as(?*anyopaque, @ptrFromInt(@as(c_int, 0)));
    }
    var result: ?*anyopaque = realloc(pointer, newSize);
    _ = &result;
    if ((result == @as(?*anyopaque, @ptrFromInt(@as(c_int, 0)))) and (newSize > @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))))) {
        _ = fprintf(stderr, "Memory allocation failed. Attempted to allocate %zu bytes.\n", newSize);
        collectGarbage();
        result = realloc(pointer, newSize);
        if (result == @as(?*anyopaque, @ptrFromInt(@as(c_int, 0)))) {
            _ = fprintf(stderr, "Critical error: Memory allocation failed after garbage collection attempt\n");
            exit(@as(c_int, 1));
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
    if (vm.grayCapacity < (vm.grayCount + @as(c_int, 1))) {
        vm.grayCapacity = if (vm.grayCapacity < @as(c_int, 8)) @as(c_int, 8) else vm.grayCapacity * @as(c_int, 2);
        vm.grayStack = @as([*c][*c]Obj, @ptrCast(@alignCast(realloc(@as(?*anyopaque, @ptrCast(vm.grayStack)), @sizeOf([*c]Obj) *% @as(c_ulong, @bitCast(@as(c_long, vm.grayCapacity)))))));
    }
    (blk: {
        const tmp = blk_1: {
            const ref = &vm.grayCount;
            const tmp_2 = ref.*;
            ref.* += 1;
            break :blk_1 tmp_2;
        };
        if (tmp >= 0) break :blk vm.grayStack + @as(usize, @intCast(tmp)) else break :blk vm.grayStack - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).* = object;
    if (vm.grayStack == @as([*c][*c]Obj, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) {
        exit(1);
    }
}
pub export fn markValue(arg_value: Value) void {
    var value = arg_value;
    _ = &value;
    if (value.type == @as(c_uint, @bitCast(.VAL_OBJ))) {
        markObject(value.as.obj);
    }
}
pub export fn collectGarbage() void {
    while (gcData.state != @as(c_uint, @bitCast(GC_IDLE))) {
        incrementalGC();
    }
}
pub export fn freeObjects() void {
    var object: [*c]Obj = vm.objects;
    _ = &object;
    while (object != @as([*c]Obj, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) {
        var next: [*c]Obj = object.*.next;
        _ = &next;
        freeObject(object);
        object = next;
    }
    free(@as(?*anyopaque, @ptrCast(vm.grayStack)));
}

pub fn freeObject(arg_object: [*c]Obj) callconv(.C) void {
    var object = arg_object;
    _ = &object;
    while (true) {
        switch (object.*.type) {
            @as(c_uint, @bitCast(@as(c_int, 6))) => {
                {
                    _ = reallocate(@as(?*anyopaque, @ptrCast(object)), @sizeOf(obj_h.ObjBoundMethod), @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))));
                    break;
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 7))) => {
                {
                    var klass: [*c]obj_h.ObjClass = @as([*c]obj_h.ObjClass, @ptrCast(@alignCast(object)));
                    _ = &klass;
                    freeTable(&klass.*.methods);
                    _ = reallocate(@as(?*anyopaque, @ptrCast(object)), @sizeOf(obj_h.ObjClass), @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))));
                    break;
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 0))) => {
                {
                    var closure: [*c]obj_h.ObjClosure = @as([*c]obj_h.ObjClosure, @ptrCast(@alignCast(object)));
                    _ = &closure;
                    _ = reallocate(@as(?*anyopaque, @ptrCast(closure.*.upvalues)), @sizeOf([*c]obj_h.ObjUpvalue) *% @as(c_ulong, @bitCast(@as(c_long, closure.*.upvalueCount))), @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))));
                    _ = reallocate(@as(?*anyopaque, @ptrCast(object)), @sizeOf(obj_h.ObjClosure), @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))));
                    break;
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 1))) => {
                {
                    var function: [*c]obj_h.ObjFunction = @as([*c]obj_h.ObjFunction, @ptrCast(@alignCast(object)));
                    _ = &function;
                    chunk_h.freeChunk(&function.*.chunk);
                    _ = reallocate(@as(?*anyopaque, @ptrCast(object)), @sizeOf(obj_h.ObjFunction), @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))));
                    break;
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 2))) => {
                {
                    var instance: [*c]obj_h.ObjInstance = @as([*c]obj_h.ObjInstance, @ptrCast(@alignCast(object)));
                    _ = &instance;
                    freeTable(&instance.*.fields);
                    _ = reallocate(@as(?*anyopaque, @ptrCast(object)), @sizeOf(obj_h.ObjInstance), @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))));
                    break;
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 3))) => {
                _ = reallocate(@as(?*anyopaque, @ptrCast(object)), @sizeOf(obj_h.ObjNative), @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))));
                break;
            },
            @as(c_uint, @bitCast(@as(c_int, 4))) => {
                {
                    var string: [*c]obj_h.ObjString = @as([*c]obj_h.ObjString, @ptrCast(@alignCast(object)));
                    _ = &string;
                    _ = reallocate(@as(?*anyopaque, @ptrCast(string.*.chars)), @sizeOf(u8) *% @as(c_ulong, @bitCast(@as(c_long, string.*.length + @as(c_int, 1)))), @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))));
                    _ = reallocate(@as(?*anyopaque, @ptrCast(object)), @sizeOf(obj_h.ObjString), @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))));
                    break;
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 5))) => {
                {
                    _ = reallocate(@as(?*anyopaque, @ptrCast(object)), @sizeOf(obj_h.ObjUpvalue), @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))));
                    break;
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 8))) => {
                {
                    var array: [*c]obj_h.ObjArray = @as([*c]obj_h.ObjArray, @ptrCast(@alignCast(object)));
                    _ = &array;
                    obj_h.freeObjectArray(array);
                    break;
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 9))) => {
                {
                    var linkedList: [*c]obj_h.ObjLinkedList = @as([*c]obj_h.ObjLinkedList, @ptrCast(@alignCast(object)));
                    _ = &linkedList;
                    obj_h.freeObjectLinkedList(linkedList);
                    break;
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 10))) => {
                {
                    var hashTable: [*c]obj_h.ObjHashTable = @as([*c]obj_h.ObjHashTable, @ptrCast(@alignCast(object)));
                    _ = &hashTable;
                    obj_h.freeObjectHashTable(hashTable);
                    break;
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 12))) => {
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
                    while ((gcData.rootIndex < @as(usize, @bitCast(@divExact(@as(c_long, @bitCast(@intFromPtr(vm.stackTop) -% @intFromPtr(@as([*c]Value, @ptrCast(@alignCast(&vm.stack)))))), @sizeOf(Value))))) and (workDone < INCREMENT_LIMIT)) : (gcData.rootIndex +%= 1) {
                        markValue(vm.stack[gcData.rootIndex]);
                        workDone += 1;
                    }
                    if (gcData.rootIndex >= @as(usize, @bitCast(@divExact(@as(c_long, @bitCast(@intFromPtr(vm.stackTop) -% @intFromPtr(@as([*c]Value, @ptrCast(@alignCast(&vm.stack)))))), @sizeOf(Value))))) {
                        {
                            var i: c_int = 0;
                            _ = &i;
                            while (i < vm.frameCount) : (i += 1) {
                                markObject(@as([*c]Obj, @ptrCast(@alignCast(vm.frames[@as(c_uint, @intCast(i))].closure))));
                            }
                        }
                        markTable(&vm.globals);
                        markTable(&vm.strings);
                        markObject(@as([*c]Obj, @ptrCast(@alignCast(vm.initString))));
                        {
                            var upvalue: [*c]obj_h.ObjUpvalue = vm.openUpvalues;
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
                    while ((vm.grayCount > @as(c_int, 0)) and (workDone < INCREMENT_LIMIT)) {
                        var object: [*c]Obj = (blk: {
                            const tmp = blk_1: {
                                const ref = &vm.grayCount;
                                ref.* -= 1;
                                break :blk_1 ref.*;
                            };
                            if (tmp >= 0) break :blk vm.grayStack + @as(usize, @intCast(tmp)) else break :blk vm.grayStack - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
                        }).*;
                        _ = &object;
                        obj_h.blackenObject(object);
                        workDone += 1;
                    }
                    if (vm.grayCount == @as(c_int, 0)) {
                        gcData.state = @as(c_uint, @bitCast(GC_SWEEPING));
                        gcData.sweepingObject = vm.objects;
                    }
                    break;
                },
                @as(c_uint, @bitCast(@as(c_int, 3))) => {
                    while ((gcData.sweepingObject != @as([*c]Obj, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) and (workDone < INCREMENT_LIMIT)) {
                        var next: [*c]Obj = gcData.sweepingObject.*.next;
                        _ = &next;
                        if (!gcData.sweepingObject.*.isMarked) {
                            freeObject(gcData.sweepingObject);
                            vm.objects = next;
                        } else {
                            gcData.sweepingObject.*.isMarked = @as(c_int, 0) != 0;
                        }
                        gcData.sweepingObject = next;
                        workDone += 1;
                    }
                    if (gcData.sweepingObject == @as([*c]Obj, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) {
                        gcData.state = @as(c_uint, @bitCast(GC_IDLE));
                        vm.nextGC = vm.bytesAllocated *% @as(usize, @bitCast(@as(c_long, @as(c_int, 2))));
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
