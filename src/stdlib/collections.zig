const std = @import("std");
const Value = @import("../value.zig").Value;
const stdlib_core = @import("../stdlib_core.zig");
const DefineFunction = stdlib_core.DefineFunction;
const ParamSpec = stdlib_core.ParamSpec;
const ParamType = stdlib_core.ParamType;
const NoParams = stdlib_core.NoParams;
const OneAny = stdlib_core.OneAny;
const OneNumber = stdlib_core.OneNumber;

const conv = @import("../conv.zig");
const mem_utils = @import("../mem_utils.zig");
const object_h = @import("../object.zig");
const ObjType = object_h.ObjType;
const ObjLinkedList = object_h.LinkedList;
const ObjHashTable = object_h.ObjHashTable;
const FloatVector = object_h.FloatVector;
const fvector = @import("../objects/fvec.zig");
const ObjRange = @import("../objects/range.zig").ObjRange;
const valuesEqual = @import("../value.zig").valuesEqual;
const valueToString = @import("../value.zig").valueToString;

// Implementation functions

fn linked_list_impl(argc: i32, args: [*]Value) Value {
    _ = argc;
    _ = args;
    const ll: *ObjLinkedList = ObjLinkedList.init();
    return Value.init_obj(@ptrCast(ll));
}

fn hash_table_impl(argc: i32, args: [*]Value) Value {
    _ = argc;
    _ = args;
    const ht: *ObjHashTable = ObjHashTable.init();
    return Value.init_obj(@ptrCast(ht));
}

fn fvec_impl(argc: i32, args: [*]Value) Value {
    _ = argc;
    const capacity = args[0].as_num_int();
    if (capacity < 0) {
        return stdlib_core.stdlib_error("fvec() capacity must be positive!", .{});
    }

    const vec = fvector.FloatVector.init(@intCast(capacity));
    return Value.init_obj(@ptrCast(vec));
}

fn push_impl(argc: i32, args: [*]Value) Value {
    if (!Value.is_obj_type(args[0], .OBJ_LINKED_LIST) and
        !Value.is_obj_type(args[0], .OBJ_FVECTOR))
    {
        return stdlib_core.stdlib_error("First argument must be a list or vector!", .{});
    }

    if (Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        const vector = args[0].as_vector();
        for (1..@intCast(argc)) |i| {
            if (!args[i].is_prim_num()) {
                return stdlib_core.stdlib_error("Vector values must be numeric!", .{});
            }
            vector.push(args[i].as_num_double());
        }
    } else if (Value.is_obj_type(args[0], .OBJ_LINKED_LIST)) {
        const list = args[0].as_linked_list();
        for (1..@intCast(argc)) |i| {
            ObjLinkedList.push(list, args[i]);
        }
    }

    return Value.init_nil();
}

fn pop_impl(argc: i32, args: [*]Value) Value {
    _ = argc;

    if (!Value.is_obj_type(args[0], .OBJ_LINKED_LIST) and
        !Value.is_obj_type(args[0], .OBJ_FVECTOR))
    {
        return stdlib_core.stdlib_error("Argument must be a list or vector!", .{});
    }

    if (Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        const vector = args[0].as_vector();
        return Value.init_double(vector.pop());
    } else {
        const list = args[0].as_linked_list();
        return ObjLinkedList.pop(list);
    }
}

fn push_front_impl(argc: i32, args: [*]Value) Value {
    _ = argc;

    if (!Value.is_obj_type(args[0], .OBJ_LINKED_LIST) and
        !Value.is_obj_type(args[0], .OBJ_FVECTOR))
    {
        return stdlib_core.stdlib_error("First argument must be a list or vector!", .{});
    }

    if (Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        const vector = args[0].as_vector();
        if (!args[1].is_prim_num()) {
            return stdlib_core.stdlib_error("Vector values must be numeric!", .{});
        }
        vector.insert(0, args[1].as_num_double());
    } else if (Value.is_obj_type(args[0], .OBJ_LINKED_LIST)) {
        const list = args[0].as_linked_list();
        ObjLinkedList.push_front(list, args[1]);
    }

    return Value.init_nil();
}

fn pop_front_impl(argc: i32, args: [*]Value) Value {
    _ = argc;

    if (!Value.is_obj_type(args[0], .OBJ_LINKED_LIST) and
        !Value.is_obj_type(args[0], .OBJ_FVECTOR))
    {
        return stdlib_core.stdlib_error("Argument must be a list or vector!", .{});
    }

    if (Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        const vector = args[0].as_vector();
        const value = vector.get(0);
        _ = vector.remove(0);
        return Value.init_double(value);
    } else {
        const list = args[0].as_linked_list();
        return ObjLinkedList.pop_front(list);
    }
}

fn len_impl(argc: i32, args: [*]Value) Value {
    _ = argc;

    switch (args[0].type) {
        .VAL_OBJ => {
            if (Value.is_obj_type(args[0], .OBJ_STRING)) {
                const str = args[0].as_zstring();
                return Value.init_int(@intCast(str.len));
            } else if (Value.is_obj_type(args[0], .OBJ_LINKED_LIST)) {
                const list = args[0].as_linked_list();
                return Value.init_int(@intCast(list.count));
            } else if (Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
                const vector = args[0].as_vector();
                return Value.init_int(@intCast(vector.count));
            } else if (Value.is_obj_type(args[0], .OBJ_HASH_TABLE)) {
                const table = args[0].as_hash_table();
                return Value.init_int(@intCast(table.len()));
            } else {
                return stdlib_core.stdlib_error("Object type does not support length!", .{});
            }
        },
        else => return stdlib_core.stdlib_error("Value does not support length!", .{}),
    }
}

fn get_impl(argc: i32, args: [*]Value) Value {
    _ = argc;

    if (Value.is_obj_type(args[0], .OBJ_LINKED_LIST)) {
        const list = args[0].as_linked_list();
        const index = args[1].as_num_int();
        return ObjLinkedList.get(list, index);
    } else if (Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        const vector = args[0].as_vector();
        const index = args[1].as_num_int();
        return Value.init_double(vector.get(@intCast(index)));
    } else if (Value.is_obj_type(args[0], .OBJ_HASH_TABLE)) {
        const table = args[0].as_hash_table();
        if (!args[1].is_string()) {
            return stdlib_core.stdlib_error("Hash table key must be a string!", .{});
        }
        const key = args[1].as_string();
        return ObjHashTable.get(table, key) orelse Value.init_nil();
    } else {
        return stdlib_core.stdlib_error("Object does not support indexing!", .{});
    }
}

fn set_impl(argc: i32, args: [*]Value) Value {
    _ = argc;

    if (Value.is_obj_type(args[0], .OBJ_LINKED_LIST)) {
        const list = args[0].as_linked_list();
        const index = args[1].as_num_int();
        ObjLinkedList.set(list, index, args[2]);
    } else if (Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        const vector = args[0].as_vector();
        const index = args[1].as_num_int();
        if (!args[2].is_prim_num()) {
            return stdlib_core.stdlib_error("Vector values must be numeric!", .{});
        }
        vector.set(@intCast(index), args[2].as_num_double());
    } else if (Value.is_obj_type(args[0], .OBJ_HASH_TABLE)) {
        const table = args[0].as_hash_table();
        if (!args[1].is_string()) {
            return stdlib_core.stdlib_error("Hash table key must be a string!", .{});
        }
        const key = args[1].as_string();
        _ = table.put(key, args[2]);
    } else {
        return stdlib_core.stdlib_error("Object does not support assignment!", .{});
    }

    return Value.init_nil();
}

