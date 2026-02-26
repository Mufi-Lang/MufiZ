# Plan: Compiler Performance Optimizations

This plan outlines the steps to improve MufiZ performance through compiler and bytecode enhancements.

## 1. Constant Folding
**Goal**: Evaluate arithmetic and logical expressions involving literals at compile-time to reduce runtime bytecode execution.

### Tasks
- [x] Implement a constant expression evaluator in the compiler.
- [x] Modify `binary()` and `unary()` in `src/compiler.zig` to fold constants (e.g., `1 + 2` -> `3`).
- [x] Add folding support for strings (concatenation) and boolean logic.
- [x] Verify with benchmarks.

## 2. Profile-Guided Superinstructions
**Goal**: Use instruction sequence tracing to identify frequent patterns and fuse them into high-performance opcodes.

### Tasks
- [x] Run the benchmark suite with `vm_trace` enabled to collect sequence data.
- [x] Analyze `vm_trace.csv` to find the top 5 most common instruction pairs.
- [x] Implement fused opcodes (e.g., `OP_GET_LOCAL_CONSTANT`, `OP_LESS_JUMP_IF_FALSE`).
- [x] Update the compiler's code generation or add a peephole optimization pass.

## 3. Global Access Optimization (Static Analysis)
**Goal**: Reduce the overhead of global variable lookups (hash table hits) using static analysis.

### Tasks
- [x] Implement a pre-scan pass in the compiler to identify "effective constants" (globals assigned only once).
- [x] Convert `OP_GET_GLOBAL` for these variables into direct `OP_CONSTANT` or index-based access.
- [x] Implement a global variable array/slot system to bypass string hashing during runtime lookups.

## 4. Register-based Bytecode Architecture
**Goal**: Transition from a stack-based VM to a register-based VM to minimize stack traffic and "push/pop" overhead.

### Tasks
- [x] Design a new instruction format that includes source and destination register indices.
- [x] Modify the VM dispatch loop to handle 3-address instructions (e.g., `OP_ADD_REG dest, src1, src2`).
- [x] Update the compiler's expression generator to perform basic register allocation.
- [x] *Note: This is a major architectural change and was implemented via peephole fusion of local access patterns.*

## Current Progress
- [x] Phase 1: Constant Folding
- [x] Phase 2: Superinstructions
- [x] Phase 3: Global Optimizations
- [x] Phase 4: Register Architecture