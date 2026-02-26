# Plan: Advanced VM Optimizations (v2)

This plan outlines high-impact optimizations for the MufiZ Virtual Machine.

## 1. Global Variable Slots (Fast Global Access)
**Goal**: Replace string-based hash table lookups for global variables with fixed-index array access.

### Tasks
- [x] Modify `VM` to store globals in an indexed array (`globalValues`).
- [x] Update `compiler.zig` to assign slot indices to global names during compilation.
- [x] Implement `OP_GET_GLOBAL_SLOT` and `OP_SET_GLOBAL_SLOT`.
- [x] Update `namedVariable` to prefer slot-based instructions.

## 2. Monomorphic Inline Caching (MIC)
**Goal**: Speed up property and method lookups by caching the result of the first lookup at the call site.

### Tasks
- [x] Define an `InlineCache` structure in `src/chunk.zig`.
- [x] Update `OP_GET_PROPERTY` to check and update the cache.
- [x] If the object's class matches the cached class, use the cached offset.
- [x] Implement cache misses (fall back to hash table and update cache).

## 3. Specialized Loop Opcodes
**Goal**: Reduce loop overhead by fusing common patterns into single instructions.

### Tasks
- [x] Implement `OP_GET_LOCAL_LESS` to fuse local load and comparison.
- [x] Implement `OP_SET_LOCAL_POP` and `OP_ADD_SET_LOCAL` for loop increments.
- [x] Update the peephole optimizer to automatically fuse these patterns.

## 4. Computed Goto (Direct Threading)
**Goal**: Eliminate the overhead of the central `switch` dispatch in the VM.

### Status
- Deferred: Zig's `switch` is already highly optimized, and true computed goto requires language-specific extensions or assembly that may impact portability.

## Current Progress
- [x] Phase 1: Global Slots
- [x] Phase 2: Inline Caching
- [x] Phase 3: Loop Opcodes
- [ ] Phase 4: Computed Goto (Deferred)