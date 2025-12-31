const std = @import("std");
const Allocator = std.mem.Allocator;

const mem_utils = @import("../mem_utils.zig");
const allocateObject = @import("../object.zig").allocateObject;
const ObjString = @import("../object.zig").ObjString;
const LinkedList = @import("../object.zig").LinkedList;
const ObjPair = @import("../object.zig").ObjPair;
const Value = @import("../value.zig").Value;
const obj_h = @import("obj.zig");
const Obj = obj_h.Obj;
const printValue = @import("../value.zig").printValue;

// Use improved string hash context from string_hash module
const string_hash = @import("../string_hash.zig");
const StringHashContext = string_hash.ObjStringHashContext;

/// HashTable struct using std.HashMap internally
pub const HashTable = struct {
    obj: Obj,
    map: std.HashMap(*ObjString, Value, StringHashContext, std.hash_map.default_max_load_percentage),
    allocator: Allocator,

    const Self = *@This();
    const InternalMap = std.HashMap(*ObjString, Value, StringHashContext, std.hash_map.default_max_load_percentage);

    /// Creates a new empty hash table
    pub fn init() Self {
        const htable: Self = @ptrCast(@alignCast(allocateObject(@sizeOf(HashTable), .OBJ_HASH_TABLE)));

        // Use our global allocator directly
        const allocator = mem_utils.getAllocator();
        htable.allocator = allocator;
        htable.map = InternalMap.init(allocator);

        return htable;
    }

    /// Creates a new hash table (alias for init)
    pub fn new() Self {
        return HashTable.init();
    }

    /// Frees the hash table
    pub fn deinit(self: Self) void {
        self.map.deinit();
        const allocator = mem_utils.getAllocator();
        const self_slice = @as([*]u8, @ptrCast(self))[0..@sizeOf(HashTable)];
        mem_utils.free(allocator, self_slice);
    }

    /// Clears all entries from the hash table
    pub fn clear(self: Self) void {
        self.map.clearRetainingCapacity();
    }

    /// Puts a key-value pair into the hash table
    pub fn put(self: Self, key: *ObjString, value: Value) bool {
        const result = self.map.getOrPut(key) catch {
            // Handle allocation failure gracefully
            return false;
        };
        const is_new = !result.found_existing;
        result.value_ptr.* = value;
        return is_new;
    }

    /// Gets a value from the hash table by key
    pub fn get(self: Self, key: *ObjString) ?Value {
        return self.map.get(key);
    }

    /// Gets a value from the hash table, returns default if not found
    pub fn getOrDefault(self: Self, key: *ObjString, default: Value) Value {
        return self.map.get(key) orelse default;
    }

    /// Removes a key-value pair from the hash table
    pub fn remove(self: Self, key: *ObjString) bool {
        return self.map.remove(key);
    }

    /// Checks if the hash table contains a key
    pub fn contains(self: Self, key: *ObjString) bool {
        return self.map.contains(key);
    }

    /// Returns the number of entries in the hash table
    pub fn len(self: Self) usize {
        return self.map.count();
    }

    /// Checks if the hash table is empty
    pub fn is_empty(self: Self) bool {
        return self.map.count() == 0;
    }

    /// Creates a copy of the hash table
    pub fn clone(self: Self) Self {
        const newTable = HashTable.init();

        var iter = self.map.iterator();
        while (iter.next()) |entry| {
            _ = newTable.put(entry.key_ptr.*, entry.value_ptr.*);
        }

        return newTable;
    }

    /// Merges another hash table into this one
    pub fn merge(self: Self, other: Self) void {
        var iter = other.map.iterator();
        while (iter.next()) |entry| {
            _ = self.put(entry.key_ptr.*, entry.value_ptr.*);
        }
    }

    /// Prints the hash table (for debugging)
    pub fn print(self: Self) void {
        std.debug.print("#{{", .{});

        var iter = self.map.iterator();
        var first = true;

        while (iter.next()) |entry| {
            if (!first) std.debug.print(", ", .{});
            first = false;

            // Print key
            std.debug.print("\"", .{});
            for (0..entry.key_ptr.*.length) |j| {
                std.debug.print("{c}", .{entry.key_ptr.*.chars[j]});
            }
            std.debug.print("\": ", .{});

            // Print value
            printValue(entry.value_ptr.*);
        }

        std.debug.print("}}", .{});
    }

    /// Converts the hash table to a list of key-value pairs
    pub fn toPairs(self: Self) *LinkedList {
        const list = LinkedList.init();

        var iter = self.map.iterator();
        while (iter.next()) |entry| {
            const keyValue = Value.init_obj(@ptrCast(entry.key_ptr.*));
            const pair = ObjPair.create(keyValue, entry.value_ptr.*);
            const pairValue = Value.init_obj(@ptrCast(pair));
            list.push(pairValue);
        }

        return list;
    }

    /// Gets all keys as a list
    pub fn keys(self: Self) *LinkedList {
        const list = LinkedList.init();

        var iter = self.map.iterator();
        while (iter.next()) |entry| {
            const keyValue = Value.init_obj(@ptrCast(entry.key_ptr.*));
            list.push(keyValue);
        }

        return list;
    }

    /// Gets all values as a list
    pub fn values(self: Self) *LinkedList {
        const list = LinkedList.init();

        var iter = self.map.iterator();
        while (iter.next()) |entry| {
            list.push(entry.value_ptr.*);
        }

        return list;
    }

    /// Iterator support (wraps std.HashMap iterator)
    pub const Iterator = struct {
        internal_iterator: InternalMap.Iterator,

        pub fn next(self: *Iterator) ?struct { key: *ObjString, value: Value } {
            if (self.internal_iterator.next()) |entry| {
                return .{
                    .key = entry.key_ptr.*,
                    .value = entry.value_ptr.*,
                };
            }
            return null;
        }
    };

    /// Creates an iterator for the hash table
    pub fn iterator(self: Self) Iterator {
        return Iterator{
            .internal_iterator = self.map.iterator(),
        };
    }

    /// Applies a function to each key-value pair
    pub fn foreach(self: Self, func: fn (key: *ObjString, value: Value) void) void {
        var iter = self.map.iterator();
        while (iter.next()) |entry| {
            func(entry.key_ptr.*, entry.value_ptr.*);
        }
    }

    /// Maps values to create a new hash table
    pub fn mapValues(self: Self, func: fn (key: *ObjString, value: Value) Value) Self {
        const newTable = HashTable.init();

        var iter = self.map.iterator();
        while (iter.next()) |entry| {
            const newValue = func(entry.key_ptr.*, entry.value_ptr.*);
            _ = newTable.put(entry.key_ptr.*, newValue);
        }

        return newTable;
    }

    /// Filters entries to create a new hash table
    pub fn filter(self: Self, predicate: fn (key: *ObjString, value: Value) bool) Self {
        const newTable = HashTable.init();

        var iter = self.map.iterator();
        while (iter.next()) |entry| {
            if (predicate(entry.key_ptr.*, entry.value_ptr.*)) {
                _ = newTable.put(entry.key_ptr.*, entry.value_ptr.*);
            }
        }

        return newTable;
    }

    /// Gets the capacity of the internal hash map
    pub fn capacity(self: Self) usize {
        return self.map.capacity();
    }

    /// Gets the load factor of the internal hash map
    pub fn loadFactor(self: Self) f32 {
        const cap = self.map.capacity();
        if (cap == 0) return 0.0;
        return @as(f32, @floatFromInt(self.map.count())) / @as(f32, @floatFromInt(cap));
    }

    /// Ensures the hash table has at least the specified capacity
    pub fn ensureCapacity(self: Self, new_capacity: usize) bool {
        self.map.ensureTotalCapacity(@intCast(new_capacity)) catch return false;
        return true;
    }

    /// Shrinks the hash table to fit its current size
    pub fn shrinkToFit(self: Self) void {
        // std.HashMap doesn't have a direct shrink method, but we can clone to a new one
        // This is an expensive operation and should be used sparingly
        const newTable = self.clone();
        self.map.deinit();
        self.map = newTable.map;
        // Don't deinit newTable since we've stolen its map
        const self_slice = @as([*]u8, @ptrCast(newTable))[0..@sizeOf(HashTable)];
        mem_utils.free(self.allocator, self_slice);
    }
};
