const std = @import("std");
const nostd = @import("build_opts").nostd;
const vm = @cImport(@cInclude("vm.h"));
const conv = @import("conv.zig");
const builtin = @import("builtin");
/// Because Windows hangs on `system.repl()`
pub const pre = if (builtin.os.tag == .windows) @cImport(@cInclude("pre.h")) else {};

const MAJOR: u8 = 0;
const MINOR: u8 = 4;
const PATCH: u8 = 0;
const CODENAME: []const u8 = "Voxl";

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
    if (builtin.os.tag == .windows) pre.repl() else try zrepl();
}

inline fn zrepl() !void {
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

pub const Runner = struct {
    main: []u8 = &.{},
    link: ?[]u8 = null,
    allocator: std.mem.Allocator,

    const max_bytes: usize = 1048576;
    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{ .allocator = allocator };
    }

    fn read_file(self: *Self, path: []u8) ![]u8 {
        return try std.fs.cwd().readFileAlloc(self.allocator, path, max_bytes);
    }

    fn run(str: []u8) void {
        const result = vm.interpret(conv.cstr(str));
        if (result == vm.INTERPRET_COMPILE_ERROR) std.os.exit(65);
        if (result == vm.INTERPRET_RUNTIME_ERROR) std.os.exit(70);
    }

    pub fn setOnlyMain(self: *Self, main: []u8) void {
        self.main = main;
        self.link = null;
    }
    pub fn setMainWithLink(self: *Self, main: []u8, link: []u8) void {
        self.main = main;
        self.link = link;
    }
    pub fn runFile(self: *Self) !void {
        var str: []u8 = undefined;
        if (self.link) |l| {
            var main_str = try self.read_file(self.main);
            defer self.allocator.free(main_str);
            var link_str = try self.read_file(l);
            defer self.allocator.free(link_str);
            const size = main_str.len + link_str.len;
            str = try self.allocator.alloc(u8, size);
            @memcpy(str[0..link_str.len], link_str[0..]);
            @memcpy(str[link_str.len..], main_str[0..]);
        } else {
            str = try self.read_file(self.main);
        }
        run(str);
        self.allocator.free(str);
    }
};
