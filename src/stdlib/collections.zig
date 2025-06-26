const std = @import("std");

const conv = @import("../conv.zig");
const type_check = conv.type_check;
const GlobalAlloc = @import("../main.zig").GlobalAlloc;
const reallocate = @import("../memory.zig").reallocate;
const obj_h = @import("../object.zig");
const ObjType = obj_h.ObjType;
const ObjLinkedList = obj_h.ObjLinkedList;
const ObjHashTable = obj_h.ObjHashTable;
const FloatVector = obj_h.FloatVector;
const fvector = @import("../objects/fvec.zig");
const ObjRange = @import("../objects/range.zig").ObjRange;
const stdlib_error = @import("../stdlib.zig").stdlib_error;
const Value = @import("../value.zig").Value;
const valuesEqual = @import("../value.zig").valuesEqual;

// linked_list() - Creates a new linked list
pub fn linked_list(argc: i32, args: [*]Value) Value {
    _ = args;
    if (argc != 0) return stdlib_error("linked_list() expects no arguments!", .{ .argn = argc });

    const ll: *ObjLinkedList = obj_h.newLinkedList();
    return Value.init_obj(@ptrCast(ll));
}

// hash_table() - Creates a new hash table
pub fn hash_table(argc: i32, args: [*]Value) Value {
    _ = args;
    if (argc != 0) return stdlib_error("hash_table() expects no arguments!", .{ .argn = argc });

    const ht: *ObjHashTable = obj_h.newHashTable();
    return Value.init_obj(@ptrCast(ht));
}

// fvec(capacity) - Creates a new float vector with specified capacity
pub fn fvec(argc: i32, args: [*]Value) Value {
    if (argc != 1) return stdlib_error("fvec() expects one argument!", .{ .argn = argc });
    if (!type_check(1, args, 6)) return stdlib_error("fvec() expects a Number!", .{ .value_type = conv.what_is(args[0]) });

    const capacity = args[0].as_num_int();
    if (capacity < 0) {
        return stdlib_error("fvec() capacity must be positive!", .{ .value_type = conv.what_is(args[0]) });
    }

    const vec = fvector.FloatVector.init(@intCast(capacity));
    return Value.init_obj(@ptrCast(vec));
}

// push(list, value, ...) - Adds elements to the end of a list
pub fn push(argc: i32, args: [*]Value) Value {
    if (argc < 2) return stdlib_error("push() expects at least two arguments!", .{ .argn = argc });

    if (!Value.is_obj_type(args[0], .OBJ_LINKED_LIST) and
        !Value.is_obj_type(args[0], .OBJ_FVECTOR))
    {
        return stdlib_error("First argument must be a list or vector!", .{ .value_type = conv.what_is(args[0]) });
    }

    if (Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        const vector = args[0].as_vector();
        for (1..@intCast(argc)) |i| {
            if (!type_check(1, args + i, 6)) {
                return stdlib_error("Vector values must be numeric!", .{ .value_type = conv.what_is(args[i]) });
            }
            vector.push(args[i].as_num_double());
        }
    } else if (Value.is_obj_type(args[0], .OBJ_LINKED_LIST)) {
        const list = args[0].as_linked_list();
        for (1..@intCast(argc)) |i| {
            obj_h.pushBack(list, args[i]);
        }
    }

    return Value.init_nil();
}

// pop(list) - Removes and returns the last element from a list
pub fn pop(argc: i32, args: [*]Value) Value {
    if (argc != 1) return stdlib_error("pop() expects one argument!", .{ .argn = argc });

    if (!Value.is_obj_type(args[0], .OBJ_LINKED_LIST) and
        !Value.is_obj_type(args[0], .OBJ_FVECTOR))
    {
        return stdlib_error("First argument must be a list or vector!", .{ .value_type = conv.what_is(args[0]) });
    }

    if (Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        const vector = args[0].as_vector();
        return Value.init_double(vector.pop());
    } else {
        const list = args[0].as_linked_list();
        return obj_h.popBack(list);
    }
}

