/// Jump Offset Patcher for MufiZ Bytecode Optimizer
///
/// This module implements jump offset tracking and patching to safely support
/// bytecode optimizations that change instruction sizes/positions.
///
/// PROBLEM: When optimizer removes/adds bytes, jump offsets become invalid
/// SOLUTION: Track jumps, track modifications, update offsets accordingly
///
/// Architecture:
/// 1. Scan bytecode → identify all jump instructions
/// 2. Track modifications → record size changes during optimization
/// 3. Patch jumps → update offsets based on modifications
/// 4. Validate → ensure all jumps are valid
///
/// Phase 4.1: Jump Offset Patching Infrastructure
const std = @import("std");
const chunk_h = @import("chunk.zig");
const Chunk = chunk_h.Chunk;
const OpCode = chunk_h.OpCode;
const analyzer = @import("bytecode_analyzer.zig");

/// Information about a single jump instruction in bytecode
pub const JumpInfo = struct {
    opcode: OpCode, // The jump instruction (JUMP, JUMP_IF_FALSE, etc.)
    location: usize, // Absolute offset of jump instruction in bytecode
    operand_offset: usize, // Absolute offset where the jump offset operand is stored
    target_offset: i32, // Relative offset to jump target (as encoded in bytecode)
    absolute_target: usize, // Absolute address of jump target (calculated)
    is_forward: bool, // true = forward jump, false = backward jump (loop)
    operand_size: u8, // Size of offset operand in bytes (usually 2 for i16)

    /// Calculate absolute target from relative offset
    pub fn calculateTarget(location: usize, relative_offset: i32, instruction_size: usize) usize {
        // Target is calculated from the NEXT instruction after the jump
        const next_instruction = location + instruction_size;
        if (relative_offset >= 0) {
            return next_instruction + @as(usize, @intCast(relative_offset));
        } else {
            const abs_offset = @as(usize, @intCast(-relative_offset));
            return next_instruction - abs_offset;
        }
    }

    /// Recalculate relative offset from absolute target (after patching)
    pub fn calculateRelativeOffset(location: usize, absolute_target: usize, instruction_size: usize) i32 {
        const next_instruction = location + instruction_size;
        if (absolute_target >= next_instruction) {
            // Forward jump
            return @intCast(absolute_target - next_instruction);
        } else {
            // Backward jump (loop)
            const distance = next_instruction - absolute_target;
            return -@as(i32, @intCast(distance));
        }
    }
};

/// Record of a bytecode modification (insertion/deletion)
pub const Modification = struct {
    offset: usize, // Where in bytecode the modification occurred
    bytes_removed: usize, // Number of bytes removed (0 if insertion)
    bytes_added: usize, // Number of bytes added (0 if deletion)

    /// Get net change in bytecode size (positive = grew, negative = shrunk)
    pub fn netChange(self: *const Modification) i32 {
        return @as(i32, @intCast(self.bytes_added)) - @as(i32, @intCast(self.bytes_removed));
    }

    /// Check if this modification affects a given bytecode location
    pub fn affects(self: *const Modification, location: usize) bool {
        return location >= self.offset;
    }
};

/// Statistics from jump patching operation
pub const PatchStats = struct {
    jumps_scanned: usize = 0,
    jumps_patched: usize = 0,
    forward_jumps: usize = 0,
    backward_jumps: usize = 0,
    validation_errors: usize = 0,

    pub fn print(self: *const PatchStats) void {
        std.debug.print("\n=== Jump Patching Statistics ===\n", .{});
        std.debug.print("Jumps scanned: {d}\n", .{self.jumps_scanned});
        std.debug.print("Jumps patched: {d}\n", .{self.jumps_patched});
        std.debug.print("  Forward jumps: {d}\n", .{self.forward_jumps});
        std.debug.print("  Backward jumps: {d}\n", .{self.backward_jumps});
        if (self.validation_errors > 0) {
            std.debug.print("⚠️  Validation errors: {d}\n", .{self.validation_errors});
        }
        std.debug.print("================================\n\n", .{});
    }
};

/// Get the size of a jump instruction in bytes
fn getJumpInstructionSize(opcode: OpCode) ?usize {
    return switch (opcode) {
        .OP_JUMP => 3, // opcode (1) + i16 offset (2)
        .OP_JUMP_IF_FALSE => 3, // opcode (1) + i16 offset (2)
        .OP_LOOP => 3, // opcode (1) + i16 offset (2)
        .OP_JUMP_SHORT => 2, // opcode (1) + i8 offset (1) - Phase 2.3
        .OP_JUMP_IF_FALSE_SHORT => 2, // opcode (1) + i8 offset (1) - Phase 2.3
        .OP_LOOP_SHORT => 2, // opcode (1) + i8 offset (1) - Phase 2.3
        else => null,
    };
}

