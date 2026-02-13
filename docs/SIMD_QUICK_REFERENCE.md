# SIMD Quick Reference Card

## 🚀 Quick Start

```zig
const simd_utils = @import("simd_utils.zig");
const fvec_simd = @import("objects/fvec_simd.zig");

// Check what your CPU supports
simd_utils.printCapabilities();
```

## 📊 Platform Support

| Platform | Architecture | Vector Size (f64) |
|----------|-------------|-------------------|
| x86_64 AVX-512 | `x86_64+avx512f` | 16 elements (512-bit) |
| x86_64 AVX2 | `x86_64+avx2` | 8 elements (256-bit) |
| x86_64 SSE2 | `x86_64+sse2` | 4 elements (128-bit) |
| ARM NEON | `aarch64+neon` | 4 elements (128-bit) |
| WASM SIMD | `wasm32/64+simd128` | 4 elements (128-bit) |

## 🔧 Memory Operations

```zig
// Copy memory with SIMD
simd_utils.SimdMemory.copy(dest_ptr, src_ptr, byte_count);

// Compare memory with SIMD
const result = simd_utils.SimdMemory.compare(ptr1, ptr2, byte_count);
// Returns: -1 (less), 0 (equal), 1 (greater)

// Set memory with SIMD
simd_utils.SimdMemory.set(ptr, value, byte_count);
```

## 🧮 Vector Math Operations (f64)

### Binary Operations

```zig
// Element-wise addition: result[i] = a[i] + b[i]
simd_utils.SimdF64.add(result_slice, a_slice, b_slice);

// Element-wise subtraction: result[i] = a[i] - b[i]
simd_utils.SimdF64.sub(result_slice, a_slice, b_slice);

// Element-wise multiplication: result[i] = a[i] * b[i]
simd_utils.SimdF64.mul(result_slice, a_slice, b_slice);

// Element-wise division: result[i] = a[i] / b[i]
simd_utils.SimdF64.div(result_slice, a_slice, b_slice);
```

### Scalar Operations

```zig
// Scale: result[i] = a[i] * scalar
simd_utils.SimdF64.scale(result_slice, a_slice, 2.5);

// Add scalar: result[i] = a[i] + scalar
simd_utils.SimdF64.addScalar(result_slice, a_slice, 10.0);
```

### Statistical Operations

```zig
// Sum all elements
const total = simd_utils.SimdF64.sum(data_slice);

// Compute variance
const var_val = simd_utils.SimdF64.variance(data_slice, mean);
```

## 🎯 FloatVector Operations

### Binary Operations

```zig
// Use in FloatVector methods
pub fn add(a: Self, b: Self) Self {
    const min_count = @min(a.count, b.count);
    const result = FloatVector.init(min_count);
    fvec_simd.binaryOp(
        result.data[0..min_count],
        a.data[0..min_count],
        b.data[0..min_count],
        .add  // or .sub, .mul, .div
    );
    result.count = min_count;
    return result;
}
```

**Available Operations:**
- `.add` - Addition
- `.sub` - Subtraction
- `.mul` - Multiplication
- `.div` - Division

### Scalar Operations

```zig
pub fn scale(self: Self, scalar: f64) Self {
    const result = FloatVector.init(self.count);
    fvec_simd.scalarOp(
        result.data[0..self.count],
        self.data[0..self.count],
        scalar,
        .scale  // or .add, .sub, .div
    );
    result.count = self.count;
    return result;
}
```

**Available Operations:**
- `.scale` - Multiply by scalar
- `.add` - Add scalar
- `.sub` - Subtract scalar
- `.div` - Divide by scalar

### Unary Operations

```zig
pub fn sin_vec(self: Self) Self {
    const result = FloatVector.init(self.count);
    fvec_simd.unaryOp(
        result.data[0..self.count],
        self.data[0..self.count],
        .sin  // or .cos, .sqrt, .abs, .exp, .log
    );
    result.count = self.count;
    return result;
}
```

**Available Operations:**
- `.sin` - Sine
- `.cos` - Cosine
- `.sqrt` - Square root
- `.abs` - Absolute value
- `.exp` - Exponential
- `.log` - Natural logarithm

### Power Operation

```zig
pub fn pow_vec(self: Self, exponent: f64) Self {
    const result = FloatVector.init(self.count);
    fvec_simd.powOp(
        result.data[0..self.count],
        self.data[0..self.count],
        exponent
    );
    result.count = self.count;
    return result;
}
```

### Comparison Operations

```zig
pub fn greater_than(self: Self, other: Self) Self {
    const min_count = @min(self.count, other.count);
    const result = FloatVector.init(min_count);
    fvec_simd.compareOp(
        result.data[0..min_count],
        self.data[0..min_count],
        other.data[0..min_count],
        .greater_than
    );
    result.count = min_count;
    return result;
}
```

**Available Operations:**
- `.greater_than` - `a > b`
- `.less_than` - `a < b`
- `.greater_equal` - `a >= b`
- `.less_equal` - `a <= b`
- `.equal` - `a == b`
- `.not_equal` - `a != b`

### Statistical Operations

