const std = @import("std");
const string_h = @cImport(@cInclude("string.h"));
const memcmp = string_h.memcmp; // need to find replacement
const strlen = string_h.strlen; // need to find replacement

// inline fn strlen(s: [*c]u8) usize{
//     var i: usize = 0;
//     while(s[i] != 0): (i += 1){}
//     return i;
// }

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
    // One or more character tokens
    TOKEN_BANG = 11,
    TOKEN_BANG_EQUAL = 12,
    TOKEN_EQUAL = 13,
    TOKEN_EQUAL_EQUAL = 14,
    TOKEN_GREATER = 15,
    TOKEN_GREATER_EQUAL = 16,
    TOKEN_LESS = 17,
    TOKEN_LESS_EQUAL = 18,
    // Literals
    TOKEN_IDENTIFIER = 19,
    TOKEN_STRING = 20,
    TOKEN_DOUBLE = 21,
    TOKEN_INT = 22,
    // Keywords
    TOKEN_AND = 23,
    TOKEN_CLASS = 24,
    TOKEN_ELSE = 25,
    TOKEN_FALSE = 26,
    TOKEN_FOR = 27,
    TOKEN_FUN = 28,
    TOKEN_IF = 29,
    TOKEN_LET = 30,
    TOKEN_NIL = 31,
    TOKEN_OR = 32,
    TOKEN_PRINT = 33,
    TOKEN_RETURN = 34,
    TOKEN_SELF = 35,
    TOKEN_SUPER = 36,
    TOKEN_TRUE = 37,
    TOKEN_VAR = 38,
    TOKEN_WHILE = 39,
    //Misc
    TOKEN_ERROR = 40,
    TOKEN_EOF = 41,
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
        .length = @as(i32, @bitCast(@as(c_int, @truncate(@divExact(@as(c_longlong, @bitCast(@intFromPtr(scanner.current) -% @intFromPtr(scanner.start))), @sizeOf(u8)))))),
        .line = scanner.line,
    };
}
/// TODO: need to simply without converting so much
pub export fn errorToken(message: [*c]u8) callconv(.C) Token {
    return .{
        .type = TokenType.TOKEN_ERROR,
        .start = message,
        .length = @as(i32, @bitCast(@as(c_uint, @truncate(strlen(message))))),
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
    if ((@divExact(@as(c_longlong, @bitCast(@intFromPtr(scanner.current) -% @intFromPtr(scanner.start))), @sizeOf(u8)) == @as(c_longlong, @bitCast(@as(c_longlong, start + length)))) and (memcmp(@as(?*const anyopaque, @ptrCast(scanner.start + @as(usize, @bitCast(@as(isize, @intCast(start)))))), @as(?*const anyopaque, @ptrCast(rest)), @as(c_ulonglong, @bitCast(@as(c_longlong, length)))) == @as(c_int, 0))) {
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
    while ((@as(c_int, @intFromBool(isAlpha(peek()))) != 0) or (@as(c_int, @intFromBool(isDigit(peek()))) != 0)) {
        _ = __scanner__advance();
    }
    return makeToken(identifierType());
}
/// TODO: need to simply without converting so much
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
/// TODO: need to simply without converting so much
pub export fn __scanner__string() callconv(.C) Token {
    while ((@as(c_int, @bitCast(@as(c_uint, peek()))) != @as(c_int, '"')) and !isAtEnd()) {
        if (@as(c_int, @bitCast(@as(c_uint, peek()))) == @as(c_int, '\n')) {
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
        '-' => return makeToken(.TOKEN_MINUS),
        '+' => return makeToken(.TOKEN_PLUS),
        '/' => return makeToken(.TOKEN_SLASH),
        '*' => return makeToken(.TOKEN_STAR),
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
        '"' => return __scanner__string(),
        else => {},
    }
    return errorToken(@ptrCast(@constCast("Unexpected Character.")));
}
