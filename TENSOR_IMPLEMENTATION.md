# Tensor Type Implementation

This document describes the implementation of the new `Tensor` type in MufiZ, which replaces both `FVec` and `Matrix` types as specified in the issue.

## Overview

The `Tensor` type is a unified multi-dimensional array implementation that can handle:
- **1D tensors (vectors)** - replacing FloatVector functionality
- **2D tensors (matrices)** - replacing Matrix functionality 
- **3D tensors** - extending functionality for higher-dimensional data

## Core Structure

The Tensor struct follows the specification from the issue:

```zig
pub const Tensor = struct {
    obj: Obj,        // Required for object system integration
    order: u8,       // Tensor order (1D, 2D, 3D)
    dim1: usize,     // First dimension (always present)
    dim2: usize,     // Second dimension (0 if not used) 
    dim3: usize,     // Third dimension (0 if not used)
    ptr: [*]f64,     // Data pointer to f64 array
};
```

## Usage Examples

### Creating Tensors

```mufi
// 1D tensor (vector) with 5 elements
var vec = tensor1d(5);

// 2D tensor (matrix) with 3 rows, 4 columns  
var mat = tensor2d(3, 4);

// 3D tensor with dimensions 2×2×2
var cube = tensor3d(2, 2, 2);

// Matrix alias (same as tensor2d)
var matrix = matrix(3, 3);
```

### Basic Operations

```mufi
// Fill tensor with constant value
tensor_fill(vec, 2.5);

// Set individual elements
tensor_set(vec, 0, 1.0);           // 1D: set element at index 0
tensor_set(mat, 1, 2, 3.5);        // 2D: set element at row 1, col 2
tensor_set(cube, 0, 1, 1, 7.2);    // 3D: set element at position (0,1,1)

// Get individual elements  
var val = tensor_get(vec, 0);      // 1D: get element at index 0
var val2 = tensor_get(mat, 1, 2);  // 2D: get element at row 1, col 2
```

### Mathematical Operations

```mufi
// Element-wise addition
var result = tensor_add(tensor_a, tensor_b);

// Scalar multiplication
var scaled = tensor_scale(tensor_a, 2.0);

// Dot product (1D tensors)
var dot_result = tensor_dot(vec_a, vec_b);

// Matrix multiplication (2D tensors)
var matmul_result = tensor_matmul(mat_a, mat_b);

// Matrix transpose (2D tensors)
var transposed = tensor_transpose(mat);
```

## Integration with Existing Code

### Object System Integration
- Added `OBJ_TENSOR` to the `ObjType` enum
- Integrated with garbage collection system
- Added printing support via `printObject`
- Memory management through `freeObject`

### Native Function Registration
All tensor functions are automatically registered during VM initialization:
- `tensor1d(size)` - Create 1D tensor
- `tensor2d(rows, cols)` - Create 2D tensor  
- `tensor3d(d1, d2, d3)` - Create 3D tensor
- `matrix(rows, cols)` - Alias for `tensor2d`
- `tensor_get(tensor, indices...)` - Get element
- `tensor_set(tensor, indices..., value)` - Set element
- `tensor_fill(tensor, value)` - Fill with constant
- `tensor_add(a, b)` - Element-wise addition
- `tensor_scale(tensor, scalar)` - Scalar multiplication
- `tensor_dot(a, b)` - Dot product
- `tensor_matmul(a, b)` - Matrix multiplication
- `tensor_transpose(tensor)` - Matrix transpose

## Migration Path

### From FloatVector to Tensor
```mufi
// Old FloatVector approach
var fvec = fvec(10);
push(fvec, 1.5);

// New Tensor approach  
var vec = tensor1d(10);
tensor_set(vec, 0, 1.5);
```

### From Matrix to Tensor
```mufi
// Old Matrix approach (was commented out)
// var mat = matrix(3, 4);

// New Tensor approach
var mat = tensor2d(3, 4);  // or matrix(3, 4)
tensor_set(mat, 0, 0, 1.0);
```

## Technical Implementation Details

### Memory Layout
- Data is stored in row-major order for 2D and 3D tensors
- Memory is allocated using the existing `reallocate` function
- All data is initialized to 0.0 by default

### Error Handling
- Bounds checking for all access operations
- Dimension compatibility checking for operations
- Graceful error handling with appropriate runtime errors

### Performance Considerations
- Direct memory access using raw pointers
- Efficient indexing calculations for multi-dimensional access
- Compatible with existing SIMD optimizations (can be added later)

## Testing

A comprehensive test file `tests/tensor_test.mufi` demonstrates:
- Creating tensors of different dimensions
- Basic element access and modification
- Mathematical operations
- Matrix operations
- Error cases

## Benefits

1. **Unified Interface**: Single type handles vectors, matrices, and higher-dimensional arrays
2. **Memory Efficient**: Optimized memory layout and allocation
3. **Type Safety**: Compile-time and runtime dimension checking
4. **Extensible**: Easy to add new operations and dimensions
5. **Backward Compatible**: Matrix alias maintains familiar interface
6. **Performance**: Efficient indexing and memory access patterns

## Future Enhancements

The Tensor implementation provides a solid foundation for:
- SIMD optimizations for mathematical operations
- Additional linear algebra operations
- Broadcasting for element-wise operations
- Integration with external mathematical libraries
- Specialized tensor operations (convolution, etc.)