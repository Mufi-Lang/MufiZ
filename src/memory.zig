const std = @import("std");
const vm_h = @cImport(@cInclude("vm.h"));
const value_h = @cImport(@cInclude("value.h"));
const object_h = @cImport(@cInclude("object.h"));
const table_h = @cImport(@cInclude("table.h"));
const chunk_h = @cImport(@cInclude("chunk.h"));
const compiler_h = @cImport(@cInclude("compiler.h"));
const vm = struct {
    var v: vm_h.VM = vm_h.vm;
};

const Value = value_h.Value;
const ValueArray = value_h.ValueArray;
const VAL_INT = value_h.VAL_INT;
const VAL_BOOL = value_h.VAL_BOOL;
const VAL_DOUBLE = value_h.VAL_DOUBLE;
const VAL_NIL = value_h.VAL_NIL;
const VAL_OBJ = value_h.VAL_OBJ;
const Obj = object_h.Obj;
const alloc = std.heap.c_allocator;
const exit = std.os.exit;
const ObjClass = object_h.ObjClass;
const ObjClosure = object_h.ObjClosure;
const ObjFunction = object_h.ObjFunction;
const ObjInstance = object_h.ObjInstance;
const ObjBoundMethod = object_h.ObjBoundMethod;
const ObjUpvalue = object_h.ObjUpvalue;
const ObjNative = object_h.ObjNative;
const ObjString = object_h.ObjString;
const freeChunk = chunk_h.freeChunk;

