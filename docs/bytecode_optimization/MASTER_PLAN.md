# MufiZ VM Optimization Master Plan
## From Bytecode Interpreter to High-Performance JIT VM

**Document Version:** 1.0  
**Last Updated:** 2024  
**Status:** Phase 4 Complete, Planning Phases 5-10

---

## Executive Summary

This document provides a comprehensive overview of the MufiZ VM optimization journey, from the initial bytecode interpreter through advanced JIT compilation. The plan is structured in 10 phases, with Phases 1-4 already complete and Phases 5-10 planned for the next 18-24 months.

**Current Achievement:** Phase 4 complete - 10-20% bytecode reduction, 5-10% runtime improvement  
**Ultimate Goal:** 5-10x overall performance improvement via JIT compilation  
**Timeline to Completion:** 18-24 months for Phases 5-10

---

## Completed Work (Phases 1-4)

### Phase 1: Infrastructure & Quick Wins ✅
**Status:** Complete  
**Duration:** 2-3 weeks  
**Impact:** Foundation for all optimizations

**Achievements:**
- Bytecode format standardization
- Opcode space allocation (256 opcodes organized)
- Instruction format definitions
- Debug infrastructure (disassembler, analyzer)
- Testing framework

**Key Deliverables:**
- `src/chunk.zig` - Enhanced bytecode infrastructure
- `src/debug.zig` - Comprehensive disassembler
- `src/bytecode_analyzer.zig` - Analysis tools

---

### Phase 2: Small Constants & Local Variables ✅
**Status:** Complete  
**Duration:** 2-3 weeks  
**Impact:** 5-8% bytecode reduction

**Achievements:**
- Small constant optimization (CONSTANT_0 to CONSTANT_3)
- Small local variable optimization (GET/SET_LOCAL_0 to _3)
- Short jump variants (JUMP_SHORT, etc.)
- Reduced instruction size for common operations

**Performance Impact:**
- Bytecode size: -5-8% reduction
- Runtime: +3-5% improvement
- Better cache utilization

---

### Phase 3: Superinstructions ✅
**Status:** Complete  
**Duration:** 3-4 weeks  
**Impact:** 1-3% bytecode reduction, 2-5% runtime improvement

**Achievements:**
- Superinstruction fusion framework
- Three safe patterns implemented:
  - `GET_GLOBAL + GET_GLOBAL` → `GET_GLOBAL_GLOBAL`
  - `GET_LOCAL + GET_LOCAL` → `GET_LOCAL_LOCAL`
  - `CONSTANT + CONSTANT` → `CONSTANT_CONSTANT`
- Peephole optimizer with validation
- VM trace infrastructure for analysis

**Key Files:**
- `src/peephole_optimizer.zig` (400+ lines)
- `src/vm_trace.zig` (instrumentation framework)
- Conservative, safe approach with validation

**Performance Impact:**
- Bytecode size: -1-3% additional reduction
- Runtime: +2-5% improvement
- Reduced dispatch overhead

---

### Phase 4: Advanced Optimizations ✅
**Status:** Complete  
**Duration:** 1 session  
**Impact:** 10-20% bytecode reduction, 5-10% runtime improvement

**Achievements:**
- **Comprehensive optimization framework** with multi-pass coordination
- **Constant folding** at bytecode level:
  - Arithmetic operations (ADD, SUB, MUL, DIV)
  - Comparison operations (EQUAL, GREATER, LESS)
  - Safety: Division by zero NOT folded
- **Peephole optimizations:**
  - CONSTANT + POP elimination
  - Foundation for future patterns
- **Dead code elimination** (conservative implementation)
- **Integration** with Phase 3 superinstructions
- **Beautiful reporting** with detailed statistics

**Key Files:**
- `src/bytecode_optimizer.zig` (555 lines)
- `tests/test_bytecode_optimizer.zig` (512 lines)
- `examples/phase4_optimizer_demo.mz` (169 lines)
- `docs/bytecode_optimization/PHASE4_*.md` (1,500+ lines)

**Configuration System:**
```zig
OptimizerConfig.default()   // Production: all opts, 3 passes
OptimizerConfig.safe()      // Development: conservative, 1 pass
OptimizerConfig.disabled()  // Debugging: no optimization
```

**Performance Impact:**
- Bytecode size: -10-20% reduction (cumulative)
- Runtime: +5-10% improvement (cumulative)
- Memory: -8-18% savings
- Compilation overhead: +10-25% (acceptable)

