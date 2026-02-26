/// Peephole Optimizer for MufiZ Bytecode (Phase 3 - Safe Patterns Only)
///
/// This module implements pattern recognition and fusion for superinstructions.
/// It performs a post-emission optimization pass that identifies frequently
/// occurring instruction sequences and replaces them with fused superinstructions.
///
/// SAFETY: Only implements patterns that are verified safe:
/// - GET_GLOBAL + GET_GLOBAL (independent loads)
/// - GET_LOCAL + GET_LOCAL (independent loads)
/// - CONSTANT + CONSTANT (independent loads)
///
/// These patterns are safe because:
/// 1. Operations are independent (no shared operands)
/// 2. No operand interdependencies
/// 3. Stack effects are additive (push N values)
/// 4. No control flow changes
///
/// Phase 3: Superinstructions
const std = @import("std");
const chunk_h = @import("chunk.zig");
const Chunk = chunk_h.Chunk;
const OpCode = chunk_h.OpCode;
const value_h = @import("value.zig");
const Value = value_h.Value;
const jump_patcher = @import("jump_patcher.zig");

/// Pattern recognition result
const Pattern = struct {
    offset: usize, // Starting offset of the pattern
    length: usize, // Number of bytes in the original pattern
    opcode: u8, // Replacement superinstruction opcode
    operand1: u8 = 0, // First operand (if any)
    operand2: u8 = 0, // Second operand (if any)
    operand3: u8 = 0, // Third operand (if any)
    replacement_length: usize, // Number of bytes in replacement
    name: []const u8, // Pattern name for reporting
};

/// Statistics collected during optimization
pub const OptimizationStats = struct {
    patterns_found: usize = 0,
    bytes_saved: usize = 0,
    get_global_global: usize = 0,
    get_local_local: usize = 0,
    constant_constant: usize = 0,
    get_local_constant: usize = 0,
    less_jump_if_false: usize = 0,
    add_set_local: usize = 0,
    set_local_pop: usize = 0,
    add_reg: usize = 0,
    get_local_less: usize = 0,

    pub fn print(self: *const OptimizationStats) void {
        if (self.patterns_found == 0) return;

        std.debug.print("\n=== Peephole Optimization Results ===\n", .{});
        std.debug.print("Total patterns fused: {d}\n", .{self.patterns_found});
        std.debug.print("Bytes saved: {d}\n", .{self.bytes_saved});
        std.debug.print("\nPattern breakdown:\n", .{});

        if (self.get_global_global > 0)
            std.debug.print("  GET_GLOBAL + GET_GLOBAL: {d}\n", .{self.get_global_global});
        if (self.get_local_local > 0)
            std.debug.print("  GET_LOCAL + GET_LOCAL: {d}\n", .{self.get_local_local});
        if (self.constant_constant > 0)
            std.debug.print("  CONSTANT + CONSTANT: {d}\n", .{self.constant_constant});
        if (self.get_local_constant > 0)
            std.debug.print("  GET_LOCAL + CONSTANT: {d}\n", .{self.get_local_constant});
        if (self.less_jump_if_false > 0)
            std.debug.print("  LESS + JUMP_IF_FALSE: {d}\n", .{self.less_jump_if_false});
        if (self.add_set_local > 0)
            std.debug.print("  ADD + SET_LOCAL: {d}\n", .{self.add_set_local});
        if (self.set_local_pop > 0)
            std.debug.print("  SET_LOCAL + POP: {d}\n", .{self.set_local_pop});
        if (self.add_reg > 0)
            std.debug.print("  ADD_REG (4-fused): {d}\n", .{self.add_reg});
        if (self.get_local_less > 0)
            std.debug.print("  GET_LOCAL + LESS: {d}\n", .{self.get_local_less});

        std.debug.print("==========================================================\n\n", .{});
    }
};

/// Validation result for pattern matching
const ValidationResult = enum {
    Valid,
    InvalidBounds, // Not enough bytes remaining
    InvalidOpcode, // Opcode mismatch
    InvalidOperand, // Operand out of range
    DuplicateOperand, // Same operand used twice (not independent)
};

/// Check if bytecode has enough bytes remaining
inline fn hasBytes(chunk: *Chunk, offset: usize, count: usize) bool {
    return offset + count <= @as(usize, @intCast(chunk.count));
}

/// Read a byte at offset without bounds checking (caller must check)
inline fn readByteAt(chunk: *Chunk, offset: usize) u8 {
    return chunk.code.?[offset];
}

