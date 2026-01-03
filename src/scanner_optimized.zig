const std = @import("std");

const errors = @import("errors.zig");
const mem_utils = @import("mem_utils.zig");
pub const memcmp = @import("mem_utils.zig").memcmp;
pub const strlen = @import("mem_utils.zig").strlen;

// Optimized keyword lookup using perfect hash or trie
const KeywordEntry = struct {
    keyword: []const u8,
    token: TokenType,
    hash: u32,
};

// Pre-computed keyword table sorted by hash for binary search
const KEYWORD_TABLE = blk: {
    const keywords = [_]KeywordEntry{
        .{ .keyword = "and", .token = .TOKEN_AND, .hash = hashString("and") },
        .{ .keyword = "break", .token = .TOKEN_BREAK, .hash = hashString("break") },
        .{ .keyword = "case", .token = .TOKEN_CASE, .hash = hashString("case") },
        .{ .keyword = "class", .token = .TOKEN_CLASS, .hash = hashString("class") },
        .{ .keyword = "const", .token = .TOKEN_CONST, .hash = hashString("const") },
        .{ .keyword = "continue", .token = .TOKEN_CONTINUE, .hash = hashString("continue") },
        .{ .keyword = "each", .token = .TOKEN_EACH, .hash = hashString("each") },
        .{ .keyword = "else", .token = .TOKEN_ELSE, .hash = hashString("else") },
        .{ .keyword = "end", .token = .TOKEN_END, .hash = hashString("end") },
        .{ .keyword = "false", .token = .TOKEN_FALSE, .hash = hashString("false") },
        .{ .keyword = "for", .token = .TOKEN_FOR, .hash = hashString("for") },
        .{ .keyword = "foreach", .token = .TOKEN_FOREACH, .hash = hashString("foreach") },
        .{ .keyword = "fun", .token = .TOKEN_FUN, .hash = hashString("fun") },
        .{ .keyword = "if", .token = .TOKEN_IF, .hash = hashString("if") },
        .{ .keyword = "in", .token = .TOKEN_IN, .hash = hashString("in") },
        .{ .keyword = "item", .token = .TOKEN_ITEM, .hash = hashString("item") },
        .{ .keyword = "let", .token = .TOKEN_LET, .hash = hashString("let") },
        .{ .keyword = "nil", .token = .TOKEN_NIL, .hash = hashString("nil") },
        .{ .keyword = "or", .token = .TOKEN_OR, .hash = hashString("or") },
        .{ .keyword = "print", .token = .TOKEN_PRINT, .hash = hashString("print") },
        .{ .keyword = "return", .token = .TOKEN_RETURN, .hash = hashString("return") },
        .{ .keyword = "self", .token = .TOKEN_SELF, .hash = hashString("self") },
        .{ .keyword = "super", .token = .TOKEN_SUPER, .hash = hashString("super") },
        .{ .keyword = "switch", .token = .TOKEN_SWITCH, .hash = hashString("switch") },
        .{ .keyword = "true", .token = .TOKEN_TRUE, .hash = hashString("true") },
        .{ .keyword = "var", .token = .TOKEN_VAR, .hash = hashString("var") },
        .{ .keyword = "while", .token = .TOKEN_WHILE, .hash = hashString("while") },
    };

    // Sort by hash for binary search
    var sorted = keywords;
    const len = keywords.len;
    var i: usize = 1;
    while (i < len) : (i += 1) {
        const key = sorted[i];
        var j = i;
        while (j > 0 and sorted[j - 1].hash > key.hash) : (j -= 1) {
            sorted[j] = sorted[j - 1];
        }
        sorted[j] = key;
    }
    break :blk sorted;
};

// Fast hash function for keywords (compile-time)
fn hashString(str: []const u8) u32 {
    var hash: u32 = 5381;
    for (str) |c| {
        hash = ((hash << 5) +% hash) +% c;
    }
    return hash;
}

