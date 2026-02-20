# Advanced Optimization Roadmap for MufiZ VM
## Phases 5-10: From Bytecode to JIT Compilation

**Document Version:** 1.0  
**Last Updated:** 2024  
**Status:** Planning & Design Phase

---

## Executive Summary

This document outlines the roadmap for transforming the MufiZ VM from a bytecode interpreter with basic optimizations (Phases 1-4) into a high-performance, production-ready virtual machine with advanced optimizations and JIT compilation capabilities. The roadmap is divided into 6 major phases, each building upon the previous one.

**Timeline:** 18-24 months  
**Goal:** Achieve 5-10x performance improvement over Phase 4  
**Complexity:** High - Requires significant compiler infrastructure

---

## Current State (Phase 4 Complete)

### What We Have
- ✅ Bytecode compiler with single-pass compilation
- ✅ Stack-based VM with efficient dispatch
- ✅ Superinstruction fusion (Phase 3)
- ✅ Constant folding at bytecode level
- ✅ Peephole optimizations
- ✅ Basic dead code elimination
- ✅ Multi-pass optimization framework

### Performance Baseline
- **Bytecode Interpretation Speed:** ~50-100 million instructions/sec
- **Bytecode Size:** 10-20% optimized from raw compilation
- **Memory Usage:** Stack-based, minimal heap allocation
- **Startup Time:** < 10ms for typical programs

### Limitations
- ❌ No control flow analysis
- ❌ No dataflow analysis
- ❌ No loop-specific optimizations
- ❌ No function inlining
- ❌ No JIT compilation
- ❌ No adaptive optimization
- ❌ Limited cross-function optimization

---

## Phase 5: Control Flow Graph (CFG) Analysis
**Duration:** 3-4 months  
**Complexity:** Medium  
**Foundation for:** All subsequent phases

### Goals
Build a comprehensive control flow graph analysis infrastructure that enables advanced optimizations and serves as the foundation for dataflow analysis and JIT compilation.

### Components

#### 5.1 CFG Construction (Week 1-3)

**Data Structures:**
```zig
pub const BasicBlock = struct {
    id: usize,
    start_offset: usize,
    end_offset: usize,
    instructions: []Instruction,
    predecessors: []usize,  // IDs of blocks that jump here
    successors: []usize,    // IDs of blocks this jumps to
    dominators: []usize,    // Blocks that dominate this one
    loop_depth: usize,
    is_loop_header: bool,
};

pub const ControlFlowGraph = struct {
    blocks: []BasicBlock,
    entry_block: usize,
    exit_blocks: []usize,
    loop_headers: []usize,
    back_edges: []Edge,
};
```

**Algorithm:**
1. Scan bytecode to identify basic block boundaries
2. Identify leaders (start of basic blocks):
   - First instruction
   - Targets of jumps
   - Instructions following jumps
3. Build edges between blocks
4. Compute dominance relationships

**Implementation Files:**
- `src/cfg_builder.zig` (400-600 lines)
- `src/cfg_analysis.zig` (300-500 lines)
- `tests/test_cfg.zig` (200-300 lines)

#### 5.2 Dominance Analysis (Week 4-5)

**Purpose:** Identify which blocks always execute before others

**Algorithms:**
- **Immediate Dominator Tree:** O(n²) or O(n log n) with Lengauer-Tarjan
- **Dominance Frontier:** For SSA construction (Phase 6)
- **Post-Dominance:** For control dependence analysis

**Use Cases:**
- Loop detection
- Dead code elimination (improved)
- Code motion safety analysis

#### 5.3 Loop Detection & Analysis (Week 6-7)

**Natural Loop Detection:**
```zig
pub const Loop = struct {
    header: usize,          // Loop header block
    back_edges: []Edge,     // Edges that define the loop
    body: []usize,          // All blocks in loop body
    depth: usize,           // Nesting level
    parent: ?*Loop,         // Enclosing loop (if any)
    children: []*Loop,      // Nested loops
    
    // Analysis results
    is_reducible: bool,     // Can be optimized?
    trip_count: ?usize,     // Known iteration count
    invariants: []usize,    // Loop-invariant instructions
};
```

**Analysis Passes:**
1. **Identify back edges** (edges to dominator)
2. **Compute natural loops** (header + all nodes that reach back edge)
3. **Nest loops** (build loop tree hierarchy)
4. **Classify loops:**
   - Counted loops (for i = 0; i < N; i++)
   - While loops
   - Do-while loops
   - Infinite loops

**Metrics to Track:**
- Loop depth (nesting level)
- Trip count (iterations)
- Loop-invariant operations
- Memory access patterns

#### 5.4 Improved Dead Code Elimination (Week 8-9)

**CFG-Based DCE:**
```zig
pub fn eliminateUnreachableCode(cfg: *ControlFlowGraph) usize {
    // Mark reachable blocks from entry
    var reachable = std.AutoHashMap(usize, void).init(allocator);
    var worklist = std.ArrayList(usize).init(allocator);
    worklist.append(cfg.entry_block);
    
    while (worklist.popOrNull()) |block_id| {
        if (reachable.contains(block_id)) continue;
        reachable.put(block_id, {});
        
        const block = cfg.blocks[block_id];
        for (block.successors) |succ| {
            worklist.append(succ);
        }
    }
    
    // Remove unreachable blocks
    return removeUnreachableBlocks(cfg, &reachable);
}
```

**Improvements over Phase 4:**
- Accurate identification of unreachable code
- Handles complex control flow (nested conditionals, loops)
- Removes entire unreachable regions
- Doesn't accidentally remove jump targets

#### 5.5 Control Flow Simplification (Week 10-11)

