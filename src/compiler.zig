/// MufiZ Compiler Module
/// This module implements the bytecode compiler for the MufiZ language.
/// It handles parsing, semantic analysis, and bytecode generation.
/// The compiler uses a single-pass approach with recursive descent parsing.
const std = @import("std");
const print = std.debug.print;

const debug_opts = @import("debug");

const chunk_h = @import("chunk.zig");
const Chunk = chunk_h.Chunk;
const OpCode = chunk_h.OpCode;
const debug_h = @import("debug.zig");
const errors = @import("errors.zig");
const mem_utils = @import("mem_utils.zig");
const allocator_mod = @import("allocator.zig");
const compiler_arena = @import("compiler_arena.zig");
const memcmp = mem_utils.memcmp;
const object_h = @import("object.zig");
const ObjFunction = object_h.ObjFunction;
const scanner_h = @import("scanner_optimized.zig");
const Token = scanner_h.Token;
const TokenType = scanner_h.TokenType;
const value_h = @import("value.zig");
const Value = value_h.Value;
const Complex = value_h.Complex;
const vm_h = @import("vm.zig");
const bytecode_optimizer = @import("bytecode_optimizer.zig");
const type_system = @import("type_system.zig");
const type_checker = @import("type_checker.zig");
const type_annotations = @import("type_annotations.zig");

/// Helper to create a Value wrapping a string object (uses copyString — for runtime/dynamic strings).
fn makeStringValue(start: [*]const u8, length: usize) Value {
    return Value.init_obj(@ptrCast(object_h.copyString(start, @intCast(length))));
}

/// Helper to create a Value wrapping a string literal object (uses copyStringLiteral — for compile-time known strings).
fn makeStringLiteralValue(start: [*]const u8, length: usize) Value {
    return Value.init_obj(@ptrCast(object_h.copyStringLiteral(start, @intCast(length))));
}

// Global error manager and variable tracking
pub var globalErrorManager: errors.ErrorManager = undefined;
var knownVariables: std.ArrayList([]const u8) = undefined;
pub var errorManagerInitialized: bool = false;

// Track all declared variables for suggestion system
pub fn addKnownVariable(name: []const u8) void {
    _ = name;
    // Variable tracking disabled to avoid memory management issues in REPL
    // The suggestion system will work without prior variable tracking
}

pub fn findSimilarVariables(name: []const u8, allocator: std.mem.Allocator) []const []const u8 {
    _ = name;
    _ = allocator;
    if (!errorManagerInitialized) return &[_][]const u8{};

    // Simplified implementation - just return empty for now
    return &[_][]const u8{};
}

// Function to populate known variables from VM's global table
pub fn populateKnownVariablesFromGlobals() void {
    if (!errorManagerInitialized) return;

    const vm_module = @import("vm.zig");
    const iterator = vm_module.vm.globals.entries;
    var i: usize = 0;

    while (i < vm_module.vm.globals.capacity) : (i += 1) {
        if (iterator.?[i].key != null) {
            const objString = iterator.?[i].key.?;
            const varName = objString.chars[0..@intCast(objString.length)];
            addKnownVariable(varName);
        }
    }
}

// Function to set scanner error manager pointer
pub fn setScannerErrorManager() void {
    scanner_h.globalErrorManager = &globalErrorManager;
    scanner_h.errorManagerInitialized = errorManagerInitialized;
}

/// Tracks global variable assignment counts for optimization
const GlobalAnalyzer = struct {
    counts: std.AutoHashMap(u64, u32),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) GlobalAnalyzer {
        return .{
            .counts = std.AutoHashMap(u64, u32).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *GlobalAnalyzer) void {
        self.counts.deinit();
    }

    pub fn recordAssignment(self: *GlobalAnalyzer, name: []const u8) void {
        const h = object_h.hashString(name.ptr, name.len);
        const entry = self.counts.getOrPut(h) catch return;
        if (!entry.found_existing) {
            entry.value_ptr.* = 1;
        } else {
            entry.value_ptr.* += 1;
        }
    }

    pub fn isConstant(self: *GlobalAnalyzer, name: []const u8) bool {
        const h = object_h.hashString(name.ptr, name.len);
        const count = self.counts.get(h) orelse 0;
        return count <= 1; // Assigned once (definition) or never
    }
};

var global_analyzer: ?GlobalAnalyzer = null;

pub const Parser = struct {
    current: Token,
    previous: Token,
    hadError: bool,
    panicMode: bool,
    currentFile: ?[]const u8 = null,
};

pub const PREC_NONE: i32 = 0;
pub const PREC_ASSIGNMENT: i32 = 1;
pub const PREC_TERNARY: i32 = 2;
pub const PREC_OR: i32 = 3;
pub const PREC_AND: i32 = 4;
pub const PREC_BIT_OR: i32 = 5; // bitwise OR
pub const PREC_BIT_XOR: i32 = 6; // bitwise XOR
pub const PREC_BIT_AND: i32 = 7; // bitwise AND
pub const PREC_EQUALITY: i32 = 8;
pub const PREC_COMPARISON: i32 = 9;
pub const PREC_SHIFT: i32 = 10; // bit shifts
pub const PREC_TERM: i32 = 11;
pub const PREC_RANGE: i32 = 12; // Between PREC_TERM and PREC_FACTOR
pub const PREC_FACTOR: i32 = 13;
pub const PREC_EXPONENT: i32 = 14;
pub const PREC_UNARY: i32 = 15;
pub const PREC_CALL: i32 = 16;
pub const PREC_INDEX: i32 = 17;
pub const PREC_PRIMARY: i32 = 18;
pub const Precedence = u32;

pub const ParseFn = ?*const fn (bool) void;
pub const ParseRule = struct {
    prefix: ParseFn = null,
    infix: ParseFn = null,
    precedence: Precedence,
};
pub const Local = struct {
    name: Token,
    depth: i32,
    isCaptured: bool,
    isConst: bool = false,
};
pub const Upvalue = struct {
    index: u8,
    isLocal: bool,
};

pub const FunctionType = enum(i32) {
    TYPE_FUNCTION = 0,
    TYPE_METHOD = 1,
    TYPE_INITIALIZER = 2,
    TYPE_SCRIPT = 3,
};

pub const ClassCompiler = struct {
    enclosing: ?*ClassCompiler,
    hasSuperclass: bool,
};

pub const Loop = struct {
    enclosing: ?*Loop,
    start: i32,
    scopeDepth: i32,
    breakJumps: std.ArrayList(i32),
    continueJumps: std.ArrayList(i32),
    loopType: LoopType,

    pub const LoopType = enum {
        FOR,
        WHILE,
        FOREACH,
    };

    pub fn init(enclosing: ?*Loop, start: i32, scopeDepth: i32, loopType: LoopType) Loop {
        var loop = Loop{
            .enclosing = enclosing,
            .start = start,
            .scopeDepth = scopeDepth,
            .breakJumps = undefined,
            .continueJumps = undefined,
            .loopType = loopType,
        };
        const allocator = compiler_arena.getCompilerAllocator();
        loop.breakJumps = std.ArrayList(i32).initCapacity(allocator, 0) catch unreachable;
        loop.continueJumps = std.ArrayList(i32).initCapacity(allocator, 0) catch unreachable;
        return loop;
    }

    pub fn deinit(self: *Loop) void {
        // No need to manually deinit - arena will clean up automatically
        _ = self;
    }
};

pub const Compiler = struct {
    enclosing: ?*Compiler,
    function: *ObjFunction,
    type_: FunctionType,
    locals: [256]Local,
    localCount: i32,
    upvalues: [256]Upvalue,
    scopeDepth: i32,
    innermostLoop: ?*Loop,
};

pub var parser: Parser = undefined;
pub var current: ?*Compiler = null;
pub var currentClass: ?*ClassCompiler = null;

pub fn currentChunk() *Chunk {
    return &current.?.function.*.chunk;
}

/// Calculate the column position of a token by finding the start of its line
fn calculateTokenColumn(token: *Token, source_start: [*]const u8) u32 {
    if (@intFromPtr(token.start) < @intFromPtr(source_start)) return 1; // Safety check

    // Walk backwards from token start to find the beginning of the line
    var pos: [*]const u8 = token.start;
    var column: u32 = 1;

    // Walk backwards until we hit the start of source or a newline
    while (@intFromPtr(pos) > @intFromPtr(source_start)) {
        pos -= 1;
        if (pos[0] == '\n') {
            break;
        }
        column += 1;
    }

    // If we hit a newline, the column is the distance from newline + 1
    if (@intFromPtr(pos) > @intFromPtr(source_start) and pos[0] == '\n') {
        column = @intCast(@intFromPtr(token.start) - @intFromPtr(pos));
    }

    return if (column == 0) 1 else column;
}
pub fn errorAt(token: *Token, message: [*]const u8) void {
    if (parser.panicMode) return;

    // Convert the C-style string to a Zig-style string slice
    var i: usize = 0;
    while (message[i] != 0) : (i += 1) {}
    const msg = message[0..i];

    // Create error info with enhanced details
    var errorInfo = errors.ErrorInfo{
        .code = .UNEXPECTED_TOKEN,
        .category = .SYNTAX,
        .severity = .ERROR,
        .line = @intCast(@as(u32, @bitCast(token.*.line))),
        .column = calculateTokenColumn(token, scanner_h.getSourceStart()),
        .length = @intCast(@as(u32, @bitCast(token.*.length))),
        .message = msg,
        .suggestions = &[_]errors.ErrorSuggestion{},
        .file_path = parser.currentFile,
    };

    // Add context-specific suggestions based on token type
    if (token.*.type == .TOKEN_EOF) {
        errorInfo.suggestions = &[_]errors.ErrorSuggestion{
            .{ .message = "Add the missing token before the end of file" },
            .{ .message = "Check for unclosed brackets, braces, or parentheses" },
        };
    } else if (token.*.type == .TOKEN_ERROR) {
        errorInfo.suggestions = &[_]errors.ErrorSuggestion{
            .{ .message = "Check for invalid characters or malformed tokens" },
        };
    }

    if (errorManagerInitialized) {
        globalErrorManager.reportError(errorInfo);
    } else {
        // Fallback to old behavior if error manager not initialized
        print("[line {d}] Error: {s}\n", .{ token.*.line, msg });
    }
    parser.hadError = true;
}

pub fn @"error"(message: [*]const u8) void {
    errorAt(&parser.previous, message);
}

pub fn errorAtCurrent(message: [*]const u8) void {
    errorAt(&parser.current, message);
}

pub fn errorWithSuggestions(token: *Token, errorCode: errors.ErrorCode, message: []const u8, suggestions: []const errors.ErrorSuggestion) void {
    if (parser.panicMode) return;

    const errorInfo = errors.ErrorInfo{
        .code = errorCode,
        .category = switch (errorCode) {
            .UNEXPECTED_TOKEN, .UNTERMINATED_STRING, .INVALID_CHARACTER => .SYNTAX,
            .UNDEFINED_VARIABLE, .REDEFINED_VARIABLE, .WRONG_ARGUMENT_COUNT => .SEMANTIC,
            .STACK_OVERFLOW, .INDEX_OUT_OF_BOUNDS => .RUNTIME,
            .TYPE_MISMATCH, .INVALID_CAST => .TYPE,
            .TOO_MANY_CONSTANTS, .TOO_MANY_LOCALS => .MEMORY,
            else => .SYNTAX,
        },
        .severity = .ERROR,
        .line = @intCast(@as(u32, @bitCast(token.*.line))),
        .column = 1,
        .length = @intCast(@as(u32, @bitCast(token.*.length))),
        .message = message,
        .suggestions = suggestions,
        .file_path = parser.currentFile,
    };

    if (errorManagerInitialized) {
        globalErrorManager.reportError(errorInfo);
    } else {
        print("[line {d}] Error: {s}\n", .{ token.*.line, message });
    }
    parser.hadError = true;
}

pub fn advance() void {
    parser.previous = parser.current;
    while (true) {
        parser.current = scanner_h.scanToken();
        if (parser.current.type != .TOKEN_ERROR) break;
        errorAtCurrent(parser.current.start);
    }
}
pub fn consume(type_: TokenType, message: [*]const u8) void {
    if (parser.current.type == type_) {
        advance();
        return;
    }
    errorAtCurrent(message);
}
pub fn check(type_: TokenType) bool {
    return parser.current.type == type_;
}
pub fn match(type_: TokenType) bool {
    if (!check(type_)) return false;
    advance();
    return true;
}
pub fn emitByte(byte: u8) void {
    chunk_h.writeChunk(currentChunk(), byte, parser.previous.line);
}
pub fn emitBytes(byte1: u8, byte2: u8) void {
    emitByte(byte1);
    emitByte(byte2);
}

/// Emit a global slot instruction with support for slots > 255
pub fn emitGlobalSlot(op: u8, slot: u32) void {
    if (slot > 127) {
        // Use 2-byte encoding: high bit set + upper 8 bits, then lower 8 bits
        emitBytes(op, @as(u8, @intCast((slot >> 8) | 0x80)));
        emitByte(@as(u8, @intCast(slot & 0xFF)));
    } else {
        emitBytes(op, @as(u8, @intCast(slot)));
    }
}

pub fn emitLoop(loopStart: i32) void {
    emitByte(@intFromEnum(OpCode.OP_LOOP));
    const offset: i32 = (currentChunk().*.count - loopStart) + 2;

    if (offset > 65535) {
        const suggestions = [_]errors.ErrorSuggestion{
            .{ .message = "Break the loop body into smaller funs" },
            .{ .message = "Consider restructuring the loop logic" },
            .{ .message = "Maximum loop body size is 65535 bytes" },
        };
        errorWithSuggestions(&parser.previous, .LOOP_TOO_LARGE, "Loop body too large (maximum 65535 bytes)", &suggestions);
    }
    emitByte(@intCast((offset >> 8) & 255));
    emitByte(@intCast(offset & 255));
}

pub fn emitJump(instruction: u8) i32 {
    emitByte(instruction);
    emitByte(255);
    emitByte(255);
    return currentChunk().*.count - 2;
}
pub fn emitReturn() void {
    if (current.?.type_ == .TYPE_INITIALIZER) {
        emitBytes(@intFromEnum(OpCode.OP_GET_LOCAL), 0);
    } else {
        emitByte(@intFromEnum(OpCode.OP_NIL));
    }
    emitByte(@intFromEnum(OpCode.OP_RETURN));
}
pub fn makeConstant(value: Value) u8 {
    const constant: i32 = chunk_h.addConstant(currentChunk(), value);
    if (constant > 255) {
        const suggestions = [_]errors.ErrorSuggestion{
            .{ .message = "Break large funs into smaller ones" },
            .{ .message = "Reduce the number of literal values in this fun" },
            .{ .message = "Consider using variables for repeated constant values" },
        };
        errorWithSuggestions(&parser.previous, .TOO_MANY_CONSTANTS, "Too many constants in one chunk (maximum 256)", &suggestions);
        return 0;
    }
    return @intCast(constant);
}
pub fn emitConstant(value: Value) void {
    emitBytes(@intFromEnum(OpCode.OP_CONSTANT), makeConstant(value));
}