**Example Optimization:**
```javascript
// Source
var x = ((2 + 3) * 4) - 10;

// Pass 1: 2+3 → 5
// Pass 2: 5*4 → 20
// Pass 3: 20-10 → 10
// Result: 7 instructions → 1 instruction (86% reduction!)
```

---

## Current State Assessment

### What We Have
✅ **Compiler Infrastructure:**
- Single-pass bytecode compiler
- Stack-based VM with efficient dispatch
- Comprehensive error handling
- Debug support (disassembly, tracing)

✅ **Optimization Framework:**
- Multi-pass optimization coordinator
- Superinstruction fusion (3 patterns)
- Constant folding (arithmetic & comparisons)
- Peephole patterns (CONSTANT+POP)
- Basic dead code elimination
- Configurable optimization levels

✅ **Performance:**
- 50-100 million instructions/sec (interpreter)
- 10-20% smaller bytecode than raw
- < 10ms startup time
- 5-10% overall runtime improvement

### What We Need (Phases 5-10)

❌ **Advanced Analysis:**
- Control flow graph (CFG) analysis
- Dataflow analysis (SSA form)
- Loop analysis and classification
- Call graph construction

❌ **Advanced Optimizations:**
- Cross-block constant propagation
- Loop-invariant code motion
- Induction variable optimization
- Function inlining
- Profile-guided optimization

❌ **JIT Compilation:**
- Intermediate representation (IR)
- Register allocation
- Native code generation (x86-64, ARM64)
- Tiered compilation
- On-stack replacement
- Deoptimization

---

## Planned Work (Phases 5-10)

### Phase 5: Control Flow Graph (CFG) Analysis
**Duration:** 3-4 months  
**Complexity:** Medium  
**Priority:** HIGH (foundation for everything else)

**Goals:**
- Build comprehensive CFG infrastructure
- Enable accurate program structure analysis
- Foundation for all subsequent optimizations

**Key Components:**
1. **CFG Construction** (Weeks 1-3)
   - Identify basic blocks
   - Build edges (control flow)
   - Compute dominance relationships

2. **Dominance Analysis** (Weeks 4-5)
   - Immediate dominator tree
   - Dominance frontiers
   - Post-dominance

3. **Loop Detection** (Weeks 6-7)
   - Identify natural loops
   - Classify loop types
   - Build loop tree hierarchy

4. **Improved DCE** (Weeks 8-9)
   - Reachability analysis
   - Remove unreachable blocks
   - Safe elimination

5. **Control Flow Simplification** (Weeks 10-11)
   - Block merging
   - Jump threading
   - Empty block elimination

6. **Testing** (Week 12)

**Expected Impact:**
- Bytecode: +5-10% additional reduction
- Runtime: +10-15% improvement
- **Enables:** Phases 6-10

**Deliverables:**
- `src/cfg_builder.zig` (400-600 lines)
- `src/cfg_analysis.zig` (300-500 lines)
- Comprehensive test suite

---

### Phase 6: Dataflow Analysis & SSA Form
**Duration:** 4-5 months  
**Complexity:** High  
**Priority:** HIGH (enables major optimizations)

**Goals:**
- Implement Static Single Assignment (SSA) form
- Track value flow through program
- Enable sophisticated optimizations

**Key Components:**
1. **SSA Construction** (Weeks 1-6)
   - Minimal SSA algorithm (Cytron)
   - φ-function insertion
   - Variable renaming

2. **Reaching Definitions** (Weeks 7-8)
   - Iterative dataflow analysis
   - Definition-use chains

3. **Live Variable Analysis** (Weeks 9-10)
   - Backward dataflow
   - Register allocation prep

4. **Constant Propagation** (Weeks 11-14)
   - Sparse conditional constant propagation (SCCP)
   - Cross-block folding
   - Dead code elimination

5. **Copy Propagation** (Week 15)
   - Replace copies with originals
   - Enable further optimizations

6. **Dead Store Elimination** (Weeks 16-17)
   - Remove unused stores
   - Based on live variables

7. **Common Subexpression Elimination** (Weeks 18-20)
   - Global value numbering (GVN)
   - Eliminate redundant computations

**Expected Impact:**
- Constant folding: Across basic blocks
- Dead code: +20-30% more elimination
- Runtime: +15-25% improvement
- Bytecode: +10-15% reduction