fn contains_impl(argc: i32, args: [*]Value) Value {
    _ = argc;

    if (Value.is_obj_type(args[0], .OBJ_LINKED_LIST)) {
        const list = args[0].as_linked_list();
        return Value.init_bool(list.search(args[1]) >= 0);
    } else if (Value.is_obj_type(args[0], .OBJ_HASH_TABLE)) {
        const table = args[0].as_hash_table();
        if (!args[1].is_string()) {
            return Value.init_bool(false);
        }
        const key = args[1].as_string();
        return Value.init_bool(ObjHashTable.get(table, key) != null);
    } else if (Value.is_obj_type(args[0], .OBJ_STRING)) {
        const haystack = args[0].as_zstring();
        if (args[1].is_string()) {
            const needle = args[1].as_zstring();
            return Value.init_bool(std.mem.indexOf(u8, haystack, needle) != null);
        } else {
            return Value.init_bool(false);
        }
    } else {
        return stdlib_core.stdlib_error("Object does not support contains!", .{});
    }
}

fn clear_impl(argc: i32, args: [*]Value) Value {
    _ = argc;

    if (Value.is_obj_type(args[0], .OBJ_LINKED_LIST)) {
        const list = args[0].as_linked_list();
        ObjLinkedList.clear(list);
    } else if (Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        const vector = args[0].as_vector();
        vector.clear();
    } else if (Value.is_obj_type(args[0], .OBJ_HASH_TABLE)) {
        const table = args[0].as_hash_table();
        ObjHashTable.clear(table);
    } else {
        return stdlib_core.stdlib_error("Object does not support clear!", .{});
    }

    return Value.init_nil();
}

fn range_impl(argc: i32, args: [*]Value) Value {
    var start: i32 = 0;
    var end: i32 = 0;
    var step: i32 = 1;

    if (argc == 1) {
        // range(end)
        end = args[0].as_num_int();
    } else if (argc == 2) {
        // range(start, end)
        start = args[0].as_num_int();
        end = args[1].as_num_int();
    } else {
        // range(start, end, step)
        start = args[0].as_num_int();
        end = args[1].as_num_int();
        step = args[2].as_num_int();
    }

    if (step == 0) {
        return stdlib_core.stdlib_error("Range step cannot be zero!", .{});
    }

    const range_obj = ObjRange.init(start, end, false);
    return Value.init_obj(@ptrCast(range_obj));
}

fn range_to_array_impl(argc: i32, args: [*]Value) Value {
    _ = argc;

    if (!Value.is_obj_type(args[0], .OBJ_RANGE)) {
        return stdlib_core.stdlib_error("Argument must be a range!", .{});
    }

    const range_obj = args[0].as_range();

    // Use the range's to_array method
    return range_obj.to_array();
}

fn put_impl(argc: i32, args: [*]Value) Value {
    _ = argc;

    if (!Value.is_obj_type(args[0], .OBJ_HASH_TABLE)) {
        return stdlib_core.stdlib_error("First argument must be a hash table!", .{});
    }

    const table = args[0].as_hash_table();
    if (!args[1].is_string()) {
        return stdlib_core.stdlib_error("Hash table key must be a string!", .{});
    }
    const key = args[1].as_string();
    _ = table.put(key, args[2]);

    return Value.init_nil();
}

fn pairs_impl(argc: i32, args: [*]Value) Value {
    _ = argc;

    if (!Value.is_obj_type(args[0], .OBJ_HASH_TABLE)) {
        return stdlib_core.stdlib_error("Argument must be a hash table!", .{});
    }

    const table = args[0].as_hash_table();
    const list = ObjLinkedList.init();

    // Convert hash table entries to pairs and add to linked list
    var iter = table.map.iterator();
    while (iter.next()) |entry| {
        // Create a pair as a 2-element vector: [key, value]
        const pair_vec = fvector.FloatVector.init(2);
        // For now, convert key string to a simple representation
        // This is a simplified implementation - in a full system you'd want proper pair objects
        const key_str = entry.key_ptr.*.chars;
        pair_vec.push(@as(f64, @floatFromInt(@intFromPtr(key_str.ptr)))); // Simplified key representation

        // Convert value to float if possible, otherwise use memory address
        const val = switch (entry.value_ptr.*.type) {
            .VAL_INT => @as(f64, @floatFromInt(entry.value_ptr.*.as_int())),
            .VAL_DOUBLE => entry.value_ptr.*.as_double(),
            .VAL_BOOL => if (entry.value_ptr.*.as_bool()) @as(f64, 1.0) else @as(f64, 0.0),
            .VAL_NIL => @as(f64, 0.0),
            else => @as(f64, @floatFromInt(@intFromPtr(entry.value_ptr))),
        };
        pair_vec.push(val);

        ObjLinkedList.push(list, Value.init_obj(@ptrCast(pair_vec)));
    }

    return Value.init_obj(@ptrCast(list));
}

fn is_empty_impl(argc: i32, args: [*]Value) Value {
    _ = argc;

    switch (args[0].type) {
        .VAL_OBJ => {
            if (Value.is_obj_type(args[0], .OBJ_LINKED_LIST)) {
                const list = args[0].as_linked_list();
                return Value.init_bool(list.count == 0);
            } else if (Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
                const vector = args[0].as_vector();
                return Value.init_bool(vector.count == 0);
            } else if (Value.is_obj_type(args[0], .OBJ_HASH_TABLE)) {
                const table = args[0].as_hash_table();
                return Value.init_bool(table.len() == 0);
            } else if (Value.is_obj_type(args[0], .OBJ_STRING)) {
                const str = args[0].as_zstring();
                return Value.init_bool(str.len == 0);
            } else {
                return stdlib_core.stdlib_error("Object type does not support is_empty!", .{});
            }
        },
        else => return stdlib_core.stdlib_error("Value does not support is_empty!", .{}),
    }
}

fn nth_impl(argc: i32, args: [*]Value) Value {
    _ = argc;

    const index = args[1].as_num_int();

    if (Value.is_obj_type(args[0], .OBJ_LINKED_LIST)) {
        const list = args[0].as_linked_list();
        if (index < 0 or index >= list.count) {
            return stdlib_core.stdlib_error("Index out of bounds!", .{});
        }
        return list.get(index);
    } else if (Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        const vector = args[0].as_vector();
        if (index < 0 or index >= @as(i32, @intCast(vector.count))) {
            return stdlib_core.stdlib_error("Index out of bounds!", .{});
        }
        return Value.init_double(vector.get(@intCast(index)));
    } else {
        return stdlib_core.stdlib_error("Object does not support nth access!", .{});
    }
}

fn linspace_impl(argc: i32, args: [*]Value) Value {
    _ = argc;

    const start = args[0].as_num_double();
    const end = args[1].as_num_double();
    const count = args[2].as_num_int();

    if (count < 0) {
        return stdlib_core.stdlib_error("Count must be non-negative!", .{});
    }

    const vector = fvector.FloatVector.linspace(start, end, count);
    return Value.init_obj(@ptrCast(vector));
}

fn insert_impl(argc: i32, args: [*]Value) Value {
    _ = argc;

    const index = args[1].as_num_int();
    const value = args[2].as_num_double();

    if (Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        const vector = args[0].as_vector();
        vector.insert(@intCast(index), value);
    } else if (Value.is_obj_type(args[0], .OBJ_LINKED_LIST)) {
        const list = args[0].as_linked_list();
        list.insert(index, Value.init_double(value));
    } else {
        return stdlib_core.stdlib_error("Object does not support insert!", .{});
    }

    return Value.init_nil();
}

fn remove_impl(argc: i32, args: [*]Value) Value {
    _ = argc;

    const index = args[1].as_num_int();

    if (Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        const vector = args[0].as_vector();
        const removed_value = vector.get(@intCast(index));
        _ = vector.remove(@intCast(index));
        return Value.init_double(removed_value);
    } else if (Value.is_obj_type(args[0], .OBJ_LINKED_LIST)) {
        const list = args[0].as_linked_list();
        return list.remove(index);
    } else {
        return stdlib_core.stdlib_error("Object does not support remove!", .{});
    }
}