// External declarations for error manager
pub var globalErrorManager: ?*errors.ErrorManager = null;
pub var errorManagerInitialized: bool = false;

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
    // Special tokens
    TOKEN_ERROR = 51,
    TOKEN_EOF = 52,
    TOKEN_PLUS_EQUAL = 53,
    TOKEN_MINUS_EQUAL = 54,
    TOKEN_STAR_EQUAL = 55,
    TOKEN_SLASH_EQUAL = 56,
    TOKEN_PLUS_PLUS = 57,
    TOKEN_MINUS_MINUS = 58,
    TOKEN_HAT = 59,
    TOKEN_LEFT_SQPAREN = 60,
    TOKEN_RIGHT_SQPAREN = 61,
    TOKEN_COLON = 62,
    TOKEN_IMAGINARY = 63,
    TOKEN_MULTILINE_STRING = 64,
    TOKEN_BACKTICK_STRING = 65,
    TOKEN_F_STRING = 66,
    TOKEN_ARROW = 67,
    TOKEN_HASH = 68,
    TOKEN_RANGE_EXCLUSIVE = 69,
    TOKEN_RANGE_INCLUSIVE = 70,
};

pub const Token = struct {
    type: TokenType,
    start: [*]const u8,
    length: i32,
    line: i32,
};

pub const Scanner = struct {
    start: [*]const u8,
    current: [*]const u8,
    line: i32,
    source_end: [*]const u8, // Cache end pointer for bounds checking

    // Performance optimization: cache frequently accessed values
    last_char: u8,
    last_char_valid: bool,
};

pub var scanner: Scanner = undefined;

pub fn init_scanner(source: [*]u8) void {
    scanner.start = @ptrCast(source);
    scanner.current = @ptrCast(source);
    scanner.line = 1;
    // Calculate end by finding null terminator
    var len: usize = 0;
    while (source[len] != '\x00') len += 1;
    scanner.source_end = @ptrCast(source + len);
    scanner.last_char = 0;
    scanner.last_char_valid = false;
}

/// Get the start of the source code for column calculation
pub fn getSourceStart() [*]const u8 {
    return scanner.start;
}

// Public helper functions to match original scanner interface (removed duplicates)

// Internal helper functions (optimized versions)
inline fn is_at_end_internal() bool {
    return @intFromPtr(scanner.current) >= @intFromPtr(scanner.source_end);
}

inline fn advance_internal() u8 {
    if (is_at_end_internal()) return '\x00';
    const char = scanner.current[0];
    scanner.current += 1;
    return char;
}

inline fn peek_internal() u8 {
    if (is_at_end_internal()) return '\x00';
    return scanner.current[0];
}

inline fn peekNext_internal() u8 {
    if (is_at_end_internal()) return '\x00';
    if (@intFromPtr(scanner.current + 1) >= @intFromPtr(scanner.source_end)) return '\x00';
    return scanner.current[1];
}

inline fn match_internal(expected: u8) bool {
    if (is_at_end_internal()) return false;
    if (scanner.current[0] != expected) return false;
    scanner.current += 1;
    return true;
}

// Optimized character classification using lookup tables
const ALPHA_TABLE = blk: {
    var table: [256]bool = [_]bool{false} ** 256;
    for ('a'..('z' + 1)) |c| table[c] = true;
    for ('A'..('Z' + 1)) |c| table[c] = true;
    table['_'] = true;
    break :blk table;
};

const DIGIT_TABLE = blk: {
    var table: [256]bool = [_]bool{false} ** 256;
    for ('0'..('9' + 1)) |c| table[c] = true;
    break :blk table;
};

const WHITESPACE_TABLE = blk: {
    var table: [256]bool = [_]bool{false} ** 256;
    table[' '] = true;
    table['\r'] = true;
    table['\t'] = true;
    break :blk table;
};

pub fn is_alpha(c: u8) bool {
    return ALPHA_TABLE[c];
}

pub fn is_digit(c: u8) bool {
    return DIGIT_TABLE[c];
}

pub inline fn is_alphanum(c: u8) bool {
    return ALPHA_TABLE[c] or DIGIT_TABLE[c];
}

pub inline fn is_whitespace(c: u8) bool {
    return WHITESPACE_TABLE[c];
}

pub inline fn is_at_end() bool {
    return @intFromPtr(scanner.current) >= @intFromPtr(scanner.source_end);
}

