const std = @import("std");
const memcmp = @cImport(@cInclude("string.h")).memcmp;
const strlen = @cImport(@cInclude("string.h")).strlen;
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

pub export fn advance() callconv(.C) u8 {
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

pub export fn makeToken(type_: TokenType) callconv(.C) Token {
    return .{
        .type = type_,
        .start = scanner.start,
        .length = @as(i32, @bitCast(@as(c_int, @truncate(@divExact(@as(c_longlong, @bitCast(@intFromPtr(scanner.current) -% @intFromPtr(scanner.start))), @sizeOf(u8)))))),
        .line = scanner.line,
    };
}

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
            ' ', '\r', '\t' => _ = advance(),
            '\n' => {
                scanner.line += 1;
                _ = advance();
            },
            '/' => {
                if (peekNext() == '/') {
                    while (peek() != '\n' and !isAtEnd()) _ = advance();
                } else {
                    return;
                }
            },
            else => return,
        }
    }
}

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

//pub export fn scanToken() Token {}
