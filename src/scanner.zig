const std = @import("std");

fn memcmp(s1: ?*const anyopaque, s2: ?*const anyopaque, n: usize) c_int {
    const str1: [*c]const u8 = @ptrCast(s1.?);
    const str2: [*c]const u8 = @ptrCast(s2.?);
    const num: usize = @intCast(n);

    for (0..num) |i| {
        if (str1[i] != str2[i]) return @intCast(str1[i] - str2[i]);
    }

    return 0;
}

fn strlen(s: [*c]const u8) usize {
    var str: *[]u8 = @constCast(@ptrCast(@alignCast(s)));
    return str.*.len;
}

pub const TokenType = enum(c_int) {
    // Single character tokens
    TOKEN_LEFT_PAREN = 0,
    TOKEN_RIGHT_PAREN = 1,
    TOKEN_LEFT_BRACE = 2,
    TOKEN_RIGHT_BRACE = 3,
    TOKEN_COMMA = 4,
    TOKEN_DOT = 5,
    TOKEN_MINUS = 6,
    TOKEN_PLUS = 7,
    TOKEN_SEMICOLON = 8,
    TOKEN_SLASH = 9,
    TOKEN_STAR = 10,
    TOKEN_PERCENT = 11,
    // One or more character tokens
    TOKEN_BANG = 12,
    TOKEN_BANG_EQUAL = 13,
    TOKEN_EQUAL = 14,
    TOKEN_EQUAL_EQUAL = 15,
    TOKEN_GREATER = 16,
    TOKEN_GREATER_EQUAL = 17,
    TOKEN_LESS = 18,
    TOKEN_LESS_EQUAL = 19,
    // Literals
    TOKEN_IDENTIFIER = 20,
    TOKEN_STRING = 21,
    TOKEN_DOUBLE = 22,
    TOKEN_INT = 23,
    // Keywords
    TOKEN_AND = 24,
    TOKEN_CLASS = 25,
    TOKEN_ELSE = 26,
    TOKEN_FALSE = 27,
    TOKEN_FOR = 28,
    TOKEN_FUN = 29,
    TOKEN_IF = 30,
    TOKEN_LET = 31,
    TOKEN_NIL = 32,
    TOKEN_OR = 33,
    TOKEN_PRINT = 34,
    TOKEN_RETURN = 35,
    TOKEN_SELF = 36,
    TOKEN_SUPER = 37,
    TOKEN_TRUE = 38,
    TOKEN_VAR = 39,
    TOKEN_WHILE = 40,
    // Misc
    TOKEN_ERROR = 41,
    TOKEN_EOF = 42,
    TOKEN_PLUS_EQUAL = 43,
    TOKEN_MINUS_EQUAL = 44,
    TOKEN_STAR_EQUAL = 45,
    TOKEN_SLASH_EQUAL = 46,
    TOKEN_PLUS_PLUS = 47,
    TOKEN_MINUS_MINUS = 48,
    TOKEN_HAT = 49,
};

pub const Token = extern struct {
    type: TokenType,
    start: [*c]u8,
    length: i32,
    line: i32,
};

pub const Scanner = extern struct {
    start: [*c]u8,
    current: [*c]u8,
    line: i32,
};

var scanner: Scanner = undefined;

pub export fn initScanner(source: [*c]u8) callconv(.C) void {
    scanner.start = source;
    scanner.current = source;
    scanner.line = 1;
}

pub export fn isAlpha(c: u8) callconv(.C) bool {
    return (c >= 'a' and c <= 'z') or
        (c >= 'A' and c <= 'Z') or
        c == '_';
}

pub export fn isDigit(c: u8) callconv(.C) bool {
    return c >= '0' and c <= '9';
}

pub export fn isAtEnd() callconv(.C) bool {
    return scanner.current.* == '\x00';
}

pub export fn __scanner__advance() callconv(.C) u8 {
    const char = scanner.current[0];
    scanner.current += 1;
    return char;
}

pub export fn peek() callconv(.C) u8 {
    return scanner.current.*;
}