pub inline fn advance() u8 {
    if (is_at_end()) return '\x00';
    const char = scanner.current[0];
    scanner.current += 1;
    scanner.last_char = char;
    scanner.last_char_valid = true;
    return char;
}

pub inline fn peek() u8 {
    if (is_at_end()) return '\x00';
    return scanner.current[0];
}

pub inline fn peekNext() u8 {
    if (@intFromPtr(scanner.current) + 1 >= @intFromPtr(scanner.source_end)) return '\x00';
    return scanner.current[1];
}

pub inline fn peek_at(offset: usize) u8 {
    if (@intFromPtr(scanner.current) + offset >= @intFromPtr(scanner.source_end)) return '\x00';
    return scanner.current[offset];
}

pub fn make_token(type_: TokenType) Token {
    return .{
        .type = type_,
        .start = scanner.start,
        .length = @intCast(@intFromPtr(scanner.current) - @intFromPtr(scanner.start)),
        .line = scanner.line,
    };
}

pub fn errorToken(message: [*]u8) Token {
    // Report error if error manager is available
    if (errorManagerInitialized and globalErrorManager != null) {
        const msg_len = mem_utils.strlen(message);
        const msg_slice = message[0..msg_len];

        const errorInfo = errors.ErrorInfo{
            .code = .INVALID_CHARACTER,
            .category = .SYNTAX,
            .severity = .ERROR,
            .line = @intCast(@as(u32, @bitCast(scanner.line))),
            .column = @intCast(@intFromPtr(scanner.current) - @intFromPtr(scanner.start) + 1),
            .length = 1,
            .message = msg_slice,
            .suggestions = &[_]errors.ErrorSuggestion{},
            .file_path = "",
        };
        globalErrorManager.?.reportError(errorInfo);
    }

    return Token{
        .type = .TOKEN_ERROR,
        .start = @constCast("Error"),
        .length = @intCast(mem_utils.strlen(message)),
        .line = scanner.line,
    };
}

