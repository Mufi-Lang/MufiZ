# Compiler Optimization Analysis — Checklist

This document collects the optimization opportunities I found while analyzing the compiler. Each item below is a single checkbox so you can track progress. For each item I include a short description, expected impact, risk, and estimated effort.

---

## Quick wins (low effort, high impact)
- [ ] Use arena reset instead of deinit/init in the compiler arena  
  - Description: Replace `deinit()` + `init()` with the arena's `reset()`/equivalent to avoid allocator churn for repeated compilations.  
  - Files: `src/compiler_arena.zig` (`CompilerArena.reset`)  
  - Expected impact: medium-high (less allocation overhead across compilations / REPL)  
  - Risk: low  
  - Effort: small

- [ ] Compute and store a token hash in the scanner (`Token`) and short-circuit identifier comparisons  
  - Description: Add a `hash: u64` to `Token` (computed during scanning) and check `length` + `hash` before doing full `memcmp` in `identifiersEqual`. Use `StringHash` utilities for hashing.  
  - Files: `src/scanner_optimized.zig` (token finalize), `src/compiler.zig` (`identifiersEqual`)  
  - Expected impact: high for codebases with many identifier comparisons (resolve/local checks, symbol lookups)  
  - Risk: low-medium (ensure hashing algorithm and collisions handled)  
  - Effort: small

- [ ] Add micro-benchmarks / instrumentation for compile phases (scanner / parser / emitter)  
  - Description: Add time and allocation counters around tokenization, parsing, and bytecode emission to get baseline metrics. Add simple tests that compile large or realistic sources and measure time & memory.  
  - Files: add `bench/` harness or small helper in `src/` (no single file change required yet)  
  - Expected impact: enables data-driven optimization; no runtime change to compiler behavior  
  - Risk: negligible  
  - Effort: small

---

## Medium effort (moderate complexity, good payoff)
- [ ] Replace `resolveLocal` linear scan with a small per-function symbol table (hash)  
  - Description: Maintain a compact hash -> local-index mapping (reset per function) to get O(1) local lookups instead of O(n). Alternatively maintain a small scope/hash per scope depth. Combine with token-hash optimization.  
  - Files: `src/compiler.zig` (`resolveLocal`, `declareVariable`, `addLocal`)  
  - Expected impact: medium-high on functions with many locals or generated code (eliminate pathological quadratic behavior).  
  - Risk: medium (must ensure correct scoping / shadowing semantics)  
  - Effort: medium

- [ ] Compress `Chunk` line information to run-length or start-index representation  
  - Description: Instead of storing a `lines` entry per byte/instruction, store changes only when the source line changes (e.g., `(start_ip, line)` pairs). Adjust error/backtrace code to map instruction -> line via binary search.  
  - Files: `src/chunk.zig` (writeChunk & line storage), error reporting code that uses `chunk.lines`.  
  - Expected impact: large memory & write reduction for big functions; reduces mem traffic and allocation size.  
  - Risk: medium (needs careful adjustment of debug/backtrace code)  
  - Effort: medium-large

- [ ] Use SIMD-optimized memcmp / memcpy for large strings and buffers  
  - Description: Use `mem_utils.memcmpSIMD`/`memcpySIMD` for `tableFindString` and other places where large buffers are frequently compared/copied (conditioned on length).  
  - Files: `src/table.zig` (`tableFindString`), call-sites doing big copies (string joins, matrix ops)  
  - Expected impact: medium on workloads with large strings/matrices/vectors  
  - Risk: low (already present helpers exist, just detect lengths and call)  
  - Effort: small-medium

- [ ] Reduce duplicated scanning for complex numbers / merge lookahead with parsing  
  - Description: Currently `peek_for_complex()` scans ahead then `parse_complex_token()` re-scans. Merge these steps or parse complex numbers inline in the number token logic to avoid duplicate scans.  
  - Files: `src/scanner_optimized.zig` (`peek_for_complex`, `number`, `parse_complex_token`)  
  - Expected impact: small-medium (per-token CPU saving)  
  - Risk: low  
  - Effort: small