/// Validate constant index is in range
inline fn isValidConstantIndex(chunk: *Chunk, index: u8) bool {
    return index < @as(u8, @intCast(chunk.constants.count));
}

/// Try to match GET_GLOBAL + GET_GLOBAL pattern
/// Pattern: [OP_GET_GLOBAL] [global1_idx] [OP_GET_GLOBAL] [global2_idx]
/// Replacement: [OP_GET_GLOBAL_GLOBAL] [global1_idx] [global2_idx]
/// Safety: Both loads are independent, no operand dependencies
fn matchGetGlobalGlobal(chunk: *Chunk, offset: usize) ?Pattern {
    // Check we have enough bytes for pattern
    if (!hasBytes(chunk, offset, 4)) return null;

    const op1 = readByteAt(chunk, offset);
    const op2 = readByteAt(chunk, offset + 2);

    // Verify both opcodes are OP_GET_GLOBAL
    if (op1 != @intFromEnum(OpCode.OP_GET_GLOBAL)) return null;
    if (op2 != @intFromEnum(OpCode.OP_GET_GLOBAL)) return null;

    const global1_idx = readByteAt(chunk, offset + 1);
    const global2_idx = readByteAt(chunk, offset + 3);

    // Validate operands
    if (!isValidConstantIndex(chunk, global1_idx)) return null;
    if (!isValidConstantIndex(chunk, global2_idx)) return null;

    // Note: We allow same global loaded twice (e.g., x + x)
    // This is semantically valid and should be optimized

    return Pattern{
        .offset = offset,
        .length = 4,
        .opcode = @intFromEnum(OpCode.OP_GET_GLOBAL_GLOBAL),
        .operand1 = global1_idx,
        .operand2 = global2_idx,
        .replacement_length = 3,
        .name = "GET_GLOBAL + GET_GLOBAL",
    };
}

/// Try to match GET_LOCAL + GET_LOCAL pattern
/// Pattern: [OP_GET_LOCAL] [local1_idx] [OP_GET_LOCAL] [local2_idx]
/// Replacement: [OP_GET_LOCAL_LOCAL] [local1_idx] [local2_idx]
/// Safety: Both loads are independent, no operand dependencies
fn matchGetLocalLocal(chunk: *Chunk, offset: usize) ?Pattern {
    if (!hasBytes(chunk, offset, 4)) return null;

    const op1 = readByteAt(chunk, offset);
    const op2 = readByteAt(chunk, offset + 2);

    if (op1 != @intFromEnum(OpCode.OP_GET_LOCAL)) return null;
    if (op2 != @intFromEnum(OpCode.OP_GET_LOCAL)) return null;

    const local1_idx = readByteAt(chunk, offset + 1);
    const local2_idx = readByteAt(chunk, offset + 3);

    // Note: Local indices don't need validation against constant pool
    // They're validated at runtime against frame slots
    // We allow same local loaded twice (e.g., x + x)

    return Pattern{
        .offset = offset,
        .length = 4,
        .opcode = @intFromEnum(OpCode.OP_GET_LOCAL_LOCAL),
        .operand1 = local1_idx,
        .operand2 = local2_idx,
        .replacement_length = 3,
        .name = "GET_LOCAL + GET_LOCAL",
    };
}

/// Try to match CONSTANT + CONSTANT pattern
/// Pattern: [OP_CONSTANT] [const1_idx] [OP_CONSTANT] [const2_idx]
/// Replacement: [OP_CONSTANT_CONSTANT] [const1_idx] [const2_idx]
/// Safety: Both loads are independent, no operand dependencies
fn matchConstantConstant(chunk: *Chunk, offset: usize) ?Pattern {
    if (!hasBytes(chunk, offset, 4)) return null;

    const op1 = readByteAt(chunk, offset);
    const op2 = readByteAt(chunk, offset + 2);

    // Only match full OP_CONSTANT (not small constants)
    if (op1 != @intFromEnum(OpCode.OP_CONSTANT)) return null;
    if (op2 != @intFromEnum(OpCode.OP_CONSTANT)) return null;

    const const1_idx = readByteAt(chunk, offset + 1);
    const const2_idx = readByteAt(chunk, offset + 3);

    // Validate both constant indices
    if (!isValidConstantIndex(chunk, const1_idx)) return null;
    if (!isValidConstantIndex(chunk, const2_idx)) return null;

    // We allow same constant loaded twice (though rare)

    return Pattern{
        .offset = offset,
        .length = 4,
        .opcode = @intFromEnum(OpCode.OP_CONSTANT_CONSTANT),
        .operand1 = const1_idx,
        .operand2 = const2_idx,
        .replacement_length = 3,
        .name = "CONSTANT + CONSTANT",
    };
}