pub fn emitSymbolVariable(global: u8) void {
    emitBytes(@intFromEnum(OpCode.OP_SYMBOL), global);
}

pub fn patchJump(offset: i32) void {
    const jump: i32 = (currentChunk().*.count - offset) - 2;
    if (jump > 65535) {
        const suggestions = [_]errors.ErrorSuggestion{
            .{ .message = "Break large code blocks into smaller funs" },
            .{ .message = "Restructure conditional logic to reduce jump distances" },
            .{ .message = "Maximum jump distance is 65535 bytes" },
        };
        errorWithSuggestions(&parser.previous, .JUMP_TOO_LARGE, "Too much code to jump over (maximum 65535 bytes)", &suggestions);
    }

    if (currentChunk().*.code) |code| {
        code[@intCast(offset)] = @intCast((jump >> 8) & 255);
        code[@intCast(offset + 1)] = @intCast(jump & 255);
    }
}
pub fn initCompiler(compiler: *Compiler, type_: FunctionType) void {
    compiler.*.enclosing = current;
    compiler.*.type_ = type_;
    compiler.*.localCount = 0;
    compiler.*.scopeDepth = 0;
    compiler.*.function = object_h.newFunction();
    compiler.*.innermostLoop = null;

    // Inherit source file from enclosing function
    if (current) |enclosing| {
        compiler.*.function.*.source_file = enclosing.function.*.source_file;
    }

    current = compiler;

    // Set function name if not a script
    if (type_ != .TYPE_SCRIPT) {
        current.?.function.*.name = object_h.copyStringLiteral(parser.previous.start, @intCast(parser.previous.length));
    }

    // Create first local slot - used for 'self' in methods
    const local: *Local = &current.?.locals[0];
    current.?.localCount = 1;

    if (type_ == .TYPE_METHOD or type_ == .TYPE_INITIALIZER) {
        // For methods, initialize first local as 'self'
        local.*.name.start = @ptrCast(@constCast("self"));
        local.*.name.length = 4;
        local.*.depth = compiler.*.scopeDepth; // Mark as initialized immediately
        local.*.isCaptured = false;
    } else {
        // For functions and scripts, leave first local slot empty
        local.*.name.start = @ptrCast(@constCast(""));
        local.*.name.length = 0;
        local.*.depth = 0;
        local.*.isCaptured = false;
    }
}

pub fn endCompiler() *ObjFunction {
    emitReturn();
    const function_1: *ObjFunction = current.?.function;

    if (debug_opts.print_code) {
        if (!parser.hadError) {
            const name: [*]u8 = if (function_1.*.name != null) @ptrCast(function_1.*.name.?.chars.ptr) else @ptrCast(@constCast("<script>"));
            debug_h.disassembleChunk(currentChunk(), name);
        }
    }

    current = current.?.enclosing;
    return function_1;
}
pub fn beginScope() void {
    current.?.scopeDepth += 1;
}
pub fn endScope() void {
    current.?.scopeDepth -= 1;
    while ((current.?.localCount > 0) and (current.?.locals[@as(c_uint, @intCast(current.?.localCount - 1))].depth > current.?.scopeDepth)) {
        if (current.?.locals[@as(c_uint, @intCast(current.?.localCount - 1))].isCaptured) {
            emitByte(@intFromEnum(OpCode.OP_CLOSE_UPVALUE));
        } else {
            emitByte(@intFromEnum(OpCode.OP_POP));
        }
        current.?.localCount -= 1;
    }
}
pub fn expression() void {
    parsePrecedence(PREC_ASSIGNMENT);
}
pub fn statement() void {
    switch (parser.current.type) {
        .TOKEN_PRINT => {
            advance();
            printStatement();
        },
        .TOKEN_FOR => {
            advance();
            forStatement();
        },
        .TOKEN_FOREACH => {
            advance();
            foreachStatement();
        },
        .TOKEN_IF => {
            advance();
            ifStatement();
        },
        .TOKEN_RETURN => {
            advance();
            returnStatement();
        },
        .TOKEN_BREAK => {
            advance();
            breakStatement();
        },
        .TOKEN_CONTINUE => {
            advance();
            continueStatement();
        },
        .TOKEN_SWITCH => {
            advance();
            switchStatement();
        },
        .TOKEN_WHILE => {
            advance();
            whileStatement();
        },
        .TOKEN_LEFT_BRACE => {
            advance();
            beginScope();
            block();
            endScope();
        },
        else => expressionStatement(),
    }
}
pub fn declaration() void {
    if (match(.TOKEN_PUB)) {
        pubDeclaration();
    } else if (match(.TOKEN_CLASS)) {
        classDeclaration();
    } else if (match(.TOKEN_FUN)) {
        funDeclaration();
    } else if (match(.TOKEN_VAR)) {
        varDeclaration();
    } else if (match(.TOKEN_SYM)) {
        symDeclaration();
    } else if (match(.TOKEN_CONST)) {
        constDeclaration();
    } else if (match(.TOKEN_IMPORT)) {
        importStatement();
    } else if (match(.TOKEN_FROM)) {
        fromImportStatement();
    } else {
        statement();
    }
    if (parser.panicMode) {
        synchronize();
    }
}
pub fn getRule(type_: TokenType) ParseRule {
    return switch (type_) {
        // Single character tokens
        .TOKEN_LEFT_PAREN => ParseRule{ .prefix = &grouping, .infix = &call, .precedence = PREC_CALL },
        .TOKEN_RIGHT_PAREN => ParseRule{ .precedence = PREC_NONE },
        .TOKEN_LEFT_BRACE => ParseRule{ .prefix = &objectLiteral, .precedence = PREC_NONE },
        .TOKEN_RIGHT_BRACE => ParseRule{ .precedence = PREC_NONE },
        .TOKEN_HASH => ParseRule{ .prefix = &hashTable, .precedence = PREC_NONE },
        .TOKEN_COMMA => ParseRule{ .precedence = PREC_NONE },
        .TOKEN_DOT => ParseRule{ .prefix = &item_, .infix = &dot, .precedence = PREC_CALL },
        .TOKEN_MINUS => ParseRule{ .prefix = &unary, .infix = &binary, .precedence = PREC_TERM },
        .TOKEN_PLUS => ParseRule{ .infix = &binary, .precedence = PREC_TERM },
        .TOKEN_SEMICOLON => ParseRule{ .precedence = PREC_NONE },
        .TOKEN_SLASH => ParseRule{ .infix = &binary, .precedence = PREC_FACTOR },
        .TOKEN_STAR => ParseRule{ .infix = &binary, .precedence = PREC_FACTOR },
        .TOKEN_HAT => ParseRule{ .infix = &binary, .precedence = PREC_EXPONENT },
        .TOKEN_LEFT_SQPAREN => ParseRule{ .prefix = &fvector, .infix = &index_, .precedence = PREC_CALL },
        .TOKEN_RIGHT_SQPAREN => ParseRule{ .precedence = PREC_NONE },
        .TOKEN_COLON => ParseRule{ .precedence = PREC_NONE },
        .TOKEN_RANGE_EXCLUSIVE => ParseRule{ .infix = &rangeExclusive, .precedence = PREC_RANGE },
        .TOKEN_RANGE_INCLUSIVE => ParseRule{ .infix = &rangeInclusive, .precedence = PREC_RANGE },
        .TOKEN_PERCENT => ParseRule{ .infix = &binary, .precedence = PREC_FACTOR },
        // One or more character tokens
        .TOKEN_BANG => ParseRule{ .prefix = &unary, .precedence = PREC_NONE },
        .TOKEN_BANG_EQUAL => ParseRule{ .infix = &binary, .precedence = PREC_EQUALITY },
        .TOKEN_EQUAL => ParseRule{ .precedence = PREC_NONE },
        .TOKEN_EQUAL_EQUAL => ParseRule{ .infix = &binary, .precedence = PREC_EQUALITY },
        .TOKEN_GREATER => ParseRule{ .infix = &binary, .precedence = PREC_COMPARISON },
        .TOKEN_GREATER_EQUAL => ParseRule{ .infix = &binary, .precedence = PREC_COMPARISON },
        .TOKEN_LESS => ParseRule{ .infix = &binary, .precedence = PREC_COMPARISON },
        .TOKEN_LESS_EQUAL => ParseRule{ .infix = &binary, .precedence = PREC_COMPARISON },
        .TOKEN_PLUS_EQUAL => ParseRule{ .precedence = PREC_NONE },
        .TOKEN_MINUS_EQUAL => ParseRule{ .precedence = PREC_NONE },
        .TOKEN_STAR_EQUAL => ParseRule{ .precedence = PREC_NONE },
        .TOKEN_SLASH_EQUAL => ParseRule{ .precedence = PREC_NONE },
        .TOKEN_PLUS_PLUS => ParseRule{ .precedence = PREC_CALL },
        .TOKEN_MINUS_MINUS => ParseRule{ .precedence = PREC_CALL },
        // Literals
        .TOKEN_IDENTIFIER => ParseRule{ .prefix = &variable, .precedence = PREC_NONE },
        .TOKEN_SWITCH => ParseRule{ .precedence = PREC_NONE },
        .TOKEN_CASE => ParseRule{ .precedence = PREC_NONE },
        .TOKEN_BREAK => ParseRule{ .precedence = PREC_NONE },
        .TOKEN_STRING => ParseRule{ .prefix = &string, .precedence = PREC_NONE },
        .TOKEN_MULTILINE_STRING => ParseRule{ .prefix = &string, .precedence = PREC_NONE },
        .TOKEN_BACKTICK_STRING => ParseRule{ .prefix = &string, .precedence = PREC_NONE },
        .TOKEN_F_STRING => ParseRule{ .prefix = &fstring, .precedence = PREC_NONE },
        .TOKEN_DOUBLE => ParseRule{ .prefix = &number, .precedence = PREC_NONE },
        .TOKEN_INT => ParseRule{ .prefix = &number, .precedence = PREC_NONE },
        .TOKEN_IMAGINARY => ParseRule{ .prefix = &imaginary_number, .precedence = PREC_NONE },
        // Keywords
        .TOKEN_AND => ParseRule{ .infix = &and_, .precedence = PREC_AND },
        .TOKEN_CLASS => ParseRule{ .precedence = PREC_NONE },
        .TOKEN_ELSE => ParseRule{ .precedence = PREC_NONE },
        .TOKEN_FALSE => ParseRule{ .prefix = &literal, .precedence = PREC_NONE },
        .TOKEN_FOR => ParseRule{ .precedence = PREC_NONE },
        .TOKEN_EACH => ParseRule{ .precedence = PREC_NONE },
        .TOKEN_FUN => ParseRule{ .precedence = PREC_NONE },
        .TOKEN_IF => ParseRule{ .precedence = PREC_NONE },
        .TOKEN_NIL => ParseRule{ .prefix = &literal, .precedence = PREC_NONE },
        .TOKEN_OR => ParseRule{ .infix = &or_, .precedence = PREC_OR },
        .TOKEN_QUESTION => ParseRule{ .infix = &ternary, .precedence = PREC_TERNARY },
        .TOKEN_PRINT => ParseRule{ .precedence = PREC_NONE },
        .TOKEN_RETURN => ParseRule{ .precedence = PREC_NONE },
        .TOKEN_SELF => ParseRule{ .prefix = &self_, .precedence = PREC_NONE },
        .TOKEN_SUPER => ParseRule{ .prefix = &super_, .precedence = PREC_NONE },
        .TOKEN_TRUE => ParseRule{ .prefix = &literal, .precedence = PREC_NONE },
        .TOKEN_VAR => ParseRule{ .precedence = PREC_NONE },
        .TOKEN_WHILE => ParseRule{ .precedence = PREC_NONE },
        .TOKEN_ITEM => ParseRule{ .precedence = PREC_NONE },
        .TOKEN_FOREACH => ParseRule{ .precedence = PREC_NONE },
        .TOKEN_IN => ParseRule{ .precedence = PREC_NONE },
        .TOKEN_END => ParseRule{ .precedence = PREC_NONE },
        .TOKEN_CONST => ParseRule{ .precedence = PREC_NONE },
        .TOKEN_ARROW => ParseRule{ .infix = &pair, .precedence = PREC_TERM },
        // Import tokens
        .TOKEN_IMPORT => ParseRule{ .precedence = PREC_NONE },
        .TOKEN_FROM => ParseRule{ .precedence = PREC_NONE },
        .TOKEN_AS => ParseRule{ .precedence = PREC_NONE },
        // Visibility tokens
        .TOKEN_PUB => ParseRule{ .precedence = PREC_NONE },
        // Bitwise operators
        .TOKEN_BAND => ParseRule{ .infix = &binary, .precedence = PREC_BIT_AND },
        .TOKEN_BOR => ParseRule{ .infix = &binary, .precedence = PREC_BIT_OR },
        .TOKEN_BXOR => ParseRule{ .infix = &binary, .precedence = PREC_BIT_XOR },
        .TOKEN_BNOT => ParseRule{ .prefix = &unary, .precedence = PREC_NONE },
        .TOKEN_SHL => ParseRule{ .infix = &binary, .precedence = PREC_SHIFT },
        .TOKEN_SHR => ParseRule{ .infix = &binary, .precedence = PREC_SHIFT },
        // Element-wise operators for matrices
        .TOKEN_STAR_DOT => ParseRule{ .infix = &binary, .precedence = PREC_FACTOR },
        .TOKEN_SLASH_DOT => ParseRule{ .infix = &binary, .precedence = PREC_FACTOR },
        .TOKEN_HAT_DOT => ParseRule{ .infix = &binary, .precedence = PREC_EXPONENT },
        // Symbolic variables - @x accesses existing symbolic variables
        .TOKEN_AT => ParseRule{ .prefix = &symbolVariable, .precedence = PREC_NONE },
        else => ParseRule{ .precedence = PREC_NONE },
    };
}

pub fn parsePrecedence(precedence: Precedence) void {
    advance();
    const prefixRule: ParseFn = getRule(parser.previous.type).prefix;

    if (prefixRule == null) {
        const suggestions = [_]errors.ErrorSuggestion{
            .{ .message = "Add a valid expression (variable, number, string, etc.)" },
            .{ .message = "Check for missing operands in arithmetic expressions" },
            .{ .message = "Add a valid expression", .example = "x + 1, \"hello\", myFun()" },
        };
        errorWithSuggestions(&parser.previous, .EXPECTED_EXPRESSION, "Expected expression", &suggestions);
        return;
    }
    const canAssign: bool = precedence <= PREC_ASSIGNMENT;
    prefixRule.?(canAssign);
    while (precedence <= getRule(parser.current.type).precedence) {
        advance();
        const infixRule: ParseFn = getRule(parser.previous.type).infix;
        infixRule.?(canAssign);
    }
    const isAssignment = check(.TOKEN_EQUAL) or check(.TOKEN_PLUS_EQUAL) or check(.TOKEN_MINUS_EQUAL) or check(.TOKEN_STAR_EQUAL) or check(.TOKEN_SLASH_EQUAL);
    if (canAssign and isAssignment) {
        advance();
        const suggestions = [_]errors.ErrorSuggestion{
            .{ .message = "You can only assign to variables and object properties" },
            .{ .message = "Check that the left side is a valid assignment target" },
            .{ .message = "Use valid assignment targets", .example = "variable = value, object.property = value" },
        };
        errorWithSuggestions(&parser.previous, .INVALID_ASSIGNMENT, "Invalid assignment target", &suggestions);
    }
}

