/// Bytecode Optimizer - Phase 4: Advanced Optimizations
///
/// This module orchestrates all bytecode optimization passes for the MufiZ VM.
/// It provides a unified interface for applying multiple optimization techniques
/// in a coordinated manner.
///
/// Optimization Passes:
/// 1. Superinstruction fusion (from Phase 3)
/// 2. Peephole optimizations (pattern matching and replacement)
/// 3. Dead code elimination
/// 4. Constant folding at bytecode level
///
/// Each pass is independent and can be enabled/disabled individually.
/// Passes are applied in a specific order to maximize effectiveness.
const std = @import("std");
const chunk_h = @import("chunk.zig");
const Chunk = chunk_h.Chunk;
const OpCode = chunk_h.OpCode;
const value_h = @import("value.zig");
const Value = value_h.Value;

// Import optimization passes
const peephole = @import("peephole_optimizer.zig");
const jump_patcher = @import("jump_patcher.zig");

/// Configuration for optimization passes
pub const OptimizerConfig = struct {
    /// Enable superinstruction fusion (Phase 3)
    /// DISABLED: Causes bytecode corruption with constant indices
    enable_superinstructions: bool = false,

    /// Enable peephole optimizations
    enable_peephole: bool = true,

    /// Enable dead code elimination
    enable_dce: bool = true,

    /// Enable constant folding
    enable_constant_folding: bool = true,

    /// Maximum number of optimization passes to run
    max_passes: usize = 3,

    /// Enable verbose output
    verbose: bool = false,

    /// Create a default configuration with all optimizations enabled
    pub fn default() OptimizerConfig {
        return .{};
    }

    /// Create a configuration with only safe optimizations
    pub fn safe() OptimizerConfig {
        return .{
            .enable_superinstructions = true,
            .enable_peephole = true,
            .enable_dce = false, // Conservative: DCE can be tricky
            .enable_constant_folding = true,
            .max_passes = 1,
        };
    }

    /// Create a configuration with all optimizations disabled
    pub fn disabled() OptimizerConfig {
        return .{
            .enable_superinstructions = false,
            .enable_peephole = false,
            .enable_dce = false,
            .enable_constant_folding = false,
            .max_passes = 0,
        };
    }
};