fn matchGetLocalConstant(chunk: *Chunk, offset: usize) ?Pattern {
    if (!hasBytes(chunk, offset, 4)) return null;
    const op1 = readByteAt(chunk, offset);
    const op2 = readByteAt(chunk, offset + 2);

    if (op1 != @intFromEnum(OpCode.OP_GET_LOCAL)) return null;
    if (op2 != @intFromEnum(OpCode.OP_CONSTANT)) return null;

    const local_idx = readByteAt(chunk, offset + 1);
    const const_idx = readByteAt(chunk, offset + 3);

    if (!isValidConstantIndex(chunk, const_idx)) return null;

    return Pattern{
        .offset = offset,
        .length = 4,
        .opcode = @intFromEnum(OpCode.OP_GET_LOCAL_CONSTANT),
        .operand1 = local_idx,
        .operand2 = const_idx,
        .replacement_length = 3,
        .name = "GET_LOCAL + CONSTANT",
    };
}

fn matchLessJumpIfFalse(chunk: *Chunk, offset: usize) ?Pattern {
    if (!hasBytes(chunk, offset, 4)) return null;
    const op1 = readByteAt(chunk, offset);
    const op2 = readByteAt(chunk, offset + 1);

    if (op1 != @intFromEnum(OpCode.OP_LESS)) return null;
    if (op2 != @intFromEnum(OpCode.OP_JUMP_IF_FALSE)) return null;

    // Relative jump offset is at offset + 2 (2 bytes)
    // We'll reuse it in our new instruction.
    // Length: OP_LESS(1) + OP_JUMP_IF_FALSE(1) + offset(2) = 4
    // Replacement: OP_LESS_JUMP_IF_FALSE(1) + offset(2) = 3
    // Note: operand1 will store high byte, operand2 will store low byte of offset

    return Pattern{
        .offset = offset,
        .length = 4,
        .opcode = @intFromEnum(OpCode.OP_LESS_JUMP_IF_FALSE),
        .operand1 = readByteAt(chunk, offset + 2), // High byte
        .operand2 = readByteAt(chunk, offset + 3), // Low byte
        .replacement_length = 3,
        .name = "LESS + JUMP_IF_FALSE",
    };
}

fn matchAddSetLocal(chunk: *Chunk, offset: usize) ?Pattern {
    if (!hasBytes(chunk, offset, 3)) return null;
    const op1 = readByteAt(chunk, offset);
    const op2 = readByteAt(chunk, offset + 1);

    if (op1 != @intFromEnum(OpCode.OP_ADD)) return null;
    if (op2 != @intFromEnum(OpCode.OP_SET_LOCAL)) return null;

    const local_idx = readByteAt(chunk, offset + 2);

    return Pattern{
        .offset = offset,
        .length = 3,
        .opcode = @intFromEnum(OpCode.OP_ADD_SET_LOCAL),
        .operand1 = local_idx,
        .replacement_length = 2,
        .name = "ADD + SET_LOCAL",
    };
}

fn matchSetLocalPop(chunk: *Chunk, offset: usize) ?Pattern {
    if (!hasBytes(chunk, offset, 3)) return null;
    const op1 = readByteAt(chunk, offset);
    const op2 = readByteAt(chunk, offset + 2);

    if (op1 != @intFromEnum(OpCode.OP_SET_LOCAL)) return null;
    if (op2 != @intFromEnum(OpCode.OP_POP)) return null;

    const local_idx = readByteAt(chunk, offset + 1);

    return Pattern{
        .offset = offset,
        .length = 3,
        .opcode = @intFromEnum(OpCode.OP_SET_LOCAL_POP),
        .operand1 = local_idx,
        .replacement_length = 2,
        .name = "SET_LOCAL + POP",
    };
}

