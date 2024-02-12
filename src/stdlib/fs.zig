const std = @import("std");
const conv = @import("../conv.zig");
const Value = @cImport(@cInclude("value.h")).Value;
const stdlib_error = @import("../stdlib.zig").stdlib_error;
const type_check = conv.type_check;
const GlobalAlloc = @import("../main.zig").GlobalAlloc;
const fs = std.fs.cwd();

// Unable to do string type check
pub fn create_file(argc: c_int, args: [*c]Value) callconv(.C) Value {
    if (argc != 1) return stdlib_error("Expected 1 argument for create_file()!", .{ .argn = argc });
    const path = conv.as_zstring(args[0]);
    const file = fs.createFile(path, .{}) catch return conv.bool_val(false);
    defer file.close();

    return conv.bool_val(true);
}
