const std = @import("std");
const vm_h = @import("core.zig").vm_h;
const conv = @import("conv.zig");
const GlobalAlloc = @import("main.zig").GlobalAlloc;

const MAJOR: u8 = 0;
const MINOR: u8 = 10;
const PATCH: u8 = 0;
const CODENAME: []const u8 = "Echo";

pub inline fn version() void {
    std.debug.print("MufiZ v{d}.{d}.{d} ({s} Release)\n", .{ MAJOR, MINOR, PATCH, CODENAME });
}

pub inline fn usage() void {
    std.debug.print("Usage: mufiz [OPTIONS] [ARGS]\n", .{});
    std.debug.print("Options:\n", .{});
}

pub fn repl() !void {
    var buffer: [1024]u8 = undefined;
    var streamer = std.io.FixedBufferStream([]u8){ .buffer = &buffer, .pos = 0 };
    version();
    while (true) {
        std.debug.print("(mufi) >> ", .{});
        try std.io.getStdIn().reader().streamUntilDelimiter(streamer.writer(), '\n', 1024);
        const input = streamer.getWritten();
        _ = vm_h.interpret(conv.cstr(input));
        streamer.reset();
    }
}

pub const InterpreterError = error{
    // this might confuse you, but what if something that isn't supposed to happen happens?
    // then by definition its an error because it's not expected.
    OK,
    CompileError,
    RuntimeError,
};

pub const Runner = struct {
    main: []u8 = &.{},
    link: ?[]u8 = null,
    allocator: std.mem.Allocator,

    const max_bytes: usize = @intCast(std.math.maxInt(u16));
    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.main);
        if (self.link) |l| {
            self.allocator.free(l);
            self.link = null;
        }
    }

    fn read_file(self: *Self, path: []u8) ![]u8 {
        return try std.fs.cwd().readFileAlloc(self.allocator, path, max_bytes);
    }

    fn run(str: []u8) InterpreterError!void {
        const result = vm_h.interpret(conv.cstr(str));
        if (result == .INTERPRET_COMPILE_ERROR) return InterpreterError.CompileError;
        if (result == .INTERPRET_RUNTIME_ERROR) return InterpreterError.RuntimeError;
    }

    pub fn setMain(self: *Self, main: []u8) !void {
        self.main = try self.read_file(main);
    }

    pub fn setLink(self: *Self, link: []u8) !void {
        self.link = try self.read_file(link);
    }

    fn linkSize(self: Self) usize {
        return self.link.?.len;
    }

    fn mainSize(self: Self) usize {
        return self.main.len;
    }

    pub fn runFile(self: Self) !void {
        if (self.link) |l| {
            var str = try self.allocator.alloc(u8, self.mainSize() + self.linkSize());
            defer self.allocator.free(str);
            @memcpy(str[0..l.len], l[0..]);
            @memcpy(str[l.len..], self.main[0..]);
            try run(str);
        } else {
            try run(self.main);
        }
    }
};
