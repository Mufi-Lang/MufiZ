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

pub const Chunk = struct {
    count: i32,
    capacity: i32,
    code: [*c]u8,
    lines: [*c]i32,
    constants: value_h.ValueArray,
};

pub fn initChunk(arg_chunk: [*c]Chunk) void {
    var chunk = arg_chunk;
    _ = &chunk;
    chunk.*.count = 0;
    chunk.*.capacity = 0;
    chunk.*.code = null;
    chunk.*.lines = null;
    value_h.initValueArray(&chunk.*.constants);
}

pub fn freeChunk(arg_chunk: [*c]Chunk) void {
    var chunk = arg_chunk;
    _ = &chunk;
    _ = memory_h.reallocate(@as(?*anyopaque, @ptrCast(chunk.*.code)), @sizeOf(u8) *% @as(c_ulong, @bitCast(@as(c_long, chunk.*.capacity))), @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))));
    _ = memory_h.reallocate(@as(?*anyopaque, @ptrCast(chunk.*.lines)), @sizeOf(c_int) *% @as(c_ulong, @bitCast(@as(c_long, chunk.*.capacity))), @as(usize, @bitCast(@as(c_long, @as(c_int, 0)))));
    value_h.freeValueArray(&chunk.*.constants);
    initChunk(chunk);
}

pub fn writeChunk(arg_chunk: [*c]Chunk, arg_byte: u8, arg_line: c_int) void {
    var chunk = arg_chunk;
    _ = &chunk;
    var byte = arg_byte;
    _ = &byte;
    var line = arg_line;
    _ = &line;
    if (chunk.*.capacity < (chunk.*.count + @as(c_int, 1))) {
        var oldCapacity: c_int = chunk.*.capacity;
        _ = &oldCapacity;
        chunk.*.capacity = if (oldCapacity < @as(c_int, 8)) @as(c_int, 8) else oldCapacity * @as(c_int, 2);
        chunk.*.code = @as([*c]u8, @ptrCast(@alignCast(memory_h.reallocate(@as(?*anyopaque, @ptrCast(chunk.*.code)), @sizeOf(u8) *% @as(c_ulong, @bitCast(@as(c_long, oldCapacity))), @sizeOf(u8) *% @as(c_ulong, @bitCast(@as(c_long, chunk.*.capacity)))))));
        chunk.*.lines = @as([*c]c_int, @ptrCast(@alignCast(memory_h.reallocate(@as(?*anyopaque, @ptrCast(chunk.*.lines)), @sizeOf(c_int) *% @as(c_ulong, @bitCast(@as(c_long, oldCapacity))), @sizeOf(c_int) *% @as(c_ulong, @bitCast(@as(c_long, chunk.*.capacity)))))));
    }
    (blk: {
        const tmp = chunk.*.count;
        if (tmp >= 0) break :blk chunk.*.code + @as(usize, @intCast(tmp)) else break :blk chunk.*.code - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).* = byte;
    (blk: {
        const tmp = chunk.*.count;
        if (tmp >= 0) break :blk chunk.*.lines + @as(usize, @intCast(tmp)) else break :blk chunk.*.lines - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
    }).* = line;
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
    return chunk.*.constants.count - @as(c_int, 1);
}