// push_front(list, value) - Adds element to the front of a list or vector
pub fn push_front(argc: i32, args: [*]Value) Value {
    if (argc != 2) return stdlib_error("push_front() expects two arguments!", .{ .argn = argc });

    if (!Value.is_obj_type(args[0], .OBJ_LINKED_LIST) and
        !Value.is_obj_type(args[0], .OBJ_FVECTOR))
    {
        return stdlib_error("First argument must be a list or vector!", .{ .value_type = conv.what_is(args[0]) });
    }

    if (Value.is_obj_type(args[0], .OBJ_LINKED_LIST)) {
        const list = args[0].as_linked_list();
        obj_h.pushFront(list, args[1]);
    } else {
        // For vectors, we insert at index 0
        const vector = args[0].as_vector();
        if (!type_check(1, args + 1, 6)) {
            return stdlib_error("Vector values must be numeric!", .{ .value_type = conv.what_is(args[1]) });
        }
        vector.insert(0, args[1].as_num_double());
    }
    return Value.init_nil();
}

// pop_front(list) - Removes and returns the first element from a list or vector
pub fn pop_front(argc: i32, args: [*]Value) Value {
    if (argc != 1) return stdlib_error("pop_front() expects one argument!", .{ .argn = argc });

    if (!Value.is_obj_type(args[0], .OBJ_LINKED_LIST) and
        !Value.is_obj_type(args[0], .OBJ_FVECTOR))
    {
        return stdlib_error("First argument must be a list or vector!", .{ .value_type = conv.what_is(args[0]) });
    }

    if (Value.is_obj_type(args[0], .OBJ_LINKED_LIST)) {
        const list = args[0].as_linked_list();
        return obj_h.popFront(list);
    } else {
        const vector = args[0].as_vector();
        if (vector.count == 0) {
            return Value.init_nil();
        }
        const value = vector.get(0);
        _ = vector.remove(0);
        return Value.init_double(value);
    }
}

// len(collection) - Gets the length of a collection
pub fn len(argc: i32, args: [*]Value) Value {
    if (argc != 1) return stdlib_error("len() expects one argument!", .{ .argn = argc });

    if (!Value.is_obj_type(args[0], .OBJ_LINKED_LIST) and
        !Value.is_obj_type(args[0], .OBJ_FVECTOR) and
        !Value.is_obj_type(args[0], .OBJ_HASH_TABLE))
    {
        return stdlib_error("Argument must be a collection type!", .{ .value_type = conv.what_is(args[0]) });
    }

    if (Value.is_obj_type(args[0], .OBJ_HASH_TABLE)) {
        const table = args[0].as_hash_table();
        return Value.init_int(@intCast(table.table.count));
    } else if (Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        const vector = args[0].as_vector();
        return Value.init_int(@intCast(vector.count));
    } else {
        const list = args[0].as_linked_list();
        return Value.init_int(@intCast(list.count));
    }
}

// put(hash_table, key, value) - Puts a value into a hash table with the specified key
pub fn put(argc: i32, args: [*]Value) Value {
    if (argc != 3) return stdlib_error("put() expects three arguments!", .{ .argn = argc });

    if (!Value.is_obj_type(args[0], .OBJ_HASH_TABLE)) {
        return stdlib_error("First argument must be a hash table!", .{ .value_type = conv.what_is(args[0]) });
    }

    if (!Value.is_obj_type(args[1], .OBJ_STRING)) {
        return stdlib_error("Hash table key must be a string!", .{ .value_type = conv.what_is(args[1]) });
    }

    const table = args[0].as_hash_table();
    const key = args[1].as_string();

    _ = obj_h.putHashTable(table, key, args[2]);
    return Value.init_nil();
}

// remove(collection, key) - Removes a value from a collection
pub fn remove(argc: i32, args: [*]Value) Value {
    if (argc != 2) return stdlib_error("remove() expects two arguments!", .{ .argn = argc });

    if (!Value.is_obj_type(args[0], .OBJ_HASH_TABLE) and
        !Value.is_obj_type(args[0], .OBJ_FVECTOR))
    {
        return stdlib_error("First argument must be a hash table or vector!", .{ .value_type = conv.what_is(args[0]) });
    }

    if (Value.is_obj_type(args[0], .OBJ_HASH_TABLE)) {
        if (!Value.is_obj_type(args[1], .OBJ_STRING)) {
            return stdlib_error("Hash table key must be a string!", .{ .value_type = conv.what_is(args[1]) });
        }

        const table = args[0].as_hash_table();
        const key = args[1].as_string();

        return Value.init_bool(obj_h.removeHashTable(table, key));
    } else {
        if (!type_check(1, args + 1, 6)) {
            return stdlib_error("Vector index must be a number!", .{ .value_type = conv.what_is(args[1]) });
        }

        const vector = args[0].as_vector();
        const index = args[1].as_num_int();

        if (index < 0 or index >= vector.count) {
            return stdlib_error("Vector index out of bounds!", .{ .argn = index });
        }

        return Value.init_double(vector.remove(@intCast(index)));
    }
}

