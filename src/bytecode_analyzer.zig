const std = @import("std");
const system = @import("system.zig");
const chunk_h = @import("chunk.zig");
const value_h = @import("value.zig");
const debug_h = @import("debug.zig");

/// Instruction frequency entry
const InstructionFreq = struct {
    opcode: u8,
    count: usize,
};

/// Instruction pair frequency entry
const PairFreq = struct {
    pair: [2]u8,
    count: usize,
};

/// Statistics for bytecode analysis
pub const BytecodeStats = struct {
    total_instructions: usize = 0,
    total_bytes: usize = 0,

    // Instruction frequency counters
    instruction_counts: [256]usize = [_]usize{0} ** 256,
    instruction_bytes: [256]usize = [_]usize{0} ** 256,

    // Optimization opportunity counters
    small_constant_loads: usize = 0, // Constants 0-15
    small_local_accesses: usize = 0, // Locals 0-3
    short_jumps: usize = 0, // Jumps within ±127 bytes
    long_jumps: usize = 0, // Jumps beyond ±127 bytes

    // Pattern detection
    load_add_patterns: usize = 0, // GET_LOCAL + ADD
    load_load_op_patterns: usize = 0, // GET_LOCAL + GET_LOCAL + OP
    constant_op_patterns: usize = 0, // CONSTANT + OP
    repeated_pops: usize = 0, // Multiple consecutive POPs

    // Instruction pair frequency (for superinstruction analysis)
    instruction_pairs: std.AutoHashMap([2]u8, usize) = undefined,

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !BytecodeStats {
        const stats = BytecodeStats{
            .allocator = allocator,
            .instruction_pairs = std.AutoHashMap([2]u8, usize).init(allocator),
        };
        return stats;
    }

    pub fn deinit(self: *BytecodeStats) void {
        self.instruction_pairs.deinit();
    }
};