fn slice_impl(argc: i32, args: [*]Value) Value {
    _ = argc;

    const start_idx = args[1].as_num_int();
    const end_idx = args[2].as_num_int();

    if (Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        const vector = args[0].as_vector();
        if (start_idx < 0 or end_idx < 0 or start_idx > end_idx) {
            return stdlib_core.stdlib_error("Invalid slice indices!", .{});
        }
        const sliced = vector.slice(@intCast(start_idx), @intCast(end_idx));
        return Value.init_obj(@ptrCast(sliced));
    } else {
        return stdlib_core.stdlib_error("Object does not support slice!", .{});
    }
}

fn merge_impl(argc: i32, args: [*]Value) Value {
    _ = argc;

    if (Value.is_obj_type(args[0], .OBJ_FVECTOR) and Value.is_obj_type(args[1], .OBJ_FVECTOR)) {
        const vector1 = args[0].as_vector();
        const vector2 = args[1].as_vector();
        const merged = vector1.merge(vector2);
        return Value.init_obj(@ptrCast(merged));
    } else {
        return stdlib_core.stdlib_error("Both arguments must be vectors!", .{});
    }
}

fn search_impl(argc: i32, args: [*]Value) Value {
    _ = argc;

    const search_value = args[1].as_num_double();

    if (Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        const vector = args[0].as_vector();
        const index = vector.search(search_value);
        return Value.init_int(index);
    } else if (Value.is_obj_type(args[0], .OBJ_LINKED_LIST)) {
        const list = args[0].as_linked_list();
        return Value.init_int(list.search(Value.init_double(search_value)));
    } else {
        return stdlib_core.stdlib_error("Object does not support search!", .{});
    }
}

fn sort_impl(argc: i32, args: [*]Value) Value {
    _ = argc;

    if (Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        const vector = args[0].as_vector();
        vector.sort();
    } else if (Value.is_obj_type(args[0], .OBJ_LINKED_LIST)) {
        const list = args[0].as_linked_list();
        list.sort();
    } else {
        return stdlib_core.stdlib_error("Object does not support sort!", .{});
    }

    return Value.init_nil();
}

fn splice_impl(argc: i32, args: [*]Value) Value {
    _ = argc;

    const start_idx = args[1].as_num_int();
    const end_idx = args[2].as_num_int();

    if (Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        const vector = args[0].as_vector();
        if (start_idx < 0 or end_idx < 0 or start_idx > end_idx) {
            return stdlib_core.stdlib_error("Invalid splice indices!", .{});
        }
        const spliced = vector.splice(@intCast(start_idx), @intCast(end_idx));
        return Value.init_obj(@ptrCast(spliced));
    } else {
        return stdlib_core.stdlib_error("Object does not support splice!", .{});
    }
}

fn sum_impl(argc: i32, args: [*]Value) Value {
    _ = argc;

    if (Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        const vector = args[0].as_vector();
        return Value.init_double(vector.sum());
    } else {
        return stdlib_core.stdlib_error("Object does not support sum!", .{});
    }
}

fn mean_impl(argc: i32, args: [*]Value) Value {
    _ = argc;

    if (Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        const vector = args[0].as_vector();
        return Value.init_double(vector.mean());
    } else {
        return stdlib_core.stdlib_error("Object does not support mean!", .{});
    }
}

fn vari_impl(argc: i32, args: [*]Value) Value {
    _ = argc;

    if (Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        const vector = args[0].as_vector();
        return Value.init_double(vector.variance());
    } else {
        return stdlib_core.stdlib_error("Object does not support variance!", .{});
    }
}

fn std_impl(argc: i32, args: [*]Value) Value {
    _ = argc;

    if (Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        const vector = args[0].as_vector();
        return Value.init_double(vector.std_dev());
    } else {
        return stdlib_core.stdlib_error("Object does not support std_dev!", .{});
    }
}

fn minl_impl(argc: i32, args: [*]Value) Value {
    _ = argc;

    if (Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        const vector = args[0].as_vector();
        return Value.init_double(vector.min());
    } else {
        return stdlib_core.stdlib_error("Object does not support min!", .{});
    }
}

fn maxl_impl(argc: i32, args: [*]Value) Value {
    _ = argc;

    if (Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        const vector = args[0].as_vector();
        return Value.init_double(vector.max());
    } else {
        return stdlib_core.stdlib_error("Object does not support max!", .{});
    }
}

fn reverse_impl(argc: i32, args: [*]Value) Value {
    _ = argc;

    if (Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        const vector = args[0].as_vector();
        vector.reverse();
    } else if (Value.is_obj_type(args[0], .OBJ_LINKED_LIST)) {
        const list = args[0].as_linked_list();
        list.reverse();
    } else {
        return stdlib_core.stdlib_error("Object does not support reverse!", .{});
    }

    return Value.init_nil();
}

// ===== Phase 2: Vector Math Operations =====

fn dot_impl(_: i32, args: [*]Value) Value {
    if (!Value.is_obj_type(args[0], .OBJ_FVECTOR) or !Value.is_obj_type(args[1], .OBJ_FVECTOR)) {
        return stdlib_core.stdlib_error("dot() requires two vectors!", .{});
    }
    
    const v1 = args[0].as_vector();
    const v2 = args[1].as_vector();
    
    if (v1.size != v2.size) {
        return stdlib_core.stdlib_error("dot() requires vectors of same size!", .{});
    }
    
    var dot_sum: f64 = 0.0;
    for (0..v1.size) |i| {
        dot_sum += v1.data[i] * v2.data[i];
    }
    
    return Value.init_double(dot_sum);
}

fn cross_impl(_: i32, args: [*]Value) Value {
    if (!Value.is_obj_type(args[0], .OBJ_FVECTOR) or !Value.is_obj_type(args[1], .OBJ_FVECTOR)) {
        return stdlib_core.stdlib_error("cross() requires two vectors!", .{});
    }
    
    const v1 = args[0].as_vector();
    const v2 = args[1].as_vector();
    
    if (v1.size != 3 or v2.size != 3) {
        return stdlib_core.stdlib_error("cross() requires 3D vectors!", .{});
    }
    
    const result = fvector.FloatVector.init(3);
    result.data[0] = v1.data[1] * v2.data[2] - v1.data[2] * v2.data[1];
    result.data[1] = v1.data[2] * v2.data[0] - v1.data[0] * v2.data[2];
    result.data[2] = v1.data[0] * v2.data[1] - v1.data[1] * v2.data[0];
    result.size = 3;
    
    return Value.init_obj(@ptrCast(result));
}

fn magnitude_impl(_: i32, args: [*]Value) Value {
    if (!Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        return stdlib_core.stdlib_error("magnitude() requires a vector!", .{});
    }
    
    const v = args[0].as_vector();
    var mag_sum: f64 = 0.0;
    for (0..v.size) |i| {
        mag_sum += v.data[i] * v.data[i];
    }
    
    return Value.init_double(@sqrt(mag_sum));
}

fn normalize_impl(_: i32, args: [*]Value) Value {
    if (!Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        return stdlib_core.stdlib_error("normalize() requires a vector!", .{});
    }
    
    const v = args[0].as_vector();
    var norm_sum: f64 = 0.0;
    for (0..v.size) |i| {
        norm_sum += v.data[i] * v.data[i];
    }
    
    const mag = @sqrt(norm_sum);
    if (mag == 0.0) {
        return stdlib_core.stdlib_error("Cannot normalize zero vector!", .{});
    }
    
    const result = fvector.FloatVector.init(v.size);
    for (0..v.size) |i| {
        result.data[i] = v.data[i] / mag;
    }
    result.size = v.size;
    
    return Value.init_obj(@ptrCast(result));
}

