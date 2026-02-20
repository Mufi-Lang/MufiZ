const std = @import("std");
const testing = std.testing;
const chunk_h = @import("chunk");
const Chunk = chunk_h.Chunk;
const OpCode = chunk_h.OpCode;
const value_h = @import("value");
const Value = value_h.Value;
const bytecode_optimizer = @import("bytecode_optimizer");
const OptimizerConfig = bytecode_optimizer.OptimizerConfig;

/// Helper to create a test chunk
fn createTestChunk() Chunk {
    var chunk = Chunk{};
    chunk.init();
    return chunk;
}

/// Helper to add a constant to the chunk
fn addConstant(chunk: *Chunk, value: Value) u8 {
    chunk.constants.write(value);
    return @intCast(chunk.constants.count - 1);
}

test "optimizer: constant folding - addition" {
    var chunk = createTestChunk();
    defer chunk.free();

    // Generate: CONSTANT 5, CONSTANT 3, ADD
    const idx1 = addConstant(&chunk, value_h.numberVal(5.0));
    const idx2 = addConstant(&chunk, value_h.numberVal(3.0));

    chunk.write(@intFromEnum(OpCode.OP_CONSTANT), 1);
    chunk.write(idx1, 1);
    chunk.write(@intFromEnum(OpCode.OP_CONSTANT), 1);
    chunk.write(idx2, 1);
    chunk.write(@intFromEnum(OpCode.OP_ADD), 1);
    chunk.write(@intFromEnum(OpCode.OP_RETURN), 1);

    const size_before = chunk.count;

    // Optimize
    const stats = bytecode_optimizer.optimizeDefault(&chunk);

    // Should have folded to: CONSTANT 8, RETURN
    try testing.expect(chunk.count < size_before);
    try testing.expect(stats.constant_folding.arithmetic_ops > 0);
    try testing.expect(stats.total_bytes_saved > 0);
}

test "optimizer: constant folding - subtraction" {
    var chunk = createTestChunk();
    defer chunk.free();

    // Generate: CONSTANT 10, CONSTANT 3, SUBTRACT
    const idx1 = addConstant(&chunk, value_h.numberVal(10.0));
    const idx2 = addConstant(&chunk, value_h.numberVal(3.0));

    chunk.write(@intFromEnum(OpCode.OP_CONSTANT), 1);
    chunk.write(idx1, 1);
    chunk.write(@intFromEnum(OpCode.OP_CONSTANT), 1);
    chunk.write(idx2, 1);
    chunk.write(@intFromEnum(OpCode.OP_SUBTRACT), 1);
    chunk.write(@intFromEnum(OpCode.OP_RETURN), 1);

    const size_before = chunk.count;

    // Optimize
    const stats = bytecode_optimizer.optimizeDefault(&chunk);

    // Should have folded to: CONSTANT 7, RETURN
    try testing.expect(chunk.count < size_before);
    try testing.expect(stats.constant_folding.arithmetic_ops > 0);
}

test "optimizer: constant folding - multiplication" {
    var chunk = createTestChunk();
    defer chunk.free();

    // Generate: CONSTANT 4, CONSTANT 5, MULTIPLY
    const idx1 = addConstant(&chunk, value_h.numberVal(4.0));
    const idx2 = addConstant(&chunk, value_h.numberVal(5.0));

    chunk.write(@intFromEnum(OpCode.OP_CONSTANT), 1);
    chunk.write(idx1, 1);
    chunk.write(@intFromEnum(OpCode.OP_CONSTANT), 1);
    chunk.write(idx2, 1);
    chunk.write(@intFromEnum(OpCode.OP_MULTIPLY), 1);
    chunk.write(@intFromEnum(OpCode.OP_RETURN), 1);

    const size_before = chunk.count;

    // Optimize
    const stats = bytecode_optimizer.optimizeDefault(&chunk);

    // Should have folded to: CONSTANT 20, RETURN
    try testing.expect(chunk.count < size_before);
    try testing.expect(stats.constant_folding.arithmetic_ops > 0);
}