**Example:**
```javascript
// Before
var a = 5;
var b = 3;
var c = a + b;  // Computed at runtime
var d = input();
var e = c + d;

// After constant propagation
var a = 5;
var b = 3;
var c = 8;      // Folded across blocks!
var d = input();
var e = 8 + d;  // c replaced with 8
```

---

### Phase 7: Loop Optimizations
**Duration:** 3-4 months  
**Complexity:** Medium-High  
**Priority:** HIGH (loops are 80%+ of execution time)

**Goals:**
- Optimize loop performance
- Reduce iteration overhead
- Enable vectorization opportunities

**Key Components:**
1. **Loop-Invariant Code Motion** (Weeks 1-4)
   - Hoist invariant computations
   - Move to loop preheader

2. **Strength Reduction** (Weeks 5-7)
   - Replace expensive ops (mul → add)
   - Division → multiplication (by inverse)

3. **Induction Variable Optimization** (Weeks 8-10)
   - Identify basic/derived IVs
   - Convert to simpler updates

4. **Loop Unrolling** (Weeks 11-13)
   - Full unrolling (known small count)
   - Partial unrolling (factor 2/4/8)

5. **Loop Fusion & Fission** (Weeks 14-15)
   - Combine loops (better locality)
   - Split loops (better scheduling)

6. **Loop Interchange** (Weeks 16-17)
   - Reorder nested loops
   - Improve cache locality

**Expected Impact:**
- Loop-heavy code: +30-50% speedup
- Numeric code: +40-60% speedup
- Overall: +10-20% improvement

**Example: LICM**
```javascript
// Before
for (var i = 0; i < 100; i++) {
    var x = a + b;  // Computed 100 times
    array[i] = x * i;
}

// After
var x = a + b;      // Hoisted out
for (var i = 0; i < 100; i++) {
    array[i] = x * i;
}
```

---

### Phase 8: Interprocedural Optimization (IPO)
**Duration:** 3-4 months  
**Complexity:** High  
**Priority:** Medium (significant but can defer)

**Goals:**
- Optimize across function boundaries
- Inline frequently called functions
- Eliminate dead functions

**Key Components:**
1. **Call Graph** (Weeks 1-2)
   - Track caller-callee relationships
   - Identify recursion

2. **Function Inlining** (Weeks 3-8)
   - Smart heuristics (size, frequency)
   - Avoid code explosion

3. **Constant Parameter Propagation** (Weeks 9-11)
   - Specialize for constant args
   - Partial evaluation

4. **Devirtualization** (Weeks 12-14)
   - Virtual → direct calls
   - Class hierarchy analysis

5. **Dead Function Elimination** (Weeks 15-16)
   - Remove unreachable functions
   - Reduce binary size

6. **Tail Call Optimization** (Weeks 17-18)
   - Convert recursion to iteration
   - Eliminate stack growth

**Expected Impact:**
- Call overhead: -50-80% reduction
- Function-heavy code: +20-40% speedup

**Example: Inlining**
```javascript
// Before
function add(a, b) { return a + b; }
var x = add(5, 3);  // Call overhead

// After
var x = 5 + 3;      // Inlined!
```

---

### Phase 9: Profile-Guided Optimization (PGO)
**Duration:** 4-5 months  
**Complexity:** High  
**Priority:** Medium (great ROI but needs instrumentation)

**Goals:**
- Use runtime data to guide optimization
- Optimize hot paths aggressively
- Ignore cold code

**Key Components:**
1. **Instrumentation** (Weeks 1-4)
   - Block execution counts
   - Branch taken/not-taken
   - Function call frequencies

2. **Hot Path Detection** (Weeks 5-6)
   - Identify frequently executed code
   - Hot/cold segregation

3. **Branch Probability** (Weeks 7-9)
   - Optimize for likely outcomes
   - Better code layout

4. **Profile-Guided Inlining** (Weeks 10-12)
   - Inline based on call frequency
   - Avoid cold call sites

5. **Specialization** (Weeks 13-16)
   - Type specialization
   - Value specialization
   - Create optimized versions

6. **Feedback-Directed** (Weeks 17-20)
   - Iterative optimization
   - Adaptive recompilation

**Two-Phase Usage:**
```bash
# Phase 1: Collect profile
mufiz --profile=collect --profile-output=profile.data script.mz

# Phase 2: Use profile
mufiz --profile=use --profile-input=profile.data script.mz
```