// get(hash_table, key) - Gets a value from a hash table by key
pub fn get(argc: i32, args: [*]Value) Value {
    if (argc != 2) return stdlib_error("get() expects two arguments!", .{ .argn = argc });

    if (!Value.is_obj_type(args[0], .OBJ_HASH_TABLE)) {
        return stdlib_error("First argument must be a hash table!", .{ .value_type = conv.what_is(args[0]) });
    }

    if (!Value.is_obj_type(args[1], .OBJ_STRING)) {
        return stdlib_error("Hash table key must be a string!", .{ .value_type = conv.what_is(args[1]) });
    }

    const table = args[0].as_hash_table();
    const key = args[1].as_string();

    return obj_h.getHashTable(table, key);
}

// nth(list, index) - Gets the element at the specified index
pub fn nth(argc: i32, args: [*]Value) Value {
    if (argc != 2) return stdlib_error("nth() expects two arguments!", .{ .argn = argc });

    if (!Value.is_obj_type(args[0], .OBJ_LINKED_LIST) and
        !Value.is_obj_type(args[0], .OBJ_FVECTOR))
    {
        return stdlib_error("First argument must be a list or vector!", .{ .value_type = conv.what_is(args[0]) });
    }

    if (!type_check(1, args + 1, 6)) {
        return stdlib_error("Index must be a number!", .{ .value_type = conv.what_is(args[1]) });
    }

    const index = args[1].as_num_int();

    if (Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        const vector = args[0].as_vector();
        if (index < 0 or index >= vector.count) {
            return stdlib_error("Vector index out of bounds!", .{ .argn = index });
        }
        return Value.init_double(vector.data[@intCast(index)]);
    } else {
        const list = args[0].as_linked_list();
        if (index < 0 or index >= list.count) {
            return stdlib_error("List index out of bounds!", .{ .argn = index });
        }

        var current = list.head;
        var i: i32 = 0;
        while (current != null and i < index) : (i += 1) {
            current = current.?.next;
        }

        return if (current != null) current.?.data else Value.init_nil();
    }
}

// insert(collection, index, value) - Inserts a value at the specified index
pub fn insert(argc: i32, args: [*]Value) Value {
    if (argc != 3) return stdlib_error("insert() expects three arguments!", .{ .argn = argc });

    if (!Value.is_obj_type(args[0], .OBJ_LINKED_LIST) and
        !Value.is_obj_type(args[0], .OBJ_FVECTOR))
    {
        return stdlib_error("First argument must be a list or vector!", .{ .value_type = conv.what_is(args[0]) });
    }

    if (!type_check(1, args + 1, 6)) {
        return stdlib_error("Index must be a number!", .{ .value_type = conv.what_is(args[1]) });
    }

    if (Value.is_obj_type(args[0], .OBJ_LINKED_LIST)) {
        const list = args[0].as_linked_list();
        const index = args[1].as_num_int();

        if (index < 0 or index > list.count) {
            return stdlib_error("List index out of bounds!", .{ .argn = index });
        }

        if (index == 0) {
            obj_h.pushFront(list, args[2]);
        } else if (index == list.count) {
            obj_h.pushBack(list, args[2]);
        } else {
            var current = list.head;
            var i: i32 = 0;
            while (current != null and i < index - 1) : (i += 1) {
                current = current.?.next;
            }

            if (current != null) {
                const node = @as(*obj_h.Node, @ptrCast(@alignCast(reallocate(null, 0, @sizeOf(obj_h.Node) *% 1))));
                node.data = args[2];
                node.next = current.?.next;
                node.prev = current;

                if (current.?.next != null) {
                    current.?.next.?.prev = node;
                }
                current.?.next = node;
                list.count += 1;
            }
        }
    } else {
        // Handle vector insertion
        const vector = args[0].as_vector();
        const index = args[1].as_num_int();

        if (index < 0 or index > vector.count) {
            return stdlib_error("Vector index out of bounds!", .{ .argn = index });
        }

        if (!type_check(1, args + 2, 6)) {
            return stdlib_error("Vector values must be numeric!", .{ .value_type = conv.what_is(args[2]) });
        }

        vector.insert(@intCast(index), args[2].as_num_double());
    }

    return Value.init_nil();
}

