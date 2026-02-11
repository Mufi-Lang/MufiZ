/// Module Object for MufiZ
/// Represents an imported module with its own namespace for constants and functions
const std = @import("std");
const Obj = @import("obj.zig").Obj;
const ObjType = @import("obj.zig").ObjType;
const value_h = @import("../value.zig");
const Value = value_h.Value;
const object_h = @import("../object.zig");
const ObjString = object_h.ObjString;

/// Module object that holds a namespace of constants and functions
pub const Module = struct {
    obj: Obj,
    name: *ObjString,
    members: std.StringHashMap(Value),
    allocator: std.mem.Allocator,

    /// Get a member from the module by name
    pub fn getMember(self: *Module, name: []const u8) ?Value {
        return self.members.get(name);
    }

    /// Set a member in the module
    pub fn setMember(self: *Module, name: []const u8, value: Value) !void {
        try self.members.put(name, value);
    }

    /// Check if a member exists in the module
    pub fn hasMember(self: *Module, name: []const u8) bool {
        return self.members.contains(name);
    }

    /// Free the module's resources
    pub fn deinit(self: *Module) void {
        self.members.deinit();
    }
};

pub const ObjModule = Module;