**Optimizations:**
1. **Block merging:** Combine blocks with single predecessor/successor
2. **Empty block elimination:** Remove blocks with only jumps
3. **Jump threading:** Optimize chains of conditional jumps
4. **Switch/case optimization:** Build jump tables for dense cases

**Example:**
```
Before:
  Block A: JUMP Block B
  Block B: JUMP Block C
  Block C: actual code

After:
  Block A: JUMP Block C
  Block C: actual code
```

#### 5.6 Testing & Validation (Week 12)

**Test Coverage:**
- Simple linear code (no branches)
- Conditionals (if/else)
- Loops (for, while, do-while)
- Nested loops
- Complex control flow (switch, break, continue)
- Recursive functions
- Exception handling

**Validation:**
- CFG correctness (all paths covered)
- Loop detection accuracy
- DCE safety (no incorrect removals)
- Performance benchmarks

### Expected Improvements
- **Bytecode Size:** Additional 5-10% reduction (beyond Phase 4)
- **Runtime:** 10-15% improvement from better DCE
- **Foundation:** Enables Phase 6+ optimizations

### Deliverables
- ✅ CFG construction and analysis infrastructure
- ✅ Dominance analysis
- ✅ Loop detection and classification
- ✅ Improved DCE based on reachability
- ✅ Control flow simplification
- ✅ Comprehensive test suite
- ✅ Documentation and examples

---

## Phase 6: Dataflow Analysis & SSA Form
**Duration:** 4-5 months  
**Complexity:** High  
**Foundation for:** Constant propagation, dead store elimination, register allocation

### Goals
Implement Static Single Assignment (SSA) form and dataflow analysis to enable sophisticated optimizations that track how values flow through the program.

### Components

#### 6.1 SSA Construction (Week 1-6)

**What is SSA?**
Each variable is assigned exactly once, with φ-functions at control flow merge points.

**Example:**
```javascript
// Before SSA
var x = 5;
if (condition) {
    x = 10;
}
print x;

// After SSA
var x₁ = 5;
if (condition) {
    x₂ = 10;
}
x₃ = φ(x₁, x₂);  // φ selects based on control flow
print x₃;
```

**Algorithm:** Minimal SSA (Cytron et al.)
1. Compute dominance frontiers
2. Insert φ-functions at merge points
3. Rename variables (versioning)

**Data Structure:**
```zig
pub const SSAValue = struct {
    id: usize,
    version: usize,
    original_name: []const u8,
    def_site: usize,        // Basic block where defined
    use_sites: []usize,     // Blocks where used
};

pub const PhiFunction = struct {
    result: SSAValue,
    operands: []SSAValue,   // One per predecessor
    block: usize,
};
```

#### 6.2 Reaching Definitions Analysis (Week 7-8)

**Purpose:** Track which definitions of variables reach which points in the program

**Algorithm:** Iterative dataflow analysis
```zig
pub fn computeReachingDefinitions(cfg: *ControlFlowGraph) ReachingDefs {
    var changed = true;
    while (changed) {
        changed = false;
        for (cfg.blocks) |*block| {
            const new_in = computeIn(block);
            const new_out = computeOut(block);
            if (!equal(block.in, new_in) or !equal(block.out, new_out)) {
                block.in = new_in;
                block.out = new_out;
                changed = true;
            }
        }
    }
}
```

#### 6.3 Live Variable Analysis (Week 9-10)

**Purpose:** Determine which variables are live (may be used) at each program point

**Use Cases:**
- Register allocation (which values need storage)
- Dead store elimination (stores to dead variables)
- Interference graph construction

**Backward Dataflow:**
```zig
pub fn computeLiveVariables(cfg: *ControlFlowGraph) LiveVars {
    // Work backwards from exit blocks
    for (cfg.blocks) |*block| {
        block.live_out = union_of_successors_live_in();
        block.live_in = (block.live_out - block.kill) ∪ block.gen;
    }
}
```

#### 6.4 Constant Propagation (Week 11-14)

**Sparse Conditional Constant Propagation (SCCP):**

Combines:
- Constant propagation (track constant values)
- Dead code elimination (remove unreachable code)

**Algorithm:**
```zig
pub fn constantPropagation(cfg: *ControlFlowGraph) void {
    var lattice = std.AutoHashMap(SSAValue, LatticeValue).init(allocator);
    var ssa_worklist = std.ArrayList(SSAValue).init(allocator);
    var cfg_worklist = std.ArrayList(Edge).init(allocator);
    
    // Initialize: all values are ⊤ (unknown)
    for (cfg.getAllSSAValues()) |value| {
        lattice.put(value, .top);
    }
    
    // Process until convergence
    while (ssa_worklist.items.len > 0 or cfg_worklist.items.len > 0) {
        // Process SSA edges (value definitions)
        if (ssa_worklist.popOrNull()) |value| {
            for (value.use_sites) |use| {
                evaluateInstruction(use, &lattice, &ssa_worklist, &cfg_worklist);
            }
        }
        
        // Process CFG edges (control flow)
        if (cfg_worklist.popOrNull()) |edge| {
            if (isExecutable(edge, &lattice)) {
                visitBlock(edge.to, &lattice, &ssa_worklist, &cfg_worklist);
            }
        }
    }
    
    // Replace constants and remove dead code
    rewriteProgram(cfg, &lattice);
}
```

**Lattice Values:**
```zig
pub const LatticeValue = union(enum) {
    top,            // Unknown/uninitialized
    constant: Value, // Known constant value
    bottom,         // Not constant (runtime value)
};
```