fn distance_impl(_: i32, args: [*]Value) Value {
    if (!Value.is_obj_type(args[0], .OBJ_FVECTOR) or !Value.is_obj_type(args[1], .OBJ_FVECTOR)) {
        return stdlib_core.stdlib_error("distance() requires two vectors!", .{});
    }
    
    const v1 = args[0].as_vector();
    const v2 = args[1].as_vector();
    
    if (v1.size != v2.size) {
        return stdlib_core.stdlib_error("distance() requires vectors of same size!", .{});
    }
    
    var dist_sum: f64 = 0.0;
    for (0..v1.size) |i| {
        const delta = v1.data[i] - v2.data[i];
        dist_sum += delta * delta;
    }
    
    return Value.init_double(@sqrt(dist_sum));
}

fn angle_between_impl(_: i32, args: [*]Value) Value {
    if (!Value.is_obj_type(args[0], .OBJ_FVECTOR) or !Value.is_obj_type(args[1], .OBJ_FVECTOR)) {
        return stdlib_core.stdlib_error("angle_between() requires two vectors!", .{});
    }
    
    const v1 = args[0].as_vector();
    const v2 = args[1].as_vector();
    
    if (v1.size != v2.size) {
        return stdlib_core.stdlib_error("angle_between() requires vectors of same size!", .{});
    }
    
    // Compute dot product
    var dot_prod: f64 = 0.0;
    for (0..v1.size) |i| {
        dot_prod += v1.data[i] * v2.data[i];
    }
    
    // Compute magnitudes
    var mag1: f64 = 0.0;
    var mag2: f64 = 0.0;
    for (0..v1.size) |i| {
        mag1 += v1.data[i] * v1.data[i];
        mag2 += v2.data[i] * v2.data[i];
    }
    mag1 = @sqrt(mag1);
    mag2 = @sqrt(mag2);
    
    if (mag1 == 0.0 or mag2 == 0.0) {
        return stdlib_core.stdlib_error("Cannot compute angle with zero vector!", .{});
    }
    
    // Compute angle
    const cos_theta = dot_prod / (mag1 * mag2);
    // Clamp to [-1, 1] to handle floating point errors
    const clamped = @max(-1.0, @min(1.0, cos_theta));
    
    return Value.init_double(std.math.acos(clamped));
}

fn project_impl(_: i32, args: [*]Value) Value {
    if (!Value.is_obj_type(args[0], .OBJ_FVECTOR) or !Value.is_obj_type(args[1], .OBJ_FVECTOR)) {
        return stdlib_core.stdlib_error("project() requires two vectors!", .{});
    }
    
    const v1 = args[0].as_vector();
    const v2 = args[1].as_vector();
    
    if (v1.size != v2.size) {
        return stdlib_core.stdlib_error("project() requires vectors of same size!", .{});
    }
    
    // Compute dot products
    var dot_v1_v2: f64 = 0.0;
    var dot_v2_v2: f64 = 0.0;
    for (0..v1.size) |i| {
        dot_v1_v2 += v1.data[i] * v2.data[i];
        dot_v2_v2 += v2.data[i] * v2.data[i];
    }
    
    if (dot_v2_v2 == 0.0) {
        return stdlib_core.stdlib_error("Cannot project onto zero vector!", .{});
    }
    
    const scalar = dot_v1_v2 / dot_v2_v2;
    const result = fvector.FloatVector.init(v1.size);
    for (0..v1.size) |i| {
        result.data[i] = scalar * v2.data[i];
    }
    result.size = v1.size;
    
    return Value.init_obj(@ptrCast(result));
}

fn reject_impl(_: i32, args: [*]Value) Value {
    if (!Value.is_obj_type(args[0], .OBJ_FVECTOR) or !Value.is_obj_type(args[1], .OBJ_FVECTOR)) {
        return stdlib_core.stdlib_error("reject() requires two vectors!", .{});
    }
    
    const v1 = args[0].as_vector();
    const v2 = args[1].as_vector();
    
    if (v1.size != v2.size) {
        return stdlib_core.stdlib_error("reject() requires vectors of same size!", .{});
    }
    
    // Compute projection
    var dot_v1_v2: f64 = 0.0;
    var dot_v2_v2: f64 = 0.0;
    for (0..v1.size) |i| {
        dot_v1_v2 += v1.data[i] * v2.data[i];
        dot_v2_v2 += v2.data[i] * v2.data[i];
    }
    
    if (dot_v2_v2 == 0.0) {
        return stdlib_core.stdlib_error("Cannot reject from zero vector!", .{});
    }
    
    const scalar = dot_v1_v2 / dot_v2_v2;
    
    // Compute rejection: v1 - proj
    const result = fvector.FloatVector.init(v1.size);
    for (0..v1.size) |i| {
        result.data[i] = v1.data[i] - scalar * v2.data[i];
    }
    result.size = v1.size;
    
    return Value.init_obj(@ptrCast(result));
}

fn lerp_impl(_: i32, args: [*]Value) Value {
    const t = args[2].as_num_double();
    
    // Check if both are vectors
    if (Value.is_obj_type(args[0], .OBJ_FVECTOR) and Value.is_obj_type(args[1], .OBJ_FVECTOR)) {
        const v1 = args[0].as_vector();
        const v2 = args[1].as_vector();
        
        if (v1.size != v2.size) {
            return stdlib_core.stdlib_error("lerp() requires vectors of same size!", .{});
        }
        
        const result = fvector.FloatVector.init(v1.size);
        for (0..v1.size) |i| {
            result.data[i] = v1.data[i] * (1.0 - t) + v2.data[i] * t;
        }
        result.size = v1.size;
        
        return Value.init_obj(@ptrCast(result));
    }
    
    // Scalar lerp
    const a = args[0].as_num_double();
    const b = args[1].as_num_double();
    return Value.init_double(a * (1.0 - t) + b * t);
}

// ===== Phase 3: Advanced Statistics & Data Analysis =====

fn median_impl(_: i32, args: [*]Value) Value {
    if (!Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        return stdlib_core.stdlib_error("median() requires a vector!", .{});
    }
    
    const v = args[0].as_vector();
    if (v.size == 0) {
        return stdlib_core.stdlib_error("Cannot compute median of empty vector!", .{});
    }
    
    // Clone and sort the vector
    const sorted = fvector.FloatVector.init(v.size);
    for (0..v.size) |i| {
        sorted.data[i] = v.data[i];
    }
    sorted.size = v.size;
    sorted.sort();
    
    const mid = v.size / 2;
    if (v.size % 2 == 0) {
        // Even: average of two middle elements
        return Value.init_double((sorted.data[mid - 1] + sorted.data[mid]) / 2.0);
    } else {
        // Odd: middle element
        return Value.init_double(sorted.data[mid]);
    }
}

fn mode_impl(_: i32, args: [*]Value) Value {
    if (!Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        return stdlib_core.stdlib_error("mode() requires a vector!", .{});
    }
    
    const v = args[0].as_vector();
    if (v.size == 0) {
        return stdlib_core.stdlib_error("Cannot compute mode of empty vector!", .{});
    }
    
    // Clone and sort
    const sorted = fvector.FloatVector.init(v.size);
    for (0..v.size) |i| {
        sorted.data[i] = v.data[i];
    }
    sorted.size = v.size;
    sorted.sort();
    
    // Find mode
    var max_count: usize = 1;
    var current_count: usize = 1;
    var mode_value = sorted.data[0];
    
    for (1..sorted.size) |i| {
        if (sorted.data[i] == sorted.data[i - 1]) {
            current_count += 1;
            if (current_count > max_count) {
                max_count = current_count;
                mode_value = sorted.data[i];
            }
        } else {
            current_count = 1;
        }
    }
    
    return Value.init_double(mode_value);
}

