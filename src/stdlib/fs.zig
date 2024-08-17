const std = @import("std");
const conv = @import("../conv.zig");
const Value = @import("../value.zig").Value;
const stdlib_error = @import("../stdlib.zig").stdlib_error;
const type_check = conv.type_check;
const GlobalAlloc = @import("../main.zig").GlobalAlloc;
const fs = std.fs;
const builtin = @import("builtin");

// Unable to do string type check
pub fn create_file(argc: c_int, args: [*c]Value) callconv(.C) Value {
    if (argc != 1) return stdlib_error("Expected 1 argument for create_file()!", .{ .argn = argc });
    const path = conv.as_zstring(args[0]);
    const file = fs.cwd().createFile(path, .{}) catch return conv.bool_val(false);
    defer file.close();

    return conv.bool_val(true);
}

pub fn write_file(argc: c_int, args: [*c]Value) callconv(.C) Value {
    if (argc != 2) return stdlib_error("Expected 2 arguments for write_file()!", .{ .argn = argc });
    const path = conv.as_zstring(args[0]);
    const data = conv.as_zstring(args[1]);
    const file = fs.cwd().openFile(path, .{ .mode = .write_only }) catch return conv.bool_val(false);
    defer file.close();

    file.writeAll(data) catch return conv.bool_val(false);

    return conv.bool_val(true);
}

pub fn read_file(argc: c_int, args: [*c]Value) callconv(.C) Value {
    if (argc != 1) return stdlib_error("Expected 1 argument for read_file()!", .{ .argn = argc });
    const path = conv.as_zstring(args[0]);
    const file = fs.cwd().openFile(path, .{}) catch return conv.nil_val();
    defer file.close();

    const data = file.readToEndAlloc(GlobalAlloc, 1048576) catch return conv.nil_val();
    defer GlobalAlloc.free(data);

    return conv.string_val(data);
}

pub fn delete_file(argc: c_int, args: [*c]Value) callconv(.C) Value {
    if (argc != 1) return stdlib_error("Expected 1 argument for delete_file()!", .{ .argn = argc });
    const path = conv.as_zstring(args[0]);
    fs.cwd().deleteFile(path) catch return conv.bool_val(false);

    return conv.bool_val(true);
}

pub fn create_dir(argc: c_int, args: [*c]Value) callconv(.C) Value {
    if (argc != 1) return stdlib_error("Expected 1 argument for create_dir()!", .{ .argn = argc });
    const path = conv.as_zstring(args[0]);
    fs.cwd().makeDir(path) catch return conv.bool_val(false);

    return conv.bool_val(true);
}

pub fn delete_dir(argc: c_int, args: [*c]Value) callconv(.C) Value {
    if (argc != 1) return stdlib_error("Expected 1 argument for delete_dir()!", .{ .argn = argc });
    const path = conv.as_zstring(args[0]);
    fs.cwd().deleteDir(path) catch return conv.bool_val(false);

    return conv.bool_val(true);
}
