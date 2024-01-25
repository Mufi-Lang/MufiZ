const std = @import("std");
const nostd = @import("build_opts").nostd;
const stdlib = @import("stdlib.zig");
const conv = @import("conv.zig");
const vm = @cImport(@cInclude("vm.h"));
const value = @cImport(@cInclude("value.h"));
const Value = value.Value;
const VAL_INT = value.VAL_INT;
const builtin = @import("builtin");
const MAJOR: u8 = 0;
const MINOR: u8 = 3;
const PATCH: u8 = 0;
const CODENAME: []const u8 = "Iris";

// Create an add function for integers
// TODO: Move to stdlib.zig
fn addi(argc: c_int, args: [*c]Value) callconv(.C) Value {
    if (argc != 2) {
        return conv.int_val(0);
    } else {
        const a = conv.as_int(args[0]);
        const b = conv.as_int(args[1]);
        return conv.int_val(a + b);
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

const vopt = if (nostd) struct {
    pub inline fn version() void {
        std.debug.print("Version {d}.{d}.{d} ({s} Release [nostd])\n", .{ MAJOR, MINOR, PATCH, CODENAME });
    }
} else struct {
    pub inline fn version() void {
        std.debug.print("Version {d}.{d}.{d} ({s} Release)\n", .{ MAJOR, MINOR, PATCH, CODENAME });
    }
};

/// Zig version of `repl` from `csrc/pre.c 10:21`
/// Currently uses depreceated `readUntilDelimiterOrEof`
/// `streamUntilDelimeter` causes issue due to const pointer
pub fn repl() !void {
    const stdin = std.io.getStdIn().reader();
    var buffer: [1024]u8 = undefined;
    vopt.version();
    while (true) {
        std.debug.print("(mufi) >> ", .{});
        var input = try stdin.readUntilDelimiterOrEof(&buffer, '\n') orelse break;
        _ = vm.interpret(cstr(input));
        buffer = undefined;
    }
}

/// Because Windows has error with `getStdIn().reader()`
pub const pre = if (builtin.os.tag == .windows) @cImport(@cInclude("pre.h")) else {};

pub fn main() !void {
    vm.initVM();
    defer vm.freeVM();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const check = gpa.deinit();
        if (check == .leak) @panic("memory leak!");
    }
    const allocator = gpa.allocator();
    if (!nostd) {
        var natives = stdlib.NativeFunctions.init(allocator);
        defer natives.deinit();
        try natives.append("addi", &addi);
        try natives.append("i2d", &stdlib.i2d);
        try natives.append("d2i", &stdlib.d2i);
        try natives.append("log2", &stdlib.math.log2);
        // try natives.append("str2i", &stdlib.str2i);
        natives.define();
    }

    var args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len == 1) {
        if (builtin.os.tag == .windows) {
            pre.repl();
        } else {
            try repl();
        }
    } else if (args.len == 2) {
        if (std.mem.eql(u8, args[1], "version")) {
            vopt.version();
        } else {
            if (builtin.os.tag == .windows) {
                pre.runFile(args[1]);
            } else {
                try runFile(args[1], allocator);
            }
        }
    } else {
        std.debug.print("Usage: mufi <path>\n", .{});
    }
}
