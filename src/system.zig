const std = @import("std");
const nostd = @import("build_opts").nostd;
const vm = @cImport(@cInclude("vm.h"));
const conv = @import("conv.zig");

const MAJOR: u8 = 0;
const MINOR: u8 = 3;
const PATCH: u8 = 0;
const CODENAME: []const u8 = "Iris";

pub const vopt = if (nostd) struct {
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
        _ = vm.interpret(conv.cstr(input));
        buffer = undefined;
    }
}

/// Zig version of `runFile` from `csrc/pre.c 50:57`
pub fn runFile(path: []u8, allocator: std.mem.Allocator) !void {
    var str: []u8 = try std.fs.cwd().readFileAlloc(allocator, path, 1048576);
    defer allocator.free(str);
    const result = vm.interpret(conv.cstr(str));
    if (result == vm.INTERPRET_COMPILE_ERROR) std.os.exit(65);
    if (result == vm.INTERPRET_RUNTIME_ERROR) std.os.exit(70);
}