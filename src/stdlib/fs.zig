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
    const path = args[0].as_zstring();
    const file = fs.cwd().createFile(path, .{}) catch return Value.init_bool(false);
    defer file.close();

    return Value.init_bool(true);
}

pub fn write_file(argc: c_int, args: [*c]Value) callconv(.C) Value {
    if (argc != 2) return stdlib_error("Expected 2 arguments for write_file()!", .{ .argn = argc });
    const path = args[0].as_zstring();
    const data = args[1].as_zstring();
    const file = fs.cwd().openFile(path, .{ .mode = .write_only }) catch return Value.init_bool(false);
    defer file.close();

    file.writeAll(data) catch return Value.init_bool(false);

    return Value.init_bool(true);
}

pub fn read_file(argc: c_int, args: [*c]Value) callconv(.C) Value {
    if (argc != 1) return stdlib_error("Expected 1 argument for read_file()!", .{ .argn = argc });
    const path = args[0].as_zstring();
    const file = fs.cwd().openFile(path, .{}) catch return Value.init_nil();
    defer file.close();

    const data = file.readToEndAlloc(GlobalAlloc, 1048576) catch return Value.init_nil();
    defer GlobalAlloc.free(data);

    return Value.init_string(data);
}

pub fn delete_file(argc: c_int, args: [*c]Value) callconv(.C) Value {
    if (argc != 1) return stdlib_error("Expected 1 argument for delete_file()!", .{ .argn = argc });
    const path = args[0].as_zstring();
    fs.cwd().deleteFile(path) catch return Value.init_bool(false);

    return Value.init_bool(true);
}

pub fn create_dir(argc: c_int, args: [*c]Value) callconv(.C) Value {
    if (argc != 1) return stdlib_error("Expected 1 argument for create_dir()!", .{ .argn = argc });
    const path = args[0].as_zstring();
    fs.cwd().makeDir(path) catch return Value.init_bool(false);

    return Value.init_bool(true);
}

pub fn delete_dir(argc: c_int, args: [*c]Value) callconv(.C) Value {
    if (argc != 1) return stdlib_error("Expected 1 argument for delete_dir()!", .{ .argn = argc });
    const path = args[0].as_zstring();
    fs.cwd().deleteDir(path) catch return Value.init_bool(false);

    return Value.init_bool(true);
}