pub export fn peekNext() callconv(.C) u8 {
    if (isAtEnd()) return 0;
    return scanner.current[1];
}
/// TODO: need to simply without converting so much
pub export fn makeToken(type_: TokenType) callconv(.C) Token {
    return .{
        .type = type_,
        .start = scanner.start,
        .length = @intCast(@intFromPtr(scanner.current) - @intFromPtr(scanner.start)),
        .line = scanner.line,
    };
}
/// TODO: need to simply without converting so much
pub export fn errorToken(message: [*c]u8) callconv(.C) Token {
    return .{
        .type = TokenType.TOKEN_ERROR,
        .start = message,
        .length = @intCast(strlen(message)),
        .line = scanner.line,
    };
}

pub export fn skipWhitespace() callconv(.C) void {
    while (true) {
        const c = peek();
        switch (c) {
            ' ', '\r', '\t' => _ = __scanner__advance(),
            '\n' => {
                scanner.line += 1;
                _ = __scanner__advance();
            },
            '/' => {
                if (peekNext() == '/') {
                    while (peek() != '\n' and !isAtEnd()) _ = __scanner__advance();
                } else {
                    return;
                }
            },
            else => return,
        }
    }
}
/// TODO: need to simply without converting so much
pub export fn checkKeyword(arg_start: c_int, arg_length: c_int, arg_rest: [*c]const u8, arg_type: TokenType) callconv(.C) TokenType {
    var start = arg_start;
    var length = arg_length;
    var rest = arg_rest;
    var @"type" = arg_type;
    if (@intFromPtr(scanner.current) - @intFromPtr(scanner.start) == start + length and memcmp(@ptrCast(@as([*c]u8, @ptrFromInt(@intFromPtr(scanner.start) + @as(usize, @intCast(start))))), @ptrCast(rest), @intCast(length)) == 0) {
        return @"type";
    }
    return .TOKEN_IDENTIFIER;
}
/// TODO: need to simply without converting so much
pub export fn __scanner__match(arg_expected: u8) callconv(.C) bool {
    var expected = arg_expected;
    if (isAtEnd()) return @as(c_int, 0) != 0;
    if (@as(c_int, @bitCast(@as(c_uint, scanner.current.*))) != @as(c_int, @bitCast(@as(c_uint, expected)))) return @as(c_int, 0) != 0;
    scanner.current += 1;
    return @as(c_int, 1) != 0;
}

pub export fn identifierType() callconv(.C) TokenType {
    switch (scanner.start[0]) {
        'a' => return checkKeyword(1, 2, @ptrCast("nd"), .TOKEN_AND),
        'c' => return checkKeyword(1, 4, @ptrCast("lass"), .TOKEN_CLASS),
        'e' => return checkKeyword(1, 3, @ptrCast("lse"), .TOKEN_ELSE),
        'f' => {
            if (@intFromPtr(scanner.current) - @intFromPtr(scanner.start) > 1) {
                switch (scanner.start[1]) {
                    'a' => return checkKeyword(2, 3, @ptrCast("lse"), .TOKEN_FALSE),
                    'o' => return checkKeyword(2, 1, @ptrCast("r"), .TOKEN_FOR),
                    'u' => return checkKeyword(2, 1, @ptrCast("n"), .TOKEN_FUN),
                    else => {},
                }
            }
        },
        'i' => return checkKeyword(1, 1, @ptrCast("f"), .TOKEN_IF),
        'l' => return checkKeyword(1, 2, @ptrCast("et"), .TOKEN_LET),
        'n' => return checkKeyword(1, 2, @ptrCast("il"), .TOKEN_NIL),
        'p' => return checkKeyword(1, 4, @ptrCast("rint"), .TOKEN_PRINT),
        'r' => return checkKeyword(1, 5, @ptrCast("eturn"), .TOKEN_RETURN),
        's' => {
            if (@intFromPtr(scanner.current) - @intFromPtr(scanner.start) > 1) {
                switch (scanner.start[1]) {
                    'e' => return checkKeyword(2, 2, @ptrCast("lf"), .TOKEN_SELF),
                    'u' => return checkKeyword(2, 3, @ptrCast("per"), .TOKEN_SUPER),
                    else => {},
                }
            }
        },
        't' => return checkKeyword(1, 3, @ptrCast("rue"), .TOKEN_TRUE),
        'v' => return checkKeyword(1, 2, @ptrCast("ar"), .TOKEN_VAR),
        'w' => return checkKeyword(1, 4, @ptrCast("hile"), .TOKEN_WHILE),
        else => {},
    }
    return .TOKEN_IDENTIFIER;
}
pub export fn identifier() callconv(.C) Token {
    while (isAlpha(peek()) or isDigit(peek())) {
        _ = __scanner__advance();
    }
    return makeToken(identifierType());
}

