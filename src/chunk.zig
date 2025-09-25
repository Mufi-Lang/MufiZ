const memory_h = @import("memory.zig");
const value_h = @import("value.zig");
const vm_h = @import("vm.zig");

pub const OpCode = enum(i32) {
    OP_CONSTANT = 0,
    OP_NIL = 1,
    OP_TRUE = 2,
    OP_FALSE = 3,
    OP_POP = 4,
    OP_GET_LOCAL = 5,
    OP_SET_LOCAL = 6,
    OP_GET_GLOBAL = 7,
    OP_DEFINE_GLOBAL = 8,
    OP_DEFINE_CONST_GLOBAL = 9,
    OP_SET_GLOBAL = 10,
    OP_GET_UPVALUE = 11,
    OP_SET_UPVALUE = 12,
    OP_GET_PROPERTY = 13,
    OP_SET_PROPERTY = 14,
    OP_GET_SUPER = 15,
    OP_EQUAL = 16,
    OP_GREATER = 17,
    OP_LESS = 18,
    OP_GREATER_EQUAL = 19,
    OP_ADD = 20,
    OP_SUBTRACT = 21,
    OP_MULTIPLY = 22,
    OP_DIVIDE = 23,
    OP_MODULO = 24,
    OP_EXPONENT = 25,
    OP_NOT = 26,
    OP_NEGATE = 27,
    OP_PRINT = 28,
    OP_JUMP = 29,
    OP_JUMP_IF_FALSE = 30,
    OP_LOOP = 31,
    OP_CALL = 32,
    OP_INVOKE = 33,
    OP_SUPER_INVOKE = 34,
    OP_CLOSURE = 35,
    OP_CLOSE_UPVALUE = 36,
    OP_RETURN = 37,
    OP_CLASS = 38,
    OP_INHERIT = 39,
    OP_METHOD = 40,
    OP_LENGTH = 41,
    OP_GET_INDEX = 42,
    OP_SLICE = 43,
    OP_RANGE = 44,
    OP_RANGE_INCLUSIVE = 45,
    OP_PAIR = 46,
    OP_CHECK_RANGE = 47,
    OP_IS_RANGE = 48,
    OP_GET_RANGE_LENGTH = 49,
    OP_SET_INDEX = 50,
    OP_DUP = 51,
    OP_INT = 52,
    OP_HASH_TABLE = 53,
    OP_ADD_ENTRY = 54,
    OP_TO_STRING = 55,
    OP_BREAK = 56,
    OP_CONTINUE = 57,
    OP_FVECTOR = 58,
};

pub const Chunk = struct {
    count: i32,
    capacity: i32,
    code: ?[*]u8,
    lines: ?[*]i32,
    constants: value_h.ValueArray,
};

pub fn initChunk(chunk: *Chunk) void {
    chunk.*.count = 0;
    chunk.*.capacity = 0;
    chunk.*.code = null;
    chunk.*.lines = null;
    value_h.initValueArray(&chunk.*.constants);
}

pub fn freeChunk(chunk: *Chunk) void {
    if (chunk.*.code) |code| {
        _ = memory_h.reallocate(@ptrCast(code), @intCast(@sizeOf(u8) *% chunk.*.capacity), 0);
    }
    if (chunk.*.lines) |lines| {
        _ = memory_h.reallocate(@ptrCast(lines), @intCast(@sizeOf(i32) *% chunk.*.capacity), 0);
    }
    value_h.freeValueArray(&chunk.*.constants);
    initChunk(chunk);
}

pub fn writeChunk(chunk: *Chunk, byte: u8, line: i32) void {
    if (chunk.*.capacity < (chunk.*.count + 1)) {
        const oldCapacity: i32 = chunk.*.capacity;
        chunk.*.capacity = if (oldCapacity < 8) 8 else oldCapacity * 2;
        chunk.*.code = @ptrCast(@alignCast(memory_h.reallocate(@ptrCast(chunk.*.code), @intCast(@sizeOf(u8) *% oldCapacity), @intCast(@sizeOf(u8) *% chunk.*.capacity))));
        chunk.*.lines = @ptrCast(@alignCast(memory_h.reallocate(@ptrCast(chunk.*.lines), @intCast(@sizeOf(i32) *% oldCapacity), @intCast(@sizeOf(i32) *% chunk.*.capacity))));
    }
    if (chunk.*.code) |code| {
        code[@intCast(chunk.*.count)] = byte;
    }
    if (chunk.*.lines) |lines| {
        lines[@intCast(chunk.*.count)] = line;
    }
    chunk.*.count += 1;
}

pub fn addConstant(chunk: *Chunk, value: value_h.Value) i32 {
    vm_h.push(value);
    value_h.writeValueArray(&chunk.*.constants, value);
    _ = vm_h.pop();
    return chunk.*.constants.count - 1;
}
