const std = @import("std");
const print = std.debug.print;

const conv = @import("conv.zig");
const obj_h = @import("object.zig");
const isObjType = obj_h.isObjType;
const notObjTypes = obj_h.notObjTypes;
const ObjString = obj_h.ObjString;
const ObjLinkedList = obj_h.ObjLinkedList;
const FloatVector = obj_h.FloatVector;
const Tensor = obj_h.Tensor;
const ObjHashTable = obj_h.ObjHashTable;
const Obj = obj_h.Obj;
const Node = obj_h.Node;
const ObjTypeCheckParams = obj_h.ObjTypeCheckParams;
const fvec = @import("objects/fvec.zig");
const pushFloatVector = fvec.FloatVector.push;
const table_h = @import("table.zig");
const Entry = table_h.Entry;
const entries_ = table_h.entries_;
const value_h = @import("value.zig");
const Value = value_h.Value;
const valuesEqual = value_h.valuesEqual;
const valueToString = value_h.valueToString;
const vm_h = @import("vm.zig");
const runtimeError = vm_h.runtimeError;

// Helper functions to make code more DRY
fn validateArgCount(argCount: i32, expected: i32, funcName: []const u8) bool {
    if (argCount != expected) {
        runtimeError("{s}() takes {d} argument(s).", .{ funcName, expected });
        return false;
    }
    return true;
}

fn validateMinArgCount(argCount: i32, min: i32, funcName: []const u8) bool {
    if (argCount < min) {
        runtimeError("{s}() takes at least {d} argument(s).", .{ funcName, min });
        return false;
    }
    return true;
}

fn validateObjType(value: Value, objType: obj_h.ObjType, typeName: []const u8) bool {
    if (!isObjType(value, objType)) {
        runtimeError("Argument must be a {s}.", .{typeName});
        return false;
    }
    return true;
}

fn validateNumber(value: Value) bool {
    if (!(value.is_int() or value.is_double())) {
        runtimeError("Argument must be a number.", .{});
        return false;
    }
    return true;
}

// Helper functions removed - using Value.as_num_int() and Value.as_num_double() directly

pub fn assert_nf(argCount: i32, args: [*]Value) Value {
    if (!validateArgCount(argCount, 2, "assert")) {
        return Value.init_nil();
    }

    if (valuesEqual(args[0], args[1])) {
        return Value.init_nil();
    } else {
        runtimeError("Assertion failed {s} != {s}", .{ valueToString(args[0]), valueToString(args[1]) });
        return Value.init_nil();
    }
}

pub fn iter_nf(argCount: i32, args: [*]Value) Value {
    _ = argCount;
    _ = args;
    return Value.init_nil();
}

pub fn next_nf(argCount: i32, args: [*]Value) Value {
    if (!validateArgCount(argCount, 1, "next") or
        !validateObjType(args[0], .OBJ_FVECTOR, "iterable"))
    {
        return Value.init_nil();
    }

    const nextValue = @as(*FloatVector, @ptrCast(@alignCast(args[0].as.obj))).next();
    return Value.init_double(nextValue);
}

pub fn hasNext_nf(argCount: i32, args: [*]Value) Value {
    if (!validateArgCount(argCount, 1, "has_next") or
        !validateObjType(args[0], .OBJ_FVECTOR, "iterable"))
    {
        return Value.init_nil();
    }

    const hasNext = @as(*FloatVector, @ptrCast(@alignCast(args[0].as.obj))).has_next();
    return Value.init_bool(hasNext);
}
pub fn peek_nf(argCount: i32, args: [*]Value) Value {
    if (!validateArgCount(argCount, 2, "peek") or
        !validateObjType(args[0], .OBJ_FVECTOR, "iterable") or
        !validateNumber(args[1]))
    {
        return Value.init_nil();
    }

    const pos = args[1].as_num_int();
    const peekValue = fvec.peekFloatVector(@as(*FloatVector, @ptrCast(@alignCast(args[0].as.obj))), pos);
    return Value.init_double(peekValue);
}
pub fn reset_nf(argCount: i32, args: [*]Value) Value {
    if (!validateArgCount(argCount, 1, "reset") or
        !validateObjType(args[0], .OBJ_FVECTOR, "iterable"))
    {
        return Value.init_nil();
    }

    @as(*FloatVector, @ptrCast(@alignCast(args[0].as.obj))).reset();
    return Value.init_nil();
}
pub fn skip_nf(argCount: i32, args: [*]Value) Value {
    if (!validateArgCount(argCount, 2, "skip") or
        !validateObjType(args[0], .OBJ_FVECTOR, "iterable") or
        !validateNumber(args[1]))
    {
        return Value.init_nil();
    }

    @as(*FloatVector, @ptrCast(@alignCast(args[0].as.obj))).skip(@intCast(args[1].as_num_int()));
    return Value.init_nil();
}

pub fn linkedlist_nf(argCount: i32, args: [*]Value) Value {
    _ = args;
    if (!validateArgCount(argCount, 0, "linked_list")) {
        return Value.init_nil();
    }

    const ll: *ObjLinkedList = obj_h.newLinkedList();
    return Value.init_obj(@ptrCast(ll));
}
pub fn hashtable_nf(argCount: i32, args: [*]Value) Value {
    _ = args;
    if (!validateArgCount(argCount, 0, "hash_table")) {
        return Value.init_nil();
    }

    const h: *ObjHashTable = obj_h.newHashTable();
    return Value.init_obj(@as(*Obj, @ptrCast(@alignCast(h))));
}

pub fn fvector_nf(argCount: i32, args: [*]Value) Value {
    if (!validateArgCount(argCount, 1, "fvec") or !validateNumber(args[0])) {
        return Value.init_nil();
    }

    const cap = args[0].as_num_int();
    const f: *FloatVector = fvec.FloatVector.init(@intCast(cap));
    return Value.init_obj(@ptrCast(@alignCast(f)));
}

// Tensor native functions
pub fn tensor1d_nf(argCount: i32, args: [*]Value) Value {
    if (!validateArgCount(argCount, 1, "tensor1d") or !validateNumber(args[0])) {
        return Value.init_nil();
    }

    const size = args[0].as_num_int();
    const tensor: *Tensor = Tensor.init1D(@intCast(size));
    return Value.init_obj(@ptrCast(@alignCast(tensor)));
}

