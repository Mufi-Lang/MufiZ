const std = @import("std");

const mem_utils = @import("../mem_utils.zig");
const obj_h = @import("../object.zig");
const Obj = obj_h.Obj;
const allocateObject = obj_h.allocateObject;
const value_h = @import("../value.zig");
const Value = value_h.Value;
const __obj = @import("obj.zig");
const ObjType = __obj.ObjType;

/// ObjPair represents a key-value pair, primarily used for iterating over hash tables
/// and other key-value collections. This enables foreach loops to destructure
/// into (key, value) pairs naturally.
pub const ObjPair = struct {
    obj: Obj,
    key: Value,
    value: Value,

    const Self = @This();

    /// Creates a new pair object with the given key and value
    pub fn create(key: Value, value: Value) *ObjPair {
        const pair = @as(*ObjPair, @ptrCast(@alignCast(allocateObject(@sizeOf(ObjPair), .OBJ_PAIR))));
        pair.key = key;
        pair.value = value;

        // Retain references to prevent premature deallocation
        pair.key.retain();
        pair.value.retain();

        return pair;
    }

    /// Frees the pair and releases references to its contents
    pub fn free(self: *Self) void {
        self.key.release();
        self.value.release();
        const allocator = mem_utils.getAllocator();
        const self_slice = @as([*]u8, @ptrCast(self))[0..@sizeOf(ObjPair)];
        mem_utils.free(allocator, self_slice);
    }

    /// Returns the first element of the pair (key)
    pub fn first(self: *const Self) Value {
        return self.key;
    }

    /// Returns the second element of the pair (value)
    pub fn second(self: *const Self) Value {
        return self.value;
    }

    /// Support indexed access for compatibility
    /// Index 0 returns the key, index 1 returns the value
    pub fn index(self: *const Self, idx: i32) Value {
        return switch (idx) {
            0 => self.key,
            1 => self.value,
            else => Value.init_nil(),
        };
    }

    /// Returns the number of elements in a pair (always 2)
    pub fn length(self: *const Self) i32 {
        _ = self;
        return 2;
    }

    /// Checks if two pairs are equal (both key and value must be equal)
    pub fn equal(self: *const Self, other: *const ObjPair) bool {
        return value_h.valuesEqual(self.key, other.key) and
            value_h.valuesEqual(self.value, other.value);
    }

    /// Creates a string representation of the pair
    pub fn toString(self: *const Self) []const u8 {
        const keyStr = value_h.valueToString(self.key);
        const valueStr = value_h.valueToString(self.value);

        // Allocate memory for the formatted string
        const allocator = std.heap.page_allocator;
        const result = std.fmt.allocPrint(allocator, "({s}, {s})", .{ keyStr, valueStr }) catch {
            return "(?, ?)";
        };

        return result;
    }

    /// Creates a new pair with swapped key and value
    pub fn swap(self: *const Self) *ObjPair {
        return create(self.value, self.key);
    }

    /// Updates the key of the pair (creates a new pair)
    pub fn withKey(self: *const Self, newKey: Value) *ObjPair {
        return create(newKey, self.value);
    }

    /// Updates the value of the pair (creates a new pair)
    pub fn withValue(self: *const Self, newValue: Value) *ObjPair {
        return create(self.key, newValue);
    }
};
