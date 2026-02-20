/// VM Tracing and Instrumentation Module
///
/// This module provides runtime tracing capabilities to capture instruction
/// sequences, operand values, and stack states for optimization analysis.
///
/// Features:
/// - Instruction sequence tracking (pairs, triples, etc.)
/// - Frequency counting for pattern identification
/// - Stack state capture before/after instructions
/// - Operand value recording
/// - Export to analysis-friendly format
///
/// Usage:
///   1. Enable tracing: vm_trace.enable()
///   2. Run code normally
///   3. Get results: vm_trace.getReport()
///   4. Disable: vm_trace.disable()
const std = @import("std");
const chunk_h = @import("chunk.zig");
const OpCode = chunk_h.OpCode;
const value_h = @import("value.zig");
const Value = value_h.Value;

/// Maximum number of instruction sequences to track
const MAX_SEQUENCES: usize = 10000;

/// Maximum sequence length (for N-gram tracking)
const MAX_SEQUENCE_LENGTH: usize = 3;

/// Instruction trace entry
pub const TraceEntry = struct {
    opcode: u8,
    operand1: u8 = 0,
    operand2: u8 = 0,
    has_operand1: bool = false,
    has_operand2: bool = false,
    stack_depth_before: usize = 0,
    stack_depth_after: usize = 0,
    line: i32 = 0,
};

/// Instruction pair for pattern analysis
pub const InstructionPair = struct {
    first: u8,
    second: u8,
    first_operand: u8 = 0,
    second_operand: u8 = 0,
    count: usize = 0,

    pub fn hash(self: InstructionPair) u64 {
        var h: u64 = @as(u64, self.first);
        h = h * 31 + @as(u64, self.second);
        h = h * 31 + @as(u64, self.first_operand);
        h = h * 31 + @as(u64, self.second_operand);
        return h;
    }

    pub fn eql(self: InstructionPair, other: InstructionPair) bool {
        return self.first == other.first and
            self.second == other.second and
            self.first_operand == other.first_operand and
            self.second_operand == other.second_operand;
    }
};

/// Instruction triple for advanced pattern analysis
pub const InstructionTriple = struct {
    first: u8,
    second: u8,
    third: u8,
    count: usize = 0,
};

/// Trace statistics
pub const TraceStats = struct {
    total_instructions: usize = 0,
    unique_pairs: usize = 0,
    unique_triples: usize = 0,
    max_stack_depth: usize = 0,
};

/// Global tracing state
var enabled: bool = false;
var trace_buffer: [4096]TraceEntry = undefined;
var trace_index: usize = 0;
var pair_map: std.AutoHashMap(u64, InstructionPair) = undefined;
var pair_map_initialized: bool = false;
var stats: TraceStats = .{};

/// Initialize the tracing system
pub fn init(allocator: std.mem.Allocator) !void {
    if (!pair_map_initialized) {
        pair_map = std.AutoHashMap(u64, InstructionPair).init(allocator);
        pair_map_initialized = true;
    }
    reset();
}

/// Deinitialize and free resources
pub fn deinit() void {
    if (pair_map_initialized) {
        pair_map.deinit();
        pair_map_initialized = false;
    }
}

/// Enable instruction tracing
pub fn enable() void {
    enabled = true;
}

/// Disable instruction tracing
pub fn disable() void {
    enabled = false;
}

/// Check if tracing is enabled
pub fn isEnabled() bool {
    return enabled;
}

/// Reset all trace data
pub fn reset() void {
    trace_index = 0;
    if (pair_map_initialized) {
        pair_map.clearRetainingCapacity();
    }
    stats = .{};
}

/// Record an instruction execution
pub fn recordInstruction(
    opcode: u8,
    operand1: u8,
    operand2: u8,
    has_operand1: bool,
    has_operand2: bool,
    stack_depth_before: usize,
    stack_depth_after: usize,
    line: i32,
) void {
    if (!enabled) return;

    // Record in trace buffer
    if (trace_index < trace_buffer.len) {
        trace_buffer[trace_index] = TraceEntry{
            .opcode = opcode,
            .operand1 = operand1,
            .operand2 = operand2,
            .has_operand1 = has_operand1,
            .has_operand2 = has_operand2,
            .stack_depth_before = stack_depth_before,
            .stack_depth_after = stack_depth_after,
            .line = line,
        };
        trace_index += 1;
    }

    // Update statistics
    stats.total_instructions += 1;
    if (stack_depth_after > stats.max_stack_depth) {
        stats.max_stack_depth = stack_depth_after;
    }

    // Record instruction pair if we have a previous instruction
    if (trace_index >= 2 and pair_map_initialized) {
        const prev = trace_buffer[trace_index - 2];
        const curr = trace_buffer[trace_index - 1];

        const pair = InstructionPair{
            .first = prev.opcode,
            .second = curr.opcode,
            .first_operand = if (prev.has_operand1) prev.operand1 else 0,
            .second_operand = if (curr.has_operand1) curr.operand1 else 0,
            .count = 1,
        };

        const pair_hash = pair.hash();
        if (pair_map.getPtr(pair_hash)) |existing| {
            existing.count += 1;
        } else {
            pair_map.put(pair_hash, pair) catch {};
        }
    }
}

/// Quick record (for hot path) - minimal overhead
pub fn recordQuick(opcode: u8, stack_depth: usize) void {
    if (!enabled) return;
    recordInstruction(opcode, 0, 0, false, false, stack_depth, stack_depth, 0);
}

