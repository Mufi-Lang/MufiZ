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