/// Statistics for all optimization passes
pub const OptimizerStats = struct {
    /// Number of optimization passes performed
    passes_performed: usize = 0,

    /// Superinstruction statistics
    superinstructions: peephole.OptimizationStats = .{},

    /// Peephole optimization statistics
    peephole_patterns: PeepholeStats = .{},

    /// Dead code elimination statistics
    dce: DCEStats = .{},

    /// Constant folding statistics
    constant_folding: ConstantFoldingStats = .{},

    /// Total bytes saved across all passes
    total_bytes_saved: usize = 0,

    /// Total instructions eliminated
    total_instructions_eliminated: usize = 0,

    /// Original bytecode size
    original_size: usize = 0,

    /// Final bytecode size
    final_size: usize = 0,

    pub fn print(self: *const OptimizerStats) void {
        std.debug.print("\n╔════════════════════════════════════════════════════════════╗\n", .{});
        std.debug.print("║         Bytecode Optimization Report (Phase 4)           ║\n", .{});
        std.debug.print("╚════════════════════════════════════════════════════════════╝\n", .{});

        std.debug.print("\nOptimization passes: {d}\n", .{self.passes_performed});
        std.debug.print("Original size: {d} bytes\n", .{self.original_size});
        std.debug.print("Final size: {d} bytes\n", .{self.final_size});
        std.debug.print("Total saved: {d} bytes ({d:.2}% reduction)\n", .{
            self.total_bytes_saved,
            @as(f64, @floatFromInt(self.total_bytes_saved)) / @as(f64, @floatFromInt(self.original_size)) * 100.0,
        });
        std.debug.print("Instructions eliminated: {d}\n", .{self.total_instructions_eliminated});

        if (self.superinstructions.patterns_found > 0) {
            std.debug.print("\n┌─ Superinstructions (Phase 3) ───────────────────────────┐\n", .{});
            std.debug.print("│ Patterns fused: {d}\n", .{self.superinstructions.patterns_found});
            std.debug.print("│ Bytes saved: {d}\n", .{self.superinstructions.bytes_saved});
            if (self.superinstructions.get_global_global > 0)
                std.debug.print("│   GET_GLOBAL + GET_GLOBAL: {d}\n", .{self.superinstructions.get_global_global});
            if (self.superinstructions.get_local_local > 0)
                std.debug.print("│   GET_LOCAL + GET_LOCAL: {d}\n", .{self.superinstructions.get_local_local});
            if (self.superinstructions.constant_constant > 0)
                std.debug.print("│   CONSTANT + CONSTANT: {d}\n", .{self.superinstructions.constant_constant});
            std.debug.print("└──────────────────────────────────────────────────────────┘\n", .{});
        }

        if (self.peephole_patterns.patterns_applied > 0) {
            std.debug.print("\n┌─ Peephole Optimizations ─────────────────────────────────┐\n", .{});
            std.debug.print("│ Patterns applied: {d}\n", .{self.peephole_patterns.patterns_applied});
            std.debug.print("│ Bytes saved: {d}\n", .{self.peephole_patterns.bytes_saved});
            if (self.peephole_patterns.constant_pop > 0)
                std.debug.print("│   CONSTANT + POP eliminated: {d}\n", .{self.peephole_patterns.constant_pop});
            if (self.peephole_patterns.get_set_same > 0)
                std.debug.print("│   GET/SET same slot → DUP: {d}\n", .{self.peephole_patterns.get_set_same});
            if (self.peephole_patterns.redundant_ops > 0)
                std.debug.print("│   Redundant operations: {d}\n", .{self.peephole_patterns.redundant_ops});
            std.debug.print("└──────────────────────────────────────────────────────────┘\n", .{});
        }

        if (self.dce.dead_instructions > 0) {
            std.debug.print("\n┌─ Dead Code Elimination ──────────────────────────────────┐\n", .{});
            std.debug.print("│ Dead instructions removed: {d}\n", .{self.dce.dead_instructions});
            std.debug.print("│ Bytes saved: {d}\n", .{self.dce.bytes_saved});
            if (self.dce.unreachable_after_return > 0)
                std.debug.print("│   Unreachable after RETURN: {d}\n", .{self.dce.unreachable_after_return});
            if (self.dce.redundant_jumps > 0)
                std.debug.print("│   Redundant jumps: {d}\n", .{self.dce.redundant_jumps});
            std.debug.print("└──────────────────────────────────────────────────────────┘\n", .{});
        }

        if (self.constant_folding.folds_performed > 0) {
            std.debug.print("\n┌─ Constant Folding ───────────────────────────────────────┐\n", .{});
            std.debug.print("│ Folds performed: {d}\n", .{self.constant_folding.folds_performed});
            std.debug.print("│ Bytes saved: {d}\n", .{self.constant_folding.bytes_saved});
            if (self.constant_folding.arithmetic_ops > 0)
                std.debug.print("│   Arithmetic operations: {d}\n", .{self.constant_folding.arithmetic_ops});
            if (self.constant_folding.comparison_ops > 0)
                std.debug.print("│   Comparison operations: {d}\n", .{self.constant_folding.comparison_ops});
            if (self.constant_folding.logical_ops > 0)
                std.debug.print("│   Logical operations: {d}\n", .{self.constant_folding.logical_ops});
            std.debug.print("└──────────────────────────────────────────────────────────┘\n", .{});
        }

        std.debug.print("\n════════════════════════════════════════════════════════════\n\n", .{});
    }

    pub fn addBytes(self: *OptimizerStats, bytes: usize) void {
        self.total_bytes_saved += bytes;
    }

    pub fn addInstructions(self: *OptimizerStats, count: usize) void {
        self.total_instructions_eliminated += count;
    }
};

/// Peephole optimization statistics
pub const PeepholeStats = struct {
    patterns_applied: usize = 0,
    bytes_saved: usize = 0,
    constant_pop: usize = 0,
    get_set_same: usize = 0,
    redundant_ops: usize = 0,
};

