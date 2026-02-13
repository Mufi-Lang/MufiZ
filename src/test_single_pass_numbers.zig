const std = @import("std");
const testing = std.testing;
const scanner = @import("scanner_optimized.zig");

// Helper function to scan a number and return its token type
fn scanNumber(source: []const u8) scanner.TokenType {
    var buf: [1024]u8 = undefined;
    @memcpy(buf[0..source.len], source);
    buf[source.len] = 0;
    scanner.init_scanner(&buf);
    const token = scanner.scanToken();
    return token.type;
}

// Test integer parsing
test "single-pass numbers: basic integer" {
    try testing.expectEqual(scanner.TokenType.TOKEN_INT, scanNumber("42"));
    try testing.expectEqual(scanner.TokenType.TOKEN_INT, scanNumber("0"));
    try testing.expectEqual(scanner.TokenType.TOKEN_INT, scanNumber("123456789"));
    try testing.expectEqual(scanner.TokenType.TOKEN_INT, scanNumber("1"));
}

// Test float parsing
test "single-pass numbers: basic float" {
    try testing.expectEqual(scanner.TokenType.TOKEN_DOUBLE, scanNumber("3.14"));
    try testing.expectEqual(scanner.TokenType.TOKEN_DOUBLE, scanNumber("0.5"));
    try testing.expectEqual(scanner.TokenType.TOKEN_DOUBLE, scanNumber("123.456"));
    try testing.expectEqual(scanner.TokenType.TOKEN_DOUBLE, scanNumber("1.0"));
}

// Test imaginary numbers (integer with i)
test "single-pass numbers: integer imaginary" {
    try testing.expectEqual(scanner.TokenType.TOKEN_IMAGINARY, scanNumber("3i"));
    try testing.expectEqual(scanner.TokenType.TOKEN_IMAGINARY, scanNumber("0i"));
    try testing.expectEqual(scanner.TokenType.TOKEN_IMAGINARY, scanNumber("42i"));
    try testing.expectEqual(scanner.TokenType.TOKEN_IMAGINARY, scanNumber("1i"));
}

// Test imaginary numbers (float with i)
test "single-pass numbers: float imaginary" {
    try testing.expectEqual(scanner.TokenType.TOKEN_IMAGINARY, scanNumber("3.14i"));
    try testing.expectEqual(scanner.TokenType.TOKEN_IMAGINARY, scanNumber("0.5i"));
    try testing.expectEqual(scanner.TokenType.TOKEN_IMAGINARY, scanNumber("1.0i"));
}

// Test complex numbers (real + imaginary)
test "single-pass numbers: complex with plus" {
    try testing.expectEqual(scanner.TokenType.TOKEN_IMAGINARY, scanNumber("3+4i"));
    try testing.expectEqual(scanner.TokenType.TOKEN_IMAGINARY, scanNumber("1+2i"));
    try testing.expectEqual(scanner.TokenType.TOKEN_IMAGINARY, scanNumber("10+5i"));
    try testing.expectEqual(scanner.TokenType.TOKEN_IMAGINARY, scanNumber("0+1i"));
}

// Test complex numbers (real - imaginary)
test "single-pass numbers: complex with minus" {
    try testing.expectEqual(scanner.TokenType.TOKEN_IMAGINARY, scanNumber("3-4i"));
    try testing.expectEqual(scanner.TokenType.TOKEN_IMAGINARY, scanNumber("1-2i"));
    try testing.expectEqual(scanner.TokenType.TOKEN_IMAGINARY, scanNumber("10-5i"));
    try testing.expectEqual(scanner.TokenType.TOKEN_IMAGINARY, scanNumber("5-0i"));
}

// Test complex numbers with floats
test "single-pass numbers: complex with float real" {
    try testing.expectEqual(scanner.TokenType.TOKEN_IMAGINARY, scanNumber("3.5+4i"));
    try testing.expectEqual(scanner.TokenType.TOKEN_IMAGINARY, scanNumber("1.0+2i"));
    try testing.expectEqual(scanner.TokenType.TOKEN_IMAGINARY, scanNumber("0.5-1i"));
}

// Test complex numbers with float imaginary
test "single-pass numbers: complex with float imaginary" {
    try testing.expectEqual(scanner.TokenType.TOKEN_IMAGINARY, scanNumber("3+4.5i"));
    try testing.expectEqual(scanner.TokenType.TOKEN_IMAGINARY, scanNumber("1+2.0i"));
    try testing.expectEqual(scanner.TokenType.TOKEN_IMAGINARY, scanNumber("5-3.14i"));
}

// Test complex numbers with both floats
test "single-pass numbers: complex with both floats" {
    try testing.expectEqual(scanner.TokenType.TOKEN_IMAGINARY, scanNumber("3.14+2.71i"));
    try testing.expectEqual(scanner.TokenType.TOKEN_IMAGINARY, scanNumber("1.5+0.5i"));
    try testing.expectEqual(scanner.TokenType.TOKEN_IMAGINARY, scanNumber("0.1-0.2i"));
}