test "optimizer: constant folding - division" {
    var chunk = createTestChunk();
    defer chunk.free();

    // Generate: CONSTANT 20, CONSTANT 4, DIVIDE
    const idx1 = addConstant(&chunk, value_h.numberVal(20.0));
    const idx2 = addConstant(&chunk, value_h.numberVal(4.0));

    chunk.write(@intFromEnum(OpCode.OP_CONSTANT), 1);
    chunk.write(idx1, 1);
    chunk.write(@intFromEnum(OpCode.OP_CONSTANT), 1);
    chunk.write(idx2, 1);
    chunk.write(@intFromEnum(OpCode.OP_DIVIDE), 1);
    chunk.write(@intFromEnum(OpCode.OP_RETURN), 1);

    const size_before = chunk.count;

    // Optimize
    const stats = bytecode_optimizer.optimizeDefault(&chunk);

    // Should have folded to: CONSTANT 5, RETURN
    try testing.expect(chunk.count < size_before);
    try testing.expect(stats.constant_folding.arithmetic_ops > 0);
}

test "optimizer: constant folding - division by zero not folded" {
    var chunk = createTestChunk();
    defer chunk.free();

    // Generate: CONSTANT 20, CONSTANT 0, DIVIDE
    const idx1 = addConstant(&chunk, value_h.numberVal(20.0));
    const idx2 = addConstant(&chunk, value_h.numberVal(0.0));

    chunk.write(@intFromEnum(OpCode.OP_CONSTANT), 1);
    chunk.write(idx1, 1);
    chunk.write(@intFromEnum(OpCode.OP_CONSTANT), 1);
    chunk.write(idx2, 1);
    chunk.write(@intFromEnum(OpCode.OP_DIVIDE), 1);
    chunk.write(@intFromEnum(OpCode.OP_RETURN), 1);

    const size_before = chunk.count;

    // Optimize
    const stats = bytecode_optimizer.optimizeDefault(&chunk);

    // Should NOT fold division by zero - keep runtime error
    try testing.expectEqual(size_before, chunk.count);
    try testing.expectEqual(@as(usize, 0), stats.constant_folding.arithmetic_ops);
}

test "optimizer: constant folding - comparison equal" {
    var chunk = createTestChunk();
    defer chunk.free();

    // Generate: CONSTANT 5, CONSTANT 5, EQUAL
    const idx1 = addConstant(&chunk, value_h.numberVal(5.0));
    const idx2 = addConstant(&chunk, value_h.numberVal(5.0));

    chunk.write(@intFromEnum(OpCode.OP_CONSTANT), 1);
    chunk.write(idx1, 1);
    chunk.write(@intFromEnum(OpCode.OP_CONSTANT), 1);
    chunk.write(idx2, 1);
    chunk.write(@intFromEnum(OpCode.OP_EQUAL), 1);
    chunk.write(@intFromEnum(OpCode.OP_RETURN), 1);

    const size_before = chunk.count;

    // Optimize
    const stats = bytecode_optimizer.optimizeDefault(&chunk);

    // Should have folded to: CONSTANT true, RETURN
    try testing.expect(chunk.count < size_before);
    try testing.expect(stats.constant_folding.comparison_ops > 0);
}

test "optimizer: constant folding - comparison greater" {
    var chunk = createTestChunk();
    defer chunk.free();

    // Generate: CONSTANT 10, CONSTANT 5, GREATER
    const idx1 = addConstant(&chunk, value_h.numberVal(10.0));
    const idx2 = addConstant(&chunk, value_h.numberVal(5.0));

    chunk.write(@intFromEnum(OpCode.OP_CONSTANT), 1);
    chunk.write(idx1, 1);
    chunk.write(@intFromEnum(OpCode.OP_CONSTANT), 1);
    chunk.write(idx2, 1);
    chunk.write(@intFromEnum(OpCode.OP_GREATER), 1);
    chunk.write(@intFromEnum(OpCode.OP_RETURN), 1);

    const size_before = chunk.count;

    // Optimize
    const stats = bytecode_optimizer.optimizeDefault(&chunk);

    // Should have folded to: CONSTANT true, RETURN
    try testing.expect(chunk.count < size_before);
    try testing.expect(stats.constant_folding.comparison_ops > 0);
}

