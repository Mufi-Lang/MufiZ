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
pub fn repl() !void {
    var buffer: [1024]u8 = undefined;
    var streamer = std.io.FixedBufferStream([]u8){ .buffer = &buffer, .pos = 0 };
    vopt.version();
    while (true) {
        std.debug.print("(mufi) >> ", .{});
        try std.io.getStdIn().reader().streamUntilDelimiter(streamer.writer(), '\n', 1024);
        var input = streamer.getWritten();
        _ = vm.interpret(conv.cstr(input));
        streamer.reset();
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
