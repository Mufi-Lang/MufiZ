const std = @import("std");

const errors = @import("errors.zig");
pub const memcmp = @import("mem_utils.zig").memcmp;
pub const strlen = @import("mem_utils.zig").strlen;

// HashMap for keyword lookup
const KeywordMap = std.HashMap([]const u8, TokenType, std.hash_map.StringContext, std.hash_map.default_max_load_percentage);

var keyword_map: KeywordMap = undefined;
var keyword_map_initialized: bool = false;

// External declarations for error manager (defined in compiler.zig)
pub var globalErrorManager: ?*errors.ErrorManager = null;
pub var errorManagerInitialized: bool = false;

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
    keyword_map.put("foreach", .TOKEN_FOREACH) catch unreachable;
    keyword_map.put("in", .TOKEN_IN) catch unreachable;
    keyword_map.put("end", .TOKEN_END) catch unreachable;
    keyword_map.put("const", .TOKEN_CONST) catch unreachable;
    keyword_map.put("switch", .TOKEN_SWITCH) catch unreachable;
    keyword_map.put("case", .TOKEN_CASE) catch unreachable;
    keyword_map.put("break", .TOKEN_BREAK) catch unreachable;
    keyword_map.put("continue", .TOKEN_CONTINUE) catch unreachable;
    keyword_map.put("import", .TOKEN_IMPORT) catch unreachable;

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
    TOKEN_FOREACH = 43,
    TOKEN_IN = 44,
    TOKEN_END = 45,
    TOKEN_CONST = 46,
    TOKEN_SWITCH = 47,
    TOKEN_CASE = 48,
    TOKEN_BREAK = 49,
    TOKEN_CONTINUE = 50,
    TOKEN_IMPORT = 51,
    // Misc
    TOKEN_ERROR = 52,
    TOKEN_EOF = 53,
    TOKEN_PLUS_EQUAL = 54,
    TOKEN_MINUS_EQUAL = 55,
    TOKEN_STAR_EQUAL = 56,
    TOKEN_SLASH_EQUAL = 57,
    TOKEN_PLUS_PLUS = 58,
    TOKEN_MINUS_MINUS = 59,
    TOKEN_HAT = 60,
    TOKEN_LEFT_SQPAREN = 61,
    TOKEN_RIGHT_SQPAREN = 62,
    TOKEN_COLON = 63,
    TOKEN_IMAGINARY = 64,
    TOKEN_MULTILINE_STRING = 65,
    TOKEN_BACKTICK_STRING = 66,
    TOKEN_F_STRING = 67,
    TOKEN_ARROW = 68,
    TOKEN_HASH = 69,
    TOKEN_RANGE_EXCLUSIVE = 70,
    TOKEN_RANGE_INCLUSIVE = 71,
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

pub var scanner: Scanner = undefined;

pub fn init_scanner(source: [*]u8) void {
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

pub fn errorToken(message: [*]u8) Token {
    // Also report enhanced error through error system if available
    if (errorManagerInitialized and globalErrorManager != null) {
        const msg_len = strlen(message);
        const msg_slice = message[0..msg_len];

        const errorInfo = errors.ErrorInfo{
            .code = .INVALID_CHARACTER,
            .category = .SYNTAX,
            .severity = .ERROR,
            .line = @intCast(@as(u32, @bitCast(scanner.line))),
            .column = @intCast(scanner.current - scanner.start + 1),
            .length = 1,
            .message = msg_slice,
            .suggestions = &[_]errors.ErrorSuggestion{
                .{ .message = "Remove or replace the invalid character" },
                .{ .message = "Check for non-ASCII characters or symbols" },
            },
        };

        globalErrorManager.?.reportError(errorInfo);
    }

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
                    // Single-line comment
                    while (peek() != '\n' and !is_at_end()) _ = advance();
                } else if (peekNext() == '#') {
                    // Multi-line comment
                    _ = advance(); // Consume '/'
                    _ = advance(); // Consume '#'

                    var nesting: u32 = 1;
                    while (nesting > 0 and !is_at_end()) {
                        if (peek() == '/' and peekNext() == '#') {
                            // Nested comment start
                            _ = advance(); // Consume '/'
                            _ = advance(); // Consume '#'
                            nesting += 1;
                        } else if (peek() == '#' and peekNext() == '/') {
                            // Comment end
                            _ = advance(); // Consume '#'
                            _ = advance(); // Consume '/'
                            nesting -= 1;
                        } else {
                            if (peek() == '\n') scanner.line += 1;
                            _ = advance();
                        }
                    }

                    if (is_at_end() and nesting > 0) {
                        if (errorManagerInitialized and globalErrorManager != null) {
                            const errorInfo = errors.ErrorInfo{
                                .code = .UNTERMINATED_COMMENT,
                                .category = .SYNTAX,
                                .severity = .ERROR,
                                .line = @intCast(@as(u32, @bitCast(scanner.line))),
                                .column = 1,
                                .length = 2,
                                .message = "Unterminated multi-line comment",
                                .suggestions = &[_]errors.ErrorSuggestion{
                                    .{ .message = "Add #/ to close the multi-line comment" },
                                },
                            };
                            globalErrorManager.?.reportError(errorInfo);
                        }
                    }
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

        // Check for imaginary unit 'i'
        if (peek() == 'i') {
            _ = advance();
            return make_token(.TOKEN_IMAGINARY);
        }
        return make_token(.TOKEN_DOUBLE);
    } else {
        // Check for imaginary unit 'i' after integer
        if (peek() == 'i') {
            _ = advance();
            return make_token(.TOKEN_IMAGINARY);
        }
        return make_token(.TOKEN_INT);
    }
}