pub fn tensor2d_nf(argCount: i32, args: [*]Value) Value {
    if (!validateArgCount(argCount, 2, "tensor2d") or 
        !validateNumber(args[0]) or !validateNumber(args[1])) {
        return Value.init_nil();
    }

    const rows = args[0].as_num_int();
    const cols = args[1].as_num_int();
    const tensor: *Tensor = Tensor.init2D(@intCast(rows), @intCast(cols));
    return Value.init_obj(@ptrCast(@alignCast(tensor)));
}

pub fn tensor3d_nf(argCount: i32, args: [*]Value) Value {
    if (!validateArgCount(argCount, 3, "tensor3d") or 
        !validateNumber(args[0]) or !validateNumber(args[1]) or !validateNumber(args[2])) {
        return Value.init_nil();
    }

    const dim1 = args[0].as_num_int();
    const dim2 = args[1].as_num_int();
    const dim3 = args[2].as_num_int();
    const tensor: *Tensor = Tensor.init3D(@intCast(dim1), @intCast(dim2), @intCast(dim3));
    return Value.init_obj(@ptrCast(@alignCast(tensor)));
}

pub fn tensor_get_nf(argCount: i32, args: [*]Value) Value {
    if (argCount < 2 or !isObjType(args[0], .OBJ_TENSOR)) {
        runtimeError("tensor_get requires at least 2 arguments and first must be a tensor.", .{});
        return Value.init_nil();
    }

    const tensor = @as(*Tensor, @ptrCast(@alignCast(args[0].as.obj)));
    
    switch (tensor.order) {
        1 => {
            if (!validateArgCount(argCount, 2, "tensor_get") or !validateNumber(args[1])) {
                return Value.init_nil();
            }
            const i = args[1].as_num_int();
            return Value.init_double(tensor.get1D(@intCast(i)));
        },
        2 => {
            if (!validateArgCount(argCount, 3, "tensor_get") or 
                !validateNumber(args[1]) or !validateNumber(args[2])) {
                return Value.init_nil();
            }
            const i = args[1].as_num_int();
            const j = args[2].as_num_int();
            return Value.init_double(tensor.get2D(@intCast(i), @intCast(j)));
        },
        3 => {
            if (!validateArgCount(argCount, 4, "tensor_get") or 
                !validateNumber(args[1]) or !validateNumber(args[2]) or !validateNumber(args[3])) {
                return Value.init_nil();
            }
            const i = args[1].as_num_int();
            const j = args[2].as_num_int();
            const k = args[3].as_num_int();
            return Value.init_double(tensor.get3D(@intCast(i), @intCast(j), @intCast(k)));
        },
        else => {
            runtimeError("Invalid tensor order.", .{});
            return Value.init_nil();
        },
    }
}

pub fn tensor_set_nf(argCount: i32, args: [*]Value) Value {
    if (argCount < 3 or !isObjType(args[0], .OBJ_TENSOR)) {
        runtimeError("tensor_set requires at least 3 arguments and first must be a tensor.", .{});
        return Value.init_nil();
    }

    const tensor = @as(*Tensor, @ptrCast(@alignCast(args[0].as.obj)));
    
    switch (tensor.order) {
        1 => {
            if (!validateArgCount(argCount, 3, "tensor_set") or 
                !validateNumber(args[1]) or !validateNumber(args[2])) {
                return Value.init_nil();
            }
            const i = args[1].as_num_int();
            const value = args[2].as_num_double();
            tensor.set1D(@intCast(i), value);
        },
        2 => {
            if (!validateArgCount(argCount, 4, "tensor_set") or 
                !validateNumber(args[1]) or !validateNumber(args[2]) or !validateNumber(args[3])) {
                return Value.init_nil();
            }
            const i = args[1].as_num_int();
            const j = args[2].as_num_int();
            const value = args[3].as_num_double();
            tensor.set2D(@intCast(i), @intCast(j), value);
        },
        3 => {
            if (!validateArgCount(argCount, 5, "tensor_set") or 
                !validateNumber(args[1]) or !validateNumber(args[2]) or 
                !validateNumber(args[3]) or !validateNumber(args[4])) {
                return Value.init_nil();
            }
            const i = args[1].as_num_int();
            const j = args[2].as_num_int();
            const k = args[3].as_num_int();
            const value = args[4].as_num_double();
            tensor.set3D(@intCast(i), @intCast(j), @intCast(k), value);
        },
        else => {
            runtimeError("Invalid tensor order.", .{});
            return Value.init_nil();
        },
    }
    
    return Value.init_nil();
}

pub fn tensor_fill_nf(argCount: i32, args: [*]Value) Value {
    if (!validateArgCount(argCount, 2, "tensor_fill") or 
        !isObjType(args[0], .OBJ_TENSOR) or !validateNumber(args[1])) {
        return Value.init_nil();
    }

    const tensor = @as(*Tensor, @ptrCast(@alignCast(args[0].as.obj)));
    const value = args[1].as_num_double();
    tensor.fill(value);
    
    return Value.init_nil();
}

pub fn tensor_add_nf(argCount: i32, args: [*]Value) Value {
    if (!validateArgCount(argCount, 2, "tensor_add") or
        !isObjType(args[0], .OBJ_TENSOR) or !isObjType(args[1], .OBJ_TENSOR)) {
        return Value.init_nil();
    }

    const tensor1 = @as(*Tensor, @ptrCast(@alignCast(args[0].as.obj)));
    const tensor2 = @as(*Tensor, @ptrCast(@alignCast(args[1].as.obj)));
    
    if (tensor1.add(tensor2)) |result| {
        return Value.init_obj(@ptrCast(@alignCast(result)));
    } else {
        runtimeError("Tensor dimensions are incompatible for addition.", .{});
        return Value.init_nil();
    }
}

pub fn tensor_scale_nf(argCount: i32, args: [*]Value) Value {
    if (!validateArgCount(argCount, 2, "tensor_scale") or
        !isObjType(args[0], .OBJ_TENSOR) or !validateNumber(args[1])) {
        return Value.init_nil();
    }

    const tensor = @as(*Tensor, @ptrCast(@alignCast(args[0].as.obj)));
    const scalar = args[1].as_num_double();
    const result = tensor.scale(scalar);
    
    return Value.init_obj(@ptrCast(@alignCast(result)));
}

