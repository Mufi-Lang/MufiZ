# Memory Operations Quick Reference

## Current Status

✅ **SIMD Arithmetic**: 2x faster - **USE THIS**  
❌ **SIMD Memory (ARM)**: Slower - **USE BUILTINS**  
🔄 **Platform-Aware**: Automatic selection

---

## Quick Decisions

### For Memory Operations (copy, set, compare)

```zig
// ✅ RECOMMENDED: Use Zig builtins
@memcpy(dest, src);
@memset(buffer, value);
const cmp = std.mem.order(u8, buf1, buf2);
```

**Why?** On ARM NEON, these are faster than our SIMD implementation.

### For Arithmetic Operations (math on arrays)

```zig
// ✅ RECOMMENDED: Use SIMD
const simd_utils = @import("simd_utils.zig");

simd_utils.SimdF64.add(result, a, b);        // 2.04x faster
simd_utils.SimdF64.mul(result, a, b);        // 2.00x faster
simd_utils.SimdF64.scale(result, data, 2.5); // 1.93x faster
const sum = simd_utils.SimdF64.sum(data);    // 1.76x faster
const var = simd_utils.SimdF64.variance(data, mean); // 1.79x faster
```

---

## API Reference

### SIMD Vector Operations (FAST ✅)

```zig
const simd_utils = @import("simd_utils.zig");

// Element-wise operations
simd_utils.SimdF64.add(dest, a, b);      // dest[i] = a[i] + b[i]
simd_utils.SimdF64.sub(dest, a, b);      // dest[i] = a[i] - b[i]
simd_utils.SimdF64.mul(dest, a, b);      // dest[i] = a[i] * b[i]
simd_utils.SimdF64.div(dest, a, b);      // dest[i] = a[i] / b[i]

// Scalar operations
simd_utils.SimdF64.scale(dest, a, scalar);     // dest[i] = a[i] * scalar
simd_utils.SimdF64.addScalar(dest, a, scalar); // dest[i] = a[i] + scalar

// Reductions
const sum = simd_utils.SimdF64.sum(data);
const variance = simd_utils.SimdF64.variance(data, mean);

// Also available: SimdF32 for 32-bit floats
simd_utils.SimdF32.add(dest, a, b);
```

### Memory Operations (via mem_utils)

```zig
const mem_utils = @import("mem_utils.zig");

// Platform-aware (uses builtin on ARM, SIMD on x86)
mem_utils.memcpySIMD(dest.ptr, src.ptr, count);
mem_utils.memsetSIMD(buffer.ptr, value, count);
const cmp = mem_utils.memcmpSIMD(buf1.ptr, buf2.ptr, count);

// Direct builtins (always fast)
@memcpy(dest_slice, src_slice);
@memset(buffer_slice, value);
const cmp = std.mem.order(u8, slice1, slice2);
```

---

## Configuration

### View Current Settings

```zig
const simd_utils = @import("simd_utils.zig");
std.debug.print("Arithmetic threshold: {}\n", .{simd_utils.config.min_simd_size});
std.debug.print("Memory threshold: {}\n", .{simd_utils.config.min_memory_simd_size});
```

### Adjust Thresholds

```zig
// For arithmetic operations (default: 32 bytes)
simd_utils.config.min_simd_size = 64;

// For memory operations (default: 512 bytes)
simd_utils.config.min_memory_simd_size = 1024;

// Force scalar for debugging
simd_utils.config.force_scalar = true;
```

### Platform Detection

```zig
const caps = simd_utils.getCapabilities();
std.debug.print("Platform: {s}\n", .{simd_utils.getArchitectureName()});
std.debug.print("SIMD available: {}\n", .{caps.available});
std.debug.print("f64 vector length: {}\n", .{caps.f64_vector_len});
```

---

## Performance Expectations

### Arithmetic Operations ✅
| Size  | Operation | Expected Speedup |
|-------|-----------|------------------|
| 1KB   | ADD/MUL   | 2.0x             |
| 4KB   | SCALE     | 1.9x             |
| 4KB   | SUM/VAR   | 1.8x             |

### Memory Operations ❌ (on ARM)
| Size  | Operation      | Expected Speedup |
|-------|----------------|------------------|
| All   | memcpy/memset  | 0.3-0.7x (slower!)|