**Example:**
```javascript
// Before
var a = 5;
var b = 3;
var c = a + b;  // Can be replaced with 8
var d = input();
var e = c + d;  // Cannot fold (d is runtime)

// After
var a = 5;
var b = 3;
var c = 8;      // Propagated!
var d = input();
var e = 8 + d;  // c replaced with 8
```

#### 6.5 Copy Propagation (Week 15)

**Purpose:** Replace uses of copies with original values

**Example:**
```javascript
// Before
var x = 5;
var y = x;      // Copy
var z = y + 1;  // Use copy

// After
var x = 5;
var y = x;
var z = x + 1;  // Use original
```

**Enables further optimization:**
```javascript
// After copy propagation + dead store elimination
var x = 5;
var z = x + 1;  // y eliminated entirely
```

#### 6.6 Dead Store Elimination (Week 16-17)

**Purpose:** Remove stores to variables that are never read

**Algorithm:**
1. Compute live variables
2. Remove stores where value is not live-out
3. Handle side effects carefully

**Example:**
```javascript
// Before
var x = 5;      // Dead store
x = 10;
print x;

// After
x = 10;
print x;
```

#### 6.7 Common Subexpression Elimination (Week 18-20)

**Global Value Numbering (GVN):**

**Example:**
```javascript
// Before
var a = x + y;
var b = x + y;  // Redundant computation

// After
var a = x + y;
var b = a;      // Reuse result
```

**Algorithm:**
1. Assign value numbers to expressions
2. Identify equivalent expressions
3. Replace redundant computations with copies

### Expected Improvements
- **Constant Folding:** Across basic blocks (not just local)
- **Dead Code:** Eliminate 20-30% more dead stores
- **Runtime:** 15-25% improvement from constant propagation
- **Bytecode Size:** Additional 10-15% reduction

### Deliverables
- ✅ SSA construction and deconstruction
- ✅ Reaching definitions analysis
- ✅ Live variable analysis
- ✅ Sparse conditional constant propagation
- ✅ Copy propagation
- ✅ Dead store elimination
- ✅ Common subexpression elimination
- ✅ Comprehensive test suite
- ✅ Benchmarks and performance analysis

---

## Phase 7: Loop Optimizations
**Duration:** 3-4 months  
**Complexity:** Medium-High  
**Prerequisite:** Phase 5 (CFG) and Phase 6 (Dataflow)

### Goals
Optimize loops, which are typically the hottest parts of programs and where most execution time is spent.

### Components

#### 7.1 Loop-Invariant Code Motion (LICM) (Week 1-4)

**Purpose:** Move computations that don't change inside loop to outside

**Example:**
```javascript
// Before
for (var i = 0; i < 100; i++) {
    var x = a + b;  // Doesn't depend on i
    array[i] = x * i;
}

// After (hoisted)
var x = a + b;
for (var i = 0; i < 100; i++) {
    array[i] = x * i;
}
```

**Algorithm:**
1. Identify loop-invariant instructions (operands defined outside loop)
2. Check safety (no side effects, dominates all exits)
3. Move to preheader block

**Conditions for LICM:**
- Instruction's operands are invariant
- Instruction dominates all loop exits (always executes)
- No other instruction in loop uses the result before reassignment

#### 7.2 Strength Reduction (Week 5-7)

**Purpose:** Replace expensive operations with cheaper ones

**Examples:**

**Multiplication → Addition:**
```javascript
// Before
for (var i = 0; i < 100; i++) {
    var x = i * 4;
}

// After
var x = 0;
for (var i = 0; i < 100; i++) {
    // x = i * 4, but computed incrementally
    x = x + 4;
}
```

**Division → Multiplication:**
```javascript
// Before
for (var i = 0; i < 100; i++) {
    var x = i / 3;
}

// After
const inv = 1.0 / 3.0;
for (var i = 0; i < 100; i++) {
    var x = i * inv;  // Multiplication faster than division
}
```

#### 7.3 Induction Variable Optimization (Week 8-10)

**Purpose:** Optimize variables that change by a constant amount each iteration

**Basic Induction Variable:**
```javascript
for (var i = 0; i < N; i++) {
    // i is basic induction variable
}
```

**Derived Induction Variable:**
```javascript
for (var i = 0; i < N; i++) {
    var j = i * 4;  // Derived from i
    var k = i + 5;  // Derived from i
}
```

**Optimization:**
```javascript
// Convert derived IVs to basic IVs
var j = 0;
var k = 5;
for (var i = 0; i < N; i++, j += 4, k++) {
    // j and k updated directly
}
```

#### 7.4 Loop Unrolling (Week 11-13)

**Purpose:** Reduce loop overhead and enable other optimizations

**Full Unrolling (known small trip count):**
```javascript
// Before
for (var i = 0; i < 4; i++) {
    process(i);
}

// After
process(0);
process(1);
process(2);
process(3);
```

**Partial Unrolling:**
```javascript
// Before
for (var i = 0; i < N; i++) {
    a[i] = b[i] + c[i];
}

// After (unroll by 4)
for (var i = 0; i < N; i += 4) {
    a[i]   = b[i]   + c[i];
    a[i+1] = b[i+1] + c[i+1];
    a[i+2] = b[i+2] + c[i+2];
    a[i+3] = b[i+3] + c[i+3];
}
// Handle remainder: i to N
```

**Benefits:**
- Reduced branch overhead
- Better instruction-level parallelism
- Opportunity for vectorization

**Heuristics:**
- Unroll small loops (< 10 instructions body)
- Unroll factor: 2, 4, or 8
- Don't unroll if code size explosion

#### 7.5 Loop Fusion & Fission (Week 14-15)