test "optimizer: constant folding - comparison less" {
    var chunk = createTestChunk();
    defer chunk.free();

    // Generate: CONSTANT 3, CONSTANT 5, LESS
    const idx1 = addConstant(&chunk, value_h.numberVal(3.0));
    const idx2 = addConstant(&chunk, value_h.numberVal(5.0));

    chunk.write(@intFromEnum(OpCode.OP_CONSTANT), 1);
    chunk.write(idx1, 1);
    chunk.write(@intFromEnum(OpCode.OP_CONSTANT), 1);
    chunk.write(idx2, 1);
    chunk.write(@intFromEnum(OpCode.OP_LESS), 1);
    chunk.write(@intFromEnum(OpCode.OP_RETURN), 1);

    const size_before = chunk.count;

    // Optimize
    const stats = bytecode_optimizer.optimizeDefault(&chunk);

    // Should have folded to: CONSTANT true, RETURN
    try testing.expect(chunk.count < size_before);
    try testing.expect(stats.constant_folding.comparison_ops > 0);
}

test "optimizer: peephole - CONSTANT POP elimination" {
    var chunk = createTestChunk();
    defer chunk.free();

    // Generate: CONSTANT 5, POP (unused constant)
    const idx = addConstant(&chunk, value_h.numberVal(5.0));

    chunk.write(@intFromEnum(OpCode.OP_CONSTANT), 1);
    chunk.write(idx, 1);
    chunk.write(@intFromEnum(OpCode.OP_POP), 1);
    chunk.write(@intFromEnum(OpCode.OP_RETURN), 1);

    const size_before = chunk.count;

    // Optimize
    const stats = bytecode_optimizer.optimizeDefault(&chunk);

    // Should eliminate CONSTANT + POP
    try testing.expect(chunk.count < size_before);
    try testing.expect(stats.peephole_patterns.constant_pop > 0);
}

test "optimizer: superinstructions - GET_GLOBAL GET_GLOBAL" {
    var chunk = createTestChunk();
    defer chunk.free();

    // Add global names
    const name1 = addConstant(&chunk, value_h.numberVal(0.0)); // placeholder
    const name2 = addConstant(&chunk, value_h.numberVal(1.0)); // placeholder

    // Generate: GET_GLOBAL name1, GET_GLOBAL name2
    chunk.write(@intFromEnum(OpCode.OP_GET_GLOBAL), 1);
    chunk.write(name1, 1);
    chunk.write(@intFromEnum(OpCode.OP_GET_GLOBAL), 1);
    chunk.write(name2, 1);
    chunk.write(@intFromEnum(OpCode.OP_RETURN), 1);

    const size_before = chunk.count;

    // Optimize
    const stats = bytecode_optimizer.optimizeDefault(&chunk);

    // Should fuse to GET_GLOBAL_GLOBAL
    try testing.expect(chunk.count < size_before);
    try testing.expect(stats.superinstructions.get_global_global > 0);
}

test "optimizer: superinstructions - GET_LOCAL GET_LOCAL" {
    var chunk = createTestChunk();
    defer chunk.free();

    // Generate: GET_LOCAL 0, GET_LOCAL 1
    chunk.write(@intFromEnum(OpCode.OP_GET_LOCAL), 1);
    chunk.write(0, 1);
    chunk.write(@intFromEnum(OpCode.OP_GET_LOCAL), 1);
    chunk.write(1, 1);
    chunk.write(@intFromEnum(OpCode.OP_RETURN), 1);

    const size_before = chunk.count;

    // Optimize
    const stats = bytecode_optimizer.optimizeDefault(&chunk);

    // Should fuse to GET_LOCAL_LOCAL
    try testing.expect(chunk.count < size_before);
    try testing.expect(stats.superinstructions.get_local_local > 0);
}

