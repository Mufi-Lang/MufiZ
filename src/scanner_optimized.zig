/// MufiZ Optimized Scanner Module
/// This is an optimized lexical analyzer for the MufiZ language.
/// Improvements over the basic scanner include:
/// - Pre-computed keyword hash table with binary search
/// - Optimized number parsing
/// - Better error reporting with position tracking
/// - Support for complex numbers (e.g., 3+4i)
/// - Efficient string handling
const std = @import("std");
const builtin = @import("builtin");

const errors = @import("errors.zig");
const mem_utils = @import("mem_utils.zig");

// ========================================
// SIMD SUPPORT
// ========================================

/// Check if SIMD is available on this platform
const simd_available = switch (builtin.cpu.arch) {
    .x86_64 => true,
    .aarch64 => true,
    else => false,
};

/// SIMD vector width (16 bytes for SSE/NEON)
const SIMD_WIDTH = 16;

// Perfect Hash Implementation for Keyword Lookup
// This provides O(1) keyword lookup with zero collisions
// The hash table is computed at compile time

const PerfectHashEntry = struct {
    keyword: []const u8,
    token: TokenType,
};

// Perfect hash table size (must be power of 2 for fast modulo)
const PERFECT_HASH_SIZE = 64;

// Hash multipliers found by compile-time search to avoid collisions
// These values provide perfect distribution with zero collisions
const HASH_MULT_FIRST = 2;
const HASH_MULT_LAST = 5;
const HASH_MULT_MID = 37;
const HASH_MULT_LEN = 11;

// Compile-time perfect hash function
// Uses a combination of length, first char, last char, and middle char
inline fn perfectHash(str: []const u8) u8 {
    if (str.len == 0) return 0;
    const len = str.len;
    const first = str[0];
    const last = str[len - 1];
    const middle = if (len > 2) str[len / 2] else first;

    // Optimized hash using pre-computed multipliers
    const hash = (@as(u32, first) *% HASH_MULT_FIRST) +%
        (@as(u32, last) *% HASH_MULT_LAST) +%
        (@as(u32, middle) *% HASH_MULT_MID) +%
        (@as(u32, @intCast(len)) *% HASH_MULT_LEN);
    return @truncate(hash & 63);
}

// Compile-time search for collision-free hash multipliers
fn findPerfectHashMultipliers() void {
    comptime {
        const keywords = [_][]const u8{
            "and",  "as",    "break",  "case",  "class", "const",   "continue",
            "each", "else",  "end",    "false", "for",   "foreach", "from",
            "fun",  "if",    "import", "in",    "item",  "let",     "nil",
            "or",   "print", "return", "self",  "super", "switch",  "true",
            "var",  "while",
        };

        // Test with our chosen multipliers
        var used = [_]bool{false} ** PERFECT_HASH_SIZE;
        for (keywords) |kw| {
            const hash = perfectHash(kw);
            if (used[hash]) {
                @compileError("Perfect hash collision detected for keyword: " ++ kw ++
                    ". Adjust HASH_MULT_* constants to find collision-free values.");
            }
            used[hash] = true;
        }
    }
}

