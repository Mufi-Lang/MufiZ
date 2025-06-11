const std = @import("std");
const fs = std.fs;
const mem = std.mem;

const conv = @import("conv.zig");
const GlobalAlloc = @import("main.zig").GlobalAlloc;
const SimpleLineEditor = @import("simple_line.zig").SimpleLineEditor;
const syntax = @import("syntax_min.zig");
const vm_h = @import("vm.zig");

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
    std.debug.print("  --help         Show this help message\n", .{});
    std.debug.print("  --version      Show version information\n", .{});
}

fn processSpecialCommand(command: []const u8) bool {
    const cmd = std.mem.trim(u8, command, " \t\r\n");

    if (std.mem.eql(u8, cmd, "help")) {
        std.debug.print("MufiZ Interactive Help\n", .{});
        std.debug.print("-----------------\n", .{});
        std.debug.print("Special commands:\n", .{});
        std.debug.print("  help       Display this help\n", .{});
        std.debug.print("  exit/quit  Exit the interpreter\n", .{});
        std.debug.print("  version    Show version information\n", .{});
        return true;
    } else if (std.mem.eql(u8, cmd, "version")) {
        version();
        return true;
    } else if (std.mem.eql(u8, cmd, "exit") or std.mem.eql(u8, cmd, "quit")) {
        std.process.exit(0);
    }

    return false;
}

pub fn repl() !void {
    // Create arena allocator for the REPL session
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Initialize our line editor with history support
    var line_editor = try SimpleLineEditor.init(allocator, 1024);
    defer line_editor.deinit();

    // Display welcome message and version
    std.debug.print("Welcome to MufiZ Interactive Shell\n", .{});
    version();
    std.debug.print("Type 'help' for more information or 'exit' to quit\n", .{});

    while (true) {
        // Read a line with history support and no echo
        const input = (try line_editor.readLine("(mufi) >> ")) orelse {
            std.debug.print("Exiting MufiZ\n", .{});
            return;
        };

        // Skip empty lines
        if (input.len == 0) continue;

        // Check for special commands
        if (processSpecialCommand(input)) {
            continue;
        }

        // Copy to a mutable buffer for interpreter
        var mutable_buffer: [1024]u8 = undefined;
        const len = @min(input.len, mutable_buffer.len - 1);
        @memcpy(mutable_buffer[0..len], input[0..len]);
        mutable_buffer[len] = 0; // null terminate

        // Execute the code
        _ = vm_h.interpret(conv.cstr(mutable_buffer[0..len]));

        // Print a new prompt on the same line
        //std.debug.print("\n", .{});

        // Add to history after execution (even if there was an error)
        try line_editor.addHistory(input);
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