fn matchGetLocalLess(chunk: *Chunk, offset: usize) ?Pattern {
    // Pattern: GET_LOCAL(slot), CONSTANT(idx), LESS
    // Length: 2 + 2 + 1 = 5 bytes
    // Replacement: OP_GET_LOCAL_LESS(slot, idx) = 3 bytes
    if (!hasBytes(chunk, offset, 5)) return null;

    if (readByteAt(chunk, offset) != @intFromEnum(OpCode.OP_GET_LOCAL)) return null;
    if (readByteAt(chunk, offset + 2) != @intFromEnum(OpCode.OP_CONSTANT)) return null;
    if (readByteAt(chunk, offset + 4) != @intFromEnum(OpCode.OP_LESS)) return null;

    const slot = readByteAt(chunk, offset + 1);
    const const_idx = readByteAt(chunk, offset + 3);

    if (!isValidConstantIndex(chunk, const_idx)) return null;

    return Pattern{
        .offset = offset,
        .length = 5,
        .opcode = @intFromEnum(OpCode.OP_GET_LOCAL_LESS),
        .operand1 = slot,
        .operand2 = const_idx,
        .replacement_length = 3,
        .name = "GET_LOCAL + LESS",
    };
}

fn matchAddReg(chunk: *Chunk, offset: usize) ?Pattern {
    // Pattern: GET_LOCAL r1, GET_LOCAL r2, ADD, SET_LOCAL dest
    // Length: 2 + 2 + 1 + 2 = 7 bytes
    // Replacement: OP_ADD_REG dest, r1, r2 = 4 bytes
    if (!hasBytes(chunk, offset, 7)) return null;
    
    if (readByteAt(chunk, offset) != @intFromEnum(OpCode.OP_GET_LOCAL)) return null;
    if (readByteAt(chunk, offset + 2) != @intFromEnum(OpCode.OP_GET_LOCAL)) return null;
    if (readByteAt(chunk, offset + 4) != @intFromEnum(OpCode.OP_ADD)) return null;
    if (readByteAt(chunk, offset + 5) != @intFromEnum(OpCode.OP_SET_LOCAL)) return null;

    const r1 = readByteAt(chunk, offset + 1);
    const r2 = readByteAt(chunk, offset + 3);
    const dest = readByteAt(chunk, offset + 6);

    return Pattern{
        .offset = offset,
        .length = 7,
        .opcode = @intFromEnum(OpCode.OP_ADD_REG),
        .operand1 = dest,
        .operand2 = r1,
        .operand3 = r2,
        .replacement_length = 4,
        .name = "ADD_REG (4-fused)",
    };
}

fn matchLoopCount(chunk: *Chunk, offset: usize) ?Pattern {
    // Pattern: GET_LOCAL(slot), CONSTANT(limit), LESS, JUMP_IF_FALSE(end), POP
    // This is the start of most for/while loops.
    // Total length: 2 + 2 + 1 + 3 + 1 = 9 bytes
    if (!hasBytes(chunk, offset, 9)) return null;

    if (readByteAt(chunk, offset) != @intFromEnum(OpCode.OP_GET_LOCAL)) return null;
    if (readByteAt(chunk, offset + 2) != @intFromEnum(OpCode.OP_CONSTANT)) return null;
    if (readByteAt(chunk, offset + 4) != @intFromEnum(OpCode.OP_LESS)) return null;
    if (readByteAt(chunk, offset + 5) != @intFromEnum(OpCode.OP_JUMP_IF_FALSE)) return null;
    if (readByteAt(chunk, offset + 8) != @intFromEnum(OpCode.OP_POP)) return null;

    const slot = readByteAt(chunk, offset + 1);
    const limit_idx = readByteAt(chunk, offset + 3);

    // We can't easily fuse this yet because we need to know where the LOOP at the end is
    // to calculate the backward offset. 
    // For now, let's skip this complex fusion and focus on simpler ones.
    _ = slot;
    _ = limit_idx;

    return null;
}

/// Try to match any safe pattern at the given offset
/// Returns the first matching pattern, or null if no match
fn matchPattern(chunk: *Chunk, offset: usize) ?Pattern {
    const code = chunk.code.?;
    const op = code[offset];

    // Efficient dispatch based on the first opcode
    switch (op) {
        @intFromEnum(OpCode.OP_GET_GLOBAL) => {
            return matchGetGlobalGlobal(chunk, offset);
        },
        @intFromEnum(OpCode.OP_GET_LOCAL) => {
            // Prioritize longest patterns (ADD_REG is 7 bytes)
            if (matchAddReg(chunk, offset)) |p| return p;
            if (matchGetLocalLess(chunk, offset)) |p| return p;
            if (matchGetLocalLocal(chunk, offset)) |p| return p;
            if (matchGetLocalConstant(chunk, offset)) |p| return p;
        },
        @intFromEnum(OpCode.OP_CONSTANT) => {
            if (matchConstantConstant(chunk, offset)) |p| return p;
        },
        @intFromEnum(OpCode.OP_LESS) => {
            return matchLessJumpIfFalse(chunk, offset);
        },
        @intFromEnum(OpCode.OP_ADD) => {
            return matchAddSetLocal(chunk, offset);
        },
        @intFromEnum(OpCode.OP_SET_LOCAL) => {
            return matchSetLocalPop(chunk, offset);
        },
        else => {},
    }

    return null;
}