pub fn identifierConstant(name: *Token) u8 {
    return makeConstant(makeStringLiteralValue(name.*.start, @intCast(name.*.length)));
}
pub fn identifiersEqual(a: *Token, b: *Token) bool {
    if (a.*.length != b.*.length) return false;
    return mem_utils.memcmp(@ptrCast(a.*.start), @ptrCast(b.*.start), @as(usize, @intCast(a.*.length))) == 0;
}
pub fn resolveLocal(compiler: *Compiler, name: *Token) i32 {
    var i: i32 = compiler.*.localCount - 1;
    while (i >= 0) : (i -= 1) {
        const local: *Local = &compiler.*.locals[@as(c_uint, @intCast(i))];
        if (identifiersEqual(name, &local.*.name)) {
            if (local.*.depth == -1) {
                const suggestions = [_]errors.ErrorSuggestion{
                    .{ .message = "Use a different variable name or initialize with a different value" },
                    .{ .message = "A variable cannot reference itself during initialization" },
                    .{ .message = "Initialize with a different value", .example = "var x = 5; // Not: var x = x + 1;" },
                };
                errorWithSuggestions(&parser.previous, .UNDEFINED_VARIABLE, "Cannot read local variable in its own initializer", &suggestions);
            }
            return i;
        }
    }

    return -1;
}

pub fn addUpvalue(compiler: *Compiler, index_1: u8, isLocal: bool) i32 {
    const upvalueCount: i32 = compiler.*.function.*.upvalueCount;

    for (0..@intCast(upvalueCount)) |i| {
        const upvalue: *Upvalue = &compiler.*.upvalues[@as(c_uint, @intCast(i))];

        if ((upvalue.*.index == index_1) and upvalue.*.isLocal) {
            return @intCast(i);
        }
    }

    if (upvalueCount == (255 + 1)) {
        const suggestions = [_]errors.ErrorSuggestion{
            .{ .message = "Reduce the number of captured variables from outer scopes" },
            .{ .message = "Pass values as parameters instead of capturing them" },
            .{ .message = "Maximum closure variables per fun is 256" },
        };
        errorWithSuggestions(&parser.previous, .TOO_MANY_LOCALS, "Too many closure variables in fun (maximum 256)", &suggestions);
        return 0;
    }
    compiler.*.upvalues[@intCast(upvalueCount)].isLocal = isLocal;
    compiler.*.upvalues[@intCast(upvalueCount)].index = index_1;
    return blk: {
        const ref = &compiler.*.function.*.upvalueCount;
        const tmp = ref.*;
        ref.* += 1;
        break :blk tmp;
    };
}
pub fn resolveUpvalue(compiler: *Compiler, name: *Token) i32 {
    if (compiler.*.enclosing == null) return -1;
    const local: i32 = resolveLocal(compiler.*.enclosing.?, name);
    if (local != -1) {
        compiler.*.enclosing.?.locals[@as(c_uint, @intCast(local))].isCaptured = true;
        return addUpvalue(compiler, @as(u8, @bitCast(@as(i8, @truncate(local)))), true);
    }
    const upvalue: i32 = resolveUpvalue(compiler.*.enclosing.?, name);
    if (upvalue != -1) {
        return addUpvalue(compiler, @as(u8, @bitCast(@as(i8, @truncate(upvalue)))), false);
    }
    return -1;
}
pub fn addLocal(name: Token) void {
    addLocalWithConst(name, false);
}

pub fn addConstLocal(name: Token) void {
    addLocalWithConst(name, true);
}

fn addLocalWithConst(name: Token, isConst: bool) void {
    if (current.?.localCount == (255 + 1)) {
        const errorInfo = errors.ErrorTemplates.tooManyLocals();
        if (errorManagerInitialized) {
            globalErrorManager.reportError(errorInfo);
        } else {
            print("Error: Too many local variables in function\n", .{});
        }
        parser.hadError = true;
        return;
    }
    const local: *Local = &current.?.locals[
        @intCast(blk: {
            const ref = &current.?.localCount;
            const tmp = ref.*;
            ref.* += 1;
            break :blk tmp;
        })
    ];
    local.*.name = name;
    local.*.depth = -1;
    local.*.isCaptured = false;
    local.*.isConst = isConst;

    // Track this variable for suggestion system
    const varName = name.start[0..@intCast(name.length)];
    addKnownVariable(varName);
}
fn declareVariableImpl(isConst: bool) void {
    if (current.?.scopeDepth == 0) return;
    const name: *Token = &parser.previous;
    const kind = if (isConst) "Constant" else "Variable";
    var i: i32 = current.?.localCount - 1;
    while (i >= 0) : (i -= 1) {
        const local: *Local = &current.?.locals[@as(c_uint, @intCast(i))];
        if ((local.*.depth != -1) and (local.*.depth < current.?.scopeDepth)) {
            break;
        }
        if (identifiersEqual(name, &local.*.name)) {
            const varName = name.start[0..@intCast(name.length)];
            const suggestions = [_]errors.ErrorSuggestion{
                .{ .message = if (isConst) "Use a different constant name" else "Use a different variable name" },
                .{ .message = if (isConst) "Constants in the same scope must have unique names" else "Variables in the same scope must have unique names" },
                .{ .message = "Try alternative names", .example = std.fmt.allocPrint(compiler_arena.getCompilerAllocator(), "{s}2, new{s}, {s}Value", .{ varName, varName, varName }) catch "newName, value2" },
            };
            errorWithSuggestions(&parser.previous, .REDEFINED_VARIABLE, std.fmt.allocPrint(compiler_arena.getCompilerAllocator(), "{s} '{s}' already declared in this scope", .{ kind, varName }) catch "Already declared in this scope", &suggestions);
            return;
        }
    }
    addLocalWithConst(name.*, isConst);
}

pub fn declareVariable() void {
    declareVariableImpl(false);
}

pub fn declareConstVariable() void {
    declareVariableImpl(true);
}

fn parseVariableImpl(message: [*]const u8, isConst: bool) u8 {
    consume(.TOKEN_IDENTIFIER, message);
    declareVariableImpl(isConst);
    if (current.?.scopeDepth > 0) return 0;
    return identifierConstant(&parser.previous);
}

pub fn parseVariable(message: [*]const u8) u8 {
    return parseVariableImpl(message, false);
}

pub fn parseConstVariable(message: [*]const u8) u8 {
    return parseVariableImpl(message, true);
}

pub fn markInitialized() void {
    if (current.?.scopeDepth == 0) return;
    current.?.locals[@as(c_uint, @intCast(current.?.localCount - 1))].depth = current.?.scopeDepth;
}

fn defineVariableImpl(global: u8, opcode: OpCode) void {
    if (current.?.scopeDepth > 0) {
        markInitialized();
        return;
    }

    // Track global variable/constant for suggestion system
    const constant = currentChunk().*.constants.values[@intCast(global)];
    const name_obj = @as(*object_h.ObjString, @ptrCast(@alignCast(constant.as.obj)));
    const name_slice = name_obj.chars[0..@intCast(name_obj.length)];

    if (errorManagerInitialized) {
        addKnownVariable(name_slice);
    }

    emitBytes(@intFromEnum(opcode), global);
}

pub fn defineVariable(global: u8) void {
    defineVariableImpl(global, .OP_DEFINE_GLOBAL);
}

pub fn defineConstVariable(global: u8) void {
    defineVariableImpl(global, .OP_DEFINE_CONST_GLOBAL);
}

pub fn definePublicVariable(global: u8) void {
    defineVariableImpl(global, .OP_DEFINE_PUBLIC_GLOBAL);
}

pub fn definePublicConstVariable(global: u8) void {
    defineVariableImpl(global, .OP_DEFINE_PUBLIC_CONST_GLOBAL);
}

pub fn argumentList() u8 {
    var argCount: u8 = 0;
    if (!check(.TOKEN_RIGHT_PAREN)) {
        while (true) {
            expression();
            if (@as(i32, @bitCast(@as(c_uint, argCount))) == 255) {
                const suggestions = [_]errors.ErrorSuggestion{
                    .{ .message = "Break down complex function calls into multiple steps" },
                    .{ .message = "Use data structures to group related arguments" },
                    .{ .message = "Maximum arguments per function call is 255" },
                };
                errorWithSuggestions(&parser.previous, .TOO_MANY_ARGUMENTS, "Cannot have more than 255 arguments", &suggestions);
            }
            argCount +%= 1;
            if (!match(.TOKEN_COMMA)) break;
        }
    }
    consume(.TOKEN_RIGHT_PAREN, "Expect ')' after arguments.");
    return argCount;
}
fn getLastConstant(chunk: *Chunk) ?Value {
    if (chunk.count < 2) return null;
    if (chunk.code.?[@intCast(chunk.count - 2)] != @intFromEnum(OpCode.OP_CONSTANT)) return null;
    const constant_idx = chunk.code.?[@intCast(chunk.count - 1)];
    return chunk.constants.values[constant_idx];
}

fn foldUnary(operatorType: TokenType) bool {
    const chunk = currentChunk();
    if (chunk.count < 3) return false;

    // Check if it is OP_CONSTANT <idx> <operator>
    if (chunk.code.?[@intCast(chunk.count - 3)] != @intFromEnum(OpCode.OP_CONSTANT)) return false;
    const value = chunk.constants.values[chunk.code.?[@intCast(chunk.count - 2)]];

    var result: ?Value = null;
    switch (operatorType) {
        .TOKEN_BANG => {
            if (value.type == .VAL_BOOL) {
                result = Value.init_bool(!value.as.boolean);
            } else if (value.type == .VAL_NIL) {
                result = Value.init_bool(true);
            }
        },
        .TOKEN_MINUS => {
            if (value.type == .VAL_INT) {
                result = Value.init_int(-value.as.num_int);
            } else if (value.type == .VAL_DOUBLE) {
                result = Value.init_double(-value.as.num_double);
            }
        },
        else => {},
    }

    if (result) |res| {
        chunk.count -= 3; // Remove OP_CONSTANT, index, and operator
        emitConstant(res);
        return true;
    }
    return false;
}

fn foldBinary(operatorType: TokenType) bool {
    const chunk = currentChunk();

    // Determine how many bytes the operator emitted
    const op_size: u8 = switch (operatorType) {
        .TOKEN_BANG_EQUAL, .TOKEN_GREATER_EQUAL, .TOKEN_LESS_EQUAL => 2,
        else => 1,
    };

    if (chunk.count < 4 + op_size) return false;

    const b_idx_pos: usize = @intCast(@as(i32, @intCast(chunk.count)) - op_size - 1);
    const b_op_pos: usize = @intCast(@as(i32, @intCast(chunk.count)) - op_size - 2);
    const a_idx_pos: usize = @intCast(@as(i32, @intCast(chunk.count)) - op_size - 3);
    const a_op_pos: usize = @intCast(@as(i32, @intCast(chunk.count)) - op_size - 4);

    if (chunk.code.?[b_op_pos] != @intFromEnum(OpCode.OP_CONSTANT)) return false;
    if (chunk.code.?[a_op_pos] != @intFromEnum(OpCode.OP_CONSTANT)) return false;

    const b = chunk.constants.values[chunk.code.?[b_idx_pos]];
    const a = chunk.constants.values[chunk.code.?[a_idx_pos]];

    var result: ?Value = null;

    if (a.is_prim_num() and b.is_prim_num()) {
        const da = a.as_num_double();
        const db = b.as_num_double();
        const is_int = a.is_int() and b.is_int();

        switch (operatorType) {
            .TOKEN_PLUS => {
                if (is_int) result = Value.init_int(a.as_int() + b.as_int()) else result = Value.init_double(da + db);
            },
            .TOKEN_MINUS => {
                if (is_int) result = Value.init_int(a.as_int() - b.as_int()) else result = Value.init_double(da - db);
            },
            .TOKEN_STAR => {
                if (is_int) result = Value.init_int(a.as_int() * b.as_int()) else result = Value.init_double(da * db);
            },
            .TOKEN_SLASH => {
                if (db != 0) result = Value.init_double(da / db);
            },
            .TOKEN_PERCENT => {
                if (is_int and b.as_int() != 0) result = Value.init_int(@mod(a.as_int(), b.as_int())) else if (db != 0) result = Value.init_double(@mod(da, db));
            },
            .TOKEN_HAT => result = Value.init_double(std.math.pow(f64, da, db)),
            .TOKEN_EQUAL_EQUAL => result = Value.init_bool(value_h.valuesEqual(a, b)),
            .TOKEN_BANG_EQUAL => result = Value.init_bool(!value_h.valuesEqual(a, b)),
            .TOKEN_GREATER => result = Value.init_bool(da > db),
            .TOKEN_GREATER_EQUAL => result = Value.init_bool(da >= db),
            .TOKEN_LESS => result = Value.init_bool(da < db),
            .TOKEN_LESS_EQUAL => result = Value.init_bool(da <= db),
            else => {},
        }
    } else if (a.is_string() and b.is_string() and operatorType == .TOKEN_PLUS) {
        // String concatenation
        const sa = a.as_string();
        const sb = b.as_string();
        const len = sa.length + sb.length;
        const allocator = compiler_arena.getCompilerAllocator();
        const buf = allocator.alloc(u8, len) catch return false;
        @memcpy(buf[0..sa.length], sa.chars[0..sa.length]);
        @memcpy(buf[sa.length..len], sb.chars[0..sb.length]);
        result = Value.init_obj(@ptrCast(object_h.copyStringLiteral(buf.ptr, len)));
    } else if (a.type == .VAL_BOOL and b.type == .VAL_BOOL) {
        switch (operatorType) {
            .TOKEN_EQUAL_EQUAL => result = Value.init_bool(a.as.boolean == b.as.boolean),
            .TOKEN_BANG_EQUAL => result = Value.init_bool(a.as.boolean != b.as.boolean),
            else => {},
        }
    }

    if (result) |res| {
        chunk.count -= (4 + op_size); // Remove constants and the operator
        emitConstant(res);
        return true;
    }

    return false;
}

