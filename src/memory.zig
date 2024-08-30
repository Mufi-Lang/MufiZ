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

pub const GC_HEAP_GROW_FACTOR = 2;

pub const GCState = enum(c_int) {
    GC_IDLE = 0,
    GC_MARK_ROOTS = 1,
    GC_TRACING = 2,
    GC_SWEEPING = 3,
};

pub const GCData = struct {
    state: GCState = .GC_IDLE,
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
    if (newSize > oldSize) {
        if (vm_h.vm.bytesAllocated > std.math.maxInt(usize) - (newSize - oldSize)) {
            // Handle overflow error
            _ = fprintf(stdio.stderr, "Memory allocation would cause overflow.\n");
            exit(1);
        }
        vm_h.vm.bytesAllocated += newSize - oldSize;
    } else {
        vm_h.vm.bytesAllocated -= oldSize - newSize;
    }

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

pub fn markObject(object: [*c]Obj) void {
    if (object == null or object.*.isMarked) return;
    object.*.isMarked = false;
    if (vm_h.vm.grayCapacity < (vm_h.vm.grayCount + 1)) {
        vm_h.vm.grayCapacity = if (vm_h.vm.grayCapacity < 8) 8 else vm_h.vm.grayCapacity * 2;
        vm_h.vm.grayStack = @ptrCast(@alignCast(realloc(@ptrCast(vm_h.vm.grayStack), @intCast(@sizeOf([*c]Obj) *% vm_h.vm.grayCapacity))));
    }
    vm_h.vm.grayCount += 1;
    vm_h.vm.grayStack[@intCast(vm_h.vm.grayCount)] = object;
    if (vm_h.vm.grayStack == null)
        exit(1);
}

pub fn markValue(value: Value) void {
    if (value.type == .VAL_OBJ)
        markObject(value.as.obj);
}

pub fn collectGarbage() void {
    while (gcData.state != .GC_IDLE) {
        incrementalGC();
    }
}

pub fn freeObjects() void {
    var object: [*c]Obj = vm_h.vm.objects;
    while (object != null) {
        const next = object.*.next;
        freeObject(object);
        object = next;
    }
    free(@ptrCast(vm_h.vm.grayStack));
}

pub fn freeObject(object: [*c]Obj) callconv(.C) void {
    switch (object.*.type) {
        .OBJ_BOUND_METHOD => {
            _ = reallocate(@ptrCast(object), @sizeOf(obj_h.ObjBoundMethod), 0);
        },
        .OBJ_CLASS => {
            const klass: [*c]obj_h.ObjClass = @ptrCast(@alignCast(object));
            freeTable(&klass.*.methods);
            _ = reallocate(@ptrCast(object), @sizeOf(obj_h.ObjClass), 0);
        },
        .OBJ_CLOSURE => {
            const closure: [*c]obj_h.ObjClosure = @ptrCast(@alignCast(object));
            _ = reallocate(@ptrCast(closure.*.upvalues), @intCast(@sizeOf([*c]obj_h.ObjUpvalue) *% closure.*.upvalueCount), 0);
            _ = reallocate(@ptrCast(object), @sizeOf(obj_h.ObjClosure), 0);
        },
        .OBJ_FUNCTION => {
            const function: [*c]obj_h.ObjFunction = @ptrCast(@alignCast(object));

            chunk_h.freeChunk(&function.*.chunk);
            _ = reallocate(@ptrCast(object), @sizeOf(obj_h.ObjFunction), 0);
        },
        .OBJ_INSTANCE => {
            const instance: [*c]obj_h.ObjInstance = @ptrCast(@alignCast(object));
            freeTable(&instance.*.fields);
            _ = reallocate(@ptrCast(object), @sizeOf(obj_h.ObjInstance), 0);
        },
        .OBJ_NATIVE => {
            _ = reallocate(@ptrCast(object), @sizeOf(obj_h.ObjNative), 0);
        },
        .OBJ_STRING => {
            const string: [*c]obj_h.ObjString = @ptrCast(@alignCast(object));
            _ = reallocate(@ptrCast(string.*.chars), @intCast(@sizeOf(u8) *% string.*.length + 1), 0);
            _ = reallocate(@ptrCast(object), @sizeOf(obj_h.ObjString), 0);
        },
        .OBJ_UPVALUE => {
            _ = reallocate(@ptrCast(object), @sizeOf(obj_h.ObjUpvalue), 0);
        },
        .OBJ_ARRAY => {
            const array: [*c]obj_h.ObjArray = @ptrCast(@alignCast(object));
            obj_h.freeObjectArray(array);
        },
        .OBJ_LINKED_LIST => {
            const linkedList: [*c]obj_h.ObjLinkedList = @ptrCast(@alignCast(object));
            _ = &linkedList;
            obj_h.freeObjectLinkedList(linkedList);
        },
        .OBJ_HASH_TABLE => {
            const hashTable: [*c]obj_h.ObjHashTable = @ptrCast(@alignCast(object));
            obj_h.freeObjectHashTable(hashTable);
        },
        .OBJ_FVECTOR => {
            const fvector: [*c]obj_h.FloatVector = @ptrCast(@alignCast(object));
            obj_h.freeFloatVector(fvector);
        },
        else => {},
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
                    var instance: [*c]obj_h.ObjInstance = @ptrCast(@alignCast(object));
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
                var array: [*c]obj_h.ObjArray = @ptrCast(@alignCast(object));
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
            },
            .OBJ_LINKED_LIST => {
                var linkedList: [*c]obj_h.ObjLinkedList = @ptrCast(@alignCast(object));
                _ = &linkedList;
                var current: [*c]Node = linkedList.*.head;
                _ = &current;
                while (current != @as([*c]Node, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(0)))))) {
                    markValue(current.*.data);
                    current = current.*.next;
                }
                break;
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
                    const matrix: [*c]ObjMatrix = @as([*c]ObjMatrix, @ptrCast(@alignCast(object)));
                    for (0..@intCast(matrix.*.len)) |i| {
                        markValue(matrix.*.data.*.values[i]);
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

pub fn incrementalGC() void {
    const INCREMENT_LIMIT: c_int = 500;

    var workDone: c_int = 0;
    while (workDone < INCREMENT_LIMIT) {
        while (true) {
            switch (gcData.state) {
                .GC_IDLE => {
                    gcData.state = .GC_MARK_ROOTS;
                    gcData.rootIndex = 0;
                    gcData.sweepingObject = null;
                    break;
                },
                .GC_MARK_ROOTS => {
                    const stackSize: usize = @intCast(@intFromPtr(vm_h.vm.stackTop) - @intFromPtr(&vm_h.vm.stack));
                    const stackItemCount = stackSize / @sizeOf(Value);
                    while ((gcData.rootIndex < stackItemCount) and (workDone < INCREMENT_LIMIT)) : (gcData.rootIndex +%= 1) {
                        markValue(vm_h.vm.stack[gcData.rootIndex]);
                        workDone += 1;
                    }
                    if (gcData.rootIndex >= stackItemCount) {
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
                            while (upvalue != null) : (upvalue = upvalue.*.next) {
                                markObject(@as([*c]Obj, @ptrCast(@alignCast(upvalue))));
                            }
                        }
                        gcData.state = .GC_TRACING;
                    }
                    break;
                },
                .GC_TRACING => {
                    while ((vm_h.vm.grayCount > 0) and (workDone < INCREMENT_LIMIT)) {
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
                    if (vm_h.vm.grayCount == 0) {
                        gcData.state = .GC_SWEEPING;
                        gcData.sweepingObject = vm_h.vm.objects;
                    }
                    break;
                },
                .GC_SWEEPING => {
                    while ((gcData.sweepingObject != null) and (workDone < INCREMENT_LIMIT)) {
                        var next: [*c]Obj = gcData.sweepingObject.*.next;
                        _ = &next;
                        if (!gcData.sweepingObject.*.isMarked) {
                            freeObject(gcData.sweepingObject);
                            vm_h.vm.objects = next;
                        } else {
                            gcData.sweepingObject.*.isMarked = false;
                        }
                        gcData.sweepingObject = next;
                        workDone += 1;
                    }
                    if (gcData.sweepingObject == @as([*c]Obj, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(0)))))) {
                        gcData.state = .GC_IDLE;
                        // Safe calculation of nextGC
                        if (vm_h.vm.bytesAllocated > std.math.maxInt(usize) / 2) {
                            vm_h.vm.nextGC = std.math.maxInt(usize);
                        } else {
                            vm_h.vm.nextGC = vm_h.vm.bytesAllocated * 2;
                        }
                    }
                    break;
                },
            }
            break;
        }
        if (gcData.state == .GC_IDLE) {
            break;
        }
    }
}

pub inline fn FREE_ARRAY(@"type": anytype, pointer: *anyopaque, oldCount: usize) @TypeOf(reallocate(pointer, @import("std").zig.c_translation.sizeof(@"type") * oldCount, 0)) {
    return reallocate(@ptrCast(@alignCast(pointer)), @import("std").zig.c_translation.sizeof(@"type") * oldCount, 0);
}
