// Syntax highlighting for MufiZ language
// This module provides ANSI color highlighting for the REPL

const std = @import("std");
const mem = std.mem;

pub const SyntaxColors = struct {
    keyword: []const u8 = "\x1b[1;34m", // bold blue
    string: []const u8 = "\x1b[32m",    // green
    number: []const u8 = "\x1b[33m",    // yellow
    comment: []const u8 = "\x1b[90m",   // gray
    operator: []const u8 = "\x1b[1;37m", // bright white
    identifier: []const u8 = "\x1b[37m", // white
    special: []const u8 = "\x1b[35m",   // magenta
    error_: []const u8 = "\x1b[31m",     // red
    reset: []const u8 = "\x1b[0m",      // reset

    pub fn init() SyntaxColors {
        return SyntaxColors{};
    }
};

// Keywords in the MufiZ language
const keywords = [_][]const u8{
    "and", "class", "else", "each", "false", "for", "fun", 
    "if", "item", "let", "nil", "or", "print", "return", 
    "self", "super", "true", "var", "while", "foreach", "in"
};

// Simple tokenizer states
const State = enum {
    Default,
    Identifier,
    Number,
    String,
    Comment,
    Operator,
};

pub fn highlightCode(code: []const u8, allocator: std.mem.Allocator) ![]const u8 {
    const colors = SyntaxColors.init();
    var result = std.ArrayList(u8).init(allocator);
    errdefer result.deinit();

    var state: State = .Default;
    var i: usize = 0;

    while (i < code.len) {
        const c = code[i];

        switch (state) {
            .Default => {
                if (isAlpha(c)) {
                    // Start of identifier
                    const start = i;
                    while (i < code.len and (isAlpha(code[i]) or isDigit(code[i]) or code[i] == '_')) {
                        i += 1;
                    }
                    const id = code[start..i];
                    
                    // Check if it's a keyword
                    var is_keyword = false;
                    for (keywords) |keyword| {
                        if (mem.eql(u8, id, keyword)) {
                            try result.appendSlice(colors.keyword);
                            try result.appendSlice(id);
                            try result.appendSlice(colors.reset);
                            is_keyword = true;
                            break;
                        }
                    }

                    if (!is_keyword) {
                        try result.appendSlice(colors.identifier);
                        try result.appendSlice(id);
                        try result.appendSlice(colors.reset);
                    }
                    continue;
                } else if (isDigit(c)) {
                    // Start of number
                    state = .Number;
                    try result.appendSlice(colors.number);
                    try result.append(c);
                } else if (c == '"') {
                    // Start of string
                    state = .String;
                    try result.appendSlice(colors.string);
                    try result.append(c);
                } else if (c == '/' and i + 1 < code.len and code[i + 1] == '/') {
                    // Start of comment
                    state = .Comment;
                    try result.appendSlice(colors.comment);
                    try result.append(c);
                } else if (isOperator(c)) {
                    // Operator
                    try result.appendSlice(colors.operator);
                    try result.append(c);
                    try result.appendSlice(colors.reset);
                } else if (c == '{' or c == '}' or c == '[' or c == ']' or c == '(' or c == ')') {
                    // Special character (brackets, parentheses)
                    try result.appendSlice(colors.special);
                    try result.append(c);
                    try result.appendSlice(colors.reset);
                } else {
                    // Any other character
                    try result.append(c);
                }
            },
            .Number => {
                if (isDigit(c) or c == '.' or c == 'e' or c == 'E' or 
                    ((c == '+' or c == '-') and (i > 0 and (code[i-1] == 'e' or code[i-1] == 'E')))) {
                    try result.append(c);
                } else {
                    try result.appendSlice(colors.reset);
                    state = .Default;
                    continue;
                }
            },
            .String => {
                try result.append(c);
                if (c == '"' and (i == 0 or code[i-1] != '\\')) {
                    try result.appendSlice(colors.reset);
                    state = .Default;
                }
            },
            .Comment => {
                try result.append(c);
                if (c == '\n') {
                    try result.appendSlice(colors.reset);
                    state = .Default;
                }
            },
            else => {
                try result.append(c);
                state = .Default;
            },
        }
        i += 1;
    }

    // Reset color if we're still in a special state
    if (state != .Default) {
        try result.appendSlice(colors.reset);
    }

    return result.toOwnedSlice();
}

inline fn isAlpha(c: u8) bool {
    return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or c == '_';
}

inline fn isDigit(c: u8) bool {
    return c >= '0' and c <= '9';
}

inline fn isOperator(c: u8) bool {
    return switch (c) {
        '+', '-', '*', '/', '%', '=', '<', '>', '!', '&', '|', '^', '~', ':', '.', ',' => true,
        else => false,
    };
}

// This function can be used to enable/disable syntax highlighting based on terminal capabilities
pub fn isSyntaxHighlightingSupported() bool {
    const term = std.process.getEnvVarOwned(std.heap.page_allocator, "TERM") catch return false;
    defer std.heap.page_allocator.free(term);
    
    // Check if terminal supports colors
    if (mem.indexOf(u8, term, "color") != null or 
        mem.eql(u8, term, "xterm") or 
        mem.eql(u8, term, "rxvt") or
        mem.eql(u8, term, "linux") or
        mem.indexOf(u8, term, "256") != null) {
        return true;
    }
    
    // Check for NO_COLOR environment variable (https://no-color.org/)
    const has_no_color = std.process.hasEnvVar(std.heap.page_allocator, "NO_COLOR") catch false;
    if (has_no_color) {
        return false;
    }
    
    return false;
}