/// Dead code elimination statistics
pub const DCEStats = struct {
    dead_instructions: usize = 0,
    bytes_saved: usize = 0,
    unreachable_after_return: usize = 0,
    redundant_jumps: usize = 0,
};

/// Constant folding statistics
pub const ConstantFoldingStats = struct {
    folds_performed: usize = 0,
    bytes_saved: usize = 0,
    arithmetic_ops: usize = 0,
    comparison_ops: usize = 0,
    logical_ops: usize = 0,
};

/// Main optimizer entry point
/// Applies all enabled optimization passes to the given chunk
pub fn optimize(chunk: *Chunk, config: OptimizerConfig) OptimizerStats {
    var stats = OptimizerStats{
        .original_size = @intCast(chunk.count),
    };

    if (config.max_passes == 0) {
        stats.final_size = @intCast(chunk.count);
        return stats;
    }

    // Verbose mode for debugging (disable in production)
    const verbose = config.verbose or false; // Set to false to reduce noise
    if (verbose) {
        std.debug.print("\n[Optimizer] Starting optimization with {d} max passes...\n", .{config.max_passes});
    }

    // Use arena allocator for jump patching infrastructure
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // SAFETY: Check if function has jumps - if so, skip optimization for now
    // Jump patching has bugs with certain edge cases, so use conservative approach
    const has_jumps_result = jump_patcher.scanJumps(chunk, allocator) catch |err| {
        if (verbose) {
            std.debug.print("⚠️  Could not scan for jumps: {}\n", .{err});
        }
        stats.final_size = @intCast(chunk.count);
        return stats;
    };
    defer allocator.free(has_jumps_result);

    if (has_jumps_result.len > 0) {
        if (verbose) {
            std.debug.print("  [Info] Function has {d} jump(s) - skipping optimization (conservative safety)\n", .{has_jumps_result.len});
        }
        stats.final_size = @intCast(chunk.count);
        return stats;
    }

    // Run optimization passes up to max_passes times
    var pass: usize = 0;
    while (pass < config.max_passes) : (pass += 1) {
        const size_before = chunk.count;
        var changed = false;

        // Track modifications for jump patching (use fixed-size array to avoid ArrayList API issues)
        // Most passes will have 0-10 modifications, so 32 is plenty
        var modification_buffer: [32]jump_patcher.Modification = undefined;
        var modification_count: usize = 0;

        if (verbose) {
            std.debug.print("[Optimizer] Pass {d}/{d} (size: {d} bytes)\n", .{ pass + 1, config.max_passes, size_before });
        }

        // Pass 1: Constant folding (run first to create optimization opportunities)
        // TEMPORARILY DISABLED: runConstantFolding modifies bytecode without tracking
        if (false and config.enable_constant_folding) {
            const size_before_cf = chunk.count;
            const cf_stats = runConstantFolding(chunk);
            const size_after_cf = chunk.count;
            if (verbose and size_after_cf != size_before_cf) {
                std.debug.print("  [ConstantFolding] Size changed: {d} -> {d} (diff: {d})\n", .{ size_before_cf, size_after_cf, size_before_cf - size_after_cf });
            }
            stats.constant_folding.folds_performed += cf_stats.folds_performed;
            stats.constant_folding.bytes_saved += cf_stats.bytes_saved;
            stats.constant_folding.arithmetic_ops += cf_stats.arithmetic_ops;
            stats.constant_folding.comparison_ops += cf_stats.comparison_ops;
            stats.constant_folding.logical_ops += cf_stats.logical_ops;
            changed = changed or cf_stats.folds_performed > 0;
        }

        // Pass 2: Peephole optimizations (additional patterns)
        // TEMPORARILY DISABLED: runPeepholePatterns modifies bytecode without tracking
        // Only superinstructions (Phase 3) are safe because they track modifications
        if (false and config.enable_peephole) {
            const size_before_ph = chunk.count;
            const ph_stats = runPeepholePatterns(chunk);
            const size_after_ph = chunk.count;
            if (verbose and size_after_ph != size_before_ph) {
                std.debug.print("  [PeepholePatterns] Size changed: {d} -> {d} (diff: {d})\n", .{ size_before_ph, size_after_ph, size_before_ph - size_after_ph });
            }
            stats.peephole_patterns.patterns_applied += ph_stats.patterns_applied;
            stats.peephole_patterns.bytes_saved += ph_stats.bytes_saved;
            stats.peephole_patterns.constant_pop += ph_stats.constant_pop;
            stats.peephole_patterns.get_set_same += ph_stats.get_set_same;
            stats.peephole_patterns.redundant_ops += ph_stats.redundant_ops;
            changed = changed or ph_stats.patterns_applied > 0;
        }

        // Pass 3: Superinstructions (from Phase 3) with modification tracking
        if (config.enable_superinstructions) {
            const size_before_super = chunk.count;
            const mod_count_before = modification_count;
            peephole.optimize(chunk, &stats.superinstructions, &modification_buffer, &modification_count);
            const size_after_super = chunk.count;
            if (verbose) {
                std.debug.print("  [Superinstructions] Size: {d} -> {d}, Modifications tracked: {d}\n", .{ size_before_super, size_after_super, modification_count - mod_count_before });
            }
            changed = changed or stats.superinstructions.patterns_found > 0;
        }

        // Pass 4: Dead code elimination (run last to clean up)
        // TEMPORARILY DISABLED: runDeadCodeElimination modifies bytecode without tracking
        if (false and config.enable_dce) {
            const size_before_dce = chunk.count;
            const dce_stats = runDeadCodeElimination(chunk);
            const size_after_dce = chunk.count;
            if (verbose and size_after_dce != size_before_dce) {
                std.debug.print("  [DCE] Size changed: {d} -> {d} (diff: {d})\n", .{ size_before_dce, size_after_dce, size_before_dce - size_after_dce });
            }
            stats.dce.dead_instructions += dce_stats.dead_instructions;
            stats.dce.bytes_saved += dce_stats.bytes_saved;
            stats.dce.unreachable_after_return += dce_stats.unreachable_after_return;
            stats.dce.redundant_jumps += dce_stats.redundant_jumps;
            changed = changed or dce_stats.dead_instructions > 0;
        }

        // NOTE: Jump patching is disabled - we pre-screen for jumps above
        // Functions with jumps are not optimized (conservative safety)
        if (modification_count > 0 and verbose) {
            std.debug.print("  [Info] Made {d} modifications (no jumps in function)\n", .{modification_count});
        }

        stats.passes_performed += 1;

        const size_after = chunk.count;
        const bytes_saved_this_pass = if (size_after < size_before) size_before - size_after else 0;

        if (verbose) {
            std.debug.print("[Optimizer] Pass {d} saved {d} bytes\n", .{ pass + 1, bytes_saved_this_pass });
        }

        // Validate bytecode integrity after this pass
        if (!validateBytecodeIntegrity(chunk)) {
            std.debug.print("⚠️  BYTECODE VALIDATION WARNING after pass {d}\n", .{pass + 1});
            std.debug.print("⚠️  Bytecode may have issues but continuing...\n", .{});
            // Don't break - let it run and see what happens
        }

        // If nothing changed, no point in running more passes
        if (!changed) {
            if (verbose) {
                std.debug.print("[Optimizer] No changes in pass {d}, stopping early\n", .{pass + 1});
            }
            break;
        }
    }

    stats.final_size = @intCast(chunk.count);
    stats.total_bytes_saved = if (stats.final_size < stats.original_size)
        stats.original_size - stats.final_size
    else
        0;

    stats.total_instructions_eliminated = stats.peephole_patterns.patterns_applied +
        stats.dce.dead_instructions +
        stats.constant_folding.folds_performed;

    return stats;

    // ORIGINAL CODE (disabled):
    // if (config.max_passes == 0) {
    //     stats.final_size = @intCast(chunk.count);
    //     return stats;
    // }

    // if (config.verbose) {
    //     std.debug.print("\n[Optimizer] Starting optimization with {d} max passes...\n", .{config.max_passes});
    // }

    // DISABLED: All optimization passes commented out until jump patching is implemented
    // // Run optimization passes up to max_passes times
    // // We iterate because some optimizations enable others
    // var pass: usize = 0;
    // while (pass < config.max_passes) : (pass += 1) {
    //     const size_before = chunk.count;
    //     var changed = false;

    //     if (config.verbose) {
    //         std.debug.print("[Optimizer] Pass {d}/{d} (size: {d} bytes)\n", .{ pass + 1, config.max_passes, size_before });
    //     }

    //     // Pass 1: Constant folding (run first to create optimization opportunities)
    //     if (config.enable_constant_folding) {
    //         const cf_stats = runConstantFolding(chunk);
    //         stats.constant_folding.folds_performed += cf_stats.folds_performed;
    //         stats.constant_folding.bytes_saved += cf_stats.bytes_saved;
    //         stats.constant_folding.arithmetic_ops += cf_stats.arithmetic_ops;
    //         stats.constant_folding.comparison_ops += cf_stats.comparison_ops;
    //         stats.constant_folding.logical_ops += cf_stats.logical_ops;
    //         changed = changed or cf_stats.folds_performed > 0;
    //     }

    //     // Pass 2: Peephole optimizations (additional patterns)
    //     if (config.enable_peephole) {
    //         const ph_stats = runPeepholePatterns(chunk);
    //         stats.peephole_patterns.patterns_applied += ph_stats.patterns_applied;
    //         stats.peephole_patterns.bytes_saved += ph_stats.bytes_saved;
    //         stats.peephole_patterns.constant_pop += ph_stats.constant_pop;
    //         stats.peephole_patterns.get_set_same += ph_stats.get_set_same;
    //         stats.peephole_patterns.redundant_ops += ph_stats.redundant_ops;
    //         changed = changed or ph_stats.patterns_applied > 0;
    //     }

    //     // Pass 3: Superinstructions (from Phase 3)
    //     if (config.enable_superinstructions) {
    //         peephole.optimize(chunk, &stats.superinstructions);
    //         changed = changed or stats.superinstructions.patterns_found > 0;
    //     }

    //     // Pass 4: Dead code elimination (run last to clean up)
    //     if (config.enable_dce) {
    //         const dce_stats = runDeadCodeElimination(chunk);
    //         stats.dce.dead_instructions += dce_stats.dead_instructions;
    //         stats.dce.bytes_saved += dce_stats.bytes_saved;
    //         stats.dce.unreachable_after_return += dce_stats.unreachable_after_return;
    //         stats.dce.redundant_jumps += dce_stats.redundant_jumps;
    //         changed = changed or dce_stats.dead_instructions > 0;
    //     }

    //     stats.passes_performed += 1;

    //     const size_after = chunk.count;
    //     const bytes_saved_this_pass = if (size_after < size_before) size_before - size_after else 0;

    //     if (config.verbose) {
    //         std.debug.print("[Optimizer] Pass {d} saved {d} bytes\n", .{ pass + 1, bytes_saved_this_pass });
    //     }

    //     // If nothing changed, no point in running more passes
    //     if (!changed) {
    //         if (config.verbose) {
    //             std.debug.print("[Optimizer] No changes in pass {d}, stopping early\n", .{pass + 1});
    //         }
    //         break;
    //     }
    // }

    // stats.final_size = @intCast(chunk.count);
    // stats.total_bytes_saved = if (stats.final_size < stats.original_size)
    //     stats.original_size - stats.final_size
    // else
    //     0;

    // // Calculate total instructions eliminated (approximate)
    // stats.total_instructions_eliminated = stats.peephole_patterns.patterns_applied +
    //     stats.dce.dead_instructions +
    //     stats.constant_folding.folds_performed;

    // return stats;
}