pub fn and_(canAssign: bool) void {
    _ = canAssign;
    const endJump = emitJump(@intFromEnum(OpCode.OP_JUMP_IF_FALSE));
    emitByte(@intFromEnum(OpCode.OP_POP));
    parsePrecedence(PREC_AND);
    patchJump(endJump);
}
pub fn binary(canAssign: bool) void {
    _ = canAssign;
    const operatorType: TokenType = parser.previous.type;
    const rule: ParseRule = getRule(operatorType);
    parsePrecedence(rule.precedence +% 1);

    switch (operatorType) {
        .TOKEN_BANG_EQUAL => emitBytes(@intFromEnum(OpCode.OP_EQUAL), @intFromEnum(OpCode.OP_NOT)),
        .TOKEN_EQUAL_EQUAL => emitByte(@intFromEnum(OpCode.OP_EQUAL)),
        .TOKEN_GREATER => emitByte(@intFromEnum(OpCode.OP_GREATER)),
        .TOKEN_GREATER_EQUAL => emitBytes(@intFromEnum(OpCode.OP_LESS), @intFromEnum(OpCode.OP_NOT)),
        .TOKEN_LESS => emitByte(@intFromEnum(OpCode.OP_LESS)),
        .TOKEN_LESS_EQUAL => emitBytes(@intFromEnum(OpCode.OP_GREATER), @intFromEnum(OpCode.OP_NOT)),
        .TOKEN_PLUS => emitByte(@intFromEnum(OpCode.OP_ADD)),
        .TOKEN_MINUS => emitByte(@intFromEnum(OpCode.OP_SUBTRACT)),
        .TOKEN_STAR => emitByte(@intFromEnum(OpCode.OP_MULTIPLY)),
        .TOKEN_SLASH => emitByte(@intFromEnum(OpCode.OP_DIVIDE)),
        .TOKEN_PERCENT => emitByte(@intFromEnum(OpCode.OP_MODULO)),
        .TOKEN_HAT => emitByte(@intFromEnum(OpCode.OP_EXPONENT)),
        .TOKEN_BAND => emitByte(@intFromEnum(OpCode.OP_BAND)),
        .TOKEN_BOR => emitByte(@intFromEnum(OpCode.OP_BOR)),
        .TOKEN_BXOR => emitByte(@intFromEnum(OpCode.OP_BXOR)),
        .TOKEN_SHL => emitByte(@intFromEnum(OpCode.OP_SHL)),
        .TOKEN_SHR => emitByte(@intFromEnum(OpCode.OP_SHR)),
        // Element-wise operators
        .TOKEN_STAR_DOT => emitByte(@intFromEnum(OpCode.OP_ELEMENT_WISE_MULTIPLY)),
        .TOKEN_SLASH_DOT => emitByte(@intFromEnum(OpCode.OP_ELEMENT_WISE_DIVIDE)),
        .TOKEN_HAT_DOT => emitByte(@intFromEnum(OpCode.OP_ELEMENT_WISE_POWER)),
        else => {},
    }

    _ = foldBinary(operatorType);
}
pub fn call(canAssign: bool) void {
    _ = canAssign;
    const argCount = argumentList();
    emitBytes(@intFromEnum(OpCode.OP_CALL), argCount);
}
pub fn dot(canAssign: bool) void {
    consume(.TOKEN_IDENTIFIER, "Expect property name after '.'.");
    const name = identifierConstant(&parser.previous);
    if (canAssign and match(.TOKEN_EQUAL)) {
        expression();
        emitBytes(@intFromEnum(OpCode.OP_SET_PROPERTY), name);
    } else if (canAssign and (match(.TOKEN_PLUS_EQUAL) or match(.TOKEN_MINUS_EQUAL) or match(.TOKEN_STAR_EQUAL) or match(.TOKEN_SLASH_EQUAL))) {
        const operatorType = parser.previous.type;
        // Duplicate the receiver to use it for both GET and SET
        emitByte(@intFromEnum(OpCode.OP_DUP));
        emitBytes(@intFromEnum(OpCode.OP_GET_PROPERTY), name);
        expression();
        switch (operatorType) {
            .TOKEN_PLUS_EQUAL => emitByte(@intFromEnum(OpCode.OP_ADD)),
            .TOKEN_MINUS_EQUAL => emitByte(@intFromEnum(OpCode.OP_SUBTRACT)),
            .TOKEN_STAR_EQUAL => emitByte(@intFromEnum(OpCode.OP_MULTIPLY)),
            .TOKEN_SLASH_EQUAL => emitByte(@intFromEnum(OpCode.OP_DIVIDE)),
            else => {},
        }
        emitBytes(@intFromEnum(OpCode.OP_SET_PROPERTY), name);
    } else if (match(.TOKEN_LEFT_PAREN)) {
        const argCount = argumentList();
        emitBytes(@intFromEnum(OpCode.OP_INVOKE), name);
        emitByte(argCount);
    } else {
        emitBytes(@intFromEnum(OpCode.OP_GET_PROPERTY), name);
    }
}
pub fn literal(canAssign: bool) void {
    _ = canAssign;
    switch (parser.previous.type) {
        .TOKEN_FALSE => emitByte(@intFromEnum(OpCode.OP_FALSE)),
        .TOKEN_NIL => emitByte(@intFromEnum(OpCode.OP_NIL)),
        .TOKEN_TRUE => emitByte(@intFromEnum(OpCode.OP_TRUE)),
        else => {},
    }
}
pub fn grouping(canAssign: bool) void {
    _ = canAssign;
    expression();
    consume(.TOKEN_RIGHT_PAREN, "Expect ')' after expression.");
}

// Process hashtable literal
pub fn hashTable(canAssign: bool) void {
    // Expecting '{' next
    consume(.TOKEN_LEFT_BRACE, "Expect '{' after '#' for hashtable");
    // Set isDict to true and pass it to objectLiteral
    parser.previous.type = .TOKEN_HASH; // Mark that we came from hash
    objectLiteral(canAssign);
}
pub fn number(canAssign: bool) void {
    _ = canAssign;
    if (parser.previous.type == .TOKEN_INT) {
        const token_slice = parser.previous.start[0..@intCast(parser.previous.length)];
        const value: i32 = std.fmt.parseInt(i32, token_slice, 10) catch 0;
        emitConstant(Value{
            .type = .VAL_INT,
            .as = .{
                .num_int = value,
            },
        });
    } else {
        const token_slice = parser.previous.start[0..@intCast(parser.previous.length)];
        const value: f64 = std.fmt.parseFloat(f64, token_slice) catch 0.0;
        emitConstant(Value{
            .type = .VAL_DOUBLE,
            .as = .{
                .num_double = value,
            },
        });
    }
}

pub fn imaginary_number(canAssign: bool) void {
    _ = canAssign;
    const token_slice = parser.previous.start[0..@intCast(parser.previous.length)];

    // Parse complex number in format "a+bi" or "a-bi"
    if (parseComplexNumber(token_slice)) |complex_val| {
        emitConstant(Value{
            .type = .VAL_COMPLEX,
            .as = .{
                .complex = complex_val,
            },
        });
    } else {
        // Fallback to pure imaginary number
        const imaginary_str = token_slice[0 .. token_slice.len - 1]; // Remove 'i' suffix
        const imaginary_value: f64 = std.fmt.parseFloat(f64, imaginary_str) catch 0.0;
        emitConstant(Value{
            .type = .VAL_COMPLEX,
            .as = .{
                .complex = Complex{ .r = 0.0, .i = imaginary_value },
            },
        });
    }
}

fn parseComplexNumber(input: []const u8) ?Complex {
    var real_part: f64 = 0.0;
    var imaginary_part: f64 = 0.0;
    var i: usize = 0;

    // Skip leading whitespace
    while (i < input.len and (input[i] == ' ' or input[i] == '\t')) {
        i += 1;
    }

    // Parse real part
    const real_start = i;
    while (i < input.len and (isDigitChar(input[i]) or input[i] == '.' or input[i] == '-' or input[i] == '+')) {
        if (input[i] == '+' or input[i] == '-') {
            if (i > real_start) break; // Found operator after real part
        }
        i += 1;
    }

    if (i > real_start) {
        const real_str = input[real_start..i];
        real_part = std.fmt.parseFloat(f64, real_str) catch return null;
    }

    // Skip whitespace
    while (i < input.len and (input[i] == ' ' or input[i] == '\t')) {
        i += 1;
    }

    // Look for +/- operator
    var sign: f64 = 1.0;
    if (i < input.len and (input[i] == '+' or input[i] == '-')) {
        if (input[i] == '-') sign = -1.0;
        i += 1;

        // Skip whitespace after operator
        while (i < input.len and (input[i] == ' ' or input[i] == '\t')) {
            i += 1;
        }

        // Parse imaginary part
        const imaginary_start = i;
        while (i < input.len and (isDigitChar(input[i]) or input[i] == '.')) {
            i += 1;
        }

        if (i > imaginary_start and i < input.len and input[i] == 'i') {
            const imaginary_str = input[imaginary_start..i];
            imaginary_part = (std.fmt.parseFloat(f64, imaginary_str) catch return null) * sign;
            return Complex{ .r = real_part, .i = imaginary_part };
        }
    }

    return null;
}

fn isDigitChar(c: u8) bool {
    return c >= '0' and c <= '9';
}
pub fn or_(canAssign: bool) void {
    _ = canAssign;
    const elseJump = emitJump(@intFromEnum(OpCode.OP_JUMP_IF_FALSE));
    const endJump = emitJump(@intFromEnum(OpCode.OP_JUMP));
    patchJump(elseJump);
    emitByte(@intFromEnum(OpCode.OP_POP));
    parsePrecedence(PREC_OR);
    patchJump(endJump);
}

pub fn ternary(canAssign: bool) void {
    _ = canAssign;

    // Jump to else branch if condition is false
    const elseJump: i32 = emitJump(@intFromEnum(OpCode.OP_JUMP_IF_FALSE));
    emitByte(@intFromEnum(OpCode.OP_POP)); // Pop condition

    // Parse the true expression
    parsePrecedence(PREC_TERNARY);

    // Jump over the false expression
    const endJump: i32 = emitJump(@intFromEnum(OpCode.OP_JUMP));

    // Patch the else jump to come here
    patchJump(elseJump);
    emitByte(@intFromEnum(OpCode.OP_POP)); // Pop condition (for false branch)

    // Expect ':' separator
    consume(.TOKEN_COLON, "Expect ':' after ternary true expression.");

    // Parse the false expression
    parsePrecedence(PREC_TERNARY);

    // Patch the end jump
    patchJump(endJump);
}
pub fn string(canAssign: bool) void {
    _ = canAssign;

    var start = parser.previous.start + 1; // Skip opening quote
    var length: i32 = if (parser.previous.length >= 2) parser.previous.length - 2 else 0;

    // Handle triple-quoted strings differently
    if (length >= 4 and start[0] == '"' and start[1] == '"') {
        // For triple-quoted strings, skip the additional opening quotes and closing quotes
        start += 2; // Skip the two additional opening quotes
        if (length >= 4) {
            length -= 4; // Remove two leading and two trailing quotes
        }
    }

    emitConstant(Value.init_obj(@ptrCast(object_h.copyStringLiteral(start, @intCast(length)))));
}

pub fn fstring(canAssign: bool) void {
    _ = canAssign;

    // Parse f-string content to extract expressions and create format call
    const fstring_content = parser.previous.start[0..@intCast(parser.previous.length)];

    // Count placeholders and collect expressions
    var arg_count: u8 = 0;
    var template_buffer: [1024]u8 = undefined;
    var template_pos: usize = 0;
    var i: usize = 0;

    // Create array to store expression strings for later parsing
    var expressions: [32][64]u8 = undefined;
    var expr_lengths: [32]usize = undefined;

    // First pass: build template and extract expressions
    while (i < fstring_content.len and template_pos < template_buffer.len - 3) {
        if (fstring_content[i] == '{') {
            if (i + 1 < fstring_content.len and fstring_content[i + 1] == '}') {
                // Empty placeholder {}
                template_buffer[template_pos] = '{';
                template_buffer[template_pos + 1] = '}';
                template_pos += 2;
                arg_count += 1;
                i += 2;
            } else if (i + 1 < fstring_content.len and fstring_content[i + 1] == '{') {
                // Escaped {{ -> {
                template_buffer[template_pos] = '{';
                template_pos += 1;
                i += 2;
            } else {
                // Expression placeholder {expr}
                const expr_start = i + 1;
                var expr_end = expr_start;
                var brace_count: i32 = 1;

                // Find matching closing brace
                while (expr_end < fstring_content.len and brace_count > 0) {
                    if (fstring_content[expr_end] == '{') {
                        brace_count += 1;
                    } else if (fstring_content[expr_end] == '}') {
                        brace_count -= 1;
                    }
                    if (brace_count > 0) expr_end += 1;
                }

                if (brace_count == 0 and arg_count < 32) {
                    // Store expression for later parsing
                    const expr_len = expr_end - expr_start;
                    if (expr_len < 64) {
                        @memcpy(expressions[arg_count][0..expr_len], fstring_content[expr_start..expr_end]);
                        expr_lengths[arg_count] = expr_len;

                        // Add placeholder to template
                        template_buffer[template_pos] = '{';
                        template_buffer[template_pos + 1] = '}';
                        template_pos += 2;
                        arg_count += 1;
                    }

                    i = expr_end + 1;
                } else {
                    @"error"("Unclosed '{' in f-string or too many expressions");
                    return;
                }
            }
        } else if (fstring_content[i] == '}' and i + 1 < fstring_content.len and fstring_content[i + 1] == '}') {
            // Escaped }} -> }
            template_buffer[template_pos] = '}';
            template_pos += 1;
            i += 2;
        } else {
            // Regular character
            template_buffer[template_pos] = fstring_content[i];
            template_pos += 1;
            i += 1;
        }
    }

    // Emit format function call
    emitBytes(@intFromEnum(OpCode.OP_GET_GLOBAL), makeConstant(Value.init_obj(@ptrCast(object_h.copyStringLiteral("format", 6)))));

    // Emit template string as first argument
    const template_value = Value.init_obj(@ptrCast(object_h.copyStringLiteral(template_buffer[0..template_pos].ptr, template_pos)));
    emitConstant(template_value);

    // Parse and emit each expression
    const saved_scanner = scanner_h.scanner;
    const saved_current = parser.current;
    const saved_previous = parser.previous;

    var expr_idx: u8 = 0;
    while (expr_idx < arg_count) {
        const expr_text = expressions[expr_idx][0..expr_lengths[expr_idx]];

        if (expr_text.len == 0) {
            // Empty expression, emit nil
            emitByte(@intFromEnum(OpCode.OP_NIL));
        } else {
            // Set up scanner for this expression
            scanner_h.scanner.start = expr_text.ptr;
            scanner_h.scanner.current = expr_text.ptr;
            scanner_h.scanner.line = saved_scanner.line;

            // Parse the expression
            advance();
            expression();
        }

        expr_idx += 1;
    }

    // Restore scanner state
    scanner_h.scanner = saved_scanner;
    parser.current = saved_current;
    parser.previous = saved_previous;

    // Call format function
    emitBytes(@intFromEnum(OpCode.OP_CALL), arg_count + 1);
}
fn emitRange(opcode: OpCode) void {
    parsePrecedence(@as(c_uint, @bitCast(PREC_RANGE + 1)));
    emitByte(@intFromEnum(opcode));
}

pub fn rangeExclusive(canAssign: bool) void {
    _ = canAssign;
    emitRange(.OP_RANGE);
}

pub fn rangeInclusive(canAssign: bool) void {
    _ = canAssign;
    emitRange(.OP_RANGE_INCLUSIVE);
}

pub fn pair(canAssign: bool) void {
    _ = canAssign;

    // Parse the value expression (right hand side)
    parsePrecedence(@as(c_uint, @bitCast(PREC_TERM + 1)));

    // Emit the pair creation instruction
    emitByte(@intFromEnum(OpCode.OP_PAIR));
}