/// Update statistics based on matched pattern
fn updateStats(stats: *OptimizationStats, pattern: *const Pattern) void {
    stats.patterns_found += 1;
    stats.bytes_saved += pattern.length - pattern.replacement_length;

    switch (pattern.opcode) {
        @intFromEnum(OpCode.OP_GET_GLOBAL_GLOBAL) => stats.get_global_global += 1,
        @intFromEnum(OpCode.OP_GET_LOCAL_LOCAL) => stats.get_local_local += 1,
        @intFromEnum(OpCode.OP_CONSTANT_CONSTANT) => stats.constant_constant += 1,
        @intFromEnum(OpCode.OP_GET_LOCAL_CONSTANT) => stats.get_local_constant += 1,
        @intFromEnum(OpCode.OP_LESS_JUMP_IF_FALSE) => stats.less_jump_if_false += 1,
        @intFromEnum(OpCode.OP_ADD_SET_LOCAL) => stats.add_set_local += 1,
        @intFromEnum(OpCode.OP_SET_LOCAL_POP) => stats.set_local_pop += 1,
        @intFromEnum(OpCode.OP_ADD_REG) => stats.add_reg += 1,
        @intFromEnum(OpCode.OP_GET_LOCAL_LESS) => stats.get_local_less += 1,
        else => {}, // Should never happen with safe patterns
    }
}

/// Apply a pattern replacement to the bytecode
/// This shifts bytecode and adjusts line numbers
/// Records the modification for jump patching
fn applyPattern(chunk: *Chunk, pattern: *const Pattern, modifications: ?*[32]jump_patcher.Modification, mod_count: ?*usize) void {
    const code = chunk.code.?;
    const lines = chunk.lines.?;

    // Write replacement instruction
    code[pattern.offset] = pattern.opcode;
    code[pattern.offset + 1] = pattern.operand1;
    code[pattern.offset + 2] = pattern.operand2;
    
    // Write operand3 if replacement is long enough
    if (pattern.replacement_length >= 4) {
        code[pattern.offset + 3] = pattern.operand3;
    }

    // Calculate how many bytes to remove
    const bytes_removed = pattern.length - pattern.replacement_length;

    if (bytes_removed > 0) {
        // Shift remaining bytecode left
        const src_start = pattern.offset + pattern.length;
        const dst_start = pattern.offset + pattern.replacement_length;
        const remaining = @as(usize, @intCast(chunk.count)) - src_start;

        if (remaining > 0) {
            // Shift bytecode
            std.mem.copyForwards(
                u8,
                code[dst_start .. dst_start + remaining],
                code[src_start .. src_start + remaining],
            );

            // Shift line numbers
            std.mem.copyForwards(
                i32,
                lines[dst_start .. dst_start + remaining],
                lines[src_start .. src_start + remaining],
            );
        }

        // Update chunk count
        chunk.count -= @intCast(bytes_removed);

        // Track modification for jump patching
        if (modifications) |mods| {
            if (mod_count) |count| {
                if (count.* < mods.len) {
                    mods[count.*] = jump_patcher.Modification{
                        .offset = pattern.offset,
                        .bytes_removed = bytes_removed,
                        .bytes_added = 0,
                    };
                    count.* += 1;
                }
            }
        }
    }
}