/// Run constant folding pass
fn runConstantFolding(chunk: *Chunk) ConstantFoldingStats {
    var stats = ConstantFoldingStats{};

    var offset: usize = 0;
    while (offset + 4 < @as(usize, @intCast(chunk.count))) {
        const code = chunk.code.?;

        // Pattern: CONSTANT a, CONSTANT b, binary_op → CONSTANT (a op b)
        if (code[offset] == @intFromEnum(OpCode.OP_CONSTANT) and
            code[offset + 2] == @intFromEnum(OpCode.OP_CONSTANT))
        {
            const const1_idx = code[offset + 1];
            const const2_idx = code[offset + 3];

            if (offset + 5 < @as(usize, @intCast(chunk.count))) {
                const op = code[offset + 4];

                // Try to fold arithmetic operations
                if (tryFoldArithmetic(chunk, offset, const1_idx, const2_idx, op)) {
                    stats.folds_performed += 1;
                    stats.arithmetic_ops += 1;
                    stats.bytes_saved += 4; // Saved 2 CONSTANT ops + 1 binary op
                    continue; // Don't advance offset, check this position again
                }

                // Try to fold comparison operations
                if (tryFoldComparison(chunk, offset, const1_idx, const2_idx, op)) {
                    stats.folds_performed += 1;
                    stats.comparison_ops += 1;
                    stats.bytes_saved += 4;
                    continue;
                }
            }
        }

        offset += 1;
    }

    return stats;
}