pub fn tensor_matmul_nf(argCount: i32, args: [*]Value) Value {
    if (!validateArgCount(argCount, 2, "tensor_matmul") or
        !isObjType(args[0], .OBJ_TENSOR) or !isObjType(args[1], .OBJ_TENSOR)) {
        return Value.init_nil();
    }

    const tensor1 = @as(*Tensor, @ptrCast(@alignCast(args[0].as.obj)));
    const tensor2 = @as(*Tensor, @ptrCast(@alignCast(args[1].as.obj)));
    
    if (tensor1.matmul(tensor2)) |result| {
        return Value.init_obj(@ptrCast(@alignCast(result)));
    } else {
        runtimeError("Tensor dimensions are incompatible for matrix multiplication.", .{});
        return Value.init_nil();
    }
}

pub fn tensor_transpose_nf(argCount: i32, args: [*]Value) Value {
    if (!validateArgCount(argCount, 1, "tensor_transpose") or
        !isObjType(args[0], .OBJ_TENSOR)) {
        return Value.init_nil();
    }

    const tensor = @as(*Tensor, @ptrCast(@alignCast(args[0].as.obj)));
    
    if (tensor.transpose()) |result| {
        return Value.init_obj(@ptrCast(@alignCast(result)));
    } else {
        runtimeError("Can only transpose 2D tensors.", .{});
        return Value.init_nil();
    }
}

pub fn tensor_dot_nf(argCount: i32, args: [*]Value) Value {
    if (!validateArgCount(argCount, 2, "tensor_dot") or
        !isObjType(args[0], .OBJ_TENSOR) or !isObjType(args[1], .OBJ_TENSOR)) {
        return Value.init_nil();
    }

    const tensor1 = @as(*Tensor, @ptrCast(@alignCast(args[0].as.obj)));
    const tensor2 = @as(*Tensor, @ptrCast(@alignCast(args[1].as.obj)));
    
    if (tensor1.dot(tensor2)) |result| {
        return Value.init_double(result);
    } else {
        runtimeError("Can only compute dot product of 1D tensors with same dimensions.", .{});
        return Value.init_nil();
    }
}

// Compatibility alias for creating matrices (2D tensors)
pub fn matrix_nf(argCount: i32, args: [*]Value) Value {
    return tensor2d_nf(argCount, args);
}

// pub fn range_nf(argCount: i32, args: [*]Value) Value {
//     _ = &argCount;
//     if (!((args[0].type == .VAL_INT) or (args[0].is_double())) and !((args[1].type == .VAL_INT) or (args[1].is_double()))) {
//         runtimeError("Both arguments must be numbers.", .{});
//         return Value.init_nil();
//     }
//     var start: i32 = if (args[0].is_double()) @intFromFloat(args[0].as_num_double()) else args[0].as.num_int;
//     _ = &start;
//     var end: i32 = if (args[1].is_double()) @intFromFloat(args[1].as_num_double()) else args[1].as.num_int;
//     _ = &end;
//     var a: *ObjArray = obj_h.newArrayWithCap(end - start, true);
//     _ = &a;
//     {
//         var i: i32 = start;
//         _ = &i;
//         while (i < end) : (i += 1) {
//             obj_h.pushArray(a, Value.init_int(i));
//         }
//     }
//     return Value{
//         .type = .VAL_OBJ,
//         .as = .{
//             .obj = @ptrCast(a),
//         },
//     };
// }

pub fn slice_nf(argCount: i32, args: [*]Value) Value {
    // Validate argument count
    if (!validateArgCount(argCount, 3, "slice"))
        return Value.init_nil();

    // Check that first argument is a linked list or vector
    if ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_LINKED_LIST,
        .count = 1,
    })) and (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    }))) {
        runtimeError("First argument must be an array, linked list or vector.", .{});
        return Value.init_nil();
    }

    // Check that second and third arguments are numbers
    if (!(args[1].is_int() or args[1].is_double()) or
        !(args[2].is_int() or args[2].is_double()))
    {
        runtimeError("Second and third arguments must be numbers.", .{});
        return Value.init_nil();
    }

    // Convert start and end indices to integers
    const start: i32 = if (args[1].is_double()) @intFromFloat(args[1].as_num_double()) else args[1].as.num_int;
    const end: i32 = if (args[2].is_double()) @intFromFloat(args[2].as_num_double()) else args[2].as.num_int;

    // Process based on object type
    switch (args[0].as.obj.?.type) {
        .OBJ_FVECTOR => {
            const f = @as(*FloatVector, @ptrCast(args[0].as.obj));
            const s = f.slice(@intCast(start), @intCast(end));
            return Value.init_obj(@ptrCast(s));
        },
        .OBJ_LINKED_LIST => {
            const l = @as(*ObjLinkedList, @ptrCast(args[0].as.obj));
            const s = obj_h.sliceLinkedList(l, start, end);
            return Value.init_obj(@ptrCast(s));
        },
        else => {}, // Should never reach here due to type checking above
    }

    return Value.init_nil();
}

pub fn splice_nf(argCount: i32, args: [*]Value) Value {
    // Validate argument count
    if (!validateArgCount(argCount, 3, "splice"))
        return Value.init_nil();

    // Check first argument is list or vector
    if ((notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_LINKED_LIST,
        .count = 1,
    })) and (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    }))) {
        runtimeError("First argument must be an array, linked list or vector.", .{});
        return Value.init_nil();
    }

    // Validate index arguments
    if (!(args[1].is_int() or args[1].is_double()) or
        !(args[2].is_int() or args[2].is_double()))
    {
        runtimeError("Second and third arguments must be numbers.", .{});
        return Value.init_nil();
    }

    // Extract start and end indices
    const start: i32 = if (args[1].is_double()) @intFromFloat(args[1].as_num_double()) else args[1].as.num_int;
    const end: i32 = if (args[2].is_double()) @intFromFloat(args[2].as_num_double()) else args[2].as.num_int;

    // Process based on object type
    switch (args[0].as.obj.?.type) {
        .OBJ_FVECTOR => {
            const f = @as(*FloatVector, @ptrCast(args[0].as.obj));
            const s = f.splice(@intCast(start), @intCast(end));
            return Value.init_obj(@ptrCast(s));
        },
        .OBJ_LINKED_LIST => {
            const l = @as(*ObjLinkedList, @ptrCast(args[0].as.obj));
            const s = obj_h.spliceLinkedList(l, start, end);
            return Value.init_obj(@ptrCast(s));
        },
        else => {},
    }

    return Value.init_nil();
}