pub fn objectLiteral(canAssign: bool) void {
    _ = canAssign;

    // Check if this is a dictionary or float vector
    // A dictionary is indicated by the pattern: { string/identifier : value }
    var isDict = false;

    // Check if we came from a # token for hashtable
    if (parser.previous.type == .TOKEN_HASH) {
        isDict = true;
    } else {
        // If no # prefix, it's a float vector
        isDict = false;
    }

    if (isDict) {
        // It's a dictionary (hash table)
        emitByte(@intFromEnum(OpCode.OP_HASH_TABLE));

        if (!check(.TOKEN_RIGHT_BRACE)) {
            while (true) {
                // Parse key - either a string literal or an identifier
                if (match(.TOKEN_STRING)) {
                    // String literal is already parsed and on stack as a string
                    emitConstant(Value.init_obj(@ptrCast(object_h.copyStringLiteral(parser.previous.start + 1, // Skip opening quote
                        @intCast(parser.previous.length - 2) // Skip both quotes
                    ))));
                } else if (match(.TOKEN_IDENTIFIER)) {
                    // Convert identifier to string literal
                    const name = parser.previous.start[0..@intCast(parser.previous.length)];
                    emitConstant(Value.init_obj(@ptrCast(object_h.copyStringLiteral(name.ptr, name.len))));
                } else {
                    errorAtCurrent(@ptrCast(@constCast("Dictionary key must be a string or identifier")));
                    return;
                }

                consume(.TOKEN_COLON, "Expect ':' after dictionary key");

                // Parse the value
                expression();

                // Emit instruction to add entry to hash table
                emitByte(@intFromEnum(OpCode.OP_ADD_ENTRY));

                if (!match(.TOKEN_COMMA)) break;

                // Error if trailing comma followed by closing brace
                if (check(.TOKEN_RIGHT_BRACE)) break;
            }
        }
    } else {
        // It's a float vector
        var argCount: u8 = 0;

        if (!check(.TOKEN_RIGHT_BRACE)) {
            while (true) {
                expression();
                argCount +%= 1;

                if (@as(i32, @bitCast(@as(c_uint, argCount))) > 255) {
                    const suggestions = [_]errors.ErrorSuggestion{
                        .{ .message = "Break large vectors into smaller ones" },
                        .{ .message = "Use arrays or other data structures for large collections" },
                        .{ .message = "Maximum vector size is 255 elements" },
                    };
                    errorWithSuggestions(&parser.previous, .TOO_MANY_ARGUMENTS, "Cannot have more than 255 elements in a vector", &suggestions);
                }

                if (!match(.TOKEN_COMMA)) break;
            }
        }

        emitBytes(@intFromEnum(OpCode.OP_FVECTOR), argCount);
    }

    consume(.TOKEN_RIGHT_BRACE, "Expect '}' after object literal");
}

// Handle both vector literals [1, 2, 3] and matrix literals [[1, 2], [3, 4]]
pub fn fvector(canAssign: bool) void {
    _ = canAssign;

    // Check if this is a matrix literal (starts with [[)
    if (check(.TOKEN_LEFT_SQPAREN)) {
        // This is a matrix literal [[...], [...], ...]
        matrixLiteral();
    } else {
        // This is a regular vector literal [1, 2, 3]
        regularVector();
    }
}

fn matrixLiteral() void {
    var rowCount: u8 = 0;
    var colCount: u8 = 0;
    var firstRow = true;

    // Parse rows
    while (true) {
        if (!match(.TOKEN_LEFT_SQPAREN)) {
            errorAtCurrent(@ptrCast(@constCast("Expect '[' at start of matrix row")));
            return;
        }

        var currentRowCols: u8 = 0;

        // Parse elements in this row
        if (!check(.TOKEN_RIGHT_SQPAREN)) {
            while (true) {
                expression();
                currentRowCols +%= 1;

                if (!match(.TOKEN_COMMA)) break;
            }
        }

        consume(.TOKEN_RIGHT_SQPAREN, "Expect ']' after matrix row");

        // Check column count consistency
        if (firstRow) {
            colCount = currentRowCols;
            firstRow = false;
        } else if (currentRowCols != colCount) {
            errorAtCurrent(@ptrCast(@constCast("All matrix rows must have same number of columns")));
            return;
        }

        rowCount +%= 1;

        if (@as(i32, @bitCast(@as(c_uint, rowCount))) > 255 or @as(i32, @bitCast(@as(c_uint, colCount))) > 255) {
            const suggestions = [_]errors.ErrorSuggestion{
                .{ .message = "Matrix dimensions are limited to 255x255" },
                .{ .message = "Use smaller matrices or break into blocks" },
            };
            errorWithSuggestions(&parser.previous, .TOO_MANY_ARGUMENTS, "Matrix too large", &suggestions);
        }

        if (!match(.TOKEN_COMMA)) break;
    }

    consume(.TOKEN_RIGHT_SQPAREN, "Expect ']' after matrix literal");

    // Emit matrix creation instruction with dimensions
    emitBytes(@intFromEnum(OpCode.OP_MATRIX), rowCount);
    emitByte(colCount);
}

fn regularVector() void {
    var argCount: u8 = 0;
    if (!check(.TOKEN_RIGHT_SQPAREN)) {
        while (true) {
            expression();
            argCount +%= 1;
            if (@as(i32, @bitCast(@as(c_uint, argCount))) > 255) {
                const suggestions = [_]errors.ErrorSuggestion{
                    .{ .message = "Break large vectors into smaller ones" },
                    .{ .message = "Use arrays or other data structures for large collections" },
                    .{ .message = "Maximum vector size is 255 elements" },
                };
                errorWithSuggestions(&parser.previous, .TOO_MANY_ARGUMENTS, "Cannot have more than 255 elements in a vector", &suggestions);
            }
            if (!match(.TOKEN_COMMA)) break;
        }
    }
    consume(.TOKEN_RIGHT_SQPAREN, "Expect ']' after vector elements.");
    emitBytes(@intFromEnum(OpCode.OP_FVECTOR), argCount);
}
/// Check if a local variable is const and emit an error if so. Returns true if const (caller should return).
fn checkConstAssignment(name: Token, arg: i32, isLocal: bool) bool {
    const varName = name.start[0..@intCast(name.length)];
    var is_const = false;

    if (isLocal) {
        if (current.?.locals[@intCast(arg)].isConst) is_const = true;
    }

    if (is_const) {
        const suggestions = [_]errors.ErrorSuggestion{
            .{ .message = "Use 'var' instead of 'const' if you need to modify this variable" },
            .{ .message = "Constants cannot be modified after declaration" },
            .{ .message = "Declare as mutable", .example = "var myVariable = value;" },
        };
        var mutable_name = name;
        errorWithSuggestions(&mutable_name, .INVALID_ASSIGNMENT, std.fmt.allocPrint(compiler_arena.getCompilerAllocator(), "Cannot assign to constant variable '{s}'", .{varName}) catch "Cannot assign to constant variable", &suggestions);
        return true;
    }
    return false;
}

/// Emit an increment or decrement operation: get var, add/subtract 1, set var.
fn emitIncDec(getOp: u8, setOp: u8, arg: i32, opcode: OpCode) void {
    const argByte = @as(u8, @bitCast(@as(i8, @truncate(arg))));
    emitBytes(getOp, argByte);
    emitConstant(Value.init_int(1));
    emitByte(@intFromEnum(opcode));
    emitBytes(setOp, argByte);
}

fn emitIncDecGlobal(getOp: u8, setOp: u8, arg: i32, opcode: OpCode, isSingleByte: bool) void {
    if (isSingleByte) {
        const argByte = @as(u8, @bitCast(@as(i8, @truncate(arg))));
        emitBytes(getOp, argByte);
        emitConstant(Value.init_int(1));
        emitByte(@intFromEnum(opcode));
        emitBytes(setOp, argByte);
    } else {
        const slot = @as(u32, @intCast(arg));
        emitGlobalSlot(getOp, slot);
        emitConstant(Value.init_int(1));
        emitByte(@intFromEnum(opcode));
        emitGlobalSlot(setOp, slot);
    }
}

pub fn namedVariable(name: Token, canAssign: bool) void {
    var getOp: u8 = undefined;
    var setOp: u8 = undefined;
    var arg: i32 = resolveLocal(current.?, @constCast(&name));
    var isLocal: bool = false;

    const name_slice = name.start[0..@intCast(name.length)];

    if (arg != -1) {
        getOp = @intFromEnum(OpCode.OP_GET_LOCAL);
        setOp = @intFromEnum(OpCode.OP_SET_LOCAL);
        isLocal = true;
    } else if ((blk: {
        arg = resolveUpvalue(current.?, @constCast(&name));
        break :blk arg;
    }) != -1) {
        getOp = @intFromEnum(OpCode.OP_GET_UPVALUE);
        setOp = @intFromEnum(OpCode.OP_SET_UPVALUE);
    } else {
        const name_idx = identifierConstant(@constCast(&name));
        const name_str_val = currentChunk().constants.values[name_idx];
        const name_obj = @as(*object_h.ObjString, @ptrCast(@alignCast(name_str_val.as.obj)));

        // Use name-based lookup for builtins (always available)
        const module_registry = @import("module_registry.zig");
        const is_builtin = module_registry.isBuiltInModule(name_slice);

        if (is_builtin) {
            getOp = @intFromEnum(OpCode.OP_GET_GLOBAL);
            setOp = @intFromEnum(OpCode.OP_SET_GLOBAL);
            arg = @intCast(name_idx);
        } else {
            // Project globals use slot-based access
            getOp = @intFromEnum(OpCode.OP_GET_GLOBAL_SLOT);
            setOp = @intFromEnum(OpCode.OP_SET_GLOBAL_SLOT_KEEP);
            arg = @intCast(vm_h.getGlobalSlot(name_obj));
        }
    }

    if (canAssign and match(.TOKEN_EQUAL)) {
        if (checkConstAssignment(name, arg, isLocal)) return;
        expression();
        if (isLocal or getOp == @intFromEnum(OpCode.OP_GET_GLOBAL)) {
            const argByte = @as(u8, @bitCast(@as(i8, @truncate(arg))));
            emitBytes(setOp, argByte);
        } else {
            emitGlobalSlot(setOp, @as(u32, @intCast(arg)));
        }
    } else if (canAssign and (match(.TOKEN_PLUS_EQUAL) or match(.TOKEN_MINUS_EQUAL) or match(.TOKEN_STAR_EQUAL) or match(.TOKEN_SLASH_EQUAL))) {
        if (checkConstAssignment(name, arg, isLocal)) return;
        if (isLocal or getOp == @intFromEnum(OpCode.OP_GET_GLOBAL)) {
            const argByte = @as(u8, @bitCast(@as(i8, @truncate(arg))));
            emitBytes(getOp, argByte);
        } else {
            emitGlobalSlot(getOp, @as(u32, @intCast(arg)));
        }
        expression();
        switch (parser.previous.type) {
            .TOKEN_PLUS_EQUAL => emitByte(@intFromEnum(OpCode.OP_ADD)),
            .TOKEN_MINUS_EQUAL => emitByte(@intFromEnum(OpCode.OP_SUBTRACT)),
            .TOKEN_STAR_EQUAL => emitByte(@intFromEnum(OpCode.OP_MULTIPLY)),
            .TOKEN_SLASH_EQUAL => emitByte(@intFromEnum(OpCode.OP_DIVIDE)),
            else => {},
        }
        if (isLocal or getOp == @intFromEnum(OpCode.OP_GET_GLOBAL)) {
            const argByte = @as(u8, @bitCast(@as(i8, @truncate(arg))));
            emitBytes(setOp, argByte);
        } else {
            emitGlobalSlot(setOp, @as(u32, @intCast(arg)));
        }
    } else if (canAssign and match(.TOKEN_PLUS_PLUS)) {
        if (checkConstAssignment(name, arg, isLocal)) return;
        emitIncDecGlobal(getOp, setOp, arg, .OP_ADD, isLocal or getOp == @intFromEnum(OpCode.OP_GET_GLOBAL));
    } else if (canAssign and match(.TOKEN_MINUS_MINUS)) {
        if (checkConstAssignment(name, arg, isLocal)) return;
        emitIncDecGlobal(getOp, setOp, arg, .OP_SUBTRACT, isLocal or getOp == @intFromEnum(OpCode.OP_GET_GLOBAL));
    } else {
        if (isLocal or getOp == @intFromEnum(OpCode.OP_GET_GLOBAL)) {
            const argByte = @as(u8, @bitCast(@as(i8, @truncate(arg))));
            emitBytes(getOp, argByte);
        } else {
            emitGlobalSlot(getOp, @as(u32, @intCast(arg)));
        }
    }
}

pub fn variable(canAssign: bool) void {
    namedVariable(parser.previous, canAssign);
}

pub fn symbolVariable(canAssign: bool) void {
    _ = canAssign;
    // When @x is used in an expression, look up variable x as a symbol
    if (!check(.TOKEN_IDENTIFIER)) {
        errorAtCurrent("Expect variable name after '@'");
        return;
    }
    const nameConstant = identifierConstant(&parser.current);
    advance(); // consume the identifier
    emitBytes(@intFromEnum(OpCode.OP_SYMBOL), nameConstant);
}

pub fn syntheticToken(text: [*]const u8) Token {
    const length = mem_utils.strlen(text);
    return Token{
        .type = .TOKEN_IDENTIFIER,
        .start = @ptrCast(@constCast(text)),
        .length = @as(i32, @intCast(length)),
        .line = 0,
    };
}

pub fn super_(canAssign: bool) void {
    _ = canAssign;
    if (currentClass == null) {
        const suggestions = [_]errors.ErrorSuggestion{
            .{ .message = "Use 'super' only inside class methods" },
            .{ .message = "Move the 'super' call into a class definition" },
            .{ .message = "Use super in derived class methods", .example = "class Child extends Parent { method() { super.method(); } }" },
        };
        errorWithSuggestions(&parser.previous, .INVALID_SUPER_USAGE, "Cannot use 'super' outside of a class", &suggestions);
        return;
    } else if (!currentClass.?.*.hasSuperclass) {
        const suggestions = [_]errors.ErrorSuggestion{
            .{ .message = "Add a parent class for inheritance" },
            .{ .message = "Remove the 'super' call if inheritance is not needed" },
            .{ .message = "Use proper inheritance syntax", .example = "class Child extends Parent { ... }" },
        };
        errorWithSuggestions(&parser.previous, .INVALID_SUPER_USAGE, "Cannot use 'super' in a class with no superclass", &suggestions);
        return;
    }
    consume(.TOKEN_DOT, "Expect '.' after 'super'.");
    consume(.TOKEN_IDENTIFIER, "Expect superclass method name.");
    const name = identifierConstant(&parser.previous);

    // Push 'self' as the receiver (this)
    namedVariable(syntheticToken("self"), false);

    if (match(.TOKEN_LEFT_PAREN)) {
        const argCount = argumentList();
        namedVariable(syntheticToken("super"), false);
        emitBytes(@intFromEnum(OpCode.OP_SUPER_INVOKE), name);
        emitByte(argCount);
    } else {
        namedVariable(syntheticToken("super"), false);
        emitBytes(@intFromEnum(OpCode.OP_GET_SUPER), name);
    }
}
pub fn self_(canAssign: bool) void {
    _ = canAssign;
    if (currentClass == null) {
        const suggestions = [_]errors.ErrorSuggestion{
            .{ .message = "Use 'self' only inside class methods" },
            .{ .message = "Move the 'self' reference into a class definition" },
            .{ .message = "Use self in class methods", .example = "class MyClass { method() { self.property = value; } }" },
        };
        errorWithSuggestions(&parser.previous, .INVALID_SELF_USAGE, "Cannot use 'self' outside of a class", &suggestions);
        return;
    }
    // Look up "self" variable
    namedVariable(syntheticToken("self"), false);
}
pub fn item_(canAssign: bool) void {
    _ = &canAssign;
    variable(false);
}

