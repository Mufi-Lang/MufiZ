// collections_patch.zig
// Adds range_to_array function to convert range objects to arrays
// This can be merged into collections.zig

const std = @import("std");

const obj_h = @import("../object.zig");
const ObjRange = @import("../objects/range.zig").ObjRange;
const stdlib_error = @import("../stdlib.zig").stdlib_error;
const Value = @import("../value.zig").Value;

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