// contains(collection, value) - Checks if a collection contains the specified value
pub fn contains(argc: i32, args: [*]Value) Value {
    if (argc != 2) return stdlib_error("contains() expects two arguments!", .{ .argn = argc });

    if (!Value.is_obj_type(args[0], .OBJ_LINKED_LIST) and
        !Value.is_obj_type(args[0], .OBJ_HASH_TABLE) and
        !Value.is_obj_type(args[0], .OBJ_FVECTOR))
    {
        return stdlib_error("First argument must be a collection type!", .{ .value_type = conv.what_is(args[0]) });
    }

    if (Value.is_obj_type(args[0], .OBJ_HASH_TABLE)) {
        if (!Value.is_obj_type(args[1], .OBJ_STRING)) {
            return stdlib_error("Hash table key must be a string!", .{ .value_type = conv.what_is(args[1]) });
        }

        const table = args[0].as_hash_table();
        const key = args[1].as_string();

        return Value.init_bool(obj_h.getHashTable(table, key).type != .VAL_NIL);
    } else if (Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        if (!type_check(1, args + 1, 6)) {
            return stdlib_error("Vector value must be numeric!", .{ .value_type = conv.what_is(args[1]) });
        }

        const vector = args[0].as_vector();
        const value = args[1].as_num_double();

        for (0..vector.count) |i| {
            if (vector.data[i] == value) {
                return Value.init_bool(true);
            }
        }

        return Value.init_bool(false);
    } else {
        if (Value.is_obj_type(args[0], .OBJ_LINKED_LIST)) {
            const list = args[0].as_linked_list();
            var current = list.head;

            while (current != null) : (current = current.?.next) {
                if (valuesEqual(current.?.data, args[1])) {
                    return Value.init_bool(true);
                }
            }

            return Value.init_bool(false);
        }

        return Value.init_bool(false);
    }
}

// sort(list) - Sorts a list in place
pub fn sort(argc: i32, args: [*]Value) Value {
    if (argc != 1) return stdlib_error("sort() expects one argument!", .{ .argn = argc });

    if (Value.is_obj_type(args[0], .OBJ_LINKED_LIST)) {
        const list = args[0].as_linked_list();
        obj_h.mergeSort(list);

        // Update tail and fix prev pointers
        var current = list.head;
        var prev: ?*obj_h.Node = null;
        while (current != null) : (current = current.?.next) {
            current.?.prev = prev;
            prev = current;
            if (current.?.next == null) {
                list.tail = current;
            }
        }

        return Value.init_nil();
    } else if (Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        const vector = args[0].as_vector();
        vector.sort();
        return Value.init_nil();
    } else {
        return stdlib_error("Argument must be a list or vector!", .{ .value_type = conv.what_is(args[0]) });
    }
}

/// reverse(list) - Reverses a list in place
pub fn reverse(argc: i32, args: [*]Value) Value {
    if (argc != 1) return stdlib_error("reverse() expects one argument!", .{ .argn = argc });

    if (Value.is_obj_type(args[0], .OBJ_LINKED_LIST)) {
        const list = args[0].as_linked_list();
        obj_h.reverseLinkedList(list);
        return Value.init_nil();
    } else if (Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        const vector = args[0].as_vector();
        vector.reverse();
        return Value.init_nil();
    } else {
        return stdlib_error("Argument must be a list or vector!", .{ .value_type = conv.what_is(args[0]) });
    }
}

// slice(list, start, end) - Creates a slice of a list from start to end
pub fn slice_fn(argc: i32, args: [*]Value) Value {
    if (argc != 3) return stdlib_error("slice() expects three arguments!", .{ .argn = argc });

    if (!Value.is_obj_type(args[0], .OBJ_LINKED_LIST) and
        !Value.is_obj_type(args[0], .OBJ_FVECTOR))
    {
        return stdlib_error("First argument must be a list or vector!", .{ .value_type = conv.what_is(args[0]) });
    }

    if (!type_check(1, args + 1, 6) or !type_check(1, args + 2, 6)) {
        return stdlib_error("Start and end indices must be numbers!", .{ .value_type = conv.what_is(args[1]) });
    }

    const start = args[1].as_num_int();
    const end = args[2].as_num_int();

    if (start < 0 or end < start) {
        return stdlib_error("Invalid slice range!", .{ .argn = start });
    }

    if (Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        const vector = args[0].as_vector();
        if (start >= vector.count) {
            return stdlib_error("Slice start out of bounds!", .{ .argn = start });
        }

        const actual_end = @min(end, @as(i32, @intCast(vector.count)));

        // Use FloatVector's native slice method
        const result = vector.slice(@intCast(start), @intCast(actual_end));
        return Value.init_obj(@ptrCast(result));
    } else {
        const list = args[0].as_linked_list();
        if (start >= list.count) {
            return stdlib_error("Slice start out of bounds!", .{ .argn = start });
        }

        const actual_end = @min(end, @as(i32, @intCast(list.count)));
        const result = obj_h.sliceLinkedList(list, @intCast(start), @intCast(actual_end));
        return Value.init_obj(@ptrCast(result));
    }
}