/// Get opcode name string
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
        67...82 => "OP_CONSTANT_N",
        83...90 => "OP_GET/SET_LOCAL_N",
        91...93 => "OP_JUMP_SHORT",
        100 => "OP_DEFINE_GLOBAL_CONST",
        101 => "OP_SET_GLOBAL_CONST",
        110 => "OP_GET_GLOBAL_ADD",
        111 => "OP_GET_GLOBAL_SUBTRACT",
        112 => "OP_GET_GLOBAL_MULTIPLY",
        113 => "OP_GET_GLOBAL_DIVIDE",
        114 => "OP_GET_LOCAL_ADD",
        120 => "OP_GET_GLOBAL_GLOBAL",
        121 => "OP_GET_LOCAL_LOCAL",
        122 => "OP_GET_GLOBAL_LOCAL",
        123 => "OP_GET_LOCAL_GLOBAL",
        130 => "OP_CONSTANT_CONSTANT",
        131 => "OP_CONSTANT_ADD",
        132 => "OP_CONSTANT_MULTIPLY",
        else => "UNKNOWN",
    };
}

/// Print trace report to stdout
pub fn printReport() void {
    if (!pair_map_initialized) return;

    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("         VM Instruction Trace Report\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("\n", .{});

    std.debug.print("📊 Trace Statistics:\n", .{});
    std.debug.print("───────────────────────────────────────────────────────────\n", .{});
    std.debug.print("  Total instructions:      {d}\n", .{stats.total_instructions});
    std.debug.print("  Unique pairs:            {d}\n", .{pair_map.count()});
    std.debug.print("  Max stack depth:         {d}\n", .{stats.max_stack_depth});
    std.debug.print("  Trace buffer usage:      {d} / {d}\n", .{ trace_index, trace_buffer.len });
    std.debug.print("\n", .{});

    // Convert map to sorted list
    const allocator = std.heap.page_allocator;
    var pairs = std.ArrayList(InstructionPair).initCapacity(allocator, 0) catch unreachable;
    defer pairs.deinit(allocator);

    var it = pair_map.valueIterator();
    while (it.next()) |pair| {
        pairs.append(allocator, pair.*) catch continue;
    }

    // Sort by count (descending)
    std.mem.sort(InstructionPair, pairs.items, {}, struct {
        fn lessThan(_: void, a: InstructionPair, b: InstructionPair) bool {
            return a.count > b.count;
        }
    }.lessThan);

    // Print top instruction pairs
    std.debug.print("🔥 Top Instruction Pairs (Superinstruction Candidates):\n", .{});
    std.debug.print("───────────────────────────────────────────────────────────\n", .{});

    const max_pairs = @min(30, pairs.items.len);
    for (pairs.items[0..max_pairs]) |pair| {
        const first_name = getOpcodeName(pair.first);
        const second_name = getOpcodeName(pair.second);

        if (pair.first_operand != 0 or pair.second_operand != 0) {
            std.debug.print("  {s: <24} → {s: <24} ({d:2}, {d:2})  {d:4}×\n", .{
                first_name,
                second_name,
                pair.first_operand,
                pair.second_operand,
                pair.count,
            });
        } else {
            std.debug.print("  {s: <24} → {s: <24}         {d:4}×\n", .{
                first_name,
                second_name,
                pair.count,
            });
        }
    }

    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("\n", .{});
}

/// Get statistics
pub fn getStats() TraceStats {
    return stats;
}

/// Export trace data to file for offline analysis
pub fn exportToFile(filename: []const u8) !void {
    const allocator = std.heap.page_allocator;
    const file = try std.fs.cwd().createFile(filename, .{});
    defer file.close();

    // Write header using simple string formatting
    const header = try std.fmt.allocPrint(allocator, "# MufiZ VM Instruction Trace\n# Total instructions: {d}\n# Unique pairs: {d}\n\n", .{ stats.total_instructions, pair_map.count() });
    defer allocator.free(header);
    try file.writeAll(header);

    // Write instruction pairs header
    try file.writeAll("# Instruction Pairs (first, second, first_op, second_op, count)\n");

    var pairs = std.ArrayList(InstructionPair).initCapacity(allocator, 0) catch unreachable;
    defer pairs.deinit(allocator);

    var it = pair_map.valueIterator();
    while (it.next()) |pair| {
        try pairs.append(allocator, pair.*);
    }

    // Sort by count
    std.mem.sort(InstructionPair, pairs.items, {}, struct {
        fn lessThan(_: void, a: InstructionPair, b: InstructionPair) bool {
            return a.count > b.count;
        }
    }.lessThan);

    for (pairs.items) |pair| {
        const line = try std.fmt.allocPrint(allocator, "{d},{d},{d},{d},{d}\n", .{
            pair.first,
            pair.second,
            pair.first_operand,
            pair.second_operand,
            pair.count,
        });
        defer allocator.free(line);
        try file.writeAll(line);
    }
}

/// Check if a specific pair would benefit from superinstruction
/// Returns true if count is above threshold and pattern is safe
pub fn shouldOptimizePair(first: u8, second: u8, threshold: usize) bool {
    if (!pair_map_initialized) return false;

    const pair = InstructionPair{
        .first = first,
        .second = second,
        .first_operand = 0,
        .second_operand = 0,
    };

    const pair_hash = pair.hash();
    if (pair_map.get(pair_hash)) |found| {
        return found.count >= threshold;
    }

    return false;
}