```zig
// Sum
pub fn sum(self: Self) f64 {
    return fvec_simd.sum(self.data[0..self.count]);
}

// Mean
pub fn mean(self: Self) f64 {
    if (self.count == 0) return 0.0;
    return fvec_simd.mean(self.data[0..self.count]);
}

// Variance
pub fn variance(self: Self) f64 {
    if (self.count == 0) return 0.0;
    const mean_val = self.mean();
    return fvec_simd.variance(self.data[0..self.count], mean_val);
}
```

## ⚙️ Configuration

### Runtime Configuration

```zig
// Force scalar operations (disable SIMD)
simd_utils.config.force_scalar = true;

// Adjust SIMD threshold (default: 32)
simd_utils.config.min_simd_size = 64;

// Check if SIMD is supported
if (simd_utils.isSupported()) {
    // SIMD available
}

// Get architecture name
const arch = simd_utils.getArchitectureName();
// "x86_64 AVX2", "ARM NEON", etc.

// Print detailed capabilities
simd_utils.printCapabilities();
```

### Compile-Time Configuration

```bash
# Enable AVX2
zig build -Dcpu=x86_64+avx2

# Enable AVX-512
zig build -Dcpu=x86_64+avx512f

# ARM with NEON
zig build -Dcpu=aarch64+neon

# Optimize for speed
zig build -O ReleaseFast
```

## 🧪 Testing

```bash
# Test SIMD utilities
zig test src/simd_utils.zig

# Test FloatVector helpers
zig test src/objects/fvec_simd.zig

# Run benchmark
zig build-exe src/simd_benchmark.zig -O ReleaseFast
./simd_benchmark
```

## 📈 Performance Tips

1. **Use SIMD for arrays ≥ 32 elements**
   - Smaller arrays: overhead may exceed benefits
   - Adjust `min_simd_size` if needed

2. **Prefer slice operations over element-by-element**
   ```zig
   // Good: Direct slice operation
   const vec: @Vector(4, f64) = data[0..4].*;
   
   // Bad: Manual element loading
   const vec = @Vector(4, f64){
       data[0], data[1], data[2], data[3]
   };
   ```

3. **Use aligned memory when possible**
   - SIMD operations work best with aligned addresses
   - Consider using `@alignOf(@Vector(vec_len, T))`

4. **Batch operations**
   - Process multiple operations together
   - Better cache utilization

5. **Profile first, optimize second**
   - Use the benchmark to identify hot paths
   - Not all operations benefit equally from SIMD

## 🐛 Debugging

### Disable SIMD temporarily

```zig
// At the start of your program
simd_utils.config.force_scalar = true;
```

### Check capabilities

```zig
const caps = simd_utils.getCapabilities();
std.debug.print("SIMD available: {}\n", .{caps.available});
std.debug.print("Vector length (f64): {}\n", .{caps.f64_vector_len});
```

### Compare with scalar implementation

```zig
// Save original setting
const original = simd_utils.config.force_scalar;
defer simd_utils.config.force_scalar = original;

// Test with SIMD
simd_utils.config.force_scalar = false;
const simd_result = myOperation();

// Test without SIMD
simd_utils.config.force_scalar = true;
const scalar_result = myOperation();

// Compare results
try testing.expectEqual(scalar_result, simd_result);
```

## 📋 Migration Checklist

When refactoring existing SIMD code:

- [ ] Import `simd_utils` and `fvec_simd`
- [ ] Replace hardcoded `Vec4` with dynamic sizing
- [ ] Use slice operations instead of manual element access
- [ ] Replace repetitive SIMD code with helper functions
- [ ] Add tests to verify correctness
- [ ] Run benchmarks to verify performance
- [ ] Update documentation

## 🔗 Related Documentation

- **Detailed Guide**: `SIMD_OPTIMIZATION_GUIDE.md`
- **Architecture**: `SIMD_REFACTORING_SUMMARY.md`
- **Examples**: `src/objects/fvec_refactored_example.zig`
- **Benchmarks**: `src/simd_benchmark.zig`

## 💡 Common Patterns

### Pattern 1: Simple Binary Operation

```zig
pub fn myBinaryOp(a: []const f64, b: []const f64) []f64 {
    const result = allocator.alloc(f64, a.len) catch unreachable;
    simd_utils.SimdF64.add(result, a, b);
    return result;
}
```

### Pattern 2: Reduction Operation

```zig
pub fn myReduction(data: []const f64) f64 {
    return simd_utils.SimdF64.sum(data);
}
```

### Pattern 3: Transform Operation

```zig
pub fn myTransform(data: []f64) void {
    simd_utils.SimdF64.scale(data, data, 2.0);
}
```

### Pattern 4: Conditional Optimization

```zig
pub fn myOperation(data: []f64) void {
    if (simd_utils.shouldUseSIMD(data.len)) {
        // Use SIMD path
        simd_utils.SimdF64.scale(data, data, 2.0);
    } else {
        // Use scalar path for small arrays
        for (data) |*val| {
            val.* *= 2.0;
        }
    }
}
```

---

**Quick Tip**: Start with `simd_utils.printCapabilities()` to see what your CPU supports!