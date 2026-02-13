const std = @import("std");
const testing = std.testing;
const scanner = @import("scanner_optimized.zig");

// Helper function to scan and return first non-whitespace token
fn scanAfterWhitespace(source: []const u8) scanner.TokenType {
    var buf: [1024]u8 = undefined;
    @memcpy(buf[0..source.len], source);
    buf[source.len] = 0;
    scanner.init_scanner(&buf);
    const token = scanner.scanToken();
    return token.type;
}

// Helper to count line numbers after scanning
fn getLineAfterScan(source: []const u8) i32 {
    var buf: [1024]u8 = undefined;
    @memcpy(buf[0..source.len], source);
    buf[source.len] = 0;
    scanner.init_scanner(&buf);
    _ = scanner.scanToken();
    return scanner.scanner.line;
}

// Test basic whitespace skipping
test "fsm whitespace: basic spaces and tabs" {
    const source = "     \t\t   if";
    const token_type = scanAfterWhitespace(source);
    try testing.expectEqual(scanner.TokenType.TOKEN_IF, token_type);
}

// Test newline handling and line counting
test "fsm whitespace: newlines increment line counter" {
    const source = "\n\n\nif";
    var buf: [1024]u8 = undefined;
    @memcpy(buf[0..source.len], source);
    buf[source.len] = 0;
    scanner.init_scanner(&buf);
    _ = scanner.scanToken();
    try testing.expectEqual(@as(i32, 4), scanner.scanner.line);
}

// Test mixed whitespace
test "fsm whitespace: mixed spaces, tabs, newlines" {
    const source = "  \t\n \n\t  \n  for";
    const token_type = scanAfterWhitespace(source);
    try testing.expectEqual(scanner.TokenType.TOKEN_FOR, token_type);
}

// Test single-line comment
test "fsm whitespace: single-line comment basic" {
    const source = "// this is a comment\nif";
    const token_type = scanAfterWhitespace(source);
    try testing.expectEqual(scanner.TokenType.TOKEN_IF, token_type);
}

// Test single-line comment at EOF
test "fsm whitespace: single-line comment at EOF" {
    const source = "if // comment at end";
    var buf: [1024]u8 = undefined;
    @memcpy(buf[0..source.len], source);
    buf[source.len] = 0;
    scanner.init_scanner(&buf);
    const token1 = scanner.scanToken();
    try testing.expectEqual(scanner.TokenType.TOKEN_IF, token1.type);
    const token2 = scanner.scanToken();
    try testing.expectEqual(scanner.TokenType.TOKEN_EOF, token2.type);
}

// Test single-line comment with content
test "fsm whitespace: single-line comment with special chars" {
    const source = "// comment with !@#$%^&*() symbols\nwhile";
    const token_type = scanAfterWhitespace(source);
    try testing.expectEqual(scanner.TokenType.TOKEN_WHILE, token_type);
}

// Test multiple single-line comments
test "fsm whitespace: multiple single-line comments" {
    const source =
        \\// first comment
        \\// second comment
        \\// third comment
        \\class
    ;
    const token_type = scanAfterWhitespace(source);
    try testing.expectEqual(scanner.TokenType.TOKEN_CLASS, token_type);
}

// Test multi-line comment basic
test "fsm whitespace: multi-line comment basic" {
    const source = "/# this is a multi-line comment #/if";
    const token_type = scanAfterWhitespace(source);
    try testing.expectEqual(scanner.TokenType.TOKEN_IF, token_type);
}

// Test multi-line comment with newlines
test "fsm whitespace: multi-line comment with newlines" {
    const source =
        \\/# multi-line
        \\comment spanning
        \\multiple lines #/
        \\fun
    ;
    const token_type = scanAfterWhitespace(source);
    try testing.expectEqual(scanner.TokenType.TOKEN_FUN, token_type);
}

// Test nested multi-line comments
test "fsm whitespace: nested multi-line comments level 1" {
    const source = "/# outer /# inner #/ outer #/var";
    const token_type = scanAfterWhitespace(source);
    try testing.expectEqual(scanner.TokenType.TOKEN_VAR, token_type);
}

// Test deeply nested multi-line comments
test "fsm whitespace: nested multi-line comments level 3" {
    const source = "/# level1 /# level2 /# level3 #/ back2 #/ back1 #/return";
    const token_type = scanAfterWhitespace(source);
    try testing.expectEqual(scanner.TokenType.TOKEN_RETURN, token_type);
}

// Test multi-line comment line counting
test "fsm whitespace: multi-line comment tracks newlines" {
    const source =
        \\/# comment
        \\line 2
        \\line 3 #/
        \\if
    ;
    var buf: [1024]u8 = undefined;
    @memcpy(buf[0..source.len], source);
    buf[source.len] = 0;
    scanner.init_scanner(&buf);
    _ = scanner.scanToken();
    try testing.expectEqual(@as(i32, 4), scanner.scanner.line);
}

// Test mixed whitespace and comments
test "fsm whitespace: mixed whitespace and single-line comments" {
    const source =
        \\  // comment 1
        \\
        \\  // comment 2
        \\
        \\while
    ;
    const token_type = scanAfterWhitespace(source);
    try testing.expectEqual(scanner.TokenType.TOKEN_WHILE, token_type);
}

// Test mixed single and multi-line comments
test "fsm whitespace: mixed single and multi-line comments" {
    const source =
        \\// single line
        \\/# multi
        \\line #/
        \\// another single
        \\break
    ;
    const token_type = scanAfterWhitespace(source);
    try testing.expectEqual(scanner.TokenType.TOKEN_BREAK, token_type);
}

