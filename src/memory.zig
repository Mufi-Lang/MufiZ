const std = @import("std");
const print = std.debug.print;

const obj_h = @import("object.zig");
const debug_opts = @import("debug");
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
const fvec = @import("objects/fvec.zig");

pub const GC_HEAP_GROW_FACTOR = 2;

pub const GCState = enum(i32) {
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
const stdlib = @cImport(@cInclude("stdlib.h"));
const exit = std.process.exit;
// const realloc = stdlib.realloc;
// const free = stdlib.free;

const mem_utils = @import("mem_utils.zig");
const realloc = mem_utils.realloc;
const free = mem_utils.free;

//todo: fix collect garbage debugging
pub fn reallocate(pointer: ?*anyopaque, oldSize: usize, newSize: usize) ?*anyopaque {
    if (newSize > oldSize) {
        if (debug_opts.stress_gc) collectGarbage();

        // Check for overflow
        if (vm_h.vm.bytesAllocated > std.math.maxInt(usize) - (newSize - oldSize)) {
            std.debug.print("Memory allocation would cause overflow.\n", .{});
            std.process.exit(1);
        }

        vm_h.vm.bytesAllocated += newSize - oldSize;
    } else if (oldSize > newSize) {
        vm_h.vm.bytesAllocated -= oldSize - newSize;
    }

    if (vm_h.vm.bytesAllocated > vm_h.vm.nextGC) {
        collectGarbage();
    }

    if (newSize == 0) {
        if (pointer != null) free(pointer);
        return null;
    }

    var result = realloc(pointer, newSize);
    if (result == null and newSize > 0) {
        std.debug.print("Memory allocation failed. Attempted to allocate {} bytes.\n", .{newSize});
        collectGarbage();
        result = realloc(pointer, newSize);
        if (result == null) {
            std.debug.print("Critical error: Memory allocation failed after garbage collection attempt.\n", .{});
            std.process.exit(1);
        }
    }

    return result;
}

pub fn markObject(object: [*c]Obj) void {
    if (object == null or object.*.isMarked) return;

    if (debug_opts.log_gc) {
        print("{p} mark ", .{@as(*anyopaque, @ptrCast(@alignCast(object)))});
        value_h.printValue(value_h.OBJ_VAL(object));
        print("\n", .{});
    }

    object.*.isMarked = true;
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

pub fn freeObject(object: [*c]Obj) void {
    if (debug_opts.log_gc) print("{p} free type {any}\n", .{ @as(*anyopaque, @ptrCast(@alignCast(object))), object.*.type });

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
            const fvector: *obj_h.FloatVector = @ptrCast(@alignCast(object));
            fvec.FloatVector.deinit(fvector);
        },
    }
}

pub fn blackenObject(object: [*c]Obj) void {
    if (debug_opts.log_gc) {
        print("{p} blacken ", .{@as(*anyopaque, @ptrCast(@alignCast(object)))});
        value_h.printValue(value_h.OBJ_VAL(@ptrCast(@alignCast(object))));
        print("\n", .{});
    }

    switch (object.*.type) {
        .OBJ_BOUND_METHOD => {
            const bound: [*c]obj_h.ObjBoundMethod = @ptrCast(@alignCast(object));
            markValue(bound.*.receiver);
            markObject(@ptrCast(@alignCast(bound.*.method)));
        },
        .OBJ_CLASS => {
            var klass: [*c]obj_h.ObjClass = @ptrCast(@alignCast(object));
            _ = &klass;
            markObject(@ptrCast(@alignCast(klass.*.name)));
            markTable(&klass.*.methods);
        },
        .OBJ_CLOSURE => {
            const closure: [*c]obj_h.ObjClosure = @ptrCast(@alignCast(object));
            markObject(@ptrCast(@alignCast(closure.*.function)));
            for (0..@intCast(closure.*.upvalueCount)) |i| {
                markObject(@ptrCast(@alignCast(closure.*.upvalues[i])));
            }
        },
        .OBJ_FUNCTION => {
            const function: [*c]obj_h.ObjFunction = @ptrCast(@alignCast(object));
            markObject(@ptrCast(@alignCast(function.*.name)));
            markArray(&function.*.chunk.constants);
        },
        .OBJ_INSTANCE => {
            const instance: [*c]obj_h.ObjInstance = @ptrCast(@alignCast(object));
            markObject(@ptrCast(@alignCast(instance.*.klass)));
            markTable(&instance.*.fields);
        },
        .OBJ_UPVALUE => {
            markValue(@as([*c]obj_h.ObjUpvalue, @ptrCast(@alignCast(object))).*.closed);
        },
        // .OBJ_ARRAY => {
        //     const array: [*c]obj_h.ObjArray = @ptrCast(@alignCast(object));
        //     for (0..@intCast(array.*.count)) |i| {
        //         markValue(array.*.values[i]);
        //     }
        // },
        .OBJ_LINKED_LIST => {
            const linkedList: [*c]obj_h.ObjLinkedList = @ptrCast(@alignCast(object));
            var current: [*c]Node = linkedList.*.head;
            while (current != null) {
                markValue(current.*.data);
                current = current.*.next;
            }
        },
        .OBJ_HASH_TABLE => {
            const hashTable: [*c]ObjHashTable = @ptrCast(@alignCast(object));
            markTable(&hashTable.*.table);
        },

        else => {},
    }
}

