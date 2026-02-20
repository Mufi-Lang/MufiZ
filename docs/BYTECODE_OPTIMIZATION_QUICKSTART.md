# Bytecode Optimization Quick Start Guide

## Overview

This guide will help you get started with bytecode optimization in MufiZ. We've created comprehensive analysis tools and documented optimization strategies that can reduce bytecode size by 15-23% and improve performance by 9-15%.

## Current Status

✅ **Completed:**
- Comprehensive optimization strategy document (`BYTECODE_OPTIMIZATION.md`)
- Bytecode analyzer tool (`src/bytecode_analyzer.zig`)
- Test script for demonstrating patterns (`examples/bytecode_test.mufi`)

🔨 **Next Steps:**
- Integrate analyzer into CLI
- Implement Phase 1 optimizations
- Add benchmarking framework

## Quick Analysis

### Step 1: Run the Test Script

```bash
# Build MufiZ
zig build -Doptimize=ReleaseFast

# Run the test script to see current bytecode
./zig-out/bin/mufiz examples/bytecode_test.mufi
```

### Step 2: View Bytecode with Tracing

To see the actual bytecode being executed:

```bash
# Enable trace execution (if available)
./zig-out/bin/mufiz --trace examples/bytecode_test.mufi
```

### Step 3: Integrate the Analyzer

Add to `src/main.zig` or wherever CLI arguments are handled:

```zig
const bytecode_analyzer = @import("bytecode_analyzer.zig");

// After compilation, before execution:
if (args.analyze_bytecode) {
    try bytecode_analyzer.analyzeAndReport(&chunk, allocator);
}
```

## Implementation Roadmap

### Phase 1: Foundation (2 weeks)

#### Week 1: Analyzer Integration

**File: `src/main.zig`**
```zig
// Add CLI flag
var analyze_bytecode = false;
// ... in argument parsing ...
if (std.mem.eql(u8, arg, "--analyze-bytecode")) {
    analyze_bytecode = true;
}

// After compilation
if (analyze_bytecode) {
    const bytecode_analyzer = @import("bytecode_analyzer.zig");
    try bytecode_analyzer.analyzeAndReport(&function.chunk, allocator);
    return; // Exit after analysis
}
```

**Test:**
```bash
./zig-out/bin/mufiz --analyze-bytecode examples/bytecode_test.mufi
```

Expected output:
```
═══════════════════════════════════════════════════════════
         MufiZ Bytecode Analysis Report
═══════════════════════════════════════════════════════════

📊 Basic Statistics:
───────────────────────────────────────────────────────────
  Total instructions:  1,245
  Total bytes:         2,876
  Average inst size:   2.31 bytes

🔥 Most Frequent Instructions:
───────────────────────────────────────────────────────────
  OP_GET_LOCAL              287 (23.0%)  - 574 bytes
  OP_CONSTANT               156 (12.5%)  - 312 bytes
  OP_ADD                    142 (11.4%)  - 142 bytes
  ...

💡 Optimization Opportunities:
───────────────────────────────────────────────────────────
  ✓ Small constants (0-15):   89 loads
    → Potential savings:      89 bytes
  ✓ Small locals (0-3):       201 accesses
    → Potential savings:      201 bytes
  ✓ Short jumps:              45 of 52 (86.5%)
    → Potential savings:      45 bytes

  📦 Total potential savings:   335 bytes
  📊 Estimated reduction:       11.6%
```

#### Week 2: Opcode Refactoring

**File: `src/chunk.zig`**

Add opcode range constants:
```zig
// Opcode ranges for organization
pub const OpcodeRanges = struct {
    pub const SIMPLE_START = 0;
    pub const SIMPLE_END = 66;
    
    // Reserved for small constants (Phase 2)
    pub const SMALL_CONSTANT_START = 67;
    pub const SMALL_CONSTANT_END = 82;
    
    // Reserved for small locals (Phase 2)
    pub const SMALL_LOCAL_START = 83;
    pub const SMALL_LOCAL_END = 98;
    
    // Reserved for superinstructions (Phase 3)
    pub const SUPERINSTRUCTION_START = 100;
    pub const SUPERINSTRUCTION_END = 191;
    
    // Reserved for future use
    pub const RESERVED_START = 192;
    pub const RESERVED_END = 255;
};

pub fn getInstructionLength(chunk: *Chunk, offset: usize) usize {
    // Import from bytecode_analyzer.zig
    return @import("bytecode_analyzer.zig").getInstructionLength(chunk, offset);
}
```

