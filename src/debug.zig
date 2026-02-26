const std = @import("std");
const print = std.debug.print;

const chunk_h = @import("chunk.zig");
const object_h = @import("object.zig");
const ObjFunction = object_h.ObjFunction;
const printValue = @import("value.zig").printValue;
const value_h = @import("value.zig");

// Helper function to get line at a specific offset
fn getLine(c: *chunk_h.Chunk, pos: i32) i32 {
    const idx: usize = @intCast(if (pos >= 0) pos else unreachable);
    if (c.*.lines) |lines| {
        return lines[idx];
    }
    return 0;
}

// Helper function to get byte at a specific offset
fn getByte(chunk: *chunk_h.Chunk, pos: i32) u8 {
    const idx: usize = @intCast(if (pos >= 0) pos else unreachable);
    if (chunk.*.code) |code| {
        return code[idx];
    }
    return 0;
}

pub fn disassembleChunk(chunk: *chunk_h.Chunk, name: [*]const u8) void {
    // Create a slice from the pointer to handle string formatting properly
    const nameSlice = std.mem.span(@as([*:0]const u8, @ptrCast(name)));
    print("== {s} ==\n", .{nameSlice});

    var offset: i32 = 0;

    while (offset < chunk.*.count) {
        offset = disassembleInstruction(chunk, offset);
    }
}

