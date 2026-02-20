# Quick Reference: Resume Jump Patching Work

**Last Updated:** 2024  
**Status:** 90% Complete - Ready for Final Integration  
**Tests Passing:** 165/170 (97%)

---

## 🎯 What to Do Next

### The Problem (5-minute read)

The bytecode optimizer works but is **disabled** because it changes bytecode size without updating jump instruction offsets. This causes infinite loops and stack overflows.

**Example:**
```
Before optimization:
  [0]  CONSTANT 0
  [2]  CONSTANT 1
  [4]  ADD
  [5]  JUMP_IF_FALSE → offset 20

After optimization (CONSTANT+CONSTANT fused):
  [0]  CONSTANT_CONSTANT 0 1  (saved 1 byte!)
  [3]  ADD
  [4]  JUMP_IF_FALSE → offset 20  ⚠️ WRONG! Should be 19
```

**Solution:** Implemented jump patching infrastructure (431 lines in `src/jump_patcher.zig`) but modification tracking is too coarse.

---

## 🔧 What's Built (90% Complete)

✅ **Jump detection** - `scanJumps()` finds all jumps  
✅ **Jump patching** - `patchJumps()` updates offsets  
✅ **Validation** - `validateJumps()` checks correctness  
✅ **Integration framework** - hooks in optimizer  
✅ **Unit tests** - all passing  

🟡 **Modification tracking** - records changes but not detailed enough  

---

## 🚀 Next 6 Hours of Work

### Hour 1-2: Fix Modification Tracking

**Problem:** We track "24 bytes removed" but not WHERE they were removed.

**Current (broken):**
```zig
// Only knows total size change
modifications[0] = .{
    .offset = 0,  // ❌ Doesn't know where!
    .bytes_removed = 24,
};
```

**Fix Needed:**
```zig
// Each optimization appends exact changes
modifications.append(.{ .offset = 15, .bytes_removed = 4, .bytes_added = 3 });
modifications.append(.{ .offset = 23, .bytes_removed = 1, .bytes_added = 0 });
```

**Files to Modify:**

1. `src/peephole_optimizer.zig` line ~240
   ```zig
   // Change signature:
   pub fn optimize(chunk: *Chunk, stats: *OptimizationStats, 
                   mods: *std.ArrayList(Modification)) void
   
   // In applyPattern():
   try mods.append(.{
       .offset = pattern.offset,
       .bytes_removed = pattern.length,
       .bytes_added = pattern.replacement_length,
   });
   ```

2. `src/bytecode_optimizer.zig` line ~250
   ```zig
   // Pass modifications list to each optimizer:
   peephole.optimize(chunk, &stats.superinstructions, &modifications);
   runConstantFolding(chunk, &modifications);
   runPeepholePatterns(chunk, &modifications);
   ```

### Hour 3-4: Enable & Test

**Enable one optimization at a time:**

```bash
# Test each in isolation
./zig-out/bin/mufiz -r test_suite/if/if.mufi
./zig-out/bin/mufiz -r test_suite/loops/syntax_for.mufi
./zig-out/bin/mufiz -r test_suite/while/basic.mufi
```

**Check for:**
- No stack overflows
- Correct output
- Jump patching stats printed

### Hour 5-6: Validate & Document

```bash
# Run full test suite
python3 test_suite.py

# Expected: 165/170 still passing
# Goal: Same pass rate, but with optimizations enabled
```

**Update docs:**
- Mark Phase 4.1 as complete
- Document modification tracking API
- Update roadmap

---

## 📁 Key Files

| File | Lines | Status | Purpose |
|------|-------|--------|---------|
| `src/jump_patcher.zig` | 431 | ✅ Done | Jump patching infrastructure |
| `src/bytecode_optimizer.zig` | ~550 | 🟡 90% | Optimizer orchestrator |
| `src/peephole_optimizer.zig` | ~350 | 🟡 Needs mod tracking | Superinstructions |
| `src/compiler.zig` line 471 | - | 🔴 Disabled | Enable when ready |

---

## 🐛 Common Issues & Fixes

### Issue: ArrayList API Error
```
error: struct 'array_list.Aligned(Type,null)' has no member named 'init'
```