pub fn peek_for_complex() bool {
    var i: usize = 0;
    const start_pos = scanner.current;

    // Skip over first number
    while (start_pos[i] != 0 and is_digit(start_pos[i])) {
        i += 1;
    }
    if (start_pos[i] == '.' and is_digit(start_pos[i + 1])) {
        i += 1;
        while (start_pos[i] != 0 and is_digit(start_pos[i])) {
            i += 1;
        }
    }

    // Check for immediate 'i' (pure imaginary)
    if (start_pos[i] == 'i') {
        return true;
    }

    // Look for operator
    if (start_pos[i] == '+' or start_pos[i] == '-') {
        i += 1;

        // Skip optional digits for coefficient
        while (start_pos[i] != 0 and is_digit(start_pos[i])) {
            i += 1;
        }
        if (start_pos[i] == '.' and is_digit(start_pos[i + 1])) {
            i += 1;
            while (start_pos[i] != 0 and is_digit(start_pos[i])) {
                i += 1;
            }
        }

        // Must end with 'i'
        if (start_pos[i] == 'i') {
            return true;
        }
    }

    return false;
}

pub fn parse_complex_token() Token {
    // Start by parsing the first number
    while (is_digit(peek())) {
        _ = advance();
    }
    if (peek() == '.' and is_digit(peekNext())) {
        _ = advance();
        while (is_digit(peek())) _ = advance();
    }

    // Check for 'i' (pure imaginary)
    if (peek() == 'i') {
        _ = advance();
        return make_token(.TOKEN_IMAGINARY);
    }

    // Check for operator
    if (peek() == '+' or peek() == '-') {
        _ = advance();

        // Parse second number (imaginary coefficient)
        while (is_digit(peek())) {
            _ = advance();
        }
        if (peek() == '.' and is_digit(peekNext())) {
            _ = advance();
            while (is_digit(peek())) _ = advance();
        }

        // Must end with 'i'
        if (peek() == 'i') {
            _ = advance();
            return make_token(.TOKEN_IMAGINARY);
        }
    }

    // Enhanced error for complex numbers
    if (errorManagerInitialized and globalErrorManager != null) {
        const errorInfo = errors.ErrorInfo{
            .code = .INVALID_CHARACTER,
            .category = .SYNTAX,
            .severity = .ERROR,
            .line = @intCast(@as(u32, @bitCast(scanner.line))),
            .column = @intCast(scanner.current - scanner.start + 1),
            .length = @intCast(@intFromPtr(scanner.current) - @intFromPtr(scanner.start)),
            .message = "Invalid complex number format",
            .suggestions = &[_]errors.ErrorSuggestion{
                .{ .message = "Complex numbers should be in format: real+imagi or real-imagi" },
                .{ .message = "Use proper complex number format", .example = "3+4i, 2.5-1.2i, 0+5i" },
                .{ .message = "Ensure both real and imaginary parts are valid numbers" },
            },
        };
        globalErrorManager.?.reportError(errorInfo);
    }

    return errorToken(@ptrCast(@constCast("Invalid complex number.")));
}

pub fn string() Token {
    // Regular string processing
    while (peek() != '"' and !is_at_end()) {
        if (peek() == '\n') {
            scanner.line += 1;
        }
        _ = advance();
    }
    if (is_at_end()) {
        // Enhanced error for unterminated string
        if (errorManagerInitialized and globalErrorManager != null) {
            const errorInfo = errors.ErrorInfo{
                .code = .UNTERMINATED_STRING,
                .category = .SYNTAX,
                .severity = .ERROR,
                .line = @intCast(@as(u32, @bitCast(scanner.line))),
                .column = 1,
                .length = @intCast(@intFromPtr(scanner.current) - @intFromPtr(scanner.start)),
                .message = "Unterminated string literal",
                .suggestions = &[_]errors.ErrorSuggestion{
                    .{ .message = "Add a closing quote (\") to end the string" },
                    .{ .message = "Check for escaped quotes that should be \\\"" },
                    .{ .message = "Use proper string syntax", .example = "\"Hello, world!\"" },
                },
            };
            globalErrorManager.?.reportError(errorInfo);
        }
        return errorToken(@ptrCast(@constCast("Unterminated string.")));
    }
    _ = advance();
    return make_token(.TOKEN_STRING);
}

// f-string functionality moved to the 'f' case in scanToken
// and uses the string() function with a modified token type