pub fn disassembleInstruction(chunk: *chunk_h.Chunk, offset: i32) i32 {
    print("{d:0>4} ", .{offset});

    // Check if we're on the same line as the previous instruction
    if (offset > 0 and getLine(chunk, offset) == getLine(chunk, offset - 1)) {
        print("   | ", .{});
    } else {
        print("{d:4} ", .{getLine(chunk, offset)});
    }

    // Get the instruction
    const instruction: u8 = getByte(chunk, offset);

    // Dispatch based on opcode
    switch (instruction) {
        0 => return constantInstruction("OP_CONSTANT", chunk, offset),
        1 => return simpleInstruction("OP_NIL", offset),
        2 => return simpleInstruction("OP_TRUE", offset),
        3 => return simpleInstruction("OP_FALSE", offset),
        4 => return simpleInstruction("OP_POP", offset),
        5 => return byteInstruction("OP_GET_LOCAL", chunk, offset),
        6 => return byteInstruction("OP_SET_LOCAL", chunk, offset),
        7 => return constantInstruction("OP_GET_GLOBAL", chunk, offset),
        8 => return constantInstruction("OP_DEFINE_GLOBAL", chunk, offset),
        9 => return constantInstruction("OP_DEFINE_CONST_GLOBAL", chunk, offset),
        10 => return constantInstruction("OP_SET_GLOBAL", chunk, offset),
        11 => return byteInstruction("OP_GET_UPVALUE", chunk, offset),
        12 => return byteInstruction("OP_SET_UPVALUE", chunk, offset),
        13 => return constantInstruction("OP_GET_PROPERTY", chunk, offset),
        14 => return constantInstruction("OP_SET_PROPERTY", chunk, offset),
        15 => return constantInstruction("OP_GET_SUPER", chunk, offset),
        16 => return simpleInstruction("OP_EQUAL", offset),
        17 => return simpleInstruction("OP_GREATER", offset),
        18 => return simpleInstruction("OP_LESS", offset),
        19 => return simpleInstruction("OP_GREATER_EQUAL", offset),
        20 => return simpleInstruction("OP_ADD", offset),
        21 => return simpleInstruction("OP_SUBTRACT", offset),
        22 => return simpleInstruction("OP_MULTIPLY", offset),
        23 => return simpleInstruction("OP_DIVIDE", offset),
        24 => return simpleInstruction("OP_MODULO", offset),
        25 => return simpleInstruction("OP_EXPONENT", offset),
        26 => return simpleInstruction("OP_NOT", offset),
        27 => return simpleInstruction("OP_NEGATE", offset),
        28 => return simpleInstruction("OP_PRINT", offset),
        29 => return jumpInstruction("OP_JUMP", 1, chunk, offset),
        30 => return jumpInstruction("OP_JUMP_IF_FALSE", 1, chunk, offset),
        31 => return jumpInstruction("OP_LOOP", -1, chunk, offset),
        32 => return byteInstruction("OP_CALL", chunk, offset),
        33 => return byteInstruction("OP_TAIL_CALL", chunk, offset),
        34 => return invokeInstruction("OP_INVOKE", chunk, offset),
        35 => return invokeInstruction("OP_SUPER_INVOKE", chunk, offset),
        36 => {
            var offset_: i32 = offset + 1;
            const constant: u8 = chunk.*.code.?[@as(c_uint, @intCast(offset_))];
            offset_ += 1;
            std.debug.print("{s:<16} {d:4} ", .{ "OP_CLOSURE", constant });
            value_h.printValue(chunk.*.constants.values[constant]);
            std.debug.print("\n", .{});

            const function: *object_h.ObjFunction = @as(*object_h.ObjFunction, @ptrCast(@alignCast(chunk.*.constants.values[constant].as.obj)));
            {
                var j: i32 = 0;
                _ = &j;
                while (j < function.*.upvalueCount) : (j += 1) {
                    var isLocal: i32 = @as(i32, chunk.*.code.?[@as(c_uint, @intCast((offset_) + 1))]);
                    _ = &isLocal;
                    offset_ += 1;
                    var index: i32 = @as(i32, chunk.*.code.?[@as(c_uint, @intCast((offset_) + 1))]);
                    _ = &index;
                    offset_ += 1;
                    std.debug.print("{d:04}      |                     {s} {d}\n", .{ offset_ - 2, if (isLocal != 0) "local" else "upvalue", index });
                }
            }

            return offset_;
        },
        37 => return byteInstruction("OP_CLOSE_UPVALUE", chunk, offset),
        38 => return simpleInstruction("OP_RETURN", offset),
        39 => return constantInstruction("OP_CLASS", chunk, offset),
        40 => return simpleInstruction("OP_INHERIT", offset),
        41 => return constantInstruction("OP_METHOD", chunk, offset),
        42 => return simpleInstruction("OP_LENGTH", offset),
        43 => return simpleInstruction("OP_GET_INDEX", offset),
        44 => return simpleInstruction("OP_SLICE", offset),
        45 => return simpleInstruction("OP_RANGE", offset),
        46 => return simpleInstruction("OP_RANGE_INCLUSIVE", offset),
        47 => return simpleInstruction("OP_PAIR", offset),
        48 => return simpleInstruction("OP_CHECK_RANGE", offset),
        49 => return simpleInstruction("OP_IS_RANGE", offset),
        50 => return simpleInstruction("OP_GET_RANGE_LENGTH", offset),
        51 => return simpleInstruction("OP_SET_INDEX", offset),
        52 => return simpleInstruction("OP_DUP", offset),
        53 => return simpleInstruction("OP_INT", offset),
        54 => return simpleInstruction("OP_HASH_TABLE", offset),
        55 => return simpleInstruction("OP_ADD_ENTRY", offset),
        56 => return simpleInstruction("OP_TO_STRING", offset),
        57 => return simpleInstruction("OP_BREAK", offset),
        58 => return simpleInstruction("OP_CONTINUE", offset),
        59 => return byteInstruction("OP_FVECTOR", chunk, offset),
        60 => return twoByteInstruction("OP_MATRIX", chunk, offset),
        61 => return simpleInstruction("OP_GET_MATRIX_FLAT", offset),
        // Import opcodes (62-65 in OpCode enum)
        62 => return constantInstruction("OP_IMPORT_MODULE", chunk, offset),
        63 => return constantInstruction("OP_IMPORT_FILE", chunk, offset),
        64 => {
            // OP_IMPORT_SPECIFIC has 2 constant indices
            const nameSlice = "OP_IMPORT_SPECIFIC";
            const moduleConstant: u8 = getByte(chunk, offset + 1);
            const funcConstant: u8 = getByte(chunk, offset + 2);
            print("{s: <16} {d:4} {d:4}\n", .{ nameSlice, moduleConstant, funcConstant });
            return offset + 3;
        },
        65 => return constantInstruction("OP_IMPORT_MODULE_AS", chunk, offset),
        66 => return constantInstruction("OP_GET_MODULE_MEMBER", chunk, offset),

        // Phase 2: Small constant opcodes (67-82)
        67 => return smallConstantInstruction("OP_CONSTANT_0", chunk, 0, offset),
        68 => return smallConstantInstruction("OP_CONSTANT_1", chunk, 1, offset),
        69 => return smallConstantInstruction("OP_CONSTANT_2", chunk, 2, offset),
        70 => return smallConstantInstruction("OP_CONSTANT_3", chunk, 3, offset),
        71 => return smallConstantInstruction("OP_CONSTANT_4", chunk, 4, offset),
        72 => return smallConstantInstruction("OP_CONSTANT_5", chunk, 5, offset),
        73 => return smallConstantInstruction("OP_CONSTANT_6", chunk, 6, offset),
        74 => return smallConstantInstruction("OP_CONSTANT_7", chunk, 7, offset),
        75 => return smallConstantInstruction("OP_CONSTANT_8", chunk, 8, offset),
        76 => return smallConstantInstruction("OP_CONSTANT_9", chunk, 9, offset),
        77 => return smallConstantInstruction("OP_CONSTANT_10", chunk, 10, offset),
        78 => return smallConstantInstruction("OP_CONSTANT_11", chunk, 11, offset),
        79 => return smallConstantInstruction("OP_CONSTANT_12", chunk, 12, offset),
        80 => return smallConstantInstruction("OP_CONSTANT_13", chunk, 13, offset),
        81 => return smallConstantInstruction("OP_CONSTANT_14", chunk, 14, offset),
        82 => return smallConstantInstruction("OP_CONSTANT_15", chunk, 15, offset),

        // Phase 2.2: Small local opcodes (83-90)
        83 => return simpleInstruction("OP_GET_LOCAL_0", offset),
        84 => return simpleInstruction("OP_GET_LOCAL_1", offset),
        85 => return simpleInstruction("OP_GET_LOCAL_2", offset),
        86 => return simpleInstruction("OP_GET_LOCAL_3", offset),
        87 => return simpleInstruction("OP_SET_LOCAL_0", offset),
        88 => return simpleInstruction("OP_SET_LOCAL_1", offset),
        89 => return simpleInstruction("OP_SET_LOCAL_2", offset),
        90 => return simpleInstruction("OP_SET_LOCAL_3", offset),

        // Phase 2.3: Short jump opcodes (91-93)
        91 => return shortJumpInstruction("OP_JUMP_SHORT", 1, chunk, offset),
        92 => return shortJumpInstruction("OP_JUMP_IF_FALSE_SHORT", 1, chunk, offset),
        93 => return shortJumpInstruction("OP_LOOP_SHORT", -1, chunk, offset),

        // Visibility opcodes (94-97)
        94 => return constantInstruction("OP_DEFINE_PUBLIC_GLOBAL", chunk, offset),
        95 => return constantInstruction("OP_DEFINE_PUBLIC_CONST_GLOBAL", chunk, offset),
        96 => {
            // OP_IMPORT_FILE_AS has 2 constant indices (path + alias)
            const pathConst: u8 = getByte(chunk, offset + 1);
            const aliasConst: u8 = getByte(chunk, offset + 2);
            print("{s: <16} {d:4} {d:4}\n", .{ "OP_IMPORT_FILE_AS", pathConst, aliasConst });
            return offset + 3;
        },
        97 => {
            // OP_FROM_IMPORT_FILE has 2 constant indices (path + func name)
            const pathConst: u8 = getByte(chunk, offset + 1);
            const funcConst: u8 = getByte(chunk, offset + 2);
            print("{s: <16} {d:4} {d:4}\n", .{ "OP_FROM_IMPORT_FILE", pathConst, funcConst });
            return offset + 3;
        },

        // Phase 3: Superinstructions (100-191)
        100 => return superinstructionTwoOp("OP_DEFINE_GLOBAL_CONST", chunk, offset),
        101 => return superinstructionTwoOp("OP_SET_GLOBAL_CONST", chunk, offset),
        110 => return superinstructionOneOp("OP_GET_GLOBAL_ADD", chunk, offset),
        111 => return superinstructionOneOp("OP_GET_GLOBAL_SUBTRACT", chunk, offset),
        112 => return superinstructionOneOp("OP_GET_GLOBAL_MULTIPLY", chunk, offset),
        113 => return superinstructionOneOp("OP_GET_GLOBAL_DIVIDE", chunk, offset),
        114 => return superinstructionOneOp("OP_GET_LOCAL_ADD", chunk, offset),
        120 => return superinstructionTwoOp("OP_GET_GLOBAL_GLOBAL", chunk, offset),
        121 => return superinstructionTwoOp("OP_GET_LOCAL_LOCAL", chunk, offset),
        122 => return superinstructionTwoOp("OP_GET_GLOBAL_LOCAL", chunk, offset),
        123 => return superinstructionTwoOp("OP_GET_LOCAL_GLOBAL", chunk, offset),
        130 => return superinstructionTwoOp("OP_CONSTANT_CONSTANT", chunk, offset),
        131 => return superinstructionOneOp("OP_CONSTANT_ADD", chunk, offset),
        132 => return superinstructionOneOp("OP_CONSTANT_MULTIPLY", chunk, offset),
        140 => return jumpInstruction("OP_LESS_JUMP_IF_FALSE", 1, chunk, offset),
        150 => return superinstructionTwoOp("OP_GET_LOCAL_CONSTANT", chunk, offset),
        151 => return superinstructionOneOp("OP_ADD_SET_LOCAL", chunk, offset),
        152 => return superinstructionOneOp("OP_SET_LOCAL_POP", chunk, offset),
        192 => return superinstructionThreeOp("OP_ADD_REG", chunk, offset),
        193 => return superinstructionThreeOp("OP_SUB_REG", chunk, offset),
        194 => return superinstructionThreeOp("OP_MUL_REG", chunk, offset),
        195 => return superinstructionThreeOp("OP_DIV_REG", chunk, offset),
        196 => return byteInstruction("OP_GET_GLOBAL_SLOT", chunk, offset),
        197 => return byteInstruction("OP_SET_GLOBAL_SLOT", chunk, offset),
        198 => return byteInstruction("OP_SET_GLOBAL_SLOT_KEEP", chunk, offset),
        199 => return jumpInstruction("OP_LOOP_COUNT", -1, chunk, offset),
        200 => return superinstructionTwoOp("OP_GET_LOCAL_LESS", chunk, offset),

        else => {
            std.debug.print("Unknown opcode {d}\n", .{instruction});
            return offset + 1;
        },
    }
}