**Loop Fusion (combine loops):**
```javascript
// Before
for (var i = 0; i < N; i++) {
    a[i] = b[i] + 1;
}
for (var i = 0; i < N; i++) {
    c[i] = a[i] * 2;
}

// After
for (var i = 0; i < N; i++) {
    a[i] = b[i] + 1;
    c[i] = a[i] * 2;
}
```

**Benefits:** Better cache locality, fewer loop overhead

**Loop Fission (split loops):**
```javascript
// Before (large body)
for (var i = 0; i < N; i++) {
    a[i] = b[i] + c[i];  // Memory-bound
    d[i] = heavy_computation(i);  // CPU-bound
}

// After
for (var i = 0; i < N; i++) {
    a[i] = b[i] + c[i];
}
for (var i = 0; i < N; i++) {
    d[i] = heavy_computation(i);
}
```

**Benefits:** Better register allocation, parallelization opportunities

#### 7.6 Loop Interchange (Week 16-17)

**Purpose:** Improve cache locality by changing loop order

**Example (matrix operations):**
```javascript
// Before (poor cache locality)
for (var i = 0; i < N; i++) {
    for (var j = 0; j < N; j++) {
        sum += matrix[j][i];  // Column-major access
    }
}

// After (better cache locality)
for (var j = 0; j < N; j++) {
    for (var i = 0; i < N; i++) {
        sum += matrix[j][i];  // Row-major access
    }
}
```

**Legality Check:** Ensure loop interchange doesn't change semantics (dependency analysis)

### Expected Improvements
- **Loop-Heavy Code:** 30-50% speedup
- **Numeric Code:** 40-60% speedup (with unrolling + strength reduction)
- **General Code:** 10-20% average improvement

### Deliverables
- ✅ Loop-invariant code motion
- ✅ Strength reduction
- ✅ Induction variable optimization
- ✅ Loop unrolling (full and partial)
- ✅ Loop fusion and fission
- ✅ Loop interchange
- ✅ Comprehensive test suite
- ✅ Benchmarks on numeric and loop-heavy workloads

---

## Phase 8: Interprocedural Optimization (IPO)
**Duration:** 3-4 months  
**Complexity:** High  
**Prerequisite:** Phases 5, 6, 7

### Goals
Optimize across function boundaries to enable inlining, devirtualization, and whole-program optimization.

### Components

#### 8.1 Call Graph Construction (Week 1-2)

**Purpose:** Track relationships between functions

```zig
pub const CallGraph = struct {
    nodes: []CallGraphNode,
    edges: []CallEdge,
    
    pub const CallGraphNode = struct {
        function: *ObjFunction,
        callers: []usize,    // Who calls this function
        callees: []usize,    // Who this function calls
        is_recursive: bool,
        call_count: usize,   // Estimated call frequency
    };
    
    pub const CallEdge = struct {
        caller: usize,
        callee: usize,
        call_site: usize,    // Bytecode offset
        is_direct: bool,     // Direct vs indirect call
    };
};
```

#### 8.2 Function Inlining (Week 3-8)

**Purpose:** Replace function calls with function body

**Example:**
```javascript
// Before
function add(a, b) {
    return a + b;
}
function main() {
    var x = add(5, 3);  // Function call overhead
}

// After inlining
function main() {
    var x = 5 + 3;  // Direct computation
}
```

**Heuristics for Inlining:**
- Small functions (< 20 bytecode instructions)
- Frequently called functions
- Functions called once (always inline)
- Don't inline recursive functions (or limit depth)
- Don't inline if code size explosion (> 2x growth)

**Cost Model:**
```zig
pub fn shouldInline(callee: *ObjFunction, call_site: CallSite) bool {
    const size = callee.chunk.count;
    const call_freq = call_site.estimated_frequency;
    
    // Always inline tiny functions
    if (size < 10) return true;
    
    // Inline hot functions
    if (call_freq > 100 and size < 50) return true;
    
    // Inline single-call functions
    if (callee.call_count == 1 and size < 100) return true;
    
    // Don't inline large or cold functions
    return false;
}
```

#### 8.3 Constant Parameter Propagation (Week 9-11)

**Purpose:** Specialize functions for constant arguments

**Example:**
```javascript
function power(x, n) {
    if (n == 2) return x * x;  // Special case
    if (n == 3) return x * x * x;
    return Math.pow(x, n);
}

// Call site: power(x, 2) always passes 2
var y = power(x, 2);

// Specialize function
function power_2(x) {
    return x * x;  // n=2 is constant
}
var y = power_2(x);
```

#### 8.4 Devirtualization (Week 12-14)

**Purpose:** Convert virtual/dynamic calls to direct calls

**Example:**
```javascript
class Animal {
    speak() { return "..."; }
}
class Dog extends Animal {
    speak() { return "Woof!"; }
}

var animal = Dog();
animal.speak();  // Virtual call - which speak()?

// If we know animal is always Dog:
animal.Dog.speak();  // Direct call
```

**Class Hierarchy Analysis (CHA):**
- Build class hierarchy
- Determine possible types at each call site
- Convert to direct call if only one possibility

#### 8.5 Dead Function Elimination (Week 15-16)

**Purpose:** Remove unused functions

**Algorithm:**
1. Start from entry point (main)
2. Mark all reachable functions (via call graph)
3. Remove unmarked functions

**Example:**
```javascript
function used() {
    return 42;
}
function unused() {  // Never called
    return 100;
}
function main() {
    return used();
}

// After DFE: unused() is removed
```

#### 8.6 Tail Call Optimization (Week 17-18)

**Purpose:** Optimize tail-recursive calls to iteration