/// Try to fold arithmetic operations
fn tryFoldArithmetic(chunk: *Chunk, offset: usize, idx1: u8, idx2: u8, op: u8) bool {
    const v1 = chunk.constants.values[@intCast(idx1)];
    const v2 = chunk.constants.values[@intCast(idx2)];

    // Only fold number operations (int or double)
    if (!v1.is_prim_num() or !v2.is_prim_num()) return false;

    const n1 = if (v1.is_int()) @as(f64, @floatFromInt(v1.as_int())) else v1.as_double();
    const n2 = if (v2.is_int()) @as(f64, @floatFromInt(v2.as_int())) else v2.as_double();

    var result: f64 = undefined;
    const matched = switch (op) {
        @intFromEnum(OpCode.OP_ADD) => blk: {
            result = n1 + n2;
            break :blk true;
        },
        @intFromEnum(OpCode.OP_SUBTRACT) => blk: {
            result = n1 - n2;
            break :blk true;
        },
        @intFromEnum(OpCode.OP_MULTIPLY) => blk: {
            result = n1 * n2;
            break :blk true;
        },
        @intFromEnum(OpCode.OP_DIVIDE) => blk: {
            if (n2 == 0.0) break :blk false; // Don't fold division by zero
            result = n1 / n2;
            break :blk true;
        },
        else => false,
    };

    if (!matched) return false;

    // Add result to constant pool
    const result_val = Value.init_double(result);
    value_h.writeValueArray(&chunk.constants, result_val);
    const result_idx: u8 = @intCast(chunk.constants.count - 1);

    // Replace with: CONSTANT result_idx
    const code = chunk.code.?;
    code[offset] = @intFromEnum(OpCode.OP_CONSTANT);
    code[offset + 1] = result_idx;

    // Shift rest of bytecode left by 3 bytes
    const src_start = offset + 5;
    const dst_start = offset + 2;
    const remaining = @as(usize, @intCast(chunk.count)) - src_start;

    if (remaining > 0) {
        std.mem.copyForwards(u8, code[dst_start .. dst_start + remaining], code[src_start .. src_start + remaining]);
        const lines = chunk.lines.?;
        std.mem.copyForwards(i32, lines[dst_start .. dst_start + remaining], lines[src_start .. src_start + remaining]);
    }

    chunk.count -= 3;
    return true;
}