pub fn processMultilineString() Token {
    // Process multi-line string content
    while (!is_at_end()) {
        // Check for closing backtick
        if (peek() == '`') {
            // Found closing backtick
            _ = advance(); // Consume `
            return make_token(.TOKEN_BACKTICK_STRING);
        }

        if (peek() == '\n') {
            scanner.line += 1;
        }
        _ = advance();
    }

    // Unterminated multi-line string
    if (errorManagerInitialized and globalErrorManager != null) {
        const errorInfo = errors.ErrorInfo{
            .code = .UNTERMINATED_STRING,
            .category = .SYNTAX,
            .severity = .ERROR,
            .line = @intCast(@as(u32, @bitCast(scanner.line))),
            .column = 1,
            .length = @intCast(@intFromPtr(scanner.current) - @intFromPtr(scanner.start)),
            .message = "Unterminated multi-line string literal",
            .suggestions = &[_]errors.ErrorSuggestion{
                .{ .message = "Add closing backtick (`) to end the multi-line string" },
                .{ .message = "Check that opening and closing backticks match" },
                .{ .message = "Multi-line strings use backticks (`) not quotes (\")" },
            },
        };
        globalErrorManager.?.reportError(errorInfo);
    }
    return errorToken(@ptrCast(@constCast("Unterminated backtick string.")));
}

pub fn scanToken() Token {
    skip_whitespace();
    scanner.start = scanner.current;
    if (is_at_end()) return make_token(.TOKEN_EOF);
    const c = advance();

    if (is_alpha(c)) return identifier();
    if (is_digit(c)) {
        // Look ahead to see if this could be a complex number
        if (peek_for_complex()) {
            return parse_complex_token();
        } else {
            return number();
        }
    }

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
        '.' => {
            if (match('.')) {
                if (match('=')) {
                    return make_token(.TOKEN_RANGE_INCLUSIVE);
                } else {
                    return make_token(.TOKEN_RANGE_EXCLUSIVE);
                }
            } else {
                return make_token(.TOKEN_DOT);
            }
        },
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
            if (match('=')) return make_token(.TOKEN_SLASH_EQUAL) else if (match('#')) {
                // Handle multi-line comment start in token context
                // We'll unread the '#' and let skip_whitespace handle it
                scanner.current -= 1;
                skip_whitespace();
                return scanToken();
            } else return make_token(.TOKEN_SLASH);
        },
        '*' => {
            if (match('=')) return make_token(.TOKEN_STAR_EQUAL) else return make_token(.TOKEN_STAR);
        },
        '!' => {
            if (match('=')) return make_token(.TOKEN_BANG_EQUAL) else return make_token(.TOKEN_BANG);
        },
        '=' => {
            if (match('=')) return make_token(.TOKEN_EQUAL_EQUAL) else if (match('>')) return make_token(.TOKEN_ARROW) else return make_token(.TOKEN_EQUAL);
        },
        '<' => {
            if (match('=')) return make_token(.TOKEN_LESS_EQUAL) else return make_token(.TOKEN_LESS);
        },
        '>' => {
            if (match('=')) return make_token(.TOKEN_GREATER_EQUAL) else return make_token(.TOKEN_GREATER);
        },
        '%' => return make_token(.TOKEN_PERCENT),
        '^' => return make_token(.TOKEN_HAT),
        '#' => return make_token(.TOKEN_HASH), // Used as a prefix for hashtable literals (#{})
        'f' => {
            // Check for f-string pattern (f followed immediately by ")
            if (peek() == '"') {
                _ = advance(); // Consume the quote character
                // Create a string token but mark it as f-string
                var token = string();
                // Change the token type to F_STRING
                token.type = .TOKEN_F_STRING;
                return token;
            } else {
                return identifier();
            }
        },
        '"' => {
            return string();
        },
        '`' => {
            return processMultilineString();
        },
        else => {},
    }
    // Enhanced error for unexpected character
    if (errorManagerInitialized and globalErrorManager != null) {
        const current_char = if (@intFromPtr(scanner.current) > @intFromPtr(scanner.start)) (scanner.current - 1)[0] else scanner.current[0];
        const message = std.fmt.allocPrint(std.heap.page_allocator, "Unexpected character '{c}' (ASCII {d})", .{ current_char, current_char }) catch "Unexpected character";

        const errorInfo = errors.ErrorInfo{
            .code = .UNEXPECTED_TOKEN,
            .category = .SYNTAX,
            .severity = .ERROR,
            .line = @intCast(@as(u32, @bitCast(scanner.line))),
            .column = @intCast(scanner.current - scanner.start),
            .length = 1,
            .message = message,
            .suggestions = &[_]errors.ErrorSuggestion{
                .{ .message = "Remove the unexpected character" },
                .{ .message = "Check if you meant to use a different operator or symbol" },
                .{ .message = "Ensure all characters are valid in the current context" },
            },
        };
        globalErrorManager.?.reportError(errorInfo);
    }

    return errorToken(@ptrCast(@constCast("Unexpected Character.")));
}