**Example:**
```javascript
// Before (uses stack)
function factorial(n, acc) {
    if (n == 0) return acc;
    return factorial(n - 1, acc * n);  // Tail call
}

// After (converted to loop)
function factorial(n, acc) {
    while (true) {
        if (n == 0) return acc;
        const new_n = n - 1;
        const new_acc = acc * n;
        n = new_n;
        acc = new_acc;
        // Continue loop (tail call eliminated)
    }
}
```

### Expected Improvements
- **Function Call Overhead:** 50-80% reduction (via inlining)
- **Small Functions:** Near elimination of call overhead
- **Overall Performance:** 20-40% improvement on function-heavy code

### Deliverables
- ✅ Call graph construction
- ✅ Function inlining with smart heuristics
- ✅ Constant parameter propagation
- ✅ Devirtualization (class hierarchy analysis)
- ✅ Dead function elimination
- ✅ Tail call optimization
- ✅ Test suite and benchmarks

---

## Phase 9: Profile-Guided Optimization (PGO)
**Duration:** 4-5 months  
**Complexity:** High  
**Prerequisite:** Phases 5-8

### Goals
Use runtime profiling data to guide optimization decisions, enabling adaptive and workload-specific optimizations.

### Components

#### 9.1 Instrumentation Framework (Week 1-4)

**Purpose:** Collect runtime execution data

**What to Instrument:**
- Basic block execution counts
- Branch taken/not-taken frequencies
- Function call counts
- Loop iteration counts
- Type information (for dynamic languages)

**Implementation:**
```zig
pub const ProfilingData = struct {
    block_counts: std.AutoHashMap(usize, u64),      // Block ID → count
    branch_outcomes: std.AutoHashMap(usize, BranchProfile),
    call_counts: std.AutoHashMap(*ObjFunction, u64),
    loop_trip_counts: std.AutoHashMap(usize, LoopProfile),
    
    pub const BranchProfile = struct {
        taken: u64,
        not_taken: u64,
        
        pub fn probability(self: *const BranchProfile) f64 {
            const total = self.taken + self.not_taken;
            return @as(f64, @floatFromInt(self.taken)) / @as(f64, @floatFromInt(total));
        }
    };
    
    pub const LoopProfile = struct {
        iterations: std.ArrayList(usize),  // Observed trip counts
        avg_iterations: f64,
        min_iterations: usize,
        max_iterations: usize,
    };
};
```

**Two-Phase Execution:**
1. **Instrumented Run:** Collect profiling data
   ```bash
   mufiz --profile=collect --profile-output=profile.data script.mz
   ```

2. **Optimized Run:** Use profile data for optimization
   ```bash
   mufiz --profile=use --profile-input=profile.data script.mz
   ```

#### 9.2 Hot Path Detection (Week 5-6)

**Purpose:** Identify frequently executed code paths

**Hot Spot Identification:**
```zig
pub fn identifyHotSpots(profile: *ProfilingData, threshold: f64) HotSpots {
    var hot_blocks = std.ArrayList(usize).init(allocator);
    var hot_functions = std.ArrayList(*ObjFunction).init(allocator);
    var hot_loops = std.ArrayList(usize).init(allocator);
    
    const total_execution = computeTotalExecution(profile);
    
    // Find blocks that account for > threshold% of execution
    for (profile.block_counts.entries()) |entry| {
        const percentage = @as(f64, @floatFromInt(entry.value)) / total_execution;
        if (percentage > threshold) {
            hot_blocks.append(entry.key);
        }
    }
    
    // Similar for functions and loops
    // ...
    
    return HotSpots{
        .blocks = hot_blocks.toOwnedSlice(),
        .functions = hot_functions.toOwnedSlice(),
        .loops = hot_loops.toOwnedSlice(),
    };
}
```

**Hot/Cold Code Segregation:**
- Place hot code in separate section (better cache locality)
- Minimize cold code pollution in instruction cache
- Optimize hot paths aggressively, ignore cold paths

#### 9.3 Branch Probability & Prediction (Week 7-9)

**Purpose:** Optimize branches based on likely outcome

**Example:**
```javascript
if (unlikely_condition) {  // Taken 1% of the time
    handle_error();
} else {                    // Taken 99% of the time
    normal_path();
}

// Optimize for common case
// Layout code so hot path is fall-through (no jump)
```

**Static Branch Prediction Hints:**
```zig
pub fn emitConditionalJump(
    compiler: *Compiler,
    condition: Value,
    true_target: usize,
    false_target: usize,
    profile: ?*BranchProfile
) void {
    if (profile) |p| {
        const prob = p.probability();
        if (prob > 0.8) {
            // Branch likely taken - optimize for true path
            compiler.emitJump(OP_JUMP_IF_FALSE_UNLIKELY, false_target);
        } else if (prob < 0.2) {
            // Branch rarely taken - optimize for false path
            compiler.emitJump(OP_JUMP_IF_TRUE_UNLIKELY, true_target);
        } else {
            // Branch unpredictable - use default
            compiler.emitJump(OP_JUMP_IF_FALSE, false_target);
        }
    }
}
```

#### 9.4 Profile-Guided Inlining (Week 10-12)

**Purpose:** Inline based on actual call frequency

**Hot Call Site Inlining:**
```zig
pub fn shouldInlineWithProfile(
    callee: *ObjFunction,
    call_site: CallSite,
    profile: *ProfilingData
) bool {
    const call_count = profile.call_counts.get(callee) orelse 0;
    const site_count = profile.block_counts.get(call_site.block) orelse 0;
    
    // Inline if this call site is hot
    if (site_count > 1000 and callee.chunk.count < 100) {
        return true;
    }
    
    // Don't inline cold call sites even if function is small
    if (site_count < 10) {
        return false;
    }
    
    // Use default heuristics
    return shouldInline(callee, call_site);
}
```

