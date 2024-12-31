const scanner_h = @import("scanner.zig");
const debug_opts = @import("debug");
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
const OpCode = chunk_h.OpCode;
const debug_h = @import("debug.zig");

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

pub const ParseFn = ?*const fn (bool) void;
pub const ParseRule = extern struct {
    prefix: ParseFn = null,
    infix: ParseFn = null,
    precedence: Precedence,
};
pub const Local = extern struct {
    name: Token,
    depth: c_int,
    isCaptured: bool,
};
pub const Upvalue = extern struct {
    index: u8,
    isLocal: bool,
};

pub const FunctionType = enum(c_int) {
    TYPE_FUNCTION = 0,
    TYPE_METHOD = 1,
    TYPE_INITIALIZER = 2,
    TYPE_SCRIPT = 3,
};

pub const ClassCompiler = extern struct {
    enclosing: [*c]ClassCompiler,
    hasSuperClass: bool,
};

pub const Compiler = extern struct {
    enclosing: [*c]Compiler,
    function: [*c]ObjFunction,
    type_: FunctionType,
    locals: [256]Local,
    localCount: c_int,
    upvalues: [256]Upvalue,
    scopeDepth: c_int,
};

pub export var parser: Parser = undefined;
pub export var current: [*c]Compiler = null;
pub export var currentClass: [*c]ClassCompiler = null;

pub fn currentChunk() [*c]Chunk {
    return &current.*.function.*.chunk;
}
pub fn errorAt(token: [*c]Token, message: [*c]const u8) void {
    if (parser.panicMode) return;
    parser.panicMode = true;
    print("[line {d}] Error", .{token.*.line});
    if (token.*.type == .TOKEN_EOF) {
        print(" at end", .{});
    } else if (token.*.type == .TOKEN_ERROR) {} else {
        print(" at '{s}'", .{token.*.start[0..@intCast(token.*.length)]});
    }
    print(": {s}\n", .{message});
    parser.hadError = true;
}

pub fn @"error"(message: [*c]const u8) void {
    errorAt(&parser.previous, message);
}
pub fn errorAtCurrent(message: [*c]const u8) void {
    errorAt(&parser.current, message);
}

