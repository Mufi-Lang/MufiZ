# SIMD Optimizations in MufiZ

## Overview

MufiZ's FloatVector implementation uses SIMD (Single Instruction, Multiple Data) optimizations to accelerate vector operations. These optimizations leverage Zig's `@Vector` type to process multiple elements simultaneously on modern CPUs.

## Architecture

### Vector Processing
- **SIMD Width**: 4 elements (f64)
- **Vector Type**: `@Vector(4, f64)`
- **Target**: x86_64 SSE2/AVX compatible CPUs

### Pattern
All SIMD-optimized operations follow this pattern:

```zig
pub fn operation(self: Self) f64 {
    const len = self.count;
    const Vec4 = @Vector(4, f64);
    
    // Initialize accumulator/result vector
    var result_vec: Vec4 = @splat(initial_value);
    
    // Process elements in chunks of 4
    const vec_iterations = @divTrunc(len, 4);
    var i: usize = 0;
    while (i < vec_iterations) : (i += 1) {
        const offset = i * 4;
        
        // Load 4 elements into a vector
        const data_vec = Vec4{
            self.data[offset],
            self.data[offset + 1],
            self.data[offset + 2],
            self.data[offset + 3],
        };
        
        // Perform vector operation
        result_vec = vector_operation(result_vec, data_vec);
    }
    
    // Reduce vector to scalar
    var result = @reduce(.Operation, result_vec);
    
    // Handle remaining elements (len % 4)
    const remaining = @mod(len, 4);
    if (remaining > 0) {
        const start = len - remaining;
        for (start..len) |j| {
            result = scalar_operation(result, self.data[j]);
        }
    }
    
    return result;
}
```

## SIMD-Optimized Operations

### Vector Arithmetic
- **add**: Element-wise addition of two vectors
- **sub**: Element-wise subtraction of two vectors
- **mul**: Element-wise multiplication of two vectors
- **div**: Element-wise division of two vectors

### Scalar Operations
- **scale**: Multiply all elements by a scalar
- **single_add**: Add a scalar to all elements
- **single_sub**: Subtract a scalar from all elements
- **single_div**: Divide all elements by a scalar

### Statistical Operations
- **sum**: Sum of all elements using SIMD accumulation
- **mean**: Average using SIMD sum
- **variance**: Variance using SIMD for squared differences
- **std_dev**: Standard deviation (uses SIMD variance)

### Reduction Operations
- **dot**: Dot product using SIMD multiply-accumulate
- **max**: Maximum element using SIMD max reduction
- **min**: Minimum element using SIMD min reduction

### Derived Operations (Auto-SIMD)
These operations automatically benefit from SIMD optimizations by using the above primitives:

- **magnitude**: Uses SIMD dot product
- **normalize**: Uses SIMD magnitude and single_div
- **projection**: Uses SIMD dot and scale
- **rejection**: Uses SIMD projection and sub
- **reflection**: Uses SIMD dot, scale, and sub
- **refraction**: Uses SIMD dot, scale, and sub
- **angle**: Uses SIMD dot and magnitude

## Performance Benefits

### Expected Speedup
For vectors with 16+ elements:
- **Theoretical**: 4x speedup on operations that vectorize well
- **Practical**: 2-3x speedup accounting for overhead and memory bandwidth

### Best Performance
Operations achieve best performance when:
- Vector length is a multiple of 4
- Data is aligned in memory
- Vectors are large enough to amortize setup costs (>= 16 elements)

### Operations Not SIMD-Optimized
Some operations don't use SIMD because:
- **cross**: Only works on 3-element vectors (too small for SIMD benefit)
- **equal**: Short-circuits on first difference (SIMD would prevent early exit)
- **search**: Binary search has different access pattern
- **sort**: QuickSort has complex branching

## Example Performance

For a vector with 1000 elements:

```mufi
var v1 = linspace(0.0, 1000.0, 1000);
var v2 = linspace(0.0, 1000.0, 1000);

// SIMD-accelerated operations
var sum = dot(v1, v2);        // ~250 SIMD iterations
var maximum = max(v1);         // ~250 SIMD iterations
var minimum = min(v2);         // ~250 SIMD iterations
var result = addfv(v1, v2);   // ~250 SIMD iterations
```

Each SIMD iteration processes 4 elements, so operations on 1000 elements require only ~250 iterations plus handling of remaining elements.

## Compiler Optimization

Zig's LLVM backend will further optimize these operations:
- Use CPU-specific SIMD instructions (SSE2, AVX, AVX2, AVX-512)
- Optimize register allocation
- Unroll loops when beneficial
- Vectorize remaining scalar loops when possible

## Testing

The `tests/simd_test.mufi` file provides validation tests for SIMD operations.

## Future Improvements

Potential enhancements:
1. **Wider SIMD**: Use @Vector(8, f64) for AVX-512 when available
2. **Adaptive Width**: Choose vector width based on CPU capabilities
3. **More Operations**: Add SIMD to other suitable operations
4. **Aligned Allocations**: Ensure data alignment for better performance