test "optimizer: superinstructions - CONSTANT CONSTANT" {
    var chunk = createTestChunk();
    defer chunk.free();

    // Add constants
    const idx1 = addConstant(&chunk, value_h.numberVal(5.0));
    const idx2 = addConstant(&chunk, value_h.numberVal(10.0));

    // Generate: CONSTANT idx1, CONSTANT idx2
    chunk.write(@intFromEnum(OpCode.OP_CONSTANT), 1);
    chunk.write(idx1, 1);
    chunk.write(@intFromEnum(OpCode.OP_CONSTANT), 1);
    chunk.write(idx2, 1);
    chunk.write(@intFromEnum(OpCode.OP_RETURN), 1);

    const size_before = chunk.count;

    // Optimize
    const stats = bytecode_optimizer.optimizeDefault(&chunk);

    // Should fuse to CONSTANT_CONSTANT
    try testing.expect(chunk.count < size_before);
    try testing.expect(stats.superinstructions.constant_constant > 0);
}

test "optimizer: multiple passes convergence" {
    var chunk = createTestChunk();
    defer chunk.free();

    // Generate complex code that needs multiple passes
    // CONSTANT 5, CONSTANT 3, ADD, CONSTANT 2, ADD
    const idx1 = addConstant(&chunk, value_h.numberVal(5.0));
    const idx2 = addConstant(&chunk, value_h.numberVal(3.0));
    const idx3 = addConstant(&chunk, value_h.numberVal(2.0));

    chunk.write(@intFromEnum(OpCode.OP_CONSTANT), 1);
    chunk.write(idx1, 1);
    chunk.write(@intFromEnum(OpCode.OP_CONSTANT), 1);
    chunk.write(idx2, 1);
    chunk.write(@intFromEnum(OpCode.OP_ADD), 1);
    chunk.write(@intFromEnum(OpCode.OP_CONSTANT), 1);
    chunk.write(idx3, 1);
    chunk.write(@intFromEnum(OpCode.OP_ADD), 1);
    chunk.write(@intFromEnum(OpCode.OP_RETURN), 1);

    const size_before = chunk.count;

    // Optimize with multiple passes
    var config = OptimizerConfig.default();
    config.max_passes = 3;
    const stats = bytecode_optimizer.optimize(&chunk, config);

    // Should optimize significantly
    try testing.expect(chunk.count < size_before);
    try testing.expect(stats.passes_performed > 0);
    try testing.expect(stats.total_bytes_saved > 0);
}

test "optimizer: disabled config makes no changes" {
    var chunk = createTestChunk();
    defer chunk.free();

    // Generate some code
    const idx = addConstant(&chunk, value_h.numberVal(5.0));
    chunk.write(@intFromEnum(OpCode.OP_CONSTANT), 1);
    chunk.write(idx, 1);
    chunk.write(@intFromEnum(OpCode.OP_POP), 1);
    chunk.write(@intFromEnum(OpCode.OP_RETURN), 1);

    const size_before = chunk.count;

    // Optimize with disabled config
    const config = OptimizerConfig.disabled();
    const stats = bytecode_optimizer.optimize(&chunk, config);

    // Should make no changes
    try testing.expectEqual(size_before, chunk.count);
    try testing.expectEqual(@as(usize, 0), stats.passes_performed);
    try testing.expectEqual(@as(usize, 0), stats.total_bytes_saved);
}

test "optimizer: safe config is conservative" {
    var chunk = createTestChunk();
    defer chunk.free();

    // Generate code
    const idx = addConstant(&chunk, value_h.numberVal(5.0));
    chunk.write(@intFromEnum(OpCode.OP_CONSTANT), 1);
    chunk.write(idx, 1);
    chunk.write(@intFromEnum(OpCode.OP_RETURN), 1);

    // Optimize with safe config (DCE disabled)
    const config = OptimizerConfig.safe();
    const stats = bytecode_optimizer.optimize(&chunk, config);

    // Should only run 1 pass with safe config
    try testing.expectEqual(@as(usize, 1), config.max_passes);
    try testing.expectEqual(false, config.enable_dce);
}