/// Check if an opcode is a jump instruction
/// Uses raw byte comparison instead of @enumFromInt to avoid panics on invalid enum values
fn isJumpInstruction(opcode_byte: u8) bool {
    return switch (opcode_byte) {
        @intFromEnum(OpCode.OP_JUMP),
        @intFromEnum(OpCode.OP_JUMP_IF_FALSE),
        @intFromEnum(OpCode.OP_LOOP),
        => true,
        @intFromEnum(OpCode.OP_JUMP_SHORT),
        @intFromEnum(OpCode.OP_JUMP_IF_FALSE_SHORT),
        @intFromEnum(OpCode.OP_LOOP_SHORT),
        => true, // Phase 2.3 short jumps
        else => false,
    };
}

/// Read an 8-bit signed offset from bytecode (for short jumps)
fn readOffset8(code: [*]u8, offset: usize) i8 {
    return @bitCast(code[offset]);
}

/// Read a 16-bit signed offset from bytecode (BIG-ENDIAN to match compiler's patchJump)
fn readOffset16(code: [*]u8, offset: usize) i16 {
    const byte1 = code[offset]; // HIGH byte
    const byte2 = code[offset + 1]; // LOW byte
    const value = (@as(u16, byte1) << 8) | @as(u16, byte2);
    return @bitCast(value);
}

/// Write an 8-bit signed offset to bytecode (for short jumps)
fn writeOffset8(code: [*]u8, offset: usize, value: i8) void {
    code[offset] = @bitCast(value);
}

/// Write a 16-bit signed offset to bytecode (BIG-ENDIAN to match compiler's patchJump)
fn writeOffset16(code: [*]u8, offset: usize, value: i16) void {
    const uvalue: u16 = @bitCast(value);
    code[offset] = @truncate((uvalue >> 8) & 0xFF); // HIGH byte first
    code[offset + 1] = @truncate(uvalue & 0xFF); // LOW byte second
}

/// Scan bytecode and collect all jump instructions
pub fn scanJumps(chunk: *Chunk, allocator: std.mem.Allocator) ![]JumpInfo {
    // First pass: count jumps
    const code = chunk.code.?;
    var offset: usize = 0;
    var jump_count: usize = 0;

    while (offset < @as(usize, @intCast(chunk.count))) {
        const opcode_byte = code[offset];
        if (isJumpInstruction(opcode_byte)) {
            jump_count += 1;
        }
        // Advance by full instruction size, not just 1 byte
        const instruction_length = chunk_h.getInstructionLength(chunk, offset);
        if (instruction_length == 0) break; // Safety: invalid offset
        offset += instruction_length;
    }

    // Allocate array for jumps
    const jumps = try allocator.alloc(JumpInfo, jump_count);
    errdefer allocator.free(jumps);

    // Second pass: collect jump info
    offset = 0;
    var jump_index: usize = 0;

    while (offset < @as(usize, @intCast(chunk.count))) {
        const opcode_byte = code[offset];

        if (isJumpInstruction(opcode_byte)) {
            const opcode: OpCode = @enumFromInt(opcode_byte);
            const instruction_size = getJumpInstructionSize(opcode) orelse {
                return error.InvalidJumpInstruction;
            };

            // Read the jump offset operand (depends on instruction type)
            const operand_offset = offset + 1;
            const is_short_jump = (opcode == .OP_JUMP_SHORT or
                opcode == .OP_JUMP_IF_FALSE_SHORT or
                opcode == .OP_LOOP_SHORT);

            // Read the offset from bytecode
            var relative_offset: i32 = if (is_short_jump)
                @as(i32, readOffset8(code, operand_offset))
            else
                @as(i32, readOffset16(code, operand_offset));

            // IMPORTANT: OP_LOOP and OP_LOOP_SHORT store POSITIVE offsets that represent BACKWARD jumps
            // The VM interprets them by subtracting from IP, so we need to negate them here
            const is_loop = (opcode == .OP_LOOP or opcode == .OP_LOOP_SHORT);

            // Determine if forward or backward jump BEFORE negating loop offsets
            // For loops, they are ALWAYS backward jumps (by definition)
            const is_forward = if (is_loop) false else (relative_offset >= 0);

            if (is_loop) {
                relative_offset = -relative_offset;
            }

            // Calculate absolute target
            const absolute_target = JumpInfo.calculateTarget(
                offset,
                relative_offset,
                instruction_size,
            );

            jumps[jump_index] = JumpInfo{
                .opcode = opcode,
                .location = offset,
                .operand_offset = operand_offset,
                .target_offset = relative_offset,
                .absolute_target = absolute_target,
                .is_forward = is_forward,
                .operand_size = if (is_short_jump) @as(usize, 1) else @as(usize, 2),
            };
            jump_index += 1;
        }

        // Advance by full instruction size, not just 1 byte
        const instruction_length = chunk_h.getInstructionLength(chunk, offset);
        if (instruction_length == 0) break; // Safety: invalid offset
        offset += instruction_length;
    }

    return jumps;
}