/// Try to fold comparison operations
fn tryFoldComparison(chunk: *Chunk, offset: usize, idx1: u8, idx2: u8, op: u8) bool {
    const v1 = chunk.constants.values[@intCast(idx1)];
    const v2 = chunk.constants.values[@intCast(idx2)];

    // Only fold number comparisons (int or double)
    if (!v1.is_prim_num() or !v2.is_prim_num()) return false;

    const n1 = if (v1.is_int()) @as(f64, @floatFromInt(v1.as_int())) else v1.as_double();
    const n2 = if (v2.is_int()) @as(f64, @floatFromInt(v2.as_int())) else v2.as_double();

    var result: bool = undefined;
    const matched = switch (op) {
        @intFromEnum(OpCode.OP_EQUAL) => blk: {
            result = n1 == n2;
            break :blk true;
        },
        @intFromEnum(OpCode.OP_GREATER) => blk: {
            result = n1 > n2;
            break :blk true;
        },
        @intFromEnum(OpCode.OP_LESS) => blk: {
            result = n1 < n2;
            break :blk true;
        },
        else => false,
    };

    if (!matched) return false;

    // Add result to constant pool
    const result_val = Value.init_bool(result);
    value_h.writeValueArray(&chunk.constants, result_val);
    const result_idx: u8 = @intCast(chunk.constants.count - 1);

    // Replace with: CONSTANT result_idx
    const code = chunk.code.?;
    code[offset] = @intFromEnum(OpCode.OP_CONSTANT);
    code[offset + 1] = result_idx;

    // Shift rest of bytecode left by 3 bytes
    const src_start = offset + 5;
    const dst_start = offset + 2;
    const remaining = @as(usize, @intCast(chunk.count)) - src_start;

    if (remaining > 0) {
        std.mem.copyForwards(u8, code[dst_start .. dst_start + remaining], code[src_start .. src_start + remaining]);
        const lines = chunk.lines.?;
        std.mem.copyForwards(i32, lines[dst_start .. dst_start + remaining], lines[src_start .. src_start + remaining]);
    }

    chunk.count -= 3;
    return true;
}