fn percentile_impl(_: i32, args: [*]Value) Value {
    if (!Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        return stdlib_core.stdlib_error("percentile() requires a vector!", .{});
    }
    
    const v = args[0].as_vector();
    const p = args[1].as_num_double();
    
    if (v.size == 0) {
        return stdlib_core.stdlib_error("Cannot compute percentile of empty vector!", .{});
    }
    
    if (p < 0.0 or p > 100.0) {
        return stdlib_core.stdlib_error("Percentile must be in range [0, 100]!", .{});
    }
    
    // Clone and sort
    const sorted = fvector.FloatVector.init(v.size);
    for (0..v.size) |i| {
        sorted.data[i] = v.data[i];
    }
    sorted.size = v.size;
    sorted.sort();
    
    // Linear interpolation method
    const rank = (p / 100.0) * @as(f64, @floatFromInt(v.size - 1));
    const lower_idx = @as(usize, @intFromFloat(@floor(rank)));
    const upper_idx = @min(lower_idx + 1, v.size - 1);
    const frac = rank - @floor(rank);
    
    const result = sorted.data[lower_idx] * (1.0 - frac) + sorted.data[upper_idx] * frac;
    return Value.init_double(result);
}

fn quantile_impl(_: i32, args: [*]Value) Value {
    if (!Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        return stdlib_core.stdlib_error("quantile() requires a vector!", .{});
    }
    
    const v = args[0].as_vector();
    const q = args[1].as_num_double();
    
    if (v.size == 0) {
        return stdlib_core.stdlib_error("Cannot compute quantile of empty vector!", .{});
    }
    
    if (q < 0.0 or q > 1.0) {
        return stdlib_core.stdlib_error("Quantile must be in range [0, 1]!", .{});
    }
    
    // Clone and sort
    const sorted = fvector.FloatVector.init(v.size);
    for (0..v.size) |i| {
        sorted.data[i] = v.data[i];
    }
    sorted.size = v.size;
    sorted.sort();
    
    // Linear interpolation
    const rank = q * @as(f64, @floatFromInt(v.size - 1));
    const lower_idx = @as(usize, @intFromFloat(@floor(rank)));
    const upper_idx = @min(lower_idx + 1, v.size - 1);
    const frac = rank - @floor(rank);
    
    const result = sorted.data[lower_idx] * (1.0 - frac) + sorted.data[upper_idx] * frac;
    return Value.init_double(result);
}

fn covariance_impl(_: i32, args: [*]Value) Value {
    if (!Value.is_obj_type(args[0], .OBJ_FVECTOR) or !Value.is_obj_type(args[1], .OBJ_FVECTOR)) {
        return stdlib_core.stdlib_error("covariance() requires two vectors!", .{});
    }
    
    const v1 = args[0].as_vector();
    const v2 = args[1].as_vector();
    
    if (v1.size != v2.size) {
        return stdlib_core.stdlib_error("covariance() requires vectors of same size!", .{});
    }
    
    if (v1.size == 0) {
        return stdlib_core.stdlib_error("Cannot compute covariance of empty vectors!", .{});
    }
    
    // Compute means
    const mean1 = v1.mean();
    const mean2 = v2.mean();
    
    // Compute covariance
    var cov: f64 = 0.0;
    for (0..v1.size) |i| {
        cov += (v1.data[i] - mean1) * (v2.data[i] - mean2);
    }
    cov /= @as(f64, @floatFromInt(v1.size));
    
    return Value.init_double(cov);
}

fn correlation_impl(_: i32, args: [*]Value) Value {
    if (!Value.is_obj_type(args[0], .OBJ_FVECTOR) or !Value.is_obj_type(args[1], .OBJ_FVECTOR)) {
        return stdlib_core.stdlib_error("correlation() requires two vectors!", .{});
    }
    
    const v1 = args[0].as_vector();
    const v2 = args[1].as_vector();
    
    if (v1.size != v2.size) {
        return stdlib_core.stdlib_error("correlation() requires vectors of same size!", .{});
    }
    
    if (v1.size == 0) {
        return stdlib_core.stdlib_error("Cannot compute correlation of empty vectors!", .{});
    }
    
    // Compute means and standard deviations
    const mean1 = v1.mean();
    const mean2 = v2.mean();
    const std1 = v1.std_dev();
    const std2 = v2.std_dev();
    
    if (std1 == 0.0 or std2 == 0.0) {
        return stdlib_core.stdlib_error("Cannot compute correlation with zero variance!", .{});
    }
    
    // Compute correlation
    var corr: f64 = 0.0;
    for (0..v1.size) |i| {
        corr += (v1.data[i] - mean1) * (v2.data[i] - mean2);
    }
    corr /= @as(f64, @floatFromInt(v1.size));
    corr /= (std1 * std2);
    
    return Value.init_double(corr);
}

fn cumsum_impl(_: i32, args: [*]Value) Value {
    if (!Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        return stdlib_core.stdlib_error("cumsum() requires a vector!", .{});
    }
    
    const v = args[0].as_vector();
    const result = fvector.FloatVector.init(v.size);
    
    var cum: f64 = 0.0;
    for (0..v.size) |i| {
        cum += v.data[i];
        result.data[i] = cum;
    }
    result.size = v.size;
    
    return Value.init_obj(@ptrCast(result));
}

fn cumprod_impl(_: i32, args: [*]Value) Value {
    if (!Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        return stdlib_core.stdlib_error("cumprod() requires a vector!", .{});
    }
    
    const v = args[0].as_vector();
    const result = fvector.FloatVector.init(v.size);
    
    var prod: f64 = 1.0;
    for (0..v.size) |i| {
        prod *= v.data[i];
        result.data[i] = prod;
    }
    result.size = v.size;
    
    return Value.init_obj(@ptrCast(result));
}

fn diff_impl(_: i32, args: [*]Value) Value {
    if (!Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        return stdlib_core.stdlib_error("diff() requires a vector!", .{});
    }
    
    const v = args[0].as_vector();
    if (v.size < 2) {
        return stdlib_core.stdlib_error("diff() requires at least 2 elements!", .{});
    }
    
    const result = fvector.FloatVector.init(v.size - 1);
    for (0..v.size - 1) |i| {
        result.data[i] = v.data[i + 1] - v.data[i];
    }
    result.size = v.size - 1;
    
    return Value.init_obj(@ptrCast(result));
}

fn histogram_impl(_: i32, args: [*]Value) Value {
    if (!Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        return stdlib_core.stdlib_error("histogram() requires a vector!", .{});
    }
    
    const v = args[0].as_vector();
    const bins_count = @as(usize, @intCast(args[1].as_num_int()));
    
    if (v.size == 0) {
        return stdlib_core.stdlib_error("Cannot compute histogram of empty vector!", .{});
    }
    
    if (bins_count == 0) {
        return stdlib_core.stdlib_error("Number of bins must be positive!", .{});
    }
    
    // Find min and max
    var min_val = v.data[0];
    var max_val = v.data[0];
    for (0..v.size) |i| {
        if (v.data[i] < min_val) min_val = v.data[i];
        if (v.data[i] > max_val) max_val = v.data[i];
    }
    
    const bin_width = (max_val - min_val) / @as(f64, @floatFromInt(bins_count));
    const result = fvector.FloatVector.init(bins_count);
    
    // Initialize bins to zero
    for (0..bins_count) |i| {
        result.data[i] = 0.0;
    }
    
    // Count values in each bin
    for (0..v.size) |i| {
        var bin_idx: usize = 0;
        if (bin_width > 0.0) {
            bin_idx = @intFromFloat(@floor((v.data[i] - min_val) / bin_width));
            if (bin_idx >= bins_count) bin_idx = bins_count - 1;
        }
        result.data[bin_idx] += 1.0;
    }
    result.size = bins_count;
    
    return Value.init_obj(@ptrCast(result));
}