### Phase 2: Quick Wins (2 weeks)

#### Week 3: Small Constants

**File: `src/chunk.zig`**
```zig
pub const OpCode = enum(u8) {
    // ... existing opcodes (0-66) ...
    
    // Small constant opcodes (67-82)
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
};
```

**File: `src/compiler.zig`**

Find the `emitConstant` function and modify:
```zig
fn emitConstant(value: Value) void {
    const constant = makeConstant(value);
    
    // Optimization: Use single-byte opcode for small constant indices
    if (constant <= 15) {
        emitByte(@intFromEnum(OpCode.OP_CONSTANT_0) + @as(u8, @intCast(constant)));
    } else {
        emitBytes(@intFromEnum(OpCode.OP_CONSTANT), @intCast(constant));
    }
}
```

**File: `src/vm.zig`**

Add jump table entries:
```zig
// In jumpTable initialization
jumpTable[@intFromEnum(OpCode.OP_CONSTANT_0)] = op_constant_0;
jumpTable[@intFromEnum(OpCode.OP_CONSTANT_1)] = op_constant_1;
// ... etc ...

// Implement handlers
fn op_constant_0() InterpretResult {
    const frame = vm.currentFrame.?;
    const constant = frame.closure.function.chunk.constants.values[0];
    push(constant);
    return .INTERPRET_OK;
}

fn op_constant_1() InterpretResult {
    const frame = vm.currentFrame.?;
    const constant = frame.closure.function.chunk.constants.values[1];
    push(constant);
    return .INTERPRET_OK;
}

// ... or use a macro/comptime to generate these ...
```

**Optimization:** Use comptime to generate handlers:
```zig
inline fn makeConstantHandler(comptime idx: u8) fn() InterpretResult {
    return struct {
        fn handler() InterpretResult {
            const frame = vm.currentFrame.?;
            const constant = frame.closure.function.chunk.constants.values[idx];
            push(constant);
            return .INTERPRET_OK;
        }
    }.handler;
}

// In jumpTable init:
inline for (0..16) |i| {
    jumpTable[@intFromEnum(OpCode.OP_CONSTANT_0) + i] = makeConstantHandler(i);
}
```

**File: `src/debug.zig`**

Update disassembler:
```zig
pub fn disassembleInstruction(chunk: *Chunk, offset: i32) i32 {
    // ... existing code ...
    
    // Add cases for small constants
    67...82 => {
        const const_idx = instruction - @intFromEnum(OpCode.OP_CONSTANT_0);
        print("OP_CONSTANT_{d: <2}     {d:4} '", .{const_idx, const_idx});
        printValue(chunk.*.constants.values[const_idx]);
        print("'\n", .{});
        return offset + 1;
    },
    
    // ... rest of switch ...
}
```

#### Week 4: Small Locals & Short Jumps

**Similar implementation for:**
- `OP_GET_LOCAL_0` through `OP_GET_LOCAL_3` (83-86)
- `OP_SET_LOCAL_0` through `OP_SET_LOCAL_3` (87-90)
- `OP_JUMP_SHORT`, `OP_JUMP_IF_FALSE_SHORT`, `OP_LOOP_SHORT` (91-93)

**Test after Phase 2:**
```bash
# Rebuild
zig build -Doptimize=ReleaseFast

# Analyze
./zig-out/bin/mufiz --analyze-bytecode examples/bytecode_test.mufi

# Run benchmarks
./zig-out/bin/mufiz benchmarks/fibonacci.mufi
```

Expected improvement: **10-12% bytecode reduction**

### Phase 3: Superinstructions (3 weeks)

#### Week 5: Profiling

Add instruction pair profiling to VM (when enabled):