/// Calculate adjustment needed for a jump's target based on modifications
/// The adjustment is the sum of all modifications between the jump and its target
fn calculateJumpAdjustment(jump: *const JumpInfo, modifications: []const Modification) i32 {
    var adjustment: i32 = 0;

    // Calculate the range between jump and target
    const range_start = if (jump.is_forward) jump.location else jump.absolute_target;
    const range_end = if (jump.is_forward) jump.absolute_target else jump.location;

    // Sum up modifications that fall within this range
    // Modifications shift everything after them, so if a modification is between
    // the jump and its target, it affects the relative distance
    for (modifications) |mod| {
        // Only count modifications that are after the range start and before/at the range end
        // For forward jumps: modifications between jump location and target
        // For backward jumps: modifications between target and jump location
        if (mod.offset > range_start and mod.offset <= range_end) {
            adjustment += mod.netChange();
        }
    }

    return adjustment;
}

/// Update jump offsets in bytecode based on modifications
pub fn patchJumps(
    chunk: *Chunk,
    jumps: []JumpInfo,
    modifications: []const Modification,
    stats: *PatchStats,
) !void {
    const code = chunk.code.?;

    for (jumps) |*jump| {
        stats.jumps_scanned += 1;
        if (jump.is_forward) {
            stats.forward_jumps += 1;
        } else {
            stats.backward_jumps += 1;
        }

        // Calculate how much the jump location and target have shifted
        var adjusted_location = jump.location;
        var adjusted_target = jump.absolute_target;

        // Adjust jump location for modifications before it
        for (modifications) |mod| {
            if (mod.offset < jump.location) {
                const loc_adjustment = mod.netChange();
                if (loc_adjustment >= 0) {
                    adjusted_location += @intCast(loc_adjustment);
                } else {
                    adjusted_location -= @intCast(-loc_adjustment);
                }
            }
        }

        // Adjust target for modifications before it
        for (modifications) |mod| {
            if (mod.offset < jump.absolute_target) {
                const target_adjustment = mod.netChange();
                if (target_adjustment >= 0) {
                    adjusted_target += @intCast(target_adjustment);
                } else {
                    adjusted_target -= @intCast(-target_adjustment);
                }
            }
        }

        // Update jump info for validation
        jump.location = adjusted_location;
        jump.absolute_target = adjusted_target;
        jump.operand_offset = adjusted_location + 1; // Operand is always 1 byte after opcode

        // Recalculate the relative offset from new location to new target
        const instruction_size = getJumpInstructionSize(jump.opcode) orelse {
            return error.InvalidJumpInstruction;
        };

        var new_relative_offset = JumpInfo.calculateRelativeOffset(
            adjusted_location,
            adjusted_target,
            instruction_size,
        );

        // IMPORTANT: OP_LOOP and OP_LOOP_SHORT store offsets as POSITIVE even though they're backward jumps
        // We need to negate the offset before writing it back to bytecode
        const is_loop = (jump.opcode == .OP_LOOP or jump.opcode == .OP_LOOP_SHORT);
        if (is_loop) {
            new_relative_offset = -new_relative_offset;
        }

        // Write the new offset back to bytecode
        const is_short_jump = (jump.opcode == .OP_JUMP_SHORT or
            jump.opcode == .OP_JUMP_IF_FALSE_SHORT or
            jump.opcode == .OP_LOOP_SHORT);

        if (is_short_jump) {
            // Short jump: check if offset still fits in i8
            if (new_relative_offset < -128 or new_relative_offset > 127) {
                std.debug.print(
                    "⚠️  Short jump at {d} needs offset {d} which doesn't fit in i8\n",
                    .{ adjusted_location, new_relative_offset },
                );
                return error.ShortJumpOffsetOverflow;
            }
            writeOffset8(code, jump.operand_offset, @intCast(new_relative_offset));
        } else {
            // Regular jump: check if offset fits in i16
            if (new_relative_offset < -32768 or new_relative_offset > 32767) {
                std.debug.print(
                    "⚠️  Jump at {d} needs offset {d} which doesn't fit in i16\n",
                    .{ adjusted_location, new_relative_offset },
                );
                return error.JumpOffsetOverflow;
            }
            writeOffset16(code, jump.operand_offset, @intCast(new_relative_offset));
        }

        stats.jumps_patched += 1;
    }
}