fn moving_average_impl(_: i32, args: [*]Value) Value {
    if (!Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        return stdlib_core.stdlib_error("moving_average() requires a vector!", .{});
    }
    
    const v = args[0].as_vector();
    const window = @as(usize, @intCast(args[1].as_num_int()));
    
    if (window == 0) {
        return stdlib_core.stdlib_error("Window size must be positive!", .{});
    }
    
    if (window > v.size) {
        return stdlib_core.stdlib_error("Window size cannot exceed vector size!", .{});
    }
    
    const result = fvector.FloatVector.init(v.size - window + 1);
    
    for (0..result.size) |i| {
        var avg: f64 = 0.0;
        for (0..window) |j| {
            avg += v.data[i + j];
        }
        result.data[i] = avg / @as(f64, @floatFromInt(window));
    }
    result.size = v.size - window + 1;
    
    return Value.init_obj(@ptrCast(result));
}

// Public function wrappers with metadata

pub const linked_list = DefineFunction(
    "linked_list",
    "collections",
    "Create a new empty linked list",
    NoParams,
    .object,
    &[_][]const u8{
        "linked_list() -> [empty list]",
    },
    linked_list_impl,
);

pub const hash_table = DefineFunction(
    "hash_table",
    "collections",
    "Create a new empty hash table",
    NoParams,
    .object,
    &[_][]const u8{
        "hash_table() -> {empty table}",
    },
    hash_table_impl,
);

pub const fvec = DefineFunction(
    "fvec",
    "collections",
    "Create a new float vector with specified capacity",
    OneNumber,
    .object,
    &[_][]const u8{
        "fvec(10) -> [vector with capacity 10]",
        "fvec(0) -> [empty vector]",
    },
    fvec_impl,
);

pub const push = DefineFunction(
    "push",
    "collections",
    "Add one or more elements to the end of a list or vector",
    &[_]ParamSpec{
        .{ .name = "collection", .type = .object },
        .{ .name = "values", .type = .any }, // Variadic
    },
    .nil,
    &[_][]const u8{
        "push(list, 1, 2, 3) -> nil",
        "push(vector, 1.5, 2.7) -> nil",
    },
    push_impl,
);

pub const pop = DefineFunction(
    "pop",
    "collections",
    "Remove and return the last element from a list or vector",
    &[_]ParamSpec{
        .{ .name = "collection", .type = .object },
    },
    .any,
    &[_][]const u8{
        "pop(list) -> last_element",
        "pop(vector) -> 3.14",
    },
    pop_impl,
);

pub const push_front = DefineFunction(
    "push_front",
    "collections",
    "Add an element to the front of a list or vector",
    &[_]ParamSpec{
        .{ .name = "collection", .type = .object },
        .{ .name = "value", .type = .any },
    },
    .nil,
    &[_][]const u8{
        "push_front(list, 42) -> nil",
        "push_front(vector, 1.5) -> nil",
    },
    push_front_impl,
);

pub const pop_front = DefineFunction(
    "pop_front",
    "collections",
    "Remove and return the first element from a list or vector",
    &[_]ParamSpec{
        .{ .name = "collection", .type = .object },
    },
    .any,
    &[_][]const u8{
        "pop_front(list) -> first_element",
        "pop_front(vector) -> 1.5",
    },
    pop_front_impl,
);

pub const len = DefineFunction(
    "len",
    "collections",
    "Get the length of a collection or string",
    &[_]ParamSpec{
        .{ .name = "collection", .type = .any },
    },
    .int,
    &[_][]const u8{
        "len(\"hello\") -> 5",
        "len(list) -> 3",
        "len(vector) -> 10",
        "len(table) -> 2",
    },
    len_impl,
);

pub const get = DefineFunction(
    "get",
    "collections",
    "Get an element from a collection by index or key",
    &[_]ParamSpec{
        .{ .name = "collection", .type = .object },
        .{ .name = "index_or_key", .type = .any },
    },
    .any,
    &[_][]const u8{
        "get(list, 0) -> first_element",
        "get(vector, 2) -> 3.14",
        "get(table, \"key\") -> value",
    },
    get_impl,
);

pub const set = DefineFunction(
    "set",
    "collections",
    "Set an element in a collection by index or key",
    &[_]ParamSpec{
        .{ .name = "collection", .type = .object },
        .{ .name = "index_or_key", .type = .any },
        .{ .name = "value", .type = .any },
    },
    .nil,
    &[_][]const u8{
        "set(list, 0, 42) -> nil",
        "set(vector, 2, 3.14) -> nil",
        "set(table, \"key\", \"value\") -> nil",
    },
    set_impl,
);

pub const contains = DefineFunction(
    "contains",
    "collections",
    "Check if a collection contains a value or key",
    &[_]ParamSpec{
        .{ .name = "collection", .type = .any },
        .{ .name = "value_or_key", .type = .any },
    },
    .bool,
    &[_][]const u8{
        "contains(list, 42) -> true",
        "contains(table, \"key\") -> false",
        "contains(\"hello\", \"ell\") -> true",
    },
    contains_impl,
);

pub const clear = DefineFunction(
    "clear",
    "collections",
    "Remove all elements from a collection",
    &[_]ParamSpec{
        .{ .name = "collection", .type = .object },
    },
    .nil,
    &[_][]const u8{
        "clear(list) -> nil",
        "clear(vector) -> nil",
        "clear(table) -> nil",
    },
    clear_impl,
);

pub const range = DefineFunction(
    "range",
    "collections",
    "Create a range object for iteration",
    &[_]ParamSpec{
        .{ .name = "start_or_end", .type = .int },
        .{ .name = "end", .type = .int, .optional = true },
        .{ .name = "step", .type = .int, .optional = true },
    },
    .object,
    &[_][]const u8{
        "range(5) -> 0..5",
        "range(1, 10) -> 1..10",
        "range(0, 10, 2) -> 0,2,4,6,8",
    },
    range_impl,
);

pub const range_to_array = DefineFunction(
    "range_to_array",
    "collections",
    "Convert a range object to an array (vector)",
    &[_]ParamSpec{
        .{ .name = "range", .type = .object },
    },
    .object,
    &[_][]const u8{
        "range_to_array(1..5) -> [1, 2, 3, 4]",
        "range_to_array(1..=5) -> [1, 2, 3, 4, 5]",
        "range_to_array(range(0, 10, 2)) -> [0, 2, 4, 6, 8]",
    },
    range_to_array_impl,
);

pub const put = DefineFunction(
    "put",
    "collections",
    "Add a key-value pair to a hash table",
    &[_]ParamSpec{
        .{ .name = "table", .type = .object },
        .{ .name = "key", .type = .string },
        .{ .name = "value", .type = .any },
    },
    .nil,
    &[_][]const u8{
        "put(table, \"key\", \"value\") -> nil",
        "put(ht, \"count\", 42) -> nil",
    },
    put_impl,
);

pub const pairs = DefineFunction(
    "pairs",
    "collections",
    "Convert a hash table to a list of key-value pairs",
    &[_]ParamSpec{
        .{ .name = "table", .type = .object },
    },
    .object,
    &[_][]const u8{
        "pairs(hash_table) -> list_of_pairs",
        "pairs(ht) -> [(key1, val1), (key2, val2)]",
    },
    pairs_impl,
);

pub const is_empty = DefineFunction(
    "is_empty",
    "collections",
    "Check if a collection is empty",
    &[_]ParamSpec{
        .{ .name = "collection", .type = .any },
    },
    .bool,
    &[_][]const u8{
        "is_empty(list) -> true",
        "is_empty(vector) -> false",
        "is_empty(\"\") -> true",
    },
    is_empty_impl,
);

pub const nth = DefineFunction(
    "nth",
    "collections",
    "Get the nth element from a collection",
    &[_]ParamSpec{
        .{ .name = "collection", .type = .object },
        .{ .name = "index", .type = .int },
    },
    .any,
    &[_][]const u8{
        "nth(list, 0) -> first_element",
        "nth(vector, 2) -> third_element",
    },
    nth_impl,
);