**Fix:** Use slice allocation instead:
```zig
// Don't:
var list = std.ArrayList(MyType).init(allocator);

// Do:
const items = try allocator.alloc(MyType, count);
defer allocator.free(items);
```

### Issue: Still Getting Stack Overflow

**Check:**
1. Are modifications being tracked? Add debug prints
2. Is `patchJumps()` being called?
3. Are jump offsets actually being updated?

**Debug:**
```zig
std.debug.print("Modifications: {d}\n", .{modification_count});
for (modifications) |mod| {
    std.debug.print("  offset={d}, removed={d}, added={d}\n",
        .{mod.offset, mod.bytes_removed, mod.bytes_added});
}
```

### Issue: Wrong Jump Offsets After Patching

**Check:** Modification offset calculation in `calculateJumpAdjustment()`
- Forward jumps: adjust if mod is between jump and target
- Backward jumps: adjust if mod is between target and jump

---

## 🧪 Test Strategy

**Phase 1: Simple Tests**
```bash
./zig-out/bin/mufiz -r test_suite/if/if.mufi
./zig-out/bin/mufiz -r test_suite/loops/syntax.mufi
```

**Phase 2: Complex Tests**
```bash
./zig-out/bin/mufiz -r test_suite/function/recursion.mufi
./zig-out/bin/mufiz -r test_suite/class/inherit_methods.mufi
```

**Phase 3: Full Suite**
```bash
python3 test_suite.py
```

**Success Criteria:**
- ✅ No stack overflows
- ✅ 165/170 tests still passing
- ✅ Bytecode size reduced
- ✅ Jump validation passes

---

## 📊 Expected Results

### Before (Optimizer Disabled)
```
Successful tests: [165/170]
Bytecode size: ~1000 bytes (example)
```

### After (Optimizer Enabled with Jump Patching)
```
Successful tests: [165/170]  ← Should be same
Bytecode size: ~700-800 bytes  ← 20-30% smaller
Jump patching overhead: ~50ms ← Acceptable
```

---

## 🎓 Quick Code Reference

### Scan for Jumps
```zig
const jumps = try jump_patcher.scanJumps(chunk, allocator);
defer allocator.free(jumps);
```

### Track Modification
```zig
try modifications.append(.{
    .offset = where_change_happened,
    .bytes_removed = how_many_removed,
    .bytes_added = how_many_added,
});
```

### Patch Jumps
```zig
const stats = try jump_patcher.patchAfterModifications(
    chunk,
    modifications.items,
    allocator,
);
```

---

## 🚨 If You Get Stuck

### Fallback Option: Keep Disabled
```zig
// src/compiler.zig line 471
_ = bytecode_optimizer;  // Keep this line
// Optimizer stays disabled, tests pass, move to Phase 5
```

### Nuclear Option: Revert Everything
```bash
git checkout src/bytecode_optimizer.zig
git checkout src/jump_patcher.zig
# Back to "optimizer disabled" state
```

---

## 📞 Contact Points

**Documentation:**
- `docs/bytecode_optimization/PHASE4_CRITICAL_BUG.md` - Full analysis
- `docs/bytecode_optimization/PHASE4.1_PROGRESS.md` - Detailed progress
- `SESSION_SUMMARY.md` - What happened this session

**Key Functions:**
- `jump_patcher.scanJumps()` - Find all jumps
- `jump_patcher.patchJumps()` - Update offsets
- `jump_patcher.validateJumps()` - Check correctness
- `bytecode_optimizer.optimize()` - Main entry point

---

## ✅ Done When

- [ ] Modification tracking captures exact offsets
- [ ] All optimizations enabled
- [ ] 165/170 tests still passing
- [ ] No stack overflows
- [ ] Jump validation passes
- [ ] Bytecode size reduced
- [ ] Documentation updated

**Estimated Time:** 6 hours  
**Confidence:** HIGH - Most code written, just needs integration

---

**Ready to Start?**
1. Open `src/peephole_optimizer.zig`
2. Add `mods` parameter to `optimize()` and `applyPattern()`
3. Track each modification
4. Test with simple if statement
5. If that works, enable all optimizations
6. Run full test suite
7. Done! 🎉