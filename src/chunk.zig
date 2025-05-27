const value_h = @import("value.zig");
const memory_h = @import("memory.zig");
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
    OP_SET_GLOBAL = 9,
    OP_GET_UPVALUE = 10,
    OP_SET_UPVALUE = 11,
    OP_GET_PROPERTY = 12,
    OP_SET_PROPERTY = 13,
    OP_GET_SUPER = 14,
    OP_EQUAL = 15,
    OP_GREATER = 16,
    OP_LESS = 17,
    OP_ADD = 18,
    OP_SUBTRACT = 19,
    OP_MULTIPLY = 20,
    OP_DIVIDE = 21,
    OP_MODULO = 22,
    OP_EXPONENT = 23,
    OP_NOT = 24,
    OP_NEGATE = 25,
    OP_PRINT = 26,
    OP_JUMP = 27,
    OP_JUMP_IF_FALSE = 28,
    OP_LOOP = 29,
    OP_CALL = 30,
    OP_INVOKE = 31,
    OP_SUPER_INVOKE = 32,
    OP_CLOSURE = 33,
    OP_CLOSE_UPVALUE = 34,
    OP_RETURN = 35,
    OP_CLASS = 36,
    OP_INHERIT = 37,
    OP_METHOD = 38,
    OP_FVECTOR = 39,
    OP_GET_INDEX = 40,
    OP_SET_INDEX = 41,
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