pub const linspace = DefineFunction(
    "linspace",
    "collections",
    "Create evenly spaced values between start and end",
    &[_]ParamSpec{
        .{ .name = "start", .type = .number },
        .{ .name = "end", .type = .number },
        .{ .name = "count", .type = .int },
    },
    .object,
    &[_][]const u8{
        "linspace(0.0, 10.0, 5) -> [0, 2.5, 5, 7.5, 10]",
        "linspace(1.0, 5.0, 5) -> [1, 2, 3, 4, 5]",
    },
    linspace_impl,
);

pub const insert = DefineFunction(
    "insert",
    "collections",
    "Insert a value at the specified index",
    &[_]ParamSpec{
        .{ .name = "collection", .type = .object },
        .{ .name = "index", .type = .int },
        .{ .name = "value", .type = .number },
    },
    .nil,
    &[_][]const u8{
        "insert(vector, 2, 3.14) -> nil",
        "insert(list, 0, 42) -> nil",
    },
    insert_impl,
);

pub const remove = DefineFunction(
    "remove",
    "collections",
    "Remove and return the value at the specified index",
    &[_]ParamSpec{
        .{ .name = "collection", .type = .object },
        .{ .name = "index", .type = .int },
    },
    .any,
    &[_][]const u8{
        "remove(vector, 2) -> 3.14",
        "remove(list, 0) -> first_element",
    },
    remove_impl,
);

pub const slice = DefineFunction(
    "slice",
    "collections",
    "Extract a portion of a vector from start to end index",
    &[_]ParamSpec{
        .{ .name = "vector", .type = .object },
        .{ .name = "start", .type = .int },
        .{ .name = "end", .type = .int },
    },
    .object,
    &[_][]const u8{
        "slice(vector, 0, 3) -> first 4 elements",
        "slice(v, 2, 5) -> elements at indices 2-5",
    },
    slice_impl,
);

pub const merge = DefineFunction(
    "merge",
    "collections",
    "Merge two vectors into a new vector",
    &[_]ParamSpec{
        .{ .name = "vector1", .type = .object },
        .{ .name = "vector2", .type = .object },
    },
    .object,
    &[_][]const u8{
        "merge(v1, v2) -> combined vector",
        "merge([1,2], [3,4]) -> [1,2,3,4]",
    },
    merge_impl,
);

pub const search = DefineFunction(
    "search",
    "collections",
    "Find the index of a value in a collection",
    &[_]ParamSpec{
        .{ .name = "collection", .type = .object },
        .{ .name = "value", .type = .number },
    },
    .int,
    &[_][]const u8{
        "search(vector, 3.14) -> 2",
        "search(list, 42) -> 0",
    },
    search_impl,
);

pub const sort = DefineFunction(
    "sort",
    "collections",
    "Sort a collection in place",
    &[_]ParamSpec{
        .{ .name = "collection", .type = .object },
    },
    .nil,
    &[_][]const u8{
        "sort(vector) -> nil (vector is sorted)",
        "sort(list) -> nil (list is sorted)",
    },
    sort_impl,
);

pub const sum = DefineFunction(
    "sum",
    "collections",
    "Calculate the sum of all elements in a vector",
    &[_]ParamSpec{
        .{ .name = "vector", .type = .object },
    },
    .double,
    &[_][]const u8{
        "sum([1, 2, 3, 4]) -> 10.0",
        "sum(linspace(1, 4, 4)) -> 10.0",
    },
    sum_impl,
);

pub const mean = DefineFunction(
    "mean",
    "collections",
    "Calculate the mean (average) of all elements in a vector",
    &[_]ParamSpec{
        .{ .name = "vector", .type = .object },
    },
    .double,
    &[_][]const u8{
        "mean([1, 2, 3, 4]) -> 2.5",
        "mean(linspace(1, 4, 4)) -> 2.5",
    },
    mean_impl,
);

pub const vari = DefineFunction(
    "vari",
    "collections",
    "Calculate the variance of all elements in a vector",
    &[_]ParamSpec{
        .{ .name = "vector", .type = .object },
    },
    .double,
    &[_][]const u8{
        "vari([1, 2, 3, 4]) -> 1.25",
        "vari(linspace(1, 4, 4)) -> 1.25",
    },
    vari_impl,
);

pub const stddev = DefineFunction(
    "stddev",
    "collections",
    "Calculate the standard deviation of all elements in a vector",
    &[_]ParamSpec{
        .{ .name = "vector", .type = .object },
    },
    .double,
    &[_][]const u8{
        "stddev([1, 2, 3, 4]) -> 1.118",
        "stddev(linspace(1, 4, 4)) -> 1.118",
    },
    std_impl,
);

pub const minl = DefineFunction(
    "minl",
    "collections",
    "Find the minimum value in a vector",
    &[_]ParamSpec{
        .{ .name = "vector", .type = .object },
    },
    .double,
    &[_][]const u8{
        "minl([3, 1, 4, 2]) -> 1.0",
        "minl(linspace(1, 4, 4)) -> 1.0",
    },
    minl_impl,
);

pub const maxl = DefineFunction(
    "maxl",
    "collections",
    "Find the maximum value in a vector",
    &[_]ParamSpec{
        .{ .name = "vector", .type = .object },
    },
    .double,
    &[_][]const u8{
        "maxl([3, 1, 4, 2]) -> 4.0",
        "maxl(linspace(1, 4, 4)) -> 4.0",
    },
    maxl_impl,
);

pub const splice = DefineFunction(
    "splice",
    "collections",
    "Remove and return a portion of a vector from start to end index",
    &[_]ParamSpec{
        .{ .name = "vector", .type = .object },
        .{ .name = "start", .type = .int },
        .{ .name = "end", .type = .int },
    },
    .object,
    &[_][]const u8{
        "splice(vector, 0, 3) -> removes first 4 elements",
        "splice(v, 2, 5) -> removes elements at indices 2-5",
    },
    splice_impl,
);

pub const std_alias = DefineFunction(
    "std",
    "collections",
    "Calculate the standard deviation of all elements in a vector (alias for stddev)",
    &[_]ParamSpec{
        .{ .name = "vector", .type = .object },
    },
    .double,
    &[_][]const u8{
        "std([1, 2, 3, 4]) -> 1.118",
        "std(linspace(1, 4, 4)) -> 1.118",
    },
    std_impl,
);

pub const reverse = DefineFunction(
    "reverse",
    "collections",
    "Reverse the order of elements in a collection in place",
    &[_]ParamSpec{
        .{ .name = "collection", .type = .object },
    },
    .nil,
    &[_][]const u8{
        "reverse(vector) -> nil (vector is reversed)",
        "reverse(list) -> nil (list is reversed)",
    },
    reverse_impl,
);

// ===== Phase 2: Vector Math Operations =====

pub const dot = DefineFunction(
    "dot",
    "collections",
    "Compute dot product of two vectors",
    &[_]ParamSpec{
        .{ .name = "v1", .type = .object },
        .{ .name = "v2", .type = .object },
    },
    .double,
    &[_][]const u8{
        "dot({1, 2, 3}, {4, 5, 6}) -> 32.0",
        "dot({1, 0}, {0, 1}) -> 0.0",
    },
    dot_impl,
);

pub const cross = DefineFunction(
    "cross",
    "collections",
    "Compute cross product of two 3D vectors",
    &[_]ParamSpec{
        .{ .name = "v1", .type = .object },
        .{ .name = "v2", .type = .object },
    },
    .object,
    &[_][]const u8{
        "cross({1, 0, 0}, {0, 1, 0}) -> {0, 0, 1}",
        "cross({1, 2, 3}, {4, 5, 6}) -> {-3, 6, -3}",
    },
    cross_impl,
);

pub const magnitude = DefineFunction(
    "magnitude",
    "collections",
    "Compute magnitude (length) of a vector",
    &[_]ParamSpec{
        .{ .name = "vector", .type = .object },
    },
    .double,
    &[_][]const u8{
        "magnitude({3, 4}) -> 5.0",
        "magnitude({1, 1, 1}) -> 1.732",
    },
    magnitude_impl,
);

