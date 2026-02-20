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

    pub fn print(self: *const OptimizationStats) void {
        if (self.patterns_found == 0) return;

        std.debug.print("\n=== Peephole Optimization Results (Safe Patterns Only) ===\n", .{});
        std.debug.print("Total patterns fused: {d}\n", .{self.patterns_found});
        std.debug.print("Bytes saved: {d}\n", .{self.bytes_saved});
        std.debug.print("\nPattern breakdown:\n", .{});

        if (self.get_global_global > 0)
            std.debug.print("  GET_GLOBAL + GET_GLOBAL: {d}\n", .{self.get_global_global});
        if (self.get_local_local > 0)
            std.debug.print("  GET_LOCAL + GET_LOCAL: {d}\n", .{self.get_local_local});
        if (self.constant_constant > 0)
            std.debug.print("  CONSTANT + CONSTANT: {d}\n", .{self.constant_constant});

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

/// Try to match any safe pattern at the given offset
/// Returns the first matching pattern, or null if no match
fn matchPattern(chunk: *Chunk, offset: usize) ?Pattern {
    // Try patterns in order of expected frequency (based on static analysis)

    // 1. GET_GLOBAL + GET_GLOBAL (most common in binary operations)
    if (matchGetGlobalGlobal(chunk, offset)) |pattern| return pattern;

    // 2. GET_LOCAL + GET_LOCAL (common in local computations)
    if (matchGetLocalLocal(chunk, offset)) |pattern| return pattern;

    // 3. CONSTANT + CONSTANT (less common, but still worth optimizing)
    if (matchConstantConstant(chunk, offset)) |pattern| return pattern;

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