**Note**: Use builtins for memory on ARM. May differ on x86-64.

---

## Common Patterns

### FloatVector Operations (Automatic SIMD)

```zig
const vec = FloatVector.fromSlice(allocator, data);
defer vec.deinit();

// These use SIMD internally (via fvec_simd.zig)
vec.add(other_vec);          // 2x faster
vec.mul(other_vec);          // 2x faster
vec.scale(2.5);              // 2x faster
const mean = vec.mean();     // 1.8x faster
const variance = vec.variance(); // 1.8x faster
```

### Direct SIMD Usage

```zig
const simd_utils = @import("simd_utils.zig");

// Check if SIMD is available
if (simd_utils.hasSIMD()) {
    // Use SIMD operations
    simd_utils.SimdF64.add(result, a, b);
} else {
    // Fallback (automatic in SIMD functions)
    for (0..a.len) |i| result[i] = a[i] + b[i];
}
```

### Batch Processing

```zig
// Process large arrays with SIMD
const chunk_size = 1024; // Good size for SIMD
var i: usize = 0;
while (i < data.len) : (i += chunk_size) {
    const end = @min(i + chunk_size, data.len);
    const chunk = data[i..end];
    
    // SIMD operations on chunk
    simd_utils.SimdF64.scale(output[i..end], chunk, factor);
}
```

---

## Testing & Benchmarking

### Run Tests

```bash
# Test SIMD utilities
zig test src/simd_utils.zig

# Test memory utilities
zig test src/mem_utils.zig
```

### Run Benchmark

```bash
# Build and run benchmark
zig build-exe src/simd_benchmark.zig -O ReleaseFast
./simd_benchmark

# On x86-64 with AVX2
zig build-exe src/simd_benchmark.zig -O ReleaseFast -Dcpu=x86_64_v3
./simd_benchmark
```

### Custom Benchmark Template

```zig
const std = @import("std");
const simd_utils = @import("simd_utils.zig");

pub fn main() !void {
    var data: [1024]f64 = undefined;
    for (&data, 0..) |*v, i| v.* = @floatFromInt(i);
    
    var timer = try std.time.Timer.start();
    
    // Scalar version
    timer.reset();
    for (0..10000) |_| {
        for (&data) |*v| v.* *= 2.0;
    }
    const scalar_time = timer.read();
    
    // SIMD version
    timer.reset();
    for (0..10000) |_| {
        simd_utils.SimdF64.scale(&data, &data, 2.0);
    }
    const simd_time = timer.read();
    
    const speedup = @as(f64, @floatFromInt(scalar_time)) / 
                    @as(f64, @floatFromInt(simd_time));
    std.debug.print("Speedup: {d:.2}x\n", .{speedup});
}
```

---

## Documentation

### Full Documentation
- `MEMORY_OPS_README.md` - Complete guide and recommendations
- `MEMORY_OPS_FINDINGS.md` - Detailed benchmark analysis
- `MEMORY_OPS_SUMMARY.md` - Executive summary
- `SIMD_MEMORY_OPTIMIZATION.md` - Deep dive into optimization strategies
- `SIMD_OPTIMIZATION_GUIDE.md` - General SIMD usage guide

### Implementation
- `src/simd_utils.zig` - Core SIMD infrastructure
- `src/mem_utils.zig` - Platform-aware memory utilities
- `src/objects/fvec_simd.zig` - FloatVector SIMD helpers
- `src/simd_benchmark.zig` - Benchmark suite

---

## Summary Cheat Sheet

| Operation Type    | Use This           | Speedup | Status |
|-------------------|--------------------|---------|--------|
| Vector ADD/MUL    | SIMD               | 2.0x    | ✅      |
| Vector SCALE      | SIMD               | 1.9x    | ✅      |
| SUM/VARIANCE      | SIMD               | 1.8x    | ✅      |
| memcpy (ARM)      | @memcpy builtin    | n/a     | ✅      |
| memset (ARM)      | @memset builtin    | n/a     | ✅      |
| memcpy (x86)      | Test both          | ???     | 🔬      |

**Bottom Line**: SIMD wins for math, builtins win for memory (on ARM).

---

*Last updated: Based on ARM NEON benchmarks*