fn constantInstruction(name: []const u8, chunk: *chunk_h.Chunk, offset: i32) i32 {
    const constant: u8 = getByte(chunk, offset + 1);
    print("{s: <16} {d:4} '", .{ name, constant });
    value_h.printValue(chunk.*.constants.values[constant]);
    print("'\n", .{});
    return offset + 2;
}

// Phase 2: Small constant instruction (single-byte, no operand)
fn smallConstantInstruction(name: []const u8, chunk: *chunk_h.Chunk, constant_idx: u8, offset: i32) i32 {
    print("{s: <16} (idx={d:2}) '", .{ name, constant_idx });
    value_h.printValue(chunk.*.constants.values[constant_idx]);
    print("'\n", .{});
    return offset + 1; // Only 1 byte (no operand)
}

fn invokeInstruction(name: [*]const u8, chunk: *chunk_h.Chunk, offset: i32) i32 {
    const nameSlice = std.mem.span(@as([*:0]const u8, @ptrCast(name)));
    const constant: u8 = getByte(chunk, offset + 1);
    const argCount: u8 = getByte(chunk, offset + 2);
    print("{s: <16} ({d} args) {d:4} '", .{ nameSlice, argCount, constant });
    printValue(chunk.*.constants.values[constant]);
    print("'\n", .{});
    return offset + 3;
}
fn simpleInstruction(name: [*]const u8, offset: i32) i32 {
    // Convert to a proper slice for string formatting
    const nameSlice = std.mem.span(@as([*:0]const u8, @ptrCast(name)));
    print("{s}\n", .{nameSlice});
    return offset + 1;
}