#### 9.5 Specialization & Versioning (Week 13-16)

**Purpose:** Create optimized versions of functions for common inputs

**Type Specialization (for dynamic languages):**
```javascript
function add(a, b) {
    return a + b;  // Generic: handles int, double, string, etc.
}

// Profile shows: 95% of calls have (int, int)
// Create specialized version:
function add_int_int(a: int, b: int) {
    return a + b;  // Optimized for integers only
}

// At call site, check types and dispatch:
if (typeof(a) == 'int' && typeof(b) == 'int') {
    return add_int_int(a, b);  // Fast path
} else {
    return add(a, b);          // Slow path
}
```

**Value Specialization:**
```javascript
function compute(size) {
    var result = 0;
    for (var i = 0; i < size; i++) {
        result += i;
    }
    return result;
}

// Profile shows: size is always 100
// Create specialized version with loop unrolling
```

#### 9.6 Feedback-Directed Optimization (Week 17-20)

**Iterative Optimization:**
1. Compile with instrumentation
2. Run and collect profile
3. Recompile with profile data
4. Repeat to refine

**Adaptive Optimization:**
- Monitor execution characteristics at runtime
- Reoptimize hot functions on-the-fly
- Deoptimize if assumptions violated

### Expected Improvements
- **Overall Performance:** 30-50% improvement over static optimization
- **Hot Path Performance:** 50-100% improvement
- **Cache Efficiency:** 40-60% better instruction cache hit rate
- **Branch Prediction:** 20-30% improvement in branch prediction accuracy

### Deliverables
- ✅ Instrumentation framework
- ✅ Profile data collection and storage
- ✅ Hot spot identification
- ✅ Profile-guided inlining
- ✅ Branch probability optimization
- ✅ Function specialization
- ✅ Comprehensive test suite
- ✅ Benchmarks with real-world workloads

---

## Phase 10: JIT Compilation
**Duration:** 6-8 months  
**Complexity:** Very High  
**Prerequisite:** All previous phases

### Goals
Implement Just-In-Time compilation to generate native machine code at runtime, achieving near-native performance.

### Components

#### 10.1 Intermediate Representation (IR) Design (Week 1-4)

**Purpose:** Design a low-level IR suitable for machine code generation

**IR Characteristics:**
- Register-based (not stack-based)
- Three-address code format
- Explicit control flow
- Target-independent (portable across architectures)

**Example IR:**
```
// Source: var x = a + b * 2;
// IR:
%1 = load a
%2 = load b
%3 = mul %2, 2
%4 = add %1, %3
store %4, x
```

**IR Instruction Format:**
```zig
pub const IRInstruction = struct {
    opcode: IROpCode,
    result: Register,
    operand1: Operand,
    operand2: Operand,
    type: ValueType,
};

pub const IROpCode = enum {
    // Arithmetic
    ADD, SUB, MUL, DIV, MOD,
    // Comparison
    EQ, NE, LT, LE, GT, GE,
    // Memory
    LOAD, STORE,
    // Control flow
    BRANCH, JUMP, CALL, RET,
    // Type operations
    CAST, TYPECHECK,
};
```

#### 10.2 Bytecode → IR Translation (Week 5-8)

**Purpose:** Convert stack-based bytecode to register-based IR

**Algorithm:**
1. Simulate stack with virtual registers
2. Convert stack operations to register operations
3. Build CFG in IR form
4. Perform register allocation (virtual → physical)

**Example:**
```
// Bytecode (stack-based):
CONSTANT 5       // Push 5
CONSTANT 3       // Push 3
ADD              // Pop 2, add, push result

// IR (register-based):
r0 = LOAD_CONST 5
r1 = LOAD_CONST 3
r2 = ADD r0, r1
```

#### 10.3 Register Allocation (Week 9-14)

**Purpose:** Map unlimited virtual registers to limited physical registers

**Graph Coloring Algorithm:**
1. Build interference graph (which values are live simultaneously)
2. Color graph with available physical registers
3. Spill to memory if not enough registers

**Linear Scan Allocation (simpler, faster):**
1. Assign registers in order of first use
2. Free registers when value is no longer live
3. Spill least recently used if out of registers

**Platform-Specific:**
- x86-64: 16 general-purpose registers (RAX, RBX, ..., R15)
- ARM64: 31 general-purpose registers (X0-X30)
- RISC-V: 32 registers (x0-x31)

#### 10.4 Code Generation (Week 15-22)

**Purpose:** Generate native machine code from IR

**Instruction Selection:**
- Pattern matching on IR to native instructions
- Use target-specific instruction formats
- Handle calling conventions

**Example (x86-64):**
```
// IR:
r0 = ADD r1, r2

// x86-64 Assembly:
mov rax, r1      ; Move r1 to RAX
add rax, r2      ; Add r2 to RAX
mov r0, rax      ; Move result to r0
```

**Code Emission:**
```zig
pub const CodeGenerator = struct {
    target: Target,        // x86-64, ARM64, etc.
    buffer: []u8,          // Machine code buffer
    offset: usize,
    
    pub fn emitAdd(self: *CodeGenerator, dest: Reg, src1: Reg, src2: Reg) void {
        switch (self.target) {
            .x86_64 => {
                // Emit: ADD dest, src1, src2
                self.emit(&[_]u8{0x48, 0x01, ...});  // x86-64 encoding
            },
            .arm64 => {
                // Emit: ADD dest, src1, src2
                self.emit(&[_]u8{0x8b, 0x00, ...});  // ARM64 encoding
            },
            // ...
        }
    }
};
```

#### 10.5 Tiered Compilation (Week 23-26)