/// Parse an index expression that may be `end`, `end - offset`, or a regular expression.
fn parseIndexExpression() void {
    if (check(.TOKEN_END)) {
        advance();
        emitConstant(Value.init_int(-1));
        if (match(.TOKEN_MINUS)) {
            parsePrecedence(@as(c_uint, @bitCast(PREC_UNARY)));
            emitByte(@intFromEnum(OpCode.OP_SUBTRACT));
        }
    } else {
        expression();
    }
}

pub fn index_(canAssign: bool) void {
    var isSlice = false;
    var is2DSlice = false;

    // Parse the first index
    parseIndexExpression();

    // Check if we have a colon for slice operation
    if (match(.TOKEN_COLON)) {
        isSlice = true;
        parseIndexExpression();

        // Check for 2D slicing: m[r1:r2, c1:c2]
        if (match(.TOKEN_COMMA)) {
            is2DSlice = true;
            // Parse column start:end
            parseIndexExpression();
            if (match(.TOKEN_COLON)) {
                parseIndexExpression();
            } else {
                // If no colon after comma, treat as single column index
                // Emit a constant for the end (same as start)
                emitConstant(Value.init_int(0)); // Will be fixed by VM
            }
        }
    } else if (match(.TOKEN_COMMA)) {
        // 2D indexing without slice: m[r, c]
        // We emit OP_GET_INDEX now to get the row, then the final OP_GET_INDEX
        // will get the column from that row.
        emitByte(@intFromEnum(OpCode.OP_GET_INDEX));
        parseIndexExpression();
    }

    consume(.TOKEN_RIGHT_SQPAREN, "Expect ']' after index expression.");

    if (is2DSlice) {
        emitByte(@intFromEnum(OpCode.OP_MATRIX_SLICE));
    } else if (isSlice) {
        emitByte(@intFromEnum(OpCode.OP_SLICE));
    } else if (canAssign and match(.TOKEN_EQUAL)) {
        expression();
        emitByte(@intFromEnum(OpCode.OP_SET_INDEX));
    } else {
        emitByte(@intFromEnum(OpCode.OP_GET_INDEX));
    }
}

pub fn unary(canAssign: bool) void {
    _ = canAssign;
    const operatorType = parser.previous.type;
    parsePrecedence(@as(c_uint, @bitCast(PREC_UNARY)));

    switch (operatorType) {
        .TOKEN_BANG => emitByte(@intFromEnum(OpCode.OP_NOT)),
        .TOKEN_MINUS => emitByte(@intFromEnum(OpCode.OP_NEGATE)),
        .TOKEN_BNOT => emitByte(@intFromEnum(OpCode.OP_BNOT)),
        else => {},
    }

    _ = foldUnary(operatorType);
}

pub fn block() void {
    while (!check(.TOKEN_RIGHT_BRACE) and !check(.TOKEN_EOF)) {
        declaration();
    }
    consume(.TOKEN_RIGHT_BRACE, "Expect '}' after block.");
}
pub fn function(type_: FunctionType) void {
    var compiler: Compiler = undefined;
    initCompiler(&compiler, type_);
    beginScope();
    consume(.TOKEN_LEFT_PAREN, "Expect '(' after function name.");
    if (!check(.TOKEN_RIGHT_PAREN)) {
        while (true) {
            current.?.function.*.arity += 1;
            if (current.?.function.*.arity > 255) {
                errorAtCurrent("Can't have more than 255 parameters.");
            }
            const constant = parseVariable("Expect parameter name.");
            defineVariable(constant);
            if (!match(.TOKEN_COMMA)) break;
        }
    }
    consume(.TOKEN_RIGHT_PAREN, "Expect ')' after parameters.");
    consume(.TOKEN_LEFT_BRACE, "Expect '{' before function body.");
    block();
    const function_1 = endCompiler();
    emitBytes(@intFromEnum(OpCode.OP_CLOSURE), makeConstant(Value.init_obj(@ptrCast(function_1))));
    var i: i32 = 0;
    while (i < function_1.*.upvalueCount) : (i += 1) {
        emitByte(if (compiler.upvalues[@as(c_uint, @intCast(i))].isLocal) 1 else 0);
        emitByte(compiler.upvalues[@as(c_uint, @intCast(i))].index);
    }
}
pub fn method() void {
    consume(.TOKEN_IDENTIFIER, "Expect method name.");
    const constant = identifierConstant(&parser.previous);
    var type_: FunctionType = .TYPE_METHOD;
    if ((parser.previous.length == @as(i32, 4)) and (mem_utils.memcmp(@ptrCast(parser.previous.start), @ptrCast("init"), 4) == 0)) {
        type_ = .TYPE_INITIALIZER;
    }
    function(type_);
    emitBytes(@intFromEnum(OpCode.OP_METHOD), constant);
}

pub fn classDeclaration() void {
    consume(.TOKEN_IDENTIFIER, "Expect class name.");
    const className = parser.previous;
    const nameConstant = identifierConstant(&parser.previous);
    declareVariable();
    emitBytes(@intFromEnum(OpCode.OP_CLASS), nameConstant);
    defineVariable(nameConstant);
    var classCompiler: ClassCompiler = undefined;
    classCompiler.enclosing = currentClass;
    classCompiler.hasSuperclass = false;
    currentClass = &classCompiler;

    // Begin scope for methods and self
    beginScope();
    addLocal(syntheticToken("self"));

    if (match(.TOKEN_LESS)) {
        consume(.TOKEN_IDENTIFIER, "Expect superclass name.");
        variable(false);
        if (identifiersEqual(@constCast(&className), &parser.previous)) {
            const className_str = className.start[0..@intCast(className.length)];
            const suggestions = [_]errors.ErrorSuggestion{
                .{ .message = "Inherit from a different class" },
                .{ .message = "Remove the inheritance if not needed" },
                .{ .message = "Classes cannot inherit from themselves" },
            };
            errorWithSuggestions(&parser.previous, .CLASS_INHERITANCE_ERROR, std.fmt.allocPrint(compiler_arena.getCompilerAllocator(), "Class '{s}' cannot inherit from itself", .{className_str}) catch "Class cannot inherit from itself", &suggestions);
        }

        // Store the superclass in a local variable named "super"
        addLocal(syntheticToken("super"));
        namedVariable(parser.previous, false);
        defineVariable(0);

        namedVariable(className, false);
        emitByte(@intFromEnum(OpCode.OP_INHERIT));
        currentClass.?.hasSuperclass = true;
    }

    namedVariable(className, false);
    consume(.TOKEN_LEFT_BRACE, "Expect '{' before class body.");
    while (!check(.TOKEN_RIGHT_BRACE) and !check(.TOKEN_EOF)) {
        method();
    }
    consume(.TOKEN_RIGHT_BRACE, "Expect '}' after class body.");
    emitByte(@intFromEnum(OpCode.OP_POP));

    // End scope for methods, self, and super
    endScope();

    currentClass = currentClass.?.enclosing;
}

// Import statement handling functions
pub fn importStatement() void {
    if (check(.TOKEN_STRING)) {
        // File import: import "file_path"
        fileImportStatement();
    } else if (check(.TOKEN_IDENTIFIER)) {
        // Module import: import math
        moduleImportStatement();
    } else {
        const suggestions = [_]errors.ErrorSuggestion{
            .{ .message = "Provide a module name or file path after 'import'" },
            .{ .message = "Use: import module_name; or import \"file.mufi\";" },
        };
        errorWithSuggestions(&parser.current, .EXPECTED_EXPRESSION, "Expect module name or file path after 'import'.", &suggestions);
    }
}

pub fn moduleImportStatement() void {
    consume(.TOKEN_IDENTIFIER, "Expect module name.");
    const moduleName = parser.previous;

    var alias: ?Token = null;
    if (match(.TOKEN_AS)) {
        consume(.TOKEN_IDENTIFIER, "Expect identifier after 'as'.");
        alias = parser.previous;
    }

    consume(.TOKEN_SEMICOLON, "Expect ';' after import statement.");

    // Emit the module name as a constant
    const nameConstant = makeConstant(makeStringValue(moduleName.start, @intCast(moduleName.length)));

    // If there's an alias, emit it too
    if (alias) |aliasToken| {
        var mutableAliasToken = aliasToken;
        const aliasConstant = identifierConstant(&mutableAliasToken);
        declareVariable();
        emitByte(@intFromEnum(OpCode.OP_IMPORT_MODULE_AS));
        emitByte(nameConstant);
        emitByte(aliasConstant);

        if (current.?.scopeDepth > 0) {
            markInitialized();
        }
    } else {
        emitBytes(@intFromEnum(OpCode.OP_IMPORT_MODULE), nameConstant);
    }
}

pub fn fileImportStatement() void {
    consume(.TOKEN_STRING, "Expect file path string.");
    const filePath = parser.previous;

    var alias: ?Token = null;
    if (match(.TOKEN_AS)) {
        consume(.TOKEN_IDENTIFIER, "Expect identifier after 'as'.");
        alias = parser.previous;
    }

    consume(.TOKEN_SEMICOLON, "Expect ';' after import statement.");

    // The file path token already includes quotes, so we need to remove them
    const pathStart = filePath.start + 1; // Skip opening quote
    const pathLength = filePath.length - 2; // Remove both quotes

    const pathConstant = makeConstant(makeStringValue(pathStart, @intCast(pathLength)));

    // Always execute the file first so its globals (pub and private) are defined
    emitBytes(@intFromEnum(OpCode.OP_IMPORT_FILE), pathConstant);
    // Pop the return value from the imported file
    emitByte(@intFromEnum(OpCode.OP_POP));

    if (alias) |aliasToken| {
        // import "file.mufi" as helpers;
        // Now create a module object with only pub members from the already-executed file
        const aliasConstant = makeConstant(makeStringValue(aliasToken.start, @intCast(aliasToken.length)));
        emitByte(@intFromEnum(OpCode.OP_IMPORT_FILE_AS));
        emitByte(pathConstant);
        emitByte(aliasConstant);
    }
}

// from math import sin, cos;
// from "file.mufi" import func1, func2;
pub fn fromImportStatement() void {
    // Check if it's a file import (string) or module import (identifier)
    if (check(.TOKEN_STRING)) {
        fromFileImportStatement();
        return;
    }

    consume(.TOKEN_IDENTIFIER, "Expect module name after 'from'.");
    const moduleName = parser.previous;

    consume(.TOKEN_IMPORT, "Expect 'import' after module name.");

    // Parse list of function names
    var count: u8 = 0; // Track number of imports (reserved for future validation/limits)
    while (true) {
        consume(.TOKEN_IDENTIFIER, "Expect function name.");
        const funcName = parser.previous;

        // Emit module name and function name as constants
        const moduleConstant = makeConstant(makeStringValue(moduleName.start, @intCast(moduleName.length)));
        const funcConstant = makeConstant(makeStringValue(funcName.start, @intCast(funcName.length)));

        emitByte(@intFromEnum(OpCode.OP_IMPORT_SPECIFIC));
        emitByte(moduleConstant);
        emitByte(funcConstant);

        count += 1;

        if (!match(.TOKEN_COMMA)) {
            break;
        }
    }

    consume(.TOKEN_SEMICOLON, "Expect ';' after import statement.");
}

// from "file.mufi" import func1, func2;
// Validates that each imported name is pub in the file
pub fn fromFileImportStatement() void {
    consume(.TOKEN_STRING, "Expect file path string after 'from'.");
    const filePath = parser.previous;

    consume(.TOKEN_IMPORT, "Expect 'import' after file path.");

    // The file path token includes quotes, so we need to remove them
    const pathStart = filePath.start + 1; // Skip opening quote
    const pathLength = filePath.length - 2; // Remove both quotes

    // First, import the file so its globals are available
    const pathConstant = makeConstant(makeStringValue(pathStart, @intCast(pathLength)));
    emitBytes(@intFromEnum(OpCode.OP_IMPORT_FILE), pathConstant);
    emitByte(@intFromEnum(OpCode.OP_POP));

    // Then validate each imported name is public
    var count: u8 = 0;
    while (true) {
        consume(.TOKEN_IDENTIFIER, "Expect function name.");
        const funcName = parser.previous;

        const pathConst = makeConstant(makeStringValue(pathStart, @intCast(pathLength)));
        const funcConst = makeConstant(makeStringValue(funcName.start, @intCast(funcName.length)));

        emitByte(@intFromEnum(OpCode.OP_FROM_IMPORT_FILE));
        emitByte(pathConst);
        emitByte(funcConst);

        count += 1;

        if (!match(.TOKEN_COMMA)) {
            break;
        }
    }

    consume(.TOKEN_SEMICOLON, "Expect ';' after import statement.");
}

pub fn pubDeclaration() void {
    // pub can only be used at the top level (global scope)
    if (current.?.scopeDepth > 0) {
        const suggestions = [_]errors.ErrorSuggestion{
            .{ .message = "'pub' can only be used for top-level declarations" },
            .{ .message = "Move the declaration to the top level, or remove 'pub'" },
        };
        errorWithSuggestions(&parser.previous, .EXPECTED_EXPRESSION, "'pub' can only be used at the top level.", &suggestions);
        return;
    }

    if (match(.TOKEN_FUN)) {
        pubFunDeclaration();
    } else if (match(.TOKEN_VAR)) {
        pubVarDeclaration();
    } else if (match(.TOKEN_SYM)) {
        pubSymDeclaration();
    } else if (match(.TOKEN_CONST)) {
        pubConstDeclaration();
    } else if (match(.TOKEN_CLASS)) {
        pubClassDeclaration();
    } else {
        const suggestions = [_]errors.ErrorSuggestion{
            .{ .message = "'pub' must be followed by 'fun', 'var', 'const', or 'class'" },
            .{ .message = "Example: pub fun myFunc() { ... }", .example = "pub var x = 5;" },
        };
        errorWithSuggestions(&parser.current, .EXPECTED_EXPRESSION, "Expect declaration after 'pub'.", &suggestions);
    }
}

pub fn pubFunDeclaration() void {
    const global = parseVariable("Expect function name.");
    markInitialized();
    function(.TYPE_FUNCTION);
    definePublicVariable(global);
}