fn byteInstruction(name: [*]const u8, chunk: *chunk_h.Chunk, offset: i32) i32 {
    const nameSlice = std.mem.span(@as([*:0]const u8, @ptrCast(name)));
    const slot: u8 = getByte(chunk, offset + 1);
    print("{s: <16} {d:4}", .{ nameSlice, slot });
    return offset + 2;
}

fn jumpInstruction(name: [*]const u8, sign: i32, chunk: *chunk_h.Chunk, offset: i32) i32 {
    const nameSlice = std.mem.span(@as([*:0]const u8, @ptrCast(name)));
    const byte1: u8 = getByte(chunk, offset + 1);
    const byte2: u8 = getByte(chunk, offset + 2);
    const jump: u16 = (@as(u16, byte1) << 8) | byte2;

    const jumpTarget = (offset + 3) + (sign * @as(i32, jump));
    print("{s: <16} {d:4} -> {d}\n", .{ nameSlice, offset, jumpTarget });
    return offset + 3;
}

fn twoByteInstruction(name: [*]const u8, chunk: *chunk_h.Chunk, offset: i32) i32 {
    const nameSlice = std.mem.span(@as([*:0]const u8, @ptrCast(name)));
    const byte1: u8 = getByte(chunk, offset + 1);
    const byte2: u8 = getByte(chunk, offset + 2);
    print("{s: <16} {d:4} {d:4}\n", .{ nameSlice, byte1, byte2 });
    return offset + 3;
}

