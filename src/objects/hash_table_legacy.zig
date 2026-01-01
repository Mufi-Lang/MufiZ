const std = @import("std");

const mem_utils = @import("../mem_utils.zig");
const allocateObject = @import("../object.zig").allocateObject;
const ObjString = @import("../object.zig").ObjString;
const LinkedList = @import("../object.zig").LinkedList;
const ObjPair = @import("../object.zig").ObjPair;
const table_h = @import("../table.zig");
const Table = table_h.Table;
const Value = @import("../value.zig").Value;
const obj_h = @import("obj.zig");
const Obj = obj_h.Obj;
const printValue = @import("../value.zig").printValue;

/// HashTable struct with bounded methods, following the FloatVector/LinkedList pattern
pub const HashTable = struct {
    obj: Obj,
    table: Table,

    const Self = *@This();

    /// Creates a new empty hash table
    pub fn init() Self {
        const htable: Self = @ptrCast(@alignCast(allocateObject(@sizeOf(HashTable), .OBJ_HASH_TABLE)));
        table_h.initTable(&htable.table);
        return htable;
    }

    /// Creates a new hash table (alias for init)
    pub fn new() Self {
        return HashTable.init();
    }

    /// Frees the hash table
    pub fn deinit(self: Self) void {
        table_h.freeTable(&self.table);
        const allocator = mem_utils.getAllocator();
        const self_slice = @as([*]u8, @ptrCast(self))[0..@sizeOf(HashTable)];
        mem_utils.free(allocator, self_slice);
    }

    /// Clears all entries from the hash table
    pub fn clear(self: Self) void {
        table_h.freeTable(&self.table);
        table_h.initTable(&self.table);
    }

    /// Puts a key-value pair into the hash table
    pub fn put(self: Self, key: *ObjString, value: Value) bool {
        return table_h.tableSet(&self.table, key, value);
    }

    /// Gets a value from the hash table by key
    pub fn get(self: Self, key: *ObjString) ?Value {
        var value: Value = undefined;
        if (table_h.tableGet(&self.table, key, &value)) {
            return value;
        }
        return null;
    }

    /// Gets a value from the hash table, returns default if not found
    pub fn getOrDefault(self: Self, key: *ObjString, default: Value) Value {
        var value: Value = undefined;
        if (table_h.tableGet(&self.table, key, &value)) {
            return value;
        }
        return default;
    }

    /// Removes a key-value pair from the hash table
    pub fn remove(self: Self, key: *ObjString) bool {
        return table_h.tableDelete(&self.table, key);
    }

    /// Checks if the hash table contains a key
    pub fn contains(self: Self, key: *ObjString) bool {
        var value: Value = undefined;
        return table_h.tableGet(&self.table, key, &value);
    }

    /// Returns the number of entries in the hash table
    pub fn len(self: Self) usize {
        return self.table.count;
    }

    /// Checks if the hash table is empty
    pub fn is_empty(self: Self) bool {
        return self.table.count == 0;
    }

    /// Creates a copy of the hash table
    pub fn clone(self: Self) Self {
        const newTable = HashTable.init();
        table_h.tableAddAll(&self.table, &newTable.table);
        return newTable;
    }

    /// Merges another hash table into this one
    pub fn merge(self: Self, other: Self) void {
        table_h.tableAddAll(&other.table, &self.table);
    }

    /// Prints the hash table (for debugging)
    pub fn print(self: Self) void {
        std.debug.print("{{", .{});

        if (self.table.entries) |entries| {
            var first = true;
            for (0..@intCast(self.table.capacity)) |i| {
                if (entries[i].key != null and entries[i].isActive()) {
                    if (!first) std.debug.print(", ", .{});
                    first = false;

                    // Print key
                    std.debug.print("\"", .{});
                    for (0..entries[i].key.?.length) |j| {
                        std.debug.print("{c}", .{entries[i].key.?.chars[j]});
                    }
                    std.debug.print("\": ", .{});

                    // Print value (simplified)
                    printValue(entries[i].value);
                }
            }
        }

        std.debug.print("}}", .{});
    }

    /// Converts the hash table to a list of key-value pairs
    pub fn toPairs(self: Self) *LinkedList {
        const list = LinkedList.init();

        if (self.table.entries) |entries| {
            for (0..@intCast(self.table.capacity)) |i| {
                if (entries[i].key != null and entries[i].isActive()) {
                    const keyValue = Value.init_obj(@ptrCast(entries[i].key));
                    const pair = ObjPair.create(keyValue, entries[i].value);
                    const pairValue = Value.init_obj(@ptrCast(pair));
                    list.push(pairValue);
                }
            }
        }

        return list;
    }

    /// Gets all keys as a list
    pub fn keys(self: Self) *LinkedList {
        const list = LinkedList.init();

        if (self.table.entries) |entries| {
            for (0..@intCast(self.table.capacity)) |i| {
                if (entries[i].key != null and entries[i].isActive()) {
                    const keyValue = Value.init_obj(@ptrCast(entries[i].key));
                    list.push(keyValue);
                }
            }
        }

        return list;
    }

    /// Gets all values as a list
    pub fn values(self: Self) *LinkedList {
        const list = LinkedList.init();

        if (self.table.entries) |entries| {
            for (0..@intCast(self.table.capacity)) |i| {
                if (entries[i].key != null and entries[i].isActive()) {
                    list.push(entries[i].value);
                }
            }
        }

        return list;
    }

    /// Iterator support
    pub const Iterator = struct {
        table: *const Table,
        index: usize,

        pub fn next(self: *Iterator) ?struct { key: *ObjString, value: Value } {
            if (self.table.entries) |entries| {
                while (self.index < self.table.capacity) {
                    const i = self.index;
                    self.index += 1;

                    if (entries[i].key != null and entries[i].isActive()) {
                        return .{
                            .key = entries[i].key.?,
                            .value = entries[i].value,
                        };
                    }
                }
            }
            return null;
        }
    };

    /// Creates an iterator for the hash table
    pub fn iterator(self: Self) Iterator {
        return Iterator{
            .table = &self.table,
            .index = 0,
        };
    }

    /// Applies a function to each key-value pair
    pub fn foreach(self: Self, func: fn (key: *ObjString, value: Value) void) void {
        if (self.table.entries) |entries| {
            for (0..@intCast(self.table.capacity)) |i| {
                if (entries[i].key != null and entries[i].isActive()) {
                    func(entries[i].key.?, entries[i].value);
                }
            }
        }
    }

    /// Maps values to create a new hash table
    pub fn mapValues(self: Self, func: fn (key: *ObjString, value: Value) Value) Self {
        const newTable = HashTable.init();

        if (self.table.entries) |entries| {
            for (0..@intCast(self.table.capacity)) |i| {
                if (entries[i].key != null and entries[i].isActive()) {
                    const newValue = func(entries[i].key.?, entries[i].value);
                    _ = newTable.put(entries[i].key.?, newValue);
                }
            }
        }

        return newTable;
    }

    /// Filters entries to create a new hash table
    pub fn filter(self: Self, predicate: fn (key: *ObjString, value: Value) bool) Self {
        const newTable = HashTable.init();

        if (self.table.entries) |entries| {
            for (0..@intCast(self.table.capacity)) |i| {
                if (entries[i].key != null and entries[i].isActive()) {
                    if (predicate(entries[i].key.?, entries[i].value)) {
                        _ = newTable.put(entries[i].key.?, entries[i].value);
                    }
                }
            }
        }

        return newTable;
    }
};

// Helper function to print a Value (simplified version)

// Import ObjString type