- [ ] Avoid ephemeral copies in `fstring` parsing; parse expressions in-place where possible  
  - Description: `fstring` copies expression substrings to a temporary stack buffer and reparses them. Avoid copying by pointing the scanner at slices (or parse inline), reducing mem copies.  
  - Files: `src/compiler.zig` (`fstring`)  
  - Expected impact: small (faster format-string compile)  
  - Risk: medium (ensure scanner state management is robust)  
  - Effort: medium

---

## Longer-term / higher-effort items (large impact, higher risk)
- [ ] Consider widening jump offsets or adding a long-jump opcode to avoid 65535 limitation  
  - Description: Currently jumps/loops are constrained to 65535 bytes; adding a long-jump instruction or widening encoding avoids errors on large generated functions. Requires changes in bytecode and VM interpreter.  
  - Files: `src/chunk.zig`, `src/compiler.zig` (emitJump/patchJump), `src/vm.zig` (interpreter)  
  - Expected impact: allows compiling very large functions; architectural change  
  - Risk: high (bytecode/VM compatibility & testing)  
  - Effort: large

- [ ] Consider a more compact chunk layout (single allocation for code + debug data)  
  - Description: Instead of two separate allocations for `code` and `lines`, allocate one contiguous block for both to decrease allocation count and improve cache locality. Might complicate reallocation behavior.  
  - Files: `src/chunk.zig`  
  - Expected impact: reduced allocations; better locality for interpreter and compiler emission  
  - Risk: medium-high (changes to allocation/resize logic)  
  - Effort: medium-large

- [ ] More advanced: incremental or cache-based compilation for multi-file projects  
  - Description: Add caching of compilation units or incremental compile to avoid recompiling unchanged source (requires design & build system support).  
  - Expected impact: very large for big projects; design-heavy  
  - Risk: high  
  - Effort: large / project scope

---

## Safety/quality items (bugs & correctness related to performance)
- [ ] Ensure allocator ownership is tracked for string interning / `takeWithAllocator` to avoid double-free or leaks  
  - Description: Make ownership rules explicit (allocator tag on buffer) so `String.takeWithAllocator` can safely free the incoming buffer when an interned string exists. There are docs referencing memory-fix work in this area.  
  - Files: `src/objects/string.zig`, `src/mem_utils.zig`  
  - Expected impact: correctness & safety (prevents crashes)  
  - Risk: medium  
  - Effort: small-medium

- [ ] Avoid unnecessary allocations in error formatting (use small stack buffers or arena)  
  - Description: Replace `std.fmt.allocPrint` in hot error paths with stack-based formatting or use compiler arena to reduce allocations during error generation.  
  - Files: `src/errors.zig`, call-sites in `src/compiler.zig` which build suggestions.  
  - Expected impact: minor overall (errors are rare), but can be useful in noisy debug/test scenarios  
  - Risk: low  
  - Effort: small

---

## Benchmarks & acceptance criteria (what to measure)
- [ ] Add benchmark that compiles a representative large script and reports: tokenization time, parse time, emission time, memory allocations (GPA & arena)  
  - Acceptance: before/after runs show measurable improvements for the optimized tasks
- [ ] After each change, run the benchmark and record wall time and peak memory; aim for objective improvements (e.g., 10-30% improvement on targeted phase for medium/high-impact changes).

---

## Implementation / workflow suggestions
- [ ] Implement changes incrementally (one small change + benchmark + tests per PR)
- [ ] Add tests for corner cases where behavior might change (e.g., fstring edge-cases, long jumps)
- [ ] Run full test-suite and fuzz for parser/scanner resilience after changes
- [ ] Add an opt-in "compiler profiling" mode that prints counters & arena stats for each compile (helpful for continuous performance measurement)

---

If you'd like, I can:
- produce a small patch for the "quick wins" (arena reset + token hashing + instrumentation) and include micro-benchmarks, or
- generate a prioritized development plan that maps these checklist items to concrete PRs and tests.

Which actions do you want me to take next? (I can implement items one-by-one if you want.)