**Purpose:** Balance compilation speed vs. code quality

**Three Tiers:**

**Tier 0: Interpreter (Baseline)**
- Fast startup (no compilation)
- Slow execution
- Collect profile data

**Tier 1: Template JIT (Quick Compilation)**
- Fast compilation (~1ms per function)
- Moderate performance (2-5x faster than interpreter)
- Use canned templates for common patterns

**Tier 2: Optimizing JIT (Slow Compilation)**
- Slow compilation (10-100ms per function)
- High performance (10-50x faster than interpreter)
- Apply all optimizations (Phases 5-9)

**Tiering Strategy:**
```zig
pub fn compileFunctionTiered(func: *ObjFunction, profile: *ProfilingData) void {
    const call_count = profile.call_counts.get(func) orelse 0;
    
    if (call_count == 0) {
        // Not yet called - leave as bytecode
        return;
    }
    
    if (call_count < 100) {
        // Called few times - use template JIT (Tier 1)
        compileWithTemplateJIT(func);
    } else if (call_count < 10000) {
        // Called moderately - check if worth optimizing
        if (shouldOptimize(func, profile)) {
            compileWithOptimizingJIT(func, profile);  // Tier 2
        }
    } else {
        // Hot function - definitely optimize
        compileWithOptimizingJIT(func, profile);
    }
}
```

#### 10.6 On-Stack Replacement (OSR) (Week 27-30)

**Purpose:** Switch from interpreter to JIT mid-execution (important for long-running loops)

**Problem:**
```javascript
function longLoop() {
    for (var i = 0; i < 1000000; i++) {
        // Starts in interpreter
        // After 1000 iterations, JIT compiles
        // But loop already started!
        compute(i);
    }
}
```

**Solution: On-Stack Replacement**
1. Detect hot loop in interpreter
2. Compile loop with JIT
3. Transfer execution state (registers, stack)
4. Jump into compiled code mid-loop

**Implementation:**
```zig
pub fn performOSR(func: *ObjFunction, offset: usize, stack_state: StackState) void {
    // Compile function with JIT
    const jit_code = compileWithOptimizingJIT(func, null);
    
    // Map interpreter state to JIT state
    const jit_entry = findOSREntry(jit_code, offset);
    
    // Transfer state
    for (stack_state.locals) |local, i| {
        jit_entry.registers[i] = local;
    }
    
    // Jump to JIT code
    jit_entry.execute();
}
```

#### 10.7 Deoptimization (Week 31-34)

**Purpose:** Fall back to interpreter when JIT assumptions are violated

**Speculative Optimizations:**
- Type assumptions (value is always int)
- Range assumptions (index is always in bounds)
- Object layout assumptions (class structure unchanged)

**Deoptimization Trigger:**
```javascript
function add(a, b) {
    // JIT assumes: a and b are always integers
    return a + b;
}

// Compiled JIT code:
if (typeof(a) != 'int' || typeof(b) != 'int') {
    deoptimize();  // Assumptions violated!
}
return a + b;  // Fast integer add
```

**Deoptimization Process:**
1. Detect assumption violation
2. Reconstruct interpreter state from JIT state
3. Transfer control back to interpreter
4. Continue execution in interpreter
5. (Optionally) Recompile with relaxed assumptions

#### 10.8 Memory Management (Week 35-38)

**Code Cache Management:**
- Limited memory for JIT code
- Evict cold code when cache full
- Track code age and usage

**Code Patching:**
- Inline caches for dynamic dispatch
- Polymorphic inline caches (PIC)
- Update call sites when recompiling

#### 10.9 Multi-Architecture Support (Week 39-44)

**Target Architectures:**
- **x86-64:** Desktop/server (Intel, AMD)
- **ARM64:** Mobile, Apple Silicon
- **RISC-V:** Emerging (future-proof)

**Abstraction Layer:**
```zig
pub const Target = enum {
    x86_64,
    arm64,
    riscv64,
};

pub const CodeGen = struct {
    pub fn create(target: Target) *CodeGen {
        return switch (target) {
            .x86_64 => &x86_64_codegen,
            .arm64 => &arm64_codegen,
            .riscv64 => &riscv64_codegen,
        };
    }
};
```

#### 10.10 Validation & Testing (Week 45-48)

**Correctness Testing:**
- Verify JIT produces same results as interpreter
- Fuzz testing (random programs)
- Stress testing (OSR, deopt, tier transitions)

**Performance Testing:**
- Benchmark suite (vs. interpreter, vs. other VMs)
- Real-world applications
- Compilation time vs. execution time trade-offs

### Expected Improvements
- **Overall Performance:** 5-10x faster than bytecode interpreter
- **Hot Loops:** 10-50x faster
- **Numeric Code:** 20-100x faster (near-native performance)
- **Startup Time:** Minimal impact with tiered compilation

### Deliverables
- ✅ IR design and implementation
- ✅ Bytecode → IR translator
- ✅ Register allocator
- ✅ Code generator (x86-64, ARM64)
- ✅ Tiered compilation framework
- ✅ On-stack replacement
- ✅ Deoptimization mechanism
- ✅ Code cache management
- ✅ Comprehensive test suite
- ✅ Performance benchmarks

---

## Implementation Timeline

### Gantt Chart (Simplified)

```
Year 1:
Month:     1  2  3  4  5  6  7  8  9  10 11 12
Phase 5:   [========CFG========]
Phase 6:                          [===========Dataflow===========]
Phase 7:                                                            [===Loop===]

Year 2:
Month:     1  2  3  4  5  6  7  8  9  10 11 12
Phase 7:   ]
Phase 8:   [====IPO====]
Phase 9:               [======PGO======]
Phase 10:                               [==================JIT===================]
```

