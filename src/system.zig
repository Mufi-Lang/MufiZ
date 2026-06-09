const std = @import("std");
const fs = std.fs;
const mem = std.mem;

const conv = @import("conv.zig");
const mem_utils = @import("mem_utils.zig");
const SimpleLineEditor = @import("simple_line.zig").SimpleLineEditor;
const syntax = @import("syntax_min.zig");
const vm_h = @import("vm.zig");

pub var global_io: std.Io = undefined;

pub const MAJOR: u8 = 0;
pub const MINOR: u8 = 11;
pub const PATCH: u8 = 0;
const CODENAME: []const u8 = "Dusk";

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

    if (std.mem.eql(u8, cmd, "help") or std.mem.eql(u8, cmd, "?")) {
        std.debug.print("\n📚 MufiZ Interactive Help\n", .{});
        std.debug.print("═════════════════════════\n", .{});
        std.debug.print("Special commands:\n", .{});
        std.debug.print("  help, ?         Display this help\n", .{});
        std.debug.print("  exit, quit      Exit the interpreter\n", .{});
        std.debug.print("  version         Show version information\n", .{});
        std.debug.print("  clear           Clear the screen\n", .{});
        std.debug.print("  history         Show command history\n", .{});
        std.debug.print("\nLanguage features:\n", .{});
        std.debug.print("  • Variables: var x = 5;\n", .{});
        std.debug.print("  • Functions: fn add(a, b) {{ return a + b; }}\n", .{});
        std.debug.print("  • Multi-line: Start typing and continue on next lines\n", .{});
        std.debug.print("  • Math: +, -, *, /, %, pow(), sqrt(), etc.\n", .{});
        std.debug.print("  • Built-ins: print(), time(), collections, etc.\n", .{});
        std.debug.print("\n", .{});
        return true;
    } else if (std.mem.eql(u8, cmd, "version") or std.mem.eql(u8, cmd, "ver")) {
        std.debug.print("\n", .{});
        version();
        std.debug.print("\n", .{});
        return true;
    } else if (std.mem.eql(u8, cmd, "exit") or std.mem.eql(u8, cmd, "quit") or std.mem.eql(u8, cmd, "bye")) {
        std.debug.print("\n👋 Thanks for using MufiZ!\n", .{});
        std.process.exit(0);
    } else if (std.mem.eql(u8, cmd, "clear") or std.mem.eql(u8, cmd, "cls")) {
        // Clear screen using ANSI escape codes
        std.debug.print("\x1B[2J\x1B[H", .{});
        std.debug.print("🚀 MufiZ Interactive Shell\n", .{});
        version();
        std.debug.print("\n", .{});
        return true;
    }

    return false;
}

fn isStatementComplete(input: []const u8) bool {
    var brace_count: i32 = 0;
    var paren_count: i32 = 0;
    var in_string: bool = false;
    var i: usize = 0;

    while (i < input.len) {
        const c = input[i];

        // Handle string literals
        if (c == '"' and (i == 0 or input[i - 1] != '\\')) {
            in_string = !in_string;
        }

        // Only count braces/parens outside of strings
        if (!in_string) {
            switch (c) {
                '{' => brace_count += 1,
                '}' => brace_count -= 1,
                '(' => paren_count += 1,
                ')' => paren_count -= 1,
                else => {},
            }
        }

        i += 1;
    }

    // Statement is complete if all braces and parens are balanced
    return brace_count <= 0 and paren_count <= 0;
}