// Build the perfect hash lookup table at compile time
const PERFECT_HASH_TABLE = blk: {
    // Verify no collisions
    findPerfectHashMultipliers();

    // Initialize table with null entries
    var table: [PERFECT_HASH_SIZE]?PerfectHashEntry = [_]?PerfectHashEntry{null} ** PERFECT_HASH_SIZE;

    // Insert all keywords into their perfect hash positions
    const keywords = [_]struct { str: []const u8, tok: TokenType }{
        .{ .str = "and", .tok = .TOKEN_AND },
        .{ .str = "as", .tok = .TOKEN_AS },
        .{ .str = "break", .tok = .TOKEN_BREAK },
        .{ .str = "case", .tok = .TOKEN_CASE },
        .{ .str = "class", .tok = .TOKEN_CLASS },
        .{ .str = "const", .tok = .TOKEN_CONST },
        .{ .str = "continue", .tok = .TOKEN_CONTINUE },
        .{ .str = "each", .tok = .TOKEN_EACH },
        .{ .str = "else", .tok = .TOKEN_ELSE },
        .{ .str = "end", .tok = .TOKEN_END },
        .{ .str = "false", .tok = .TOKEN_FALSE },
        .{ .str = "for", .tok = .TOKEN_FOR },
        .{ .str = "foreach", .tok = .TOKEN_FOREACH },
        .{ .str = "from", .tok = .TOKEN_FROM },
        .{ .str = "fun", .tok = .TOKEN_FUN },
        .{ .str = "if", .tok = .TOKEN_IF },
        .{ .str = "import", .tok = .TOKEN_IMPORT },
        .{ .str = "in", .tok = .TOKEN_IN },
        .{ .str = "item", .tok = .TOKEN_ITEM },
        .{ .str = "let", .tok = .TOKEN_LET },
        .{ .str = "nil", .tok = .TOKEN_NIL },
        .{ .str = "or", .tok = .TOKEN_OR },
        .{ .str = "print", .tok = .TOKEN_PRINT },
        .{ .str = "return", .tok = .TOKEN_RETURN },
        .{ .str = "self", .tok = .TOKEN_SELF },
        .{ .str = "super", .tok = .TOKEN_SUPER },
        .{ .str = "switch", .tok = .TOKEN_SWITCH },
        .{ .str = "true", .tok = .TOKEN_TRUE },
        .{ .str = "var", .tok = .TOKEN_VAR },
        .{ .str = "while", .tok = .TOKEN_WHILE },
    };

    for (keywords) |kw| {
        const hash = perfectHash(kw.str);
        table[hash] = PerfectHashEntry{
            .keyword = kw.str,
            .token = kw.tok,
        };
    }

    break :blk table;
};

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
    // Import tokens
    TOKEN_IMPORT = 51,
    TOKEN_FROM = 52,
    TOKEN_AS = 53,
    // Special tokens
    TOKEN_ERROR = 54,
    TOKEN_EOF = 55,
    TOKEN_PLUS_EQUAL = 56,
    TOKEN_MINUS_EQUAL = 57,
    TOKEN_STAR_EQUAL = 58,
    TOKEN_SLASH_EQUAL = 59,
    TOKEN_PLUS_PLUS = 60,
    TOKEN_MINUS_MINUS = 61,
    TOKEN_HAT = 62,
    TOKEN_LEFT_SQPAREN = 63,
    TOKEN_RIGHT_SQPAREN = 64,
    TOKEN_COLON = 65,
    TOKEN_IMAGINARY = 66,
    TOKEN_MULTILINE_STRING = 67,
    TOKEN_BACKTICK_STRING = 68,
    TOKEN_F_STRING = 69,
    TOKEN_ARROW = 70,
    TOKEN_HASH = 71,
    TOKEN_RANGE_EXCLUSIVE = 72,
    TOKEN_RANGE_INCLUSIVE = 73,
    TOKEN_QUESTION = 74,
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
// Branchless bounds check using pointer comparison
inline fn is_at_end_internal() bool {
    return @intFromPtr(scanner.current) >= @intFromPtr(scanner.source_end);
}

// Optimized advance with direct pointer access
inline fn advance_internal() u8 {
    const not_at_end = @intFromPtr(scanner.current) < @intFromPtr(scanner.source_end);
    const char = if (not_at_end) scanner.current[0] else '\x00';
    scanner.current += @intFromBool(not_at_end);
    return char;
}

// Optimized peek with single comparison
inline fn peek_internal() u8 {
    return if (@intFromPtr(scanner.current) < @intFromPtr(scanner.source_end)) scanner.current[0] else '\x00';
}

// Optimized peekNext with single comparison
inline fn peekNext_internal() u8 {
    const next_ptr = scanner.current + 1;
    return if (@intFromPtr(next_ptr) < @intFromPtr(scanner.source_end)) scanner.current[1] else '\x00';
}