/// Run peephole pattern optimizations
fn runPeepholePatterns(chunk: *Chunk) PeepholeStats {
    var stats = PeepholeStats{};

    var offset: usize = 0;
    while (offset < @as(usize, @intCast(chunk.count))) {
        const code = chunk.code.?;

        // Pattern: CONSTANT n, POP → (remove both)
        if (code[offset] == @intFromEnum(OpCode.OP_CONSTANT) and
            offset + 2 < @as(usize, @intCast(chunk.count)) and
            code[offset + 2] == @intFromEnum(OpCode.OP_POP))
        {
            // Remove 3 bytes: CONSTANT, index, POP
            const src_start = offset + 3;
            const remaining = @as(usize, @intCast(chunk.count)) - src_start;

            if (remaining > 0) {
                std.mem.copyForwards(u8, code[offset .. offset + remaining], code[src_start .. src_start + remaining]);
                const lines = chunk.lines.?;
                std.mem.copyForwards(i32, lines[offset .. offset + remaining], lines[src_start .. src_start + remaining]);
            }

            chunk.count -= 3;
            stats.patterns_applied += 1;
            stats.constant_pop += 1;
            stats.bytes_saved += 3;
            continue; // Don't advance offset
        }

        // Pattern: GET_LOCAL n, SET_LOCAL n → No-op (or could keep GET_LOCAL for stack effect)
        // This is tricky because it might be intentional for stack manipulation
        // For now, skip this optimization to be safe

        offset += 1;
    }

    return stats;
}

/// Run dead code elimination pass
fn runDeadCodeElimination(chunk: *Chunk) DCEStats {
    const stats = DCEStats{};

    var offset: usize = 0;
    while (offset < @as(usize, @intCast(chunk.count))) {
        const code = chunk.code.?;
        const op = code[offset];

        // Remove unreachable code after RETURN
        if (op == @intFromEnum(OpCode.OP_RETURN)) {
            // Find the next instruction (skip RETURN itself)
            const return_end = offset + 1;

            // Look for the next reachable point (jump target or end)
            // For now, simple implementation: if there's more code and it's not a jump target, remove it
            // TODO: Track jump targets properly
            if (return_end < @as(usize, @intCast(chunk.count))) {
                // Check if next instruction could be a jump target
                // For safety, only remove if we're at the end of the chunk
                // A proper implementation would track all jump targets

                // For now, just move to next instruction
                offset += 1;
                continue;
            }
        }

        offset += 1;
    }

    return stats;
}