pub fn push_nf(argCount: i32, args: [*]Value) Value {
    if (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_LINKED_LIST,
        .count = 1,
    }) and notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    })) {
        runtimeError("First argument must be a list type.", .{});
        return Value.init_nil();
    }
    switch (args[0].as.obj.?.type) {
        .OBJ_FVECTOR => {
            const f: *FloatVector = @as(*FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
            for (1..@intCast(argCount)) |i| {
                FloatVector.push(f, args[i].as_num_double());
            }

            return Value.init_nil();
        },
        .OBJ_LINKED_LIST => {
            const l: *ObjLinkedList = @as(*ObjLinkedList, @ptrCast(@alignCast(args[0].as.obj)));

            for (1..@intCast(argCount)) |i| {
                obj_h.pushBack(l, args[i]);
            }

            return Value.init_nil();
        },
        else => {
            // This should never be reached due to type checking above,
            // but included for safety
            runtimeError("Argument must be a linked list or float vector.", .{});
            return Value.init_nil();
        },
    }
}

pub fn pop_nf(argCount: i32, args: [*]Value) Value {
    // Validate argument count
    if (!validateArgCount(argCount, 1, "pop")) {
        return Value.init_nil();
    }

    // Check if first argument is a list or vector
    if (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_LINKED_LIST,
        .count = 1,
    }) and notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    })) {
        runtimeError("First argument must be a list type.", .{});
        return Value.init_nil();
    }

    // Process based on object type
    switch (args[0].as.obj.?.type) {
        .OBJ_FVECTOR => {
            const vector = @as(*FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
            return Value.init_double(vector.pop());
        },
        .OBJ_LINKED_LIST => {
            const list = @as(*ObjLinkedList, @ptrCast(@alignCast(args[0].as.obj)));
            return obj_h.popBack(list);
        },
        else => {
            // This should never be reached due to type checking above,
            // but included for safety
            runtimeError("Argument must be a linked list or float vector.", .{});
            return Value.init_nil();
        },
    }
}
pub fn nth_nf(argCount: i32, args: [*]Value) Value {
    // Validate argument count
    if (!validateArgCount(argCount, 2, "nth")) {
        return Value.init_nil();
    }

    // Check if first argument is a supported collection type
    if (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_LINKED_LIST,
        .count = 1,
    }) and notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    }) and notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_HASH_TABLE,
        .count = 1,
    })) {
        runtimeError("First argument must be an array, linked list or vector.", .{});
        return Value.init_nil();
    }

    // Validate that second argument is a number
    if (!(args[1].is_int() or args[1].is_double())) {
        runtimeError("Second argument must be a number.", .{});
        return Value.init_nil();
    }

    // Convert index to integer
    const index = args[1].as_num_int();

    // Process based on object type
    switch (args[0].as.obj.?.type) {
        .OBJ_FVECTOR => {
            const f = @as(*FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
            const value = f.get(@intCast(index));
            return Value.init_double(value);
        },
        .OBJ_LINKED_LIST => {
            const l = @as(*ObjLinkedList, @ptrCast(@alignCast(args[0].as.obj)));
            return l.get(index);
        },
        .OBJ_HASH_TABLE => {
            runtimeError("Hash tables do not support indexed access. Use get() instead.", .{});
            return Value.init_nil();
        },
        else => {
            runtimeError("Invalid argument type.", .{});
            return Value.init_nil();
        },
    }
}

pub fn sort_nf(argCount: i32, args: [*]Value) Value {
    // Validate argument count
    if (!validateArgCount(argCount, 1, "sort")) {
        return Value.init_nil();
    }

    // Check if first argument is a list or vector
    if (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_LINKED_LIST,
        .count = 1,
    }) and notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    })) {
        runtimeError("First argument must be a list type.", .{});
        return Value.init_nil();
    }

    // Process based on object type
    switch (args[0].as.obj.?.type) {
        .OBJ_FVECTOR => {
            const vector = @as(*FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
            fvec.FloatVector.sort(vector);
            return Value.init_nil();
        },
        .OBJ_LINKED_LIST => {
            const list = @as(*ObjLinkedList, @ptrCast(@alignCast(args[0].as.obj)));
            obj_h.mergeSort(list);
            return Value.init_nil();
        },
        else => {
            // This should never be reached due to type checking above,
            // but included for safety
            runtimeError("Argument must be a linked list or float vector.", .{});
            return Value.init_nil();
        },
    }
}

pub fn contains_nf(argCount: i32, args: [*]Value) Value {
    // Validate argument count
    if (!validateArgCount(argCount, 2, "contains")) {
        return Value.init_nil();
    }

    // Check if first argument is a supported collection type
    if (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_LINKED_LIST,
        .count = 1,
    }) and notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    }) and notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_HASH_TABLE,
        .count = 1,
    })) {
        runtimeError("First argument must be a collection type.", .{});
        return Value.init_nil();
    }

    // Process based on object type
    switch (args[0].as.obj.?.type) {
        .OBJ_FVECTOR => {
            //TODO: Implement contains for float vector
            return Value.init_bool(false);
        },
        .OBJ_HASH_TABLE => {
            const hashTable = @as(*ObjHashTable, @ptrCast(@alignCast(args[0].as.obj)));

            if (!isObjType(args[1], .OBJ_STRING)) {
                runtimeError("Hash table key must be a string.", .{});
                return Value.init_nil();
            }

            const key = @as(*ObjString, @ptrCast(@alignCast(args[1].as.obj)));
            const value = obj_h.getHashTable(hashTable, key);
            return Value.init_bool(!valuesEqual(value, Value.init_nil()));
        },
        .OBJ_LINKED_LIST => {
            const list = @as(*ObjLinkedList, @ptrCast(@alignCast(args[0].as.obj)));
            return Value.init_bool(list.search(args[1]) != -1);
        },
        else => {
            runtimeError("Invalid argument type.", .{});
            return Value.init_nil();
        },
    }
}

pub fn insert_nf(argCount: i32, args: [*]Value) Value {
    // Validate argument count
    if (!validateArgCount(argCount, 3, "insert")) {
        return Value.init_nil();
    }

    // Check if first argument is a float vector
    if (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    })) {
        runtimeError("First argument must be an array or vector.", .{});
        return Value.init_nil();
    }

    // Validate index argument
    if (!(args[1].is_int() or args[1].is_double())) {
        runtimeError("Second argument must be a number.", .{});
        return Value.init_nil();
    }

    // Validate value argument
    if (!(args[2].is_int() or args[2].is_double())) {
        runtimeError("Third argument must be a number.", .{});
        return Value.init_nil();
    }

    // FloatVector is the only supported type for insert currently
    const vector = @as(*FloatVector, @ptrCast(@alignCast(args[0].as.obj)));

    // Safely convert index to integer
    const index = args[1].as_num_int();

    // Safely convert value to double
    const value = args[2].as_num_double();

    FloatVector.insert(vector, @intCast(index), value);
    return Value.init_nil();
}

