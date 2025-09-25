const std = @import("std");
const print = std.debug.print;

const Chunk = @import("chunk.zig").Chunk;
const obj_h = @import("object.zig");
const ObjFunction = obj_h.ObjFunction;
const printValue = @import("value.zig").printValue;

// Helper function to get line at a specific offset
fn getLine(c: *Chunk, pos: i32) i32 {
    const idx: usize = @intCast(if (pos >= 0) pos else unreachable);
    if (c.*.lines) |lines| {
        return lines[idx];
    }
    return 0;
}

// Helper function to get byte at a specific offset
fn getByte(c: *Chunk, pos: i32) u8 {
    const idx: usize = @intCast(if (pos >= 0) pos else unreachable);
    if (c.*.code) |code| {
        return code[idx];
    }
    return 0;
}

pub fn disassembleChunk(chunk: *Chunk, name: [*]const u8) void {
    // Create a slice from the pointer to handle string formatting properly
    const nameSlice = std.mem.span(@as([*:0]const u8, @ptrCast(name)));
    print("== {s} ==\n", .{nameSlice});

    var offset: i32 = 0;

    while (offset < chunk.*.count) {
        offset = disassembleInstruction(chunk, offset);
    }
}

pub fn disassembleInstruction(chunk: *Chunk, offset: i32) i32 {
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
        9 => return constantInstruction("OP_SET_GLOBAL", chunk, offset),
        10 => return byteInstruction("OP_GET_UPVALUE", chunk, offset),
        11 => return byteInstruction("OP_SET_UPVALUE", chunk, offset),
        12 => return constantInstruction("OP_GET_PROPERTY", chunk, offset),
        13 => return constantInstruction("OP_SET_PROPERTY", chunk, offset),
        14 => return constantInstruction("OP_GET_SUPER", chunk, offset),
        15 => return simpleInstruction("OP_EQUAL", offset),
        16 => return simpleInstruction("OP_GREATER", offset),
        17 => return simpleInstruction("OP_LESS", offset),
        18 => return simpleInstruction("OP_ADD", offset),
        19 => return simpleInstruction("OP_SUBTRACT", offset),
        20 => return simpleInstruction("OP_MULTIPLY", offset),
        21 => return simpleInstruction("OP_DIVIDE", offset),
        22 => return simpleInstruction("OP_MODULO", offset),
        23 => return simpleInstruction("OP_EXPONENT", offset),
        24 => return simpleInstruction("OP_NOT", offset),
        25 => return simpleInstruction("OP_NEGATE", offset),
        26 => return simpleInstruction("OP_PRINT", offset),
        27 => return jumpInstruction("OP_JUMP", 1, chunk, offset),
        28 => return jumpInstruction("OP_JUMP_IF_FALSE", 1, chunk, offset),
        29 => return jumpInstruction("OP_LOOP", -1, chunk, offset),
        30 => return byteInstruction("OP_CALL", chunk, offset),
        31 => return invokeInstruction("OP_INVOKE", chunk, offset),
        32 => return invokeInstruction("OP_SUPER_INVOKE", chunk, offset),
        33 => {
            // Special handling for OP_CLOSURE instruction
            var newOffset = offset + 1;
            const constant = getByte(chunk, newOffset);
            newOffset += 1;

            print("{s: <16} {d:4}", .{ "OP_CLOSURE", constant });
            printValue(chunk.*.constants.values[constant]);
            print("\n", .{});

            const function = @as(*ObjFunction, @ptrCast(@alignCast(chunk.*.constants.values[constant].as.obj)));

            // Process upvalues
            var j: i32 = 0;
            while (j < function.*.upvalueCount) : (j += 1) {
                const isLocal = getByte(chunk, newOffset) != 0;
                newOffset += 1;
                const index = getByte(chunk, newOffset);
                newOffset += 1;

                const localOrUpvalue = if (isLocal) "local" else "upvalue";
                print("{d:0>4}      |                  {s} {d:0>4}\n", .{ newOffset - 2, localOrUpvalue, index });
            }

            return newOffset;
        },
        34 => return simpleInstruction("OP_CLOSE_UPVALUE", offset),
        35 => return simpleInstruction("OP_RETURN", offset),
        36 => return constantInstruction("OP_CLASS", chunk, offset),
        37 => return simpleInstruction("OP_INHERIT", offset),
        38 => return constantInstruction("OP_METHOD", chunk, offset),
        39 => return byteInstruction("OP_FVECTOR", chunk, offset),
        40 => return simpleInstruction("OP_GET_INDEX", offset),
        41 => return simpleInstruction("OP_SET_INDEX", offset),
        42 => return simpleInstruction("OP_LENGTH", offset),
        43 => return simpleInstruction("OP_DUP", offset),
        44 => return simpleInstruction("OP_SLICE", offset),
        45 => return simpleInstruction("OP_INT", offset),
        46 => return simpleInstruction("OP_TO_STRING", offset),
        47 => return simpleInstruction("OP_HASH_TABLE", offset),
        48 => return simpleInstruction("OP_ADD_ENTRY", offset),
        49 => return simpleInstruction("OP_RANGE", offset),
        50 => return simpleInstruction("OP_RANGE_INCLUSIVE", offset),
        51 => return simpleInstruction("OP_GREATER_EQUAL", offset),
        52 => return simpleInstruction("OP_CHECK_RANGE", offset),
        53 => return simpleInstruction("OP_IS_RANGE", offset),
        54 => return simpleInstruction("OP_GET_RANGE_LENGTH", offset),
        55 => return simpleInstruction("OP_BREAK", offset),
        56 => return simpleInstruction("OP_CONTINUE", offset),
        57 => return simpleInstruction("OP_PAIR", offset),
        58 => return simpleInstruction("OP_ADD_INT", offset),
        59 => return simpleInstruction("OP_ADD_FLOAT", offset),
        60 => return simpleInstruction("OP_SUB_INT", offset),
        61 => return simpleInstruction("OP_SUB_FLOAT", offset),
        62 => return simpleInstruction("OP_MUL_INT", offset),
        63 => return simpleInstruction("OP_MUL_FLOAT", offset),
        else => {
            print("Unknown opcode {d}\n", .{instruction});
            return offset + 1;
        },
    }
}