// clone(list) - Creates a copy of a list
pub fn clone(argc: i32, args: [*]Value) Value {
    if (argc != 1) return stdlib_error("clone() expects one argument!", .{ .argn = argc });

    if (!Value.is_obj_type(args[0], .OBJ_LINKED_LIST) and
        !Value.is_obj_type(args[0], .OBJ_HASH_TABLE) and
        !Value.is_obj_type(args[0], .OBJ_FVECTOR))
    {
        return stdlib_error("Argument must be a collection type!", .{ .value_type = conv.what_is(args[0]) });
    }

    if (Value.is_obj_type(args[0], .OBJ_HASH_TABLE)) {
        const table = args[0].as_hash_table();
        const new_table = obj_h.cloneHashTable(table);
        return Value.init_obj(@ptrCast(new_table));
    } else if (Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        const vector = args[0].as_vector();
        const new_vector = fvector.FloatVector.init(@intCast(vector.count));

        // Copy all elements
        for (0..vector.count) |i| {
            new_vector.push(vector.data[i]);
        }

        return Value.init_obj(@ptrCast(new_vector));
    } else {
        const list = args[0].as_linked_list();
        const new_list = obj_h.cloneLinkedList(list);
        return Value.init_obj(@ptrCast(new_list));
    }
}

// clear(collection) - Clears all elements from a collection
pub fn clear(argc: i32, args: [*]Value) Value {
    if (argc != 1) return stdlib_error("clear() expects one argument!", .{ .argn = argc });

    if (!Value.is_obj_type(args[0], .OBJ_LINKED_LIST) and
        !Value.is_obj_type(args[0], .OBJ_HASH_TABLE) and
        !Value.is_obj_type(args[0], .OBJ_FVECTOR))
    {
        return stdlib_error("Argument must be a collection type!", .{ .value_type = conv.what_is(args[0]) });
    }

    if (Value.is_obj_type(args[0], .OBJ_HASH_TABLE)) {
        const table = args[0].as_hash_table();
        obj_h.clearHashTable(table);
    } else if (Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        const vector = args[0].as_vector();
        vector.clear();
    } else {
        const list = args[0].as_linked_list();
        obj_h.clearLinkedList(list);
    }

    return Value.init_nil();
}

/// is_empty(collection) - Checks if a collection is empty
pub fn is_empty(argc: i32, args: [*]Value) Value {
    if (argc != 1) return stdlib_error("is_empty() expects one argument!", .{ .argn = argc });

    if (!Value.is_obj_type(args[0], .OBJ_LINKED_LIST) and
        !Value.is_obj_type(args[0], .OBJ_HASH_TABLE) and
        !Value.is_obj_type(args[0], .OBJ_FVECTOR))
    {
        return stdlib_error("Argument must be a collection type!", .{ .value_type = conv.what_is(args[0]) });
    }

    if (Value.is_obj_type(args[0], .OBJ_HASH_TABLE)) {
        const table = args[0].as_hash_table();
        return Value.init_bool(table.table.count == 0);
    } else if (Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        const vector = args[0].as_vector();
        return Value.init_bool(vector.count == 0);
    } else {
        const list = args[0].as_linked_list();
        return Value.init_bool(list.count == 0);
    }
}

// next(iterator) - Gets the next element from an iterator
pub fn next(argc: i32, args: [*]Value) Value {
    if (argc != 1) return stdlib_error("next() expects one argument!", .{ .argn = argc });

    if (!Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        return stdlib_error("Argument must be an iterator!", .{ .value_type = conv.what_is(args[0]) });
    }

    const vector = args[0].as_vector();
    const value = vector.next();
    return Value.init_double(value);
}