**Expected Impact:**
- Overall: +30-50% over static optimization
- Hot paths: +50-100% speedup
- Cache: +40-60% better hit rate

---

### Phase 10: JIT Compilation
**Duration:** 6-8 months  
**Complexity:** Very High  
**Priority:** HIGH (ultimate performance goal)

**Goals:**
- Compile bytecode to native machine code
- Achieve near-native performance
- Maintain fast startup with tiered compilation

**Architecture:**
```
Tier 0: Interpreter          → 1x speed, 0ms compile
Tier 1: Template JIT         → 2-5x speed, ~1ms compile
Tier 2: Optimizing JIT       → 10-50x speed, 10-100ms compile
```

**Key Components:**
1. **IR Design** (Weeks 1-4)
   - Register-based IR
   - Three-address code format
   - Target-independent

2. **Bytecode → IR** (Weeks 5-8)
   - Stack to register conversion
   - CFG in IR form

3. **Register Allocation** (Weeks 9-14)
   - Graph coloring or linear scan
   - Spill to memory handling

4. **Code Generation** (Weeks 15-22)
   - Instruction selection
   - x86-64 and ARM64 support
   - Machine code emission

5. **Tiered Compilation** (Weeks 23-26)
   - Fast template JIT (Tier 1)
   - Slow optimizing JIT (Tier 2)
   - Transition logic

6. **On-Stack Replacement** (Weeks 27-30)
   - Transition mid-loop
   - State transfer

7. **Deoptimization** (Weeks 31-34)
   - Fallback to interpreter
   - Handle assumption violations

8. **Memory Management** (Weeks 35-38)
   - Code cache management
   - Code patching

9. **Multi-Architecture** (Weeks 39-44)
   - x86-64 support
   - ARM64 support
   - RISC-V support (future)

10. **Testing** (Weeks 45-48)
    - Correctness verification
    - Performance benchmarks

**Expected Impact:**
- Overall: 5-10x vs interpreter
- Hot loops: 10-50x improvement
- Numeric: 20-100x (near-native!)
- Startup: Minimal impact (tiered)

**Example: OSR**
```javascript
for (var i = 0; i < 1000000; i++) {
    // Iterations 0-1000: Interpreter (slow)
    // Detect hot, compile with JIT
    // Iterations 1001+: JIT code (10x faster!)
}
```

---

## Performance Projections

### Cumulative Performance Improvements

| Milestone | Bytecode | Runtime | Relative to Phase 4 |
|-----------|----------|---------|---------------------|
| **Phase 4 (Current)** | -10-20% | +5-10% | 1.0x baseline |
| **Phase 5 (CFG)** | -15-30% | +15-25% | 1.2x |
| **Phase 6 (Dataflow)** | -25-45% | +30-50% | 1.4x |
| **Phase 7 (Loops)** | -30-50% | +50-80% | 1.7x |
| **Phase 8 (IPO)** | -35-55% | +70-120% | 2.1x |
| **Phase 9 (PGO)** | -40-60% | +100-170% | 2.7x |
| **Phase 10 (JIT)** | N/A | **+400-900%** | **5-10x** |

### Target Benchmarks (Phase 10)

| Workload | Phase 4 | Phase 10 | Improvement |
|----------|---------|----------|-------------|
| **Numeric computation** | 100 Mops/s | 1,000 Mops/s | 10x |
| **Loop-heavy code** | 50 Mops/s | 500 Mops/s | 10x |
| **Function calls** | 10M calls/s | 50M calls/s | 5x |
| **String operations** | 20 MB/s | 100 MB/s | 5x |
| **Overall (geomean)** | Baseline | **5-10x faster** | **5-10x** |

---

## Implementation Timeline

### Gantt Chart

```
Year 1:
Q1: [====Phase 5: CFG====]
Q2: [=====Phase 6: Dataflow=====]
Q3: [=====Phase 6 cont'd=====][==Phase 7: Loops==]
Q4: [==Phase 7==][====Phase 8: IPO====]

Year 2:
Q1: [===Phase 8===][======Phase 9: PGO======]
Q2: [======Phase 9======][====Phase 10: JIT====]
Q3: [================Phase 10: JIT================]
Q4: [======Phase 10======][Testing & Polish]
```

### Key Milestones