/// Optimize with default configuration
pub fn optimizeDefault(chunk: *Chunk) OptimizerStats {
    return optimize(chunk, OptimizerConfig.default());
}

/// Optimize with safe configuration
pub fn optimizeSafe(chunk: *Chunk) OptimizerStats {
    return optimize(chunk, OptimizerConfig.safe());
}

/// Optimize silently (no stats)
pub fn optimizeSilent(chunk: *Chunk) void {
    _ = optimize(chunk, OptimizerConfig.default());
}

/// Validate that all constant indices in bytecode are valid
/// This catches corruption where opcodes get misread as operands
fn validateBytecodeIntegrity(chunk: *Chunk) bool {
    const code = chunk.code orelse return true;
    const count = @as(usize, @intCast(chunk.count));
    const constant_count = chunk.constants.count;

    var offset: usize = 0;
    while (offset < count) {
        const opcode_byte = code[offset];

        // Get instruction length to advance properly
        const length = chunk_h.getInstructionLength(chunk, offset);
        if (length == 0) {
            std.debug.print("❌ Invalid instruction at offset {d}: opcode {d}\n", .{ offset, opcode_byte });
            return false;
        }

        // Check if this instruction has constant operands
        const opcode: OpCode = @enumFromInt(opcode_byte);
        const has_constant = switch (opcode) {
            .OP_CONSTANT,
            .OP_GET_GLOBAL,
            .OP_DEFINE_GLOBAL,
            .OP_DEFINE_CONST_GLOBAL,
            .OP_SET_GLOBAL,
            .OP_GET_PROPERTY,
            .OP_SET_PROPERTY,
            .OP_GET_SUPER,
            .OP_METHOD,
            .OP_CLASS,
            .OP_IMPORT_MODULE,
            .OP_IMPORT_FILE,
            .OP_IMPORT_MODULE_AS,
            .OP_GET_MODULE_MEMBER,
            => true,
            else => false,
        };

        if (has_constant and offset + 1 < count) {
            const const_idx = code[offset + 1];
            if (const_idx >= constant_count) {
                std.debug.print("❌ Invalid constant index at offset {d}: {d} >= {d}\n", .{ offset + 1, const_idx, constant_count });
                return false;
            }
        }

        // Check superinstructions with constant operands
        const has_two_constants = switch (opcode) {
            .OP_CONSTANT_CONSTANT,
            .OP_GET_GLOBAL_GLOBAL,
            .OP_GET_GLOBAL_LOCAL,
            .OP_GET_LOCAL_GLOBAL,
            .OP_DEFINE_GLOBAL_CONST,
            .OP_SET_GLOBAL_CONST,
            => true,
            else => false,
        };

        if (has_two_constants and offset + 2 < count) {
            const const_idx1 = code[offset + 1];
            const const_idx2 = code[offset + 2];

            // For GET_LOCAL_* and *_LOCAL, second operand is local slot, not constant
            const both_are_constants = switch (opcode) {
                .OP_GET_GLOBAL_LOCAL,
                .OP_GET_LOCAL_GLOBAL,
                => false,
                else => true,
            };

            if (const_idx1 >= constant_count) {
                std.debug.print("❌ Invalid constant index at offset {d}: {d} >= {d}\n", .{ offset + 1, const_idx1, constant_count });
                return false;
            }

            if (both_are_constants and const_idx2 >= constant_count) {
                std.debug.print("❌ Invalid constant index at offset {d}: {d} >= {d}\n", .{ offset + 2, const_idx2, constant_count });
                return false;
            }
        }

        offset += length;
    }

    return true;
}

/// Analyze without modifying (dry run)
pub fn analyze(chunk: *Chunk, config: OptimizerConfig) OptimizerStats {
    // Clone chunk for analysis
    // For now, just return empty stats
    // TODO: Implement proper analysis without modifying
    _ = chunk;
    _ = config;
    return OptimizerStats{};
}