// has_next(iterator) - Checks if an iterator has a next element
pub fn has_next(argc: i32, args: [*]Value) Value {
    if (argc != 1) return stdlib_error("has_next() expects one argument!", .{ .argn = argc });

    if (!Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        return stdlib_error("Argument must be an iterator!", .{ .value_type = conv.what_is(args[0]) });
    }

    const vector = args[0].as_vector();
    return Value.init_bool(vector.has_next());
}

// reset(iterator) - Resets an iterator's position
pub fn reset(argc: i32, args: [*]Value) Value {
    if (argc != 1) return stdlib_error("reset() expects one argument!", .{ .argn = argc });

    if (!Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        return stdlib_error("Argument must be an iterator!", .{ .value_type = conv.what_is(args[0]) });
    }

    const vector = args[0].as_vector();
    vector.reset();
    return Value.init_nil();
}

// skip(iterator, count) - Skips a number of elements in an iterator
pub fn skip(argc: i32, args: [*]Value) Value {
    if (argc != 2) return stdlib_error("skip() expects two arguments!", .{ .argn = argc });

    if (!Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        return stdlib_error("First argument must be an iterator!", .{ .value_type = conv.what_is(args[0]) });
    }

    if (!type_check(1, args + 1, 6)) {
        return stdlib_error("Count must be a number!", .{ .value_type = conv.what_is(args[1]) });
    }

    const vector = args[0].as_vector();
    const count = args[1].as_num_int();

    if (count < 0) {
        return stdlib_error("Skip count must be non-negative!", .{ .argn = count });
    }

    vector.skip(@intCast(count));
    return Value.init_nil();
}

// sum(vector) - Calculates the sum of all elements in a vector
pub fn sum(argc: i32, args: [*]Value) Value {
    if (argc != 1) return stdlib_error("sum() expects one argument!", .{ .argn = argc });

    if (!Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        return stdlib_error("Argument must be a vector!", .{ .value_type = conv.what_is(args[0]) });
    }

    const vector = args[0].as_vector();
    var total: f64 = 0;

    for (0..vector.count) |i| {
        total += vector.data[i];
    }

    return Value.init_double(total);
}

// mean(vector) - Calculates the mean of all elements in a vector
pub fn mean(argc: i32, args: [*]Value) Value {
    if (argc != 1) return stdlib_error("mean() expects one argument!", .{ .argn = argc });

    if (!Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        return stdlib_error("Argument must be a vector!", .{ .value_type = conv.what_is(args[0]) });
    }

    const vector = args[0].as_vector();

    if (vector.count == 0) {
        return Value.init_double(0);
    }

    var total: f64 = 0;

    for (0..vector.count) |i| {
        total += vector.data[i];
    }

    return Value.init_double(total / @as(f64, @floatFromInt(vector.count)));
}

// std_dev(vector) - Calculates the standard deviation of all elements in a vector
pub fn std_dev(argc: i32, args: [*]Value) Value {
    if (argc != 1) return stdlib_error("std() expects one argument!", .{ .argn = argc });

    if (!Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        return stdlib_error("Argument must be a vector!", .{ .value_type = conv.what_is(args[0]) });
    }

    const vector = args[0].as_vector();

    if (vector.count <= 1) {
        return Value.init_double(0);
    }

    const mean_val = mean(1, args).as_double();
    var sum_squares: f64 = 0;

    for (0..vector.count) |i| {
        const diff = vector.data[i] - mean_val;
        sum_squares += diff * diff;
    }

    return Value.init_double(@sqrt(sum_squares / @as(f64, @floatFromInt(vector.count - 1))));
}

// variance(vector) - Calculates the variance of all elements in a vector
pub fn variance(argc: i32, args: [*]Value) Value {
    if (argc != 1) return stdlib_error("vari() expects one argument!", .{ .argn = argc });

    if (!Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        return stdlib_error("Argument must be a vector!", .{ .value_type = conv.what_is(args[0]) });
    }

    const vector = args[0].as_vector();

    if (vector.count <= 1) {
        return Value.init_double(0);
    }

    const mean_val = mean(1, args).as_double();
    var sum_squares: f64 = 0;

    for (0..vector.count) |i| {
        const diff = vector.data[i] - mean_val;
        sum_squares += diff * diff;
    }

    return Value.init_double(sum_squares / @as(f64, @floatFromInt(vector.count - 1)));
}

