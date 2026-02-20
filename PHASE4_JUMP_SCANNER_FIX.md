# Phase 4: Jump Scanner Fix - Status Report

**Date**: 2024
**Status**: Jump Scanner Fixed ✅ | Optimizer Integration Blocked ⚠️

---

## Executive Summary

The critical jump scanner bug has been **successfully fixed**. The scanner was advancing byte-by-byte instead of instruction-by-instruction, causing it to misinterpret operand bytes as opcodes and report false-positive jump instructions.

However, **a new blocker has been discovered**: enabling the bytecode optimizer causes "Invalid constant index" runtime errors in the VM, even though jump validation now passes. This suggests the superinstruction optimizer may be corrupting constant table references or bytecode structure in a way that affects constant lookups.

---

## What Was Fixed

### 1. Jump Scanner (✅ COMPLETE)

**Problem**: 
- `scanJumps()` in `jump_patcher.zig` was advancing by 1 byte at a time
- This caused the scanner to read operand bytes as if they were opcodes
- Result: false positives (non-jump bytes detected as jumps) and invalid jump targets

**Solution**:
```zig
// BEFORE (wrong - advances 1 byte):
offset += 1;

// AFTER (correct - advances by full instruction size):
const instruction_length = chunk_h.getInstructionLength(chunk, offset);
if (instruction_length == 0) break;
offset += instruction_length;
```

**Key Changes**:
- Modified `scanJumps()` to use `chunk_h.getInstructionLength()` instead of `+= 1`
- Made `getInstructionLength()` in `bytecode_analyzer.zig` public (was private)
- Added comprehensive unit test `"scanJumps - instruction boundary scanning"` with realistic bytecode
- Test creates a 15-byte sequence with mixed instruction sizes (1, 2, 3 bytes) and verifies only actual jumps are detected

### 2. Short Jump Support (✅ COMPLETE)

**Problem**:
- Phase 2.3 introduced short jump instructions (OP_JUMP_SHORT, etc.) with i8 offsets
- Original scanner only handled standard jumps (i16 offsets)
- Short jumps were being scanned but not recognized as jumps

**Solution**:
- Extended `isJumpInstruction()` to include `.OP_JUMP_SHORT`, `.OP_JUMP_IF_FALSE_SHORT`, `.OP_LOOP_SHORT`
- Extended `getJumpInstructionSize()` to return 2 bytes for short jumps (opcode + i8)
- Added `readOffset8()` and `writeOffset8()` helper functions
- Modified `scanJumps()` to read i8 or i16 offsets based on jump type
- Modified `patchJumps()` to write i8 or i16 offsets and validate overflow

**Code Added**:
```zig
fn readOffset8(code: [*]u8, offset: usize) i8 {
    return @bitCast(code[offset]);
}

fn writeOffset8(code: [*]u8, offset: usize, value: i8) void {
    code[offset] = @bitCast(value);
}
```

### 3. Test Coverage (✅ COMPLETE)

**Unit Tests Added**:
- `test "scanJumps - instruction boundary scanning"` - validates scanner finds only actual jumps
- All existing jump patcher tests still pass (7/7 tests pass)

**Files Modified**:
- `src/jump_patcher.zig` - scanner fix + short jump support
- `src/bytecode_analyzer.zig` - made `getInstructionLength()` public
- `src/compiler.zig` - optimizer enable/disable toggle

---

## What's Still Broken

### Issue: Invalid Constant Index Errors (⚠️ BLOCKER)

**Symptom**:
```
[Jump Patching] Patching 26 modifications...
Invalid constant index.
[line 1] in script
error: RuntimeError
```

**Observations**:
1. Jump patching runs successfully (no validation errors)
2. The optimizer reports 26 modifications for `test_suite/class/arity.mufi`
3. Runtime error occurs when VM tries to load a constant
4. Tests pass when optimizer is disabled
5. Simple tests (loops, conditionals) work with optimizer enabled
6. Class-related tests consistently fail