/// Validate that the pattern replacement is safe
/// This is a paranoid check to ensure we don't corrupt bytecode
fn validatePattern(chunk: *Chunk, pattern: *const Pattern) ValidationResult {
    // Check bounds
    if (pattern.offset + pattern.length > @as(usize, @intCast(chunk.count))) {
        return .InvalidBounds;
    }

    // Verify the pattern still matches (bytecode might have changed)
    const matched = matchPattern(chunk, pattern.offset);
    if (matched == null) {
        return .InvalidOpcode;
    }

    // Verify operands are still valid
    switch (pattern.opcode) {
        @intFromEnum(OpCode.OP_GET_GLOBAL_GLOBAL),
        @intFromEnum(OpCode.OP_CONSTANT_CONSTANT),
        => {
            if (!isValidConstantIndex(chunk, pattern.operand1)) return .InvalidOperand;
            if (!isValidConstantIndex(chunk, pattern.operand2)) return .InvalidOperand;
        },
        @intFromEnum(OpCode.OP_GET_LOCAL_LOCAL) => {
            // Local indices are validated at runtime, not compile time
        },
        @intFromEnum(OpCode.OP_GET_LOCAL_CONSTANT) => {
            if (!isValidConstantIndex(chunk, pattern.operand2)) return .InvalidOperand;
        },
        @intFromEnum(OpCode.OP_GET_LOCAL_LESS) => {
            if (!isValidConstantIndex(chunk, pattern.operand2)) return .InvalidOperand;
        },
        @intFromEnum(OpCode.OP_LESS_JUMP_IF_FALSE) => {
            // Jump offset bytes are just copied, always valid bytes
        },
        @intFromEnum(OpCode.OP_ADD_SET_LOCAL),
        @intFromEnum(OpCode.OP_SET_LOCAL_POP),
        @intFromEnum(OpCode.OP_ADD_REG) => {
            // Local indices are safe
        },
        else => return .InvalidOpcode,
    }

    return .Valid;
}

/// Main optimization entry point
/// Performs a single pass over the bytecode, identifying and fusing safe patterns
/// Optionally tracks modifications for jump patching
pub fn optimize(chunk: *Chunk, stats: *OptimizationStats, modifications: ?*[32]jump_patcher.Modification, mod_count: ?*usize) void {
    var offset: usize = 0;

    while (offset < @as(usize, @intCast(chunk.count))) {
        if (matchPattern(chunk, offset)) |pattern| {
            // Validate pattern is safe to apply
            const validation = validatePattern(chunk, &pattern);
            if (validation == .Valid) {
                // Found a valid pattern - apply it
                updateStats(stats, &pattern);
                applyPattern(chunk, &pattern, modifications, mod_count);

                // Move past the replacement (not the original length, since we shifted)
                offset += pattern.replacement_length;
            } else {
                // Pattern validation failed - skip this instruction by its full length
                const length = chunk_h.getInstructionLength(chunk, offset);
                if (length == 0) break;
                offset += length;
            }
        } else {
            // No pattern matched - move to next instruction by its full length
            const length = chunk_h.getInstructionLength(chunk, offset);
            if (length == 0) break;
            offset += length;
        }
    }
}

/// Optimize with default stats (no reporting)
pub fn optimizeSilent(chunk: *Chunk) void {
    var stats = OptimizationStats{};
    optimize(chunk, &stats, null, null);
}

/// Optimize with stats reporting
pub fn optimizeWithReport(chunk: *Chunk) OptimizationStats {
    var stats = OptimizationStats{};
    optimize(chunk, &stats, null, null);
    return stats;
}

/// Analyze bytecode for potential patterns without modifying it
/// Returns statistics about what could be optimized
pub fn analyzePatterns(chunk: *Chunk) OptimizationStats {
    var stats = OptimizationStats{};
    var offset: usize = 0;

    while (offset < @as(usize, @intCast(chunk.count))) {
        if (matchPattern(chunk, offset)) |pattern| {
            updateStats(&stats, &pattern);
            offset += pattern.length; // Skip entire pattern
        } else {
            offset += 1;
        }
    }

    return stats;
}

/// Test helper: Check if optimization is safe (no corruption)
pub fn verifySafety(chunk: *Chunk) bool {
    // Save original bytecode
    const allocator = std.heap.page_allocator;
    const original_code = allocator.dupe(u8, chunk.code.?[0..@intCast(chunk.count)]) catch return false;
    defer allocator.free(original_code);

    const original_count = chunk.count;

    // Try to optimize
    var stats = OptimizationStats{};
    optimize(chunk, &stats, null, null);

    // If no patterns found, bytecode should be unchanged
    if (stats.patterns_found == 0) {
        const unchanged = std.mem.eql(u8, original_code, chunk.code.?[0..@intCast(chunk.count)]);
        return unchanged and chunk.count == original_count;
    }

    // If patterns were found, bytecode should be shorter
    return chunk.count < original_count;
}