pub fn len_nf(argCount: i32, args: [*]Value) Value {
    // Validate argument count
    if (!validateArgCount(argCount, 1, "len")) {
        return Value.init_nil();
    }

    // Check if first argument is a supported collection type
    if (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_HASH_TABLE,
        .count = 1,
    }) and notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_LINKED_LIST,
        .count = 1,
    }) and notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    })) {
        runtimeError("First argument must be a collection type.", .{});
        return Value.init_nil();
    }

    // Process based on object type
    switch (args[0].as.obj.?.type) {
        .OBJ_HASH_TABLE => {
            const hashTable = @as(*ObjHashTable, @ptrCast(@alignCast(args[0].as.obj)));
            return Value.init_int(@intCast(hashTable.*.table.count));
        },
        .OBJ_FVECTOR => {
            const vector = @as(*FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
            return Value.init_int(@intCast(vector.count));
        },
        .OBJ_LINKED_LIST => {
            const list = @as(*ObjLinkedList, @ptrCast(@alignCast(args[0].as.obj)));
            return Value.init_int(list.len());
        },
        else => {
            runtimeError("Invalid argument type.", .{});
            return Value.init_nil();
        },
    }
}
pub fn search_nf(argCount: i32, args: [*]Value) Value {
    // Validate argument count
    if (!validateArgCount(argCount, 2, "search")) {
        return Value.init_nil();
    }

    // Check if first argument is a supported collection type
    if (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_LINKED_LIST,
        .count = 1,
    }) and notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    })) {
        runtimeError("First argument must be a list type.", .{});
        return Value.init_nil();
    }

    // Process based on object type
    switch (args[0].as.obj.?.type) {
        .OBJ_FVECTOR => {
            const vector = @as(*FloatVector, @ptrCast(@alignCast(args[0].as.obj)));

            if (!(args[1].is_int() or args[1].is_double())) {
                runtimeError("Search value must be a number for float vector.", .{});
                return Value.init_nil();
            }

            const searchValue =
                args[1].as_num_double();

            const result = vector.search(searchValue);
            return if (result == -1) Value.init_nil() else Value.init_int(result);
        },
        .OBJ_LINKED_LIST => {
            const list = @as(*ObjLinkedList, @ptrCast(@alignCast(args[0].as.obj)));
            const result = obj_h.searchLinkedList(list, args[1]);
            return if (result == -1) Value.init_nil() else Value.init_int(result);
        },
        else => {
            runtimeError("Invalid argument type.", .{});
            return Value.init_nil();
        },
    }
}
pub fn is_empty_nf(argCount: i32, args: [*]Value) Value {
    // Validate argument count
    if (!validateArgCount(argCount, 1, "is_empty")) {
        return Value.init_nil();
    }

    // Check if first argument is a supported collection type
    if (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_HASH_TABLE,
        .count = 1,
    }) and notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_LINKED_LIST,
        .count = 1,
    }) and notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    })) {
        runtimeError("First argument must be a collection type.", .{});
        return Value.init_nil();
    }

    // Process based on object type
    switch (args[0].as.obj.?.type) {
        .OBJ_HASH_TABLE => {
            const hashTable = @as(*ObjHashTable, @ptrCast(@alignCast(args[0].as.obj)));
            return Value.init_bool(hashTable.*.table.count == 0);
        },
        .OBJ_FVECTOR => {
            const vector = @as(*FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
            return Value.init_bool(vector.*.count == 0);
        },
        .OBJ_LINKED_LIST => {
            const list = @as(*ObjLinkedList, @ptrCast(@alignCast(args[0].as.obj)));
            return Value.init_bool(list.is_empty());
        },
        else => {
            runtimeError("Unsupported type for is_empty().", .{});
            return Value.init_nil();
        },
    }
}
pub fn equal_list_nf(argCount: i32, args: [*]Value) Value {
    // Validate argument count
    if (!validateArgCount(argCount, 2, "equal_list")) {
        return Value.init_nil();
    }

    // Check if first argument is a list or vector
    if (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_LINKED_LIST,
        .count = 1,
    }) and notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    })) {
        runtimeError("First argument must be a linked list or vector.", .{});
        return Value.init_nil();
    }

    // Process based on object type
    switch (args[0].as.obj.?.type) {
        .OBJ_FVECTOR => {
            // Check that second argument is also a vector
            if (!isObjType(args[1], .OBJ_FVECTOR)) {
                runtimeError("Second argument must also be a vector.", .{});
                return Value.init_nil();
            }

            const vecA = @as(*FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
            const vecB = @as(*FloatVector, @ptrCast(@alignCast(args[1].as.obj)));

            return Value.init_bool(vecA.equal(vecB));
        },
        .OBJ_LINKED_LIST => {
            // Check that second argument is also a linked list
            if (!isObjType(args[1], .OBJ_LINKED_LIST)) {
                runtimeError("Second argument must also be a linked list.", .{});
                return Value.init_nil();
            }

            const listA = @as(*ObjLinkedList, @ptrCast(@alignCast(args[0].as.obj)));
            const listB = @as(*ObjLinkedList, @ptrCast(@alignCast(args[1].as.obj)));

            return Value.init_bool(obj_h.equalLinkedList(listA, listB));
        },
        else => {
            runtimeError("Argument must be a linked list or float vector.", .{});
            return Value.init_nil();
        },
    }
}
pub fn reverse_nf(argCount: i32, args: [*]Value) Value {
    // Validate argument count
    if (!validateArgCount(argCount, 1, "reverse")) {
        return Value.init_nil();
    }

    // Check if first argument is a list or vector
    if (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_LINKED_LIST,
        .count = 1,
    }) and notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    })) {
        runtimeError("First argument must be a list type.", .{});
        return Value.init_nil();
    }

    // Process based on object type
    switch (args[0].as.obj.?.type) {
        .OBJ_FVECTOR => {
            const vector = @as(*FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
            vector.reverse();
            return Value.init_nil();
        },
        .OBJ_LINKED_LIST => {
            const list = @as(*ObjLinkedList, @ptrCast(@alignCast(args[0].as.obj)));
            obj_h.reverseLinkedList(list);
            return Value.init_nil();
        },
        else => {
            runtimeError("Argument must be a linked list or float vector.", .{});
            return Value.init_nil();
        },
    }
}