// Test that + or - alone doesn't make it complex
test "single-pass numbers: number followed by operator" {
    var buf: [1024]u8 = undefined;
    const source = "10 + 20";
    @memcpy(buf[0..source.len], source);
    buf[source.len] = 0;
    scanner.init_scanner(&buf);

    const token1 = scanner.scanToken();
    try testing.expectEqual(scanner.TokenType.TOKEN_INT, token1.type);

    const token2 = scanner.scanToken();
    try testing.expectEqual(scanner.TokenType.TOKEN_PLUS, token2.type);

    const token3 = scanner.scanToken();
    try testing.expectEqual(scanner.TokenType.TOKEN_INT, token3.type);
}

// Test expression with subtraction
test "single-pass numbers: subtraction expression" {
    var buf: [1024]u8 = undefined;
    const source = "10 - 5";
    @memcpy(buf[0..source.len], source);
    buf[source.len] = 0;
    scanner.init_scanner(&buf);

    const token1 = scanner.scanToken();
    try testing.expectEqual(scanner.TokenType.TOKEN_INT, token1.type);

    const token2 = scanner.scanToken();
    try testing.expectEqual(scanner.TokenType.TOKEN_MINUS, token2.type);

    const token3 = scanner.scanToken();
    try testing.expectEqual(scanner.TokenType.TOKEN_INT, token3.type);
}

// Test number without 'i' after +/- is not complex
test "single-pass numbers: plus without i is not complex" {
    var buf: [1024]u8 = undefined;
    const source = "10+20";
    @memcpy(buf[0..source.len], source);
    buf[source.len] = 0;
    scanner.init_scanner(&buf);

    const token1 = scanner.scanToken();
    try testing.expectEqual(scanner.TokenType.TOKEN_INT, token1.type);

    const token2 = scanner.scanToken();
    try testing.expectEqual(scanner.TokenType.TOKEN_PLUS, token2.type);
}

// Test multiple numbers in sequence
test "single-pass numbers: multiple integers" {
    var buf: [1024]u8 = undefined;
    const source = "1 2 3 4 5";
    @memcpy(buf[0..source.len], source);
    buf[source.len] = 0;
    scanner.init_scanner(&buf);

    try testing.expectEqual(scanner.TokenType.TOKEN_INT, scanner.scanToken().type);
    try testing.expectEqual(scanner.TokenType.TOKEN_INT, scanner.scanToken().type);
    try testing.expectEqual(scanner.TokenType.TOKEN_INT, scanner.scanToken().type);
    try testing.expectEqual(scanner.TokenType.TOKEN_INT, scanner.scanToken().type);
    try testing.expectEqual(scanner.TokenType.TOKEN_INT, scanner.scanToken().type);
}

// Test mixed number types
test "single-pass numbers: mixed types" {
    var buf: [1024]u8 = undefined;
    const source = "42 3.14 2i 1+1i";
    @memcpy(buf[0..source.len], source);
    buf[source.len] = 0;
    scanner.init_scanner(&buf);

    try testing.expectEqual(scanner.TokenType.TOKEN_INT, scanner.scanToken().type);
    try testing.expectEqual(scanner.TokenType.TOKEN_DOUBLE, scanner.scanToken().type);
    try testing.expectEqual(scanner.TokenType.TOKEN_IMAGINARY, scanner.scanToken().type);
    try testing.expectEqual(scanner.TokenType.TOKEN_IMAGINARY, scanner.scanToken().type);
}

// Test edge case: zero values
test "single-pass numbers: zero values" {
    try testing.expectEqual(scanner.TokenType.TOKEN_INT, scanNumber("0"));
    try testing.expectEqual(scanner.TokenType.TOKEN_DOUBLE, scanNumber("0.0"));
    try testing.expectEqual(scanner.TokenType.TOKEN_IMAGINARY, scanNumber("0i"));
    try testing.expectEqual(scanner.TokenType.TOKEN_IMAGINARY, scanNumber("0+0i"));
}

// Test edge case: large numbers
test "single-pass numbers: large integers" {
    try testing.expectEqual(scanner.TokenType.TOKEN_INT, scanNumber("999999999"));
    try testing.expectEqual(scanner.TokenType.TOKEN_DOUBLE, scanNumber("123456.789012"));
}

// Test that numbers followed by identifiers are parsed correctly
test "single-pass numbers: number followed by identifier" {
    var buf: [1024]u8 = undefined;
    const source = "42x";
    @memcpy(buf[0..source.len], source);
    buf[source.len] = 0;
    scanner.init_scanner(&buf);

    const token1 = scanner.scanToken();
    try testing.expectEqual(scanner.TokenType.TOKEN_INT, token1.type);

    const token2 = scanner.scanToken();
    try testing.expectEqual(scanner.TokenType.TOKEN_IDENTIFIER, token2.type);
}

// Test complex with no space
test "single-pass numbers: complex no spaces" {
    try testing.expectEqual(scanner.TokenType.TOKEN_IMAGINARY, scanNumber("3+4i"));
    try testing.expectEqual(scanner.TokenType.TOKEN_IMAGINARY, scanNumber("10-5i"));
}