pub fn pubVarDeclaration() void {
    const global = parseVariable("Expect variable name.");
    if (match(.TOKEN_EQUAL)) {
        expression();
    } else {
        emitByte(@intFromEnum(OpCode.OP_NIL));
    }
    consume(.TOKEN_SEMICOLON, "Expect ';' after variable declaration.");
    definePublicVariable(global);
}

pub fn pubSymDeclaration() void {
    // Parse public symbolic variable declarations: pub sym x; or pub sym x, y, z;
    const name = parseVariable("Expect variable name after 'sym'.");
    
    // Emit the symbolic variable declaration
    emitSymbolVariable(name);
    
    // Define the variable in the current scope as public
    definePublicVariable(name);
    
    // Handle multiple declarations: pub sym x, y, z;
    while (match(.TOKEN_COMMA)) {
        const next_name = parseVariable("Expect variable name after ','.");
        emitSymbolVariable(next_name);
        definePublicVariable(next_name);
    }
    
    consume(.TOKEN_SEMICOLON, "Expect ';' after symbolic variable declaration.");
}

pub fn pubConstDeclaration() void {
    const global = parseConstVariable("Expect constant name.");

    if (!match(.TOKEN_EQUAL)) {
        const suggestions = [_]errors.ErrorSuggestion{
            .{ .message = "Add an initialization value after '='" },
            .{ .message = "Constants must be given a value when declared" },
            .{ .message = "Initialize the constant", .example = "pub const PI = 3.14159;" },
        };
        errorWithSuggestions(&parser.current, .EXPECTED_EXPRESSION, "Constants must be initialized.", &suggestions);
        return;
    }

    expression();
    consume(.TOKEN_SEMICOLON, "Expect ';' after constant declaration.");
    definePublicConstVariable(global);
}

pub fn pubClassDeclaration() void {
    consume(.TOKEN_IDENTIFIER, "Expect class name.");
    const className = parser.previous;
    const nameConstant = identifierConstant(&parser.previous);
    declareVariable();
    emitBytes(@intFromEnum(OpCode.OP_CLASS), nameConstant);
    // Use pub define for the class
    definePublicVariable(nameConstant);
    var classCompiler: ClassCompiler = undefined;
    classCompiler.enclosing = currentClass;
    classCompiler.hasSuperclass = false;
    currentClass = &classCompiler;

    // Begin scope for methods and self
    beginScope();
    addLocal(syntheticToken("self"));

    if (match(.TOKEN_LESS)) {
        consume(.TOKEN_IDENTIFIER, "Expect superclass name.");
        variable(false);
        if (identifiersEqual(@constCast(&className), &parser.previous)) {
            const className_str = className.start[0..@intCast(className.length)];
            const suggestions = [_]errors.ErrorSuggestion{
                .{ .message = "Inherit from a different class" },
                .{ .message = "Remove the inheritance if not needed" },
                .{ .message = "Classes cannot inherit from themselves" },
            };
            errorWithSuggestions(&parser.previous, .CLASS_INHERITANCE_ERROR, std.fmt.allocPrint(compiler_arena.getCompilerAllocator(), "Class '{s}' cannot inherit from itself", .{className_str}) catch "Class cannot inherit from itself", &suggestions);
        }

        // Store the superclass in a local variable named "super"
        addLocal(syntheticToken("super"));
        namedVariable(parser.previous, false);
        defineVariable(0);

        namedVariable(className, false);
        emitByte(@intFromEnum(OpCode.OP_INHERIT));
        currentClass.?.hasSuperclass = true;
    }

    namedVariable(className, false);
    consume(.TOKEN_LEFT_BRACE, "Expect '{' before class body.");
    while (!check(.TOKEN_RIGHT_BRACE) and !check(.TOKEN_EOF)) {
        method();
    }
    consume(.TOKEN_RIGHT_BRACE, "Expect '}' after class body.");
    emitByte(@intFromEnum(OpCode.OP_POP));

    // End scope for methods, self, and super
    endScope();

    currentClass = currentClass.?.enclosing;
}

pub fn funDeclaration() void {
    const global = parseVariable("Expect function name.");
    markInitialized();
    function(.TYPE_FUNCTION);
    defineVariable(global);
}
pub fn varDeclaration() void {
    const global = parseVariable("Expect variable name.");

    // Check for optional type annotation: ": typename"
    if (match(.TOKEN_COLON)) {
        if (parser.current.type == .TOKEN_IDENTIFIER) {
            const type_name = parser.current.start[0..@intCast(parser.current.length)];
            const annotated_type = type_annotations.parseTypeNameString(type_name);

            if (annotated_type == null) {
                errorAtCurrent("Unknown type name");
            }
            advance();
        } else {
            errorAtCurrent("Expect type name after ':'");
        }
    }

    if (match(.TOKEN_EQUAL)) {
        expression();
    } else {
        emitByte(@intFromEnum(OpCode.OP_NIL));
    }
    consume(.TOKEN_SEMICOLON, "Expect ';' after variable declaration.");
    defineVariable(global);
}

pub fn symDeclaration() void {
    // Parse symbolic variable declarations: sym x; or sym x, y, z;
    const name = parseVariable("Expect variable name after 'sym'.");
    
    // Emit the symbolic variable declaration
    emitSymbolVariable(name);
    
    // Define the variable in the current scope
    defineVariable(name);
    
    // Handle multiple declarations: sym x, y, z;
    while (match(.TOKEN_COMMA)) {
        const next_name = parseVariable("Expect variable name after ','.");
        emitSymbolVariable(next_name);
        defineVariable(next_name);
    }
    
    consume(.TOKEN_SEMICOLON, "Expect ';' after symbolic variable declaration.");
}

pub fn constDeclaration() void {
    const global = parseConstVariable("Expect constant name.");

    // Constants MUST be initialized
    if (!match(.TOKEN_EQUAL)) {
        const suggestions = [_]errors.ErrorSuggestion{
            .{ .message = "Add an initialization value after '='" },
            .{ .message = "Constants must be given a value when declared" },
            .{ .message = "Initialize the constant", .example = "const PI = 3.14159;" },
        };
        errorWithSuggestions(&parser.current, .EXPECTED_EXPRESSION, "Constants must be initialized.", &suggestions);
        return;
    }

    expression();
    consume(.TOKEN_SEMICOLON, "Expect ';' after constant declaration.");
    defineConstVariable(global);
}

pub fn expressionStatement() void {
    expression();
    consume(.TOKEN_SEMICOLON, "Expect ';' after expression.");
    emitByte(@intFromEnum(OpCode.OP_POP));
}
pub fn forStatement() void {
    beginScope();
    consume(.TOKEN_LEFT_PAREN, "Expect '(' after 'for'.");
    if (match(.TOKEN_SEMICOLON)) {} else if (match(.TOKEN_VAR)) {
        varDeclaration();
    } else {
        expressionStatement();
    }
    var loopStart: i32 = currentChunk().*.count;
    var exitJump: i32 = -1;
    if (!match(.TOKEN_SEMICOLON)) {
        expression();
        consume(.TOKEN_SEMICOLON, "Expect ';' after loop condition.");
        exitJump = emitJump(@intFromEnum(OpCode.OP_JUMP_IF_FALSE));
        emitByte(@intFromEnum(OpCode.OP_POP));
    }

    // Set up loop tracking for break/continue
    var loop = Loop.init(current.?.innermostLoop, loopStart, current.?.scopeDepth, .FOR);
    defer loop.deinit();
    current.?.innermostLoop = &loop;

    if (!match(.TOKEN_RIGHT_PAREN)) {
        const bodyJump = emitJump(@intFromEnum(OpCode.OP_JUMP));
        const incrementStart: i32 = currentChunk().*.count;
        expression();
        emitByte(@intFromEnum(OpCode.OP_POP));
        consume(.TOKEN_RIGHT_PAREN, "Expect ')' after for clauses.");
        emitLoop(loopStart);
        loopStart = incrementStart;
        loop.start = incrementStart; // Update loop start for continue to jump to increment
        patchJump(bodyJump);
    }
    statement();
    emitLoop(loopStart);
    if (exitJump != -1) {
        patchJump(exitJump);
        emitByte(@intFromEnum(OpCode.OP_POP));
    }

    // Patch all break jumps to point here
    for (loop.breakJumps.items) |breakJump| {
        patchJump(breakJump);
    }

    // For loops shouldn't have continue jumps to patch (they use direct loops)
    // But let's be safe and patch them if they exist
    for (loop.continueJumps.items) |continueJump| {
        patchJump(continueJump);
    }

    // Restore the enclosing loop
    current.?.innermostLoop = loop.enclosing;

    endScope();
}
// eachStatement function removed - it was using removed iterator opcodes
pub fn foreachStatement() void {
    beginScope();

    // Parse: foreach (item in collection)
    consume(.TOKEN_LEFT_PAREN, "Expect '(' after 'foreach'.");
    consume(.TOKEN_IDENTIFIER, "Expect variable name.");
    const itemName = parser.previous;
    consume(.TOKEN_IN, "Expect 'in' after loop variable.");

    // Parse and immediately store the collection
    expression();
    consume(.TOKEN_RIGHT_PAREN, "Expect ')' after collection.");

    // Collection is now on stack - store it in a local variable
    const collectionSlot = current.?.localCount;
    addLocal(syntheticToken("__collection"));
    markInitialized();

    // Initialize index = 0
    const indexSlot = current.?.localCount;
    addLocal(syntheticToken("__index"));
    markInitialized();
    emitConstant(Value.init_int(0));

    // Declare the loop item variable
    const itemSlot = current.?.localCount;
    addLocal(itemName);
    markInitialized();
    emitByte(@intFromEnum(OpCode.OP_NIL));

    // Main loop start
    const loopStart: i32 = @intCast(currentChunk().*.count);

    // Condition: index < collection.length
    emitBytes(@intFromEnum(OpCode.OP_GET_LOCAL), @intCast(indexSlot));
    emitBytes(@intFromEnum(OpCode.OP_GET_LOCAL), @intCast(collectionSlot));
    emitByte(@intFromEnum(OpCode.OP_LENGTH));
    emitByte(@intFromEnum(OpCode.OP_LESS));

    // Exit if condition is false
    const exitJump: i32 = emitJump(@intFromEnum(OpCode.OP_JUMP_IF_FALSE));
    emitByte(@intFromEnum(OpCode.OP_POP));

    // Set item = collection[index]
    emitBytes(@intFromEnum(OpCode.OP_GET_LOCAL), @intCast(collectionSlot));
    emitBytes(@intFromEnum(OpCode.OP_GET_LOCAL), @intCast(indexSlot));
    emitByte(@intFromEnum(OpCode.OP_GET_INDEX));
    emitBytes(@intFromEnum(OpCode.OP_SET_LOCAL), @intCast(itemSlot));
    emitByte(@intFromEnum(OpCode.OP_POP));

    // Set up loop tracking for break/continue before executing body
    // For foreach, we'll patch continue jumps later to jump to increment
    var loop = Loop.init(current.?.innermostLoop, loopStart, current.?.scopeDepth, .FOREACH);
    defer loop.deinit();
    current.?.innermostLoop = &loop;

    // Execute the loop body
    statement();

    // Continue point: increment index (continue jumps here)
    const incrementStart: i32 = @intCast(currentChunk().*.count);
    _ = incrementStart; // autofix

    // Patch all continue jumps to point to increment start
    for (loop.continueJumps.items) |continueJump| {
        patchJump(continueJump);
    }

    // Increment: index = index + 1
    emitBytes(@intFromEnum(OpCode.OP_GET_LOCAL), @intCast(indexSlot));
    emitConstant(Value.init_int(1));
    emitByte(@intFromEnum(OpCode.OP_ADD));
    emitBytes(@intFromEnum(OpCode.OP_SET_LOCAL), @intCast(indexSlot));
    emitByte(@intFromEnum(OpCode.OP_POP));

    // Jump back to condition check
    emitLoop(loopStart);

    // Patch exit jump
    patchJump(exitJump);
    emitByte(@intFromEnum(OpCode.OP_POP));

    // Patch all break jumps to point here
    for (loop.breakJumps.items) |breakJump| {
        patchJump(breakJump);
    }

    // Restore the enclosing loop
    current.?.innermostLoop = loop.enclosing;

    endScope();
}

pub fn ifStatement() void {
    consume(.TOKEN_LEFT_PAREN, "Expect '(' after 'if'.");
    expression();
    consume(.TOKEN_RIGHT_PAREN, "Expect ')' after condition.");
    const thenJump = emitJump(@intFromEnum(OpCode.OP_JUMP_IF_FALSE));
    emitByte(@intFromEnum(OpCode.OP_POP));
    statement();
    const elseJump = emitJump(@intFromEnum(OpCode.OP_JUMP));
    patchJump(thenJump);
    emitByte(@intFromEnum(OpCode.OP_POP));
    if (match(.TOKEN_ELSE)) {
        statement();
    }
    patchJump(elseJump);
}
pub fn printStatement() void {
    expression();
    consume(.TOKEN_SEMICOLON, "Expect ';' after value.");
    emitByte(@intFromEnum(OpCode.OP_PRINT));
}
pub fn returnStatement() void {
    if (current.?.type_ == .TYPE_SCRIPT) {
        const suggestions = [_]errors.ErrorSuggestion{
            .{ .message = "Use return statements only inside functions" },
            .{ .message = "Remove the return statement from global scope" },
            .{ .message = "Use return in functions", .example = "fun example() { return value; }" },
        };
        errorWithSuggestions(&parser.previous, .INVALID_RETURN, "Cannot return from top-level code", &suggestions);
    }
    if (match(.TOKEN_SEMICOLON)) {
        emitReturn();
    } else {
        if (current.?.type_ == .TYPE_INITIALIZER) {
            const suggestions = [_]errors.ErrorSuggestion{
                .{ .message = "Use 'return;' without a value in initializers" },
                .{ .message = "Initializers automatically return the instance" },
                .{ .message = "Use return without value in initializers", .example = "init() { this.property = value; return; }" },
            };
            errorWithSuggestions(&parser.previous, .INVALID_RETURN, "Cannot return a value from an initializer", &suggestions);
        }

        // Simple approach: parse the expression and check if last instruction was OP_CALL
        const chunkBeforeExpr = currentChunk().count;
        expression();
        consume(.TOKEN_SEMICOLON, "Expect ';' after return value.");

        // Check if the last two bytes were OP_CALL + argCount, and convert to tail call
        const chunk = currentChunk();
        if (chunk.count >= chunkBeforeExpr + 2 and
            chunk.code.?[@intCast(chunk.count - 2)] == @intFromEnum(OpCode.OP_CALL))
        {
            // Replace OP_CALL with OP_TAIL_CALL for tail position calls
            chunk.code.?[@intCast(chunk.count - 2)] = @intFromEnum(OpCode.OP_TAIL_CALL);
            // Don't emit OP_RETURN for tail calls - the tail call handles it
        } else {
            emitByte(@intFromEnum(OpCode.OP_RETURN));
        }
    }
}
pub fn whileStatement() void {
    beginScope();

    const loopStart: i32 = @intCast(currentChunk().*.count);

    // Set up loop tracking for break/continue
    var loop = Loop.init(current.?.innermostLoop, loopStart, current.?.scopeDepth, .WHILE);
    defer loop.deinit();
    current.?.innermostLoop = &loop;

    consume(.TOKEN_LEFT_PAREN, "Expect '(' after 'while'.");
    expression();
    consume(.TOKEN_RIGHT_PAREN, "Expect ')' after condition.");
    const exitJump = emitJump(@intFromEnum(OpCode.OP_JUMP_IF_FALSE));
    emitByte(@intFromEnum(OpCode.OP_POP));
    statement();
    emitLoop(loopStart);
    patchJump(exitJump);
    emitByte(@intFromEnum(OpCode.OP_POP));

    // Patch all break jumps to point here
    for (loop.breakJumps.items) |breakJump| {
        patchJump(breakJump);
    }

    // Patch all continue jumps to point to loop start
    for (loop.continueJumps.items) |continueJump| {
        patchJump(continueJump);
    }

    // Restore previous loop
    current.?.innermostLoop = loop.enclosing;

    endScope();
}

