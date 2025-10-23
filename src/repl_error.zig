// Enhanced error reporting for the MufiZ REPL
// This module provides prettier error messages for the interactive shell

const std = @import("std");
const errors = @import("errors.zig");
const mem = std.mem;
const print = std.debug.print;

pub const ErrorDisplayStyle = enum {
    Simple, // Single line error
    Detailed, // Multi-line error with source context and pointer
    Interactive, // Special formatting for REPL
};

// Colors for error messages
const ErrorColors = struct {
    error_text: []const u8 = "\x1b[1;31m", // Bold red
    error_label: []const u8 = "\x1b[1;35m", // Bold magenta
    line_number: []const u8 = "\x1b[90m", // Gray
    hint: []const u8 = "\x1b[36m", // Cyan
    pointer: []const u8 = "\x1b[1;33m", // Bold yellow
    reset: []const u8 = "\x1b[0m", // Reset

    pub fn init() ErrorColors {
        return ErrorColors{};
    }
};

pub const ReplErrorReporter = struct {
    style: ErrorDisplayStyle = .Interactive,
    color_enabled: bool = true,

    const Self = @This();

    pub fn init() Self {
        return Self{
            .style = .Interactive,
            .color_enabled = checkTerminalSupportsColors(),
        };
    }

    // Format and display a single error
    pub fn report(self: Self, err: errors.ErrorInfo) void {
        const colors = if (self.color_enabled) ErrorColors.init() else ErrorColors{
            .error_text = "",
            .error_label = "",
            .line_number = "",
            .hint = "",
            .pointer = "",
            .reset = "",
        };

        switch (self.style) {
            .Simple => self.reportSimple(err, colors),
            .Detailed => self.reportDetailed(err, colors),
            .Interactive => self.reportInteractive(err, colors),
        }
    }

    fn reportSimple(self: Self, err: errors.ErrorInfo, colors: ErrorColors) void {
        _ = self;
        print("{s}Error{s}: {s}\n", .{ colors.error_text, colors.reset, err.message });
    }

    fn reportDetailed(self: Self, err: errors.ErrorInfo, colors: ErrorColors) void {
        _ = self;
        // Print error header with location
        print("{s}Error{s} in ", .{ colors.error_text, colors.reset });
        if (err.filename) |name| {
            print("file {s}", .{name});
        } else {
            print("interactive session", .{});
        }

        print(" at line {d}: {s}{s}\n", .{ err.line, colors.error_label, err.message });
        print("{s}\n", .{colors.reset});

        // Print the code context if available
        if (err.source_line) |source| {
            // Print line number and source line
            print("{s}  {d} │{s} {s}\n", .{ colors.line_number, err.line, colors.reset, source });

            // Print error pointer
            if (err.column >= 0 and err.column <= source.len) {
                const indent = err.column;
                var pointer_buf: [256]u8 = undefined;
                const pointer_str = blk: {
                    var i: usize = 0;
                    while (i < indent) : (i += 1) {
                        pointer_buf[i] = ' ';
                    }
                    pointer_buf[i] = '^';
                    i += 1;

                    if (err.error_length > 1) {
                        var j: usize = 1;
                        while (j < err.error_length and i < pointer_buf.len - 1) : (j += 1) {
                            pointer_buf[i] = '~';
                            i += 1;
                        }
                    }

                    break :blk pointer_buf[0..i];
                };

                print("{s}     │{s} {s}{s}{s}\n", .{ colors.line_number, colors.reset, colors.pointer, pointer_str, colors.reset });
            }
        }

        // Print suggestions if available
        if (err.suggestions.len > 0) {
            print("\n{s}Suggestions:{s}\n", .{ colors.hint, colors.reset });
            for (err.suggestions) |suggestion| {
                print(" - {s}\n", .{suggestion.message});
                if (suggestion.example.len > 0) {
                    print("   Example: {s}\n", .{suggestion.example});
                }
            }
        }

        print("\n", .{});
    }

    fn reportInteractive(self: Self, err: errors.ErrorInfo, colors: ErrorColors) void {
        _ = self;
        // Use a cleaner format specially designed for the REPL
        print("{s}Error{s}: {s}\n", .{ colors.error_text, colors.reset, err.message });

        // Print the code context if available
        if (err.source_line) |source| {
            // In REPL we don't need to show the file info, just the line
            print("{s}  │{s} {s}\n", .{ colors.line_number, colors.reset, source });

            // Print error pointer
            if (err.column >= 0 and err.column <= source.len) {
                const indent = err.column;
                var pointer_buf: [256]u8 = undefined;
                const pointer_str = blk: {
                    var i: usize = 0;
                    while (i < indent) : (i += 1) {
                        pointer_buf[i] = ' ';
                    }
                    pointer_buf[i] = '^';
                    i += 1;

                    if (err.error_length > 1) {
                        var j: usize = 1;
                        while (j < err.error_length and i < pointer_buf.len - 1) : (j += 1) {
                            pointer_buf[i] = '~';
                            i += 1;
                        }
                    }

                    break :blk pointer_buf[0..i];
                };

                print("{s}  │{s} {s}{s}{s}\n", .{ colors.line_number, colors.reset, colors.pointer, pointer_str, colors.reset });
            }
        }

        // Print the first suggestion inline
        if (err.suggestions.len > 0) {
            print("{s}Hint:{s} {s}\n", .{ colors.hint, colors.reset, err.suggestions[0].message });
        }
    }

    pub fn setStyle(self: *Self, style: ErrorDisplayStyle) void {
        self.style = style;
    }

    pub fn enableColors(self: *Self, enable: bool) void {
        self.color_enabled = enable;
    }
};

// Check if the terminal supports colors
fn checkTerminalSupportsColors() bool {
    const term = std.process.getEnvVarOwned(std.heap.page_allocator, "TERM") catch return false;
    defer std.heap.page_allocator.free(term);

    // Check if terminal supports colors
    if (mem.indexOf(u8, term, "color") != null or
        mem.eql(u8, term, "xterm") or
        mem.eql(u8, term, "rxvt") or
        mem.eql(u8, term, "linux") or
        mem.indexOf(u8, term, "256") != null)
    {
        return true;
    }

    // Check for NO_COLOR environment variable (https://no-color.org/)
    const has_no_color = std.process.hasEnvVar(std.heap.page_allocator, "NO_COLOR") catch false;
    if (has_no_color) {
        return false;
    }

    return false;
}