// Phase 2.3: Short jump instruction (single-byte i8 offset)
fn shortJumpInstruction(name: [*]const u8, sign: i32, chunk: *chunk_h.Chunk, offset: i32) i32 {
    const nameSlice = std.mem.span(@as([*:0]const u8, @ptrCast(name)));
    const jumpOffset: i8 = @bitCast(getByte(chunk, offset + 1));
    const jumpTarget = (offset + 2) + (sign * @as(i32, jumpOffset));
    print("{s: <16} {d:4} -> {d}\n", .{ nameSlice, offset, jumpTarget });
    return offset + 2; // Only 2 bytes total (opcode + i8 offset)
}

// Phase 3: Superinstruction with one operand
fn superinstructionOneOp(name: [*]const u8, chunk: *chunk_h.Chunk, offset: i32) i32 {
    const nameSlice = std.mem.span(@as([*:0]const u8, @ptrCast(name)));
    const operand: u8 = getByte(chunk, offset + 1);
    print("{s: <16} {d:4}\n", .{ nameSlice, operand });
    return offset + 2;
}

// Phase 3: Superinstruction with two operands
fn superinstructionTwoOp(name: [*]const u8, chunk: *chunk_h.Chunk, offset: i32) i32 {
    const nameSlice = std.mem.span(@as([*:0]const u8, @ptrCast(name)));
    const operand1: u8 = getByte(chunk, offset + 1);
    const operand2: u8 = getByte(chunk, offset + 2);
    print("{s: <16} {d:4} {d:4}\n", .{ nameSlice, operand1, operand2 });
    return offset + 3;
}

// Phase 4: Superinstruction with three operands
fn superinstructionThreeOp(name: [*]const u8, chunk: *chunk_h.Chunk, offset: i32) i32 {
    const nameSlice = std.mem.span(@as([*:0]const u8, @ptrCast(name)));
    const operand1: u8 = getByte(chunk, offset + 1);
    const operand2: u8 = getByte(chunk, offset + 2);
    const operand3: u8 = getByte(chunk, offset + 3);
    print("{s: <16} {d:4} {d:4} {d:4}\n", .{ nameSlice, operand1, operand2, operand3 });
    return offset + 4;
}