// maxl(vector) - Returns the maximum element in a vector
pub fn maxl(argc: i32, args: [*]Value) Value {
    if (argc != 1) return stdlib_error("maxl() expects one argument!", .{ .argn = argc });

    if (!Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        return stdlib_error("Argument must be a vector!", .{ .value_type = conv.what_is(args[0]) });
    }

    const vector = args[0].as_vector();

    if (vector.count == 0) {
        return stdlib_error("Cannot find maximum in empty vector!", .{ .argn = 0 });
    }

    var max_val = vector.data[0];

    for (1..vector.count) |i| {
        max_val = @max(max_val, vector.data[i]);
    }

    return Value.init_double(max_val);
}

// minl(vector) - Returns the minimum element in a vector
pub fn minl(argc: i32, args: [*]Value) Value {
    if (argc != 1) return stdlib_error("minl() expects one argument!", .{ .argn = argc });

    if (!Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        return stdlib_error("Argument must be a vector!", .{ .value_type = conv.what_is(args[0]) });
    }

    const vector = args[0].as_vector();

    if (vector.count == 0) {
        return stdlib_error("Cannot find minimum in empty vector!", .{ .argn = 0 });
    }

    var min_val = vector.data[0];

    for (1..vector.count) |i| {
        min_val = @min(min_val, vector.data[i]);
    }

    return Value.init_double(min_val);
}

// dot(vector1, vector2) - Calculates the dot product of two vectors
pub fn dot(argc: i32, args: [*]Value) Value {
    if (argc != 2) return stdlib_error("dot() expects two arguments!", .{ .argn = argc });

    if (!Value.is_obj_type(args[0], .OBJ_FVECTOR) or !Value.is_obj_type(args[1], .OBJ_FVECTOR)) {
        return stdlib_error("Both arguments must be vectors!", .{ .value_type = conv.what_is(args[0]) });
    }

    const v1 = args[0].as_vector();
    const v2 = args[1].as_vector();

    if (v1.count != v2.count) {
        return stdlib_error("Vectors must have the same length for dot product!", .{ .argn = @intCast(v1.count) });
    }

    var result: f64 = 0;

    for (0..v1.count) |i| {
        result += v1.data[i] * v2.data[i];
    }

    return Value.init_double(result);
}

// norm(vector) - Calculates the Euclidean norm (magnitude) of a vector
pub fn norm(argc: i32, args: [*]Value) Value {
    if (argc != 1) return stdlib_error("norm() expects one argument!", .{ .argn = argc });

    if (!Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        return stdlib_error("Argument must be a vector!", .{ .value_type = conv.what_is(args[0]) });
    }

    const vector = args[0].as_vector();
    var sum_squares: f64 = 0;

    for (0..vector.count) |i| {
        sum_squares += vector.data[i] * vector.data[i];
    }

    return Value.init_double(@sqrt(sum_squares));
}

/// Converts a range to an array
/// Usage: range_to_array(range)
/// Returns a new array with all values in the range
pub fn range_to_array(argc: i32, args: [*]Value) Value {
    if (argc != 1) return stdlib_error("range_to_array() expects 1 argument", .{ .argn = argc });

    const value = args[0];
    if (value.type != .VAL_OBJ or value.as.obj == null or value.as.obj.?.type != .OBJ_RANGE) {
        return stdlib_error("range_to_array() expects a range object", .{ .value_type = "non-range" });
    }

    // Cast to range object and call to_array
    const range: *ObjRange = @ptrCast(@alignCast(value.as.obj));
    return range.to_array();
}

// linspace(start, end, count) - Creates a vector with evenly spaced values
pub fn linspace(argc: i32, args: [*]Value) Value {
    if (argc != 3) return stdlib_error("linspace() expects three arguments!", .{ .argn = argc });

    if (!type_check(1, args, 6) or !type_check(1, args + 1, 6) or !type_check(1, args + 2, 6)) {
        return stdlib_error("All arguments must be numbers!", .{ .value_type = conv.what_is(args[0]) });
    }

    const start = args[0].as_num_double();
    const end = args[1].as_num_double();
    const count = args[2].as_num_int();

    if (count < 0) {
        return stdlib_error("Count must be non-negative!", .{ .argn = count });
    }

    const result = fvector.FloatVector.linspace(start, end, count);
    return Value.init_obj(@ptrCast(result));
}