/// Get the length of an instruction at a given offset
pub fn getInstructionLength(chunk: *chunk_h.Chunk, offset: usize) usize {
    if (offset >= @as(usize, @intCast(chunk.count))) return 0;

    const instruction = chunk.code.?[offset];

    return switch (instruction) {
        // Simple instructions (1 byte)
        1,
        2,
        3,
        4, // OP_NIL, OP_TRUE, OP_FALSE, OP_POP
        16,
        17,
        18,
        19, // Comparisons
        20,
        21,
        22,
        23,
        24,
        25, // Arithmetic
        26,
        27,
        28, // OP_NOT, OP_NEGATE, OP_PRINT
        37, // OP_CLOSE_UPVALUE
        38, // OP_RETURN
        42,
        43,
        44,
        45,
        46,
        47,
        48,
        49, // Array/Range operations
        50,
        51,
        52,
        53,
        54,
        55, // More operations
        56,
        57,
        58,
        61, // OP_TO_STRING, OP_BREAK, OP_CONTINUE, OP_GET_MATRIX_FLAT
        67,
        68,
        69,
        70,
        71,
        72,
        73,
        74,
        75,
        76,
        77,
        78,
        79,
        80,
        81,
        82, // OP_CONSTANT_0..15 (Phase 2.1)
        83,
        84,
        85,
        86,
        87,
        88,
        89,
        90, // OP_GET/SET_LOCAL_0..3 (Phase 2.2)
        => 1,

        // Phase 3: Superinstructions with one operand (2 bytes)
        110, // OP_GET_GLOBAL_ADD
        111, // OP_GET_GLOBAL_SUBTRACT
        112, // OP_GET_GLOBAL_MULTIPLY
        113, // OP_GET_GLOBAL_DIVIDE
        114, // OP_GET_LOCAL_ADD
        131, // OP_CONSTANT_ADD
        132, // OP_CONSTANT_MULTIPLY
        => 2,

        // Phase 3: Superinstructions with two operands (3 bytes)
        100, // OP_DEFINE_GLOBAL_CONST
        101, // OP_SET_GLOBAL_CONST
        120, // OP_GET_GLOBAL_GLOBAL
        121, // OP_GET_LOCAL_LOCAL
        122, // OP_GET_GLOBAL_LOCAL
        123, // OP_GET_LOCAL_GLOBAL
        130, // OP_CONSTANT_CONSTANT
        => 3,

        // Byte instructions (2 bytes: opcode + operand)
        5,
        6, // OP_GET_LOCAL, OP_SET_LOCAL
        11,
        12, // OP_GET_UPVALUE, OP_SET_UPVALUE
        32, // OP_CALL
        33, // OP_TAIL_CALL
        59, // OP_FVECTOR
        => 2,

        // Constant instructions (2 bytes: opcode + constant index)
        0, // OP_CONSTANT
        7,
        8,
        9,
        10, // Global operations
        13,
        14,
        15, // Property operations
        39, // OP_CLASS
        40, // OP_INHERIT
        41, // OP_METHOD
        62,
        63,
        65,
        66, // Class/Import operations
        94,
        95, // OP_DEFINE_PUBLIC_GLOBAL, OP_DEFINE_PUBLIC_CONST_GLOBAL
        => 2,

        // Jump instructions (3 bytes: opcode + 2-byte offset)
        29,
        30,
        31, // OP_JUMP, OP_JUMP_IF_FALSE, OP_LOOP
        => 3,

        // File import visibility opcodes (3 bytes: opcode + 2 constant indices)
        96, // OP_IMPORT_FILE_AS
        97, // OP_FROM_IMPORT_FILE
        => 3,

        // Short jump instructions (2 bytes: opcode + i8 offset) - Phase 2.3
        91,
        92,
        93, // OP_JUMP_SHORT, OP_JUMP_IF_FALSE_SHORT, OP_LOOP_SHORT
        => 2,

        // Invoke instructions (2 bytes for name + arg count handled separately)
        34,
        35, // OP_INVOKE, OP_SUPER_INVOKE
        => 3,

        // Two-byte operand instructions
        60, // OP_MATRIX (opcode + rows + cols)
        => 3,

        // OP_IMPORT_SPECIFIC (special case: 3 bytes)
        64 => 3,

        // OP_CLOSURE (variable length)
        36 => blk: {
            if (offset + 1 >= @as(usize, @intCast(chunk.count))) break :blk 2;
            const constant_idx = chunk.code.?[offset + 1];
            if (constant_idx >= @as(u8, @intCast(chunk.constants.count))) break :blk 2;

            const function_value = chunk.constants.values[constant_idx];
            if (!function_value.is_obj()) break :blk 2;

            // Each upvalue takes 2 bytes (isLocal + index)
            // We need to know upvalue count, but that requires object access
            // For now, estimate based on next instruction
            var len: usize = 2; // opcode + constant
            var pos = offset + 2;

            // Scan ahead for upvalue pairs (heuristic)
            while (pos + 1 < @as(usize, @intCast(chunk.count)) and len < 50) : (pos += 2) {
                // Upvalue bytes are typically small values
                const b1 = chunk.code.?[pos];
                const b2 = chunk.code.?[pos + 1];
                if (b1 > 1 or b2 > 255) break; // Not an upvalue pair
                len += 2;
            }

            break :blk len;
        },

        else => 1, // Unknown, assume 1 byte
    };
}

/// Analyze a chunk of bytecode
pub fn analyzeChunk(chunk: *chunk_h.Chunk, stats: *BytecodeStats) !void {
    var offset: usize = 0;
    var prev_instruction: ?u8 = null;

    while (offset < @as(usize, @intCast(chunk.count))) {
        const instruction = chunk.code.?[offset];
        const length = getInstructionLength(chunk, offset);

        // Update basic stats
        stats.total_instructions += 1;
        stats.total_bytes += length;
        stats.instruction_counts[instruction] += 1;
        stats.instruction_bytes[instruction] += length;

        // Analyze specific patterns
        analyzeInstruction(chunk, offset, instruction, stats);

        // Track instruction pairs for superinstruction analysis
        if (prev_instruction) |prev| {
            const pair = [2]u8{ prev, instruction };
            const count = stats.instruction_pairs.get(pair) orelse 0;
            try stats.instruction_pairs.put(pair, count + 1);
        }

        prev_instruction = instruction;
        offset += length;
    }
}

