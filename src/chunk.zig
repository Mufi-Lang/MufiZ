const mem_utils = @import("mem_utils.zig");
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
    OP_TAIL_CALL = 33,
    OP_INVOKE = 34,
    OP_SUPER_INVOKE = 35,
    OP_CLOSURE = 36,
    OP_CLOSE_UPVALUE = 37,
    OP_RETURN = 38,
    OP_CLASS = 39,
    OP_INHERIT = 40,
    OP_METHOD = 41,
    OP_LENGTH = 42,
    OP_GET_INDEX = 43,
    OP_SLICE = 44,
    OP_RANGE = 45,
    OP_RANGE_INCLUSIVE = 46,
    OP_PAIR = 47,
    OP_CHECK_RANGE = 48,
    OP_IS_RANGE = 49,
    OP_GET_RANGE_LENGTH = 50,
    OP_SET_INDEX = 51,
    OP_DUP = 52,
    OP_INT = 53,
    OP_HASH_TABLE = 54,
    OP_ADD_ENTRY = 55,
    OP_TO_STRING = 56,
    OP_BREAK = 57,
    OP_CONTINUE = 58,
    OP_FVECTOR = 59,
    OP_MATRIX = 60,
    OP_GET_MATRIX_FLAT = 61,
    // Import opcodes
    OP_IMPORT_MODULE = 62,
    OP_IMPORT_FILE = 63,
    OP_IMPORT_SPECIFIC = 64,
    OP_IMPORT_MODULE_AS = 65,
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
    const allocator = mem_utils.getAllocator();
    if (chunk.*.code) |code| {
        const code_slice = code[0..@intCast(chunk.*.capacity)];
        mem_utils.free(allocator, code_slice);
    }
    if (chunk.*.lines) |lines| {
        const lines_slice = lines[0..@intCast(chunk.*.capacity)];
        mem_utils.free(allocator, lines_slice);
    }
    value_h.freeValueArray(&chunk.*.constants);
    initChunk(chunk);
}

pub fn writeChunk(chunk: *Chunk, byte: u8, line: i32) void {
    if (chunk.*.capacity < (chunk.*.count + 1)) {
        const oldCapacity: i32 = chunk.*.capacity;
        chunk.*.capacity = if (oldCapacity < 8) 8 else oldCapacity * 2;
        const allocator = mem_utils.getAllocator();

        // Reallocate code array
        if (chunk.*.code) |old_code| {
            const old_code_slice = old_code[0..@intCast(oldCapacity)];
            const new_code_slice = mem_utils.realloc(allocator, old_code_slice, @intCast(chunk.*.capacity)) catch {
                // Handle allocation failure - could implement fallback or error handling
                return;
            };
            chunk.*.code = new_code_slice.ptr;
        } else {
            const new_code_slice = mem_utils.alloc(allocator, u8, @intCast(chunk.*.capacity)) catch {
                return;
            };
            chunk.*.code = new_code_slice.ptr;
        }

        // Reallocate lines array
        if (chunk.*.lines) |old_lines| {
            const old_lines_slice = old_lines[0..@intCast(oldCapacity)];
            const new_lines_slice = mem_utils.realloc(allocator, old_lines_slice, @intCast(chunk.*.capacity)) catch {
                return;
            };
            chunk.*.lines = new_lines_slice.ptr;
        } else {
            const new_lines_slice = mem_utils.alloc(allocator, i32, @intCast(chunk.*.capacity)) catch {
                return;
            };
            chunk.*.lines = new_lines_slice.ptr;
        }
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