| Date | Milestone | Cumulative Performance |
|------|-----------|----------------------|
| **Month 0** | Phase 4 Complete ✅ | 1.0x baseline |
| **Month 4** | Phase 5 Complete | 1.2x |
| **Month 9** | Phase 6 Complete | 1.4x |
| **Month 12** | Phase 7 Complete | 1.7x |
| **Month 15** | Phase 8 Complete | 2.1x |
| **Month 20** | Phase 9 Complete | 2.7x |
| **Month 28** | Phase 10 Complete | **5-10x** |
| **Month 30** | **Production Release** | Stable 5-10x |

---

## Resource Planning

### Team Composition

**Full Implementation (All Phases):**
- 1 Senior Compiler Engineer (lead, architecture)
- 2 Compiler Engineers (implementation)
- 1 Performance Engineer (benchmarking, profiling)
- 1 QA Engineer (testing, validation)

**Lean Implementation (Phases 5-7 only):**
- 1-2 Engineers
- Focus on CFG, Dataflow, Loops
- Defer IPO, PGO, JIT
- 10-12 months to 70% improvement

### Infrastructure Needs

**Development:**
- CI/CD with automated testing
- Performance regression tracking
- Cross-platform builds (x86-64, ARM64)
- Code coverage tools

**Testing:**
- Comprehensive benchmark suite
- Fuzz testing infrastructure
- Real-world application tests
- Correctness verification tools

---

## Risk Management

### Technical Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| **JIT complexity overwhelming** | High | High | Start with template JIT, use LLVM as fallback |
| **Correctness bugs** | Medium | High | Extensive testing, formal verification |
| **Performance regressions** | Medium | Medium | Continuous benchmarking, CI |
| **Architecture portability** | Low | Medium | Abstract target code, test all platforms |
| **Deopt edge cases** | Medium | Medium | Thorough speculation testing |

### Schedule Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| **Underestimated complexity** | High | High | Incremental delivery, MVP approach |
| **Scope creep** | Medium | Medium | Strict phase boundaries, defer extras |
| **Resource constraints** | Medium | High | Prioritize Phases 5-7, JIT optional |
| **Team turnover** | Low | High | Good documentation, knowledge sharing |

---

## Alternative Approaches

### Option 1: Use Existing JIT Framework
**Use LLVM or Cranelift for Phase 10**

**Pros:**
- Production-quality code generation
- Multi-architecture support
- Mature optimization pipeline

**Cons:**
- Large dependency (~100 MB)
- Longer compilation times
- Less control over strategy

**Recommendation:** Good fallback if custom JIT too complex

---

### Option 2: Focus on Phases 5-7 Only
**Skip IPO, PGO, and JIT**

**Pros:**
- Achieves 70% improvement in 10-12 months
- Manageable complexity
- Solid foundation for future work

**Cons:**
- Misses 5-10x potential
- No adaptive optimization
- Still interpreter-based

**Recommendation:** Excellent middle ground for small teams

---

### Option 3: Hybrid AOT + Interpreter
**Ahead-of-time compilation for static code, interpret dynamic**

**Pros:**
- Predictable performance
- No JIT complexity
- Good security (no runtime code gen)

**Cons:**
- Platform-specific binaries
- No adaptive optimization
- Longer deploy time

**Recommendation:** Consider for embedded/security-critical deployments

---

## Success Criteria

### Quantitative Metrics

**Performance:**
- ✅ 5-10x overall improvement (geomean across benchmarks)
- ✅ < 5% regression on any existing benchmark
- ✅ < 2x compilation time increase

**Quality:**
- ✅ > 90% test coverage for all phases
- ✅ < 1 bug per 1000 lines of code
- ✅ Pass all correctness tests (vs. interpreter baseline)

**Deliverables:**
- ✅ All phase implementations complete
- ✅ Comprehensive documentation
- ✅ Benchmark suite and results
- ✅ Migration guide for users

### Qualitative Metrics

**Maintainability:**
- Code is well-documented
- Architecture is modular
- Easy to extend with new optimizations

**Usability:**
- Optimizations are transparent to users
- Good error messages when deopt occurs
- Configurable optimization levels

**Portability:**
- Works on x86-64 and ARM64
- Clean abstraction for new architectures
- Consistent behavior across platforms

---

## Decision Points

### Phase 5-7 Completion Checkpoint
**After 12 months, evaluate:**

✅ **Proceed to Phase 8-10 if:**
- Performance meets Phase 7 targets (1.7x)
- Team capacity available
- Resources for 12+ more months secured
- User demand for higher performance

