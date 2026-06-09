const std = @import("std");
const testing = std.testing;

const scanner_h = @import("scanner_optimized.zig");
const TokenType = scanner_h.TokenType;

/// MufiZ Code Formatter
/// Implements formatting logic based on the formal PEG grammar.
pub const Formatter = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Formatter {
        return .{ .allocator = allocator };
    }

    /// Formats the provided Mufi-Lang source code.
    /// Returns a new allocated string with the formatted code.
    pub fn format(self: *Formatter, source: []const u8) ![]u8 {
        var output = std.ArrayList(u8).initCapacity(self.allocator, 0) catch unreachable;
        defer output.deinit(self.allocator);

        // Initialize scanner
        // The scanner expects a null-terminated string or at least a stable pointer.
        // We'll create a null-terminated copy to be safe.
        const source_z = try self.allocator.dupeZ(u8, source);
        defer self.allocator.free(source_z);

        scanner_h.init_scanner(source_z.ptr);

        var indent_level: usize = 0;
        var last_token_type: ?TokenType = null;
        var at_start_of_line = true;

        while (true) {
            const token = scanner_h.scanToken();
            if (token.type == .TOKEN_EOF) break;
            if (token.type == .TOKEN_ERROR) {
                return try self.allocator.dupe(u8, source);
            }

            const token_text = token.start[0..@intCast(token.length)];

            if (token.type == .TOKEN_RIGHT_BRACE) {
                if (indent_level > 0) indent_level -= 1;
            }

            if (at_start_of_line) {
                var i: usize = 0;
                while (i < indent_level) : (i += 1) {
                    try output.appendSlice(self.allocator, "    ");
                }
                at_start_of_line = false;
            } else if (last_token_type) |last| {
                // Add spacing logic
                const is_op = switch (token.type) {
                    .TOKEN_EQUAL, .TOKEN_EQUAL_EQUAL, .TOKEN_PLUS, .TOKEN_MINUS, .TOKEN_STAR, .TOKEN_SLASH, .TOKEN_GREATER, .TOKEN_GREATER_EQUAL, .TOKEN_LESS, .TOKEN_LESS_EQUAL, .TOKEN_BANG_EQUAL, .TOKEN_PERCENT, .TOKEN_ARROW, .TOKEN_AND, .TOKEN_OR, .TOKEN_QUESTION, .TOKEN_COLON => true,
                    else => false,
                };

                const last_was_op = switch (last) {
                    .TOKEN_EQUAL, .TOKEN_EQUAL_EQUAL, .TOKEN_PLUS, .TOKEN_MINUS, .TOKEN_STAR, .TOKEN_SLASH, .TOKEN_GREATER, .TOKEN_GREATER_EQUAL, .TOKEN_LESS, .TOKEN_LESS_EQUAL, .TOKEN_BANG_EQUAL, .TOKEN_PERCENT, .TOKEN_ARROW, .TOKEN_AND, .TOKEN_OR, .TOKEN_QUESTION, .TOKEN_COLON, .TOKEN_COMMA => true,
                    else => false,
                };

                const is_keyword = switch (token.type) {
                    .TOKEN_VAR, .TOKEN_CONST, .TOKEN_FUN, .TOKEN_CLASS, .TOKEN_IF, .TOKEN_WHILE, .TOKEN_FOR, .TOKEN_FOREACH, .TOKEN_RETURN => true,
                    else => false,
                };

                const last_was_keyword = switch (last) {
                    .TOKEN_VAR, .TOKEN_CONST, .TOKEN_FUN, .TOKEN_CLASS, .TOKEN_IF, .TOKEN_WHILE, .TOKEN_FOR, .TOKEN_FOREACH, .TOKEN_RETURN => true,
                    else => false,
                };

                const needs_space = is_op or last_was_op or is_keyword or last_was_keyword or (token.type == .TOKEN_LEFT_BRACE and last != .TOKEN_LEFT_PAREN);

                if (needs_space) {
                    if (output.items.len > 0 and output.items[output.items.len - 1] != '\n' and output.items[output.items.len - 1] != ' ') {
                        try output.append(self.allocator, ' ');
                    }
                }
            }

            try output.appendSlice(self.allocator, token_text);

            if (token.type == .TOKEN_LEFT_BRACE) {
                indent_level += 1;
            }

            if (token.type == .TOKEN_SEMICOLON or token.type == .TOKEN_LEFT_BRACE or token.type == .TOKEN_RIGHT_BRACE) {
                try output.append(self.allocator, '\n');
                at_start_of_line = true;
            }

            last_token_type = token.type;
        }

        // Final newline if missing
        if (output.items.len > 0 and output.items[output.items.len - 1] != '\n') {
            try output.append(self.allocator, '\n');
        }

        return output.toOwnedSlice(self.allocator);
    }
};

test "basic formatting - indentation" {
    var fmt = Formatter.init(testing.allocator);
    const source = "fun main() {\nprint(\"hello\");\n}";
    const expected = "fun main() {\n    print(\"hello\");\n}\n";

    const result = try fmt.format(source);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings(expected, result);
}

test "basic formatting - spacing" {
    var fmt = Formatter.init(testing.allocator);
    const source = "var x=10+20;";
    const expected = "var x = 10 + 20;\n";

    const result = try fmt.format(source);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings(expected, result);
}

// ============================================================================
// Public API Functions (for library use)
// ============================================================================

/// Format a MufiZ source string
/// Returns allocated formatted string (caller must free)
pub fn formatSource(allocator: std.mem.Allocator, source: []const u8) ![]const u8 {
    var formatter = Formatter.init(allocator);
    return try formatter.format(source);
}

/// Format a MufiZ file in-place
/// Note: Not implemented in Zig 0.16+ due to API changes
pub fn formatFile(allocator: std.mem.Allocator, filepath: []const u8) !void {
    _ = allocator;
    _ = filepath;
    return error.NotImplementedInZig016;
}