// Optimized whitespace skipping with minimal branching
pub fn skip_whitespace() void {
    while (true) {
        const c = peek_internal();

        // Handle common whitespace characters first
        if (is_whitespace(c)) {
            _ = advance_internal();
            continue;
        }

        if (c == '\n') {
            scanner.line += 1;
            _ = advance_internal();
            continue;
        }

        // Handle comments
        if (c == '/') {
            const next = peekNext_internal();
            if (next == '/') {
                // Single-line comment
                _ = advance_internal(); // /
                _ = advance_internal(); // /
                while (peek_internal() != '\n' and !is_at_end_internal()) {
                    _ = advance_internal();
                }
                continue;
            } else if (next == '#') {
                // Multi-line comment
                _ = advance_internal(); // /
                _ = advance_internal(); // #

                var nesting: u32 = 1;
                while (nesting > 0 and !is_at_end_internal()) {
                    const curr = peek_internal();
                    const peek_next = peekNext_internal();

                    if (curr == '/' and peek_next == '#') {
                        _ = advance_internal();
                        _ = advance_internal();
                        nesting += 1;
                    } else if (curr == '#' and peek_next == '/') {
                        _ = advance_internal();
                        _ = advance_internal();
                        nesting -= 1;
                    } else {
                        if (curr == '\n') scanner.line += 1;
                        _ = advance_internal();
                    }
                }

                if (is_at_end_internal() and nesting > 0) {
                    // Report unterminated comment error
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
                continue;
            }
        }

        // No more whitespace or comments
        break;
    }
}

pub inline fn match(expected: u8) bool {
    if (is_at_end() or scanner.current[0] != expected) return false;
    scanner.current += 1;
    return true;
}

// Optimized keyword lookup using binary search on pre-sorted hash table
pub fn identifierType() TokenType {
    const length = @intFromPtr(scanner.current) - @intFromPtr(scanner.start);
    if (length == 0) return .TOKEN_IDENTIFIER;

    const identifier_slice = scanner.start[0..@intCast(length)];

    // Quick length-based filtering for common cases
    switch (length) {
        1 => {
            // No 1-letter keywords
            return .TOKEN_IDENTIFIER;
        },
        2 => {
            // Handle 2-letter keywords: "if", "in", "or"
            const first = identifier_slice[0];
            const second = identifier_slice[1];
            if (first == 'i' and second == 'f') return .TOKEN_IF;
            if (first == 'i' and second == 'n') return .TOKEN_IN;
            if (first == 'o' and second == 'r') return .TOKEN_OR;
            return .TOKEN_IDENTIFIER;
        },
        3 => {
            // Handle 3-letter keywords: "and", "for", "fun", "let", "nil", "var", "end"
            const hash = hashString(identifier_slice);
            switch (hash) {
                hashString("and") => if (std.mem.eql(u8, identifier_slice, "and")) return .TOKEN_AND,
                hashString("for") => if (std.mem.eql(u8, identifier_slice, "for")) return .TOKEN_FOR,
                hashString("fun") => if (std.mem.eql(u8, identifier_slice, "fun")) return .TOKEN_FUN,
                hashString("let") => if (std.mem.eql(u8, identifier_slice, "let")) return .TOKEN_LET,
                hashString("nil") => if (std.mem.eql(u8, identifier_slice, "nil")) return .TOKEN_NIL,
                hashString("var") => if (std.mem.eql(u8, identifier_slice, "var")) return .TOKEN_VAR,
                hashString("end") => if (std.mem.eql(u8, identifier_slice, "end")) return .TOKEN_END,
                else => {},
            }
            return .TOKEN_IDENTIFIER;
        },
        else => {
            // Use binary search for longer keywords
            const hash = hashString(identifier_slice);
            var left: usize = 0;
            var right: usize = KEYWORD_TABLE.len;

            while (left < right) {
                const mid = (left + right) / 2;
                const mid_hash = KEYWORD_TABLE[mid].hash;

                if (mid_hash == hash) {
                    // Hash match, verify string equality
                    if (std.mem.eql(u8, identifier_slice, KEYWORD_TABLE[mid].keyword)) {
                        return KEYWORD_TABLE[mid].token;
                    }
                    // Hash collision, search adjacent entries
                    var i = mid;
                    while (i > 0 and KEYWORD_TABLE[i - 1].hash == hash) {
                        i -= 1;
                        if (std.mem.eql(u8, identifier_slice, KEYWORD_TABLE[i].keyword)) {
                            return KEYWORD_TABLE[i].token;
                        }
                    }
                    i = mid + 1;
                    while (i < KEYWORD_TABLE.len and KEYWORD_TABLE[i].hash == hash) {
                        if (std.mem.eql(u8, identifier_slice, KEYWORD_TABLE[i].keyword)) {
                            return KEYWORD_TABLE[i].token;
                        }
                        i += 1;
                    }
                    break;
                } else if (mid_hash < hash) {
                    left = mid + 1;
                } else {
                    right = mid;
                }
            }
            return .TOKEN_IDENTIFIER;
        },
    }
}

pub fn identifier() Token {
    // Check for f-string at the start
    if (scanner.start[0] == 'f' and peek_internal() == '"') {
        _ = advance_internal(); // consume quote
        var token = string();
        token.type = .TOKEN_F_STRING;
        return token;
    }

    // Fast identifier scanning - avoid function calls in tight loop
    while (true) {
        const c = peek();
        if (!is_alphanum(c)) break;
        _ = advance();
    }
    return make_token(identifierType());
}

// Optimized number parsing with minimal branching
fn number() Token {
    // Scan integer part
    while (is_digit(peek_internal())) {
        _ = advance_internal();
    }

    // Check for decimal point
    if (peek_internal() == '.' and is_digit(peekNext_internal())) {
        _ = advance_internal(); // consume '.'
        while (is_digit(peek_internal())) {
            _ = advance_internal();
        }

        // Check for imaginary unit 'i'
        if (peek_internal() == 'i') {
            _ = advance_internal();
            return make_token(.TOKEN_IMAGINARY);
        }
        return make_token(.TOKEN_DOUBLE);
    }

    // Check for imaginary unit after integer
    if (peek_internal() == 'i') {
        _ = advance_internal();
        return make_token(.TOKEN_IMAGINARY);
    }

    return make_token(.TOKEN_INT);
}

// Fast complex number detection
pub fn peek_for_complex() bool {
    // Look ahead for patterns like: number+numberi, number-numberi
    var temp_pos: [*]const u8 = scanner.current;
    const end = scanner.source_end;

    // Skip digits
    while (@intFromPtr(temp_pos) < @intFromPtr(end) and is_digit(temp_pos[0])) {
        temp_pos += 1;
    }

    // Skip decimal part if present
    if (@intFromPtr(temp_pos) < @intFromPtr(end) and temp_pos[0] == '.' and @intFromPtr(temp_pos) + 1 < @intFromPtr(end) and is_digit(temp_pos[1])) {
        temp_pos += 1; // skip '.'
        while (@intFromPtr(temp_pos) < @intFromPtr(end) and is_digit(temp_pos[0])) {
            temp_pos += 1;
        }
    }

    // Check for '+' or '-'
    if (@intFromPtr(temp_pos) < @intFromPtr(end) and (temp_pos[0] == '+' or temp_pos[0] == '-')) {
        temp_pos += 1;

        // Skip more digits
        while (@intFromPtr(temp_pos) < @intFromPtr(end) and is_digit(temp_pos[0])) {
            temp_pos += 1;
        }

        // Skip decimal part if present
        if (@intFromPtr(temp_pos) < @intFromPtr(end) and temp_pos[0] == '.' and @intFromPtr(temp_pos) + 1 < @intFromPtr(end) and is_digit(temp_pos[1])) {
            temp_pos += 1; // skip '.'
            while (@intFromPtr(temp_pos) < @intFromPtr(end) and is_digit(temp_pos[0])) {
                temp_pos += 1;
            }
        }

        // Check for 'i'
        return @intFromPtr(temp_pos) < @intFromPtr(end) and temp_pos[0] == 'i';
    }

    return false;
}

fn parse_complex_token() Token {
    // Parse first number (real part)
    while (is_digit(peek_internal())) _ = advance_internal();
    if (peek_internal() == '.' and is_digit(peekNext_internal())) {
        _ = advance_internal(); // consume '.'
        while (is_digit(peek_internal())) _ = advance_internal();
    }

    // Consume + or -
    if (peek_internal() == '+' or peek_internal() == '-') {
        _ = advance_internal();
    }

    // Parse second number (imaginary part)
    // Parse imaginary part
    while (is_digit(peek_internal())) _ = advance_internal();
    if (peek_internal() == '.' and is_digit(peekNext_internal())) {
        _ = advance_internal(); // consume '.'
        while (is_digit(peek_internal())) _ = advance_internal();
    }

    // Consume 'i'
    if (peek_internal() == 'i') {
        _ = advance_internal();
    }

    return make_token(.TOKEN_IMAGINARY);
}

// Optimized string parsing with escape sequence handling
pub fn string() Token {
    while (true) {
        const c = peek_internal();

        if (c == '"') {
            _ = advance_internal(); // consume closing quote
            return make_token(.TOKEN_STRING);
        }

        if (c == '\x00') {
            // Unterminated string
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
                    },
                };
                globalErrorManager.?.reportError(errorInfo);
            }
            return errorToken(@constCast("Unterminated string."));
        }

        if (c == '\n') {
            scanner.line += 1;
        } else if (c == '\\') {
            // Skip escape sequence
            _ = advance_internal(); // consume backslash
            if (!is_at_end_internal()) _ = advance_internal(); // consume escaped character
            continue;
        }

        _ = advance_internal();
    }
}