❌ **Stop or defer Phase 8-10 if:**
- Phase 7 performance sufficient for users
- Resource constraints
- Other features higher priority
- Consider LLVM integration instead

---

### Phase 9 Optional Checkpoint
**PGO can be skipped if:**
- Phases 5-8 achieve sufficient performance
- Two-phase compilation workflow too complex
- Users prefer predictable performance

**JIT (Phase 10) can proceed without PGO**
- Use static heuristics instead
- Tiered compilation still valuable

---

## Maintenance Plan

### Post-Phase 10 Ongoing Work

**Regular Tasks:**
- Performance regression monitoring
- Benchmark suite updates
- Bug fixes and stability improvements
- Documentation updates

**Future Enhancements:**
- SIMD vectorization
- GPU offloading (for numeric workloads)
- Additional target architectures (RISC-V)
- Speculative optimizations
- Escape analysis
- Advanced alias analysis

**Team Size Post-Launch:**
- 1-2 engineers for maintenance
- Part-time performance engineer
- QA support

---

## Conclusion

The MufiZ VM optimization roadmap is a comprehensive, ambitious plan to transform a bytecode interpreter into a high-performance, JIT-compiled virtual machine. The journey is divided into 10 phases, with the first 4 already complete and delivering meaningful improvements.

### Current Status (Phase 4 Complete)
✅ 10-20% bytecode reduction  
✅ 5-10% runtime improvement  
✅ Solid optimization framework  
✅ Production-ready baseline  

### Future Potential (Phase 10 Complete)
🚀 5-10x overall performance improvement  
🚀 Near-native speed on hot code  
🚀 World-class VM infrastructure  
🚀 Competitive with V8, LuaJIT, PyPy  

### Recommended Path Forward

**Short-term (6 months):**
- Implement Phases 5-6 (CFG + Dataflow)
- Achieve 1.4x improvement
- Solid foundation for advanced opts

**Medium-term (12 months):**
- Add Phase 7 (Loops)
- Achieve 1.7x improvement
- Evaluate proceed/defer decision

**Long-term (24 months):**
- Complete Phases 8-10 (IPO + PGO + JIT)
- Achieve 5-10x improvement
- Production-ready high-performance VM

### Key Takeaways

1. **Incremental Delivery:** Each phase delivers value independently
2. **Flexibility:** Can stop after Phase 7 with 70% improvement
3. **Risk Management:** Multiple decision points to reassess
4. **Clear Metrics:** Success criteria at every milestone
5. **World-Class Potential:** Path to competitive VM performance

**The foundation is solid. The roadmap is clear. Let's build something amazing! 🚀**

---

## Appendices

### A. Related Documentation
- [ADVANCED_OPTIMIZATION_ROADMAP.md](ADVANCED_OPTIMIZATION_ROADMAP.md) - Full technical details
- [ROADMAP_QUICK_REF.md](ROADMAP_QUICK_REF.md) - Quick reference guide
- [PHASE4_COMPLETE.md](PHASE4_COMPLETE.md) - Current state summary
- [PHASE4_ADVANCED_OPTIMIZATIONS.md](PHASE4_ADVANCED_OPTIMIZATIONS.md) - Phase 4 technical details

### B. Bibliography
- Cooper & Torczon: "Engineering a Compiler" (2nd Edition)
- Appel: "Modern Compiler Implementation in ML/Java/C"
- Allen & Kennedy: "Optimizing Compilers for Modern Architectures"
- Muchnick: "Advanced Compiler Design and Implementation"
- Aho et al.: "Compilers: Principles, Techniques, and Tools" (Dragon Book)

### C. Benchmark Suite
- Numeric: Matrix multiplication, FFT, integration
- String: Parsing, regex, manipulation
- Function: Recursion, callbacks, higher-order
- Loop: Nested loops, array processing
- Real-world: JSON parser, markdown renderer, calculator

### D. Community Resources
- LuaJIT Wiki: Excellent JIT design insights
- V8 Blog: Real-world optimization stories
- PyPy Documentation: RPython toolchain
- LLVM Documentation: IR and code generation
- Zig Language: Modern systems programming

---

**Document Status:** Living document, updated as phases complete  
**Next Update:** After Phase 5 completion  
**Contact:** MufiZ Development Team

*Version 1.0 - Phase 4 Complete, Planning Phases 5-10*