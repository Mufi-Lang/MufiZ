const std = @import("std");
const stdlib = @import("stdlib.zig");
//const Conv = @import("conv.zig").Conv; //broken
const vm = @cImport(@cInclude("vm.h"));
const value = @cImport(@cInclude("value.h"));
const Value = value.Value;
const VAL_INT = value.VAL_INT;
const stdin = std.io.getStdIn().reader();

const MAJOR: u8 = 1;
const MINOR: u8 = 0;
const PATCH: u8 = 0;
const CODENAME: []const u8 = "Zula";

// TODO: Move to conv.zig
fn int_val(i: i32) Value {
    return Value{ .type = VAL_INT, .as = .{ .num_int = i } };
}
// TODO: Move to conv.zig
fn as_int(v: Value) i32 {
    return v.as.num_int;
}

// Create an add function for integers
// TODO: Move to stdlib.zig
fn addi(argc: c_int, args: [*c]Value) callconv(.C) Value {
    if (argc != 2) {
        return int_val(0);
    } else {
        const a = as_int(args[0]);
        const b = as_int(args[1]);
        return int_val(a + b);
    }
}

/// Converts a Zig string to a C Null-Terminated string
// TODO: Move to conv.zig
fn cstr(s: []u8) [*c]u8 {
    var ptr: [*c]u8 = @ptrCast(s.ptr);
    ptr[s.len] = '\x00';
    return ptr;
}

/// Zig version of `runFile` from `csrc/pre.c 50:57`
pub fn runFile(path: []u8, allocator: std.mem.Allocator) !void {
    var str: []u8 = try std.fs.cwd().readFileAlloc(allocator, path, 1048576);
    defer allocator.free(str);
    const result = vm.interpret(cstr(str));
    if (result == vm.INTERPRET_COMPILE_ERROR) std.os.exit(65);
    if (result == vm.INTERPRET_RUNTIME_ERROR) std.os.exit(70);
}

pub inline fn version() void {
    std.debug.print("Version {d}.{d}.{d} ({s} Release)\n", .{ MAJOR, MINOR, PATCH, CODENAME });
}

/// Zig version of `repl` from `csrc/pre.c 10:21` 
/// Currently uses depreceated `readUntilDelimiterOrEof` 
/// `streamUntilDelimeter` causes issue due to const pointer
pub fn repl() !void {
    var buffer: [1024]u8 = undefined;
    version();
    while (true) {
        std.debug.print("(mufi) >> ", .{});
        var input = try stdin.readUntilDelimiterOrEof(&buffer, '\n') orelse break;
        _ = vm.interpret(cstr(input));
        buffer = undefined;
    }
}

pub fn main() !void {
    vm.initVM();
    defer vm.freeVM();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const check = gpa.deinit();
        if (check == .leak) @panic("memory leak!");
    }
    const allocator = gpa.allocator();
    var natives = stdlib.NativeFunctions.init(allocator);
    defer natives.deinit();
    try natives.append("addi", &addi);
    natives.define();

    var args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len == 1) {
        try repl();
    } else if (args.len == 2) {
        if (std.mem.eql(u8, args[1], "version")) {
            version();
        } else {
            try runFile(args[1], allocator);
        }
    } else {
        std.debug.print("Usage: mufi <path>\n", .{});
    }
}