pub fn markArray(array: [*c]value_h.ValueArray) void {
    for (0..@intCast(array.*.count)) |i| {
        markValue(array.*.values[i]);
    }
}

pub fn incrementalGC() void {
    const INCREMENT_LIMIT: i32 = 500;

    var workDone: i32 = 0;
    while (workDone < INCREMENT_LIMIT) {
        switch (gcData.state) {
            .GC_IDLE => {
                gcData.state = .GC_MARK_ROOTS;
                gcData.rootIndex = 0;
                gcData.sweepingObject = null;
            },
            .GC_MARK_ROOTS => {
                const stackSize: usize = @intCast(@intFromPtr(vm_h.vm.stackTop) - @intFromPtr(&vm_h.vm.stack));
                const stackItemCount = stackSize / @sizeOf(Value);
                while ((gcData.rootIndex < stackItemCount) and (workDone < INCREMENT_LIMIT)) : (gcData.rootIndex +%= 1) {
                    markValue(vm_h.vm.stack[gcData.rootIndex]);
                    workDone += 1;
                }
                if (gcData.rootIndex >= stackItemCount) {
                    for (0..@intCast(vm_h.vm.frameCount)) |i| {
                        markObject(@ptrCast(@alignCast(vm_h.vm.frames[i].closure)));
                    }
                    markTable(&vm_h.vm.globals);
                    markTable(&vm_h.vm.strings);
                    markObject(@ptrCast(@alignCast(vm_h.vm.initString)));

                    var upvalue: [*c]obj_h.ObjUpvalue = vm_h.vm.openUpvalues;

                    while (upvalue != null) : (upvalue = upvalue.*.next) {
                        markObject(@ptrCast(@alignCast(upvalue)));
                    }

                    gcData.state = .GC_TRACING;
                }
            },
            .GC_TRACING => {
                while ((vm_h.vm.grayCount > 0) and (workDone < INCREMENT_LIMIT)) {
                    vm_h.vm.grayCount -= 1;
                    const object = vm_h.vm.grayStack[@intCast(vm_h.vm.grayCount)];
                    blackenObject(object);
                    workDone += 1;
                }
                if (vm_h.vm.grayCount == 0) {
                    gcData.state = .GC_SWEEPING;
                    gcData.sweepingObject = vm_h.vm.objects;
                }
            },
            .GC_SWEEPING => {
                while ((gcData.sweepingObject != null) and (workDone < INCREMENT_LIMIT)) {
                    const next: [*c]Obj = gcData.sweepingObject.*.next;
                    if (!gcData.sweepingObject.*.isMarked) {
                        freeObject(gcData.sweepingObject);
                        vm_h.vm.objects = next;
                    } else {
                        gcData.sweepingObject.*.isMarked = false;
                    }
                    gcData.sweepingObject = next;
                    workDone += 1;
                }
                if (gcData.sweepingObject == null) {
                    gcData.state = .GC_IDLE;
                    // Safe calculation of nextGC
                    if (vm_h.vm.bytesAllocated > std.math.maxInt(usize) / 2) {
                        vm_h.vm.nextGC = std.math.maxInt(usize);
                    } else {
                        vm_h.vm.nextGC = vm_h.vm.bytesAllocated * 2;
                    }
                }
            },
        }
        if (gcData.state == .GC_IDLE) {
            break;
        }
    }
}

pub inline fn FREE_ARRAY(@"type": anytype, pointer: *anyopaque, oldCount: usize) @TypeOf(reallocate(pointer, @import("std").zig.c_translation.sizeof(@"type") * oldCount, 0)) {
    return reallocate(@ptrCast(@alignCast(pointer)), @import("std").zig.c_translation.sizeof(@"type") * oldCount, 0);
}