pub export fn __scanner__number() callconv(.C) Token {
    while (isDigit(peek())) {
        _ = __scanner__advance();
    }
    if (peek() == '.' and isDigit(peekNext())) {
        _ = __scanner__advance();
        while (isDigit(peek())) _ = __scanner__advance();

        return makeToken(.TOKEN_DOUBLE);
    } else {
        return makeToken(.TOKEN_INT);
    }
}

pub export fn __scanner__string() callconv(.C) Token {
    while (peek() != '"' and !isAtEnd()) {
        if (peek() == '\n') {
            scanner.line += 1;
        }
        _ = __scanner__advance();
    }
    if (isAtEnd()) return errorToken(@ptrCast(@constCast("Unterminated string.")));
    _ = __scanner__advance();
    return makeToken(.TOKEN_STRING);
}

pub export fn scanToken() Token {
    skipWhitespace();
    scanner.start = scanner.current;
    if (isAtEnd()) return makeToken(.TOKEN_EOF);
    const c = __scanner__advance();

    if (isAlpha(c)) return identifier();
    if (isDigit(c)) return __scanner__number();

    switch (c) {
        '(' => return makeToken(.TOKEN_LEFT_PAREN),
        ')' => return makeToken(.TOKEN_RIGHT_PAREN),
        '{' => return makeToken(.TOKEN_LEFT_BRACE),
        '}' => return makeToken(.TOKEN_RIGHT_BRACE),
        ';' => return makeToken(.TOKEN_SEMICOLON),
        ',' => return makeToken(.TOKEN_COMMA),
        '.' => return makeToken(.TOKEN_DOT),
        '-' => {
            if (__scanner__match('=')) {
                return makeToken(.TOKEN_MINUS_EQUAL);
            } else if (__scanner__match('-')) {
                return makeToken(.TOKEN_MINUS_MINUS);
            } else {
                return makeToken(.TOKEN_MINUS);
            }
        },
        '+' => {
            if (__scanner__match('=')) {
                return makeToken(.TOKEN_PLUS_EQUAL);
            } else if (__scanner__match('+')) {
                return makeToken(.TOKEN_PLUS_PLUS);
            } else {
                return makeToken(.TOKEN_PLUS);
            }
        },
        '/' => {
            if (__scanner__match('=')) return makeToken(.TOKEN_SLASH_EQUAL) else return makeToken(.TOKEN_SLASH);
        },
        '*' => {
            if (__scanner__match('=')) return makeToken(.TOKEN_STAR_EQUAL) else return makeToken(.TOKEN_STAR);
        },
        '!' => {
            if (__scanner__match('=')) return makeToken(.TOKEN_BANG_EQUAL) else return makeToken(.TOKEN_BANG);
        },
        '=' => {
            if (__scanner__match('=')) return makeToken(.TOKEN_EQUAL_EQUAL) else return makeToken(.TOKEN_EQUAL);
        },
        '<' => {
            if (__scanner__match('=')) return makeToken(.TOKEN_LESS_EQUAL) else return makeToken(.TOKEN_LESS);
        },
        '>' => {
            if (__scanner__match('=')) return makeToken(.TOKEN_GREATER_EQUAL) else return makeToken(.TOKEN_GREATER);
        },
        '%' => return makeToken(.TOKEN_PERCENT),
        '^' => return makeToken(.TOKEN_HAT),
        '"' => return __scanner__string(),
        else => {},
    }
    return errorToken(@ptrCast(@constCast("Unexpected Character.")));
}