// Test that decimal must be followed by digit
test "single-pass numbers: decimal requires following digit" {
    var buf: [1024]u8 = undefined;
    const source = "3.";
    @memcpy(buf[0..source.len], source);
    buf[source.len] = 0;
    scanner.init_scanner(&buf);

    const token1 = scanner.scanToken();
    try testing.expectEqual(scanner.TokenType.TOKEN_INT, token1.type);

    const token2 = scanner.scanToken();
    try testing.expectEqual(scanner.TokenType.TOKEN_DOT, token2.type);
}

// Test single-pass efficiency: no backtracking
test "single-pass numbers: complex expression parsing" {
    var buf: [1024]u8 = undefined;
    const source = "3+4i * 2-1i";
    @memcpy(buf[0..source.len], source);
    buf[source.len] = 0;
    scanner.init_scanner(&buf);

    try testing.expectEqual(scanner.TokenType.TOKEN_IMAGINARY, scanner.scanToken().type);
    try testing.expectEqual(scanner.TokenType.TOKEN_STAR, scanner.scanToken().type);
    try testing.expectEqual(scanner.TokenType.TOKEN_IMAGINARY, scanner.scanToken().type);
}

// Test that plus/minus in middle doesn't confuse parser
test "single-pass numbers: arithmetic operations" {
    var buf: [1024]u8 = undefined;
    const source = "10+5-3";
    @memcpy(buf[0..source.len], source);
    buf[source.len] = 0;
    scanner.init_scanner(&buf);

    try testing.expectEqual(scanner.TokenType.TOKEN_INT, scanner.scanToken().type);
    try testing.expectEqual(scanner.TokenType.TOKEN_PLUS, scanner.scanToken().type);
    try testing.expectEqual(scanner.TokenType.TOKEN_INT, scanner.scanToken().type);
    try testing.expectEqual(scanner.TokenType.TOKEN_MINUS, scanner.scanToken().type);
}

// Test float precision
test "single-pass numbers: float precision" {
    try testing.expectEqual(scanner.TokenType.TOKEN_DOUBLE, scanNumber("3.141592653589793"));
    try testing.expectEqual(scanner.TokenType.TOKEN_DOUBLE, scanNumber("2.718281828"));
    try testing.expectEqual(scanner.TokenType.TOKEN_DOUBLE, scanNumber("1.41421356"));
}

// Test imaginary with long numbers
test "single-pass numbers: long imaginary" {
    try testing.expectEqual(scanner.TokenType.TOKEN_IMAGINARY, scanNumber("123456789i"));
    try testing.expectEqual(scanner.TokenType.TOKEN_IMAGINARY, scanNumber("999.999i"));
}

// Test complex with long numbers
test "single-pass numbers: long complex" {
    try testing.expectEqual(scanner.TokenType.TOKEN_IMAGINARY, scanNumber("12345+67890i"));
    try testing.expectEqual(scanner.TokenType.TOKEN_IMAGINARY, scanNumber("999.99+888.88i"));
}

// Test that single 'i' is identifier not number
test "single-pass numbers: lone i is identifier" {
    try testing.expectEqual(scanner.TokenType.TOKEN_IDENTIFIER, scanNumber("i"));
}

// Test numbers in realistic code context
test "single-pass numbers: realistic code" {
    var buf: [1024]u8 = undefined;
    const source = "var x = 3+4i;";
    @memcpy(buf[0..source.len], source);
    buf[source.len] = 0;
    scanner.init_scanner(&buf);

    try testing.expectEqual(scanner.TokenType.TOKEN_VAR, scanner.scanToken().type);
    try testing.expectEqual(scanner.TokenType.TOKEN_IDENTIFIER, scanner.scanToken().type);
    try testing.expectEqual(scanner.TokenType.TOKEN_EQUAL, scanner.scanToken().type);
    try testing.expectEqual(scanner.TokenType.TOKEN_IMAGINARY, scanner.scanToken().type);
    try testing.expectEqual(scanner.TokenType.TOKEN_SEMICOLON, scanner.scanToken().type);
}

// Test various decimal patterns
test "single-pass numbers: decimal patterns" {
    try testing.expectEqual(scanner.TokenType.TOKEN_DOUBLE, scanNumber("0.1"));
    try testing.expectEqual(scanner.TokenType.TOKEN_DOUBLE, scanNumber("10.0"));
    try testing.expectEqual(scanner.TokenType.TOKEN_DOUBLE, scanNumber("123.456789"));
}

// Test performance scenario: many numbers
test "single-pass numbers: many sequential numbers" {
    var buf: [2048]u8 = undefined;
    const source = "1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20";
    @memcpy(buf[0..source.len], source);
    buf[source.len] = 0;
    scanner.init_scanner(&buf);

    var count: usize = 0;
    while (count < 20) : (count += 1) {
        const token = scanner.scanToken();
        try testing.expectEqual(scanner.TokenType.TOKEN_INT, token.type);
    }
}
