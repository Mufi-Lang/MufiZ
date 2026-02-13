const std = @import("std");
const testing = std.testing;
const scanner = @import("scanner_optimized.zig");

// Test all keywords are correctly recognized
test "perfect hash: all keywords recognized" {
    const keywords = [_]struct { str: []const u8, expected: scanner.TokenType }{
        .{ .str = "and", .expected = .TOKEN_AND },
        .{ .str = "as", .expected = .TOKEN_AS },
        .{ .str = "break", .expected = .TOKEN_BREAK },
        .{ .str = "case", .expected = .TOKEN_CASE },
        .{ .str = "class", .expected = .TOKEN_CLASS },
        .{ .str = "const", .expected = .TOKEN_CONST },
        .{ .str = "continue", .expected = .TOKEN_CONTINUE },
        .{ .str = "each", .expected = .TOKEN_EACH },
        .{ .str = "else", .expected = .TOKEN_ELSE },
        .{ .str = "end", .expected = .TOKEN_END },
        .{ .str = "false", .expected = .TOKEN_FALSE },
        .{ .str = "for", .expected = .TOKEN_FOR },
        .{ .str = "foreach", .expected = .TOKEN_FOREACH },
        .{ .str = "from", .expected = .TOKEN_FROM },
        .{ .str = "fun", .expected = .TOKEN_FUN },
        .{ .str = "if", .expected = .TOKEN_IF },
        .{ .str = "import", .expected = .TOKEN_IMPORT },
        .{ .str = "in", .expected = .TOKEN_IN },
        .{ .str = "item", .expected = .TOKEN_ITEM },
        .{ .str = "let", .expected = .TOKEN_LET },
        .{ .str = "nil", .expected = .TOKEN_NIL },
        .{ .str = "or", .expected = .TOKEN_OR },
        .{ .str = "print", .expected = .TOKEN_PRINT },
        .{ .str = "return", .expected = .TOKEN_RETURN },
        .{ .str = "self", .expected = .TOKEN_SELF },
        .{ .str = "super", .expected = .TOKEN_SUPER },
        .{ .str = "switch", .expected = .TOKEN_SWITCH },
        .{ .str = "true", .expected = .TOKEN_TRUE },
        .{ .str = "var", .expected = .TOKEN_VAR },
        .{ .str = "while", .expected = .TOKEN_WHILE },
    };

    // Initialize scanner for each keyword
    for (keywords) |kw| {
        // Create null-terminated string for scanner
        var buf: [256]u8 = undefined;
        @memcpy(buf[0..kw.str.len], kw.str);
        buf[kw.str.len] = 0;
        scanner.init_scanner(&buf);
        const token = scanner.scanToken();
        try testing.expectEqual(kw.expected, token.type);
    }
}

// Test that non-keywords are recognized as identifiers
test "perfect hash: non-keywords are identifiers" {
    const identifiers = [_][]const u8{
        "variable",
        "function",
        "my_var",
        "className",
        "ands", // Similar to keyword but not exact match
        "forloop",
        "endif",
        "returnable",
        "x",
        "i",
        "counter",
        "value123",
        "a1b2c3",
    };

    for (identifiers) |id| {
        var buf: [256]u8 = undefined;
        @memcpy(buf[0..id.len], id);
        buf[id.len] = 0;
        scanner.init_scanner(&buf);
        const token = scanner.scanToken();
        try testing.expectEqual(scanner.TokenType.TOKEN_IDENTIFIER, token.type);
    }
}

// Test case sensitivity - keywords are case-sensitive
test "perfect hash: case sensitivity" {
    const non_keywords = [_][]const u8{
        "AND",
        "And",
        "IF",
        "If",
        "FOR",
        "For",
        "CLASS",
        "Class",
        "TRUE",
        "True",
        "FALSE",
        "False",
    };

    for (non_keywords) |id| {
        var buf: [256]u8 = undefined;
        @memcpy(buf[0..id.len], id);
        buf[id.len] = 0;
        scanner.init_scanner(&buf);
        const token = scanner.scanToken();
        try testing.expectEqual(scanner.TokenType.TOKEN_IDENTIFIER, token.type);
    }
}

