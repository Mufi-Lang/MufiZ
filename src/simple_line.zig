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
        _ = self;
        _ = prompt;
        // STUB: Not ported to Zig 0.16 Io API yet
        return null;
    }


    // Simple fallback readline
    pub fn readLineSimple(self: *Self, prompt: []const u8) !?[]const u8 {
        _ = self;
        _ = prompt;
        // STUB: Not ported to Zig 0.16 Io API yet
        return null;
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