**Hypothesis**:
The superinstruction optimizer may be:
1. Corrupting constant indices when shifting bytecode during fusion
2. Creating invalid bytecode sequences that reference wrong constant pool entries
3. Not accounting for multi-byte instructions properly when calculating constant indices
4. Over-reporting modifications (26 seems excessive for a single function)

**Evidence**:
- The optimizer validation checks pass (constant indices are validated before fusion)
- The jump patching completes without errors
- The error only occurs at VM execution time, not during optimization/patching
- Error message "Invalid constant index" comes from VM's constant loading code

---

## Test Results

### With Optimizer Disabled
```
Success rate: 165/170 tests passing (97%)
```

The 5 failing tests are pre-existing issues unrelated to Phase 4:
- JSON tests
- Range tests
- Edge cases

### With Optimizer Enabled (Superinstructions Only)
```
Success rate: 74/170 tests passing (44%)
Failed: 96/170 tests
```

**Failure Pattern**:
- All class-related tests fail
- All loop tests fail
- Matrix tests fail
- Range/switch tests fail

**Common error**: "Invalid constant index"

### Jump Scanner Validation
- ✅ Unit tests: 7/7 passing
- ✅ No more "jump validation failed" errors
- ✅ Scanner correctly identifies jump instructions only
- ✅ Scanner advances by full instruction boundaries

---

## Architecture Changes

### Files Modified

1. **src/jump_patcher.zig** (Scanner Fix)
   - `scanJumps()` - now uses instruction-aware scanning
   - Added short jump support (i8 offsets)
   - Added overflow validation for both i8 and i16 jumps
   - New unit test for instruction boundary scanning

2. **src/bytecode_analyzer.zig** (API Change)
   - `getInstructionLength()` - marked as `pub` (was private)
   - Now callable from jump_patcher

3. **src/compiler.zig** (Integration Point)
   - Optimizer disabled pending constant index bug fix
   - Contains detailed comments explaining current blocker

### No Breaking Changes
- All existing APIs preserved
- Jump patcher interface unchanged
- Optimizer config structure unchanged

---

## Next Steps (Prioritized)

### IMMEDIATE (High Priority)

#### 1. Debug Constant Index Corruption (8-12 hours)
**Goal**: Understand why optimizer causes "Invalid constant index" errors

**Tasks**:
1. Add extensive logging to `applyPattern()` in peephole_optimizer.zig:
   - Log before/after bytecode state
   - Log constant indices being referenced
   - Log chunk.constants.count vs indices in code
   
2. Compare bytecode disassembly with/without optimizer:
   - Use `--print-code` flag to see generated bytecode
   - Identify where constant indices become invalid
   
3. Check if modifications are accumulating incorrectly:
   - 26 modifications for one function seems excessive
   - May indicate patterns are being applied multiple times to same code
   
4. Verify constant pool isn't being corrupted:
   - Check if optimizer changes chunk.constants
   - Verify constant count remains stable

**Debugging Commands**:
```bash
# Enable verbose optimizer output
# Edit src/compiler.zig: set .verbose = true

# Compare with/without optimizer
./zig-out/bin/mufiz -r test_suite/class/arity.mufi --print-code

# Test simple case
echo 'var x = 1; var y = 2; print(x + y);' | ./zig-out/bin/mufiz --repl
```

#### 2. Add Safety Checks to Optimizer (4 hours)
**Goal**: Prevent optimizer from creating invalid bytecode

**Tasks**:
1. Add post-optimization validation:
   - Verify all constant indices in bytecode are < chunk.constants.count
   - Verify bytecode length matches chunk.count
   - Verify no dangling references

2. Add modification accounting:
   - Track total bytes added/removed
   - Verify it matches actual chunk size change
   - Detect if modifications overlap (corruption indicator)

3. Add rollback capability:
   - Save original bytecode before optimization
   - Restore if validation fails

