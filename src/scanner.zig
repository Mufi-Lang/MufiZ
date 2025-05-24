const std = @import("std");
pub const memcmp = @import("mem_utils.zig").memcmp;
pub const strlen = @import("mem_utils.zig").strlen;

// HashMap for keyword lookup
const KeywordMap = std.HashMap([]const u8, TokenType, std.hash_map.StringContext, std.hash_map.default_max_load_percentage);

var keyword_map: KeywordMap = undefined;
var keyword_map_initialized: bool = false;

fn initKeywordMap() void {
    if (keyword_map_initialized) return;

    keyword_map = KeywordMap.init(std.heap.page_allocator);

    keyword_map.put("and", .TOKEN_AND) catch unreachable;
    keyword_map.put("class", .TOKEN_CLASS) catch unreachable;
    keyword_map.put("else", .TOKEN_ELSE) catch unreachable;
    keyword_map.put("each", .TOKEN_EACH) catch unreachable;
    keyword_map.put("false", .TOKEN_FALSE) catch unreachable;
    keyword_map.put("for", .TOKEN_FOR) catch unreachable;
    keyword_map.put("fun", .TOKEN_FUN) catch unreachable;
    keyword_map.put("if", .TOKEN_IF) catch unreachable;
    keyword_map.put("item", .TOKEN_ITEM) catch unreachable;
    keyword_map.put("let", .TOKEN_LET) catch unreachable;
    keyword_map.put("nil", .TOKEN_NIL) catch unreachable;
    keyword_map.put("or", .TOKEN_OR) catch unreachable;
    keyword_map.put("print", .TOKEN_PRINT) catch unreachable;
    keyword_map.put("return", .TOKEN_RETURN) catch unreachable;
    keyword_map.put("self", .TOKEN_SELF) catch unreachable;
    keyword_map.put("super", .TOKEN_SUPER) catch unreachable;
    keyword_map.put("true", .TOKEN_TRUE) catch unreachable;
    keyword_map.put("var", .TOKEN_VAR) catch unreachable;
    keyword_map.put("while", .TOKEN_WHILE) catch unreachable;

    keyword_map_initialized = true;
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

pub const Token = struct {
    type: TokenType,
    start: [*]u8,
    length: i32,
    line: i32,
};

pub const Scanner = struct {
    start: [*]u8,
    current: [*]u8,
    line: i32,
};

var scanner: Scanner = undefined;

pub fn init_scanner(source: [*c]u8) void {
    scanner.start = @ptrCast(source);
    scanner.current = @ptrCast(source);
    scanner.line = 1;
    initKeywordMap();
}

pub fn is_alpha(c: u8) bool {
    return (c >= 'a' and c <= 'z') or
        (c >= 'A' and c <= 'Z') or
        c == '_';
}

pub fn is_digit(c: u8) bool {
    return c >= '0' and c <= '9';
}

pub fn is_at_end() bool {
    return scanner.current[0] == '\x00';
}

pub fn advance() u8 {
    const char = scanner.current[0];
    scanner.current += 1;
    return char;
}

pub fn peek() u8 {
    return scanner.current[0];
}

pub fn peekNext() u8 {
    if (is_at_end()) return 0;
    return scanner.current[1];
}
/// TODO: need to simply without converting so much
pub fn make_token(type_: TokenType) Token {
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
        .start = @ptrCast(message),
        .length = @intCast(strlen(message)),
        .line = scanner.line,
    };
}

pub fn skip_whitespace() void {
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
                    while (peek() != '\n' and !is_at_end()) _ = advance();
                } else {
                    return;
                }
            },
            else => return,
        }
    }
}

/// TODO: need to simply without converting so much
pub fn match(arg_expected: u8) bool {
    const expected = arg_expected;
    if (is_at_end()) return false;
    if (scanner.current[0] != expected) return false;
    scanner.current += 1;
    return true;
}

pub fn identifierType() TokenType {
    const length = @intFromPtr(scanner.current) - @intFromPtr(scanner.start);
    const identifier_slice = scanner.start[0..@intCast(length)];

    if (keyword_map.get(identifier_slice)) |token_type| {
        return token_type;
    }

    return .TOKEN_IDENTIFIER;
}
pub fn identifier() Token {
    while (is_alpha(peek()) or is_digit(peek())) {
        _ = advance();
    }
    return make_token(identifierType());
}

pub fn number() Token {
    while (is_digit(peek())) {
        _ = advance();
    }
    if (peek() == '.' and is_digit(peekNext())) {
        _ = advance();
        while (is_digit(peek())) _ = advance();

        return make_token(.TOKEN_DOUBLE);
    } else {
        return make_token(.TOKEN_INT);
    }
}

pub fn string() Token {
    while (peek() != '"' and !is_at_end()) {
        if (peek() == '\n') {
            scanner.line += 1;
        }
        _ = advance();
    }
    if (is_at_end()) return errorToken(@ptrCast(@constCast("Unterminated string.")));
    _ = advance();
    return make_token(.TOKEN_STRING);
}

pub fn scanToken() Token {
    skip_whitespace();
    scanner.start = scanner.current;
    if (is_at_end()) return make_token(.TOKEN_EOF);
    const c = advance();

    if (is_alpha(c)) return identifier();
    if (is_digit(c)) return number();

    switch (c) {
        '(' => return make_token(.TOKEN_LEFT_PAREN),
        ')' => return make_token(.TOKEN_RIGHT_PAREN),
        '{' => return make_token(.TOKEN_LEFT_BRACE),
        '}' => return make_token(.TOKEN_RIGHT_BRACE),
        '[' => return make_token(.TOKEN_LEFT_SQPAREN),
        ']' => return make_token(.TOKEN_RIGHT_SQPAREN),
        ';' => return make_token(.TOKEN_SEMICOLON),
        ':' => return make_token(.TOKEN_COLON),
        ',' => return make_token(.TOKEN_COMMA),
        '.' => return make_token(.TOKEN_DOT),
        '-' => {
            if (match('=')) {
                return make_token(.TOKEN_MINUS_EQUAL);
            } else if (match('-')) {
                return make_token(.TOKEN_MINUS_MINUS);
            } else {
                return make_token(.TOKEN_MINUS);
            }
        },
        '+' => {
            if (match('=')) {
                return make_token(.TOKEN_PLUS_EQUAL);
            } else if (match('+')) {
                return make_token(.TOKEN_PLUS_PLUS);
            } else {
                return make_token(.TOKEN_PLUS);
            }
        },
        '/' => {
            if (match('=')) return make_token(.TOKEN_SLASH_EQUAL) else return make_token(.TOKEN_SLASH);
        },
        '*' => {
            if (match('=')) return make_token(.TOKEN_STAR_EQUAL) else return make_token(.TOKEN_STAR);
        },
        '!' => {
            if (match('=')) return make_token(.TOKEN_BANG_EQUAL) else return make_token(.TOKEN_BANG);
        },
        '=' => {
            if (match('=')) return make_token(.TOKEN_EQUAL_EQUAL) else return make_token(.TOKEN_EQUAL);
        },
        '<' => {
            if (match('=')) return make_token(.TOKEN_LESS_EQUAL) else return make_token(.TOKEN_LESS);
        },
        '>' => {
            if (match('=')) return make_token(.TOKEN_GREATER_EQUAL) else return make_token(.TOKEN_GREATER);
        },
        '%' => return make_token(.TOKEN_PERCENT),
        '^' => return make_token(.TOKEN_HAT),
        '"' => return string(),
        else => {},
    }
    return errorToken(@ptrCast(@constCast("Unexpected Character.")));
}
