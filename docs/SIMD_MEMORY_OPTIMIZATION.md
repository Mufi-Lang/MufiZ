# SIMD Memory Operations Optimization Guide

## Overview

This document explains the optimization strategies used for SIMD memory operations in MufiZ and why memory operations often show **worse** performance with naive SIMD implementations compared to scalar code.

## The Memory Operations Problem

### Why SIMD Can Be Slower for Memory Operations

Unlike arithmetic operations where SIMD excels, memory operations face several challenges:

1. **Memory Bandwidth Bottleneck**
   - Modern CPUs can execute SIMD instructions faster than memory can supply data
   - Memory bandwidth is often the limiting factor, not compute
   - SIMD doesn't increase memory bandwidth, just processes data faster once loaded

2. **Alignment Penalties**
   - Unaligned SIMD loads/stores can be 2-3x slower than aligned ones
   - On some architectures (older x86), unaligned access causes hardware exceptions
   - ARM NEON handles unaligned better but still has performance cost

3. **Setup Overhead**
   - SIMD code has more instructions (setup vectors, handle remainders)
   - For small buffers (<512 bytes), this overhead exceeds benefits
   - Branch prediction and loop unrolling work better for small scalar loops

4. **Cache Effects**
   - Small buffers fit in L1 cache where scalar code is extremely fast
   - SIMD instructions may evict useful data from cache
   - Prefetching doesn't help for small, already-cached data

5. **Compiler Optimizations**
   - Modern compilers generate highly optimized code for `memcpy`, `memset`, `memcmp`
   - Often calls into platform-specific assembly (glibc, musl, etc.)
   - These implementations use rep movsb, AVX-512, and other tricks

## Optimization Strategies Implemented

### 1. Adaptive Thresholds

```zig
pub const SimdConfig = struct {
    /// For arithmetic operations (lower overhead)
    min_simd_size: usize = 32,
    
    /// For memory operations (higher overhead due to alignment)
    min_memory_simd_size: usize = 512,
    
    force_scalar: bool = false,
};
```

**Why 512 bytes for memory?**
- Below 512 bytes: compiler's builtin is faster
- 512-1024 bytes: SIMD becomes competitive
- Above 1024 bytes: SIMD can provide 20-50% improvement with proper alignment

### 2. Overlapping Vector Technique

For moderate sizes (512-1024 bytes):

```zig
fn copyOverlapping(dest: [*]u8, src: [*]const u8, count: usize, vector_len: usize) void {
    // Copy main body with full vectors
    var i: usize = 0;
    while (i + vector_len <= count) : (i += vector_len) {
        const vec = src[i..][0..vector_len].*;
        dest[i..][0..vector_len].* = vec;
    }
    
    // Handle tail with overlapping vector (reads some bytes twice)
    if (remaining >= vector_len / 2) {
        const tail_start = count - vector_len;
        const vec = src[tail_start..][0..vector_len].*;
        dest[tail_start..][0..vector_len].* = vec;
    }
}
```

**Benefits:**
- No alignment handling needed (simpler code)
- No scalar tail loop (better branch prediction)
- Overlapping read/write is safe and fast for read-only src

### 3. Alignment-Aware Copy for Large Buffers

For large buffers (>1024 bytes):

```zig
fn copyAligned(dest: [*]u8, src: [*]const u8, count: usize, vector_len: usize) void {
    var i: usize = 0;
    
    // Step 1: Align destination pointer
    const dest_misalignment = @intFromPtr(dest) % vector_len;
    if (dest_misalignment != 0) {
        const align_bytes = vector_len - dest_misalignment;
        @memcpy(dest[0..align_bytes], src[0..align_bytes]);
        i = align_bytes;
    }
    
    // Step 2: Copy with aligned stores (fast)
    while (i + vector_len <= count) : (i += vector_len) {
        const vec = src[i..][0..vector_len].*;
        dest[i..][0..vector_len].* = vec;
    }
    
    // Step 3: Copy remainder
    if (i < count) {
        @memcpy(dest[i..count], src[i..count]);
    }
}
```

**Why align destination?**
- Aligned stores are 2-3x faster than unaligned stores
- Source alignment matters less (loads are more forgiving)
- Small scalar prefix is worth the aligned bulk copy

### 4. Platform-Specific Vector Lengths

```zig
pub const SimdCapabilities = struct {
    available: bool,
    f32_vector_len: usize,  // 4 (SSE/NEON) or 8 (AVX2)
    f64_vector_len: usize,  // 2 (SSE/NEON) or 4 (AVX2)
    u8_vector_len: usize,   // 16 (SSE/NEON) or 32 (AVX2)
    
    pub fn detect() SimdCapabilities {
        // Detect at compile time based on target
    }
};
```

**ARM NEON vs x86:**
- ARM NEON: Always 128-bit (16 bytes)
- x86 SSE2: 128-bit (16 bytes)
- x86 AVX2: 256-bit (32 bytes)
- x86 AVX-512: 512-bit (64 bytes) - often not worth it for memory

## Performance Characteristics

### Expected Speedups by Buffer Size