### Milestones

| Date | Milestone | Description |
|------|-----------|-------------|
| **Month 4** | Phase 5 Complete | CFG analysis infrastructure ready |
| **Month 9** | Phase 6 Complete | SSA and dataflow analysis ready |
| **Month 12** | Phase 7 Complete | Loop optimizations implemented |
| **Month 15** | Phase 8 Complete | Interprocedural optimization ready |
| **Month 20** | Phase 9 Complete | Profile-guided optimization ready |
| **Month 28** | Phase 10 Complete | JIT compilation fully functional |
| **Month 30** | **Production Release** | All optimizations stable and tested |

---

## Resource Requirements

### Team Composition

**For Full Implementation (Phases 5-10):**
- **1 Senior Compiler Engineer** (lead, architecture)
- **2 Compiler Engineers** (implementation)
- **1 Performance Engineer** (benchmarking, profiling)
- **1 QA Engineer** (testing, validation)

**Alternative (Solo/Small Team):**
- Focus on Phases 5-7 first (CFG, Dataflow, Loops) - 10-12 months
- Defer JIT (Phase 10) until later
- Implement PGO (Phase 9) only if needed

### Infrastructure

**Development:**
- CI/CD pipeline for automated testing
- Performance regression testing infrastructure
- Cross-platform build system (x86-64, ARM64)

**Testing:**
- Comprehensive benchmark suite
- Fuzz testing infrastructure
- Real-world applications for validation

---

## Risk Assessment

### Technical Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| **JIT complexity** | High | High | Start with simple template JIT, defer optimizing JIT |
| **Correctness bugs** | Medium | High | Extensive testing, formal verification where possible |
| **Performance regressions** | Medium | Medium | Continuous benchmarking, performance CI |
| **Architecture portability** | Low | Medium | Abstract target-specific code, test on all platforms |
| **Deoptimization edge cases** | Medium | Medium | Thorough testing of speculative optimizations |

### Schedule Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| **Underestimated complexity** | High | High | Build phases incrementally, MVP first |
| **Scope creep** | Medium | Medium | Strict phase boundaries, defer nice-to-haves |
| **Resource constraints** | Medium | Medium | Prioritize phases 5-7, defer 8-10 if needed |

---

## Success Metrics

### Performance Targets

| Benchmark | Baseline (Phase 4) | Target (Phase 10) | Stretch Goal |
|-----------|-------------------|-------------------|--------------|
| **Numeric computation** | 100 Mops/s | 1,000 Mops/s | 2,000 Mops/s |
| **Loop-heavy code** | 50 Mops/s | 500 Mops/s | 1,000 Mops/s |
| **Function calls** | 10M calls/s | 50M calls/s | 100M calls/s |
| **String operations** | 20 MB/s | 100 MB/s | 200 MB/s |
| **Overall (geomean)** | 1.0x | 5.0x | 10.0x |

### Code Quality Metrics

- **Test Coverage:** > 90% for all optimization passes
- **Bug Density:** < 1 bug per 1000 lines of code
- **Performance Regression:** < 5% on any benchmark
- **Compilation Time:** < 2x increase for optimized builds

---

## Alternatives & Trade-offs

### Alternative Approaches

#### 1. Use Existing JIT Framework
**Option:** Use LLVM or Cranelift for code generation

**Pros:**
- Production-quality code generation
- Multi-architecture support out-of-box
- Mature optimization pipeline

**Cons:**
- Large dependency (~100 MB for LLVM)
- Longer compilation times
- Less control over optimization strategy

**Recommendation:** Consider for Phase 10 if JIT development is too complex

#### 2. Ahead-of-Time (AOT) Compilation
**Option:** Compile to native code at install time

**Pros:**
- No JIT complexity
- Predictable performance
- Smaller runtime

**Cons:**
- No adaptive optimization
- Platform-specific binaries
- Longer startup time

**Recommendation:** Good complement to JIT (hybrid approach)

#### 3. Transpilation
**Option:** Transpile to C/JavaScript/Rust and use their compilers

**Pros:**
- Leverage mature compilers
- Potentially best performance

**Cons:**
- Lose VM benefits (sandboxing, debugging)
- Compilation time overhead
- Deployment complexity

**Recommendation:** Not suitable for dynamic scripting language

---

## Conclusion

This roadmap outlines a path from the current Phase 4 optimized bytecode interpreter to a full-featured, high-performance VM with JIT compilation. The journey involves:

1. **Phase 5 (CFG):** Build foundation for advanced analysis
2. **Phase 6 (Dataflow):** Enable value-tracking optimizations
3. **Phase 7 (Loops):** Optimize the hottest code
4. **Phase 8 (IPO):** Cross-function optimizations
5. **Phase 9 (PGO):** Workload-adaptive optimization
6. **Phase 10 (JIT):** Native code generation

**Recommended Approach:**
- **Short-term (6 months):** Phases 5-6 (CFG + Dataflow)
- **Medium-term (12 months):** Phase 7 (Loops)
- **Long-term (24 months):** Phases 8-10 (IPO + PGO + JIT)

**Expected Results:**
- 5-10x overall performance improvement
- 10-50x improvement on hot loops
- Near-native performance on numeric code

This roadmap is ambitious but achievable with focused effort and incremental delivery. Each phase delivers value independently and builds toward the ultimate goal of a world-class virtual machine.

---

**Next Steps:**
1. Review and refine this roadmap
2. Prioritize phases based on impact and resources
3. Create detailed design documents for Phase 5
4. Begin implementation of CFG analysis
5. Set up performance benchmarking infrastructure

**Let's build something amazing! 🚀**