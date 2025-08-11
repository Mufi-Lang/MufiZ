const print = @import("std").debug.print;
const std = @import("std");

const debug_opts = @import("debug");

const chunk_h = @import("chunk.zig");
const Chunk = chunk_h.Chunk;
const OpCode = chunk_h.OpCode;
const debug_h = @import("debug.zig");
const errors = @import("errors.zig");
const mem_utils = @import("mem_utils.zig");
const memcmp = mem_utils.memcmp;
const object_h = @import("object.zig");
const ObjFunction = object_h.ObjFunction;
const scanner_h = @import("scanner.zig");
const Token = scanner_h.Token;
const TokenType = scanner_h.TokenType;
const strlen = @import("mem_utils.zig").strlen;
const value_h = @import("value.zig");
const Value = value_h.Value;
const Complex = value_h.Complex;
const vm_h = @import("vm.zig");

// Global error manager and variable tracking
pub var globalErrorManager: errors.ErrorManager = undefined;
var knownVariables: std.ArrayList([]const u8) = undefined;
pub var errorManagerInitialized: bool = false;

// Track all declared variables for suggestion system
pub fn addKnownVariable(name: []const u8) void {
    if (errorManagerInitialized) {
        knownVariables.append(name) catch {};
    }
}

pub fn findSimilarVariables(name: []const u8, allocator: std.mem.Allocator) []const []const u8 {
    if (!errorManagerInitialized) return &[_][]const u8{};

    var similar = std.ArrayList([]const u8).init(allocator);

    for (knownVariables.items) |candidate| {
        const distance = errors.levenshteinDistance(name, candidate);
        if (distance <= 2 and distance > 0 and !std.mem.eql(u8, name, candidate)) {
            similar.append(candidate) catch break;
        }
    }

    return similar.toOwnedSlice() catch &[_][]const u8{};
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

pub const Parser = struct {
    current: Token,
    previous: Token,
    hadError: bool,
    panicMode: bool,
    currentFile: ?[]const u8 = null,
};

pub const PREC_NONE: i32 = 0;
pub const PREC_ASSIGNMENT: i32 = 1;
pub const PREC_OR: i32 = 2;
pub const PREC_AND: i32 = 3;
pub const PREC_EQUALITY: i32 = 4;
pub const PREC_COMPARISON: i32 = 5;
pub const PREC_TERM: i32 = 6;
pub const PREC_RANGE: i32 = 7; // Between PREC_TERM and PREC_FACTOR
pub const PREC_FACTOR: i32 = 8;
pub const PREC_EXPONENT: i32 = 9;
pub const PREC_UNARY: i32 = 10;
pub const PREC_CALL: i32 = 11;
pub const PREC_INDEX: i32 = 12;
pub const PREC_PRIMARY: i32 = 13;
pub const Precedence = u32;

// We'll remove the OP_ROT_THREE opcode and use a simpler approach

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
        return Loop{
            .enclosing = enclosing,
            .start = start,
            .scopeDepth = scopeDepth,
            .breakJumps = std.ArrayList(i32).init(std.heap.page_allocator),
            .continueJumps = std.ArrayList(i32).init(std.heap.page_allocator),
            .loopType = loopType,
        };
    }

    pub fn deinit(self: *Loop) void {
        self.breakJumps.deinit();
        self.continueJumps.deinit();
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
        .column = 1, // TODO: Calculate actual column from token position
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
        emitBytes(@intCast(@intFromEnum(OpCode.OP_GET_LOCAL)), 0);
    } else {
        emitByte(@intCast(@intFromEnum(OpCode.OP_NIL)));
    }
    emitByte(@intCast(@intFromEnum(OpCode.OP_RETURN)));
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