// merge(list1, list2) - Merges two lists or vectors into a new one
pub fn merge(argc: i32, args: [*]Value) Value {
    if (argc != 2) return stdlib_error("merge() expects two arguments!", .{ .argn = argc });

    // Both arguments must be of the same type (either both vectors or both lists)
    if (Value.is_obj_type(args[0], .OBJ_FVECTOR) and Value.is_obj_type(args[1], .OBJ_FVECTOR)) {
        const v1 = args[0].as_vector();
        const v2 = args[1].as_vector();

        // Create a new vector with combined capacity
        const result = fvector.FloatVector.init(@intCast(v1.count + v2.count));

        // Copy elements from first vector
        for (0..v1.count) |i| {
            result.push(v1.data[i]);
        }

        // Copy elements from second vector
        for (0..v2.count) |i| {
            result.push(v2.data[i]);
        }

        return Value.init_obj(@ptrCast(result));
    } else if (Value.is_obj_type(args[0], .OBJ_LINKED_LIST) and Value.is_obj_type(args[1], .OBJ_LINKED_LIST)) {
        const l1 = args[0].as_linked_list();
        const l2 = args[1].as_linked_list();

        const result = obj_h.mergeLinkedList(l1, l2);
        return Value.init_obj(@ptrCast(result));
    } else {
        return stdlib_error("Both arguments must be of the same type (vectors or lists)!", .{ .value_type = conv.what_is(args[0]) });
    }
}

// search(collection, value) - Searches for a value in a collection and returns its index
pub fn search(argc: i32, args: [*]Value) Value {
    if (argc != 2) return stdlib_error("search() expects two arguments!", .{ .argn = argc });

    if (!Value.is_obj_type(args[0], .OBJ_FVECTOR) and
        !Value.is_obj_type(args[0], .OBJ_LINKED_LIST))
    {
        return stdlib_error("First argument must be a vector or list!", .{ .value_type = conv.what_is(args[0]) });
    }

    if (Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        if (!type_check(1, args + 1, 6)) {
            return stdlib_error("Value must be a number for vector search!", .{ .value_type = conv.what_is(args[1]) });
        }

        const vector = args[0].as_vector();
        const value = args[1].as_num_double();

        const index = vector.search(value);
        return Value.init_int(index);
    } else {
        // Linked list search
        const list = args[0].as_linked_list();
        var current = list.head;
        var i: i32 = 0;

        while (current != null) : ({
            current = current.?.next;
            i += 1;
        }) {
            if (valuesEqual(current.?.data, args[1])) {
                return Value.init_int(i);
            }
        }

        return Value.init_int(-1); // Not found
    }
}

// splice(list, start, end) - Removes and returns elements from a list
pub fn splice(argc: i32, args: [*]Value) Value {
    if (argc != 3) return stdlib_error("splice() expects three arguments!", .{ .argn = argc });

    if (!Value.is_obj_type(args[0], .OBJ_LINKED_LIST) and
        !Value.is_obj_type(args[0], .OBJ_FVECTOR))
    {
        return stdlib_error("First argument must be a list or vector!", .{ .value_type = conv.what_is(args[0]) });
    }

    if (!type_check(1, args + 1, 6) or !type_check(1, args + 2, 6)) {
        return stdlib_error("Start and end indices must be numbers!", .{ .value_type = conv.what_is(args[1]) });
    }

    const start = args[1].as_num_int();
    const end = args[2].as_num_int();

    if (start < 0 or end < start) {
        return stdlib_error("Invalid splice range!", .{ .argn = start });
    }

    if (Value.is_obj_type(args[0], .OBJ_FVECTOR)) {
        const vector = args[0].as_vector();
        if (start >= vector.count) {
            return stdlib_error("Splice start out of bounds!", .{ .argn = start });
        }

        const actual_end = @min(end, @as(i32, @intCast(vector.count)));

        // Use FloatVector's native splice method
        const result = vector.splice(@intCast(start), @intCast(actual_end));
        return Value.init_obj(@ptrCast(result));
    } else {
        const list = args[0].as_linked_list();
        if (start >= list.count) {
            return stdlib_error("Splice start out of bounds!", .{ .argn = start });
        }

        const actual_end = @min(end, @as(i32, @intCast(list.count)));
        const result = obj_h.spliceLinkedList(list, @intCast(start), @intCast(actual_end));
        return Value.init_obj(@ptrCast(result));
    }
}
