const value_h = @import("value.zig");
const memory_h = @import("memory.zig");
const vm_h = @import("vm.zig");

pub const OpCode = enum(c_int) {
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
    OP_INDEX_GET = 15,
    OP_INDEX_SET = 16,
    OP_EQUAL = 17,
    OP_GREATER = 18,
    OP_LESS = 19,
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
    OP_JUMP_IF_DONE = 31,
    OP_LOOP = 32,
    OP_CALL = 33,
    OP_INVOKE = 34,
    OP_SUPER_INVOKE = 35,
    OP_CLOSURE = 36,
    OP_CLOSE_UPVALUE = 37,
    OP_RETURN = 38,
    OP_CLASS = 39,
    OP_INHERIT = 40,
    OP_METHOD = 41,
    OP_ARRAY = 42,
    OP_FVECTOR = 43,
    OP_GET_ITERATOR = 44,
    OP_ITERATOR_NEXT = 45,
    OP_ITERATOR_HAS_NEXT = 46,
};

pub const Chunk = extern struct {
    count: i32,
    capacity: i32,
    code: [*c]u8,
    lines: [*c]i32,
    constants: value_h.ValueArray,
};

pub fn initChunk(chunk: [*c]Chunk) void {
    chunk.*.count = 0;
    chunk.*.capacity = 0;
    chunk.*.code = null;
    chunk.*.lines = null;
    value_h.initValueArray(&chunk.*.constants);
}

pub fn freeChunk(chunk: [*c]Chunk) void {
    _ = memory_h.reallocate(@ptrCast(chunk.*.code), @intCast(@sizeOf(u8) *% chunk.*.capacity), 0);
    _ = memory_h.reallocate(@ptrCast(chunk.*.lines), @intCast(@sizeOf(c_int) *% chunk.*.capacity), 0);
    value_h.freeValueArray(&chunk.*.constants);
    initChunk(chunk);
}

pub fn writeChunk(chunk: [*c]Chunk, byte: u8, line: c_int) void {
    if (chunk.*.capacity < (chunk.*.count + 1)) {
        const oldCapacity: c_int = chunk.*.capacity;
        chunk.*.capacity = if (oldCapacity < 8) 8 else oldCapacity * 2;
        chunk.*.code = @ptrCast(@alignCast(memory_h.reallocate(@ptrCast(chunk.*.code), @intCast(@sizeOf(u8) *% oldCapacity), @intCast(@sizeOf(u8) *% chunk.*.capacity))));
        chunk.*.lines = @ptrCast(@alignCast(memory_h.reallocate(@ptrCast(chunk.*.lines), @intCast(@sizeOf(c_int) *% oldCapacity), @intCast(@sizeOf(c_int) *% chunk.*.capacity))));
    }
    chunk.*.code[@intCast(chunk.*.count)] = byte;
    chunk.*.lines[@intCast(chunk.*.count)] = line;
    chunk.*.count += 1;
}

pub fn addConstant(arg_chunk: [*c]Chunk, arg_value: value_h.Value) c_int {
    var chunk = arg_chunk;
    _ = &chunk;
    var value = arg_value;
    _ = &value;
    vm_h.push(value);
    value_h.writeValueArray(&chunk.*.constants, value);
    _ = vm_h.pop();
    return chunk.*.constants.count - 1;
}