pub fn merge_nf(argCount: i32, args: [*]Value) Value {
    // Validate argument count
    if (!validateArgCount(argCount, 2, "merge")) {
        return Value.init_nil();
    }

    // Check that both arguments are of the same list type
    if (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_LINKED_LIST,
        .count = 2,
    }) and notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 2,
    })) {
        runtimeError("Both arguments must be the same list type.", .{});
        return Value.init_nil();
    }

    // Process based on object type
    switch (args[0].as.obj.?.type) {
        .OBJ_LINKED_LIST => {
            const listA = @as(*ObjLinkedList, @ptrCast(args[0].as.obj));
            const listB = @as(*ObjLinkedList, @ptrCast(args[1].as.obj));
            const result = obj_h.mergeLinkedList(listA, listB);
            return Value.init_obj(@ptrCast(result));
        },
        .OBJ_FVECTOR => {
            const vecA = @as(*FloatVector, @ptrCast(args[0].as.obj));
            const vecB = @as(*FloatVector, @ptrCast(args[1].as.obj));
            const result = vecA.merge(vecB);
            return Value.init_obj(@ptrCast(result));
        },
        else => {
            runtimeError("Invalid argument types.", .{});
            return Value.init_nil();
        },
    }
}

pub fn clone_nf(argCount: i32, args: [*]Value) Value {
    // Validate argument count
    if (!validateArgCount(argCount, 1, "clone")) {
        return Value.init_nil();
    }

    // Check if first argument is a supported collection type
    if (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_HASH_TABLE,
        .count = 1,
    }) and notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_LINKED_LIST,
        .count = 1,
    }) and notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    })) {
        runtimeError("First argument must be a hash table, linked list or vector.", .{});
        return Value.init_nil();
    }

    // Process based on object type
    switch (args[0].as.obj.?.type) {
        .OBJ_FVECTOR => {
            const vector = @as(*FloatVector, @ptrCast(args[0].as.obj));
            const clone = vector.clone();
            return Value.init_obj(@ptrCast(clone));
        },
        .OBJ_LINKED_LIST => {
            const list = @as(*ObjLinkedList, @ptrCast(args[0].as.obj));
            const clone = obj_h.cloneLinkedList(list);
            return Value.init_obj(@ptrCast(clone));
        },
        .OBJ_HASH_TABLE => {
            const hashTable = @as(*ObjHashTable, @ptrCast(@alignCast(args[0].as.obj)));
            const clone = obj_h.cloneHashTable(hashTable);
            return Value.init_obj(@as(*Obj, @ptrCast(@alignCast(clone))));
        },
        else => {
            runtimeError("Unsupported type for clone().", .{});
            return Value.init_nil();
        },
    }
}

pub fn clear_nf(argCount: i32, args: [*]Value) Value {
    // Validate argument count
    if (!validateArgCount(argCount, 1, "clear")) {
        return Value.init_nil();
    }

    // Check if first argument is a supported collection type
    if (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_HASH_TABLE,
        .count = 1,
    }) and notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_LINKED_LIST,
        .count = 1,
    }) and notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    })) {
        runtimeError("First argument must be a hash table, linked list or vector.", .{});
        return Value.init_nil();
    }

    // Process based on object type
    switch (args[0].as.obj.?.type) {
        .OBJ_FVECTOR => {
            const vector = @as(*FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
            vector.clear();
        },
        .OBJ_LINKED_LIST => {
            const list = @as(*ObjLinkedList, @ptrCast(@alignCast(args[0].as.obj)));
            obj_h.clearLinkedList(list);
        },
        .OBJ_HASH_TABLE => {
            const hashTable = @as(*ObjHashTable, @ptrCast(@alignCast(args[0].as.obj)));
            obj_h.clearHashTable(hashTable);
        },
        else => {
            runtimeError("Unsupported type for clear().", .{});
            return Value.init_nil();
        },
    }

    return Value.init_nil();
}

pub fn sum_nf(argCount: i32, args: [*]Value) Value {
    // Validate argument count
    if (!validateArgCount(argCount, 1, "sum")) {
        return Value.init_nil();
    }

    // Check if first argument is a float vector
    if (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    })) {
        runtimeError("First argument must be a vector.", .{});
        return Value.init_nil();
    }

    // Process the float vector
    const vector = @as(*FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
    return Value.init_double(FloatVector.sum(vector));
}

pub fn mean_nf(argCount: i32, args: [*]Value) Value {
    // Validate argument count
    if (!validateArgCount(argCount, 1, "mean")) {
        return Value.init_nil();
    }

    // Check if first argument is a float vector
    if (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    })) {
        runtimeError("First argument must be a vector.", .{});
        return Value.init_nil();
    }

    // Process the float vector
    const vector = @as(*FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
    return Value.init_double(FloatVector.mean(vector));
}

pub fn std_nf(argCount: i32, args: [*]Value) Value {
    // Validate argument count
    if (!validateArgCount(argCount, 1, "std")) {
        return Value.init_nil();
    }

    // Check if first argument is a float vector
    if (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    })) {
        runtimeError("First argument must be a vector.", .{});
        return Value.init_nil();
    }

    // Process the float vector
    const vector = @as(*FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
    return Value.init_double(FloatVector.std_dev(vector));
}

pub fn var_nf(argCount: i32, args: [*]Value) Value {
    // Validate argument count
    if (!validateArgCount(argCount, 1, "var")) {
        return Value.init_nil();
    }

    // Check if first argument is a float vector
    if (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    })) {
        runtimeError("First argument must be a vector.", .{});
        return Value.init_nil();
    }

    // Process the float vector
    const vector = @as(*FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
    return Value.init_double(FloatVector.variance(vector));
}

pub fn maxl_nf(argCount: i32, args: [*]Value) Value {
    // Validate argument count
    if (!validateArgCount(argCount, 1, "maxl")) {
        return Value.init_nil();
    }

    // Check if first argument is a float vector
    if (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    })) {
        runtimeError("First argument must be a vector.", .{});
        return Value.init_nil();
    }

    // Process the float vector
    const vector = @as(*FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
    return Value.init_double(vector.max());
}

pub fn minl_nf(argCount: i32, args: [*]Value) Value {
    // Validate argument count
    if (!validateArgCount(argCount, 1, "minl")) {
        return Value.init_nil();
    }

    // Check if first argument is a float vector
    if (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    })) {
        runtimeError("First argument must be a vector.", .{});
        return Value.init_nil();
    }

    // Process the float vector
    const vector = @as(*FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
    return Value.init_double(vector.min());
}