pub fn advance() void {
    parser.previous = parser.current;
    while (true) {
        parser.current = scanner_h.scanToken();
        if (parser.current.type != .TOKEN_ERROR) break;
        errorAtCurrent(parser.current.start);
    }
}
pub fn consume(type_: TokenType, message: [*c]const u8) void {
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
pub fn emitLoop(loopStart: c_int) void {
    emitByte(@intFromEnum(OpCode.OP_LOOP));
    const offset: c_int = (currentChunk().*.count - loopStart) + 2;

    if (offset > 65535) {
        @"error"("Loop body too large.");
    }
    emitByte(@intCast((offset >> 8) & 255));
    emitByte(@intCast(offset & 255));
}

pub fn emitJump(instruction: u8) c_int {
    emitByte(instruction);
    emitByte(255);
    emitByte(255);
    return currentChunk().*.count - 2;
}
pub fn emitReturn() void {
    if (current.*.type_ == .TYPE_INITIALIZER) {
        emitBytes(@intCast(@intFromEnum(OpCode.OP_GET_LOCAL)), 0);
    } else {
        emitByte(@intCast(@intFromEnum(OpCode.OP_NIL)));
    }
    emitByte(@intCast(@intFromEnum(OpCode.OP_RETURN)));
}
pub fn makeConstant(value: Value) u8 {
    const constant: c_int = chunk_h.addConstant(currentChunk(), value);
    if (constant > 255) {
        @"error"("Too many constants in one chunk.");
        return 0;
    }
    return @intCast(constant);
}
pub fn emitConstant(value: Value) void {
    emitBytes(@intFromEnum(OpCode.OP_CONSTANT), makeConstant(value));
}

pub fn patchJump(offset: c_int) void {
    const jump: c_int = (currentChunk().*.count - offset) - 2;
    if (jump > 65535) {
        @"error"("Too much code to jump over.");
    }

    currentChunk().*.code[@intCast(offset)] = @intCast((jump >> 8) & 255);
    currentChunk().*.code[@intCast(offset + 1)] = @intCast(jump & 255);
}
pub fn initCompiler(compiler: [*c]Compiler, type_: FunctionType) void {
    compiler.*.enclosing = current;
    compiler.*.function = null;
    compiler.*.type_ = type_;
    compiler.*.localCount = 0;
    compiler.*.scopeDepth = 0;
    compiler.*.function = object_h.newFunction();
    current = compiler;
    if (type_ != .TYPE_SCRIPT) {
        current.*.function.*.name = object_h.copyString(parser.previous.start, parser.previous.length);
    }
    current.*.localCount += 1;
    const local: [*c]Local = &current.*.locals[@intCast(current.*.localCount)];
    local.*.depth = 0;
    local.*.isCaptured = false;
    if (type_ != .TYPE_FUNCTION) {
        local.*.name.start = @ptrCast(@constCast("self"));
        local.*.name.length = 4;
    } else {
        local.*.name.start = @ptrCast(@constCast(""));
        local.*.name.length = 0;
    }
}
pub fn endCompiler() [*c]ObjFunction {
    emitReturn();
    const function_1: [*c]ObjFunction = current.*.function;

    if (debug_opts.print_code) {
        if (!parser.hadError) {
            const name: [*c]u8 = if (function_1.*.name != null) function_1.*.name.*.chars else @ptrCast(@constCast("<script>"));
            debug_h.disassembleChunk(currentChunk(), name);
        }
    }

    current = current.*.enclosing;
    return function_1;
}
pub fn beginScope() void {
    current.*.scopeDepth += 1;
}
pub fn endScope() void {
    current.*.scopeDepth -= 1;
    while ((current.*.localCount > 0) and (current.*.locals[@intCast(current.*.localCount - 1)].depth > current.*.scopeDepth)) {
        if (current.*.locals[@as(c_uint, @intCast(current.*.localCount - 1))].isCaptured) {
            emitByte(@intFromEnum(OpCode.OP_CLOSE_UPVALUE));
        } else {
            emitByte(@intFromEnum(OpCode.OP_POP));
        }
        current.*.localCount -= 1;
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
        .TOKEN_EACH => {
            advance();
            eachStatement();
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
pub fn getRule(type_: TokenType) [*c]ParseRule {
    const index: usize = @intCast(@intFromEnum(type_));
    return &rules[index];
}
pub fn parsePrecedence(precedence: Precedence) void {
    advance();
    const prefixRule: ParseFn = getRule(parser.previous.type).*.prefix;

    if (prefixRule == null) {
        @"error"("Expect expression.");
        return;
    }
    const canAssign: bool = precedence <= PREC_ASSIGNMENT;
    prefixRule.?(canAssign);
    while (precedence <= getRule(parser.current.type).*.precedence) {
        advance();
        const infixRule: ParseFn = getRule(parser.previous.type).*.infix;
        infixRule.?(canAssign);
    }
    if (canAssign and match(.TOKEN_EQUAL)) {
        @"error"("Invalid assignment target.");
    }
}

pub fn identifierConstant(name: [*c]Token) u8 {
    return makeConstant(Value{
        .type = .VAL_OBJ,
        .as = .{
            .obj = @as([*c]object_h.Obj, @ptrCast(@alignCast(object_h.copyString(name.*.start, name.*.length)))),
        },
    });
}
pub fn identifiersEqual(a: [*c]Token, b: [*c]Token) bool {
    if (a.*.length != b.*.length) return false;
    return scanner_h.memcmp(@as(?*const anyopaque, @ptrCast(a.*.start)), @as(?*const anyopaque, @ptrCast(b.*.start)), @as(c_ulong, @bitCast(@as(c_long, a.*.length)))) == 0;
}
pub fn resolveLocal(compiler: [*c]Compiler, name: [*c]Token) c_int {
    var i: c_int = compiler.*.localCount - 1;
    while (i >= 0) : (i -= 1) {
        const local: [*c]Local = &compiler.*.locals[@as(c_uint, @intCast(i))];
        if (identifiersEqual(name, &local.*.name)) {
            if (local.*.depth == -1) {
                @"error"("Can't read local variable in its own initializer.");
            }
            return i;
        }
    }

    return -1;
}

pub fn addUpvalue(compiler: [*c]Compiler, index_1: u8, isLocal: bool) c_int {
    const upvalueCount: c_int = compiler.*.function.*.upvalueCount;

    for (0..@intCast(upvalueCount)) |i| {
        const upvalue: [*c]Upvalue = &compiler.*.upvalues[@as(c_uint, @intCast(i))];

        if ((upvalue.*.index == index_1) and upvalue.*.isLocal) {
            return @intCast(i);
        }
    }

    if (upvalueCount == (255 + 1)) {
        @"error"("Too many closures variables in function.");
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
pub fn resolveUpvalue(compiler: [*c]Compiler, name: [*c]Token) c_int {
    if (compiler.*.enclosing == @as([*c]Compiler, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(0)))))) return -1;
    const local: c_int = resolveLocal(compiler.*.enclosing, name);
    if (local != -1) {
        compiler.*.enclosing.*.locals[@as(c_uint, @intCast(local))].isCaptured = true;
        return addUpvalue(compiler, @as(u8, @bitCast(@as(i8, @truncate(local)))), true);
    }
    const upvalue: c_int = resolveUpvalue(compiler.*.enclosing, name);
    if (upvalue != -1) {
        return addUpvalue(compiler, @as(u8, @bitCast(@as(i8, @truncate(upvalue)))), false);
    }
    return -1;
}
pub fn addLocal(name: Token) void {
    if (current.*.localCount == (255 + 1)) {
        @"error"("Too many local variables in function.");
        return;
    }
    const local: [*c]Local = &current.*.locals[
        @as(c_uint, @intCast(blk: {
            const ref = &current.*.localCount;
            const tmp = ref.*;
            ref.* += 1;
            break :blk tmp;
        }))
    ];
    local.*.name = name;
    local.*.depth = -1;
    local.*.isCaptured = false;
}
pub fn declareVariable() void {
    if (current.*.scopeDepth == 0) return;
    const name: [*c]Token = &parser.previous;
    {
        var i: c_int = current.*.localCount - 1;
        _ = &i;
        while (i >= 0) : (i -= 1) {
            var local: [*c]Local = &current.*.locals[@as(c_uint, @intCast(i))];
            _ = &local;
            if ((local.*.depth != -1) and (local.*.depth < current.*.scopeDepth)) {
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
pub fn parseVariable(errorMessage: [*c]const u8) u8 {
    consume(.TOKEN_IDENTIFIER, errorMessage);
    declareVariable();
    if (current.*.scopeDepth > 0) return 0;
    return identifierConstant(&parser.previous);
}
pub fn markInitialized() void {
    if (current.*.scopeDepth == 0) return;
    current.*.locals[@as(c_uint, @intCast(current.*.localCount - 1))].depth = current.*.scopeDepth;
}
pub fn defineVariable(global: u8) void {
    if (current.*.scopeDepth > 0) {
        markInitialized();
        return;
    }
    emitBytes(@intCast(@intFromEnum(OpCode.OP_DEFINE_GLOBAL)), global);
}
pub fn argumentList() u8 {
    var argCount: u8 = 0;
    if (!check(.TOKEN_RIGHT_PAREN)) {
        while (true) {
            expression();
            if (@as(c_int, @bitCast(@as(c_uint, argCount))) == 255) {
                @"error"("Can't have more than 255 arguments.");
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
    var endJump: c_int = emitJump(@intCast(@intFromEnum(OpCode.OP_JUMP_IF_FALSE)));
    _ = &endJump;
    emitByte(@intCast(@intFromEnum(OpCode.OP_POP)));
    parsePrecedence(PREC_AND);
    patchJump(endJump);
}
pub fn binary(canAssign: bool) void {
    _ = canAssign;
    const operatorType: TokenType = parser.previous.type;
    const rule: [*c]ParseRule = getRule(operatorType);
    parsePrecedence(rule.*.precedence +% 1);
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
    if ((@as(c_int, @intFromBool(canAssign)) != 0) and (@as(c_int, @intFromBool(match(.TOKEN_EQUAL))) != 0)) {
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
    while (true) {
        switch (parser.previous.type) {
            .TOKEN_FALSE => {
                emitByte(@intCast(@intFromEnum(OpCode.OP_FALSE)));
                break;
            },
            .TOKEN_NIL => {
                emitByte(@intCast(@intFromEnum(OpCode.OP_NIL)));
                break;
            },
            .TOKEN_TRUE => {
                emitByte(@intCast(@intFromEnum(OpCode.OP_TRUE)));
                break;
            },
            else => return,
        }
        break;
    }
}
pub fn grouping(canAssign: bool) void {
    _ = &canAssign;
    expression();
    consume(.TOKEN_RIGHT_PAREN, "Expect ')' after expression.");
}
pub fn number(canAssign: bool) void {
    _ = &canAssign;
    if (parser.previous.type == .TOKEN_INT) {
        var value: c_int = atoi(parser.previous.start);
        _ = &value;
        emitConstant(Value{
            .type = .VAL_INT,
            .as = .{
                .num_int = value,
            },
        });
    } else {
        var value: f64 = strtod(parser.previous.start, null);
        _ = &value;
        emitConstant(Value{
            .type = .VAL_DOUBLE,
            .as = .{
                .num_double = value,
            },
        });
    }
}
pub fn or_(canAssign: bool) void {
    _ = &canAssign;
    var elseJump: c_int = emitJump(@intCast(@intFromEnum(OpCode.OP_JUMP_IF_FALSE)));
    _ = &elseJump;
    var endJump: c_int = emitJump(@intCast(@intFromEnum(OpCode.OP_JUMP)));
    _ = &endJump;
    patchJump(elseJump);
    emitByte(@intCast(@intFromEnum(OpCode.OP_POP)));
    parsePrecedence(PREC_OR);
    patchJump(endJump);
}
pub fn string(canAssign: bool) void {
    _ = &canAssign;
    emitConstant(Value{
        .type = .VAL_OBJ,
        .as = .{
            .obj = @as([*c]object_h.Obj, @ptrCast(@alignCast(object_h.copyString(parser.previous.start + @as(usize, @bitCast(@as(isize, @intCast(1)))), parser.previous.length - 2)))),
        },
    });
}
// pub fn array(canAssign: bool)  void {
//     _ = &canAssign;
//     var argCount: u8 = 0;
//     _ = &argCount;
//     if (!check(.TOKEN_RIGHT_SQPAREN)) {
//         while (true) {
//             expression();
//             argCount +%= 1;
//             if (@as(c_int, @bitCast(@as(c_uint, argCount))) > 255) {
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
            if (@as(c_int, @bitCast(@as(c_uint, argCount))) > 255) {
                @"error"("Can't have more than 255 elements in a vector.");
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
    var arg: c_int = resolveLocal(current, @constCast(&name));
    if (arg != -1) {
        getOp = @intCast(@intFromEnum(OpCode.OP_GET_LOCAL));
        setOp = @intCast(@intFromEnum(OpCode.OP_SET_LOCAL));
    } else if ((blk: {
        const tmp = resolveUpvalue(current, @constCast(&name));
        arg = tmp;
        break :blk tmp;
    }) != -1) {
        getOp = @intCast(@intFromEnum(OpCode.OP_GET_UPVALUE));
        setOp = @intCast(@intFromEnum(OpCode.OP_SET_UPVALUE));
    } else {
        arg = @intCast(identifierConstant(@constCast(&name)));
        getOp = @intCast(@intFromEnum(OpCode.OP_GET_GLOBAL));
        setOp = @intCast(@intFromEnum(OpCode.OP_SET_GLOBAL));
    }
    if ((@as(c_int, @intFromBool(canAssign)) != 0) and (@as(c_int, @intFromBool(match(.TOKEN_EQUAL))) != 0)) {
        expression();
        emitBytes(setOp, @as(u8, @bitCast(@as(i8, @truncate(arg)))));
    } else if ((((@as(c_int, @intFromBool(match(.TOKEN_PLUS_EQUAL))) != 0) or (@as(c_int, @intFromBool(match(.TOKEN_MINUS_EQUAL))) != 0)) or (@as(c_int, @intFromBool(match(.TOKEN_STAR_EQUAL))) != 0)) or (@as(c_int, @intFromBool(match(.TOKEN_SLASH_EQUAL))) != 0)) {
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
pub fn index_(canAssign: bool) void {
    if (check(.TOKEN_LEFT_SQPAREN)) {
        consume(.TOKEN_LEFT_SQPAREN, "Expect '[' after array.");
        expression();
        consume(.TOKEN_RIGHT_SQPAREN, "Expect ']' after index.");
        if ((@as(c_int, @intFromBool(canAssign)) != 0) and (@as(c_int, @intFromBool(match(.TOKEN_EQUAL))) != 0)) {
            expression();
            emitByte(@intCast(@intFromEnum(OpCode.OP_INDEX_SET)));
        } else {
            emitByte(@intCast(@intFromEnum(OpCode.OP_INDEX_GET)));
        }
    } else {
        vm_h.runtimeError("Only arrays support indexing.", .{});
    }
}
pub fn variable(canAssign: bool) void {
    namedVariable(parser.previous, canAssign);
}

pub fn syntheticToken(text: [*c]const u8) Token {
    var token: Token = Token{
        .type = @import("std").mem.zeroes(TokenType),
        .start = @constCast(text),
        .length = @as(c_int, @bitCast(@as(c_uint, @truncate(scanner_h.strlen(text))))),
        .line = 0,
    };
    _ = &token;
    return token;
}
pub fn super_(canAssign: bool) void {
    _ = canAssign;
    if (currentClass == @as([*c]ClassCompiler, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(0)))))) {
        @"error"("Can't use 'super' outside of a class.");
    } else if (!currentClass.*.hasSuperClass) {
        @"error"("Can't use 'super' in a class with no superclass.");
    }
    consume(.TOKEN_DOT, "Expect '.' after 'super'.");
    consume(.TOKEN_IDENTIFIER, "Expect superclass method name.");
    var name: u8 = identifierConstant(&parser.previous);
    _ = &name;
    namedVariable(syntheticToken("self"), false);
    if (match(.TOKEN_LEFT_PAREN)) {
        var argCount: u8 = argumentList();
        _ = &argCount;
        namedVariable(syntheticToken("super"), false);
        emitBytes(@intCast(@intFromEnum(OpCode.OP_SUPER_INVOKE)), name);
        emitByte(argCount);
    } else {
        namedVariable(syntheticToken("super"), false);
        emitBytes(@intCast(@intFromEnum(OpCode.OP_GET_SUPER)), name);
    }
}
pub fn self_(canAssign: bool) void {
    _ = &canAssign;
    if (currentClass == @as([*c]ClassCompiler, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(0)))))) {
        @"error"("Can't use 'self' outside of a class.");
        return;
    }
    variable(false);
}
pub fn item_(canAssign: bool) void {
    _ = &canAssign;
    variable(false);
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
            else => return,
        }
        break;
    }
}
pub export var rules: [53]ParseRule = .{
    .{
        .prefix = &grouping,
        .infix = &call,
        .precedence = PREC_CALL,
    },
    .{
        .precedence = PREC_NONE,
    },
    .{
        .prefix = &fvector,
        .precedence = PREC_NONE,
    },
    .{
        .precedence = PREC_NONE,
    },
    .{
        .precedence = PREC_NONE,
    },
    .{
        .infix = &dot,
        .precedence = PREC_CALL,
    },
    .{
        .prefix = &unary,
        .infix = &binary,
        .precedence = PREC_TERM,
    },
    .{
        .infix = &binary,
        .precedence = PREC_TERM,
    },
    .{
        .precedence = PREC_NONE,
    },
    .{
        .infix = &binary,
        .precedence = PREC_FACTOR,
    },
    .{
        .infix = &binary,
        .precedence = PREC_FACTOR,
    },
    .{
        .infix = &binary,
        .precedence = PREC_FACTOR,
    },
    .{
        .prefix = &unary,
        .precedence = PREC_NONE,
    },
    .{
        .infix = &binary,
        .precedence = PREC_EQUALITY,
    },
    .{
        .precedence = PREC_NONE,
    },
    .{
        .infix = &binary,
        .precedence = PREC_EQUALITY,
    },
    .{
        .infix = &binary,
        .precedence = PREC_COMPARISON,
    },
    .{
        .infix = &binary,
        .precedence = PREC_COMPARISON,
    },
    .{
        .infix = &binary,
        .precedence = PREC_COMPARISON,
    },
    .{
        .infix = &binary,
        .precedence = PREC_COMPARISON,
    },
    .{
        .prefix = &variable,
        .infix = &index_,
        .precedence = PREC_NONE,
    },
    .{
        .prefix = &string,
        .precedence = PREC_NONE,
    },
    .{
        .prefix = &number,
        .precedence = PREC_NONE,
    },
    .{
        .prefix = &number,
        .precedence = PREC_NONE,
    },
    .{
        .infix = &and_,
        .precedence = PREC_AND,
    },
    .{
        .precedence = PREC_NONE,
    },
    .{
        .precedence = PREC_NONE,
    },
    .{
        .prefix = &literal,
        .precedence = PREC_NONE,
    },
    .{
        .precedence = PREC_NONE,
    },
    .{
        .precedence = PREC_NONE,
    },
    .{
        .precedence = PREC_NONE,
    },
    .{
        .precedence = PREC_NONE,
    },
    .{
        .precedence = PREC_NONE,
    },
    .{
        .prefix = &literal,
        .precedence = PREC_NONE,
    },
    .{
        .infix = &or_,
        .precedence = PREC_OR,
    },
    .{
        .precedence = PREC_NONE,
    },
    .{
        .precedence = PREC_NONE,
    },
    .{
        .prefix = &self_,
        .precedence = PREC_NONE,
    },
    .{
        .prefix = &super_,
        .precedence = PREC_NONE,
    },
    .{
        .prefix = &literal,
        .precedence = PREC_NONE,
    },
    .{
        .precedence = PREC_NONE,
    },
    .{
        .precedence = PREC_NONE,
    },
    .{
        .prefix = &item_,
        .precedence = PREC_NONE,
    },
    .{
        .precedence = PREC_NONE,
    },
    .{
        .precedence = PREC_NONE,
    },
    .{
        .precedence = PREC_NONE,
    },
    .{
        .precedence = PREC_NONE,
    },
    .{
        .precedence = PREC_NONE,
    },
    .{
        .precedence = PREC_NONE,
    },
    .{
        .precedence = PREC_NONE,
    },
    .{
        .precedence = PREC_NONE,
    },
    .{
        .infix = &binary,
        .precedence = PREC_FACTOR,
    },
    .{
        .precedence = PREC_NONE,
    },
};
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
            current.*.function.*.arity += 1;
            if (current.*.function.*.arity > 255) {
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
    emitBytes(@intCast(@intFromEnum(OpCode.OP_CLOSURE)), makeConstant(Value{
        .type = .VAL_OBJ,
        .as = .{
            .obj = @as([*c]object_h.Obj, @ptrCast(@alignCast(function_1))),
        },
    }));
    {
        var i: c_int = 0;
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
    if ((parser.previous.length == @as(c_int, 4)) and (scanner_h.memcmp(@as(?*const anyopaque, @ptrCast(parser.previous.start)), @as(?*const anyopaque, @ptrCast("init")), @as(c_ulong, @bitCast(@as(c_long, @as(c_int, 4))))) == 0)) {
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
    classCompiler.hasSuperClass = false;
    currentClass = &classCompiler;
    if (match(.TOKEN_LESS)) {
        consume(.TOKEN_IDENTIFIER, "Expect superclass name.");
        variable(false);
        if (identifiersEqual(&className, &parser.previous)) {
            @"error"("A class can't inherit itself.");
        }
        beginScope();
        addLocal(syntheticToken("super"));
        defineVariable(@as(u8, @bitCast(@as(i8, @truncate(0)))));
        namedVariable(className, false);
        emitByte(@intCast(@intFromEnum(OpCode.OP_INHERIT)));
        currentClass.*.hasSuperClass = true;
    }
    namedVariable(className, false);
    consume(.TOKEN_LEFT_BRACE, "Expect '{' before class body.");
    while (!check(.TOKEN_RIGHT_BRACE) and !check(.TOKEN_EOF)) {
        method();
    }
    consume(.TOKEN_RIGHT_BRACE, "Expect '}' after class body.");
    emitByte(@intCast(@intFromEnum(OpCode.OP_POP)));
    if (classCompiler.hasSuperClass) {
        endScope();
    }
    currentClass = currentClass.*.enclosing;
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
    var loopStart: c_int = currentChunk().*.count;
    _ = &loopStart;
    var exitJump: c_int = -1;
    _ = &exitJump;
    if (!match(.TOKEN_SEMICOLON)) {
        expression();
        consume(.TOKEN_SEMICOLON, "Expect ';' after loop condition.");
        exitJump = emitJump(@intCast(@intFromEnum(OpCode.OP_JUMP_IF_FALSE)));
        emitByte(@intCast(@intFromEnum(OpCode.OP_POP)));
    }
    if (!match(.TOKEN_RIGHT_PAREN)) {
        var bodyJump: c_int = emitJump(@intCast(@intFromEnum(OpCode.OP_JUMP)));
        _ = &bodyJump;
        var incrementStart: c_int = currentChunk().*.count;
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
pub fn eachStatement() void {
    var loopStart: c_int = currentChunk().*.count;
    _ = &loopStart;
    consume(.TOKEN_LEFT_PAREN, "Expect '(' after 'while'.");
    expression();
    consume(.TOKEN_RIGHT_PAREN, "Expect ')' after condition.");
    var exitJump: c_int = emitJump(@intCast(@intFromEnum(OpCode.OP_JUMP_IF_DONE)));
    _ = &exitJump;
    var item: Token = Token{
        .type = .TOKEN_ITEM,
        .start = @ptrCast(@constCast("item")),
        .length = @as(c_int, 4),
        .line = 0,
    };
    _ = &item;
    emitBytes(@intCast(@intFromEnum(OpCode.OP_SET_GLOBAL)), identifierConstant(&item));
    statement();
    emitLoop(loopStart);
    patchJump(exitJump);
    emitByte(@intCast(@intFromEnum(OpCode.OP_POP)));
}
pub fn ifStatement() void {
    consume(.TOKEN_LEFT_PAREN, "Expect '(' after 'if'.");
    expression();
    consume(.TOKEN_RIGHT_PAREN, "Expect ')' after condition.");
    var thenJump: c_int = emitJump(@intCast(@intFromEnum(OpCode.OP_JUMP_IF_FALSE)));
    _ = &thenJump;
    emitByte(@intCast(@intFromEnum(OpCode.OP_POP)));
    statement();
    var elseJump: c_int = emitJump(@intCast(@intFromEnum(OpCode.OP_JUMP)));
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
    if (current.*.type_ == .TYPE_SCRIPT) {
        @"error"("Can't return from top-level code.");
    }
    if (match(.TOKEN_SEMICOLON)) {
        emitReturn();
    } else {
        if (current.*.type_ == .TYPE_INITIALIZER) {
            @"error"("Can't return a value from an initializer.");
        }
        expression();
        consume(.TOKEN_SEMICOLON, "Expect ';' after return value.");
        emitByte(@intCast(@intFromEnum(OpCode.OP_RETURN)));
    }
}
pub fn whileStatement() void {
    var loopStart: c_int = currentChunk().*.count;
    _ = &loopStart;
    consume(.TOKEN_LEFT_PAREN, "Expect '(' after 'while'.");
    expression();
    consume(.TOKEN_RIGHT_PAREN, "Expect ')' after condition.");
    var exitJump: c_int = emitJump(@intCast(@intFromEnum(OpCode.OP_JUMP_IF_FALSE)));
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

pub export fn compile(source: [*c]const u8) [*c]ObjFunction {
    scanner_h.initScanner(@constCast(source));
    var compiler: Compiler = undefined;
    _ = &compiler;
    initCompiler(&compiler, .TYPE_SCRIPT);
    parser.hadError = false;
    parser.panicMode = false;
    advance();
    while (!match(.TOKEN_EOF)) {
        declaration();
    }
    var function_1: [*c]ObjFunction = endCompiler();
    _ = &function_1;
    return if (@as(c_int, @intFromBool(parser.hadError)) != 0) null else function_1;
}