/// Validate that all jumps are valid after patching
pub fn validateJumps(chunk: *Chunk, jumps: []const JumpInfo, stats: *PatchStats) bool {
    var all_valid = true;
    const chunk_size = @as(usize, @intCast(chunk.count));

    for (jumps) |jump| {
        // Check 1: Jump target is within bounds
        if (jump.absolute_target >= chunk_size) {
            std.debug.print(
                "❌ Jump at offset {d} targets out-of-bounds offset {d} (chunk size: {d})\n",
                .{ jump.location, jump.absolute_target, chunk_size },
            );
            stats.validation_errors += 1;
            all_valid = false;
            continue;
        }

        // Check 2: Jump target is at a valid instruction boundary
        // This is a heuristic check - we verify the target is a reasonable opcode
        const target_byte = chunk.code.?[jump.absolute_target];
        const is_valid_opcode = target_byte < 200; // Reasonable upper bound for opcodes

        if (!is_valid_opcode) {
            std.debug.print(
                "⚠️  Jump at offset {d} targets suspicious opcode {d} at offset {d}\n",
                .{ jump.location, target_byte, jump.absolute_target },
            );
            // Don't fail validation on this - it might be a valid opcode we don't know about
        }

        // Check 3: Jump doesn't target itself (infinite tight loop)
        if (jump.absolute_target == jump.location) {
            std.debug.print(
                "⚠️  Jump at offset {d} targets itself (infinite loop)\n",
                .{jump.location},
            );
            // This is technically valid but suspicious
        }
    }

    return all_valid;
}

/// High-level API: Patch jumps after a set of modifications
pub fn patchAfterModifications(
    chunk: *Chunk,
    modifications: []const Modification,
    allocator: std.mem.Allocator,
) !PatchStats {
    var stats = PatchStats{};

    // Scan for jumps in the modified bytecode
    const jumps = try scanJumps(chunk, allocator);
    defer allocator.free(jumps);

    // Patch all jumps
    try patchJumps(chunk, jumps, modifications, &stats);

    // Validate results
    const valid = validateJumps(chunk, jumps, &stats);
    if (!valid) {
        return error.JumpValidationFailed;
    }

    return stats;
}

/// Test helper: Verify jump patching didn't corrupt bytecode
pub fn verifyBytecodeIntegrity(chunk: *Chunk, allocator: std.mem.Allocator) !bool {
    const jumps = try scanJumps(chunk, allocator);
    defer allocator.free(jumps);

    var stats = PatchStats{};
    return validateJumps(chunk, jumps, &stats);
}

// =============================================================================
// UNIT TESTS
// =============================================================================

test "JumpInfo.calculateTarget - forward jump" {
    // Jump at offset 10, instruction size 3, relative offset +20
    // Next instruction at 13, target at 13 + 20 = 33
    const target = JumpInfo.calculateTarget(10, 20, 3);
    try std.testing.expectEqual(@as(usize, 33), target);
}

test "JumpInfo.calculateTarget - backward jump" {
    // Jump at offset 50, instruction size 3, relative offset -20
    // Next instruction at 53, target at 53 - 20 = 33
    const target = JumpInfo.calculateTarget(50, -20, 3);
    try std.testing.expectEqual(@as(usize, 33), target);
}

test "JumpInfo.calculateRelativeOffset - forward jump" {
    // Jump at 10, target at 33, instruction size 3
    // Next instruction at 13, relative offset = 33 - 13 = 20
    const offset = JumpInfo.calculateRelativeOffset(10, 33, 3);
    try std.testing.expectEqual(@as(i32, 20), offset);
}

test "JumpInfo.calculateRelativeOffset - backward jump" {
    // Jump at 50, target at 33, instruction size 3
    // Next instruction at 53, relative offset = -(53 - 33) = -20
    const offset = JumpInfo.calculateRelativeOffset(50, 33, 3);
    try std.testing.expectEqual(@as(i32, -20), offset);
}

test "Modification.netChange" {
    const mod_remove = Modification{ .offset = 10, .bytes_removed = 5, .bytes_added = 0 };
    try std.testing.expectEqual(@as(i32, -5), mod_remove.netChange());

    const mod_add = Modification{ .offset = 10, .bytes_removed = 0, .bytes_added = 3 };
    try std.testing.expectEqual(@as(i32, 3), mod_add.netChange());

    const mod_replace = Modification{ .offset = 10, .bytes_removed = 4, .bytes_added = 3 };
    try std.testing.expectEqual(@as(i32, -1), mod_replace.netChange());
}