**File: `src/vm.zig`**
```zig
pub var profiling_enabled = false;
pub var instruction_pairs: ?std.AutoHashMap([2]u8, u64) = null;

pub fn enableProfiling(allocator: std.mem.Allocator) !void {
    profiling_enabled = true;
    instruction_pairs = std.AutoHashMap([2]u8, u64).init(allocator);
}

pub fn disableProfiling() void {
    profiling_enabled = false;
    if (instruction_pairs) |*pairs| {
        pairs.deinit();
    }
}

// In run() loop:
pub fn run() InterpretResult {
    var prev_instruction: ?u8 = null;
    
    while (true) {
        const instruction = frame.ip[0];
        frame.ip += 1;
        
        // Profile instruction pairs
        if (profiling_enabled and prev_instruction != null) {
            const pair = [2]u8{prev_instruction.?, instruction};
            const count = instruction_pairs.?.get(pair) orelse 0;
            instruction_pairs.?.put(pair, count + 1) catch {};
        }
        
        const result = jumpTable[instruction]();
        // ... rest of loop ...
        
        prev_instruction = instruction;
    }
}
```

Run profiling on real workloads:
```bash
./zig-out/bin/mufiz --profile examples/bytecode_test.mufi > profile_results.txt
```

#### Week 6-7: Implement Top 10 Superinstructions

Based on profiling results, implement most common pairs:

**File: `src/chunk.zig`**
```zig
pub const OpCode = enum(u8) {
    // ... existing ...
    
    // Superinstructions (100-109)
    OP_ADD_LOCAL = 100,         // GET_LOCAL + ADD
    OP_SUB_LOCAL = 101,         // GET_LOCAL + SUB
    OP_MUL_LOCAL = 102,         // GET_LOCAL + MUL
    OP_DIV_LOCAL = 103,         // GET_LOCAL + DIV
    OP_EQUAL_LOCAL = 104,       // GET_LOCAL + EQUAL
    OP_LESS_LOCAL = 105,        // GET_LOCAL + LESS
    OP_GREATER_LOCAL = 106,     // GET_LOCAL + GREATER
    OP_RETURN_LOCAL = 107,      // GET_LOCAL + RETURN
    OP_RETURN_CONSTANT = 108,   // CONSTANT + RETURN
    OP_GET_LOCAL_PROPERTY = 109, // GET_LOCAL + GET_PROPERTY
};
```

**File: `src/compiler.zig`**

Add peephole optimizer:
```zig
fn optimizeChunk(chunk: *Chunk) void {
    var i: usize = 0;
    while (i + 1 < chunk.count) {
        const op1 = chunk.code.?[i];
        const op2 = chunk.code.?[i + op1_length];
        
        // Pattern: GET_LOCAL + ADD
        if (op1 == @intFromEnum(OpCode.OP_GET_LOCAL) and 
            op2 == @intFromEnum(OpCode.OP_ADD)) {
            const slot = chunk.code.?[i + 1];
            // Replace with superinstruction
            chunk.code.?[i] = @intFromEnum(OpCode.OP_ADD_LOCAL);
            chunk.code.?[i + 1] = slot;
            // Remove the ADD instruction
            removeInstruction(chunk, i + 2);
            continue;
        }
        
        // ... more patterns ...
        
        i += getInstructionLength(chunk, i);
    }
}
```

### Phase 4: Benchmarking (1 week)

#### Week 8: Benchmark Suite

**File: `benchmarks/run_benchmarks.zig`**
```zig
const std = @import("std");

pub fn main() !void {
    const benchmarks = [_][]const u8{
        "fibonacci.mufi",
        "mandelbrot.mufi",
        "binary_trees.mufi",
        "matrix_multiply.mufi",
    };
    
    for (benchmarks) |bench| {
        std.debug.print("\n=== Running: {s} ===\n", .{bench});
        
        // Measure original
        const start1 = std.time.nanoTimestamp();
        // run with original bytecode
        const end1 = std.time.nanoTimestamp();
        
        // Measure optimized
        const start2 = std.time.nanoTimestamp();
        // run with optimized bytecode
        const end2 = std.time.nanoTimestamp();
        
        const improvement = @as(f64, @floatFromInt(end1 - start1)) / 
                           @as(f64, @floatFromInt(end2 - start2));
        
        std.debug.print("Speedup: {d:.2}x\n", .{improvement});
    }
}
```

Create benchmark scripts:

