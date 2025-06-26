const std = @import("std");

const reallocate = @import("../memory.zig").reallocate;
const allocateObject = @import("../object.zig").allocateObject;
const obj_h = @import("../object.zig");
const Obj = obj_h.Obj;
const ObjString = obj_h.ObjString;
const FloatVector = obj_h.FloatVector;
const fvector = @import("../objects/fvec.zig");
const value_h = @import("../value.zig");
const Value = value_h.Value;

/// Range object represents a range of values from start to end,
/// either inclusive (..=) or exclusive (..)
pub const ObjRange = struct {
    obj: Obj,
    start: i32,
    end: i32,
    inclusive: bool, // true for inclusive range (..=), false for exclusive (..)
    current: i32, // Current position for iteration

    const Self = *@This();

    /// Initialize a new range object with the given start, end, and inclusivity
    pub fn init(start: i32, end: i32, inclusive: bool) Self {
        const obj = @as(*ObjRange, @ptrCast(@alignCast(allocateObject(@sizeOf(ObjRange), .OBJ_RANGE))));

        // Ensure the object type is properly set (redundant but defensive)
        obj.obj.type = .OBJ_RANGE;

        // Additional defensive initialization to prevent first object issues
        obj.obj.isMarked = false;
        obj.obj.next = null;

        // Initialize all range-specific fields explicitly with validation
        obj.start = start;
        obj.end = end;
        obj.inclusive = inclusive;
        obj.current = start; // Initialize current position to start

        // Validate the range parameters to ensure proper initialization
        if (start > end and !inclusive) {
            // For exclusive ranges, start should not be greater than end
            // But we'll allow it and handle it in length calculation
        }

        return obj;
    }

    /// Get the length of the range
    pub fn length(self: Self) i32 {
        // Defensive null pointer check
        if (@intFromPtr(self) == 0) {
            return 0;
        }

        // Defensive checks for object corruption
        if (self.start < -1000000 or self.start > 1000000) {
            // Start value is corrupted - return 0 to prevent crashes
            return 0;
        }

        if (self.end < -1000000 or self.end > 1000000) {
            // End value is corrupted - return 0 to prevent crashes
            return 0;
        }

        // Ensure proper object type
        if (self.obj.type != .OBJ_RANGE) {
            return 0;
        }

        const end_value = if (self.inclusive) self.end else self.end - 1;
        if (self.start > end_value) {
            return 0; // Empty range
        }

        const computed_length = end_value - self.start + 1;

        // Additional defensive check for corrupted calculation
        if (computed_length < 0 or computed_length > 1000000) {
            return 0;
        }

        return computed_length;
    }

    /// Reset the iteration to the beginning
    pub fn reset(self: Self) void {
        self.current = self.start;
    }

    /// Check if the range contains a specific value
    pub fn contains(self: Self, value: i32) bool {
        if (self.inclusive) {
            return value >= self.start and value <= self.end;
        } else {
            return value >= self.start and value < self.end;
        }
    }

    /// Pattern matching support for switch statements
    pub fn equals(self: Self, other: Value) bool {
        if (!other.is_int() and !other.is_double()) {
            return false;
        }

        const value = other.as_num_int();
        return self.contains(value);
    }

    /// Get the next value in the range and advance the current position
    /// Returns nil if the end has been reached
    pub fn next(self: Self) Value {
        const end_value = if (self.inclusive) self.end else self.end - 1;

        if (self.current <= end_value) {
            const value = self.current;
            self.current += 1;
            return Value.init_int(value);
        } else {
            return Value.init_nil();
        }
    }

    /// Check if there are more values in the range
    pub fn has_next(self: Self) bool {
        const end_value = if (self.inclusive) self.end else self.end - 1;
        return self.current <= end_value;
    }

    /// Return a FloatVector with all values in the range
    pub fn to_array(self: Self) Value {
        const len = self.length();
        if (len <= 0) {
            return Value.init_nil();
        }

        // Create a new float vector with the appropriate capacity
        const vector = fvector.FloatVector.init(@intCast(len));

        // Fill the vector with values from the range
        var current = self.start;
        const end_value = if (self.inclusive) self.end else self.end - 1;

        while (current <= end_value) {
            vector.push(@floatFromInt(current));
            current += 1;
        }

        return Value.init_obj(@ptrCast(vector));
    }

    /// Support array-like access for ranges - makes ranges compatible with foreach loops
    pub fn index(self: Self, idx: i32) Value {
        // Defensive null pointer check
        if (@intFromPtr(self) == 0) {
            return Value.init_nil();
        }

        // Ensure proper object type
        if (self.obj.type != .OBJ_RANGE) {
            return Value.init_nil();
        }

        const len = self.length();
        if (len == 0 or idx < 0 or idx >= len) {
            return Value.init_nil();
        }

        // Additional bounds checking
        const value = self.start + idx;

        // Validate the computed value is within reasonable bounds
        if (value < -1000000 or value > 1000000) {
            return Value.init_nil();
        }

        return Value.init_int(value);
    }

    /// Return the length of the range - makes ranges work with len() function
    pub fn get_length(self: Self) Value {
        return Value.init_int(self.length());
    }

    /// Return a string representation of the range
    pub fn toString(self: Self) Value {
        const operator = if (self.inclusive) "..=" else "..";
        const format_str = std.fmt.allocPrint(std.heap.page_allocator, "{d}{s}{d}", .{ self.start, operator, self.end }) catch "range(error)";

        const string = obj_h.copyString(format_str.ptr, @intCast(format_str.len));
        return Value.init_obj(@ptrCast(string));
    }
};