// Emit a single byte opcode
pub fn emitSingleByte(byte: u8) void {
    chunk_h.writeChunk(currentChunk(), byte, parser.previous.line);
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
    current = compiler;

    // Set function name if not a script
    if (type_ != .TYPE_SCRIPT) {
        current.?.function.*.name = object_h.copyString(parser.previous.start, @intCast(parser.previous.length));
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
// pub fn initCompiler(compiler: [*c]Compiler, type_: FunctionType) void {
//     compiler.*.enclosing = current;
//     compiler.*.function = null;
//     compiler.*.type_ = type_;
//     compiler.*.localCount = 0;
//     compiler.*.scopeDepth = 0;
//     compiler.*.function = object_h.newFunction();
//     current = compiler;
//     if (type_ != .TYPE_SCRIPT) {
//         current.*.function.*.name = object_h.copyString(parser.previous.start, parser.previous.length);
//     }
//     current.*.localCount += 1;
//     const local: [*c]Local = &current.*.locals[@intCast(current.*.localCount)];
//     local.*.depth = 0;
//     local.*.isCaptured = false;
//     if (type_ != .TYPE_FUNCTION) {
//         local.*.name.start = @ptrCast(@constCast("self"));
//         local.*.name.length = 4;
//     } else {
//         local.*.name.start = @ptrCast(@constCast(""));
//         local.*.name.length = 0;
//     }
// }

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
            emitByte(@intCast(@intFromEnum(OpCode.OP_CLOSE_UPVALUE)));
        } else {
            emitByte(@intCast(@intFromEnum(OpCode.OP_POP)));
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
    if (match(.TOKEN_CLASS)) {
        classDeclaration();
    } else if (match(.TOKEN_FUN)) {
        funDeclaration();
    } else if (match(.TOKEN_VAR)) {
        varDeclaration();
    } else if (match(.TOKEN_CONST)) {
        constDeclaration();
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
    if (canAssign and match(.TOKEN_EQUAL)) {
        const suggestions = [_]errors.ErrorSuggestion{
            .{ .message = "You can only assign to variables and object properties" },
            .{ .message = "Check that the left side is a valid assignment target" },
            .{ .message = "Use valid assignment targets", .example = "variable = value, object.property = value" },
        };
        errorWithSuggestions(&parser.previous, .INVALID_ASSIGNMENT, "Invalid assignment target", &suggestions);
    }
}

pub fn identifierConstant(name: *Token) u8 {
    return makeConstant(Value{
        .type = .VAL_OBJ,
        .as = .{
            .obj = @ptrCast(object_h.copyString(name.*.start, @intCast(name.*.length))),
        },
    });
}
pub fn identifiersEqual(a: *Token, b: *Token) bool {
    if (a.*.length != b.*.length) return false;
    return scanner_h.memcmp(@as(?*const anyopaque, @ptrCast(a.*.start)), @as(?*const anyopaque, @ptrCast(b.*.start)), @as(c_ulong, @bitCast(@as(c_long, a.*.length)))) == 0;
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
pub fn declareVariable() void {
    if (current.?.scopeDepth == 0) return;
    const name: *Token = &parser.previous;
    {
        var i: i32 = current.?.localCount - 1;
        _ = &i;
        while (i >= 0) : (i -= 1) {
            var local: *Local = &current.?.locals[@as(c_uint, @intCast(i))];
            _ = &local;
            if ((local.*.depth != -1) and (local.*.depth < current.?.scopeDepth)) {
                break;
            }
            if (identifiersEqual(name, &local.*.name)) {
                const varName = name.start[0..@intCast(name.length)];
                const suggestions = [_]errors.ErrorSuggestion{
                    .{ .message = "Use a different variable name" },
                    .{ .message = "Variables in the same scope must have unique names" },
                    .{ .message = "Try alternative names", .example = std.fmt.allocPrint(std.heap.page_allocator, "{s}2, new{s}, {s}Value", .{ varName, varName, varName }) catch "newName, value2" },
                };
                errorWithSuggestions(&parser.previous, .REDEFINED_VARIABLE, std.fmt.allocPrint(std.heap.page_allocator, "Variable '{s}' already declared in this scope", .{varName}) catch "Variable already declared", &suggestions);
                return;
            }
        }
    }
    addLocal(name.*);
}

pub fn declareConstVariable() void {
    if (current.?.scopeDepth == 0) return;
    const name: *Token = &parser.previous;
    {
        var i: i32 = current.?.localCount - 1;
        _ = &i;
        while (i >= 0) : (i -= 1) {
            var local: *Local = &current.?.locals[@as(c_uint, @intCast(i))];
            _ = &local;
            if ((local.*.depth != -1) and (local.*.depth < current.?.scopeDepth)) {
                break;
            }
            if (identifiersEqual(name, &local.*.name)) {
                const varName = name.start[0..@intCast(name.length)];
                const suggestions = [_]errors.ErrorSuggestion{
                    .{ .message = "Use a different constant name" },
                    .{ .message = "Constants in the same scope must have unique names" },
                    .{ .message = "Try alternative names", .example = std.fmt.allocPrint(std.heap.page_allocator, "{s}2, new{s}, {s}Value", .{ varName, varName, varName }) catch "newName, value2" },
                };
                errorWithSuggestions(&parser.previous, .REDEFINED_VARIABLE, std.fmt.allocPrint(std.heap.page_allocator, "Constant '{s}' already declared in this scope", .{varName}) catch "Constant already declared", &suggestions);
                return;
            }
        }
    }
    addConstLocal(name.*);
}

pub fn parseVariable(message: [*]const u8) u8 {
    consume(.TOKEN_IDENTIFIER, message);
    declareVariable();
    if (current.?.scopeDepth > 0) return 0;
    return identifierConstant(&parser.previous);
}

pub fn parseConstVariable(message: [*]const u8) u8 {
    consume(.TOKEN_IDENTIFIER, message);
    declareConstVariable();
    if (current.?.scopeDepth > 0) return 0;
    return identifierConstant(&parser.previous);
}
pub fn markInitialized() void {
    if (current.?.scopeDepth == 0) return;
    current.?.locals[@as(c_uint, @intCast(current.?.localCount - 1))].depth = current.?.scopeDepth;
}
pub fn defineVariable(global: u8) void {
    if (current.?.scopeDepth > 0) {
        markInitialized();
        return;
    }

    // Track global variable for suggestion system
    if (errorManagerInitialized and global < currentChunk().*.constants.count) {
        const constant = currentChunk().*.constants.values[@intCast(global)];
        if (constant.type == .VAL_OBJ and object_h.isObjType(constant, .OBJ_STRING)) {
            const objString = @as(*object_h.ObjString, @ptrCast(@alignCast(constant.as.obj)));
            const varName = objString.chars[0..@intCast(objString.length)];
            addKnownVariable(varName);
        }
    }

    emitBytes(@intCast(@intFromEnum(OpCode.OP_DEFINE_GLOBAL)), global);
}

pub fn defineConstVariable(global: u8) void {
    if (current.?.scopeDepth > 0) {
        markInitialized();
        return;
    }

    // Track global constant for suggestion system
    if (errorManagerInitialized and global < currentChunk().*.constants.count) {
        const constant = currentChunk().*.constants.values[@intCast(global)];
        if (constant.type == .VAL_OBJ and object_h.isObjType(constant, .OBJ_STRING)) {
            const objString = @as(*object_h.ObjString, @ptrCast(@alignCast(constant.as.obj)));
            const varName = objString.chars[0..@intCast(objString.length)];
            addKnownVariable(varName);
        }
    }

    emitBytes(@intCast(@intFromEnum(OpCode.OP_DEFINE_GLOBAL)), global);
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
pub fn and_(canAssign: bool) void {
    _ = canAssign;
    var endJump: i32 = emitJump(@intCast(@intFromEnum(OpCode.OP_JUMP_IF_FALSE)));
    _ = &endJump;
    emitByte(@intCast(@intFromEnum(OpCode.OP_POP)));
    parsePrecedence(PREC_AND);
    patchJump(endJump);
}
pub fn binary(canAssign: bool) void {
    _ = canAssign;
    const operatorType: TokenType = parser.previous.type;
    const rule: ParseRule = getRule(operatorType);
    parsePrecedence(rule.precedence +% 1);
    while (true) {
        switch (operatorType) {
            .TOKEN_BANG_EQUAL => {
                emitBytes(@intCast(@intFromEnum(OpCode.OP_EQUAL)), @intCast(@intFromEnum(OpCode.OP_NOT)));
                break;
            },
            .TOKEN_EQUAL_EQUAL => {
                emitByte(@intCast(@intFromEnum(OpCode.OP_EQUAL)));
                break;
            },
            .TOKEN_GREATER => {
                emitByte(@intCast(@intFromEnum(OpCode.OP_GREATER)));
                break;
            },
            .TOKEN_GREATER_EQUAL => {
                emitBytes(@intCast(@intFromEnum(OpCode.OP_LESS)), @intCast(@intFromEnum(OpCode.OP_NOT)));
                break;
            },
            .TOKEN_LESS => {
                emitByte(@intCast(@intFromEnum(OpCode.OP_LESS)));
                break;
            },
            .TOKEN_LESS_EQUAL => {
                emitBytes(@intCast(@intFromEnum(OpCode.OP_GREATER)), @intCast(@intFromEnum(OpCode.OP_NOT)));
                break;
            },
            .TOKEN_PLUS => {
                emitByte(@intCast(@intFromEnum(OpCode.OP_ADD)));
                break;
            },
            .TOKEN_MINUS => {
                emitByte(@intCast(@intFromEnum(OpCode.OP_SUBTRACT)));
                break;
            },
            .TOKEN_STAR => {
                emitByte(@intCast(@intFromEnum(OpCode.OP_MULTIPLY)));
                break;
            },
            .TOKEN_SLASH => {
                emitByte(@intCast(@intFromEnum(OpCode.OP_DIVIDE)));
                break;
            },
            .TOKEN_PERCENT => {
                emitByte(@intCast(@intFromEnum(OpCode.OP_MODULO)));
                break;
            },
            .TOKEN_HAT => {
                emitByte(@intCast(@intFromEnum(OpCode.OP_EXPONENT)));
                break;
            },
            else => return,
        }
        break;
    }
}
pub fn call(canAssign: bool) void {
    _ = &canAssign;
    var argCount: u8 = argumentList();
    _ = &argCount;
    emitBytes(@intCast(@intFromEnum(OpCode.OP_CALL)), argCount);
}
pub fn dot(canAssign: bool) void {
    consume(.TOKEN_IDENTIFIER, "Expect property name after '.'.");
    var name: u8 = identifierConstant(&parser.previous);
    _ = &name;
    if ((@as(i32, @intFromBool(canAssign)) != 0) and (@as(i32, @intFromBool(match(.TOKEN_EQUAL))) != 0)) {
        expression();
        emitBytes(@intCast(@intFromEnum(OpCode.OP_SET_PROPERTY)), name);
    } else if (match(.TOKEN_LEFT_PAREN)) {
        var argCount: u8 = argumentList();
        _ = &argCount;
        emitBytes(@intCast(@intFromEnum(OpCode.OP_INVOKE)), name);
        emitByte(argCount);
    } else {
        emitBytes(@intCast(@intFromEnum(OpCode.OP_GET_PROPERTY)), name);
    }
}
pub fn literal(canAssign: bool) void {
    _ = canAssign;
    switch (parser.previous.type) {
        .TOKEN_FALSE => {
            emitByte(@intCast(@intFromEnum(OpCode.OP_FALSE)));
        },
        .TOKEN_NIL => {
            emitByte(@intCast(@intFromEnum(OpCode.OP_NIL)));
        },
        .TOKEN_TRUE => {
            emitByte(@intCast(@intFromEnum(OpCode.OP_TRUE)));
        },
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
    var elseJump: i32 = emitJump(@intCast(@intFromEnum(OpCode.OP_JUMP_IF_FALSE)));
    _ = &elseJump;
    var endJump: i32 = emitJump(@intCast(@intFromEnum(OpCode.OP_JUMP)));
    _ = &endJump;
    patchJump(elseJump);
    emitByte(@intCast(@intFromEnum(OpCode.OP_POP)));
    parsePrecedence(PREC_OR);
    patchJump(endJump);
}
pub fn string(canAssign: bool) void {
    _ = &canAssign;

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

    emitConstant(Value.init_obj(@ptrCast(object_h.copyString(start, @intCast(length)))));
}

pub fn fstring(canAssign: bool) void {
    _ = canAssign;

    // The token includes the quotes but not the 'f'
    // For f-string, we'll create a normal string instead
    // but mark it specially in the compiler so the VM understands it's an f-string

    // Create a normal string literal and emit it
    string(false);

    // For our basic implementation, we'll leave the string as is
    // A more complete implementation would parse expressions in {}
    // and replace them with their values

    // For now, we'll just be emitting the string to the VM
    // The proper implementation would require parsing the expressions
    // within {} and evaluating them at runtime
}
// pub fn array(canAssign: bool)  void {
//     _ = &canAssign;
//     var argCount: u8 = 0;
//     _ = &argCount;
//     if (!check(.TOKEN_RIGHT_SQPAREN)) {
//         while (true) {
//             expression();
//             argCount +%= 1;
//             if (@as(i32, @bitCast(@as(c_uint, argCount))) > 255) {
//                 @"error"("Can't have more than 255 elements in an array.");
//             }
//             if (!match(.TOKEN_COMMA)) break;
//         }
//     }
//     consume(.TOKEN_RIGHT_SQPAREN, "Expect ']' after array elements.");
//     emitBytes(@intCast(@intFromEnum(OpCode.OP_ARRAY)), argCount);
// Handle either dictionary or fvector literals
pub fn rangeExclusive(canAssign: bool) void {
    _ = canAssign;

    // Parse the end expression (right hand side)
    parsePrecedence(@as(c_uint, @bitCast(PREC_RANGE + 1)));

    // Emit the range creation instruction with exclusive flag
    emitByte(@intCast(@intFromEnum(OpCode.OP_RANGE)));
}

pub fn rangeInclusive(canAssign: bool) void {
    _ = canAssign;

    // Parse the end expression (right hand side)
    parsePrecedence(@as(c_uint, @bitCast(PREC_RANGE + 1)));

    // Emit the range creation instruction with inclusive flag
    emitByte(@intCast(@intFromEnum(OpCode.OP_RANGE_INCLUSIVE)));
}

pub fn pair(canAssign: bool) void {
    _ = canAssign;

    // Parse the value expression (right hand side)
    parsePrecedence(@as(c_uint, @bitCast(PREC_TERM + 1)));

    // Emit the pair creation instruction
    emitByte(@intCast(@intFromEnum(OpCode.OP_PAIR)));
}

// Helper function to determine if the current token sequence looks like a range pattern
fn isRangePattern() bool {
    // Save current position
    const savedCurrent = parser.current;
    const savedPrevious = parser.previous;

    // Try to parse a value followed by a range operator
    if (check(.TOKEN_INT) or check(.TOKEN_DOUBLE) or check(.TOKEN_IDENTIFIER)) {
        advance(); // Consume the start value

        const hasRange = check(.TOKEN_RANGE_EXCLUSIVE) or check(.TOKEN_RANGE_INCLUSIVE);

        // Restore position regardless of result
        parser.current = savedCurrent;
        parser.previous = savedPrevious;

        return hasRange;
    }

    return false;
}

// Helper function to check the next token without consuming it
fn checkNext(type_: TokenType) bool {
    if (parser.current.type == .TOKEN_EOF) return false;

    // Save current position
    const saved = parser.current;

    // Advance and check
    advance();
    const result = parser.current.type == type_;

    // Restore token position
    parser.current = saved;

    return result;
}

// Note: This function appears to be unused but is left for historical reference
// Float vectors are now handled by objectLiteral when isDict is false
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
        emitByte(@intCast(@intFromEnum(OpCode.OP_HASH_TABLE)));

        if (!check(.TOKEN_RIGHT_BRACE)) {
            while (true) {
                // Parse key - either a string literal or an identifier
                if (match(.TOKEN_STRING)) {
                    // String literal is already parsed and on stack as a string
                    emitConstant(Value.init_obj(@ptrCast(object_h.copyString(parser.previous.start + 1, // Skip opening quote
                        @intCast(parser.previous.length - 2) // Skip both quotes
                    ))));
                } else if (match(.TOKEN_IDENTIFIER)) {
                    // Convert identifier to string literal
                    const name = parser.previous.start[0..@intCast(parser.previous.length)];
                    emitConstant(Value.init_obj(@ptrCast(object_h.copyString(name.ptr, name.len))));
                } else {
                    errorAtCurrent(@ptrCast(@constCast("Dictionary key must be a string or identifier")));
                    return;
                }

                consume(.TOKEN_COLON, "Expect ':' after dictionary key");

                // Parse the value
                expression();

                // Emit instruction to add entry to hash table
                emitByte(@intCast(@intFromEnum(OpCode.OP_ADD_ENTRY)));

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

        emitBytes(@intCast(@intFromEnum(OpCode.OP_FVECTOR)), argCount);
    }

    consume(.TOKEN_RIGHT_BRACE, "Expect '}' after object literal");
}

// Note: This function appears to be unused but is left for historical reference
// Float vectors are now handled by objectLiteral when isDict is false
pub fn fvector(canAssign: bool) void {
    _ = canAssign;

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
    consume(.TOKEN_RIGHT_BRACE, "Expect '}' after vector elements.");
    emitBytes(@intCast(@intFromEnum(OpCode.OP_FVECTOR)), argCount);
}
pub fn namedVariable(name: Token, canAssign: bool) void {
    var getOp: u8 = undefined;
    var setOp: u8 = undefined;
    var arg: i32 = resolveLocal(current.?, @constCast(&name));

    if (arg != -1) {
        getOp = @intCast(@intFromEnum(OpCode.OP_GET_LOCAL));
        setOp = @intCast(@intFromEnum(OpCode.OP_SET_LOCAL));
    } else if ((blk: {
        arg = resolveUpvalue(current.?, @constCast(&name));
        break :blk arg;
    }) != -1) {
        getOp = @intCast(@intFromEnum(OpCode.OP_GET_UPVALUE));
        setOp = @intCast(@intFromEnum(OpCode.OP_SET_UPVALUE));
    } else {
        // For now, we'll let undefined globals be caught at runtime
        // since compile-time detection is complex with dynamic scoping
        arg = @intCast(identifierConstant(@constCast(&name)));
        getOp = @intCast(@intFromEnum(OpCode.OP_GET_GLOBAL));
        setOp = @intCast(@intFromEnum(OpCode.OP_SET_GLOBAL));
    }
    if ((@as(i32, @intFromBool(canAssign)) != 0) and (@as(i32, @intFromBool(match(.TOKEN_EQUAL))) != 0)) {
        // Check if trying to assign to a const local variable
        if (arg != -1 and current.?.locals[@intCast(arg)].isConst) {
            const varName = name.start[0..@intCast(name.length)];
            const suggestions = [_]errors.ErrorSuggestion{
                .{ .message = "Use 'var' instead of 'const' if you need to modify this variable" },
                .{ .message = "Constants cannot be modified after declaration" },
                .{ .message = "Declare as mutable", .example = "var myVariable = value;" },
            };
            errorWithSuggestions(&parser.previous, .INVALID_ASSIGNMENT, std.fmt.allocPrint(std.heap.page_allocator, "Cannot assign to constant variable '{s}'", .{varName}) catch "Cannot assign to constant variable", &suggestions);
            return;
        }
        expression();
        emitBytes(setOp, @as(u8, @bitCast(@as(i8, @truncate(arg)))));
    } else if ((((@as(i32, @intFromBool(match(.TOKEN_PLUS_EQUAL))) != 0) or (@as(i32, @intFromBool(match(.TOKEN_MINUS_EQUAL))) != 0)) or (@as(i32, @intFromBool(match(.TOKEN_STAR_EQUAL))) != 0)) or (@as(i32, @intFromBool(match(.TOKEN_SLASH_EQUAL))) != 0)) {
        // Check if trying to assign to a const local variable
        if (arg != -1 and current.?.locals[@intCast(arg)].isConst) {
            const varName = name.start[0..@intCast(name.length)];
            const suggestions = [_]errors.ErrorSuggestion{
                .{ .message = "Use 'var' instead of 'const' if you need to modify this variable" },
                .{ .message = "Constants cannot be modified with assignment operators" },
                .{ .message = "Declare as mutable", .example = "var myVariable = value;" },
            };
            errorWithSuggestions(&parser.previous, .INVALID_ASSIGNMENT, std.fmt.allocPrint(std.heap.page_allocator, "Cannot assign to constant variable '{s}'", .{varName}) catch "Cannot assign to constant variable", &suggestions);
            return;
        }
        emitBytes(getOp, @as(u8, @bitCast(@as(i8, @truncate(arg)))));
        expression();
        while (true) {
            switch (parser.previous.type) {
                .TOKEN_PLUS_EQUAL => {
                    emitByte(@intCast(@intFromEnum(OpCode.OP_ADD)));
                    break;
                },
                .TOKEN_MINUS_EQUAL => {
                    emitByte(@intCast(@intFromEnum(OpCode.OP_SUBTRACT)));
                    break;
                },
                .TOKEN_STAR_EQUAL => {
                    emitByte(@intCast(@intFromEnum(OpCode.OP_MULTIPLY)));
                    break;
                },
                .TOKEN_SLASH_EQUAL => {
                    emitByte(@intCast(@intFromEnum(OpCode.OP_DIVIDE)));
                    break;
                },
                else => return,
            }
            break;
        }
        emitBytes(setOp, @as(u8, @bitCast(@as(i8, @truncate(arg)))));
    } else if (match(.TOKEN_PLUS_PLUS)) {
        // Check if trying to increment a const local variable
        if (arg != -1 and current.?.locals[@intCast(arg)].isConst) {
            const varName = name.start[0..@intCast(name.length)];
            const suggestions = [_]errors.ErrorSuggestion{
                .{ .message = "Use 'var' instead of 'const' if you need to modify this variable" },
                .{ .message = "Constants cannot be incremented" },
                .{ .message = "Declare as mutable", .example = "var myVariable = value;" },
            };
            errorWithSuggestions(&parser.previous, .INVALID_ASSIGNMENT, std.fmt.allocPrint(std.heap.page_allocator, "Cannot assign to constant variable '{s}'", .{varName}) catch "Cannot assign to constant variable", &suggestions);
            return;
        }
        emitBytes(getOp, @as(u8, @bitCast(@as(i8, @truncate(arg)))));
        emitByte(@intCast(@intFromEnum(OpCode.OP_CONSTANT)));
        emitByte(makeConstant(Value{
            .type = .VAL_INT,
            .as = .{
                .num_int = 1,
            },
        }));
        emitByte(@intCast(@intFromEnum(OpCode.OP_ADD)));
        emitBytes(setOp, @as(u8, @bitCast(@as(i8, @truncate(arg)))));
    } else if (match(.TOKEN_MINUS_MINUS)) {
        // Check if trying to decrement a const local variable
        if (arg != -1 and current.?.locals[@intCast(arg)].isConst) {
            const varName = name.start[0..@intCast(name.length)];
            const suggestions = [_]errors.ErrorSuggestion{
                .{ .message = "Use 'var' instead of 'const' if you need to modify this variable" },
                .{ .message = "Constants cannot be decremented" },
                .{ .message = "Declare as mutable", .example = "var myVariable = value;" },
            };
            errorWithSuggestions(&parser.previous, .INVALID_ASSIGNMENT, std.fmt.allocPrint(std.heap.page_allocator, "Cannot assign to constant variable '{s}'", .{varName}) catch "Cannot assign to constant variable", &suggestions);
            return;
        }
        emitBytes(getOp, @as(u8, @bitCast(@as(i8, @truncate(arg)))));
        emitByte(@intCast(@intFromEnum(OpCode.OP_CONSTANT)));
        emitByte(makeConstant(Value{
            .type = .VAL_INT,
            .as = .{
                .num_int = 1,
            },
        }));
        emitByte(@intCast(@intFromEnum(OpCode.OP_SUBTRACT)));
        emitBytes(setOp, @as(u8, @bitCast(@as(i8, @truncate(arg)))));
    } else {
        emitBytes(getOp, @as(u8, @bitCast(@as(i8, @truncate(arg)))));
    }
}

pub fn variable(canAssign: bool) void {
    namedVariable(parser.previous, canAssign);
}

pub fn syntheticToken(text: [*]const u8) Token {
    // Calculate the length to create a proper slice
    const length = scanner_h.strlen(text);
    var token: Token = Token{
        .type = .TOKEN_IDENTIFIER,
        .start = @ptrCast(@constCast(text)),
        .length = @as(i32, @intCast(length)),
        .line = 0,
    };
    _ = &token;
    return token;
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
    var name: u8 = identifierConstant(&parser.previous);
    _ = &name;

    // Push 'self' as the receiver (this)
    namedVariable(syntheticToken("self"), false);

    if (match(.TOKEN_LEFT_PAREN)) {
        var argCount: u8 = argumentList();
        _ = &argCount;

        // Use the "super" local variable that stores the superclass
        namedVariable(syntheticToken("super"), false);

        emitBytes(@intCast(@intFromEnum(OpCode.OP_SUPER_INVOKE)), name);
        emitByte(argCount);
    } else {
        // Use the "super" local variable that stores the superclass
        namedVariable(syntheticToken("super"), false);

        emitBytes(@intCast(@intFromEnum(OpCode.OP_GET_SUPER)), name);
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
pub fn index_(canAssign: bool) void {
    // Check if we're doing a slice operation or a regular index
    var isSlice = false;

    // Parse the start index
    if (check(.TOKEN_END)) {
        advance(); // consume 'end'

        if (match(.TOKEN_MINUS)) {
            // Parse the offset value for 'end - offset'
            // Emit -1 first, then parse offset, then subtract
            emitConstant(Value.init_int(-1));
            parsePrecedence(@as(c_uint, @bitCast(PREC_UNARY)));
            emitByte(@intCast(@intFromEnum(OpCode.OP_SUBTRACT)));
        } else {
            // Simple 'end', use -1 as sentinel value
            emitConstant(Value.init_int(-1));
        }
    } else {
        // Regular index expression
        expression();
    }

    // Check if we have a slice with colon
    if (match(.TOKEN_COLON)) {
        isSlice = true;

        // Parse the end index
        if (check(.TOKEN_END)) {
            advance(); // consume 'end'

            if (match(.TOKEN_MINUS)) {
                // Parse the offset value for 'end - offset'
                // Emit -1 first, then parse offset, then subtract
                emitConstant(Value.init_int(-1));
                parsePrecedence(@as(c_uint, @bitCast(PREC_UNARY)));
                emitByte(@intCast(@intFromEnum(OpCode.OP_SUBTRACT)));
            } else {
                // Simple 'end', use -1 as sentinel value
                emitConstant(Value.init_int(-1));
            }
        } else {
            // Regular end index
            expression();
        }
    }

    consume(.TOKEN_RIGHT_SQPAREN, "Expect ']' after index expression.");

    if (isSlice) {
        // Handle slice operation
        emitByte(@intCast(@intFromEnum(OpCode.OP_SLICE)));
    } else if (canAssign and match(.TOKEN_EQUAL)) {
        // Handle assignment to index
        expression();
        emitByte(@intCast(@intFromEnum(OpCode.OP_SET_INDEX)));
    } else {
        // Handle regular indexing
        emitByte(@intCast(@intFromEnum(OpCode.OP_GET_INDEX)));
    }
}

pub fn unary(canAssign: bool) void {
    _ = &canAssign;
    var operatorType: TokenType = parser.previous.type;
    _ = &operatorType;
    parsePrecedence(@as(c_uint, @bitCast(PREC_UNARY)));
    while (true) {
        switch (operatorType) {
            .TOKEN_BANG => {
                emitByte(@intCast(@intFromEnum(OpCode.OP_NOT)));
                break;
            },
            .TOKEN_MINUS => {
                emitByte(@intCast(@intFromEnum(OpCode.OP_NEGATE)));
                break;
            },
            else => break,
        }
        break;
    }
}

pub fn block() void {
    while (!check(.TOKEN_RIGHT_BRACE) and !check(.TOKEN_EOF)) {
        declaration();
    }
    consume(.TOKEN_RIGHT_BRACE, "Expect '}' after block.");
}
pub fn function(type_: FunctionType) void {
    var compiler: Compiler = undefined;
    _ = &compiler;
    initCompiler(&compiler, type_);
    beginScope();
    consume(.TOKEN_LEFT_PAREN, "Expect '(' after function name.");
    if (!check(.TOKEN_RIGHT_PAREN)) {
        while (true) {
            current.?.function.*.arity += 1;
            if (current.?.function.*.arity > 255) {
                errorAtCurrent("Can't have more than 255 parameters.");
            }
            var constant: u8 = parseVariable("Expect parameter name.");
            _ = &constant;
            defineVariable(constant);
            if (!match(.TOKEN_COMMA)) break;
        }
    }
    consume(.TOKEN_RIGHT_PAREN, "Expect ')' after parameters.");
    consume(.TOKEN_LEFT_BRACE, "Expect '{' before function body.");
    block();
    var function_1: *ObjFunction = endCompiler();
    _ = &function_1;
    emitBytes(@intCast(@intFromEnum(OpCode.OP_CLOSURE)), makeConstant(Value{
        .type = .VAL_OBJ,
        .as = .{
            .obj = @ptrCast(function_1),
        },
    }));
    {
        var i: i32 = 0;
        _ = &i;
        while (i < function_1.*.upvalueCount) : (i += 1) {
            emitByte(if (compiler.upvalues[@as(c_uint, @intCast(i))].isLocal) 1 else 0);
            emitByte(compiler.upvalues[@as(c_uint, @intCast(i))].index);
        }
    }
}
pub fn method() void {
    consume(.TOKEN_IDENTIFIER, "Expect method name.");
    var constant: u8 = identifierConstant(&parser.previous);
    _ = &constant;
    var type_: FunctionType = .TYPE_METHOD;
    _ = &type_;
    if ((parser.previous.length == @as(i32, 4)) and (scanner_h.memcmp(@as(?*const anyopaque, @ptrCast(parser.previous.start)), @as(?*const anyopaque, @ptrCast("init")), @as(c_ulong, @bitCast(@as(c_long, @as(i32, 4))))) == 0)) {
        type_ = .TYPE_INITIALIZER;
    }
    function(type_);
    emitBytes(@intCast(@intFromEnum(OpCode.OP_METHOD)), constant);
}

pub fn classDeclaration() void {
    consume(.TOKEN_IDENTIFIER, "Expect class name.");
    var className: Token = parser.previous;
    _ = &className;
    var nameConstant: u8 = identifierConstant(&parser.previous);
    _ = &nameConstant;
    declareVariable();
    emitBytes(@intCast(@intFromEnum(OpCode.OP_CLASS)), nameConstant);
    defineVariable(nameConstant);
    var classCompiler: ClassCompiler = undefined;
    _ = &classCompiler;
    classCompiler.enclosing = currentClass;
    classCompiler.hasSuperclass = false;
    currentClass = &classCompiler;

    // Begin scope for methods and self
    beginScope();
    addLocal(syntheticToken("self"));

    if (match(.TOKEN_LESS)) {
        consume(.TOKEN_IDENTIFIER, "Expect superclass name.");
        variable(false);
        if (identifiersEqual(&className, &parser.previous)) {
            const className_str = className.start[0..@intCast(className.length)];
            const suggestions = [_]errors.ErrorSuggestion{
                .{ .message = "Inherit from a different class" },
                .{ .message = "Remove the inheritance if not needed" },
                .{ .message = "Classes cannot inherit from themselves" },
            };
            errorWithSuggestions(&parser.previous, .CLASS_INHERITANCE_ERROR, std.fmt.allocPrint(std.heap.page_allocator, "Class '{s}' cannot inherit from itself", .{className_str}) catch "Class cannot inherit from itself", &suggestions);
        }

        // Store the superclass in a local variable named "super"
        addLocal(syntheticToken("super"));
        namedVariable(parser.previous, false);
        defineVariable(0);

        namedVariable(className, false);
        emitByte(@intCast(@intFromEnum(OpCode.OP_INHERIT)));
        currentClass.?.hasSuperclass = true;
    }

    namedVariable(className, false);
    consume(.TOKEN_LEFT_BRACE, "Expect '{' before class body.");
    while (!check(.TOKEN_RIGHT_BRACE) and !check(.TOKEN_EOF)) {
        method();
    }
    consume(.TOKEN_RIGHT_BRACE, "Expect '}' after class body.");
    emitByte(@intCast(@intFromEnum(OpCode.OP_POP)));

    // End scope for methods, self, and super
    endScope();

    currentClass = currentClass.?.enclosing;
}
pub fn funDeclaration() void {
    var global: u8 = parseVariable("Expect function name.");
    _ = &global;
    markInitialized();
    function(.TYPE_FUNCTION);
    defineVariable(global);
}
pub fn varDeclaration() void {
    var global: u8 = parseVariable("Expect variable name.");
    _ = &global;
    if (match(.TOKEN_EQUAL)) {
        expression();
    } else {
        emitByte(@intCast(@intFromEnum(OpCode.OP_NIL)));
    }
    consume(.TOKEN_SEMICOLON, "Expect ';' after variable declaration.");
    defineVariable(global);
}

pub fn constDeclaration() void {
    var global: u8 = parseConstVariable("Expect constant name.");
    _ = &global;

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
    emitByte(@intCast(@intFromEnum(OpCode.OP_POP)));
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
    _ = &loopStart;
    var exitJump: i32 = -1;
    _ = &exitJump;
    if (!match(.TOKEN_SEMICOLON)) {
        expression();
        consume(.TOKEN_SEMICOLON, "Expect ';' after loop condition.");
        exitJump = emitJump(@intCast(@intFromEnum(OpCode.OP_JUMP_IF_FALSE)));
        emitByte(@intCast(@intFromEnum(OpCode.OP_POP)));
    }

    // Set up loop tracking for break/continue
    var loop = Loop.init(current.?.innermostLoop, loopStart, current.?.scopeDepth, .FOR);
    defer loop.deinit();
    current.?.innermostLoop = &loop;

    if (!match(.TOKEN_RIGHT_PAREN)) {
        var bodyJump: i32 = emitJump(@intCast(@intFromEnum(OpCode.OP_JUMP)));
        _ = &bodyJump;
        var incrementStart: i32 = currentChunk().*.count;
        _ = &incrementStart;
        expression();
        emitByte(@intCast(@intFromEnum(OpCode.OP_POP)));
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
        emitByte(@intCast(@intFromEnum(OpCode.OP_POP)));
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
    emitBytes(@intCast(@intFromEnum(OpCode.OP_SET_LOCAL)), @intCast(collectionSlot));
    emitByte(@intCast(@intFromEnum(OpCode.OP_POP)));

    // Initialize index = 0
    const indexSlot = current.?.localCount;
    addLocal(syntheticToken("__index"));
    markInitialized();
    emitConstant(Value.init_int(0));
    emitBytes(@intCast(@intFromEnum(OpCode.OP_SET_LOCAL)), @intCast(indexSlot));
    emitByte(@intCast(@intFromEnum(OpCode.OP_POP)));

    // Declare the loop item variable
    const itemSlot = current.?.localCount;
    addLocal(itemName);
    markInitialized();

    // Main loop start
    const loopStart: i32 = @intCast(currentChunk().*.count);

    // Condition: index < collection.length
    emitBytes(@intCast(@intFromEnum(OpCode.OP_GET_LOCAL)), @intCast(indexSlot));
    emitBytes(@intCast(@intFromEnum(OpCode.OP_GET_LOCAL)), @intCast(collectionSlot));
    emitByte(@intCast(@intFromEnum(OpCode.OP_LENGTH)));
    emitByte(@intCast(@intFromEnum(OpCode.OP_LESS)));

    // Exit if condition is false
    const exitJump: i32 = emitJump(@intCast(@intFromEnum(OpCode.OP_JUMP_IF_FALSE)));
    emitByte(@intCast(@intFromEnum(OpCode.OP_POP)));

    // Set item = collection[index]
    emitBytes(@intCast(@intFromEnum(OpCode.OP_GET_LOCAL)), @intCast(collectionSlot));
    emitBytes(@intCast(@intFromEnum(OpCode.OP_GET_LOCAL)), @intCast(indexSlot));
    emitByte(@intCast(@intFromEnum(OpCode.OP_GET_INDEX)));
    emitBytes(@intCast(@intFromEnum(OpCode.OP_SET_LOCAL)), @intCast(itemSlot));
    emitByte(@intCast(@intFromEnum(OpCode.OP_POP)));

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
    emitBytes(@intCast(@intFromEnum(OpCode.OP_GET_LOCAL)), @intCast(indexSlot));
    emitConstant(Value.init_int(1));
    emitByte(@intCast(@intFromEnum(OpCode.OP_ADD)));
    emitBytes(@intCast(@intFromEnum(OpCode.OP_SET_LOCAL)), @intCast(indexSlot));
    emitByte(@intCast(@intFromEnum(OpCode.OP_POP)));

    // Jump back to condition check
    emitLoop(loopStart);

    // Patch exit jump
    patchJump(exitJump);
    emitByte(@intCast(@intFromEnum(OpCode.OP_POP)));

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
    var thenJump: i32 = emitJump(@intCast(@intFromEnum(OpCode.OP_JUMP_IF_FALSE)));
    _ = &thenJump;
    emitByte(@intCast(@intFromEnum(OpCode.OP_POP)));
    statement();
    var elseJump: i32 = emitJump(@intCast(@intFromEnum(OpCode.OP_JUMP)));
    _ = &elseJump;
    patchJump(thenJump);
    emitByte(@intCast(@intFromEnum(OpCode.OP_POP)));
    if (match(.TOKEN_ELSE)) {
        statement();
    }
    patchJump(elseJump);
}
pub fn printStatement() void {
    expression();
    consume(.TOKEN_SEMICOLON, "Expect ';' after value.");
    emitByte(@intCast(@intFromEnum(OpCode.OP_PRINT)));
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
        expression();
        consume(.TOKEN_SEMICOLON, "Expect ';' after return value.");
        emitByte(@intCast(@intFromEnum(OpCode.OP_RETURN)));
    }
}
pub fn whileStatement() void {
    var loopStart: i32 = @intCast(currentChunk().*.count);
    _ = &loopStart;

    // Set up loop tracking for break/continue
    var loop = Loop.init(current.?.innermostLoop, loopStart, current.?.scopeDepth, .WHILE);
    defer loop.deinit();
    current.?.innermostLoop = &loop;

    consume(.TOKEN_LEFT_PAREN, "Expect '(' after 'while'.");
    expression();
    consume(.TOKEN_RIGHT_PAREN, "Expect ')' after condition.");
    var exitJump: i32 = emitJump(@intCast(@intFromEnum(OpCode.OP_JUMP_IF_FALSE)));
    _ = &exitJump;
    emitByte(@intCast(@intFromEnum(OpCode.OP_POP)));
    statement();
    emitLoop(loopStart);
    patchJump(exitJump);
    emitByte(@intCast(@intFromEnum(OpCode.OP_POP)));

    // Patch all break jumps to point here
    for (loop.breakJumps.items) |breakJump| {
        patchJump(breakJump);
    }

    // While loops shouldn't have continue jumps to patch (they use direct loops)
    // But let's be safe and patch them if they exist
    for (loop.continueJumps.items) |continueJump| {
        patchJump(continueJump);
    }

    // Restore the enclosing loop
    current.?.innermostLoop = loop.enclosing;
}

pub fn breakStatement() void {
    if (current.?.innermostLoop == null) {
        @"error"("'break' statement must be inside a loop.");
        consume(.TOKEN_SEMICOLON, "Expect ';' after 'break'.");
        return;
    }

    consume(.TOKEN_SEMICOLON, "Expect ';' after 'break'.");

    // Emit a jump that will be patched to jump to the end of the loop
    const jump = emitJump(@intCast(@intFromEnum(OpCode.OP_JUMP)));
    current.?.innermostLoop.?.breakJumps.append(jump) catch unreachable;
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
        const jump = emitJump(@intCast(@intFromEnum(OpCode.OP_JUMP)));
        current.?.innermostLoop.?.continueJumps.append(jump) catch unreachable;
    } else {
        // Emit a loop instruction to jump back to the start of the loop
        emitLoop(current.?.innermostLoop.?.start);
    }
}

pub fn switchStatement() void {
    consume(.TOKEN_LEFT_PAREN, "Expect '(' after 'switch'.");
    expression(); // Parse the switch expression
    consume(.TOKEN_RIGHT_PAREN, "Expect ')' after switch condition.");

    // Store the switch value for later comparisons
    consume(.TOKEN_LEFT_BRACE, "Expect '{' before switch cases.");

    // Store the switch expression value in a local variable for later use
    // This will let us compare it against case values, including ranges
    beginScope();
    const switchVarSlot = current.?.localCount;
    addLocal(syntheticToken("__switch_value"));
    markInitialized();

    // Store the switch value in a local variable
    emitBytes(@intCast(@intFromEnum(OpCode.OP_SET_LOCAL)), @intCast(switchVarSlot));
    // No need to pop here since OP_SET_LOCAL doesn't consume the value

    // Keep track of all end jumps - we'll patch these at the end
    var endJumps = std.ArrayList(i32).init(std.heap.page_allocator);
    defer endJumps.deinit();

    // Track default case location and whether we've seen one
    var hasDefault: bool = false;
    var defaultJump: i32 = -1;

    // Track if we're in a case block for break statement handling
    var inCaseBlock: bool = false;
    var breakJumpPos: i32 = -1;

    // Process each case until we reach the end of the switch block
    while (!check(.TOKEN_RIGHT_BRACE) and !check(.TOKEN_EOF)) {
        if (check(.TOKEN_IDENTIFIER) and parser.current.length == 1 and parser.current.start[0] == '_') {
            // Handle default case: _ => ...
            advance(); // consume '_'
            consume(.TOKEN_ARROW, "Expect '=>' after default case.");

            if (hasDefault) {
                @"error"("Cannot have more than one default case in a switch statement.");
            }
            hasDefault = true;

            // Remember where the default case starts
            defaultJump = @intCast(currentChunk().*.count);

            // Parse the default case body
            if (match(.TOKEN_LEFT_BRACE)) {
                inCaseBlock = true;
                beginScope();

                // Capture current position for break statements
                breakJumpPos = @intCast(currentChunk().*.count);

                block();

                // Check for unconsumed break statements and handle them
                if (inCaseBlock) {
                    inCaseBlock = false;
                }

                endScope();
            } else {
                expression();
                emitByte(@intCast(@intFromEnum(OpCode.OP_POP)));
            }

            // After the default case, jump to the end
            const endJump = emitJump(@intCast(@intFromEnum(OpCode.OP_JUMP)));
            endJumps.append(endJump) catch unreachable;
        } else if (check(.TOKEN_CASE)) {
            // Handle case statement: case expr => ...
            advance(); // consume 'case'

            // Parse the first part of the case value
            // For range patterns, we need to handle them specially
            if (check(.TOKEN_INT) or check(.TOKEN_DOUBLE) or check(.TOKEN_IDENTIFIER)) {
                // Parse the first value
                parsePrecedence(@as(c_uint, @bitCast(PREC_RANGE + 1)));

                // Check if this is a range pattern
                if (check(.TOKEN_RANGE_EXCLUSIVE) or check(.TOKEN_RANGE_INCLUSIVE)) {
                    // This is a range pattern
                    const isInclusive = match(.TOKEN_RANGE_INCLUSIVE);
                    if (!isInclusive) {
                        consume(.TOKEN_RANGE_EXCLUSIVE, "Expect range operator '..' or '..='");
                    }

                    // Parse the end value
                    parsePrecedence(@as(c_uint, @bitCast(PREC_RANGE + 1)));

                    // Store end value in a temporary local
                    beginScope();
                    addLocal(syntheticToken("__case_range_end"));
                    markInitialized();
                    const rangeEndSlot = current.?.localCount - 1;
                    emitBytes(@intCast(@intFromEnum(OpCode.OP_SET_LOCAL)), @intCast(rangeEndSlot));

                    // Check if switch value >= start
                    // Stack before: [start_value]
                    emitBytes(@intCast(@intFromEnum(OpCode.OP_GET_LOCAL)), @intCast(switchVarSlot));
                    // Stack: [start_value, switch_value]
                    // We need switch_value >= start_value, which is !(switch_value < start_value)
                    emitByte(@intCast(@intFromEnum(OpCode.OP_LESS)));
                    emitByte(@intCast(@intFromEnum(OpCode.OP_NOT)));

                    const skipStartCheck = emitJump(@intCast(@intFromEnum(OpCode.OP_JUMP_IF_FALSE)));
                    emitByte(@intCast(@intFromEnum(OpCode.OP_POP))); // Pop comparison result

                    // Check if switch value <= end (or < for exclusive)
                    emitBytes(@intCast(@intFromEnum(OpCode.OP_GET_LOCAL)), @intCast(switchVarSlot));
                    emitBytes(@intCast(@intFromEnum(OpCode.OP_GET_LOCAL)), @intCast(rangeEndSlot));

                    if (isInclusive) {
                        emitByte(@intCast(@intFromEnum(OpCode.OP_GREATER)));
                        emitByte(@intCast(@intFromEnum(OpCode.OP_NOT)));
                    } else {
                        emitByte(@intCast(@intFromEnum(OpCode.OP_LESS)));
                    }

                    const skipEndCheck = emitJump(@intCast(@intFromEnum(OpCode.OP_JUMP_IF_FALSE)));
                    emitByte(@intCast(@intFromEnum(OpCode.OP_POP))); // Pop comparison result

                    consume(.TOKEN_ARROW, "Expect '=>' after range pattern.");

                    // Parse case body
                    if (match(.TOKEN_LEFT_BRACE)) {
                        beginScope();

                        while (!check(.TOKEN_RIGHT_BRACE) and !check(.TOKEN_EOF)) {
                            if (match(.TOKEN_BREAK)) {
                                consume(.TOKEN_SEMICOLON, "Expect ';' after break.");
                                const breakJump = emitJump(@intCast(@intFromEnum(OpCode.OP_JUMP)));
                                endJumps.append(breakJump) catch unreachable;
                                break;
                            } else {
                                statement();
                            }
                        }

                        consume(.TOKEN_RIGHT_BRACE, "Expect '}' after case body.");
                        endScope();
                    } else {
                        expression();
                        emitByte(@intCast(@intFromEnum(OpCode.OP_POP)));

                        if (match(.TOKEN_BREAK)) {
                            consume(.TOKEN_SEMICOLON, "Expect ';' after break.");
                            const breakJump = emitJump(@intCast(@intFromEnum(OpCode.OP_JUMP)));
                            endJumps.append(breakJump) catch unreachable;
                        }
                    }

                    // Jump to end of switch after executing case
                    const endJump = emitJump(@intCast(@intFromEnum(OpCode.OP_JUMP)));
                    endJumps.append(endJump) catch unreachable;

                    // Patch skip jumps
                    patchJump(skipStartCheck);
                    patchJump(skipEndCheck);
                    emitByte(@intCast(@intFromEnum(OpCode.OP_POP))); // Pop comparison result

                    endScope(); // End scope for range end variable
                } else {
                    // Not a range, just a regular case value
                    // We already parsed the value, now consume the arrow
                    consume(.TOKEN_ARROW, "Expect '=>' after case value.");

                    // Get the switch value for comparison (gets the value we stored in the local)
                    emitBytes(@intCast(@intFromEnum(OpCode.OP_GET_LOCAL)), @intCast(switchVarSlot));

                    // Compare the case value with the switch value (on stack as: case_value, switch_value)
                    emitByte(@intCast(@intFromEnum(OpCode.OP_EQUAL)));

                    // If they're not equal, skip this case
                    const skipCaseJump = emitJump(@intCast(@intFromEnum(OpCode.OP_JUMP_IF_FALSE)));

                    // Pop the comparison result only when we execute the case
                    emitByte(@intCast(@intFromEnum(OpCode.OP_POP)));

                    // Parse case body
                    if (match(.TOKEN_LEFT_BRACE)) {
                        inCaseBlock = true;
                        beginScope();

                        // Capture current position for break statements
                        breakJumpPos = @intCast(currentChunk().*.count);

                        // Parse statements until we hit a break or the end of the block
                        while (!check(.TOKEN_RIGHT_BRACE) and !check(.TOKEN_EOF)) {
                            if (match(.TOKEN_BREAK)) {
                                consume(.TOKEN_SEMICOLON, "Expect ';' after break.");

                                // Jump to the end of the switch statement
                                const breakJump = emitJump(@intCast(@intFromEnum(OpCode.OP_JUMP)));
                                endJumps.append(breakJump) catch unreachable;

                                // No need to continue parsing this block
                                break;
                            } else {
                                statement();
                            }
                        }

                        // Reset case block tracking
                        inCaseBlock = false;

                        consume(.TOKEN_RIGHT_BRACE, "Expect '}' after case body.");
                        endScope();
                    } else {
                        expression();
                        emitByte(@intCast(@intFromEnum(OpCode.OP_POP)));

                        // Handle single-statement break
                        if (match(.TOKEN_BREAK)) {
                            consume(.TOKEN_SEMICOLON, "Expect ';' after break.");

                            // Jump to the end of the switch statement
                            const breakJump = emitJump(@intCast(@intFromEnum(OpCode.OP_JUMP)));
                            endJumps.append(breakJump) catch unreachable;
                        }
                    }

                    // After case body, jump to the end of the switch (if no break was encountered)
                    const endJump = emitJump(@intCast(@intFromEnum(OpCode.OP_JUMP)));
                    endJumps.append(endJump) catch unreachable;

                    // If comparison was false, skip to here (next case)
                    patchJump(skipCaseJump);

                    // No need to pop the switch value as we're using a local variable
                }
            } else {
                // Parse other types of expressions
                parsePrecedence(@as(c_uint, @bitCast(PREC_TERM + 1)));
                consume(.TOKEN_ARROW, "Expect '=>' after case value.");

                // Get the switch value for comparison (gets the value we stored in the local)
                emitBytes(@intCast(@intFromEnum(OpCode.OP_GET_LOCAL)), @intCast(switchVarSlot));

                // Compare the case value with the switch value (on stack as: case_value, switch_value)
                emitByte(@intCast(@intFromEnum(OpCode.OP_EQUAL)));

                // If they're not equal, skip this case
                const skipCaseJump = emitJump(@intCast(@intFromEnum(OpCode.OP_JUMP_IF_FALSE)));

                // Pop the comparison result only when we execute the case
                emitByte(@intCast(@intFromEnum(OpCode.OP_POP)));

                // Parse case body
                if (match(.TOKEN_LEFT_BRACE)) {
                    inCaseBlock = true;
                    beginScope();

                    // Capture current position for break statements
                    breakJumpPos = @intCast(currentChunk().*.count);

                    // Parse statements until we hit a break or the end of the block
                    while (!check(.TOKEN_RIGHT_BRACE) and !check(.TOKEN_EOF)) {
                        if (match(.TOKEN_BREAK)) {
                            consume(.TOKEN_SEMICOLON, "Expect ';' after break.");

                            // Jump to the end of the switch statement
                            const breakJump = emitJump(@intCast(@intFromEnum(OpCode.OP_JUMP)));
                            endJumps.append(breakJump) catch unreachable;

                            // No need to continue parsing this block
                            break;
                        } else {
                            statement();
                        }
                    }

                    // Reset case block tracking
                    inCaseBlock = false;

                    consume(.TOKEN_RIGHT_BRACE, "Expect '}' after case body.");
                    endScope();
                } else {
                    expression();
                    emitByte(@intCast(@intFromEnum(OpCode.OP_POP)));

                    // Handle single-statement break
                    if (match(.TOKEN_BREAK)) {
                        consume(.TOKEN_SEMICOLON, "Expect ';' after break.");

                        // Jump to the end of the switch statement
                        const breakJump = emitJump(@intCast(@intFromEnum(OpCode.OP_JUMP)));
                        endJumps.append(breakJump) catch unreachable;
                    }
                }

                // After case body, jump to the end of the switch (if no break was encountered)
                const endJump = emitJump(@intCast(@intFromEnum(OpCode.OP_JUMP)));
                endJumps.append(endJump) catch unreachable;

                // If comparison was false, skip to here (next case)
                patchJump(skipCaseJump);

                // No need to pop the switch value as we're using a local variable
            }
        } else {
            // Original syntax: expr => ...

            // Parse with precedence that stops before => operator
            parsePrecedence(@as(c_uint, @bitCast(PREC_TERM + 1)));

            // Get the switch value for comparison
            emitBytes(@intCast(@intFromEnum(OpCode.OP_GET_LOCAL)), @intCast(switchVarSlot));

            consume(.TOKEN_ARROW, "Expect '=>' after case value.");

            // Get the switch value for comparison
            emitBytes(@intCast(@intFromEnum(OpCode.OP_GET_LOCAL)), @intCast(switchVarSlot));

            // Compare the values (stack now has: case_value, switch_value)
            emitByte(@intCast(@intFromEnum(OpCode.OP_EQUAL)));

            // If comparison result is false (not equal), skip this case
            const skipCaseJump = emitJump(@intCast(@intFromEnum(OpCode.OP_JUMP_IF_FALSE)));

            // Pop the comparison result when we're executing the case
            emitByte(@intCast(@intFromEnum(OpCode.OP_POP)));

            // Parse case body
            if (match(.TOKEN_LEFT_BRACE)) {
                inCaseBlock = true;
                beginScope();

                // Capture current position for break statements
                breakJumpPos = @intCast(currentChunk().*.count);

                // Parse statements until we hit a break or the end of the block
                while (!check(.TOKEN_RIGHT_BRACE) and !check(.TOKEN_EOF)) {
                    if (match(.TOKEN_BREAK)) {
                        consume(.TOKEN_SEMICOLON, "Expect ';' after break.");

                        // Jump to the end of the switch statement
                        const breakJump = emitJump(@intCast(@intFromEnum(OpCode.OP_JUMP)));
                        endJumps.append(breakJump) catch unreachable;

                        // No need to continue parsing this block
                        break;
                    } else {
                        statement();
                    }
                }

                // Reset case block tracking
                inCaseBlock = false;

                consume(.TOKEN_RIGHT_BRACE, "Expect '}' after case body.");
                endScope();
            } else {
                expression();
                emitByte(@intCast(@intFromEnum(OpCode.OP_POP)));

                // Handle single-statement break
                if (match(.TOKEN_BREAK)) {
                    consume(.TOKEN_SEMICOLON, "Expect ';' after break.");

                    // Jump to the end of the switch statement
                    const breakJump = emitJump(@intCast(@intFromEnum(OpCode.OP_JUMP)));
                    endJumps.append(breakJump) catch unreachable;
                }
            }

            // After case body, jump to the end of the switch
            const endJump = emitJump(@intCast(@intFromEnum(OpCode.OP_JUMP)));
            endJumps.append(endJump) catch unreachable;

            // If comparison was false, skip to here (next case)
            patchJump(skipCaseJump);
            // Pop the comparison result that's still on the stack if we skip this case
            emitByte(@intCast(@intFromEnum(OpCode.OP_POP)));

            // No need to pop the switch value as we're using a local variable
        }

        // Optional comma between cases
        _ = match(.TOKEN_COMMA);
    }

    // If no case matched and we have a default case, jump to it
    if (hasDefault) emitLoop(defaultJump);

    // Patch all the end jumps to point to here
    for (endJumps.items) |endJump| {
        patchJump(endJump);
    }

    // End the scope we created for the switch value
    endScope();

    consume(.TOKEN_RIGHT_BRACE, "Expect '}' after switch cases.");
}

// Future enhancement: Parse range cases like 1..5 =>
fn parseRangeCase() void {
    // Parse start expression
    expression();

    // Expect .. token (would need to add TOKEN_DOT_DOT to scanner)
    // consume(.TOKEN_DOT_DOT, "Expect '..' in range case.");

    // Parse end expression
    expression();

    consume(.TOKEN_ARROW, "Expect '=>' after range case.");

    // Emit OP_SWITCH_CASE with range type (1)
    emitBytes(@intCast(@intFromEnum(OpCode.OP_SWITCH_CASE)), 1);

    // Range comparison logic would be handled in VM
}

// Future enhancement: Parse multiple value cases like 1 | 2 | 3 =>
fn parseMultipleValueCase() void {
    var valueCount: u8 = 1;

    // Parse first value
    expression();

    // Parse additional values separated by |
    while (match(.TOKEN_OR)) { // TOKEN_OR is |
        if (valueCount >= 255) {
            @"error"("Too many values in case (max 255).");
        }
        expression();
        valueCount += 1;
    }

    consume(.TOKEN_ARROW, "Expect '=>' after case values.");

    // Emit OP_SWITCH_CASE with multiple value type (2) and count
    emitBytes(@intCast(@intFromEnum(OpCode.OP_SWITCH_CASE)), 2);
    emitByte(valueCount);

    // Multiple value comparison logic would be handled in VM
}

// Future enhancement: Parse guard clauses like value when condition =>
fn parseGuardCase() void {
    // Parse case value
    expression();

    // Expect 'when' keyword (would need to add TOKEN_WHEN)
    // consume(.TOKEN_WHEN, "Expect 'when' in guard case.");

    // Parse guard condition
    expression();

    consume(.TOKEN_ARROW, "Expect '=>' after guard case.");

    // Emit OP_SWITCH_CASE with guard type (3)
    emitBytes(@intCast(@intFromEnum(OpCode.OP_SWITCH_CASE)), 3);

    // Guard evaluation logic would be handled in VM
}

pub fn synchronize() void {
    parser.panicMode = false;
    while (parser.current.type != .TOKEN_EOF) {
        if (parser.previous.type == .TOKEN_SEMICOLON) return;
        while (true) {
            switch (parser.current.type) {
                else => return,
            }
            break;
        }
        advance();
    }
}

pub fn compile(source: [*]const u8) ?*ObjFunction {
    // Initialize error manager if not already done
    if (!errorManagerInitialized) {
        globalErrorManager = errors.ErrorManager.init(std.heap.page_allocator);
        knownVariables = std.ArrayList([]const u8).init(std.heap.page_allocator);
        errorManagerInitialized = true;
    } else {
        globalErrorManager.reset();
        knownVariables.clearRetainingCapacity();
    }

    // Set scanner error manager
    setScannerErrorManager();

    scanner_h.init_scanner(@constCast(source));
    var compiler: Compiler = undefined;
    _ = &compiler;
    initCompiler(&compiler, .TYPE_SCRIPT);
    parser.hadError = false;
    parser.panicMode = false;
    parser.currentFile = "<script>";
    advance();
    while (!match(.TOKEN_EOF)) {
        declaration();
    }
    var function_1: *ObjFunction = endCompiler();
    _ = &function_1;

    return if (@as(i32, @intFromBool(parser.hadError)) != 0) null else function_1;
}
