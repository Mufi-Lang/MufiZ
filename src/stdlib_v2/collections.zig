const std = @import("std");
const Value = @import("../value.zig").Value;
const stdlib_v2 = @import("../stdlib_v2.zig");
const DefineFunction = stdlib_v2.DefineFunction;
const ParamSpec = stdlib_v2.ParamSpec;
const ParamType = stdlib_v2.ParamType;
const NoParams = stdlib_v2.NoParams;
const OneAny = stdlib_v2.OneAny;
const OneNumber = stdlib_v2.OneNumber;

const conv = @import("../conv.zig");
const mem_utils = @import("../mem_utils.zig");
const obj_h = @import("../object.zig");
const ObjType = obj_h.ObjType;
const ObjLinkedList = obj_h.LinkedList;
const ObjHashTable = obj_h.ObjHashTable;
const FloatVector = obj_h.FloatVector;
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
        return stdlib_v2.stdlib_error("fvec() capacity must be positive!", .{});
    }

    const vec = fvector.FloatVector.init(@intCast(capacity));
    return Value.init_obj(@ptrCast(vec));
}

fn push_impl(argc: i32, args: [*]Value) Value {
    if (!Value.is_obj_type(args[0], .OBJ_LINKED_LIST) and
        !Value.is_obj_type(args[0], .OBJ_FVECTOR))
    {
        return stdlib_v2.stdlib_error("First argument must be a list or vector!", .{});
    }

    if (Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        const vector = args[0].as_vector();
        for (1..@intCast(argc)) |i| {
            if (!args[i].is_prim_num()) {
                return stdlib_v2.stdlib_error("Vector values must be numeric!", .{});
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
        return stdlib_v2.stdlib_error("Argument must be a list or vector!", .{});
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
        return stdlib_v2.stdlib_error("First argument must be a list or vector!", .{});
    }

    if (Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        const vector = args[0].as_vector();
        if (!args[1].is_prim_num()) {
            return stdlib_v2.stdlib_error("Vector values must be numeric!", .{});
        }
        vector.push_front(args[1].as_num_double());
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
        return stdlib_v2.stdlib_error("Argument must be a list or vector!", .{});
    }

    if (Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        const vector = args[0].as_vector();
        return Value.init_double(vector.pop_front());
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
                return Value.init_int(@intCast(ObjLinkedList.length(list)));
            } else if (Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
                const vector = args[0].as_vector();
                return Value.init_int(@intCast(vector.size));
            } else if (Value.is_obj_type(args[0], .OBJ_HASH_TABLE)) {
                const table = args[0].as_hash_table();
                return Value.init_int(@intCast(ObjHashTable.size(table)));
            } else {
                return stdlib_v2.stdlib_error("Object type does not support length!", .{});
            }
        },
        else => return stdlib_v2.stdlib_error("Value does not support length!", .{}),
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
        return ObjHashTable.get(table, args[1]);
    } else {
        return stdlib_v2.stdlib_error("Object does not support indexing!", .{});
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
            return stdlib_v2.stdlib_error("Vector values must be numeric!", .{});
        }
        vector.set(@intCast(index), args[2].as_num_double());
    } else if (Value.is_obj_type(args[0], .OBJ_HASH_TABLE)) {
        const table = args[0].as_hash_table();
        ObjHashTable.set(table, args[1], args[2]);
    } else {
        return stdlib_v2.stdlib_error("Object does not support assignment!", .{});
    }

    return Value.init_nil();
}

fn contains_impl(argc: i32, args: [*]Value) Value {
    _ = argc;

    if (Value.is_obj_type(args[0], .OBJ_LINKED_LIST)) {
        const list = args[0].as_linked_list();
        return Value.init_bool(ObjLinkedList.contains(list, args[1]));
    } else if (Value.is_obj_type(args[0], .OBJ_HASH_TABLE)) {
        const table = args[0].as_hash_table();
        return Value.init_bool(ObjHashTable.contains(table, args[1]));
    } else if (Value.is_obj_type(args[0], .OBJ_STRING)) {
        const haystack = args[0].as_zstring();
        if (args[1].is_string()) {
            const needle = args[1].as_zstring();
            return Value.init_bool(std.mem.indexOf(u8, haystack, needle) != null);
        } else {
            return Value.init_bool(false);
        }
    } else {
        return stdlib_v2.stdlib_error("Object does not support contains!", .{});
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
        return stdlib_v2.stdlib_error("Object does not support clear!", .{});
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
        return stdlib_v2.stdlib_error("Range step cannot be zero!", .{});
    }

    const range_obj = ObjRange.init(start, end, step);
    return Value.init_obj(@ptrCast(range_obj));
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
