const mem_utils = @import("mem_utils.zig");
const value_h = @import("value.zig");
const vm_h = @import("vm.zig");

/// Opcode range organization for bytecode optimization
/// This structure documents the allocation of the 256-opcode space
pub const OpcodeRanges = struct {
    // Original opcodes (Phase 0)
    pub const ORIGINAL_START: u8 = 0;
    pub const ORIGINAL_END: u8 = 66;

    // Small constant opcodes (Phase 2) - Single-byte constant loads for 0-15
    pub const SMALL_CONSTANT_START: u8 = 67;
    pub const SMALL_CONSTANT_END: u8 = 82; // 16 opcodes (OP_CONSTANT_0..15)

    // Small local opcodes (Phase 2) - Single-byte local access for slots 0-3
    pub const SMALL_LOCAL_START: u8 = 83;
    pub const SMALL_LOCAL_END: u8 = 90; // 8 opcodes (GET/SET_LOCAL_0..3)

    // Short jump opcodes (Phase 2) - One-byte offset jumps
    pub const SHORT_JUMP_START: u8 = 91;
    pub const SHORT_JUMP_END: u8 = 93; // 3 opcodes

    // Padding for future quick wins
    pub const RESERVED_QUICK_START: u8 = 94;
    pub const RESERVED_QUICK_END: u8 = 99; // 6 opcodes

    // Superinstructions (Phase 3) - Fused instruction patterns
    pub const SUPERINSTRUCTION_START: u8 = 100;
    pub const SUPERINSTRUCTION_END: u8 = 191; // 92 opcodes

    // Reserved for future expansion
    pub const RESERVED_START: u8 = 192;
    pub const RESERVED_END: u8 = 255; // 64 opcodes

    /// Check if an opcode is in the original range
    pub inline fn isOriginal(opcode: u8) bool {
        return opcode >= ORIGINAL_START and opcode <= ORIGINAL_END;
    }

    /// Check if an opcode is a small constant
    pub inline fn isSmallConstant(opcode: u8) bool {
        return opcode >= SMALL_CONSTANT_START and opcode <= SMALL_CONSTANT_END;
    }

    /// Check if an opcode is a small local
    pub inline fn isSmallLocal(opcode: u8) bool {
        return opcode >= SMALL_LOCAL_START and opcode <= SMALL_LOCAL_END;
    }

    /// Check if an opcode is a short jump
    pub inline fn isShortJump(opcode: u8) bool {
        return opcode >= SHORT_JUMP_START and opcode <= SHORT_JUMP_END;
    }

    /// Check if an opcode is a superinstruction
    pub inline fn isSuperinstruction(opcode: u8) bool {
        return opcode >= SUPERINSTRUCTION_START and opcode <= SUPERINSTRUCTION_END;
    }
};