pub fn constantInstruction(name: [*]const u8, chunk: *Chunk, offset: i32) i32 {
    const nameSlice = std.mem.span(@as([*:0]const u8, @ptrCast(name)));
    const constant: u8 = getByte(chunk, offset + 1);
    print("{s: <16} {d:4} '", .{ nameSlice, constant });
    printValue(chunk.*.constants.values[constant]);
    print("'\n", .{});
    return offset + 2;
}

pub fn invokeInstruction(name: [*]const u8, chunk: *Chunk, offset: i32) i32 {
    const nameSlice = std.mem.span(@as([*:0]const u8, @ptrCast(name)));
    const constant: u8 = getByte(chunk, offset + 1);
    const argCount: u8 = getByte(chunk, offset + 2);
    print("{s: <16} ({d} args) {d:4} '", .{ nameSlice, argCount, constant });
    printValue(chunk.*.constants.values[constant]);
    print("'\n", .{});
    return offset + 3;
}
pub fn simpleInstruction(name: [*]const u8, offset: i32) i32 {
    // Convert to a proper slice for string formatting
    const nameSlice = std.mem.span(@as([*:0]const u8, @ptrCast(name)));
    print("{s}\n", .{nameSlice});
    return offset + 1;
}

pub fn byteInstruction(name: [*]const u8, chunk: *Chunk, offset: i32) i32 {
    const nameSlice = std.mem.span(@as([*:0]const u8, @ptrCast(name)));
    const slot: u8 = getByte(chunk, offset + 1);
    print("{s: <16} {d:4}", .{ nameSlice, slot });
    return offset + 2;
}

pub fn jumpInstruction(name: [*]const u8, sign: i32, chunk: *Chunk, offset: i32) i32 {
    const nameSlice = std.mem.span(@as([*:0]const u8, @ptrCast(name)));
    const byte1: u8 = getByte(chunk, offset + 1);
    const byte2: u8 = getByte(chunk, offset + 2);
    const jump: u16 = (@as(u16, byte1) << 8) | byte2;

    const jumpTarget = (offset + 3) + (sign * @as(i32, jump));
    print("{s: <16} {d:4} -> {d}\n", .{ nameSlice, offset, jumpTarget });
    return offset + 3;
}