// Test comment immediately followed by token
test "fsm whitespace: comment immediately before token" {
    const source = "//comment\nfor";
    const token_type = scanAfterWhitespace(source);
    try testing.expectEqual(scanner.TokenType.TOKEN_FOR, token_type);
}

// Test whitespace between tokens
test "fsm whitespace: whitespace between multiple tokens" {
    const source = "if   \t\n  for";
    var buf: [1024]u8 = undefined;
    @memcpy(buf[0..source.len], source);
    buf[source.len] = 0;
    scanner.init_scanner(&buf);

    const token1 = scanner.scanToken();
    try testing.expectEqual(scanner.TokenType.TOKEN_IF, token1.type);

    const token2 = scanner.scanToken();
    try testing.expectEqual(scanner.TokenType.TOKEN_FOR, token2.type);
}

// Test empty input
test "fsm whitespace: empty input" {
    var buf: [1]u8 = .{0};
    scanner.init_scanner(&buf);
    const token = scanner.scanToken();
    try testing.expectEqual(scanner.TokenType.TOKEN_EOF, token.type);
}

// Test only whitespace
test "fsm whitespace: only whitespace" {
    const source = "   \t\n\n  \t  ";
    const token_type = scanAfterWhitespace(source);
    try testing.expectEqual(scanner.TokenType.TOKEN_EOF, token_type);
}

// Test only comments
test "fsm whitespace: only single-line comment" {
    const source = "// just a comment";
    const token_type = scanAfterWhitespace(source);
    try testing.expectEqual(scanner.TokenType.TOKEN_EOF, token_type);
}

test "fsm whitespace: only multi-line comment" {
    const source = "/# just a comment #/";
    const token_type = scanAfterWhitespace(source);
    try testing.expectEqual(scanner.TokenType.TOKEN_EOF, token_type);
}

// Test comment with forward slash that's not a comment start
test "fsm whitespace: single slash not comment" {
    const source = "/ + / if";
    var buf: [1024]u8 = undefined;
    @memcpy(buf[0..source.len], source);
    buf[source.len] = 0;
    scanner.init_scanner(&buf);

    const token1 = scanner.scanToken();
    try testing.expectEqual(scanner.TokenType.TOKEN_SLASH, token1.type);
}

// Test nested comments with newlines
test "fsm whitespace: nested comments preserve line count" {
    const source =
        \\/# outer
        \\   /# inner
        \\   more inner #/
        \\   more outer
        \\#/
        \\fun
    ;
    var buf: [1024]u8 = undefined;
    @memcpy(buf[0..source.len], source);
    buf[source.len] = 0;
    scanner.init_scanner(&buf);
    _ = scanner.scanToken();
    try testing.expectEqual(@as(i32, 6), scanner.scanner.line);
}

// Test performance: long whitespace sequence
test "fsm whitespace: long whitespace sequence" {
    var buf: [2048]u8 = undefined;
    var i: usize = 0;
    while (i < 1000) : (i += 1) {
        buf[i] = ' ';
    }
    const if_str = "if";
    @memcpy(buf[1000..1002], if_str);
    buf[1002] = 0;

    scanner.init_scanner(&buf);
    const token = scanner.scanToken();
    try testing.expectEqual(scanner.TokenType.TOKEN_IF, token.type);
}

// Test state transitions: Normal -> SingleLine -> Normal
test "fsm whitespace: state transition normal to single-line" {
    const source = "//\nif";
    const token_type = scanAfterWhitespace(source);
    try testing.expectEqual(scanner.TokenType.TOKEN_IF, token_type);
}

// Test state transitions: Normal -> MultiLine -> Normal
test "fsm whitespace: state transition normal to multi-line" {
    const source = "/##/if";
    const token_type = scanAfterWhitespace(source);
    try testing.expectEqual(scanner.TokenType.TOKEN_IF, token_type);
}

// Test edge case: comment markers in strings are not handled here
// (strings are handled by separate scanner logic)
test "fsm whitespace: multiple tokens with comments between" {
    const source =
        \\if // comment
        \\for /# multi #/
        \\while
    ;
    var buf: [1024]u8 = undefined;
    @memcpy(buf[0..source.len], source);
    buf[source.len] = 0;
    scanner.init_scanner(&buf);

    try testing.expectEqual(scanner.TokenType.TOKEN_IF, scanner.scanToken().type);
    try testing.expectEqual(scanner.TokenType.TOKEN_FOR, scanner.scanToken().type);
    try testing.expectEqual(scanner.TokenType.TOKEN_WHILE, scanner.scanToken().type);
}

// Test that FSM correctly handles EOF in each state
test "fsm whitespace: EOF in normal state" {
    const source = "   ";
    const token_type = scanAfterWhitespace(source);
    try testing.expectEqual(scanner.TokenType.TOKEN_EOF, token_type);
}

test "fsm whitespace: EOF in single-line comment" {
    const source = "// comment no newline";
    const token_type = scanAfterWhitespace(source);
    try testing.expectEqual(scanner.TokenType.TOKEN_EOF, token_type);
}

// Test complex real-world-like scenario
test "fsm whitespace: complex real-world scenario" {
    const source =
        \\// Header comment
        \\/# Multi-line header
        \\   with description #/
        \\
        \\fun main() {
    ;
    var buf: [1024]u8 = undefined;
    @memcpy(buf[0..source.len], source);
    buf[source.len] = 0;
    scanner.init_scanner(&buf);

    const token = scanner.scanToken();
    try testing.expectEqual(scanner.TokenType.TOKEN_FUN, token.type);
}