/// Analyze a specific instruction for optimization opportunities
fn analyzeInstruction(chunk: *chunk_h.Chunk, offset: usize, instruction: u8, stats: *BytecodeStats) void {
    switch (instruction) {
        // OP_CONSTANT - check if it's a small constant
        0 => {
            if (offset + 1 < @as(usize, @intCast(chunk.count))) {
                const const_idx = chunk.code.?[offset + 1];
                if (const_idx <= 15) {
                    stats.small_constant_loads += 1;
                }
            }
        },

        // OP_GET_LOCAL, OP_SET_LOCAL - check if it's a small local
        5, 6 => {
            if (offset + 1 < @as(usize, @intCast(chunk.count))) {
                const slot = chunk.code.?[offset + 1];
                if (slot <= 3) {
                    stats.small_local_accesses += 1;
                }
            }
        },

        // Jump instructions - analyze jump distance
        29, 30, 31 => {
            if (offset + 2 < @as(usize, @intCast(chunk.count))) {
                const byte1 = chunk.code.?[offset + 1];
                const byte2 = chunk.code.?[offset + 2];
                const jump_offset = (@as(u16, byte1) << 8) | byte2;

                // Check if this could be a short jump (±127 bytes)
                if (jump_offset <= 127) {
                    stats.short_jumps += 1;
                } else {
                    stats.long_jumps += 1;
                }
            }
        },

        // OP_POP - check for repeated pops
        4 => {
            var count: usize = 1;
            var pos = offset + 1;
            while (pos < @as(usize, @intCast(chunk.count)) and chunk.code.?[pos] == 4) : (pos += 1) {
                count += 1;
            }
            if (count >= 2) {
                stats.repeated_pops += 1;
            }
        },

        else => {},
    }

    // Check for common patterns that could be fused
    if (offset > 0) {
        const prev_offset = offset -| getInstructionLength(chunk, offset - 1);
        if (prev_offset < @as(usize, @intCast(chunk.count))) {
            const prev_instruction = chunk.code.?[prev_offset];

            // GET_LOCAL + binary op
            if (prev_instruction == 5) { // OP_GET_LOCAL
                if (instruction >= 20 and instruction <= 25) { // Arithmetic ops
                    stats.load_add_patterns += 1;
                }
            }

            // CONSTANT + binary op
            if (prev_instruction == 0) { // OP_CONSTANT
                if (instruction >= 20 and instruction <= 25) {
                    stats.constant_op_patterns += 1;
                }
            }
        }
    }
}

/// Get the name of an opcode
fn getOpcodeName(opcode: u8) []const u8 {
    return switch (opcode) {
        0 => "OP_CONSTANT",
        1 => "OP_NIL",
        2 => "OP_TRUE",
        3 => "OP_FALSE",
        4 => "OP_POP",
        5 => "OP_GET_LOCAL",
        6 => "OP_SET_LOCAL",
        7 => "OP_GET_GLOBAL",
        8 => "OP_DEFINE_GLOBAL",
        9 => "OP_DEFINE_CONST_GLOBAL",
        10 => "OP_SET_GLOBAL",
        11 => "OP_GET_UPVALUE",
        12 => "OP_SET_UPVALUE",
        13 => "OP_GET_PROPERTY",
        14 => "OP_SET_PROPERTY",
        15 => "OP_GET_SUPER",
        16 => "OP_EQUAL",
        17 => "OP_GREATER",
        18 => "OP_LESS",
        19 => "OP_GREATER_EQUAL",
        20 => "OP_ADD",
        21 => "OP_SUBTRACT",
        22 => "OP_MULTIPLY",
        23 => "OP_DIVIDE",
        24 => "OP_MODULO",
        25 => "OP_EXPONENT",
        26 => "OP_NOT",
        27 => "OP_NEGATE",
        28 => "OP_PRINT",
        29 => "OP_JUMP",
        30 => "OP_JUMP_IF_FALSE",
        31 => "OP_LOOP",
        32 => "OP_CALL",
        33 => "OP_TAIL_CALL",
        34 => "OP_INVOKE",
        35 => "OP_SUPER_INVOKE",
        36 => "OP_CLOSURE",
        37 => "OP_CLOSE_UPVALUE",
        38 => "OP_RETURN",
        39 => "OP_CLASS",
        40 => "OP_INHERIT",
        41 => "OP_METHOD",
        42 => "OP_LENGTH",
        43 => "OP_GET_INDEX",
        44 => "OP_SLICE",
        45 => "OP_RANGE",
        46 => "OP_RANGE_INCLUSIVE",
        47 => "OP_PAIR",
        48 => "OP_CHECK_RANGE",
        49 => "OP_IS_RANGE",
        50 => "OP_GET_RANGE_LENGTH",
        51 => "OP_SET_INDEX",
        52 => "OP_DUP",
        53 => "OP_INT",
        54 => "OP_HASH_TABLE",
        55 => "OP_ADD_ENTRY",
        56 => "OP_TO_STRING",
        57 => "OP_BREAK",
        58 => "OP_CONTINUE",
        59 => "OP_FVECTOR",
        60 => "OP_MATRIX",
        61 => "OP_GET_MATRIX_FLAT",
        62 => "OP_IMPORT_MODULE",
        63 => "OP_IMPORT_FILE",
        64 => "OP_IMPORT_SPECIFIC",
        65 => "OP_IMPORT_MODULE_AS",
        66 => "OP_GET_MODULE_MEMBER",
        // Phase 2: Small constant opcodes
        67 => "OP_CONSTANT_0",
        68 => "OP_CONSTANT_1",
        69 => "OP_CONSTANT_2",
        70 => "OP_CONSTANT_3",
        71 => "OP_CONSTANT_4",
        72 => "OP_CONSTANT_5",
        73 => "OP_CONSTANT_6",
        74 => "OP_CONSTANT_7",
        75 => "OP_CONSTANT_8",
        76 => "OP_CONSTANT_9",
        77 => "OP_CONSTANT_10",
        78 => "OP_CONSTANT_11",
        79 => "OP_CONSTANT_12",
        80 => "OP_CONSTANT_13",
        81 => "OP_CONSTANT_14",
        82 => "OP_CONSTANT_15",
        // Phase 2.2: Small local opcodes
        83 => "OP_GET_LOCAL_0",
        84 => "OP_GET_LOCAL_1",
        85 => "OP_GET_LOCAL_2",
        86 => "OP_GET_LOCAL_3",
        87 => "OP_SET_LOCAL_0",
        88 => "OP_SET_LOCAL_1",
        89 => "OP_SET_LOCAL_2",
        90 => "OP_SET_LOCAL_3",
        // Phase 2.3: Short jump opcodes
        91 => "OP_JUMP_SHORT",
        92 => "OP_JUMP_IF_FALSE_SHORT",
        93 => "OP_LOOP_SHORT",
        else => "UNKNOWN",
    };
}