pub fn repl() !void {
    // Create arena allocator for the REPL session
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Set VM to REPL mode for better user experience
    vm_h.setReplMode(true);

    // Initialize our line editor with history support
    var line_editor = SimpleLineEditor.init(allocator, 2048) catch |err| {
        std.debug.print("Failed to initialize line editor: {}\n", .{err});
        std.debug.print("Falling back to simple input mode...\n", .{});
        try replSimple();
        return;
    };
    defer line_editor.deinit();

    // Display welcome message and version
    std.debug.print("\n🚀 Welcome to MufiZ REPL Shell\n", .{});
    std.debug.print("════════════════════════════════\n", .{});
    version();
    std.debug.print("Type 'help' for commands, 'exit' to quit\n", .{});
    std.debug.print("Multi-line input supported with automatic continuation\n\n", .{});

    var statement_buffer = std.ArrayList(u8).initCapacity(allocator, 0) catch unreachable;
    defer statement_buffer.deinit(allocator);

    // Accumulate all source code for proper variable persistence
    var accumulated_source = std.ArrayList(u8).initCapacity(allocator, 0) catch unreachable;
    defer accumulated_source.deinit(allocator);

    while (true) {
        // Determine the prompt based on whether we're in a multi-line statement
        const prompt = if (statement_buffer.items.len == 0) "(mufi) » " else "   │ ";

        // Try to read a line, fall back to simple mode if it fails
        const input = line_editor.readLine(prompt) catch |err| blk: {
            std.debug.print("Input error: {}. Trying simple mode...\n", .{err});
            const simple_input = line_editor.readLineSimple(prompt) catch |simple_err| {
                std.debug.print("Failed to read input: {}\n", .{simple_err});
                continue;
            };
            break :blk simple_input;
        } orelse {
            std.debug.print("\n👋 Goodbye!\n", .{});
            return;
        };

        // Trim whitespace from input
        const trimmed_input = std.mem.trim(u8, input, " \t\r\n");

        // Skip empty lines only if we're not in a multi-line statement
        if (trimmed_input.len == 0) {
            if (statement_buffer.items.len == 0) {
                continue;
            } else {
                // Empty line in multi-line mode might indicate completion
                if (isStatementComplete(statement_buffer.items)) {
                    try executeStatement(&statement_buffer, &line_editor, allocator, &accumulated_source);
                    continue;
                }
            }
        }

        // If we're starting fresh, check for special commands
        if (statement_buffer.items.len == 0 and processSpecialCommand(trimmed_input)) {
            continue;
        }

        // Add the current line to our statement buffer
        if (statement_buffer.items.len > 0) {
            try statement_buffer.append(allocator, '\n'); // Add newline between lines for proper multi-line
        }
        try statement_buffer.appendSlice(allocator, trimmed_input);

        // Check if the statement is complete
        if (isStatementComplete(statement_buffer.items)) {
            try executeStatement(&statement_buffer, &line_editor, allocator, &accumulated_source);
        }
        // If statement is not complete, continue reading more lines
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
    main_path: []const u8 = "script",
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
        return try std.Io.Dir.cwd().readFileAlloc(global_io, path, self.allocator, std.Io.Limit.limited(max_bytes));
    }

    fn run(str: []u8) InterpreterError!void {
        const result = vm_h.interpret(conv.cstr(str));
        if (result == .INTERPRET_COMPILE_ERROR) return InterpreterError.CompileError;
        if (result == .INTERPRET_RUNTIME_ERROR) return InterpreterError.RuntimeError;
    }

    pub fn setMain(self: *Self, main: []u8) !void {
        self.main = try self.read_file(main);
        self.main_path = main;
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
        // Set the source file path for error reporting
        vm_h.setSourceFile(self.main_path);

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

// Helper function to execute a complete statement
fn executeStatement(statement_buffer: *std.ArrayList(u8), line_editor: *SimpleLineEditor, allocator: std.mem.Allocator, accumulated_source: *std.ArrayList(u8)) !void {
    if (statement_buffer.items.len == 0) return;

    // Add newline separator if there's already accumulated code
    if (accumulated_source.items.len > 0) {
        try accumulated_source.append(allocator, '\n');
    }

    // Append the current statement to accumulated source
    try accumulated_source.appendSlice(allocator, statement_buffer.items);

    // Create a null-terminated buffer for the interpreter with all accumulated code
    var exec_buffer = try allocator.alloc(u8, accumulated_source.items.len + 1);
    defer allocator.free(exec_buffer);

    @memcpy(exec_buffer[0..accumulated_source.items.len], accumulated_source.items);
    exec_buffer[accumulated_source.items.len] = 0; // null terminate

    // Execute with accumulated source code for proper variable persistence
    const result = vm_h.interpret(conv.cstr(exec_buffer[0..accumulated_source.items.len]));

    // Provide feedback based on result
    switch (result) {
        .INTERPRET_OK, .INTERPRET_FINISHED => {
            // Success - no additional message needed
        },
        .INTERPRET_COMPILE_ERROR => {
            std.debug.print("💥 Compilation error - check your syntax\n", .{});
            // Remove the failed statement from accumulated source
            for (0..statement_buffer.items.len) |_| {
                if (accumulated_source.items.len > 0) {
                    accumulated_source.shrinkRetainingCapacity(accumulated_source.items.len - 1);
                }
            }
            if (accumulated_source.items.len > 0) {
                accumulated_source.shrinkRetainingCapacity(accumulated_source.items.len - 1); // Remove separator newline too
            }
        },
        .INTERPRET_RUNTIME_ERROR => {
            std.debug.print("🚨 Runtime error - check your logic\n", .{});
        },
    }

    // Add to history after execution (even if there was an error)
    try line_editor.addHistory(statement_buffer.items);

    // Clear the statement buffer for the next statement
    statement_buffer.clearRetainingCapacity();
}

// Simple fallback REPL for when the advanced line editor fails
fn replSimple() !void {
    // Ensure VM is in REPL mode
    vm_h.setReplMode(true);

    std.debug.print("\n🔧 REPL Mode (not yet ported to Zig 0.16)\n", .{});
    std.debug.print("═══════════════════════════════════════════\n", .{});
    version();
    std.debug.print("REPL functionality requires updating the Io API\n", .{});
    std.debug.print("Please use the compile command instead\n\n", .{});
}

pub fn format(file_path: []const u8) !void {
    const allocator = mem_utils.getAllocator();

    // Read the file
    const source = try std.Io.Dir.cwd().readFileAlloc(global_io, file_path, allocator, std.Io.Limit.limited(std.math.maxInt(u16)));

    defer allocator.free(source);

    // Initialize formatter
    const fmt = @import("fmt.zig");
    var formatter = fmt.Formatter.init(allocator);

    // Format the source
    const formatted = try formatter.format(source);
    defer allocator.free(formatted);

    // Write back to the file
    const output_file = try std.Io.Dir.cwd().createFile(global_io, file_path, .{});
    defer output_file.close(global_io);
    var buf: [4096]u8 = undefined;
    var writer = output_file.writer(global_io, &buf);
    try writer.interface.print("{s}", .{formatted});
    try writer.flush();

    std.debug.print("Formatted {s}\n", .{file_path});
}

pub fn generateTests() !void {
    const allocator = mem_utils.getAllocator();

    var prng = std.Random.DefaultPrng.init(12345);
    const test_gen = @import("test_gen.zig");
    var gen = test_gen.TestGenerator.init(allocator, prng.random());

    const script = try gen.generateScript();
    defer allocator.free(script);

    std.debug.print("Generated Synthetic Test:\n\n{s}\n", .{script});
}