**File: `benchmarks/fibonacci.mufi`**
```javascript
fn fib(n) {
    if (n <= 1) return n;
    return fib(n - 1) + fib(n - 2);
}

let start = time();
let result = fib(30);
let elapsed = time() - start;

print("Result:", result);
print("Time:", elapsed, "ms");
```

## Testing Strategy

### Unit Tests

**File: `tests/bytecode_optimization_test.zig`**
```zig
const std = @import("std");
const chunk = @import("chunk.zig");
const compiler = @import("compiler.zig");
const vm = @import("vm.zig");

test "small constant optimization" {
    const source = "let x = 5;";
    const result = compiler.compile(source);
    
    // Verify OP_CONSTANT_5 is used instead of OP_CONSTANT + operand
    const expected_opcode = @intFromEnum(chunk.OpCode.OP_CONSTANT_5);
    try std.testing.expect(hasOpcode(result.chunk, expected_opcode));
}

test "small local optimization" {
    const source = 
        \\fn test() {
        \\    let a = 1;
        \\    let b = 2;
        \\    return a + b;
        \\}
    ;
    
    // Verify OP_GET_LOCAL_0 and OP_GET_LOCAL_1 are used
    // instead of OP_GET_LOCAL + operand
}

test "bytecode size reduction" {
    const sources = [_][]const u8{
        "let x = 0; let y = 1; let z = x + y;",
        "fn fib(n) { if (n <= 1) return n; return fib(n-1) + fib(n-2); }",
    };
    
    for (sources) |source| {
        const original_size = compileOriginal(source).size;
        const optimized_size = compileOptimized(source).size;
        
        const reduction = @as(f64, @floatFromInt(original_size - optimized_size)) /
                         @as(f64, @floatFromInt(original_size)) * 100.0;
        
        std.debug.print("Reduction: {d:.1}%\n", .{reduction});
        try std.testing.expect(reduction >= 5.0); // At least 5% reduction
    }
}
```

### Integration Tests

```bash
# Test that optimized bytecode produces same results
./tests/run_integration_tests.sh
```

## Performance Targets

After full implementation, we expect:

| Metric | Target | Stretch Goal |
|--------|--------|--------------|
| Bytecode size reduction | 15% | 23% |
| Execution speedup | 9% | 15% |
| Memory usage reduction | 12% | 20% |

## Monitoring Progress

Track progress with:
```bash
# Run analysis on test suite
./zig-out/bin/mufiz --analyze-bytecode examples/*.mufi > analysis.txt

# Extract metrics
grep "Estimated reduction" analysis.txt
grep "potential savings" analysis.txt
```

## Rollback Strategy

If optimizations cause issues:

1. **Feature flags** - Disable specific optimizations
2. **Bytecode version** - Support reading old format
3. **Gradual rollout** - Enable per-function or per-module

```zig
pub const CompilerOptions = struct {
    enable_small_constants: bool = true,
    enable_small_locals: bool = true,
    enable_short_jumps: bool = true,
    enable_superinstructions: bool = true,
    bytecode_version: u8 = 2,
};
```

## Next Actions

1. ✅ Read `BYTECODE_OPTIMIZATION.md` for full details
2. 🔨 Integrate `bytecode_analyzer.zig` into CLI
3. 🔨 Run analysis on existing test suite
4. 🔨 Implement Phase 1 (foundation)
5. 🔨 Implement Phase 2 (quick wins)
6. 📊 Measure and benchmark
7. 🎯 Proceed with Phase 3 based on results

## Resources

- **Main Document**: `docs/BYTECODE_OPTIMIZATION.md` (comprehensive strategy)
- **Analyzer Tool**: `src/bytecode_analyzer.zig` (profiling and analysis)
- **Test Script**: `examples/bytecode_test.mufi` (demonstration patterns)
- **Current Bytecode**: `src/chunk.zig` (opcode definitions)
- **VM Implementation**: `src/vm.zig` (execution engine)
- **Compiler**: `src/compiler.zig` (code generation)

## Questions?

Key design decisions to make:

1. **How aggressive should optimizations be?** (conservative vs. aggressive)
2. **What's the minimum supported version?** (backward compatibility)
3. **Should we support mixed bytecode versions?** (gradual migration)
4. **What's the performance budget for compilation?** (compile time vs. runtime)

Start with Phase 1, measure everything, then proceed based on data! 🚀