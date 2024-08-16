const scanner_h = @import("scanner.zig");
const object_h = @import("object.zig");
const chunk_h = @import("chunk.zig");
const value_h = @import("value.zig");
const vm_h = @import("vm.zig");
const Token = scanner_h.Token;
const TokenType = scanner_h.TokenType;
const ObjFunction = object_h.ObjFunction;
const Chunk = chunk_h.Chunk;
const Value = value_h.Value;
const print = @import("std").debug.print;
const stdlib_h = @cImport(@cInclude("stdlib.h"));
const atoi = stdlib_h.atoi;
const strtod = stdlib_h.strtod;

pub const Parser = extern struct { current: Token, previous: Token, hadError: bool, panicMode: bool };

pub const PREC_NONE: c_int = 0;
pub const PREC_ASSIGNMENT: c_int = 1;
pub const PREC_OR: c_int = 2;
pub const PREC_AND: c_int = 3;
pub const PREC_EQUALITY: c_int = 4;
pub const PREC_COMPARISON: c_int = 5;
pub const PREC_TERM: c_int = 6;
pub const PREC_FACTOR: c_int = 7;
pub const PREC_UNARY: c_int = 8;
pub const PREC_CALL: c_int = 9;
pub const PREC_INDEX: c_int = 10;
pub const PREC_PRIMARY: c_int = 11;
pub const Precedence = c_uint;

pub const ParseFn = ?*const fn (bool) callconv(.C) void;
pub const ParseRule = extern struct {
    prefix: ParseFn = @import("std").mem.zeroes(ParseFn),
    infix: ParseFn = @import("std").mem.zeroes(ParseFn),
    precedence: Precedence = @import("std").mem.zeroes(Precedence),
};
pub const Local = extern struct {
    name: Token = @import("std").mem.zeroes(.TOKEN),
    depth: c_int = @import("std").mem.zeroes(c_int),
    isCaptured: bool = @import("std").mem.zeroes(bool),
};
pub const Upvalue = extern struct {
    index: u8 = @import("std").mem.zeroes(u8),
    isLocal: bool = @import("std").mem.zeroes(bool),
};

pub const TYPE_FUNCTION: c_int = 0;
pub const TYPE_METHOD: c_int = 1;
pub const TYPE_INITIALIZER: c_int = 2;
pub const TYPE_SCRIPT: c_int = 3;
pub const FunctionType = c_uint;

pub const ClassCompiler = extern struct {
    enclosing: [*c]ClassCompiler = @import("std").mem.zeroes([*c]ClassCompiler),
    hasSuperClass: bool = @import("std").mem.zeroes(bool),
};

pub const Compiler = extern struct {
    enclosing: [*c]Compiler = @import("std").mem.zeroes([*c]Compiler),
    function: [*c]ObjFunction = @import("std").mem.zeroes([*c]ObjFunction),
    type: FunctionType = @import("std").mem.zeroes(FunctionType),
    locals: [256]Local = @import("std").mem.zeroes([256]Local),
    localCount: c_int = @import("std").mem.zeroes(c_int),
    upvalues: [256]Upvalue = @import("std").mem.zeroes([256]Upvalue),
    scopeDepth: c_int = @import("std").mem.zeroes(c_int),
};

pub export var parser: Parser = @import("std").mem.zeroes(Parser);
pub export var current: [*c]Compiler = null;
pub export var currentClass: [*c]ClassCompiler = null;

pub fn currentChunk() callconv(.C) [*c]Chunk {
    return &current.*.function.*.chunk;
}
pub fn errorAt(arg_token: [*c]Token, arg_message: [*c]const u8) callconv(.C) void {
    var token = arg_token;
    _ = &token;
    var message = arg_message;
    _ = &message;
    if (parser.panicMode) return;
    parser.panicMode = @as(c_int, 1) != 0;
    print("[line {d}] Error", .{token.*.line});
    if (.TOKEN.*.type == .TOKEN_EOF) {
        print(" at end", .{});
    } else if (.TOKEN.*.type == .TOKEN_ERROR) {} else {
        print(" at '{s}'", .{token.*.start[0..token.*.length]});
    }
    print(": {s}\n", .{message});
    parser.hadError = @as(c_int, 1) != 0;
}

pub fn @"error"(arg_message: [*c]const u8) callconv(.C) void {
    var message = arg_message;
    _ = &message;
    errorAt(&parser.previous, message);
}
pub fn errorAtCurrent(arg_message: [*c]const u8) callconv(.C) void {
    var message = arg_message;
    _ = &message;
    errorAt(&parser.current, message);
}

pub fn advance() callconv(.C) void {
    parser.previous = parser.current;
    while (true) {
        parser.current = scanner_h.scanToken();
        if (parser.current.type != .TOKEN_ERROR) break;
        errorAtCurrent(parser.current.start);
    }
}
pub fn consume(arg_type: TokenType, arg_message: [*c]const u8) callconv(.C) void {
    var @"type" = arg_type;
    _ = &@"type";
    var message = arg_message;
    _ = &message;
    if (parser.current.type == @"type") {
        advance();
        return;
    }
    errorAtCurrent(message);
}
pub fn check(arg_type: TokenType) callconv(.C) bool {
    var @"type" = arg_type;
    _ = &@"type";
    return parser.current.type == @"type";
}
pub fn match(arg_type: TokenType) callconv(.C) bool {
    var @"type" = arg_type;
    _ = &@"type";
    if (!check(@"type")) return @as(c_int, 0) != 0;
    advance();
    return @as(c_int, 1) != 0;
}
pub fn emitByte(arg_byte: u8) callconv(.C) void {
    var byte = arg_byte;
    _ = &byte;
    chunk_h.writeChunk(currentChunk(), byte, parser.previous.line);
}
pub fn emitBytes(arg_byte1: u8, arg_byte2: u8) callconv(.C) void {
    var byte1 = arg_byte1;
    _ = &byte1;
    var byte2 = arg_byte2;
    _ = &byte2;
    emitByte(byte1);
    emitByte(byte2);
}
pub fn emitLoop(arg_loopStart: c_int) callconv(.C) void {
    var loopStart = arg_loopStart;
    _ = &loopStart;
    emitByte(@as(u8, .OP_LOOP));
    var offset: c_int = (currentChunk().*.count - loopStart) + @as(c_int, 2);
    _ = &offset;
    if (offset > @as(c_int, 65535)) {
        @"error"("Loop body too large.");
    }
    emitByte(@as(u8, @bitCast(@as(i8, @truncate((offset >> @intCast(8)) & @as(c_int, 255))))));
    emitByte(@as(u8, @bitCast(@as(i8, @truncate(offset & @as(c_int, 255))))));
}