pub export fn markArray(arg_array: [*c]ValueArray) callconv(.C) void {
    var array = arg_array;
    {
        var i: c_int = 0;
        while (i < array.*.count) : (i += 1) {
            markValue((blk: {
                const tmp = i;
                if (tmp >= 0) break :blk array.*.values + @as(usize, @intCast(tmp)) else break :blk array.*.values - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*);
        }
    }
}

pub export fn markObject(arg_object: [*c]Obj) void {
    var object = arg_object;
    if (object == @as([*c]Obj, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) return;
    if (object.*.isMarked) return;
    object.*.isMarked = @as(c_int, 1) != 0;
    if (vm.v.grayCapacity < (vm.v.grayCount + @as(c_int, 1))) {
        vm.v.grayCapacity = if (vm.v.grayCapacity < @as(c_int, 8)) @as(c_int, 8) else vm.v.grayCapacity * @as(c_int, 2);
        vm.v.grayStack = @as([*c][*c]Obj, @ptrCast(@alignCast(alloc.realloc(@as(?*anyopaque, @ptrCast(vm.v.grayStack)), @sizeOf([*c]Obj) *% @as(c_ulong, @bitCast(@as(c_long, vm.v.grayCapacity)))))));
    }
    (blk: {
        const tmp = blk_1: {
            const ref = &vm.v.grayCount;
            const tmp_2 = ref.*;
            ref.* += 1;
            break :blk_1 tmp_2;
        };
        if (tmp >= 0) break :blk vm.v.grayStack + @as(usize, @intCast(tmp)) else break :blk vm.v.grayStack - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).* = object;
    if (vm.v.grayStack == @as([*c][*c]Obj, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) {
        exit(1);
    }
}
pub export fn markValue(arg_value: Value) void {
    var value = arg_value;
    if (value.type == @as(c_uint, @bitCast(VAL_OBJ))) {
        markObject(@ptrCast(@alignCast(value.as.obj)));
    }
}
pub export fn collectGarbage() void {
    markRoots();
    traceReferences();
    table_h.tableRemoveWhite(&vm.v.strings);
    sweep();
    vm.v.nextGC = vm.v.bytesAllocated *% @as(usize, @bitCast(@as(c_long, @as(c_int, 2))));
}
pub export fn freeObjects() void {
    var object: [*c]Obj = vm.v.objects;
    while (object != @as([*c]Obj, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) {
        var next: [*c]Obj = object.*.next;
        freeObject(object);
        object = next;
    }
    alloc.free(@as(?*anyopaque, @ptrCast(vm.v.grayStack)));
}

pub fn blackenObject(arg_object: [*c]Obj) callconv(.C) void {
    var object = arg_object;
    while (true) {
        switch (object.*.type) {
            @as(c_uint, @bitCast(@as(c_int, 6))) => {
                {
                    var bound: [*c]object_h.ObjBoundMethod = @as([*c]object_h.ObjBoundMethod, @ptrCast(@alignCast(object)));
                    markValue(bound.*.receiver);
                    markObject(@as([*c]Obj, @ptrCast(@alignCast(bound.*.method))));
                    break;
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 7))) => {
                {
                    var klass: [*c]ObjClass = @as([*c]ObjClass, @ptrCast(@alignCast(object)));
                    markObject(@as([*c]Obj, @ptrCast(@alignCast(klass.*.name))));
                    table_h.markTable(&klass.*.methods);
                    break;
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 0))) => {
                {
                    var closure: [*c]ObjClosure = @as([*c]ObjClosure, @ptrCast(@alignCast(object)));
                    markObject(@as([*c]Obj, @ptrCast(@alignCast(closure.*.function))));
                    {
                        var i: c_int = 0;
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
            @as(c_uint, @bitCast(@as(c_int, 1))) => {
                {
                    var function: [*c]ObjFunction = @as([*c]ObjFunction, @ptrCast(@alignCast(object)));
                    markObject(@as([*c]Obj, @ptrCast(@alignCast(function.*.name))));
                    markArray(&function.*.chunk.constants);
                    break;
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 2))) => {
                {
                    var instance: [*c]ObjInstance = @as([*c]ObjInstance, @ptrCast(@alignCast(object)));
                    markObject(@as([*c]Obj, @ptrCast(@alignCast(instance.*.klass))));
                    table_h.markTable(&instance.*.fields);
                    break;
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 5))) => {
                markValue(@as([*c]ObjUpvalue, @ptrCast(@alignCast(object))).*.closed);
                break;
            },
            @as(c_uint, @bitCast(@as(c_int, 3))), @as(c_uint, @bitCast(@as(c_int, 4))) => break,
            else => {},
        }
        break;
    }
}
pub fn freeObject(arg_object: [*c]Obj) callconv(.C) void {
    var object = arg_object;
    while (true) {
        switch (object.*.type) {
            @as(c_uint, @bitCast(@as(c_int, 6))) => {
                {
                    _ = reallocate(@as(?*anyopaque, @ptrCast(object)), @sizeOf(ObjBoundMethod), @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))));
                    break;
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 7))) => {
                {
                    var klass: [*c]ObjClass = @as([*c]ObjClass, @ptrCast(@alignCast(object)));
                    table_h.freeTable(&klass.*.methods);
                    _ = reallocate(@as(?*anyopaque, @ptrCast(object)), @sizeOf(ObjClass), @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))));
                    break;
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 0))) => {
                {
                    var closure: [*c]ObjClosure = @as([*c]ObjClosure, @ptrCast(@alignCast(object)));
                    _ = reallocate(@as(?*anyopaque, @ptrCast(closure.*.upvalues)), @sizeOf([*c]ObjUpvalue) *% @as(c_ulong, @bitCast(@as(c_long, closure.*.upvalueCount))), @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))));
                    _ = reallocate(@as(?*anyopaque, @ptrCast(object)), @sizeOf(ObjClosure), @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))));
                    break;
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 1))) => {
                {
                    var function: [*c]ObjFunction = @as([*c]ObjFunction, @ptrCast(@alignCast(object)));
                    freeChunk(&function.*.chunk);
                    _ = reallocate(@as(?*anyopaque, @ptrCast(object)), @sizeOf(ObjFunction), @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))));
                    break;
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 2))) => {
                {
                    var instance: [*c]ObjInstance = @as([*c]ObjInstance, @ptrCast(@alignCast(object)));
                    table_h.freeTable(&instance.*.fields);
                    _ = reallocate(@as(?*anyopaque, @ptrCast(object)), @sizeOf(ObjInstance), @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))));
                    break;
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 3))) => {
                _ = reallocate(@as(?*anyopaque, @ptrCast(object)), @sizeOf(ObjNative), @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))));
                break;
            },
            @as(c_uint, @bitCast(@as(c_int, 4))) => {
                {
                    var string: [*c]ObjString = @as([*c]ObjString, @ptrCast(@alignCast(object)));
                    _ = reallocate(@as(?*anyopaque, @ptrCast(string.*.chars)), @sizeOf(u8) *% @as(c_ulong, @bitCast(@as(c_long, string.*.length + @as(c_int, 1)))), @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))));
                    _ = reallocate(@as(?*anyopaque, @ptrCast(object)), @sizeOf(ObjString), @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))));
                    break;
                }
            },
            @as(c_uint, @bitCast(@as(c_int, 5))) => {
                {
                    _ = reallocate(@as(?*anyopaque, @ptrCast(object)), @sizeOf(ObjUpvalue), @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))));
                    break;
                }
            },
            else => {},
        }
        break;
    }
}
pub export fn markRoots() callconv(.C) void {
    {
        var slot: [*c]Value = @as([*c]Value, @ptrCast(@alignCast(&vm.v.stack)));
        while (slot < vm.v.stackTop) : (slot += 1) {
            markValue(slot.*);
        }
    }
    {
        var i: c_int = 0;
        while (i < vm.v.frameCount) : (i += 1) {
            markObject(@as([*c]Obj, @ptrCast(@alignCast(vm.v.frames[@as(c_uint, @intCast(i))].closure))));
        }
    }
    {
        var upvalue: [*c]ObjUpvalue = vm.v.openUpvalues;
        while (upvalue != @as([*c]ObjUpvalue, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) : (upvalue = upvalue.*.next) {
            markObject(@as([*c]Obj, @ptrCast(@alignCast(upvalue))));
        }
    }
    table_h.markTable(&vm.v.globals);
    compiler_h.markCompilerRoots();
    markObject(@as([*c]Obj, @ptrCast(@alignCast(vm.v.initString))));
}
pub export fn traceReferences() callconv(.C) void {
    while (vm.v.grayCount > @as(c_int, 0)) {
        var object: [*c]Obj = (blk: {
            const tmp = blk_1: {
                const ref = &vm.v.grayCount;
                ref.* -= 1;
                break :blk_1 ref.*;
            };
            if (tmp >= 0) break :blk vm.v.grayStack + @as(usize, @intCast(tmp)) else break :blk vm.v.grayStack - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
        }).*;
        blackenObject(object);
    }
}
pub export fn sweep() callconv(.C) void {
    var previous: [*c]Obj = null;
    var object: [*c]Obj = vm.v.objects;
    while (object != @as([*c]Obj, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) {
        if (object.*.isMarked) {
            object.*.isMarked = @as(c_int, 0) != 0;
            previous = object;
            object = object.*.next;
        } else {
            var unreached: [*c]Obj = object;
            object = object.*.next;
            if (previous != @as([*c]Obj, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) {
                previous.*.next = object;
            } else {
                vm.v.objects = object;
            }
            freeObject(unreached);
        }
    }
}

pub export fn reallocate(arg_pointer: ?*anyopaque, arg_oldSize: usize, arg_newSize: usize) ?*anyopaque {
    var pointer = arg_pointer;
    var oldSize = arg_oldSize;
    var newSize = arg_newSize;
    vm.v.bytesAllocated +%= newSize -% oldSize;
    if (newSize > oldSize) {}
    if (vm.v.bytesAllocated > vm.v.nextGC) {
        collectGarbage();
    }
    if (newSize == @as(usize, @bitCast(@as(c_long, @as(c_int, 0))))) {
        alloc.free(pointer);
        return @as(?*anyopaque, @ptrFromInt(@as(c_int, 0)));
    }
    var result: ?*anyopaque = alloc.realloc(pointer, newSize);
    if (result == @as(?*anyopaque, @ptrFromInt(@as(c_int, 0)))) {
        std.os.exit(1);
    }
    return result;
}
