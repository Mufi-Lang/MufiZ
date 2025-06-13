const print = @import("std").debug.print;
const std = @import("std");

const debug_opts = @import("debug");

const chunk_h = @import("chunk.zig");
const Chunk = chunk_h.Chunk;
const OpCode = chunk_h.OpCode;
const debug_h = @import("debug.zig");
const errors = @import("errors.zig");
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
pub const PREC_FACTOR: i32 = 7;
pub const PREC_UNARY: i32 = 8;
pub const PREC_CALL: i32 = 9;
pub const PREC_INDEX: i32 = 10;
pub const PREC_PRIMARY: i32 = 11;
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

pub const Compiler = struct {
    enclosing: ?*Compiler,
    function: *ObjFunction,
    type_: FunctionType,
    locals: [256]Local,
    localCount: i32,
    upvalues: [256]Upvalue,
    scopeDepth: i32,
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
        .TOKEN_LEFT_BRACE => ParseRule{ .prefix = &fvector, .precedence = PREC_NONE },
        .TOKEN_RIGHT_BRACE => ParseRule{ .precedence = PREC_NONE },
        .TOKEN_COMMA => ParseRule{ .precedence = PREC_NONE },
        .TOKEN_DOT => ParseRule{ .prefix = &item_, .infix = &dot, .precedence = PREC_CALL },
        .TOKEN_MINUS => ParseRule{ .prefix = &unary, .infix = &binary, .precedence = PREC_TERM },
        .TOKEN_PLUS => ParseRule{ .infix = &binary, .precedence = PREC_TERM },
        .TOKEN_SEMICOLON => ParseRule{ .precedence = PREC_NONE },
        .TOKEN_SLASH => ParseRule{ .infix = &binary, .precedence = PREC_FACTOR },
        .TOKEN_STAR => ParseRule{ .infix = &binary, .precedence = PREC_FACTOR },
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

        // Literals
        .TOKEN_IDENTIFIER => ParseRule{ .prefix = &variable, .precedence = PREC_NONE },
        .TOKEN_STRING => ParseRule{ .prefix = &string, .precedence = PREC_NONE },
        .TOKEN_MULTILINE_STRING => ParseRule{ .prefix = &string, .precedence = PREC_NONE },
        .TOKEN_BACKTICK_STRING => ParseRule{ .prefix = &string, .precedence = PREC_NONE },
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
        .TOKEN_LET => ParseRule{ .precedence = PREC_NONE },
        .TOKEN_NIL => ParseRule{ .prefix = &literal, .precedence = PREC_NONE },
        .TOKEN_OR => ParseRule{ .infix = &or_, .precedence = PREC_OR },
        .TOKEN_PRINT => ParseRule{ .precedence = PREC_NONE },
        .TOKEN_RETURN => ParseRule{ .precedence = PREC_NONE },
        .TOKEN_SELF => ParseRule{ .prefix = &self_, .precedence = PREC_NONE },
        .TOKEN_SUPER => ParseRule{ .prefix = &super_, .precedence = PREC_NONE },
        .TOKEN_TRUE => ParseRule{ .prefix = &literal, .precedence = PREC_NONE },
        .TOKEN_VAR => ParseRule{ .precedence = PREC_NONE },
        .TOKEN_WHILE => ParseRule{ .precedence = PREC_NONE },
        .TOKEN_ITEM => ParseRule{ .prefix = &literal, .precedence = PREC_NONE },
        .TOKEN_FOREACH => ParseRule{ .precedence = PREC_NONE },
        .TOKEN_IN => ParseRule{ .precedence = PREC_NONE },

        // Misc
        .TOKEN_ERROR => ParseRule{ .precedence = PREC_NONE },
        .TOKEN_EOF => ParseRule{ .precedence = PREC_NONE },
        .TOKEN_PLUS_EQUAL => ParseRule{ .precedence = PREC_NONE },
        .TOKEN_MINUS_EQUAL => ParseRule{ .precedence = PREC_NONE },
        .TOKEN_STAR_EQUAL => ParseRule{ .precedence = PREC_NONE },
        .TOKEN_SLASH_EQUAL => ParseRule{ .precedence = PREC_NONE },
        .TOKEN_PLUS_PLUS => ParseRule{ .precedence = PREC_NONE },
        .TOKEN_MINUS_MINUS => ParseRule{ .precedence = PREC_NONE },
        .TOKEN_HAT => ParseRule{ .infix = &binary, .precedence = PREC_FACTOR },
        .TOKEN_LEFT_SQPAREN => ParseRule{ .infix = &index_, .precedence = PREC_INDEX },
        .TOKEN_RIGHT_SQPAREN => ParseRule{ .precedence = PREC_NONE },
        .TOKEN_COLON => ParseRule{ .precedence = PREC_NONE },
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
pub fn parseVariable(message: [*]const u8) u8 {
    consume(.TOKEN_IDENTIFIER, message);
    declareVariable();
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
    _ = &canAssign;
    expression();
    consume(.TOKEN_RIGHT_PAREN, "Expect ')' after expression.");
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
// }
pub fn fvector(canAssign: bool) void {
    _ = &canAssign;
    var argCount: u8 = 0;
    _ = &argCount;
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
        expression();
        emitBytes(setOp, @as(u8, @bitCast(@as(i8, @truncate(arg)))));
    } else if ((((@as(i32, @intFromBool(match(.TOKEN_PLUS_EQUAL))) != 0) or (@as(i32, @intFromBool(match(.TOKEN_MINUS_EQUAL))) != 0)) or (@as(i32, @intFromBool(match(.TOKEN_STAR_EQUAL))) != 0)) or (@as(i32, @intFromBool(match(.TOKEN_SLASH_EQUAL))) != 0)) {
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
    expression();
    consume(.TOKEN_RIGHT_SQPAREN, "Expect ']' after index.");

    if (canAssign and match(.TOKEN_EQUAL)) {
        expression();
        emitByte(@intCast(@intFromEnum(OpCode.OP_SET_INDEX)));
    } else {
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
        patchJump(bodyJump);
    }
    statement();
    emitLoop(loopStart);
    if (exitJump != -1) {
        patchJump(exitJump);
        emitByte(@intCast(@intFromEnum(OpCode.OP_POP)));
    }
    endScope();
}
// eachStatement function removed - it was using removed iterator opcodes
pub fn foreachStatement() void {
    beginScope();

    // Expect '(' after 'foreach'
    consume(.TOKEN_LEFT_PAREN, "Expect '(' after 'foreach'.");

    // Parse the loop variable (item)
    consume(.TOKEN_IDENTIFIER, "Expect variable name.");
    const itemName = parser.previous;

    // Expect 'in' keyword
    consume(.TOKEN_IN, "Expect 'in' after loop variable.");

    // We need to keep the collection in a variable that won't be garbage collected
    // and won't be affected by scope changes
    addLocal(syntheticToken("__collection"));
    expression(); // Collection expression leaves value on stack

    markInitialized(); // This effectively assigns the value to the local
    const collectionSlot = current.?.localCount - 1;

    // Expect ')'
    consume(.TOKEN_RIGHT_PAREN, "Expect ')' after collection.");

    // Initialize index variable
    addLocal(syntheticToken("__index"));
    emitConstant(Value.init_int(0));
    markInitialized();
    const indexSlot = current.?.localCount - 1;

    // Declare item variable but don't initialize it yet
    addLocal(itemName);
    const itemSlot = current.?.localCount - 1;

    const loopStart: i32 = currentChunk().*.count;

    // Loop condition: check if index < collection.length
    emitBytes(@intCast(@intFromEnum(OpCode.OP_GET_LOCAL)), @intCast(indexSlot));
    emitBytes(@intCast(@intFromEnum(OpCode.OP_GET_LOCAL)), @intCast(collectionSlot));
    emitByte(@intCast(@intFromEnum(OpCode.OP_LENGTH)));
    emitByte(@intCast(@intFromEnum(OpCode.OP_LESS)));

    const exitJump: i32 = emitJump(@intCast(@intFromEnum(OpCode.OP_JUMP_IF_FALSE)));
    emitByte(@intCast(@intFromEnum(OpCode.OP_POP))); // Pop the condition result

    // Get current element: collection[index] and assign to item
    emitBytes(@intCast(@intFromEnum(OpCode.OP_GET_LOCAL)), @intCast(collectionSlot));
    emitBytes(@intCast(@intFromEnum(OpCode.OP_GET_LOCAL)), @intCast(indexSlot));
    emitByte(@intCast(@intFromEnum(OpCode.OP_GET_INDEX)));

    // Set the item variable to the value from GET_INDEX
    emitBytes(@intCast(@intFromEnum(OpCode.OP_SET_LOCAL)), @intCast(itemSlot));
    emitByte(@intCast(@intFromEnum(OpCode.OP_POP))); // Pop the value after setting local
    markInitialized(); // Mark the item variable as initialized

    // Execute loop body
    statement();

    // Increment index
    emitBytes(@intCast(@intFromEnum(OpCode.OP_GET_LOCAL)), @intCast(indexSlot));
    emitConstant(Value.init_int(1));
    emitByte(@intCast(@intFromEnum(OpCode.OP_ADD)));
    emitBytes(@intCast(@intFromEnum(OpCode.OP_SET_LOCAL)), @intCast(indexSlot));
    emitByte(@intCast(@intFromEnum(OpCode.OP_POP)));

    // Jump back to start
    emitLoop(loopStart);

    // Patch exit jump
    patchJump(exitJump);
    emitByte(@intCast(@intFromEnum(OpCode.OP_POP))); // Pop the false condition

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
    var loopStart: i32 = currentChunk().*.count;
    _ = &loopStart;
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