pub const normalize = DefineFunction(
    "normalize",
    "collections",
    "Return unit vector in the same direction",
    &[_]ParamSpec{
        .{ .name = "vector", .type = .object },
    },
    .object,
    &[_][]const u8{
        "normalize({3, 4}) -> {0.6, 0.8}",
        "normalize({1, 1}) -> {0.707, 0.707}",
    },
    normalize_impl,
);

pub const distance = DefineFunction(
    "distance",
    "collections",
    "Compute Euclidean distance between two vectors",
    &[_]ParamSpec{
        .{ .name = "v1", .type = .object },
        .{ .name = "v2", .type = .object },
    },
    .double,
    &[_][]const u8{
        "distance({0, 0}, {3, 4}) -> 5.0",
        "distance({1, 2, 3}, {4, 5, 6}) -> 5.196",
    },
    distance_impl,
);

pub const angle_between = DefineFunction(
    "angle_between",
    "collections",
    "Compute angle in radians between two vectors",
    &[_]ParamSpec{
        .{ .name = "v1", .type = .object },
        .{ .name = "v2", .type = .object },
    },
    .double,
    &[_][]const u8{
        "angle_between({1, 0}, {0, 1}) -> 1.5708",
        "angle_between({1, 1}, {1, 0}) -> 0.7854",
    },
    angle_between_impl,
);

pub const project = DefineFunction(
    "project",
    "collections",
    "Project vector v1 onto vector v2",
    &[_]ParamSpec{
        .{ .name = "v1", .type = .object },
        .{ .name = "v2", .type = .object },
    },
    .object,
    &[_][]const u8{
        "project({3, 4}, {1, 0}) -> {3, 0}",
        "project({2, 3}, {1, 1}) -> {2.5, 2.5}",
    },
    project_impl,
);

pub const reject = DefineFunction(
    "reject",
    "collections",
    "Reject vector v1 from vector v2 (orthogonal component)",
    &[_]ParamSpec{
        .{ .name = "v1", .type = .object },
        .{ .name = "v2", .type = .object },
    },
    .object,
    &[_][]const u8{
        "reject({3, 4}, {1, 0}) -> {0, 4}",
        "reject({2, 3}, {1, 1}) -> {-0.5, 0.5}",
    },
    reject_impl,
);

pub const lerp = DefineFunction(
    "lerp",
    "collections",
    "Linear interpolation between two values or vectors",
    &[_]ParamSpec{
        .{ .name = "a", .type = .any },
        .{ .name = "b", .type = .any },
        .{ .name = "t", .type = .number },
    },
    .any,
    &[_][]const u8{
        "lerp(0, 10, 0.5) -> 5.0",
        "lerp({0, 0}, {10, 10}, 0.25) -> {2.5, 2.5}",
    },
    lerp_impl,
);

// ===== Phase 3: Advanced Statistics & Data Analysis =====

pub const median = DefineFunction(
    "median",
    "collections",
    "Compute median (50th percentile) of a vector",
    &[_]ParamSpec{
        .{ .name = "vector", .type = .object },
    },
    .double,
    &[_][]const u8{
        "median({1, 2, 3, 4, 5}) -> 3.0",
        "median({1, 2, 3, 4}) -> 2.5",
    },
    median_impl,
);

pub const mode = DefineFunction(
    "mode",
    "collections",
    "Find most frequent value in a vector",
    &[_]ParamSpec{
        .{ .name = "vector", .type = .object },
    },
    .double,
    &[_][]const u8{
        "mode({1, 2, 2, 3}) -> 2.0",
        "mode({5, 5, 5, 1, 2}) -> 5.0",
    },
    mode_impl,
);

pub const percentile = DefineFunction(
    "percentile",
    "collections",
    "Compute p-th percentile (0-100) of a vector",
    &[_]ParamSpec{
        .{ .name = "vector", .type = .object },
        .{ .name = "p", .type = .number },
    },
    .double,
    &[_][]const u8{
        "percentile({1, 2, 3, 4, 5}, 50) -> 3.0",
        "percentile({1, 2, 3, 4}, 75) -> 3.25",
    },
    percentile_impl,
);

pub const quantile = DefineFunction(
    "quantile",
    "collections",
    "Compute q-th quantile (0-1) of a vector",
    &[_]ParamSpec{
        .{ .name = "vector", .type = .object },
        .{ .name = "q", .type = .number },
    },
    .double,
    &[_][]const u8{
        "quantile({1, 2, 3, 4, 5}, 0.5) -> 3.0",
        "quantile({1, 2, 3, 4}, 0.75) -> 3.25",
    },
    quantile_impl,
);

pub const covariance = DefineFunction(
    "covariance",
    "collections",
    "Compute covariance between two vectors",
    &[_]ParamSpec{
        .{ .name = "v1", .type = .object },
        .{ .name = "v2", .type = .object },
    },
    .double,
    &[_][]const u8{
        "covariance({1, 2, 3}, {2, 4, 6}) -> 2.0",
        "covariance({1, 2, 3}, {3, 2, 1}) -> -1.0",
    },
    covariance_impl,
);

pub const correlation = DefineFunction(
    "correlation",
    "collections",
    "Compute Pearson correlation coefficient between two vectors",
    &[_]ParamSpec{
        .{ .name = "v1", .type = .object },
        .{ .name = "v2", .type = .object },
    },
    .double,
    &[_][]const u8{
        "correlation({1, 2, 3}, {2, 4, 6}) -> 1.0",
        "correlation({1, 2, 3}, {3, 2, 1}) -> -1.0",
    },
    correlation_impl,
);

pub const cumsum = DefineFunction(
    "cumsum",
    "collections",
    "Cumulative sum of vector elements",
    &[_]ParamSpec{
        .{ .name = "vector", .type = .object },
    },
    .object,
    &[_][]const u8{
        "cumsum({1, 2, 3, 4}) -> {1, 3, 6, 10}",
        "cumsum({1, 1, 1}) -> {1, 2, 3}",
    },
    cumsum_impl,
);

pub const cumprod = DefineFunction(
    "cumprod",
    "collections",
    "Cumulative product of vector elements",
    &[_]ParamSpec{
        .{ .name = "vector", .type = .object },
    },
    .object,
    &[_][]const u8{
        "cumprod({1, 2, 3, 4}) -> {1, 2, 6, 24}",
        "cumprod({2, 2, 2}) -> {2, 4, 8}",
    },
    cumprod_impl,
);

pub const diff = DefineFunction(
    "diff",
    "collections",
    "Differences between consecutive elements",
    &[_]ParamSpec{
        .{ .name = "vector", .type = .object },
    },
    .object,
    &[_][]const u8{
        "diff({1, 3, 7, 10}) -> {2, 4, 3}",
        "diff({10, 5, 8}) -> {-5, 3}",
    },
    diff_impl,
);

pub const histogram = DefineFunction(
    "histogram",
    "collections",
    "Bin vector data into histogram",
    &[_]ParamSpec{
        .{ .name = "vector", .type = .object },
        .{ .name = "bins", .type = .int },
    },
    .object,
    &[_][]const u8{
        "histogram({1, 2, 3, 4, 5}, 2) -> counts per bin",
        "histogram(randn_vector, 10) -> 10 bins",
    },
    histogram_impl,
);

pub const moving_average = DefineFunction(
    "moving_average",
    "collections",
    "Simple moving average with specified window size",
    &[_]ParamSpec{
        .{ .name = "vector", .type = .object },
        .{ .name = "window", .type = .int },
    },
    .object,
    &[_][]const u8{
        "moving_average({1, 2, 3, 4, 5}, 3) -> {2, 3, 4}",
        "moving_average({1, 3, 5, 7}, 2) -> {2, 4, 6}",
    },
    moving_average_impl,
);