test "optimizer: combined optimizations" {
    var chunk = createTestChunk();
    defer chunk.free();

    // Generate: CONSTANT 2, CONSTANT 3, ADD, POP
    // Should fold constants AND eliminate dead code
    const idx1 = addConstant(&chunk, value_h.numberVal(2.0));
    const idx2 = addConstant(&chunk, value_h.numberVal(3.0));

    chunk.write(@intFromEnum(OpCode.OP_CONSTANT), 1);
    chunk.write(idx1, 1);
    chunk.write(@intFromEnum(OpCode.OP_CONSTANT), 1);
    chunk.write(idx2, 1);
    chunk.write(@intFromEnum(OpCode.OP_ADD), 1);
    chunk.write(@intFromEnum(OpCode.OP_POP), 1);
    chunk.write(@intFromEnum(OpCode.OP_RETURN), 1);

    const size_before = chunk.count;

    // Optimize
    var config = OptimizerConfig.default();
    config.max_passes = 2;
    const stats = bytecode_optimizer.optimize(&chunk, config);

    // Should apply both constant folding and peephole
    try testing.expect(chunk.count < size_before);
    try testing.expect(stats.total_bytes_saved > 0);
}

test "optimizer: empty chunk unchanged" {
    var chunk = createTestChunk();
    defer chunk.free();

    // Empty chunk
    const size_before = chunk.count;

    // Optimize
    const stats = bytecode_optimizer.optimizeDefault(&chunk);

    // Should remain unchanged
    try testing.expectEqual(size_before, chunk.count);
    try testing.expectEqual(@as(usize, 0), stats.total_bytes_saved);
}

test "optimizer: single instruction unchanged" {
    var chunk = createTestChunk();
    defer chunk.free();

    // Single RETURN
    chunk.write(@intFromEnum(OpCode.OP_RETURN), 1);

    const size_before = chunk.count;

    // Optimize
    const stats = bytecode_optimizer.optimizeDefault(&chunk);

    // Should remain unchanged
    try testing.expectEqual(size_before, chunk.count);
    try testing.expectEqual(@as(usize, 0), stats.total_bytes_saved);
}

test "optimizer: preserves semantics" {
    var chunk = createTestChunk();
    defer chunk.free();

    // Generate: CONSTANT 5, CONSTANT 3, ADD
    const idx1 = addConstant(&chunk, value_h.numberVal(5.0));
    const idx2 = addConstant(&chunk, value_h.numberVal(3.0));

    chunk.write(@intFromEnum(OpCode.OP_CONSTANT), 1);
    chunk.write(idx1, 1);
    chunk.write(@intFromEnum(OpCode.OP_CONSTANT), 1);
    chunk.write(idx2, 1);
    chunk.write(@intFromEnum(OpCode.OP_ADD), 1);
    chunk.write(@intFromEnum(OpCode.OP_RETURN), 1);

    // Optimize
    _ = bytecode_optimizer.optimizeDefault(&chunk);

    // After optimization, should have a constant with value 8.0
    // The last constant added should be the result
    const result_val = chunk.constants.values.?[chunk.constants.count - 1];
    try testing.expect(value_h.isNumber(result_val));
    try testing.expectEqual(@as(f64, 8.0), value_h.asNumber(result_val));
}

test "optimizer: stats tracking accurate" {
    var chunk = createTestChunk();
    defer chunk.free();

    // Generate multiple optimizable patterns
    const idx1 = addConstant(&chunk, value_h.numberVal(5.0));
    const idx2 = addConstant(&chunk, value_h.numberVal(3.0));

    // Pattern 1: CONSTANT + CONSTANT + ADD (foldable)
    chunk.write(@intFromEnum(OpCode.OP_CONSTANT), 1);
    chunk.write(idx1, 1);
    chunk.write(@intFromEnum(OpCode.OP_CONSTANT), 1);
    chunk.write(idx2, 1);
    chunk.write(@intFromEnum(OpCode.OP_ADD), 1);

    // Pattern 2: CONSTANT + POP (eliminable)
    const idx3 = addConstant(&chunk, value_h.numberVal(10.0));
    chunk.write(@intFromEnum(OpCode.OP_CONSTANT), 1);
    chunk.write(idx3, 1);
    chunk.write(@intFromEnum(OpCode.OP_POP), 1);

    chunk.write(@intFromEnum(OpCode.OP_RETURN), 1);

    const original_size = chunk.count;

    // Optimize
    const stats = bytecode_optimizer.optimizeDefault(&chunk);

    // Verify stats
    try testing.expect(stats.original_size == original_size);
    try testing.expect(stats.final_size < original_size);
    try testing.expect(stats.total_bytes_saved == original_size - stats.final_size);
    try testing.expect(stats.passes_performed > 0);
}
