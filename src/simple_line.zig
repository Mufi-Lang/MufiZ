// Simple line editing with history support for MufiZ
// This provides basic line editing with proper input handling

const std = @import("std");

pub const SimpleLineEditor = struct {
    history: std.ArrayList([]const u8),
    history_pos: usize,
    buffer: []u8,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, buffer_size: usize) !Self {
        return Self{
            .history = std.ArrayList([]const u8).initCapacity(allocator, 0) catch unreachable,
            .history_pos = 0,
            .buffer = try allocator.alloc(u8, buffer_size),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.history.items) |item| {
            self.allocator.free(item);
        }
        self.history.deinit(self.allocator);
        self.allocator.free(self.buffer);
    }

    pub fn addHistory(self: *Self, line: []const u8) !void {
        if (line.len == 0) return;

        // Don't add duplicate entries
        if (self.history.items.len > 0 and std.mem.eql(u8, self.history.items[self.history.items.len - 1], line)) {
            return;
        }

        const dup = try self.allocator.dupe(u8, line);
        try self.history.append(self.allocator, dup);
        self.history_pos = self.history.items.len;
    }

    // Read a line with basic terminal handling
    pub fn readLine(self: *Self, prompt: []const u8) !?[]const u8 {
        // Print the prompt
        std.debug.print("{s}", .{prompt});

        // Use the same pattern as stdlib/io.zig
        const stdin = std.fs.File.stdin();
        var pos: usize = 0;

        // Read characters until newline or buffer full
        while (pos < self.buffer.len - 1) {
            var byte_buffer: [1]u8 = undefined;
            const amt = stdin.read(byte_buffer[0..]) catch |err| {
                if (err == error.EndOfStream) {
                    if (pos == 0) return null;
                    break;
                }
                return err;
            };

            if (amt == 0) {
                if (pos == 0) return null;
                break;
            }

            const byte = byte_buffer[0];

            switch (byte) {
                '\n', '\r' => {
                    break;
                },
                3 => { // Ctrl+C
                    std.debug.print("^C\n", .{});
                    return null;
                },
                4 => { // Ctrl+D (EOF)
                    if (pos == 0) return null;
                    break;
                },
                8, 127 => { // Backspace or DEL
                    if (pos > 0) {
                        pos -= 1;
                        // Basic backspace handling
                        std.debug.print("\x08 \x08", .{});
                    }
                },
                9 => { // Tab - ignore for now
                    continue;
                },
                else => {
                    if (byte >= 32 and byte < 127) { // Printable ASCII
                        self.buffer[pos] = byte;
                        pos += 1;
                        // No manual echo - let terminal handle it
                    }
                },
            }
        }

        // No manual newline - terminal handles this

        return self.buffer[0..pos];
    }

    // Simple fallback readline
    pub fn readLineSimple(self: *Self, prompt: []const u8) !?[]const u8 {
        std.debug.print("{s}", .{prompt});

        const stdin = std.fs.File.stdin();
        var pos: usize = 0;

        while (pos < self.buffer.len - 1) {
            var byte_buffer: [1]u8 = undefined;
            const amt = stdin.read(byte_buffer[0..]) catch return null;

            if (amt == 0) break;

            const byte = byte_buffer[0];
            if (byte == '\n' or byte == '\r') {
                break;
            } else if (byte >= 32 and byte < 127) {
                self.buffer[pos] = byte;
                pos += 1;
            }
        }

        return self.buffer[0..pos];
    }

    // Get a line from history
    pub fn getHistoryLine(self: Self, index: usize) ?[]const u8 {
        if (index >= self.history.items.len) return null;
        return self.history.items[index];
    }

    // Get the current history position
    pub fn getHistoryPos(self: Self) usize {
        return self.history_pos;
    }

    // Set history position
    pub fn setHistoryPos(self: *Self, pos: usize) void {
        self.history_pos = @min(pos, self.history.items.len);
    }

    // Clear the current line buffer
    pub fn clearBuffer(self: *Self) void {
        @memset(self.buffer, 0);
    }
};
