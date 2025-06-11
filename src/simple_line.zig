// Simple line editing with history support for MufiZ
// This provides basic line editing with non-echoing input

const std = @import("std");

pub const SimpleLineEditor = struct {
    history: std.ArrayList([]const u8),
    history_pos: usize,
    buffer: []u8,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, buffer_size: usize) !Self {
        return Self{
            .history = std.ArrayList([]const u8).init(allocator),
            .history_pos = 0,
            .buffer = try allocator.alloc(u8, buffer_size),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        // Free each history item
        for (self.history.items) |item| {
            self.allocator.free(item);
        }
        self.history.deinit();
        self.allocator.free(self.buffer);
    }

    pub fn addHistory(self: *Self, line: []const u8) !void {
        // Don't add empty lines
        if (line.len == 0) return;

        // Don't add if identical to previous entry
        if (self.history.items.len > 0) {
            const last = self.history.items[self.history.items.len - 1];
            if (std.mem.eql(u8, last, line)) return;
        }

        // Add to history
        const dup = try self.allocator.alloc(u8, line.len);
        @memcpy(dup, line);
        try self.history.append(dup);
        self.history_pos = self.history.items.len;
    }

    // Read a line with non-echoing input
    pub fn readLine(self: *Self, prompt: []const u8) !?[]const u8 {
        const stdin = std.io.getStdIn();
        var stdout = std.io.getStdOut().writer();

        try stdout.writeAll(prompt);

        // Simple line reading with non-echoing input
        var pos: usize = 0;

        while (pos < self.buffer.len - 1) {
            const byte = stdin.reader().readByte() catch |err| {
                if (err == error.EndOfStream) {
                    try stdout.writeAll("\n");
                    if (pos == 0) return null;
                    break;
                }
                return err;
            };

            // Handle input
            switch (byte) {
                '\r', '\n' => {
                    // Do not print a newline, keep output clean
                    break;
                },
                8, 127 => { // backspace
                    if (pos > 0) {
                        pos -= 1;
                        try stdout.writeAll("\x08 \x08"); // backspace, space, backspace
                    }
                },
                3 => { // Ctrl+C
                    try stdout.writeAll("^C\n");
                    return null;
                },
                4 => { // Ctrl+D (EOF)
                    if (pos == 0) {
                        try stdout.writeAll("\n");
                        return null;
                    }
                },
                else => {
                    if (byte >= 32 and byte < 127) { // printable ASCII
                        self.buffer[pos] = byte;
                        pos += 1;
                        // Don't echo the character, stay silent
                    }
                },
            }
        }

        // Do not echo the input at all

        // Successfully read a line but do not echo it back
        return self.buffer[0..pos];
    }
};