// Test keywords with surrounding whitespace
test "perfect hash: keywords with whitespace" {
    const test_cases = [_]struct { src: []const u8, expected: scanner.TokenType }{
        .{ .src = "  if  ", .expected = .TOKEN_IF },
        .{ .src = "\tfor\t", .expected = .TOKEN_FOR },
        .{ .src = "\nwhile\n", .expected = .TOKEN_WHILE },
        .{ .src = "  fun  ", .expected = .TOKEN_FUN },
    };

    for (test_cases) |tc| {
        var buf: [256]u8 = undefined;
        @memcpy(buf[0..tc.src.len], tc.src);
        buf[tc.src.len] = 0;
        scanner.init_scanner(&buf);
        const token = scanner.scanToken();
        try testing.expectEqual(tc.expected, token.type);
    }
}

// Test multiple keywords in sequence
test "perfect hash: multiple keywords" {
    const source = "if for while class fun";
    const expected = [_]scanner.TokenType{
        .TOKEN_IF,
        .TOKEN_FOR,
        .TOKEN_WHILE,
        .TOKEN_CLASS,
        .TOKEN_FUN,
        .TOKEN_EOF,
    };

    var buf: [256]u8 = undefined;
    @memcpy(buf[0..source.len], source);
    buf[source.len] = 0;
    scanner.init_scanner(&buf);

    for (expected) |expected_type| {
        const token = scanner.scanToken();
        try testing.expectEqual(expected_type, token.type);
    }
}

// Test that hash distribution is good (no performance test, just validation)
test "perfect hash: coverage validation" {
    // This test ensures all 30 keywords can coexist without collision
    // The compile-time verification in scanner_optimized.zig already checks this,
    // but this runtime test provides additional validation

    const keywords = [_][]const u8{
        "and",  "as",    "break",  "case",  "class", "const",   "continue",
        "each", "else",  "end",    "false", "for",   "foreach", "from",
        "fun",  "if",    "import", "in",    "item",  "let",     "nil",
        "or",   "print", "return", "self",  "super", "switch",  "true",
        "var",  "while",
    };

    // Track which keywords we've successfully scanned
    var count: usize = 0;
    for (keywords) |kw| {
        var buf: [256]u8 = undefined;
        @memcpy(buf[0..kw.len], kw);
        buf[kw.len] = 0;
        scanner.init_scanner(&buf);
        const token = scanner.scanToken();

        // Must not be EOF or ERROR or IDENTIFIER
        try testing.expect(token.type != .TOKEN_EOF);
        try testing.expect(token.type != .TOKEN_ERROR);
        try testing.expect(token.type != .TOKEN_IDENTIFIER);

        count += 1;
    }

    // Verify we tested all 30 keywords
    try testing.expectEqual(@as(usize, 30), count);
}

// Edge case: empty input
test "perfect hash: empty input" {
    var buf: [1]u8 = .{0};
    scanner.init_scanner(&buf);
    const token = scanner.scanToken();
    try testing.expectEqual(scanner.TokenType.TOKEN_EOF, token.type);
}

// Edge case: single character (not a keyword)
test "perfect hash: single character identifiers" {
    const chars = "abcdefghijklmnopqrstuvwxyz";
    for (chars) |c| {
        var buf = [_]u8{ c, 0 };
        scanner.init_scanner(&buf);
        const token = scanner.scanToken();
        try testing.expectEqual(scanner.TokenType.TOKEN_IDENTIFIER, token.type);
    }
}

// Test that keywords work at beginning, middle, and end of source
test "perfect hash: keywords in various positions" {
    const source = "if middle while";
    var buf: [256]u8 = undefined;
    @memcpy(buf[0..source.len], source);
    buf[source.len] = 0;
    scanner.init_scanner(&buf);

    const token1 = scanner.scanToken();
    try testing.expectEqual(scanner.TokenType.TOKEN_IF, token1.type);

    const token2 = scanner.scanToken();
    try testing.expectEqual(scanner.TokenType.TOKEN_IDENTIFIER, token2.type);

    const token3 = scanner.scanToken();
    try testing.expectEqual(scanner.TokenType.TOKEN_WHILE, token3.type);
}