### SHORT-TERM (Medium Priority)

#### 3. Incremental Testing (2-4 hours)
**Goal**: Isolate which superinstruction patterns cause issues

**Tasks**:
1. Test each superinstruction pattern individually:
   - Enable only GET_GLOBAL_GLOBAL, test
   - Enable only CONSTANT_CONSTANT, test
   - Enable only GET_LOCAL_LOCAL, test
   
2. Identify safe vs unsafe patterns

3. Create regression test suite for optimizer

#### 4. Alternative Approaches (4-8 hours)
If constant corruption can't be fixed quickly:

**Option A**: Disable bytecode shifting
- Don't use superinstructions that change bytecode size
- Only use 1:1 replacements (same size in/out)
- Pro: Safe, no shifting corruption
- Con: Minimal optimization benefit

**Option B**: Use two-pass optimization
- First pass: collect patterns, don't modify
- Second pass: rebuild bytecode from scratch with optimizations
- Pro: Clean, no shifting issues
- Con: More complex, higher overhead

**Option C**: Move to IR/CFG (Phase 5)
- Build intermediate representation
- Optimize at IR level
- Generate bytecode from IR
- Pro: Robust, powerful, future-proof
- Con: Large effort (weeks)

### LONG-TERM (Future)

#### 5. Comprehensive Optimizer Testing
- Fuzzing/property-based testing
- Bytecode equivalence checking
- Performance benchmarking

#### 6. Phase 5 Planning (CFG/IR)
- Design IR structure
- Plan migration strategy

---

## Files of Interest

### Core Implementation
- `src/jump_patcher.zig` - Jump scanning and patching (fixed)
- `src/peephole_optimizer.zig` - Superinstruction fusion (suspect)
- `src/bytecode_optimizer.zig` - Orchestration (clean)
- `src/bytecode_analyzer.zig` - Instruction metadata (fixed)

### Integration Points
- `src/compiler.zig` - Optimizer invocation (disabled)
- `src/vm.zig` - Constant loading (where error occurs)

### Testing
- `test_suite.py` - Test runner
- `test_suite/class/arity.mufi` - Minimal failing test
- `test_suite/for_loop_test.mufi` - Working test

---

## Technical Debt

### Accumulated
1. **Modification tracking** - Uses fixed 32-element array, could overflow
2. **Error handling** - Optimizer failures are silent (break loop, no error)
3. **Validation** - Jump validation is heuristic, not foolproof
4. **Testing** - No optimizer-specific tests in test suite

### To Address
- Replace fixed-size modification buffer with dynamic allocation
- Proper error propagation from optimizer
- Strengthen jump validation (use instruction length table)
- Add optimizer test cases to test_suite/

---

## Summary

**What's Working**:
✅ Jump scanner correctly identifies jumps at instruction boundaries
✅ Short jump support (i8 offsets)
✅ Jump offset patching algorithm
✅ Modification tracking infrastructure
✅ Basic integration with compiler

**What's Broken**:
❌ Optimizer causes "Invalid constant index" runtime errors
❌ Class/loop/matrix tests fail with optimizer enabled
❌ Root cause unknown (constant pool corruption suspected)

**Critical Path**:
1. Debug constant index bug with extensive logging
2. Add safety validation to optimizer
3. Test patterns individually to isolate issue
4. Consider alternative approaches if needed

**Time Estimate to Completion**:
- Optimistic (bug is simple): 8-16 hours
- Realistic (requires refactor): 24-40 hours
- Pessimistic (need Phase 5 IR): 2-4 weeks

---

## Recommendations

1. **Immediate**: Add verbose logging to optimizer and run failing test with full diagnostics
2. **Short-term**: Implement safety checks and rollback capability
3. **Long-term**: Plan transition to IR/CFG-based optimization (Phase 5)

The jump scanner fix was successful and represents solid progress. The constant index bug is solvable but requires careful debugging to avoid creating more issues. A defensive, incremental approach is recommended.