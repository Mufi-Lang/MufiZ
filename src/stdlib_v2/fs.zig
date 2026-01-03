const std = @import("std");
const stdlib_v2 = @import("../stdlib_v2.zig");
const Value = @import("../value.zig").Value;
const mem_utils = @import("../mem_utils.zig");
const fs = std.fs;

const DefineFunction = stdlib_v2.DefineFunction;
const ParamSpec = stdlib_v2.ParamSpec;

// === Implementation Functions ===

fn create_file_impl(_: i32, args: [*]Value) Value {
    const path = args[0].as_zstring();
    const file = fs.cwd().createFile(path, .{}) catch return Value.init_bool(false);
    defer file.close();
    return Value.init_bool(true);
}

fn write_file_impl(_: i32, args: [*]Value) Value {
    const path = args[0].as_zstring();
    const data = args[1].as_zstring();
    const file = fs.cwd().openFile(path, .{ .mode = .write_only }) catch return Value.init_bool(false);
    defer file.close();
    file.writeAll(data) catch return Value.init_bool(false);
    return Value.init_bool(true);
}

fn read_file_impl(_: i32, args: [*]Value) Value {
    const path = args[0].as_zstring();
    const file = fs.cwd().openFile(path, .{}) catch return Value.init_nil();
    defer file.close();
    const data = file.readToEndAlloc(mem_utils.getAllocator(), 1048576) catch return Value.init_nil();
    defer mem_utils.getAllocator().free(data);
    return Value.init_string(data);
}

fn delete_file_impl(_: i32, args: [*]Value) Value {
    const path = args[0].as_zstring();
    fs.cwd().deleteFile(path) catch return Value.init_bool(false);
    return Value.init_bool(true);
}

fn create_dir_impl(_: i32, args: [*]Value) Value {
    const path = args[0].as_zstring();
    fs.cwd().makeDir(path) catch return Value.init_bool(false);
    return Value.init_bool(true);
}

fn delete_dir_impl(_: i32, args: [*]Value) Value {
    const path = args[0].as_zstring();
    fs.cwd().deleteDir(path) catch return Value.init_bool(false);
    return Value.init_bool(true);
}

fn file_exists_impl(_: i32, args: [*]Value) Value {
    const path = args[0].as_zstring();
    const file = fs.cwd().openFile(path, .{}) catch return Value.init_bool(false);
    file.close();
    return Value.init_bool(true);
}

fn dir_exists_impl(_: i32, args: [*]Value) Value {
    const path = args[0].as_zstring();
    const dir = fs.cwd().openDir(path, .{}) catch return Value.init_bool(false);
    dir.close();
    return Value.init_bool(true);
}

fn file_size_impl(_: i32, args: [*]Value) Value {
    const path = args[0].as_zstring();
    const file = fs.cwd().openFile(path, .{}) catch return Value.init_int(-1);
    defer file.close();
    const stat = file.stat() catch return Value.init_int(-1);
    return Value.init_int(@intCast(stat.size));
}

fn copy_file_impl(_: i32, args: [*]Value) Value {
    const src_path = args[0].as_zstring();
    const dest_path = args[1].as_zstring();
    fs.cwd().copyFile(src_path, fs.cwd(), dest_path, .{}) catch return Value.init_bool(false);
    return Value.init_bool(true);
}

// === Parameter Specifications ===

const PathParam = &[_]ParamSpec{.{ .name = "path", .type = .string }};
const PathAndDataParams = &[_]ParamSpec{
    .{ .name = "path", .type = .string },
    .{ .name = "data", .type = .string },
};
const SourceAndDestParams = &[_]ParamSpec{
    .{ .name = "source", .type = .string },
    .{ .name = "destination", .type = .string },
};

// === Public Function Definitions ===

pub const create_file = DefineFunction(
    "create_file",
    "filesystem",
    "Create a new file at the specified path",
    PathParam,
    .bool,
    &[_][]const u8{ "create_file(\"test.txt\") -> true", "create_file(\"/invalid/path/file.txt\") -> false" },
    create_file_impl,
);

pub const write_file = DefineFunction(
    "write_file",
    "filesystem",
    "Write data to a file at the specified path",
    PathAndDataParams,
    .bool,
    &[_][]const u8{ "write_file(\"test.txt\", \"Hello, World!\") -> true", "write_file(\"/readonly/file.txt\", \"data\") -> false" },
    write_file_impl,
);

pub const read_file = DefineFunction(
    "read_file",
    "filesystem",
    "Read the contents of a file as a string",
    PathParam,
    .string,
    &[_][]const u8{ "read_file(\"config.txt\") -> \"key=value\"", "read_file(\"missing.txt\") -> nil" },
    read_file_impl,
);

pub const delete_file = DefineFunction(
    "delete_file",
    "filesystem",
    "Delete a file at the specified path",
    PathParam,
    .bool,
    &[_][]const u8{ "delete_file(\"temp.txt\") -> true", "delete_file(\"missing.txt\") -> false" },
    delete_file_impl,
);

pub const create_dir = DefineFunction(
    "create_dir",
    "filesystem",
    "Create a new directory at the specified path",
    PathParam,
    .bool,
    &[_][]const u8{ "create_dir(\"new_folder\") -> true", "create_dir(\"/root/protected\") -> false" },
    create_dir_impl,
);

pub const delete_dir = DefineFunction(
    "delete_dir",
    "filesystem",
    "Delete an empty directory at the specified path",
    PathParam,
    .bool,
    &[_][]const u8{ "delete_dir(\"empty_folder\") -> true", "delete_dir(\"non_empty_folder\") -> false" },
    delete_dir_impl,
);

pub const file_exists = DefineFunction(
    "file_exists",
    "filesystem",
    "Check if a file exists at the specified path",
    PathParam,
    .bool,
    &[_][]const u8{ "file_exists(\"config.txt\") -> true", "file_exists(\"missing.txt\") -> false" },
    file_exists_impl,
);

pub const dir_exists = DefineFunction(
    "dir_exists",
    "filesystem",
    "Check if a directory exists at the specified path",
    PathParam,
    .bool,
    &[_][]const u8{ "dir_exists(\"documents\") -> true", "dir_exists(\"missing_folder\") -> false" },
    dir_exists_impl,
);

pub const file_size = DefineFunction(
    "file_size",
    "filesystem",
    "Get the size of a file in bytes",
    PathParam,
    .int,
    &[_][]const u8{ "file_size(\"document.pdf\") -> 1024", "file_size(\"missing.txt\") -> -1" },
    file_size_impl,
);

pub const copy_file = DefineFunction(
    "copy_file",
    "filesystem",
    "Copy a file from source to destination path",
    SourceAndDestParams,
    .bool,
    &[_][]const u8{ "copy_file(\"source.txt\", \"backup.txt\") -> true", "copy_file(\"missing.txt\", \"dest.txt\") -> false" },
    copy_file_impl,
);
