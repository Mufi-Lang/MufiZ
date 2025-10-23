const std = @import("std");
const value_h = @import("value.zig");
const Value = value_h.Value;
const object_h = @import("object.zig");

/// KeepAlive is a utility struct that manages object references
/// to ensure they aren't garbage collected during operations
pub const KeepAlive = struct {
    values: [16]Value,
    count: usize,

    /// Initialize a new KeepAlive instance
    pub fn init() KeepAlive {
        return KeepAlive{
            .values = undefined,
            .count = 0,
        };
    }

    /// Add a value to the keep-alive set and retain it
    pub fn add(self: *KeepAlive, value: Value) void {
        if (self.count >= self.values.len) {
            std.debug.print("KeepAlive capacity exceeded\n", .{});
            return;
        }

        // Only retain object values
        if (value.is_obj()) {
            value.retain();
            self.values[self.count] = value;
            self.count += 1;
        }
    }

    /// Release all values and reset the keep-alive set
    pub fn reset(self: *KeepAlive) void {
        var i: usize = 0;
        while (i < self.count) : (i += 1) {
            const value = self.values[i];
            if (value.is_obj()) {
                value.release();
            }
        }
        self.count = 0;
    }
};

/// Create a scoped KeepAlive session
pub fn keepAliveScoped(comptime func: anytype) !void {
    var keeper = KeepAlive.init();
    defer keeper.reset();

    try func(&keeper);
}