/// Original opcodes (0-66)
/// These are the baseline instruction set before optimization
pub const OpCode = enum(u8) {
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
    OP_GET_MODULE_MEMBER = 66,

    // ============================================================
    // PHASE 2 OPCODES: Small Constants (67-82)
    // ============================================================
    // Single-byte constant loads for values 0-15
    // Saves 1 byte per constant load for frequently used small values
    OP_CONSTANT_0 = 67,
    OP_CONSTANT_1 = 68,
    OP_CONSTANT_2 = 69,
    OP_CONSTANT_3 = 70,
    OP_CONSTANT_4 = 71,
    OP_CONSTANT_5 = 72,
    OP_CONSTANT_6 = 73,
    OP_CONSTANT_7 = 74,
    OP_CONSTANT_8 = 75,
    OP_CONSTANT_9 = 76,
    OP_CONSTANT_10 = 77,
    OP_CONSTANT_11 = 78,
    OP_CONSTANT_12 = 79,
    OP_CONSTANT_13 = 80,
    OP_CONSTANT_14 = 81,
    OP_CONSTANT_15 = 82,

    // ============================================================
    // PHASE 2 OPCODES: Small Locals (83-90)
    // ============================================================
    // Single-byte local access for slots 0-3
    // Saves 1 byte per local access for frequently used local variables
    OP_GET_LOCAL_0 = 83,
    OP_GET_LOCAL_1 = 84,
    OP_GET_LOCAL_2 = 85,
    OP_GET_LOCAL_3 = 86,
    OP_SET_LOCAL_0 = 87,
    OP_SET_LOCAL_1 = 88,
    OP_SET_LOCAL_2 = 89,
    OP_SET_LOCAL_3 = 90,

    // ============================================================
    // PHASE 2 OPCODES: Short Jumps (91-93)
    // ============================================================
    // Single-byte offset jumps for nearby targets (±127 bytes)
    // Saves 1 byte per jump for short distances
    OP_JUMP_SHORT = 91,
    OP_JUMP_IF_FALSE_SHORT = 92,
    OP_LOOP_SHORT = 93,

    // ============================================================
    // RESERVED OPCODES (94-99)
    // ============================================================
    // Reserved for future quick wins
    // ============================================================

    // ============================================================
    // PHASE 3 OPCODES: Superinstructions (100-191)
    // ============================================================
    // Fused instruction patterns for bytecode size and performance
    // Each superinstruction combines two frequently occurring opcodes
    // into a single instruction, reducing dispatch overhead and code size

    // ------------------------------------------------------------
    // DEFINE/SET Patterns (100-109)
    // ------------------------------------------------------------
    // Fuses: OP_DEFINE_GLOBAL + constant load
    // Format: [opcode] [global_name_idx:u8] [value_const_idx:u8]
    // Saves: 1 byte per occurrence (4 bytes -> 3 bytes)
    OP_DEFINE_GLOBAL_CONST = 100,

    // Fuses: OP_SET_GLOBAL + constant load
    // Format: [opcode] [global_name_idx:u8] [value_const_idx:u8]
    OP_SET_GLOBAL_CONST = 101,

    // Reserved for more define/set patterns
    // OP_DEFINE_CONST_GLOBAL_CONST = 102,
    // OP_SET_LOCAL_CONST = 103,
    // ... (104-109 reserved)

    // ------------------------------------------------------------
    // GET + Arithmetic Patterns (110-119)
    // ------------------------------------------------------------
    // Fuses: OP_GET_GLOBAL + OP_ADD
    // Format: [opcode] [global_idx:u8]
    // Assumes second operand already on stack
    // Saves: 1 byte per occurrence (3 bytes -> 2 bytes)
    OP_GET_GLOBAL_ADD = 110,

    // Fuses: OP_GET_GLOBAL + OP_SUBTRACT
    OP_GET_GLOBAL_SUBTRACT = 111,

    // Fuses: OP_GET_GLOBAL + OP_MULTIPLY
    OP_GET_GLOBAL_MULTIPLY = 112,

    // Fuses: OP_GET_GLOBAL + OP_DIVIDE
    OP_GET_GLOBAL_DIVIDE = 113,

    // Fuses: OP_GET_LOCAL + OP_ADD
    OP_GET_LOCAL_ADD = 114,

    // Reserved for more get+arithmetic patterns
    // OP_GET_LOCAL_MULTIPLY = 115,
    // OP_GET_GLOBAL_MODULO = 116,
    // ... (117-119 reserved)

    // ------------------------------------------------------------
    // GET + GET Patterns (120-129)
    // ------------------------------------------------------------
    // Fuses: OP_GET_GLOBAL + OP_GET_GLOBAL
    // Format: [opcode] [global1_idx:u8] [global2_idx:u8]
    // Saves: 1 byte per occurrence (4 bytes -> 3 bytes)
    OP_GET_GLOBAL_GLOBAL = 120,

    // Fuses: OP_GET_LOCAL + OP_GET_LOCAL
    // Format: [opcode] [local1_idx:u8] [local2_idx:u8]
    OP_GET_LOCAL_LOCAL = 121,

    // Fuses: OP_GET_GLOBAL + OP_GET_LOCAL
    // Format: [opcode] [global_idx:u8] [local_idx:u8]
    OP_GET_GLOBAL_LOCAL = 122,

    // Fuses: OP_GET_LOCAL + OP_GET_GLOBAL
    // Format: [opcode] [local_idx:u8] [global_idx:u8]
    OP_GET_LOCAL_GLOBAL = 123,

    // Reserved for more get+get patterns
    // ... (124-129 reserved)

    // ------------------------------------------------------------
    // CONSTANT + Operation Patterns (130-139)
    // ------------------------------------------------------------
    // Fuses: OP_CONSTANT + OP_CONSTANT
    // Format: [opcode] [const1_idx:u8] [const2_idx:u8]
    // Saves: 1 byte per occurrence (4 bytes -> 3 bytes)
    OP_CONSTANT_CONSTANT = 130,

    // Fuses: OP_CONSTANT + OP_ADD
    // Format: [opcode] [const_idx:u8]
    // Assumes second operand already on stack
    OP_CONSTANT_ADD = 131,

    // Fuses: OP_CONSTANT + OP_MULTIPLY
    OP_CONSTANT_MULTIPLY = 132,

    // Reserved for more constant patterns
    // OP_CONSTANT_SUBTRACT = 133,
    // OP_CONSTANT_DIVIDE = 134,
    // ... (135-139 reserved)

    // ------------------------------------------------------------
    // Comparison + Jump Patterns (140-149)
    // ------------------------------------------------------------
    // Reserved for fused comparison + conditional jump
    // Example: OP_EQUAL_JUMP_IF_FALSE, OP_LESS_JUMP_IF_FALSE
    // These require special handling due to jump offset calculation
    // ... (140-149 reserved for future implementation)

    // ------------------------------------------------------------
    // Reserved Superinstructions (150-191)
    // ------------------------------------------------------------
    // 42 opcodes reserved for future superinstruction patterns
    // Candidates:
    // - Three-instruction fusion (GET_GLOBAL + GET_GLOBAL + ADD)
    // - Method call patterns (GET_PROPERTY + INVOKE)
    // - Array access patterns (GET_LOCAL + GET_INDEX)
    // - Profile-guided specialized instructions
    // ============================================================

    // ============================================================
    // RESERVED OPCODES (192-255)
    // ============================================================
    // 64 opcodes reserved for future expansion
    // Potential uses:
    // - JIT hints and metadata
    // - Extended instruction formats
    // - Specialized domain-specific operations
    // ============================================================
};

/// Chunk structure containing bytecode and metadata
pub const Chunk = struct {
    count: i32,
    capacity: i32,
    code: ?[*]u8,
    lines: ?[*]i32,
    constants: value_h.ValueArray,
};

/// Get the length of an instruction at a given offset
/// This is essential for traversing variable-length bytecode
pub fn getInstructionLength(chunk: *Chunk, offset: usize) usize {
    const analyzer = @import("bytecode_analyzer.zig");
    return analyzer.getInstructionLength(chunk, offset);
}

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
