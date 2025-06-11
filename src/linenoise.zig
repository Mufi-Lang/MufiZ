// MufiZ Line Editing Library
// A simple line editing and history management implementation

const std = @import("std");

pub const LineNoiseError = error{
    NoTerminal,
    InputTooLong,
    Interrupted,
    IOError,
};

// LineNoise struct to manage the state
pub const LineNoise = struct {
    history: std.ArrayList([]const u8),
    current_history: usize,
    max_history: usize,
    allocator: std.mem.Allocator,
    buffer: []u8,
    prompt: []const u8,
    multiline_mode: bool,
    is_tty: bool,

    const HISTORY_DEFAULT_MAX = 100;
    const BUFFER_DEFAULT_SIZE = 4096;

    pub fn init(allocator: std.mem.Allocator) !*LineNoise {
        const ln = try allocator.create(LineNoise);
        ln.* = LineNoise{
            .history = std.ArrayList([]const u8).init(allocator),
            .current_history = 0,
            .max_history = HISTORY_DEFAULT_MAX,
            .allocator = allocator,
            .buffer = try allocator.alloc(u8, BUFFER_DEFAULT_SIZE),
            .prompt = ">> ",
            .multiline_mode = false,
            .is_tty = std.io.getStdIn().isTty(),
        };
        return ln;
    }

    pub fn deinit(self: *LineNoise) void {
        for (self.history.items) |item| {
            self.allocator.free(item);
        }
        self.history.deinit();
        self.allocator.free(self.buffer);
        self.allocator.destroy(self);
    }

    pub fn setPrompt(self: *LineNoise, prompt: []const u8) void {
        self.prompt = prompt;
    }

    pub fn setMultiline(self: *LineNoise, enable: bool) void {
        self.multiline_mode = enable;
    }

    pub fn setHistoryMaxLen(self: *LineNoise, len: usize) void {
        self.max_history = len;
        self.trimHistory();
    }

    fn trimHistory(self: *LineNoise) void {
        while (self.history.items.len > self.max_history) {
            const item = self.history.orderedRemove(0);
            self.allocator.free(item);
        }
    }

    pub fn addHistory(self: *LineNoise, line: []const u8) !void {
        // Don't add empty lines or duplicates of the last entry
        if (line.len == 0 or (self.history.items.len > 0 and std.mem.eql(u8, self.history.items[self.history.items.len - 1], line))) {
            return;
        }

        const dup = try self.allocator.alloc(u8, line.len);
        @memcpy(dup, line);
        try self.history.append(dup);
        
        self.trimHistory();
        self.current_history = self.history.items.len;
    }

    pub fn clearHistory(self: *LineNoise) void {
        for (self.history.items) |item| {
            self.allocator.free(item);
        }
        self.history.clearAndFree();
        self.current_history = 0;
    }

    pub fn loadHistory(self: *LineNoise, path: []const u8) !void {
        const file = std.fs.cwd().openFile(path, .{}) catch |err| {
            if (err == error.FileNotFound) return;
            return err;
        };
        defer file.close();

        var buf_reader = std.io.bufferedReader(file.reader());
        var in_stream = buf_reader.reader();

        var buf: [BUFFER_DEFAULT_SIZE]u8 = undefined;
        while (true) {
            const line = in_stream.readUntilDelimiterOrEof(&buf, '\n') catch break;
            if (line == null) break;
            try self.addHistory(line.?);
        }
    }

    pub fn saveHistory(self: *LineNoise, path: []const u8) !void {
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        var writer = file.writer();
        for (self.history.items) |item| {
            try writer.writeAll(item);
            try writer.writeByte('\n');
        }
    }

    // Simple readline implementation without terminal control
    pub fn readline(self: *LineNoise) !?[]const u8 {
        // Print prompt
        var stdout = std.io.getStdOut().writer();
        try stdout.writeAll(self.prompt);
        
        // Read line from stdin
        var stdin = std.io.getStdIn().reader();
        
        var i: usize = 0;
        while (i < self.buffer.len - 1) {
            const byte = stdin.readByte() catch |err| {
                if (err == error.EndOfStream) {
                    if (i == 0) return null;
                    break;
                }
                return err;
            };
            
            if (byte == '\n') break;
            
            // Handle backspace/delete
            if (byte == 127 or byte == 8) {
                if (i > 0) {
                    i -= 1;
                    // Erase character from terminal
                    if (self.is_tty) {
                        try stdout.writeAll("\x08 \x08");
                    }
                }
                continue;
            }
            
            // Handle Ctrl+C
            if (byte == 3) {
                try stdout.writeByte('\n');
                return null;
            }
            
            // Handle Ctrl+D
            if (byte == 4 and i == 0) {
                try stdout.writeByte('\n');
                return null;
            }
            
            // Only accept printable characters
            if (byte >= 32) {
                self.buffer[i] = byte;
                i += 1;
                
                // Echo character
                if (self.is_tty) {
                    try stdout.writeByte(byte);
                }
            }
        }
        
        try stdout.writeByte('\n');
        
        // Return the read line
        if (i > 0) {
            try self.addHistory(self.buffer[0..i]);
        }
        
        return self.buffer[0..i];
    }
};