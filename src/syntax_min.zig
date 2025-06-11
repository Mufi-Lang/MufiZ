// Minimal syntax highlighting for MufiZ
// Provides basic ANSI colored output for code elements

const std = @import("std");
const mem = std.mem;

// ANSI color escape codes
const Color = struct {
    code: []const u8,

    const reset = "\x1b[0m";
    const bold = "\x1b[1m";

    const blue = "\x1b[34m";
    const green = "\x1b[32m";
    const cyan = "\x1b[36m";
    const yellow = "\x1b[33m";
    const magenta = "\x1b[35m";
    const red = "\x1b[31m";
    const white = "\x1b[37m";

    // Style combinations
    const keyword = bold ++ blue;
    const string = green;
    const number = yellow;
    const comment = "\x1b[90m"; // gray
    const identifier = white;
    const special = magenta;
};

// Mufi language keywords
const keywords = [_][]const u8{
    "and",  "class", "else", "each", "false", "for",     "fun",
    "if",   "item",  "let",  "nil",  "or",    "print",   "return",
    "self", "super", "true", "var",  "while", "foreach", "in",
};

// Tokenizer states
const State = enum {
    Default,
    Identifier,
    Number,
    String,
    Comment,
};

// Simple parse-as-you-go highlighter
pub fn highlight(source: []const u8, writer: anytype) !void {
    const state: State = .Default;
    var i: usize = 0;
    
    while (i < source.len) {
        const c = source[i];
        
        switch (state) {
            .Default => {
                if (isAlpha(c)) {
                    // Start of identifier
                    const start = i;
                    while (i < source.len and (isAlpha(source[i]) or isDigit(source[i]) or source[i] == '_')) {
                        i += 1;
                    }
                    const id = source[start..i];

                    // Check if keyword
                    var is_keyword = false;
                    for (keywords) |kw| {
                        if (mem.eql(u8, id, kw)) {
                            try writer.print("{s}{s}{s}", .{ Color.keyword, id, Color.reset });
                            is_keyword = true;
                            break;
                        }
                    }

                    if (!is_keyword) {
                        try writer.print("{s}", .{id});
                    }
                    continue;
                } else if (isDigit(c)) {
                    // Number
                    const start = i;
                    while (i < source.len and (isDigit(source[i]) or source[i] == '.' or source[i] == 'e' or source[i] == 'E')) {
                        i += 1;
                    }
                    try writer.print("{s}{s}{s}", .{ Color.number, source[start..i], Color.reset });
                    continue;
                } else if (c == '"') {
                    // String
                    const start = i;
                    i += 1;
                    while (i < source.len and source[i] != '"') {
                        if (source[i] == '\\' and i + 1 < source.len) {
                            i += 2;
                        } else {
                            i += 1;
                        }
                    }
                    if (i < source.len) i += 1;
                    try writer.print("{s}{s}{s}", .{ Color.string, source[start..i], Color.reset });
                    continue;
                } else if (c == '/' and i + 1 < source.len and source[i + 1] == '/') {
                    // Comment
                    const start = i;
                    i += 2;
                    while (i < source.len and source[i] != '\n') {
                        i += 1;
                    }
                    try writer.print("{s}{s}{s}", .{ Color.comment, source[start..i], Color.reset });
                    continue;
                } else if (c == '{' or c == '}' or c == '[' or c == ']' or c == '(' or c == ')') {
                    // Special characters
                    try writer.print("{s}{c}{s}", .{ Color.special, c, Color.reset });
                    i += 1;
                    continue;
                }

                // Default - just output the character
                try writer.writeAll(&[_]u8{c});
                i += 1;
            },
            else => unreachable, // We handle all states above without switching
        }
    }
}

// Check if terminal supports colors
pub fn supportsColors() bool {
    // Simple check - just assume yes for now
    // In a real implementation, would check TERM env var
    return true;
}

// Highlight and return a new string
pub fn highlightString(allocator: mem.Allocator, source: []const u8) ![]const u8 {
    var list = std.ArrayList(u8).init(allocator);
    errdefer list.deinit();

    try highlight(source, list.writer());

    return list.toOwnedSlice();
}

fn isAlpha(c: u8) bool {
    return (c >= 'a' and c <= 'z') or
        (c >= 'A' and c <= 'Z') or
        c == '_';
}

fn isDigit(c: u8) bool {
    return c >= '0' and c <= '9';
}