test "readOffset16 and writeOffset16" {
    var buffer: [4]u8 = undefined;

    // Test positive offset
    writeOffset16(&buffer, 0, 1000);
    const read1 = readOffset16(&buffer, 0);
    try std.testing.expectEqual(@as(i16, 1000), read1);

    // Test negative offset
    writeOffset16(&buffer, 0, -500);
    const read2 = readOffset16(&buffer, 0);
    try std.testing.expectEqual(@as(i16, -500), read2);

    // Test zero
    writeOffset16(&buffer, 0, 0);
    const read3 = readOffset16(&buffer, 0);
    try std.testing.expectEqual(@as(i16, 0), read3);
}

test "scanJumps - instruction boundary scanning" {
    const testing = std.testing;
    const allocator = testing.allocator;

    // Create a realistic bytecode sequence with various instruction sizes
    // This tests that we scan on instruction boundaries, not byte-by-byte
    var chunk: Chunk = undefined;
    chunk_h.initChunk(&chunk);
    defer chunk_h.freeChunk(&chunk);

    // Build bytecode:
    // 0: OP_CONSTANT (2 bytes: opcode + idx)
    chunk_h.writeChunk(&chunk, 0, 1); // OP_CONSTANT
    chunk_h.writeChunk(&chunk, 5, 1); // constant index 5

    // 2: OP_GET_LOCAL (2 bytes: opcode + slot)
    chunk_h.writeChunk(&chunk, 5, 1); // OP_GET_LOCAL
    chunk_h.writeChunk(&chunk, 3, 1); // local slot 3

    // 4: OP_ADD (1 byte)
    chunk_h.writeChunk(&chunk, 20, 1); // OP_ADD

    // 5: OP_JUMP (3 bytes: opcode + 2-byte offset) <-- First jump
    // Jump forward to offset 18 (from next instruction at 8, offset = +10)
    chunk_h.writeChunk(&chunk, 29, 1); // OP_JUMP
    chunk_h.writeChunk(&chunk, 10, 1); // offset low byte (0x000A)
    chunk_h.writeChunk(&chunk, 0, 1); // offset high byte

    // 8: OP_POP (1 byte)
    chunk_h.writeChunk(&chunk, 4, 1); // OP_POP

    // 9: OP_GET_GLOBAL (2 bytes: opcode + idx)
    chunk_h.writeChunk(&chunk, 7, 1); // OP_GET_GLOBAL
    chunk_h.writeChunk(&chunk, 2, 1); // global index 2

    // 11: OP_LOOP (3 bytes: opcode + 2-byte offset) <-- Second jump
    // Loop back to offset 2 (from next instruction at 14, offset = -12 = 0xFFF4)
    chunk_h.writeChunk(&chunk, 31, 1); // OP_LOOP (backward jump)
    chunk_h.writeChunk(&chunk, 244, 1); // offset low byte (0xF4)
    chunk_h.writeChunk(&chunk, 255, 1); // offset high byte (0xFF)

    // 14: OP_POP (1 byte)
    chunk_h.writeChunk(&chunk, 4, 1); // OP_POP

    // 15: OP_CONSTANT (2 bytes)
    chunk_h.writeChunk(&chunk, 0, 1); // OP_CONSTANT
    chunk_h.writeChunk(&chunk, 7, 1); // constant index 7

    // 17: OP_RETURN (1 byte)
    chunk_h.writeChunk(&chunk, 38, 1); // OP_RETURN

    // Scan for jumps
    const jumps = try scanJumps(&chunk, allocator);
    defer allocator.free(jumps);

    // Should find exactly 2 jumps
    try testing.expectEqual(@as(usize, 2), jumps.len);

    // First jump: OP_JUMP at offset 5
    try testing.expectEqual(@as(OpCode, OpCode.OP_JUMP), jumps[0].opcode);
    try testing.expectEqual(@as(usize, 5), jumps[0].location);
    try testing.expectEqual(@as(usize, 6), jumps[0].operand_offset);
    try testing.expect(jumps[0].is_forward);

    // Second jump: OP_LOOP at offset 11 (backward jump)
    try testing.expectEqual(@as(OpCode, OpCode.OP_LOOP), jumps[1].opcode);
    try testing.expectEqual(@as(usize, 11), jumps[1].location);
    try testing.expectEqual(@as(usize, 12), jumps[1].operand_offset);
    try testing.expect(!jumps[1].is_forward); // negative offset means backward jump
}