pub fn breakStatement() void {
    if (current.?.innermostLoop == null) {
        @"error"("'break' statement must be inside a loop.");
        consume(.TOKEN_SEMICOLON, "Expect ';' after 'break'.");
        return;
    }

    consume(.TOKEN_SEMICOLON, "Expect ';' after 'break'.");

    // Emit a jump that will be patched to jump to the end of the loop
    const jump = emitJump(@intFromEnum(OpCode.OP_JUMP));
    current.?.innermostLoop.?.breakJumps.append(compiler_arena.getCompilerAllocator(), jump) catch unreachable;
}

pub fn continueStatement() void {
    if (current.?.innermostLoop == null) {
        @"error"("'continue' statement must be inside a loop.");
        consume(.TOKEN_SEMICOLON, "Expect ';' after 'continue'.");
        return;
    }

    consume(.TOKEN_SEMICOLON, "Expect ';' after 'continue'.");

    // For foreach loops, we need to emit a jump that will be patched later
    // For other loops, we can emit the loop instruction directly
    if (current.?.innermostLoop.?.loopType == .FOREACH) {
        // Emit a jump that will be patched to jump to the increment section
        const jump = emitJump(@intFromEnum(OpCode.OP_JUMP));
        current.?.innermostLoop.?.continueJumps.append(compiler_arena.getCompilerAllocator(), jump) catch unreachable;
    } else {
        // Emit a loop instruction to jump back to the start of the loop
        emitLoop(current.?.innermostLoop.?.start);
    }
}

/// Record a jump-to-end in the switch statement's end jump table.
fn recordEndJump(endJumps: *[256]i32, endJumpCount: *usize) void {
    const jump = emitJump(@intFromEnum(OpCode.OP_JUMP));
    if (endJumpCount.* < 256) {
        endJumps.*[endJumpCount.*] = jump;
        endJumpCount.* += 1;
    }
}

/// Parse a switch case body (block `{ ... }` or single expression) with break handling.
/// After the body, emits a jump to the end of the switch.
fn parseSwitchCaseBody(endJumps: *[256]i32, endJumpCount: *usize) void {
    if (match(.TOKEN_LEFT_BRACE)) {
        beginScope();
        while (!check(.TOKEN_RIGHT_BRACE) and !check(.TOKEN_EOF)) {
            if (match(.TOKEN_BREAK)) {
                consume(.TOKEN_SEMICOLON, "Expect ';' after break.");
                recordEndJump(endJumps, endJumpCount);
                break;
            } else {
                statement();
            }
        }
        consume(.TOKEN_RIGHT_BRACE, "Expect '}' after case body.");
        endScope();
    } else {
        expression();
        emitByte(@intFromEnum(OpCode.OP_POP));
        if (match(.TOKEN_BREAK)) {
            consume(.TOKEN_SEMICOLON, "Expect ';' after break.");
            recordEndJump(endJumps, endJumpCount);
        }
    }
    // Jump to end of switch after executing case
    recordEndJump(endJumps, endJumpCount);
}

/// Emit a standard equality comparison against the switch variable.
/// Emits: GET_LOCAL(switchVarSlot), OP_EQUAL, JUMP_IF_FALSE, OP_POP.
/// Returns the skip jump offset to patch later.
fn emitCaseComparison(switchVarSlot: i32) i32 {
    emitBytes(@intFromEnum(OpCode.OP_GET_LOCAL), @intCast(switchVarSlot));
    emitByte(@intFromEnum(OpCode.OP_EQUAL));
    const skipJump = emitJump(@intFromEnum(OpCode.OP_JUMP_IF_FALSE));
    emitByte(@intFromEnum(OpCode.OP_POP));
    return skipJump;
}

pub fn switchStatement() void {
    consume(.TOKEN_LEFT_PAREN, "Expect '(' after 'switch'.");
    expression();
    consume(.TOKEN_RIGHT_PAREN, "Expect ')' after switch condition.");
    consume(.TOKEN_LEFT_BRACE, "Expect '{' before switch cases.");

    // Store the switch expression value in a local variable for reuse
    beginScope();
    const switchVarSlot = current.?.localCount;
    addLocal(syntheticToken("__switch_value"));
    markInitialized();
    emitBytes(@intFromEnum(OpCode.OP_SET_LOCAL), @intCast(switchVarSlot));

    var endJumps: [256]i32 = undefined;
    var endJumpCount: usize = 0;
    var hasDefault: bool = false;
    var defaultJump: i32 = -1;

    while (!check(.TOKEN_RIGHT_BRACE) and !check(.TOKEN_EOF)) {
        if (check(.TOKEN_IDENTIFIER) and parser.current.length == 1 and parser.current.start[0] == '_') {
            // Default case: _ => ...
            advance();
            consume(.TOKEN_ARROW, "Expect '=>' after default case.");

            if (hasDefault) {
                @"error"("Cannot have more than one default case in a switch statement.");
            }
            hasDefault = true;
            defaultJump = @intCast(currentChunk().*.count);

            // Parse default body
            if (match(.TOKEN_LEFT_BRACE)) {
                beginScope();
                block();
                endScope();
            } else {
                expression();
                emitByte(@intFromEnum(OpCode.OP_POP));
            }
            recordEndJump(&endJumps, &endJumpCount);
        } else if (check(.TOKEN_CASE)) {
            advance(); // consume 'case'

            if (check(.TOKEN_INT) or check(.TOKEN_DOUBLE) or check(.TOKEN_IDENTIFIER)) {
                parsePrecedence(@as(c_uint, @bitCast(PREC_RANGE + 1)));

                if (check(.TOKEN_RANGE_EXCLUSIVE) or check(.TOKEN_RANGE_INCLUSIVE)) {
                    // Range pattern: case 1..5 => or case 1..=5 =>
                    const isInclusive = match(.TOKEN_RANGE_INCLUSIVE);
                    if (!isInclusive) {
                        consume(.TOKEN_RANGE_EXCLUSIVE, "Expect range operator '..' or '..='");
                    }
                    parsePrecedence(@as(c_uint, @bitCast(PREC_RANGE + 1)));

                    // Store end value in a temporary local
                    beginScope();
                    addLocal(syntheticToken("__case_range_end"));
                    markInitialized();
                    const rangeEndSlot = current.?.localCount - 1;
                    emitBytes(@intFromEnum(OpCode.OP_SET_LOCAL), @intCast(rangeEndSlot));

                    // Check: switch_value >= start (i.e. !(start < switch_value is false) => !(switch < start))
                    emitBytes(@intFromEnum(OpCode.OP_GET_LOCAL), @intCast(switchVarSlot));
                    emitByte(@intFromEnum(OpCode.OP_LESS));
                    emitByte(@intFromEnum(OpCode.OP_NOT));
                    const skipStartCheck = emitJump(@intFromEnum(OpCode.OP_JUMP_IF_FALSE));
                    emitByte(@intFromEnum(OpCode.OP_POP));

                    // Check: switch_value <= end (inclusive) or switch_value < end (exclusive)
                    emitBytes(@intFromEnum(OpCode.OP_GET_LOCAL), @intCast(switchVarSlot));
                    emitBytes(@intFromEnum(OpCode.OP_GET_LOCAL), @intCast(rangeEndSlot));
                    if (isInclusive) {
                        emitByte(@intFromEnum(OpCode.OP_GREATER));
                        emitByte(@intFromEnum(OpCode.OP_NOT));
                    } else {
                        emitByte(@intFromEnum(OpCode.OP_LESS));
                    }
                    const skipEndCheck = emitJump(@intFromEnum(OpCode.OP_JUMP_IF_FALSE));
                    emitByte(@intFromEnum(OpCode.OP_POP));

                    consume(.TOKEN_ARROW, "Expect '=>' after range pattern.");
                    parseSwitchCaseBody(&endJumps, &endJumpCount);

                    // Patch skip jumps for failed range checks
                    patchJump(skipStartCheck);
                    patchJump(skipEndCheck);
                    emitByte(@intFromEnum(OpCode.OP_POP));
                    endScope();
                } else {
                    // Regular case value (already parsed)
                    consume(.TOKEN_ARROW, "Expect '=>' after case value.");
                    const skipCaseJump = emitCaseComparison(switchVarSlot);
                    parseSwitchCaseBody(&endJumps, &endJumpCount);
                    patchJump(skipCaseJump);
                }
            } else {
                // Other expression types
                parsePrecedence(@as(c_uint, @bitCast(PREC_TERM + 1)));
                consume(.TOKEN_ARROW, "Expect '=>' after case value.");
                const skipCaseJump = emitCaseComparison(switchVarSlot);
                parseSwitchCaseBody(&endJumps, &endJumpCount);
                patchJump(skipCaseJump);
            }
        } else {
            // Original syntax: expr => ...
            parsePrecedence(@as(c_uint, @bitCast(PREC_TERM + 1)));
            emitBytes(@intFromEnum(OpCode.OP_GET_LOCAL), @intCast(switchVarSlot));
            consume(.TOKEN_ARROW, "Expect '=>' after case value.");
            emitBytes(@intFromEnum(OpCode.OP_GET_LOCAL), @intCast(switchVarSlot));
            emitByte(@intFromEnum(OpCode.OP_EQUAL));
            const skipCaseJump = emitJump(@intFromEnum(OpCode.OP_JUMP_IF_FALSE));
            emitByte(@intFromEnum(OpCode.OP_POP));
            parseSwitchCaseBody(&endJumps, &endJumpCount);
            patchJump(skipCaseJump);
            emitByte(@intFromEnum(OpCode.OP_POP));
        }

        _ = match(.TOKEN_COMMA);
    }

    if (hasDefault) emitLoop(defaultJump);

    for (0..endJumpCount) |i| {
        patchJump(endJumps[i]);
    }

    endScope();
    consume(.TOKEN_RIGHT_BRACE, "Expect '}' after switch cases.");
}

pub fn synchronize() void {
    parser.panicMode = false;
    while (parser.current.type != .TOKEN_EOF) {
        if (parser.previous.type == .TOKEN_SEMICOLON) return;
        switch (parser.current.type) {
            else => return,
        }
        advance();
    }
}

pub fn compile(source: [*]const u8, file_path: ?[]const u8) ?*ObjFunction {
    // Initialize compiler arena for temporary allocations
    compiler_arena.initCompilerArena();
    defer compiler_arena.deinitCompilerArena();

    // NOTE: Removed resetGlobals() - it was clearing stdlib functions!
    // TODO: Implement proper separation between stdlib and user globals
    // vm_h.resetGlobals();

    // Initialize Global Analyzer for this script
    const analyzer_allocator = compiler_arena.getCompilerAllocator();
    var analyzer = GlobalAnalyzer.init(analyzer_allocator);
    defer analyzer.deinit();

    // Pre-pass: Scan for assignments to globals
    scanner_h.init_scanner(@constCast(source));
    var nesting: i32 = 0;
    var prev_token: scanner_h.Token = undefined;
    prev_token.type = .TOKEN_EOF;

    while (true) {
        const token = scanner_h.scanToken();
        if (token.type == .TOKEN_EOF) break;
        if (token.type == .TOKEN_LEFT_BRACE) nesting += 1;
        if (token.type == .TOKEN_RIGHT_BRACE) nesting -= 1;

        // We only care about global declarations (nesting == 0)
        if (nesting == 0 and (token.type == .TOKEN_VAR or token.type == .TOKEN_CONST or token.type == .TOKEN_PUB)) {
            // Found a declaration, record it
            var is_var = token.type == .TOKEN_VAR;
            var next = scanner_h.scanToken();
            if (token.type == .TOKEN_PUB and next.type == .TOKEN_VAR) {
                is_var = true;
                next = scanner_h.scanToken();
            } else if (token.type == .TOKEN_PUB and (next.type == .TOKEN_CONST or next.type == .TOKEN_FUN or next.type == .TOKEN_CLASS)) {
                next = scanner_h.scanToken();
            }
            if (next.type == .TOKEN_IDENTIFIER) {
                const name = next.start[0..@intCast(next.length)];
                if (is_var) {
                    analyzer.recordAssignment(name);
                    analyzer.recordAssignment(name); // Force var to be mutable
                } else {
                    analyzer.recordAssignment(name);
                }
            }
            prev_token = next;
            continue;
        } else if (token.type == .TOKEN_EQUAL or token.type == .TOKEN_PLUS_EQUAL or token.type == .TOKEN_MINUS_EQUAL or token.type == .TOKEN_STAR_EQUAL or token.type == .TOKEN_SLASH_EQUAL or token.type == .TOKEN_PLUS_PLUS or token.type == .TOKEN_MINUS_MINUS) {
            // Any assignment re-evaluates the constness
            if (prev_token.type == .TOKEN_IDENTIFIER) {
                const name = prev_token.start[0..@intCast(prev_token.length)];
                analyzer.recordAssignment(name);
            }
        }

        prev_token = token;
    }
    global_analyzer = analyzer;
    defer global_analyzer = null;

    // Initialize error manager if not already done
    if (!errorManagerInitialized) {
        const allocator = mem_utils.getAllocator();
        globalErrorManager = errors.ErrorManager.init(allocator);
        knownVariables = std.ArrayList([]const u8).initCapacity(allocator, 0) catch unreachable;
        errorManagerInitialized = true;
    } else {
        globalErrorManager.reset();
        knownVariables.clearRetainingCapacity();
    }

    // Set scanner error manager
    setScannerErrorManager();

    scanner_h.init_scanner(@constCast(source));
    var compiler: Compiler = undefined;
    initCompiler(&compiler, .TYPE_SCRIPT);

    // Set source file on the top-level script function
    if (file_path) |path| {
        compiler.function.*.source_file = object_h.copyStringLiteral(path.ptr, path.len);
        parser.currentFile = path;
    } else {
        parser.currentFile = "<script>";
    }

    parser.hadError = false;
    parser.panicMode = false;
    advance();
    while (!match(.TOKEN_EOF)) {
        declaration();
    }
    const function_1 = endCompiler();

    // Optimize the compiled bytecode
    if (!parser.hadError) {
        _ = bytecode_optimizer.optimize(&function_1.chunk, bytecode_optimizer.OptimizerConfig.disabled());
    }

    return if (parser.hadError) null else function_1;
}
