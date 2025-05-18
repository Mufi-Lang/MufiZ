const std = @import("std");
pub const memcmp = @import("mem_utils.zig").memcmp;
pub const strlen = @import("mem_utils.zig").strlen;

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
    TOKEN_EACH = 29,
    TOKEN_FUN = 30,
    TOKEN_IF = 31,
    TOKEN_LET = 32,
    TOKEN_NIL = 33,
    TOKEN_OR = 34,
    TOKEN_PRINT = 35,
    TOKEN_RETURN = 36,
    TOKEN_SELF = 37,
    TOKEN_SUPER = 38,
    TOKEN_TRUE = 39,
    TOKEN_VAR = 40,
    TOKEN_WHILE = 41,
    TOKEN_ITEM = 42,
    // Misc
    TOKEN_ERROR = 43,
    TOKEN_EOF = 44,
    TOKEN_PLUS_EQUAL = 45,
    TOKEN_MINUS_EQUAL = 46,
    TOKEN_STAR_EQUAL = 47,
    TOKEN_SLASH_EQUAL = 48,
    TOKEN_PLUS_PLUS = 49,
    TOKEN_MINUS_MINUS = 50,
    TOKEN_HAT = 51,
    TOKEN_LEFT_SQPAREN = 52,
    TOKEN_RIGHT_SQPAREN = 53,
    TOKEN_COLON = 54,
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

pub fn initScanner(source: [*c]u8) void {
    scanner.start = source;
    scanner.current = source;
    scanner.line = 1;
}

pub fn isAlpha(c: u8) bool {
    return (c >= 'a' and c <= 'z') or
        (c >= 'A' and c <= 'Z') or
        c == '_';
}

pub fn isDigit(c: u8) bool {
    return c >= '0' and c <= '9';
}

pub fn isAtEnd() bool {
    return scanner.current.* == '\x00';
}

pub fn __scanner__advance() u8 {
    const char = scanner.current[0];
    scanner.current += 1;
    return char;
}

pub fn peek() u8 {
    return scanner.current.*;
}

pub fn peekNext() u8 {
    if (isAtEnd()) return 0;
    return scanner.current[1];
}
/// TODO: need to simply without converting so much
pub fn makeToken(type_: TokenType) Token {
    return .{
        .type = type_,
        .start = scanner.start,
        .length = @intCast(@intFromPtr(scanner.current) - @intFromPtr(scanner.start)),
        .line = scanner.line,
    };
}

pub fn errorToken(message: [*c]u8) Token {
    return .{
        .type = TokenType.TOKEN_ERROR,
        .start = message,
        .length = @intCast(strlen(message)),
        .line = scanner.line,
    };
}

pub fn skipWhitespace() void {
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
pub fn checkKeyword(arg_start: c_int, arg_length: c_int, arg_rest: [*c]const u8, arg_type: TokenType) TokenType {
    const start = arg_start;
    const length = arg_length;
    const rest = arg_rest;
    const @"type" = arg_type;
    if (@intFromPtr(scanner.current) - @intFromPtr(scanner.start) == start + length and memcmp(@ptrCast(@as([*c]u8, @ptrFromInt(@intFromPtr(scanner.start) + @as(usize, @intCast(start))))), @ptrCast(rest), @intCast(length)) == 0) {
        return @"type";
    }
    return .TOKEN_IDENTIFIER;
}
/// TODO: need to simply without converting so much
pub fn __scanner__match(arg_expected: u8) bool {
    const expected = arg_expected;
    if (isAtEnd()) return false;
    if ( scanner.current.* != expected) return false;
    scanner.current += 1;
    return true;
}

pub fn identifierType() TokenType {
    switch (scanner.start[0]) {
        'a' => return checkKeyword(1, 2, @ptrCast("nd"), .TOKEN_AND),
        'c' => return checkKeyword(1, 4, @ptrCast("lass"), .TOKEN_CLASS),
        'e' => {
            if (@intFromPtr(scanner.current) - @intFromPtr(scanner.start) > 1) {
                switch (scanner.start[1]) {
                    'l' => return checkKeyword(2, 2, @ptrCast("se"), .TOKEN_ELSE),
                    'a' => return checkKeyword(2, 2, @ptrCast("ch"), .TOKEN_EACH),
                    else => {},
                }
            }
        },
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
        'i' => {
            if (@intFromPtr(scanner.current) - @intFromPtr(scanner.start) > 1) {
                switch (scanner.start[1]) {
                    'f' => return checkKeyword(2, 0, @ptrCast(""), .TOKEN_IF),
                    't' => return checkKeyword(2, 2, @ptrCast("em"), .TOKEN_ITEM),
                    else => {},
                }
            }
        },
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
pub fn identifier() Token {
    while (isAlpha(peek()) or isDigit(peek())) {
        _ = __scanner__advance();
    }
    return makeToken(identifierType());
}

pub fn __scanner__number() Token {
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

pub fn __scanner__string() Token {
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

pub fn scanToken() Token {
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
        '[' => return makeToken(.TOKEN_LEFT_SQPAREN),
        ']' => return makeToken(.TOKEN_RIGHT_SQPAREN),
        ';' => return makeToken(.TOKEN_SEMICOLON),
        ':' => return makeToken(.TOKEN_COLON),
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