| Size Range | memcpy Speedup | memset Speedup | memcmp Speedup |
|------------|----------------|----------------|----------------|
| <512 bytes | 0.5-0.8x (slower!) | 0.6-0.9x | 0.7-1.0x |
| 512-1KB    | 0.9-1.2x | 1.0-1.3x | 1.1-1.4x |
| 1KB-4KB    | 1.1-1.5x | 1.2-1.6x | 1.3-1.7x |
| 4KB-64KB   | 1.2-1.8x | 1.4-2.0x | 1.5-2.2x |
| >64KB      | 1.1-1.5x (cache miss) | 1.3-1.8x | 1.4-2.0x |

**Note:** These are realistic expectations. Claims of 4-8x speedup for memory operations are usually misleading or measured incorrectly.

### Platform Differences

**ARM NEON (AArch64):**
- Better unaligned access handling
- Memory-bound sooner (narrower memory bus)
- SIMD advantage starts at larger sizes (~1KB)
- Typical speedup: 1.2-1.5x for large buffers

**x86-64 SSE2/AVX2:**
- Alignment more critical (especially pre-Haswell)
- Better memory bandwidth
- Can benefit from larger vector sizes (AVX2)
- Typical speedup: 1.3-1.8x for large buffers with AVX2

## Usage Guidelines

### When to Use SIMD Memory Operations

✅ **Good Use Cases:**
- Large buffer copies (>1KB)
- Batch processing of many buffers
- Known aligned buffers
- Zero-fill large arrays
- String search in long strings

❌ **Poor Use Cases:**
- Small buffers (<512 bytes)
- Single operation (no amortization)
- Unknown/likely unaligned data
- Temporary/stack buffers (compiler optimizes well)

### Configuration Tuning

```zig
// For your specific platform, benchmark and adjust:
simd_utils.config.min_memory_simd_size = 512;  // Default

// For ARM NEON, you might increase:
simd_utils.config.min_memory_simd_size = 1024;

// For x86 AVX2 with aligned data, you might decrease:
simd_utils.config.min_memory_simd_size = 256;

// To disable and verify baseline:
simd_utils.config.force_scalar = true;
```

### Benchmarking Tips

```zig
// Bad benchmark (measures wrong thing):
timer.reset();
for (0..1000) |_| {
    SimdMemory.copy(dst.ptr, src.ptr, size);
}
// Problem: data stays in L1 cache, unrealistic

// Good benchmark:
timer.reset();
for (0..1000) |_| {
    SimdMemory.copy(dst.ptr, src.ptr, size);
    std.mem.doNotOptimizeAway(&dst); // Prevent optimization
    // Optional: flush cache between iterations for realistic memory access
}
```

## Advanced Optimizations (Future Work)

### 1. Non-Temporal Stores
For very large buffers (>L3 cache), use non-temporal stores to avoid cache pollution:

```zig
// x86: _mm_stream_si128
// ARM: DC ZVA (zero cache line)
```

### 2. Software Prefetching
Prefetch data ahead of SIMD processing:

```zig
// Prefetch N cache lines ahead
@prefetch(src + i + N * 64, .{ .locality = 0 });
```

### 3. Loop Unrolling
Unroll SIMD loops 2-4x for better instruction-level parallelism:

```zig
while (i + vector_len * 4 <= count) : (i += vector_len * 4) {
    const vec0 = src[i + vector_len * 0..][0..vector_len].*;
    const vec1 = src[i + vector_len * 1..][0..vector_len].*;
    const vec2 = src[i + vector_len * 2..][0..vector_len].*;
    const vec3 = src[i + vector_len * 3..][0..vector_len].*;
    dest[i + vector_len * 0..][0..vector_len].* = vec0;
    dest[i + vector_len * 1..][0..vector_len].* = vec1;
    dest[i + vector_len * 2..][0..vector_len].* = vec2;
    dest[i + vector_len * 3..][0..vector_len].* = vec3;
}
```

### 4. Platform-Specific Intrinsics
Use hardware-specific instructions for hot paths:

```zig
// x86: rep movsb (for >2KB on modern CPUs)
// ARM: DC ZVA + ST1 (for cache-line-aligned zeros)
```

## Conclusion

**Key Takeaways:**

1. **SIMD is not a magic bullet for memory operations** - expect modest improvements (1.2-1.8x), not miracles
2. **Size matters** - small buffers (<512 bytes) should use scalar code
3. **Alignment matters** - align destination for best performance
4. **Compiler builtins are good** - only beat them for specific cases
5. **Measure, don't assume** - benchmark on your target platform

The optimizations in `simd_utils.zig` provide a good balance of:
- Simplicity (maintainable code)
- Performance (competitive with hand-tuned implementations)
- Safety (works correctly for all sizes and alignments)
- Portability (adapts to ARM NEON, x86 SSE/AVX, WASM SIMD)

For most use cases, these implementations will be sufficient. For extreme performance requirements, consider platform-specific assembly or LLVM intrinsics for critical hot paths.

## References

- [Agner Fog's Optimization Manuals](https://www.agner.org/optimize/)
- [Intel Intrinsics Guide](https://www.intel.com/content/www/us/en/docs/intrinsics-guide/)
- [ARM NEON Programmer's Guide](https://developer.arm.com/documentation/den0018/a)
- [LLVM Vector Programming Guide](https://llvm.org/docs/Vectorizers.html)
- [glibc memcpy implementation](https://sourceware.org/git/?p=glibc.git;a=blob;f=sysdeps/x86_64/multiarch/memcpy-avx-unaligned.S)