pub fn emitJump(arg_instruction: u8) callconv(.C) c_int {
    var instruction = arg_instruction;
    _ = &instruction;
    emitByte(instruction);
    emitByte(@as(u8, @bitCast(@as(i8, @truncate(@as(c_int, 255))))));
    emitByte(@as(u8, @bitCast(@as(i8, @truncate(@as(c_int, 255))))));
    return currentChunk().*.count - @as(c_int, 2);
}
pub fn emitReturn() callconv(.C) void {
    if (current.*.type == @as(c_uint, @bitCast(TYPE_INITIALIZER))) {
        emitBytes(@as(u8, @bitCast(@as(i8, @truncate(.OP_GET_LOCAL)))), @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, 0))))));
    } else {
        emitByte(@as(u8, @bitCast(@as(i8, @truncate(.OP_NIL)))));
    }
    emitByte(@as(u8, @bitCast(@as(i8, @truncate(.OP_RETURN)))));
}
pub fn makeConstant(arg_value: Value) callconv(.C) u8 {
    var value = arg_value;
    _ = &value;
    var constant: c_int = chunk_h.addConstant(currentChunk(), value);
    _ = &constant;
    if (constant > @as(c_int, 255)) {
        @"error"("Too many constants in one chunk.");
        return 0;
    }
    return @as(u8, @bitCast(@as(i8, @truncate(constant))));
}
pub fn emitConstant(arg_value: Value) callconv(.C) void {
    var value = arg_value;
    _ = &value;
    emitBytes(@as(u8, @bitCast(@as(i8, @truncate(.OP_CONSTANT)))), makeConstant(value));
}
pub fn patchJump(arg_offset: c_int) callconv(.C) void {
    var offset = arg_offset;
    _ = &offset;
    var jump: c_int = (currentChunk().*.count - offset) - @as(c_int, 2);
    _ = &jump;
    if (jump > @as(c_int, 65535)) {
        @"error"("Too much code to jump over.");
    }
    (blk: {
        const tmp = offset;
        if (tmp >= 0) break :blk currentChunk().*.code + @as(usize, @intCast(tmp)) else break :blk currentChunk().*.code - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).* = @as(u8, @bitCast(@as(i8, @truncate((jump >> @intCast(8)) & @as(c_int, 255)))));
    (blk: {
        const tmp = offset + @as(c_int, 1);
        if (tmp >= 0) break :blk currentChunk().*.code + @as(usize, @intCast(tmp)) else break :blk currentChunk().*.code - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).* = @as(u8, @bitCast(@as(i8, @truncate(jump & @as(c_int, 255)))));
}
pub fn initCompiler(arg_compiler: [*c]Compiler, arg_type: FunctionType) callconv(.C) void {
    var compiler = arg_compiler;
    _ = &compiler;
    var @"type" = arg_type;
    _ = &@"type";
    compiler.*.enclosing = current;
    compiler.*.function = null;
    compiler.*.type = @"type";
    compiler.*.localCount = 0;
    compiler.*.scopeDepth = 0;
    compiler.*.function = object_h.newFunction();
    current = compiler;
    if (@"type" != @as(c_uint, @bitCast(TYPE_SCRIPT))) {
        current.*.function.*.name = object_h.copyString(parser.previous.start, parser.previous.length);
    }
    var local: [*c]Local = &current.*.locals[
        @as(c_uint, @intCast(blk: {
            const ref = &current.*.localCount;
            const tmp = ref.*;
            ref.* += 1;
            break :blk tmp;
        }))
    ];
    _ = &local;
    local.*.depth = 0;
    local.*.isCaptured = @as(c_int, 0) != 0;
    if (@"type" != @as(c_uint, @bitCast(TYPE_FUNCTION))) {
        local.*.name.start = "self";
        local.*.name.length = 4;
    } else {
        local.*.name.start = "";
        local.*.name.length = 0;
    }
}
pub fn endCompiler() callconv(.C) [*c]ObjFunction {
    emitReturn();
    var function_1: [*c]ObjFunction = current.*.function;
    _ = &function_1;
    current = current.*.enclosing;
    return function_1;
}
pub fn beginScope() callconv(.C) void {
    current.*.scopeDepth += 1;
}
pub fn endScope() callconv(.C) void {
    current.*.scopeDepth -= 1;
    while ((current.*.localCount > @as(c_int, 0)) and (current.*.locals[@as(c_uint, @intCast(current.*.localCount - @as(c_int, 1)))].depth > current.*.scopeDepth)) {
        if (current.*.locals[@as(c_uint, @intCast(current.*.localCount - @as(c_int, 1)))].isCaptured) {
            emitByte(@as(u8, @bitCast(@as(i8, @truncate(.OP_CLOSE_UPVALUE)))));
        } else {
            emitByte(@as(u8, @bitCast(@as(i8, @truncate(.OP_POP)))));
        }
        current.*.localCount -= 1;
    }
}
pub fn expression() callconv(.C) void {
    parsePrecedence(@as(c_uint, @bitCast(PREC_ASSIGNMENT)));
}
pub fn statement() callconv(.C) void {
    if (match(.TOKEN_PRINT)) {
        printStatement();
    } else if (match(.TOKEN_FOR)) {
        forStatement();
    } else if (match(.TOKEN_EACH)) {
        eachStatement();
    } else if (match(.TOKEN_IF)) {
        ifStatement();
    } else if (match(.TOKEN_RETURN)) {
        returnStatement();
    } else if (match(.TOKEN_WHILE)) {
        whileStatement();
    } else if (match(.TOKEN_LEFT_BRACE)) {
        beginScope();
        block();
        endScope();
    } else {
        expressionStatement();
    }
}
pub fn declaration() callconv(.C) void {
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
pub fn getRule(arg_type: TokenType) callconv(.C) [*c]ParseRule {
    var @"type" = arg_type;
    _ = &@"type";
    return &rules[@"type"];
}
pub fn parsePrecedence(arg_precedence: Precedence) callconv(.C) void {
    var precedence = arg_precedence;
    _ = &precedence;
    advance();
    var prefixRule: ParseFn = getRule(parser.previous.type).*.prefix;
    _ = &prefixRule;
    if (prefixRule == @as(ParseFn, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) {
        @"error"("Expect expression.");
        return;
    }
    var canAssign: bool = precedence <= @as(c_uint, @bitCast(PREC_ASSIGNMENT));
    _ = &canAssign;
    prefixRule.?(canAssign);
    while (precedence <= getRule(parser.current.type).*.precedence) {
        advance();
        var infixRule: ParseFn = getRule(parser.previous.type).*.infix;
        _ = &infixRule;
        infixRule.?(canAssign);
    }
    if ((@as(c_int, @intFromBool(canAssign)) != 0) and (@as(c_int, @intFromBool(match(.TOKEN_EQUAL))) != 0)) {
        @"error"("Invalid assignment target.");
    }
}
pub fn identifierConstant(arg_name: [*c]Token) callconv(.C) u8 {
    var name = arg_name;
    _ = &name;
    return makeConstant(Value{
        .type = @as(c_uint, @bitCast(.VAL_OBJ)),
        .as = .{
            .obj = @as([*c]object_h.Obj, @ptrCast(@alignCast(object_h.copyString(name.*.start, name.*.length)))),
        },
    });
}
pub fn identifiersEqual(arg_a: [*c]Token, arg_b: [*c]Token) callconv(.C) bool {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    if (a.*.length != b.*.length) return @as(c_int, 0) != 0;
    return scanner_h.memcmp(@as(?*const anyopaque, @ptrCast(a.*.start)), @as(?*const anyopaque, @ptrCast(b.*.start)), @as(c_ulong, @bitCast(@as(c_long, a.*.length)))) == @as(c_int, 0);
}
pub fn resolveLocal(arg_compiler: [*c]Compiler, arg_name: [*c]Token) callconv(.C) c_int {
    var compiler = arg_compiler;
    _ = &compiler;
    var name = arg_name;
    _ = &name;
    {
        var i: c_int = compiler.*.localCount - @as(c_int, 1);
        _ = &i;
        while (i >= @as(c_int, 0)) : (i -= 1) {
            var local: [*c]Local = &compiler.*.locals[@as(c_uint, @intCast(i))];
            _ = &local;
            if (identifiersEqual(name, &local.*.name)) {
                if (local.*.depth == -@as(c_int, 1)) {
                    @"error"("Can't read local variable in its own initializer.");
                }
                return i;
            }
        }
    }
    return -@as(c_int, 1);
}

pub fn addUpvalue(arg_compiler: [*c]Compiler, arg_index_1: u8, arg_isLocal: bool) callconv(.C) c_int {
    var compiler = arg_compiler;
    _ = &compiler;
    var index_1 = arg_index_1;
    _ = &index_1;
    var isLocal = arg_isLocal;
    _ = &isLocal;
    var upvalueCount: c_int = compiler.*.function.*.upvalueCount;
    _ = &upvalueCount;
    {
        var i: c_int = 0;
        _ = &i;
        while (i < upvalueCount) : (i += 1) {
            var upvalue: [*c]Upvalue = &compiler.*.upvalues[@as(c_uint, @intCast(i))];
            _ = &upvalue;
            if ((@as(c_int, @bitCast(@as(c_uint, upvalue.*.index))) == @as(c_int, @bitCast(@as(c_uint, index_1)))) and (@as(c_int, @intFromBool(upvalue.*.isLocal)) == @as(c_int, @intFromBool(isLocal)))) {
                return i;
            }
        }
    }
    if (upvalueCount == (@as(c_int, 255) + @as(c_int, 1))) {
        @"error"("Too many closures variables in function.");
        return 0;
    }
    compiler.*.upvalues[@as(c_uint, @intCast(upvalueCount))].isLocal = isLocal;
    compiler.*.upvalues[@as(c_uint, @intCast(upvalueCount))].index = index_1;
    return blk: {
        const ref = &compiler.*.function.*.upvalueCount;
        const tmp = ref.*;
        ref.* += 1;
        break :blk tmp;
    };
}
pub fn resolveUpvalue(arg_compiler: [*c]Compiler, arg_name: [*c]Token) callconv(.C) c_int {
    var compiler = arg_compiler;
    _ = &compiler;
    var name = arg_name;
    _ = &name;
    if (compiler.*.enclosing == @as([*c]Compiler, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) return -@as(c_int, 1);
    var local: c_int = resolveLocal(compiler.*.enclosing, name);
    _ = &local;
    if (local != -@as(c_int, 1)) {
        compiler.*.enclosing.*.locals[@as(c_uint, @intCast(local))].isCaptured = @as(c_int, 1) != 0;
        return addUpvalue(compiler, @as(u8, @bitCast(@as(i8, @truncate(local)))), @as(c_int, 1) != 0);
    }
    var upvalue: c_int = resolveUpvalue(compiler.*.enclosing, name);
    _ = &upvalue;
    if (upvalue != -@as(c_int, 1)) {
        return addUpvalue(compiler, @as(u8, @bitCast(@as(i8, @truncate(upvalue)))), @as(c_int, 0) != 0);
    }
    return -@as(c_int, 1);
}
pub fn addLocal(arg_name: Token) callconv(.C) void {
    var name = arg_name;
    _ = &name;
    if (current.*.localCount == (@as(c_int, 255) + @as(c_int, 1))) {
        @"error"("Too many local variables in function.");
        return;
    }
    var local: [*c]Local = &current.*.locals[
        @as(c_uint, @intCast(blk: {
            const ref = &current.*.localCount;
            const tmp = ref.*;
            ref.* += 1;
            break :blk tmp;
        }))
    ];
    _ = &local;
    local.*.name = name;
    local.*.depth = -@as(c_int, 1);
    local.*.isCaptured = @as(c_int, 0) != 0;
}
pub fn declareVariable() callconv(.C) void {
    if (current.*.scopeDepth == @as(c_int, 0)) return;
    var name: [*c]Token = &parser.previous;
    _ = &name;
    {
        var i: c_int = current.*.localCount - @as(c_int, 1);
        _ = &i;
        while (i >= @as(c_int, 0)) : (i -= 1) {
            var local: [*c]Local = &current.*.locals[@as(c_uint, @intCast(i))];
            _ = &local;
            if ((local.*.depth != -@as(c_int, 1)) and (local.*.depth < current.*.scopeDepth)) {
                break;
            }
            if (identifiersEqual(name, &local.*.name)) {
                @"error"("Already a variable with this name in this scope.");
                return;
            }
        }
    }
    addLocal(name.*);
}
pub fn parseVariable(arg_errorMessage: [*c]const u8) callconv(.C) u8 {
    var errorMessage = arg_errorMessage;
    _ = &errorMessage;
    consume(.TOKEN_IDENTIFIER, errorMessage);
    declareVariable();
    if (current.*.scopeDepth > @as(c_int, 0)) return 0;
    return identifierConstant(&parser.previous);
}
pub fn markInitialized() callconv(.C) void {
    if (current.*.scopeDepth == @as(c_int, 0)) return;
    current.*.locals[@as(c_uint, @intCast(current.*.localCount - @as(c_int, 1)))].depth = current.*.scopeDepth;
}
pub fn defineVariable(arg_global: u8) callconv(.C) void {
    var global = arg_global;
    _ = &global;
    if (current.*.scopeDepth > @as(c_int, 0)) {
        markInitialized();
        return;
    }
    emitBytes(@as(u8, @bitCast(@as(i8, @truncate(.OP_DEFINE_GLOBAL)))), global);
}
pub fn argumentList() callconv(.C) u8 {
    var argCount: u8 = 0;
    _ = &argCount;
    if (!check(.TOKEN_RIGHT_PAREN)) {
        while (true) {
            expression();
            if (@as(c_int, @bitCast(@as(c_uint, argCount))) == @as(c_int, 255)) {
                @"error"("Can't have more than 255 arguments.");
            }
            argCount +%= 1;
            if (!match(.TOKEN_COMMA)) break;
        }
    }
    consume(.TOKEN_RIGHT_PAREN, "Expect ')' after arguments.");
    return argCount;
}
pub fn and_(arg_canAssign: bool) callconv(.C) void {
    var canAssign = arg_canAssign;
    _ = &canAssign;
    var endJump: c_int = emitJump(@as(u8, @bitCast(@as(i8, @truncate(.OP_JUMP_IF_FALSE)))));
    _ = &endJump;
    emitByte(@as(u8, @bitCast(@as(i8, @truncate(.OP_POP)))));
    parsePrecedence(@as(c_uint, @bitCast(PREC_AND)));
    patchJump(endJump);
}
pub fn binary(arg_canAssign: bool) callconv(.C) void {
    var canAssign = arg_canAssign;
    _ = &canAssign;
    var operatorType: TokenType = parser.previous.type;
    _ = &operatorType;
    var rule: [*c]ParseRule = getRule(operatorType);
    _ = &rule;
    parsePrecedence(rule.*.precedence +% @as(c_uint, @bitCast(@as(c_int, 1))));
    while (true) {
        switch (operatorType) {
            @as(c_uint, @bitCast(@as(c_int, 13))) => {
                emitBytes(@as(u8, @bitCast(@as(i8, @truncate(.OP_EQUAL)))), @as(u8, @bitCast(@as(i8, @truncate(.OP_NOT)))));
                break;
            },
            @as(c_uint, @bitCast(@as(c_int, 15))) => {
                emitByte(@as(u8, @bitCast(@as(i8, @truncate(.OP_EQUAL)))));
                break;
            },
            @as(c_uint, @bitCast(@as(c_int, 16))) => {
                emitByte(@as(u8, @bitCast(@as(i8, @truncate(.OP_GREATER)))));
                break;
            },
            @as(c_uint, @bitCast(@as(c_int, 17))) => {
                emitBytes(@as(u8, @bitCast(@as(i8, @truncate(.OP_LESS)))), @as(u8, @bitCast(@as(i8, @truncate(.OP_NOT)))));
                break;
            },
            @as(c_uint, @bitCast(@as(c_int, 18))) => {
                emitByte(@as(u8, @bitCast(@as(i8, @truncate(.OP_LESS)))));
                break;
            },
            @as(c_uint, @bitCast(@as(c_int, 19))) => {
                emitBytes(@as(u8, @bitCast(@as(i8, @truncate(.OP_GREATER)))), @as(u8, @bitCast(@as(i8, @truncate(.OP_NOT)))));
                break;
            },
            @as(c_uint, @bitCast(@as(c_int, 7))) => {
                emitByte(@as(u8, @bitCast(@as(i8, @truncate(.OP_ADD)))));
                break;
            },
            @as(c_uint, @bitCast(@as(c_int, 6))) => {
                emitByte(@as(u8, @bitCast(@as(i8, @truncate(.OP_SUBTRACT)))));
                break;
            },
            @as(c_uint, @bitCast(@as(c_int, 10))) => {
                emitByte(@as(u8, @bitCast(@as(i8, @truncate(.OP_MULTIPLY)))));
                break;
            },
            @as(c_uint, @bitCast(@as(c_int, 9))) => {
                emitByte(@as(u8, @bitCast(@as(i8, @truncate(.OP_DIVIDE)))));
                break;
            },
            @as(c_uint, @bitCast(@as(c_int, 11))) => {
                emitByte(@as(u8, @bitCast(@as(i8, @truncate(.OP_MODULO)))));
                break;
            },
            @as(c_uint, @bitCast(@as(c_int, 51))) => {
                emitByte(@as(u8, @bitCast(@as(i8, @truncate(.OP_EXPONENT)))));
                break;
            },
            else => return,
        }
        break;
    }
}
pub fn call(arg_canAssign: bool) callconv(.C) void {
    var canAssign = arg_canAssign;
    _ = &canAssign;
    var argCount: u8 = argumentList();
    _ = &argCount;
    emitBytes(@as(u8, @bitCast(@as(i8, @truncate(.OP_CALL)))), argCount);
}
pub fn dot(arg_canAssign: bool) callconv(.C) void {
    var canAssign = arg_canAssign;
    _ = &canAssign;
    consume(.TOKEN_IDENTIFIER, "Expect property name after '.'.");
    var name: u8 = identifierConstant(&parser.previous);
    _ = &name;
    if ((@as(c_int, @intFromBool(canAssign)) != 0) and (@as(c_int, @intFromBool(match(.TOKEN_EQUAL))) != 0)) {
        expression();
        emitBytes(@as(u8, @bitCast(@as(i8, @truncate(.OP_SET_PROPERTY)))), name);
    } else if (match(.TOKEN_LEFT_PAREN)) {
        var argCount: u8 = argumentList();
        _ = &argCount;
        emitBytes(@as(u8, @bitCast(@as(i8, @truncate(.OP_INVOKE)))), name);
        emitByte(argCount);
    } else {
        emitBytes(@as(u8, @bitCast(@as(i8, @truncate(.OP_GET_PROPERTY)))), name);
    }
}
pub fn literal(arg_canAssign: bool) callconv(.C) void {
    var canAssign = arg_canAssign;
    _ = &canAssign;
    while (true) {
        switch (parser.previous.type) {
            @as(c_uint, @bitCast(@as(c_int, 27))) => {
                emitByte(@as(u8, @bitCast(@as(i8, @truncate(.OP_FALSE)))));
                break;
            },
            @as(c_uint, @bitCast(@as(c_int, 33))) => {
                emitByte(@as(u8, @bitCast(@as(i8, @truncate(.OP_NIL)))));
                break;
            },
            @as(c_uint, @bitCast(@as(c_int, 39))) => {
                emitByte(@as(u8, @bitCast(@as(i8, @truncate(.OP_TRUE)))));
                break;
            },
            else => return,
        }
        break;
    }
}
pub fn grouping(arg_canAssign: bool) callconv(.C) void {
    var canAssign = arg_canAssign;
    _ = &canAssign;
    expression();
    consume(.TOKEN_RIGHT_PAREN, "Expect ')' after expression.");
}
pub fn number(arg_canAssign: bool) callconv(.C) void {
    var canAssign = arg_canAssign;
    _ = &canAssign;
    if (parser.previous.type == .TOKEN_INT) {
        var value: c_int = atoi(parser.previous.start);
        _ = &value;
        emitConstant(Value{
            .type = @as(c_uint, @bitCast(.VAL_INT)),
            .as = .{
                .num_int = value,
            },
        });
    } else {
        var value: f64 = strtod(parser.previous.start, null);
        _ = &value;
        emitConstant(Value{
            .type = @as(c_uint, @bitCast(.VAL_DOUBLE)),
            .as = .{
                .num_double = value,
            },
        });
    }
}
pub fn or_(arg_canAssign: bool) callconv(.C) void {
    var canAssign = arg_canAssign;
    _ = &canAssign;
    var elseJump: c_int = emitJump(@as(u8, @bitCast(@as(i8, @truncate(.OP_JUMP_IF_FALSE)))));
    _ = &elseJump;
    var endJump: c_int = emitJump(@as(u8, @bitCast(@as(i8, @truncate(.OP_JUMP)))));
    _ = &endJump;
    patchJump(elseJump);
    emitByte(@as(u8, @bitCast(@as(i8, @truncate(.OP_POP)))));
    parsePrecedence(@as(c_uint, @bitCast(PREC_OR)));
    patchJump(endJump);
}
pub fn string(arg_canAssign: bool) callconv(.C) void {
    var canAssign = arg_canAssign;
    _ = &canAssign;
    emitConstant(Value{
        .type = @as(c_uint, @bitCast(.VAL_OBJ)),
        .as = .{
            .obj = @as([*c]object_h.Obj, @ptrCast(@alignCast(object_h.copyString(parser.previous.start + @as(usize, @bitCast(@as(isize, @intCast(@as(c_int, 1))))), parser.previous.length - @as(c_int, 2))))),
        },
    });
}
pub fn array(arg_canAssign: bool) callconv(.C) void {
    var canAssign = arg_canAssign;
    _ = &canAssign;
    var argCount: u8 = 0;
    _ = &argCount;
    if (!check(.TOKEN_RIGHT_SQPAREN)) {
        while (true) {
            expression();
            argCount +%= 1;
            if (@as(c_int, @bitCast(@as(c_uint, argCount))) > @as(c_int, 255)) {
                @"error"("Can't have more than 255 elements in an array.");
            }
            if (!match(.TOKEN_COMMA)) break;
        }
    }
    consume(.TOKEN_RIGHT_SQPAREN, "Expect ']' after array elements.");
    emitBytes(@as(u8, @bitCast(@as(i8, @truncate(.OP_ARRAY)))), argCount);
}
pub fn fvector(arg_canAssign: bool) callconv(.C) void {
    var canAssign = arg_canAssign;
    _ = &canAssign;
    var argCount: u8 = 0;
    _ = &argCount;
    if (!check(.TOKEN_RIGHT_BRACE)) {
        while (true) {
            expression();
            argCount +%= 1;
            if (@as(c_int, @bitCast(@as(c_uint, argCount))) > @as(c_int, 255)) {
                @"error"("Can't have more than 255 elements in a vector.");
            }
            if (!match(.TOKEN_COMMA)) break;
        }
    }
    consume(.TOKEN_RIGHT_BRACE, "Expect '}' after vector elements.");
    emitBytes(@as(u8, @bitCast(@as(i8, @truncate(.OP_FVECTOR)))), argCount);
}
pub fn namedVariable(arg_name: Token, arg_canAssign: bool) callconv(.C) void {
    var name = arg_name;
    _ = &name;
    var canAssign = arg_canAssign;
    _ = &canAssign;
    var getOp: u8 = undefined;
    _ = &getOp;
    var setOp: u8 = undefined;
    _ = &setOp;
    var arg: c_int = resolveLocal(current, &name);
    _ = &arg;
    if (arg != -@as(c_int, 1)) {
        getOp = @as(u8, @bitCast(@as(i8, @truncate(.OP_GET_LOCAL))));
        setOp = @as(u8, @bitCast(@as(i8, @truncate(.OP_SET_LOCAL))));
    } else if ((blk: {
        const tmp = resolveUpvalue(current, &name);
        arg = tmp;
        break :blk tmp;
    }) != -@as(c_int, 1)) {
        getOp = @as(u8, @bitCast(@as(i8, @truncate(.OP_GET_UPVALUE))));
        setOp = @as(u8, @bitCast(@as(i8, @truncate(.OP_SET_UPVALUE))));
    } else {
        arg = @as(c_int, @bitCast(@as(c_uint, identifierConstant(&name))));
        getOp = @as(u8, @bitCast(@as(i8, @truncate(.OP_GET_GLOBAL))));
        setOp = @as(u8, @bitCast(@as(i8, @truncate(.OP_SET_GLOBAL))));
    }
    if ((@as(c_int, @intFromBool(canAssign)) != 0) and (@as(c_int, @intFromBool(match(.TOKEN_EQUAL))) != 0)) {
        expression();
        emitBytes(setOp, @as(u8, @bitCast(@as(i8, @truncate(arg)))));
    } else if ((((@as(c_int, @intFromBool(match(.TOKEN_PLUS_EQUAL))) != 0) or (@as(c_int, @intFromBool(match(.TOKEN_MINUS_EQUAL))) != 0)) or (@as(c_int, @intFromBool(match(.TOKEN_STAR_EQUAL))) != 0)) or (@as(c_int, @intFromBool(match(.TOKEN_SLASH_EQUAL))) != 0)) {
        emitBytes(getOp, @as(u8, @bitCast(@as(i8, @truncate(arg)))));
        expression();
        while (true) {
            switch (parser.previous.type) {
                @as(c_uint, @bitCast(@as(c_int, 45))) => {
                    emitByte(@as(u8, @bitCast(@as(i8, @truncate(.OP_ADD)))));
                    break;
                },
                @as(c_uint, @bitCast(@as(c_int, 46))) => {
                    emitByte(@as(u8, @bitCast(@as(i8, @truncate(.OP_SUBTRACT)))));
                    break;
                },
                @as(c_uint, @bitCast(@as(c_int, 47))) => {
                    emitByte(@as(u8, @bitCast(@as(i8, @truncate(.OP_MULTIPLY)))));
                    break;
                },
                @as(c_uint, @bitCast(@as(c_int, 48))) => {
                    emitByte(@as(u8, @bitCast(@as(i8, @truncate(.OP_DIVIDE)))));
                    break;
                },
                else => return,
            }
            break;
        }
        emitBytes(setOp, @as(u8, @bitCast(@as(i8, @truncate(arg)))));
    } else if (match(.TOKEN_PLUS_PLUS)) {
        emitBytes(getOp, @as(u8, @bitCast(@as(i8, @truncate(arg)))));
        emitByte(@as(u8, @bitCast(@as(i8, @truncate(.OP_CONSTANT)))));
        emitByte(makeConstant(Value{
            .type = @as(c_uint, @bitCast(.VAL_INT)),
            .as = .{
                .num_int = @as(c_int, 1),
            },
        }));
        emitByte(@as(u8, @bitCast(@as(i8, @truncate(.OP_ADD)))));
        emitBytes(setOp, @as(u8, @bitCast(@as(i8, @truncate(arg)))));
    } else if (match(.TOKEN_MINUS_MINUS)) {
        emitBytes(getOp, @as(u8, @bitCast(@as(i8, @truncate(arg)))));
        emitByte(@as(u8, @bitCast(@as(i8, @truncate(.OP_CONSTANT)))));
        emitByte(makeConstant(Value{
            .type = @as(c_uint, @bitCast(.VAL_INT)),
            .as = .{
                .num_int = @as(c_int, 1),
            },
        }));
        emitByte(@as(u8, @bitCast(@as(i8, @truncate(.OP_SUBTRACT)))));
        emitBytes(setOp, @as(u8, @bitCast(@as(i8, @truncate(arg)))));
    } else {
        emitBytes(getOp, @as(u8, @bitCast(@as(i8, @truncate(arg)))));
    }
}
pub fn index_(arg_canAssign: bool) callconv(.C) void {
    var canAssign = arg_canAssign;
    _ = &canAssign;
    if (check(.TOKEN_LEFT_SQPAREN)) {
        consume(.TOKEN_LEFT_SQPAREN, "Expect '[' after array.");
        expression();
        consume(.TOKEN_RIGHT_SQPAREN, "Expect ']' after index.");
        if ((@as(c_int, @intFromBool(canAssign)) != 0) and (@as(c_int, @intFromBool(match(.TOKEN_EQUAL))) != 0)) {
            expression();
            emitByte(@as(u8, @bitCast(@as(i8, @truncate(.OP_INDEX_SET)))));
        } else {
            emitByte(@as(u8, @bitCast(@as(i8, @truncate(.OP_INDEX_GET)))));
        }
    } else {
        vm_h.runtimeError("Only arrays support indexing.");
    }
}
pub fn variable(arg_canAssign: bool) callconv(.C) void {
    var canAssign = arg_canAssign;
    _ = &canAssign;
    namedVariable(parser.previous, canAssign);
}

pub fn syntheticToken(arg_text: [*c]const u8) callconv(.C) Token {
    var text = arg_text;
    _ = &text;
    var token: Token = Token{
        .type = @import("std").mem.zeroes(TokenType),
        .start = text,
        .length = @as(c_int, @bitCast(@as(c_uint, @truncate(scanner_h.strlen(text))))),
        .line = 0,
    };
    _ = &token;
    return token;
}
pub fn super_(arg_canAssign: bool) callconv(.C) void {
    var canAssign = arg_canAssign;
    _ = &canAssign;
    if (currentClass == @as([*c]ClassCompiler, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) {
        @"error"("Can't use 'super' outside of a class.");
    } else if (!currentClass.*.hasSuperClass) {
        @"error"("Can't use 'super' in a class with no superclass.");
    }
    consume(.TOKEN_DOT, "Expect '.' after 'super'.");
    consume(.TOKEN_IDENTIFIER, "Expect superclass method name.");
    var name: u8 = identifierConstant(&parser.previous);
    _ = &name;
    namedVariable(syntheticToken("self"), @as(c_int, 0) != 0);
    if (match(.TOKEN_LEFT_PAREN)) {
        var argCount: u8 = argumentList();
        _ = &argCount;
        namedVariable(syntheticToken("super"), @as(c_int, 0) != 0);
        emitBytes(@as(u8, @bitCast(@as(i8, @truncate(.OP_SUPER_INVOKE)))), name);
        emitByte(argCount);
    } else {
        namedVariable(syntheticToken("super"), @as(c_int, 0) != 0);
        emitBytes(@as(u8, @bitCast(@as(i8, @truncate(.OP_GET_SUPER)))), name);
    }
}
pub fn self_(arg_canAssign: bool) callconv(.C) void {
    var canAssign = arg_canAssign;
    _ = &canAssign;
    if (currentClass == @as([*c]ClassCompiler, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) {
        @"error"("Can't use 'self' outside of a class.");
        return;
    }
    variable(@as(c_int, 0) != 0);
}
pub fn item_(arg_canAssign: bool) callconv(.C) void {
    var canAssign = arg_canAssign;
    _ = &canAssign;
    variable(@as(c_int, 0) != 0);
}
pub fn unary(arg_canAssign: bool) callconv(.C) void {
    var canAssign = arg_canAssign;
    _ = &canAssign;
    var operatorType: TokenType = parser.previous.type;
    _ = &operatorType;
    parsePrecedence(@as(c_uint, @bitCast(PREC_UNARY)));
    while (true) {
        switch (operatorType) {
            @as(c_uint, @bitCast(@as(c_int, 12))) => {
                emitByte(@as(u8, @bitCast(@as(i8, @truncate(.OP_NOT)))));
                break;
            },
            @as(c_uint, @bitCast(@as(c_int, 6))) => {
                emitByte(@as(u8, @bitCast(@as(i8, @truncate(.OP_NEGATE)))));
                break;
            },
            else => return,
        }
        break;
    }
}
pub export var rules: [54]ParseRule = [54]ParseRule{
    ParseRule{
        .prefix = &grouping,
        .infix = &call,
        .precedence = @as(c_uint, @bitCast(PREC_CALL)),
    },
    ParseRule{
        .prefix = null,
        .infix = null,
        .precedence = @as(c_uint, @bitCast(PREC_NONE)),
    },
    ParseRule{
        .prefix = &fvector,
        .infix = null,
        .precedence = @as(c_uint, @bitCast(PREC_NONE)),
    },
    ParseRule{
        .prefix = null,
        .infix = null,
        .precedence = @as(c_uint, @bitCast(PREC_NONE)),
    },
    ParseRule{
        .prefix = null,
        .infix = null,
        .precedence = @as(c_uint, @bitCast(PREC_NONE)),
    },
    ParseRule{
        .prefix = null,
        .infix = &dot,
        .precedence = @as(c_uint, @bitCast(PREC_CALL)),
    },
    ParseRule{
        .prefix = &unary,
        .infix = &binary,
        .precedence = @as(c_uint, @bitCast(PREC_TERM)),
    },
    ParseRule{
        .prefix = null,
        .infix = &binary,
        .precedence = @as(c_uint, @bitCast(PREC_TERM)),
    },
    ParseRule{
        .prefix = null,
        .infix = null,
        .precedence = @as(c_uint, @bitCast(PREC_NONE)),
    },
    ParseRule{
        .prefix = null,
        .infix = &binary,
        .precedence = @as(c_uint, @bitCast(PREC_FACTOR)),
    },
    ParseRule{
        .prefix = null,
        .infix = &binary,
        .precedence = @as(c_uint, @bitCast(PREC_FACTOR)),
    },
    ParseRule{
        .prefix = null,
        .infix = &binary,
        .precedence = @as(c_uint, @bitCast(PREC_FACTOR)),
    },
    ParseRule{
        .prefix = &unary,
        .infix = null,
        .precedence = @as(c_uint, @bitCast(PREC_NONE)),
    },
    ParseRule{
        .prefix = null,
        .infix = &binary,
        .precedence = @as(c_uint, @bitCast(PREC_EQUALITY)),
    },
    ParseRule{
        .prefix = null,
        .infix = null,
        .precedence = @as(c_uint, @bitCast(PREC_NONE)),
    },
    ParseRule{
        .prefix = null,
        .infix = &binary,
        .precedence = @as(c_uint, @bitCast(PREC_EQUALITY)),
    },
    ParseRule{
        .prefix = null,
        .infix = &binary,
        .precedence = @as(c_uint, @bitCast(PREC_COMPARISON)),
    },
    ParseRule{
        .prefix = null,
        .infix = &binary,
        .precedence = @as(c_uint, @bitCast(PREC_COMPARISON)),
    },
    ParseRule{
        .prefix = null,
        .infix = &binary,
        .precedence = @as(c_uint, @bitCast(PREC_COMPARISON)),
    },
    ParseRule{
        .prefix = null,
        .infix = &binary,
        .precedence = @as(c_uint, @bitCast(PREC_COMPARISON)),
    },
    ParseRule{
        .prefix = &variable,
        .infix = &index_,
        .precedence = @as(c_uint, @bitCast(PREC_NONE)),
    },
    ParseRule{
        .prefix = &string,
        .infix = null,
        .precedence = @as(c_uint, @bitCast(PREC_NONE)),
    },
    ParseRule{
        .prefix = &number,
        .infix = null,
        .precedence = @as(c_uint, @bitCast(PREC_NONE)),
    },
    ParseRule{
        .prefix = &number,
        .infix = null,
        .precedence = @as(c_uint, @bitCast(PREC_NONE)),
    },
    ParseRule{
        .prefix = null,
        .infix = &and_,
        .precedence = @as(c_uint, @bitCast(PREC_AND)),
    },
    ParseRule{
        .prefix = null,
        .infix = null,
        .precedence = @as(c_uint, @bitCast(PREC_NONE)),
    },
    ParseRule{
        .prefix = null,
        .infix = null,
        .precedence = @as(c_uint, @bitCast(PREC_NONE)),
    },
    ParseRule{
        .prefix = &literal,
        .infix = null,
        .precedence = @as(c_uint, @bitCast(PREC_NONE)),
    },
    ParseRule{
        .prefix = null,
        .infix = null,
        .precedence = @as(c_uint, @bitCast(PREC_NONE)),
    },
    ParseRule{
        .prefix = null,
        .infix = null,
        .precedence = @as(c_uint, @bitCast(PREC_NONE)),
    },
    ParseRule{
        .prefix = null,
        .infix = null,
        .precedence = @as(c_uint, @bitCast(PREC_NONE)),
    },
    ParseRule{
        .prefix = null,
        .infix = null,
        .precedence = @as(c_uint, @bitCast(PREC_NONE)),
    },
    ParseRule{
        .prefix = null,
        .infix = null,
        .precedence = @as(c_uint, @bitCast(PREC_NONE)),
    },
    ParseRule{
        .prefix = &literal,
        .infix = null,
        .precedence = @as(c_uint, @bitCast(PREC_NONE)),
    },
    ParseRule{
        .prefix = null,
        .infix = &or_,
        .precedence = @as(c_uint, @bitCast(PREC_OR)),
    },
    ParseRule{
        .prefix = null,
        .infix = null,
        .precedence = @as(c_uint, @bitCast(PREC_NONE)),
    },
    ParseRule{
        .prefix = null,
        .infix = null,
        .precedence = @as(c_uint, @bitCast(PREC_NONE)),
    },
    ParseRule{
        .prefix = &self_,
        .infix = null,
        .precedence = @as(c_uint, @bitCast(PREC_NONE)),
    },
    ParseRule{
        .prefix = &super_,
        .infix = null,
        .precedence = @as(c_uint, @bitCast(PREC_NONE)),
    },
    ParseRule{
        .prefix = &literal,
        .infix = null,
        .precedence = @as(c_uint, @bitCast(PREC_NONE)),
    },
    ParseRule{
        .prefix = null,
        .infix = null,
        .precedence = @as(c_uint, @bitCast(PREC_NONE)),
    },
    ParseRule{
        .prefix = null,
        .infix = null,
        .precedence = @as(c_uint, @bitCast(PREC_NONE)),
    },
    ParseRule{
        .prefix = &item_,
        .infix = null,
        .precedence = @as(c_uint, @bitCast(PREC_NONE)),
    },
    ParseRule{
        .prefix = null,
        .infix = null,
        .precedence = @as(c_uint, @bitCast(PREC_NONE)),
    },
    ParseRule{
        .prefix = null,
        .infix = null,
        .precedence = @as(c_uint, @bitCast(PREC_NONE)),
    },
    ParseRule{
        .prefix = null,
        .infix = null,
        .precedence = @as(c_uint, @bitCast(PREC_NONE)),
    },
    ParseRule{
        .prefix = null,
        .infix = null,
        .precedence = @as(c_uint, @bitCast(PREC_NONE)),
    },
    ParseRule{
        .prefix = null,
        .infix = null,
        .precedence = @as(c_uint, @bitCast(PREC_NONE)),
    },
    ParseRule{
        .prefix = null,
        .infix = null,
        .precedence = @as(c_uint, @bitCast(PREC_NONE)),
    },
    ParseRule{
        .prefix = null,
        .infix = null,
        .precedence = @as(c_uint, @bitCast(PREC_NONE)),
    },
    ParseRule{
        .prefix = null,
        .infix = null,
        .precedence = @as(c_uint, @bitCast(PREC_NONE)),
    },
    ParseRule{
        .prefix = null,
        .infix = &binary,
        .precedence = @as(c_uint, @bitCast(PREC_FACTOR)),
    },
    ParseRule{
        .prefix = &array,
        .infix = null,
        .precedence = @as(c_uint, @bitCast(PREC_INDEX)),
    },
    ParseRule{
        .prefix = null,
        .infix = null,
        .precedence = @as(c_uint, @bitCast(PREC_NONE)),
    },
};
pub fn block() callconv(.C) void {
    while (!check(.TOKEN_RIGHT_BRACE) and !check(.TOKEN_EOF)) {
        declaration();
    }
    consume(.TOKEN_RIGHT_BRACE, "Expect '}' after block.");
}
pub fn function(arg_type: FunctionType) callconv(.C) void {
    var @"type" = arg_type;
    _ = &@"type";
    var compiler: Compiler = undefined;
    _ = &compiler;
    initCompiler(&compiler, @"type");
    beginScope();
    consume(.TOKEN_LEFT_PAREN, "Expect '(' after function name.");
    if (!check(.TOKEN_RIGHT_PAREN)) {
        while (true) {
            current.*.function.*.arity += 1;
            if (current.*.function.*.arity > @as(c_int, 255)) {
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
    var function_1: [*c]ObjFunction = endCompiler();
    _ = &function_1;
    emitBytes(@as(u8, @bitCast(@as(i8, @truncate(.OP_CLOSURE)))), makeConstant(Value{
        .type = @as(c_uint, @bitCast(.VAL_OBJ)),
        .as = .{
            .obj = @as([*c]object_h.Obj, @ptrCast(@alignCast(function_1))),
        },
    }));
    {
        var i: c_int = 0;
        _ = &i;
        while (i < function_1.*.upvalueCount) : (i += 1) {
            emitByte(@as(u8, @bitCast(@as(i8, @truncate(if (@as(c_int, @intFromBool(compiler.upvalues[@as(c_uint, @intCast(i))].isLocal)) != 0) @as(c_int, 1) else @as(c_int, 0))))));
            emitByte(compiler.upvalues[@as(c_uint, @intCast(i))].index);
        }
    }
}
pub fn method() callconv(.C) void {
    consume(.TOKEN_IDENTIFIER, "Expect method name.");
    var constant: u8 = identifierConstant(&parser.previous);
    _ = &constant;
    var @"type": FunctionType = @as(c_uint, @bitCast(TYPE_METHOD));
    _ = &@"type";
    if ((parser.previous.length == @as(c_int, 4)) and (scanner_h.memcmp(@as(?*const anyopaque, @ptrCast(parser.previous.start)), @as(?*const anyopaque, @ptrCast("init")), @as(c_ulong, @bitCast(@as(c_long, @as(c_int, 4))))) == @as(c_int, 0))) {
        @"type" = @as(c_uint, @bitCast(TYPE_INITIALIZER));
    }
    function(@"type");
    emitBytes(@as(u8, @bitCast(@as(i8, @truncate(.OP_METHOD)))), constant);
}

pub fn classDeclaration() callconv(.C) void {
    consume(.TOKEN_IDENTIFIER, "Expect class name.");
    var className: Token = parser.previous;
    _ = &className;
    var nameConstant: u8 = identifierConstant(&parser.previous);
    _ = &nameConstant;
    declareVariable();
    emitBytes(@as(u8, @bitCast(@as(i8, @truncate(.OP_CLASS)))), nameConstant);
    defineVariable(nameConstant);
    var classCompiler: ClassCompiler = undefined;
    _ = &classCompiler;
    classCompiler.enclosing = currentClass;
    classCompiler.hasSuperClass = @as(c_int, 0) != 0;
    currentClass = &classCompiler;
    if (match(.TOKEN_LESS)) {
        consume(.TOKEN_IDENTIFIER, "Expect superclass name.");
        variable(@as(c_int, 0) != 0);
        if (identifiersEqual(&className, &parser.previous)) {
            @"error"("A class can't inherit itself.");
        }
        beginScope();
        addLocal(syntheticToken("super"));
        defineVariable(@as(u8, @bitCast(@as(i8, @truncate(@as(c_int, 0))))));
        namedVariable(className, @as(c_int, 0) != 0);
        emitByte(@as(u8, @bitCast(@as(i8, @truncate(.OP_INHERIT)))));
        currentClass.*.hasSuperClass = @as(c_int, 1) != 0;
    }
    namedVariable(className, @as(c_int, 0) != 0);
    consume(.TOKEN_LEFT_BRACE, "Expect '{' before class body.");
    while (!check(.TOKEN_RIGHT_BRACE) and !check(.TOKEN_EOF)) {
        method();
    }
    consume(.TOKEN_RIGHT_BRACE, "Expect '}' after class body.");
    emitByte(@as(u8, @bitCast(@as(i8, @truncate(.OP_POP)))));
    if (classCompiler.hasSuperClass) {
        endScope();
    }
    currentClass = currentClass.*.enclosing;
}
pub fn funDeclaration() callconv(.C) void {
    var global: u8 = parseVariable("Expect function name.");
    _ = &global;
    markInitialized();
    function(@as(c_uint, @bitCast(TYPE_FUNCTION)));
    defineVariable(global);
}
pub fn varDeclaration() callconv(.C) void {
    var global: u8 = parseVariable("Expect variable name.");
    _ = &global;
    if (match(.TOKEN_EQUAL)) {
        expression();
    } else {
        emitByte(@as(u8, @bitCast(@as(i8, @truncate(.OP_NIL)))));
    }
    consume(.TOKEN_SEMICOLON, "Expect ';' after variable declaration.");
    defineVariable(global);
}
pub fn expressionStatement() callconv(.C) void {
    expression();
    consume(.TOKEN_SEMICOLON, "Expect ';' after expression.");
    emitByte(@as(u8, @bitCast(@as(i8, @truncate(.OP_POP)))));
}
pub fn forStatement() callconv(.C) void {
    beginScope();
    consume(.TOKEN_LEFT_PAREN, "Expect '(' after 'for'.");
    if (match(.TOKEN_SEMICOLON)) {} else if (match(.TOKEN_VAR)) {
        varDeclaration();
    } else {
        expressionStatement();
    }
    var loopStart: c_int = currentChunk().*.count;
    _ = &loopStart;
    var exitJump: c_int = -@as(c_int, 1);
    _ = &exitJump;
    if (!match(.TOKEN_SEMICOLON)) {
        expression();
        consume(.TOKEN_SEMICOLON, "Expect ';' after loop condition.");
        exitJump = emitJump(@as(u8, @bitCast(@as(i8, @truncate(.OP_JUMP_IF_FALSE)))));
        emitByte(@as(u8, @bitCast(@as(i8, @truncate(.OP_POP)))));
    }
    if (!match(.TOKEN_RIGHT_PAREN)) {
        var bodyJump: c_int = emitJump(@as(u8, @bitCast(@as(i8, @truncate(.OP_JUMP)))));
        _ = &bodyJump;
        var incrementStart: c_int = currentChunk().*.count;
        _ = &incrementStart;
        expression();
        emitByte(@as(u8, @bitCast(@as(i8, @truncate(.OP_POP)))));
        consume(.TOKEN_RIGHT_PAREN, "Expect ')' after for clauses.");
        emitLoop(loopStart);
        loopStart = incrementStart;
        patchJump(bodyJump);
    }
    statement();
    emitLoop(loopStart);
    if (exitJump != -@as(c_int, 1)) {
        patchJump(exitJump);
        emitByte(@as(u8, @bitCast(@as(i8, @truncate(.OP_POP)))));
    }
    endScope();
}
pub fn eachStatement() callconv(.C) void {
    var loopStart: c_int = currentChunk().*.count;
    _ = &loopStart;
    consume(.TOKEN_LEFT_PAREN, "Expect '(' after 'while'.");
    expression();
    consume(.TOKEN_RIGHT_PAREN, "Expect ')' after condition.");
    var exitJump: c_int = emitJump(@as(u8, @bitCast(@as(i8, @truncate(.OP_JUMP_IF_DONE)))));
    _ = &exitJump;
    var item: Token = Token{
        .type = .TOKEN_ITEM,
        .start = "item",
        .length = @as(c_int, 4),
        .line = 0,
    };
    _ = &item;
    emitBytes(@as(u8, @bitCast(@as(i8, @truncate(.OP_SET_GLOBAL)))), identifierConstant(&item));
    statement();
    emitLoop(loopStart);
    patchJump(exitJump);
    emitByte(@as(u8, @bitCast(@as(i8, @truncate(.OP_POP)))));
}
pub fn ifStatement() callconv(.C) void {
    consume(.TOKEN_LEFT_PAREN, "Expect '(' after 'if'.");
    expression();
    consume(.TOKEN_RIGHT_PAREN, "Expect ')' after condition.");
    var thenJump: c_int = emitJump(@as(u8, @bitCast(@as(i8, @truncate(.OP_JUMP_IF_FALSE)))));
    _ = &thenJump;
    emitByte(@as(u8, @bitCast(@as(i8, @truncate(.OP_POP)))));
    statement();
    var elseJump: c_int = emitJump(@as(u8, @bitCast(@as(i8, @truncate(.OP_JUMP)))));
    _ = &elseJump;
    patchJump(thenJump);
    emitByte(@as(u8, @bitCast(@as(i8, @truncate(.OP_POP)))));
    if (match(.TOKEN_ELSE)) {
        statement();
    }
    patchJump(elseJump);
}
pub fn printStatement() callconv(.C) void {
    expression();
    consume(.TOKEN_SEMICOLON, "Expect ';' after value.");
    emitByte(@as(u8, @bitCast(@as(i8, @truncate(.OP_PRINT)))));
}
pub fn returnStatement() callconv(.C) void {
    if (current.*.type == @as(c_uint, @bitCast(TYPE_SCRIPT))) {
        @"error"("Can't return from top-level code.");
    }
    if (match(.TOKEN_SEMICOLON)) {
        emitReturn();
    } else {
        if (current.*.type == @as(c_uint, @bitCast(TYPE_INITIALIZER))) {
            @"error"("Can't return a value from an initializer.");
        }
        expression();
        consume(.TOKEN_SEMICOLON, "Expect ';' after return value.");
        emitByte(@as(u8, @bitCast(@as(i8, @truncate(.OP_RETURN)))));
    }
}
pub fn whileStatement() callconv(.C) void {
    var loopStart: c_int = currentChunk().*.count;
    _ = &loopStart;
    consume(.TOKEN_LEFT_PAREN, "Expect '(' after 'while'.");
    expression();
    consume(.TOKEN_RIGHT_PAREN, "Expect ')' after condition.");
    var exitJump: c_int = emitJump(@as(u8, @bitCast(@as(i8, @truncate(.OP_JUMP_IF_FALSE)))));
    _ = &exitJump;
    emitByte(@as(u8, @bitCast(@as(i8, @truncate(.OP_POP)))));
    statement();
    emitLoop(loopStart);
    patchJump(exitJump);
    emitByte(@as(u8, @bitCast(@as(i8, @truncate(.OP_POP)))));
}
pub fn synchronize() callconv(.C) void {
    parser.panicMode = @as(c_int, 0) != 0;
    while (parser.current.type != .TOKEN_EOF) {
        if (parser.previous.type == .TOKEN_SEMICOLON) return;
        while (true) {
            switch (parser.current.type) {
                @as(c_uint, @bitCast(@as(c_int, 25))), @as(c_uint, @bitCast(@as(c_int, 30))), @as(c_uint, @bitCast(@as(c_int, 40))), @as(c_uint, @bitCast(@as(c_int, 28))), @as(c_uint, @bitCast(@as(c_int, 31))), @as(c_uint, @bitCast(@as(c_int, 41))), @as(c_uint, @bitCast(@as(c_int, 35))), @as(c_uint, @bitCast(@as(c_int, 36))) => return,
                else => {
                    {}
                },
            }
            break;
        }
        advance();
    }
}