/// Print detailed bytecode analysis report
pub fn printReport(stats: *BytecodeStats, writer: anytype) !void {
    writer.print("\n", .{});
    writer.print("═══════════════════════════════════════════════════════════\n", .{});
    writer.print("         MufiZ Bytecode Analysis Report\n", .{});
    writer.print("═══════════════════════════════════════════════════════════\n", .{});
    writer.print("\n", .{});

    // Basic statistics
    writer.print("📊 Basic Statistics:\n", .{});
    writer.print("───────────────────────────────────────────────────────────\n", .{});
    writer.print("  Total instructions:  {d}\n", .{stats.total_instructions});
    writer.print("  Total bytes:         {d}\n", .{stats.total_bytes});
    writer.print("  Average inst size:   {d:.2} bytes\n", .{@as(f64, @floatFromInt(stats.total_bytes)) / @as(f64, @floatFromInt(stats.total_instructions))});
    writer.print("\n", .{});

    // Top 15 most frequent instructions
    writer.print("🔥 Most Frequent Instructions:\n", .{});
    writer.print("───────────────────────────────────────────────────────────\n", .{});

    // Collect instructions that were used
    var instruction_list = try stats.allocator.alloc(InstructionFreq, 256);
    defer stats.allocator.free(instruction_list);
    var instruction_count: usize = 0;

    for (0..256) |i| {
        if (stats.instruction_counts[i] > 0) {
            instruction_list[instruction_count] = .{ .opcode = @intCast(i), .count = stats.instruction_counts[i] };
            instruction_count += 1;
        }
    }

    const sorted_instructions = instruction_list[0..instruction_count];
    std.sort.heap(InstructionFreq, sorted_instructions, {}, struct {
        fn lessThan(_: void, a: InstructionFreq, b: InstructionFreq) bool {
            return a.count > b.count;
        }
    }.lessThan);

    const top_n = @min(15, sorted_instructions.len);
    for (sorted_instructions[0..top_n]) |item| {
        const percentage = @as(f64, @floatFromInt(item.count)) / @as(f64, @floatFromInt(stats.total_instructions)) * 100.0;
        const bytes = stats.instruction_bytes[item.opcode];
        writer.print("  {s: <25} {d: >6} ({d:5.1}%)  - {d} bytes\n", .{
            getOpcodeName(item.opcode),
            item.count,
            percentage,
            bytes,
        });
    }
    writer.print("\n", .{});

    // Optimization opportunities
    writer.print("💡 Optimization Opportunities:\n", .{});
    writer.print("───────────────────────────────────────────────────────────\n", .{});

    var total_potential_savings: usize = 0;

    if (stats.small_constant_loads > 0) {
        writer.print("  ✓ Small constants (0-15):  {d: >6} loads\n", .{stats.small_constant_loads});
        writer.print("    → Potential savings:     {d} bytes\n", .{stats.small_constant_loads});
        total_potential_savings += stats.small_constant_loads;
    }

    if (stats.small_local_accesses > 0) {
        writer.print("  ✓ Small locals (0-3):      {d: >6} accesses\n", .{stats.small_local_accesses});
        writer.print("    → Potential savings:     {d} bytes\n", .{stats.small_local_accesses});
        total_potential_savings += stats.small_local_accesses;
    }

    if (stats.short_jumps > 0) {
        const total_jumps = stats.short_jumps + stats.long_jumps;
        const short_percentage = @as(f64, @floatFromInt(stats.short_jumps)) / @as(f64, @floatFromInt(total_jumps)) * 100.0;
        writer.print("  ✓ Short jumps:             {d: >6} of {d} ({d:.1}%)\n", .{ stats.short_jumps, total_jumps, short_percentage });
        writer.print("    → Potential savings:     {d} bytes\n", .{stats.short_jumps});
        total_potential_savings += stats.short_jumps;
    }

    if (stats.load_add_patterns > 0) {
        writer.print("  ✓ GET_LOCAL + OP:          {d: >6} patterns\n", .{stats.load_add_patterns});
        writer.print("    → Potential savings:     {d} bytes\n", .{stats.load_add_patterns});
        total_potential_savings += stats.load_add_patterns;
    }

    if (stats.constant_op_patterns > 0) {
        writer.print("  ✓ CONSTANT + OP:           {d: >6} patterns\n", .{stats.constant_op_patterns});
        writer.print("    → Potential savings:     {d} bytes\n", .{stats.constant_op_patterns});
        total_potential_savings += stats.constant_op_patterns;
    }

    if (stats.repeated_pops > 0) {
        writer.print("  ✓ Repeated POPs:           {d: >6} sequences\n", .{stats.repeated_pops});
        writer.print("    → Potential savings:     {d} bytes (est.)\n", .{stats.repeated_pops});
        total_potential_savings += stats.repeated_pops;
    }

    writer.print("\n", .{});
    writer.print("  📦 Total potential savings:   {d} bytes\n", .{total_potential_savings});

    const savings_percentage = @as(f64, @floatFromInt(total_potential_savings)) / @as(f64, @floatFromInt(stats.total_bytes)) * 100.0;
    writer.print("  📊 Estimated reduction:       {d:.1}%\n", .{savings_percentage});
    writer.print("\n", .{});

    // Top instruction pairs (for superinstruction analysis)
    writer.print("🔗 Top Instruction Pairs (Superinstruction Candidates):\n", .{});
    writer.print("───────────────────────────────────────────────────────────\n", .{});

    // Collect all pairs
    const max_pairs = stats.instruction_pairs.count();
    if (max_pairs == 0) {
        writer.print("  (No instruction pairs recorded)\n", .{});
    } else {
        var pair_list = try stats.allocator.alloc(PairFreq, max_pairs);
        defer stats.allocator.free(pair_list);
        var pair_count: usize = 0;

        var pair_iter = stats.instruction_pairs.iterator();
        while (pair_iter.next()) |entry| {
            pair_list[pair_count] = .{ .pair = entry.key_ptr.*, .count = entry.value_ptr.* };
            pair_count += 1;
        }

        const sorted_pairs = pair_list[0..pair_count];
        std.sort.heap(PairFreq, sorted_pairs, {}, struct {
            fn lessThan(_: void, a: PairFreq, b: PairFreq) bool {
                return a.count > b.count;
            }
        }.lessThan);

        const top_pairs = @min(10, sorted_pairs.len);
        for (sorted_pairs[0..top_pairs]) |item| {
            writer.print("  {s: <20} → {s: <20}  {d: >6}×\n", .{
                getOpcodeName(item.pair[0]),
                getOpcodeName(item.pair[1]),
                item.count,
            });
        }
    }

    writer.print("\n", .{});
    writer.print("═══════════════════════════════════════════════════════════\n", .{});
}

/// Convenience function to analyze and print report
pub fn analyzeAndReport(chunk: *chunk_h.Chunk, allocator: std.mem.Allocator) !void {
    var stats = try BytecodeStats.init(allocator);
    defer stats.deinit();

    try analyzeChunk(chunk, &stats);

    const stdout = std.debug;
    try printReport(&stats, stdout);
}