pub fn dot_nf(argCount: i32, args: [*]Value) Value {
    // Validate argument count
    if (!validateArgCount(argCount, 2, "dot")) {
        return Value.init_nil();
    }

    // Check if both arguments are float vectors
    if (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 2,
    })) {
        runtimeError("Both arguments must be vectors.", .{});
        return Value.init_nil();
    }

    // Process the vectors
    const vecA = @as(*FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
    const vecB = @as(*FloatVector, @ptrCast(@alignCast(args[1].as.obj)));

    return Value.init_double(vecA.dot(vecB));
}

pub fn cross_nf(argCount: i32, args: [*]Value) Value {
    // Validate argument count
    if (!validateArgCount(argCount, 2, "cross")) {
        return Value.init_nil();
    }

    // Check if both arguments are float vectors
    if (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 2,
    })) {
        runtimeError("Both arguments must be vectors.", .{});
        return Value.init_nil();
    }

    // Process the vectors
    const vecA = @as(*FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
    const vecB = @as(*FloatVector, @ptrCast(@alignCast(args[1].as.obj)));
    const result = vecA.cross(vecB);

    return Value.init_obj(@ptrCast(result));
}

pub fn norm_nf(argCount: i32, args: [*]Value) Value {
    // Validate argument count
    if (!validateArgCount(argCount, 1, "norm")) {
        return Value.init_nil();
    }

    // Check if argument is a float vector
    if (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 1,
    })) {
        runtimeError("First argument must be a vector.", .{});
        return Value.init_nil();
    }

    // Process the vector
    const vector = @as(*FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
    const result = vector.normalize();

    return Value.init_obj(@ptrCast(result));
}

pub fn proj_nf(argCount: i32, args: [*]Value) Value {
    // Validate argument count
    if (!validateArgCount(argCount, 2, "proj")) {
        return Value.init_nil();
    }

    // Check if both arguments are float vectors
    if (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 2,
    })) {
        runtimeError("Both arguments must be vectors.", .{});
        return Value.init_nil();
    }

    // Process the vectors
    const vecA = @as(*FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
    const vecB = @as(*FloatVector, @ptrCast(@alignCast(args[1].as.obj)));
    const result = vecA.projection(vecB);

    return Value.init_obj(@ptrCast(result));
}

pub fn reject_nf(argCount: i32, args: [*]Value) Value {
    // Validate argument count
    if (!validateArgCount(argCount, 2, "reject")) {
        return Value.init_nil();
    }

    // Check if both arguments are float vectors
    if (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 2,
    })) {
        runtimeError("Both arguments must be vectors.", .{});
        return Value.init_nil();
    }

    // Process the vectors
    const vecA = @as(*FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
    const vecB = @as(*FloatVector, @ptrCast(@alignCast(args[1].as.obj)));
    const result = vecA.rejection(vecB);

    return Value.init_obj(@ptrCast(result));
}

pub fn reflect_nf(argCount: i32, args: [*]Value) Value {
    // Validate argument count
    if (!validateArgCount(argCount, 2, "reflect")) {
        return Value.init_nil();
    }

    // Check if both arguments are float vectors
    if (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 2,
    })) {
        runtimeError("Both arguments must be vectors.", .{});
        return Value.init_nil();
    }

    // Process the vectors
    const vecA = @as(*FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
    const vecB = @as(*FloatVector, @ptrCast(@alignCast(args[1].as.obj)));
    const result = vecA.reflection(vecB);

    return Value.init_obj(@ptrCast(result));
}

pub fn refract_nf(argCount: i32, args: [*]Value) Value {
    // Validate argument count
    if (!validateArgCount(argCount, 4, "refract")) {
        return Value.init_nil();
    }

    // Check if first two arguments are float vectors
    if (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 2,
    })) {
        runtimeError("First and second arguments must be vectors.", .{});
        return Value.init_nil();
    }

    // Check if third and fourth arguments are numbers
    if (!(args[2].is_int() or args[2].is_double()) or
        !(args[3].is_int() or args[3].is_double()))
    {
        runtimeError("Third and fourth arguments must be numbers.", .{});
        return Value.init_nil();
    }

    // Process the inputs
    const vecA = @as(*FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
    const vecB = @as(*FloatVector, @ptrCast(@alignCast(args[1].as.obj)));
    const n1 = args[2].as_num_double();

    const result = vecA.refraction(vecB, n1);

    return Value.init_obj(@ptrCast(result));
}