pub fn processMultilineString() Token {
    while (true) {
        const c = peek_internal();

        if (c == '`') {
            _ = advance_internal(); // consume closing backtick
            return make_token(.TOKEN_BACKTICK_STRING);
        }

        if (c == '\x00') {
            return errorToken(@constCast("Unterminated multiline string."));
        }

        if (c == '\n') {
            scanner.line += 1;
        }

        _ = advance_internal();
    }
}

// Main tokenization function with optimized dispatch
pub fn scanToken() Token {
    skip_whitespace();
    scanner.start = scanner.current;

    if (is_at_end_internal()) return make_token(.TOKEN_EOF);

    const c = advance_internal();

    // Fast path for common tokens using computed goto simulation
    switch (c) {
        'a'...'z', 'A'...'Z', '_' => {
            // Identifier or keyword - backtrack and reparse
            scanner.current = scanner.start;
            _ = advance_internal(); // re-advance to maintain state
            return identifier();
        },
        '0'...'9' => {
            // Number - backtrack and reparse
            scanner.current = scanner.start;
            _ = advance_internal(); // re-advance to maintain state
            if (peek_for_complex()) {
                return parse_complex_token();
            } else {
                return number();
            }
        },
        '(' => return make_token(.TOKEN_LEFT_PAREN),
        ')' => return make_token(.TOKEN_RIGHT_PAREN),
        '{' => return make_token(.TOKEN_LEFT_BRACE),
        '}' => return make_token(.TOKEN_RIGHT_BRACE),
        '[' => return make_token(.TOKEN_LEFT_SQPAREN),
        ']' => return make_token(.TOKEN_RIGHT_SQPAREN),
        ';' => return make_token(.TOKEN_SEMICOLON),
        ':' => return make_token(.TOKEN_COLON),
        ',' => return make_token(.TOKEN_COMMA),
        '^' => return make_token(.TOKEN_HAT),
        '%' => return make_token(.TOKEN_PERCENT),
        '#' => return make_token(.TOKEN_HASH),
        '`' => return processMultilineString(),
        '"' => return string(),
        '.' => {
            if (match_internal('.')) {
                return make_token(if (match_internal('=')) .TOKEN_RANGE_INCLUSIVE else .TOKEN_RANGE_EXCLUSIVE);
            } else {
                return make_token(.TOKEN_DOT);
            }
        },
        '-' => {
            return make_token(if (match_internal('=')) .TOKEN_MINUS_EQUAL else if (match_internal('-')) .TOKEN_MINUS_MINUS else .TOKEN_MINUS);
        },
        '+' => {
            return make_token(if (match_internal('=')) .TOKEN_PLUS_EQUAL else if (match_internal('+')) .TOKEN_PLUS_PLUS else .TOKEN_PLUS);
        },
        '/' => {
            if (match_internal('=')) {
                return make_token(.TOKEN_SLASH_EQUAL);
            } else if (match_internal('#')) {
                // Multi-line comment - backtrack and skip
                scanner.current -= 1; // unread '#'
                skip_whitespace();
                return scanToken();
            } else {
                return make_token(.TOKEN_SLASH);
            }
        },
        '*' => {
            return make_token(if (match_internal('=')) .TOKEN_STAR_EQUAL else .TOKEN_STAR);
        },
        '!' => {
            return make_token(if (match_internal('=')) .TOKEN_BANG_EQUAL else .TOKEN_BANG);
        },
        '=' => {
            if (match_internal('=')) {
                return make_token(.TOKEN_EQUAL_EQUAL);
            } else if (match_internal('>')) {
                return make_token(.TOKEN_ARROW);
            } else {
                return make_token(.TOKEN_EQUAL);
            }
        },
        '<' => {
            return make_token(if (match_internal('=')) .TOKEN_LESS_EQUAL else .TOKEN_LESS);
        },
        '>' => {
            return make_token(if (match_internal('=')) .TOKEN_GREATER_EQUAL else .TOKEN_GREATER);
        },

        else => {
            // Unknown character
            if (errorManagerInitialized and globalErrorManager != null) {
                const error_msg = std.fmt.allocPrint(std.heap.page_allocator, "Unexpected character '{c}' (ASCII {d})", .{ c, c }) catch "Unexpected character";
                const errorInfo = errors.ErrorInfo{
                    .code = .UNEXPECTED_TOKEN,
                    .category = .SYNTAX,
                    .severity = .ERROR,
                    .line = @intCast(@as(u32, @bitCast(scanner.line))),
                    .column = @intCast(@intFromPtr(scanner.current) - @intFromPtr(scanner.start)),
                    .length = 1,
                    .message = error_msg,
                    .suggestions = &[_]errors.ErrorSuggestion{
                        .{ .message = "Remove the unexpected character" },
                        .{ .message = "Check if you meant to use a different operator or symbol" },
                    },
                    .file_path = "",
                };
                globalErrorManager.?.reportError(errorInfo);
            }

            return errorToken(@constCast("Unexpected character"));
        },
    }
}