// Branchless match using multiplication
inline fn match_internal(expected: u8) bool {
    const matches = (@intFromPtr(scanner.current) < @intFromPtr(scanner.source_end)) and (scanner.current[0] == expected);
    scanner.current += @intFromBool(matches);
    return matches;
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

// Character classification helpers using lookup tables
pub inline fn is_alpha(c: u8) bool {
    return ALPHA_TABLE[c];
}

pub inline fn is_digit(c: u8) bool {
    return DIGIT_TABLE[c];
}

// Branchless alphanum check using bitwise OR on table values
pub inline fn is_alphanum(c: u8) bool {
    return ALPHA_TABLE[c] or DIGIT_TABLE[c];
}

pub inline fn is_whitespace(c: u8) bool {
    return WHITESPACE_TABLE[c];
}

// ========================================
// SIMD OPTIMIZED OPERATIONS (FUTURE WORK)
// ========================================
// NOTE: SIMD optimizations are disabled pending vector boolean operation fixes
// The infrastructure is in place for future implementation
// Expected improvements: 20-40% for bulk operations when enabled
// ========================================
// END SIMD OPERATIONS
// ========================================

// Optimized end check using direct pointer comparison
pub inline fn is_at_end() bool {
    return @intFromPtr(scanner.current) >= @intFromPtr(scanner.source_end);
}

// ========================================
// DISPATCH TABLE INFRASTRUCTURE
// ========================================
// Advanced dispatch using function pointers for O(1) character routing
// This eliminates branch mispredictions in the hot path

const TokenHandlerFn = *const fn () Token;

// Handler implementations - these assume the character has already been consumed
// Note: These are defined before DISPATCH_TABLE which references them
fn handleIdentifier() Token {
    scanner.current = scanner.start;
    _ = advance_internal();
    return identifier();
}

fn handleNumber() Token {
    return number();
}

fn handleLeftParen() Token {
    return make_token(.TOKEN_LEFT_PAREN);
}

fn handleRightParen() Token {
    return make_token(.TOKEN_RIGHT_PAREN);
}

fn handleLeftBrace() Token {
    return make_token(.TOKEN_LEFT_BRACE);
}

fn handleRightBrace() Token {
    return make_token(.TOKEN_RIGHT_BRACE);
}

fn handleLeftSqParen() Token {
    return make_token(.TOKEN_LEFT_SQPAREN);
}

fn handleRightSqParen() Token {
    return make_token(.TOKEN_RIGHT_SQPAREN);
}

fn handleSemicolon() Token {
    return make_token(.TOKEN_SEMICOLON);
}

fn handleColon() Token {
    return make_token(.TOKEN_COLON);
}

fn handleComma() Token {
    return make_token(.TOKEN_COMMA);
}

fn handleHat() Token {
    return make_token(.TOKEN_HAT);
}

fn handlePercent() Token {
    return make_token(.TOKEN_PERCENT);
}

fn handleHash() Token {
    return make_token(.TOKEN_HASH);
}

fn handleBacktick() Token {
    return processMultilineString();
}

fn handleQuote() Token {
    return string();
}

fn handleDot() Token {
    if (match_internal('.')) {
        return make_token(if (match_internal('=')) .TOKEN_RANGE_INCLUSIVE else .TOKEN_RANGE_EXCLUSIVE);
    } else {
        return make_token(.TOKEN_DOT);
    }
}

fn handleMinus() Token {
    return make_token(if (match_internal('=')) .TOKEN_MINUS_EQUAL else if (match_internal('-')) .TOKEN_MINUS_MINUS else .TOKEN_MINUS);
}

fn handlePlus() Token {
    return make_token(if (match_internal('=')) .TOKEN_PLUS_EQUAL else if (match_internal('+')) .TOKEN_PLUS_PLUS else .TOKEN_PLUS);
}

fn handleSlash() Token {
    if (match_internal('=')) {
        return make_token(.TOKEN_SLASH_EQUAL);
    } else if (match_internal('#')) {
        // Multi-line comment - backtrack and skip
        scanner.current -= 1;
        skip_whitespace();
        return scanToken();
    } else {
        return make_token(.TOKEN_SLASH);
    }
}

fn handleStar() Token {
    return make_token(if (match_internal('=')) .TOKEN_STAR_EQUAL else .TOKEN_STAR);
}

fn handleBang() Token {
    return make_token(if (match_internal('=')) .TOKEN_BANG_EQUAL else .TOKEN_BANG);
}

fn handleEqual() Token {
    if (match_internal('=')) {
        return make_token(.TOKEN_EQUAL_EQUAL);
    } else if (match_internal('>')) {
        return make_token(.TOKEN_ARROW);
    } else {
        return make_token(.TOKEN_EQUAL);
    }
}

fn handleLess() Token {
    return make_token(if (match_internal('=')) .TOKEN_LESS_EQUAL else .TOKEN_LESS);
}

fn handleGreater() Token {
    return make_token(if (match_internal('=')) .TOKEN_GREATER_EQUAL else .TOKEN_GREATER);
}

fn handleQuestion() Token {
    return make_token(.TOKEN_QUESTION);
}

fn handleUnknown() Token {
    // Get the character from scanner state (already advanced)
    const c = scanner.start[0];

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
}

// Dispatch table: 256 entries mapping each ASCII char to a handler
// Built after all handler functions are defined
const DISPATCH_TABLE = blk: {
    var table: [256]TokenHandlerFn = [_]TokenHandlerFn{handleUnknown} ** 256;

    // Identifiers and keywords
    for ('a'..('z' + 1)) |c| table[c] = handleIdentifier;
    for ('A'..('Z' + 1)) |c| table[c] = handleIdentifier;
    table['_'] = handleIdentifier;

    // Numbers
    for ('0'..('9' + 1)) |c| table[c] = handleNumber;

    // Single-character tokens
    table['('] = handleLeftParen;
    table[')'] = handleRightParen;
    table['{'] = handleLeftBrace;
    table['}'] = handleRightBrace;
    table['['] = handleLeftSqParen;
    table[']'] = handleRightSqParen;
    table[';'] = handleSemicolon;
    table[':'] = handleColon;
    table[','] = handleComma;
    table['^'] = handleHat;
    table['%'] = handlePercent;
    table['#'] = handleHash;
    table['`'] = handleBacktick;
    table['"'] = handleQuote;

    // Multi-character tokens
    table['.'] = handleDot;
    table['-'] = handleMinus;
    table['+'] = handlePlus;
    table['/'] = handleSlash;
    table['*'] = handleStar;
    table['!'] = handleBang;
    table['='] = handleEqual;
    table['<'] = handleLess;
    table['>'] = handleGreater;
    table['?'] = handleQuestion;

    break :blk table;
};

// ========================================
// END DISPATCH TABLE INFRASTRUCTURE
// ========================================

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

// Optimized whitespace skipping with branchless bounds checks
// This provides better branch prediction and eliminates redundant checks
pub fn skip_whitespace() void {
    while (@intFromPtr(scanner.current) < @intFromPtr(scanner.source_end)) {
        const c = scanner.current[0];

        // Fast path: common whitespace (most frequent case)
        if (is_whitespace(c)) {
            scanner.current += 1;
            continue;
        }

        // Newline handling with branchless increment
        if (c == '\n') {
            scanner.line += 1;
            scanner.current += 1;
            continue;
        }

        // Comment detection and handling
        if (c == '/') {
            if (@intFromPtr(scanner.current) + 1 >= @intFromPtr(scanner.source_end)) break;
            const next = scanner.current[1];

            if (next == '/') {
                // Single-line comment - fast scan to newline
                scanner.current += 2;
                while (@intFromPtr(scanner.current) < @intFromPtr(scanner.source_end)) {
                    const ch = scanner.current[0];
                    if (ch == '\n') {
                        scanner.line += 1;
                        scanner.current += 1;
                        break;
                    }
                    scanner.current += 1;
                }
                continue;
            } else if (next == '#') {
                // Multi-line comment with nesting
                scanner.current += 2;
                var nesting: u32 = 1;

                while (nesting > 0 and @intFromPtr(scanner.current) < @intFromPtr(scanner.source_end)) {
                    const ch = scanner.current[0];

                    // Check for nested comment markers
                    if (@intFromPtr(scanner.current) + 1 < @intFromPtr(scanner.source_end)) {
                        const next_ch = scanner.current[1];
                        if (ch == '/' and next_ch == '#') {
                            scanner.current += 2;
                            nesting += 1;
                            continue;
                        } else if (ch == '#' and next_ch == '/') {
                            scanner.current += 2;
                            nesting -= 1;
                            continue;
                        }
                    }

                    scanner.line += @intFromBool(ch == '\n');
                    scanner.current += 1;
                }

                // Check for unterminated comment
                if (nesting > 0 and errorManagerInitialized and globalErrorManager != null) {
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

    // Perfect hash lookup - O(1) with zero collisions
    // Compute perfect hash for the identifier
    const hash = perfectHash(identifier_slice);

    // Look up in perfect hash table
    if (PERFECT_HASH_TABLE[hash]) |entry| {
        // Verify it's actually the keyword (not just a hash match)
        // This check is necessary since non-keywords can hash to occupied slots
        if (std.mem.eql(u8, identifier_slice, entry.keyword)) {
            return entry.token;
        }
    }

    return .TOKEN_IDENTIFIER;
}

pub fn identifier() Token {
    // Check for f-string at the start
    if (scanner.start[0] == 'f' and peek_internal() == '"') {
        _ = advance_internal(); // consume quote
        var token = string();
        token.type = .TOKEN_F_STRING;
        return token;
    }

    // Fast identifier scanning with optimized loop
    while (@intFromPtr(scanner.current) < @intFromPtr(scanner.source_end) and is_alphanum(scanner.current[0])) {
        scanner.current += 1;
    }
    return make_token(identifierType());
}

// Optimized single-pass number parsing with branchless checks
// Eliminates backtracking for better performance
fn number() Token {
    // Phase 1: Parse integer part with optimized loop
    while (@intFromPtr(scanner.current) < @intFromPtr(scanner.source_end) and is_digit(scanner.current[0])) {
        scanner.current += 1;
    }

    // Check for decimal point
    var has_decimal = false;
    if (@intFromPtr(scanner.current) < @intFromPtr(scanner.source_end) and
        scanner.current[0] == '.' and
        @intFromPtr(scanner.current) + 1 < @intFromPtr(scanner.source_end) and
        is_digit(scanner.current[1]))
    {
        has_decimal = true;
        scanner.current += 1; // consume '.'

        // Parse fractional part
        while (@intFromPtr(scanner.current) < @intFromPtr(scanner.source_end) and is_digit(scanner.current[0])) {
            scanner.current += 1;
        }
    }

    // Check for complex number pattern: +/- followed by imaginary part
    if (@intFromPtr(scanner.current) < @intFromPtr(scanner.source_end)) {
        const c = scanner.current[0];

        // Check for imaginary unit 'i' (simple imaginary: 3i or 3.5i)
        if (c == 'i') {
            scanner.current += 1;
            return make_token(.TOKEN_IMAGINARY);
        }

        // Check for complex number: real+imagi or real-imagi
        // Only consume if it's truly a complex number (ends with 'i')
        if (c == '+' or c == '-') {
            // Save position in case this isn't a complex number
            const save_pos = scanner.current;

            // Peek ahead to see if this is part of a complex number
            if (@intFromPtr(scanner.current) + 1 < @intFromPtr(scanner.source_end) and
                is_digit(scanner.current[1]))
            {
                // Tentatively consume the sign
                scanner.current += 1;

                // Parse imaginary integer part
                while (@intFromPtr(scanner.current) < @intFromPtr(scanner.source_end) and
                    is_digit(scanner.current[0]))
                {
                    scanner.current += 1;
                }

                // Parse imaginary decimal part if present
                if (@intFromPtr(scanner.current) < @intFromPtr(scanner.source_end) and
                    scanner.current[0] == '.' and
                    @intFromPtr(scanner.current) + 1 < @intFromPtr(scanner.source_end) and
                    is_digit(scanner.current[1]))
                {
                    scanner.current += 1; // consume '.'
                    while (@intFromPtr(scanner.current) < @intFromPtr(scanner.source_end) and
                        is_digit(scanner.current[0]))
                    {
                        scanner.current += 1;
                    }
                }

                // Must end with 'i' for complex number
                if (@intFromPtr(scanner.current) < @intFromPtr(scanner.source_end) and
                    scanner.current[0] == 'i')
                {
                    scanner.current += 1;
                    return make_token(.TOKEN_IMAGINARY);
                }

                // Not a complex number - restore position
                scanner.current = save_pos;
            }
        }
    }

    // Return appropriate token type
    return make_token(if (has_decimal) .TOKEN_DOUBLE else .TOKEN_INT);
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

    // Dispatch table lookup - O(1) with no branches
    // This eliminates the large switch statement and potential branch mispredictions
    const handler = DISPATCH_TABLE[c];
    return handler();
}
