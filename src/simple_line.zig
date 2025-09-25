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
            .history = std.ArrayList([]const u8).initCapacity(allocator, 8) catch unreachable,
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

        const dup = try self.allocator.dupe(u8, line);
        errdefer self.allocator.free(dup);

        try self.history.append(self.allocator, dup);
        self.history_pos = self.history.items.len;
    }

    // Read a line with non-echoing input
    pub fn readLine(self: *Self, prompt: []const u8) !?[]const u8 {
        // Print the prompt
        std.debug.print("{s}", .{prompt});

        // Use stdin for Zig 0.15 like stdlib does
        const stdin = std.fs.File.stdin();

        var pos: usize = 0;
        while (pos < self.buffer.len - 1) {
            // Try to read a byte
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

            // Basic input handling
            if (byte == '\n' or byte == '\r') {
                break;
            } else if (byte == 3) { // Ctrl+C
                std.debug.print("^C\n", .{});
                return null;
            } else if (byte >= 32 and byte < 127) { // Printable ASCII
                self.buffer[pos] = byte;
                pos += 1;
            }
        }

        // Return the line
        return self.buffer[0..pos];
    }
};