pub fn angle_nf(argCount: i32, args: [*]Value) Value {
    // Validate argument count
    if (!validateArgCount(argCount, 2, "angle")) {
        return Value.init_nil();
    }

    // Check if both arguments are float vectors
    if (notObjTypes(ObjTypeCheckParams{
        .values = args,
        .objType = .OBJ_FVECTOR,
        .count = 2,
    })) {
        runtimeError("Both arguments must be vectors.", .{});
        return Value.init_nil();
    }

    // Process the vectors
    const vecA = @as(*FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
    const vecB = @as(*FloatVector, @ptrCast(@alignCast(args[1].as.obj)));
    const result = vecA.angle(vecB);

    return Value.init_double(result);
}

pub fn put_nf(argCount: i32, args: [*]Value) Value {
    // Validate argument count
    if (!validateArgCount(argCount, 3, "put")) {
        return Value.init_nil();
    }

    // Check if first argument is a hash table
    if (!isObjType(args[0], .OBJ_HASH_TABLE)) {
        runtimeError("First argument must be a hash table.", .{});
        return Value.init_nil();
    }

    // Check if second argument is a string
    if (!isObjType(args[1], .OBJ_STRING)) {
        runtimeError("Second argument must be a string.", .{});
        return Value.init_nil();
    }

    // Process the hash table operation
    const hashTable = @as(*ObjHashTable, @ptrCast(@alignCast(args[0].as.obj)));
    const key = @as(*ObjString, @ptrCast(@alignCast(args[1].as.obj)));

    return Value.init_bool(obj_h.putHashTable(hashTable, key, args[2]));
}

pub fn get_nf(argCount: i32, args: [*]Value) Value {
    // Validate argument count
    if (!validateArgCount(argCount, 2, "get")) {
        return Value.init_nil();
    }

    // Check if first argument is a hash table
    if (!isObjType(args[0], .OBJ_HASH_TABLE)) {
        runtimeError("First argument must be a hash table.", .{});
        return Value.init_nil();
    }

    // Check if second argument is a string
    if (!isObjType(args[1], .OBJ_STRING)) {
        runtimeError("Second argument must be a string.", .{});
        return Value.init_nil();
    }

    // Process the hash table operation
    const hashTable = @as(*ObjHashTable, @ptrCast(@alignCast(args[0].as.obj)));
    const key = @as(*ObjString, @ptrCast(@alignCast(args[1].as.obj)));

    return obj_h.getHashTable(hashTable, key);
}

pub fn remove_nf(argCount: i32, args: [*]Value) Value {
    // Validate argument count
    if (!validateArgCount(argCount, 2, "remove")) {
        return Value.init_nil();
    }

    // Verify the first argument is a valid container type
    const isHashTable = isObjType(args[0], .OBJ_HASH_TABLE);
    const isVector = isObjType(args[0], .OBJ_FVECTOR);

    if (!isHashTable and !isVector) {
        runtimeError("First argument must be a hash table or float vector.", .{});
        return Value.init_nil();
    }

    // Check second argument based on container type
    if (isHashTable and !isObjType(args[1], .OBJ_STRING)) {
        runtimeError("For hash tables, second argument must be a string.", .{});
        return Value.init_nil();
    } else if (isVector and !(args[1].is_int() or args[1].is_double())) {
        runtimeError("For vectors, second argument must be a number.", .{});
        return Value.init_nil();
    }

    // Process the removal based on container type
    switch (args[0].as.obj.?.type) {
        .OBJ_HASH_TABLE => {
            const hashTable = @as(*ObjHashTable, @ptrCast(@alignCast(args[0].as.obj)));
            const key = @as(*ObjString, @ptrCast(@alignCast(args[1].as.obj)));
            return Value.init_bool(obj_h.removeHashTable(hashTable, key));
        },
        .OBJ_FVECTOR => {
            const vector = @as(*FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
            const index = args[1].as_num_int();

            return Value.init_double(vector.remove(@intCast(index)));
        },
        else => {
            // This should never be reached due to type checking above
            runtimeError("Unsupported container type.", .{});
            return Value.init_nil();
        },
    }
}

pub fn push_front_nf(argCount: i32, args: [*]Value) Value {
    // Validate minimum argument count
    if (!validateMinArgCount(argCount, 2, "push_front")) {
        return Value.init_nil();
    }

    // Check if first argument is a linked list
    if (!isObjType(args[0], .OBJ_LINKED_LIST)) {
        runtimeError("First argument must be a linked list.", .{});
        return Value.init_nil();
    }

    // Process the linked list operation
    const list = @as(*ObjLinkedList, @ptrCast(@alignCast(args[0].as.obj)));

    for (1..@intCast(argCount)) |i| {
        obj_h.pushFront(list, args[i]);
    }

    return Value.init_nil();
}

pub fn pop_front_nf(argCount: i32, args: [*]Value) Value {
    // Validate argument count
    if (!validateArgCount(argCount, 1, "pop_front")) {
        return Value.init_nil();
    }

    // Check if first argument is a linked list
    if (!isObjType(args[0], .OBJ_LINKED_LIST)) {
        runtimeError("First argument must be a linked list.", .{});
        return Value.init_nil();
    }

    // Process the linked list operation
    const list = @as(*ObjLinkedList, @ptrCast(@alignCast(args[0].as.obj)));
    return obj_h.popFront(list);
}

pub fn workspace_nf(argCount: i32, args: [*]Value) Value {
    _ = &args;
    // Validate argument count
    if (!validateArgCount(argCount, 0, "workspace")) {
        return Value.init_nil();
    }

    // Print header
    print("Workspace:\n", .{});

    // Check if entries exist
    if (vm_h.vm.globals.entries) |tableEntries| {
        // Iterate through all entries
        for (0..@intCast(vm_h.vm.globals.capacity)) |i| {
            const entry = &tableEntries[i];

            // Check if entry is valid and not a native function
            if (entry.*.key != null and !isObjType(entry.*.value, .OBJ_NATIVE)) {
                // Print variable name and value
                print("{s}: ", .{entry.*.key.?.chars});
                value_h.printValue(entry.*.value);
                print("\n", .{});
            }
        }
    }

    return Value.init_nil();
}

pub fn linspace_nf(argCount: i32, args: [*]Value) Value {
    // Validate argument count
    if (!validateArgCount(argCount, 3, "linspace")) {
        return Value.init_nil();
    }

    // Validate numeric arguments
    if (!(args[0].is_int() or args[0].is_double()) or
        !(args[1].is_int() or args[1].is_double()) or
        !(args[2].is_int() or args[2].is_double()))
    {
        runtimeError("All three arguments must be numbers.", .{});
        return Value.init_nil();
    }

    // Extract parameters
    const start = args[0].as_num_double();
    const end = args[1].as_num_double();
    const n = args[2].as_num_int();

    // Create linearly spaced vector
    const result = fvec.FloatVector.linspace(start, end, n);

    return Value.init_obj(@ptrCast(result));
}

pub fn interp1_nf(argCount: i32, args: [*]Value) Value {
    // Validate argument count
    if (!validateArgCount(argCount, 3, "interp1")) {
        return Value.init_nil();
    }

    // Check if first two arguments are vectors
    if (!isObjType(args[0], .OBJ_FVECTOR) or !isObjType(args[1], .OBJ_FVECTOR)) {
        runtimeError("First and second arguments must be vectors.", .{});
        return Value.init_nil();
    }

    // Check if third argument is a number
    if (!(args[2].is_int() or args[2].is_double())) {
        runtimeError("Third argument must be a number.", .{});
        return Value.init_nil();
    }

    // Extract parameters
    const x = @as(*FloatVector, @ptrCast(@alignCast(args[0].as.obj)));
    const y = @as(*FloatVector, @ptrCast(@alignCast(args[1].as.obj)));
    const x0 = args[2].as_num_double();

    // Perform interpolation
    const result = x.interp1(y, x0);

    return Value.init_double(result);
}

// Get all key-value pairs from a hash table as a list of pairs
pub fn pairs_nf(argCount: i32, args: [*]Value) Value {
    if (!validateArgCount(argCount, 1, "pairs")) {
        return Value.init_nil();
    }

    if (!isObjType(args[0], .OBJ_HASH_TABLE)) {
        runtimeError("Argument must be a hash table.", .{});
        return Value.init_nil();
    }

    const hashTable = @as(*ObjHashTable, @ptrCast(@alignCast(args[0].as.obj)));
    const pairsList = obj_h.hashTableToPairs(hashTable);

    return Value.init_obj(@ptrCast(pairsList));
}
