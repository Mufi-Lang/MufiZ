# Matrix Operations in MufiZ

MufiZ now supports 2D matrix operations by extending the FloatVector type. This document describes the matrix functionality and API.

## Overview

FloatVector has been extended to support 2D matrices while maintaining full backward compatibility with 1D vectors. Matrices are treated as n x m arrays with all operations accelerated using SIMD instructions where possible.

### Design Philosophy

- **No separate ObjMatrix type**: Matrices are implemented as an extension of FloatVector
- **1D vectors are n x 1 matrices**: Regular vectors work as column vectors in matrix context
- **SIMD acceleration**: All operations use SIMD where beneficial for performance
- **Backward compatible**: Existing vector code continues to work unchanged

## Creating Matrices

### matrix(rows, cols)
Creates a new matrix initialized with zeros.
```mufi
var m = matrix(3, 4);  // Creates a 3x4 matrix
```

### identity(size)
Creates an identity matrix (square matrix with 1s on diagonal).
```mufi
var id = identity(3);  // Creates a 3x3 identity matrix
```

### zeros(rows, cols)
Creates a matrix filled with zeros (same as matrix()).
```mufi
var z = zeros(2, 3);  // Creates a 2x3 matrix of zeros
```

### ones(rows, cols)
Creates a matrix filled with ones.
```mufi
var o = ones(2, 3);  // Creates a 2x3 matrix of ones
```

## Accessing Matrix Elements

### mat_at(matrix, row, col)
Gets the element at position (row, col).
```mufi
var val = mat_at(m, 1, 2);  // Gets element at row 1, column 2
```

### mat_set(matrix, row, col, value)
Sets the element at position (row, col).
```mufi
mat_set(m, 1, 2, 42.0);  // Sets element at row 1, column 2 to 42.0
```

### get_row(matrix, row)
Extracts a row as a new vector.
```mufi
var row = get_row(m, 0);  // Gets the first row
```

### get_col(matrix, col)
Extracts a column as a new vector.
```mufi
var col = get_col(m, 1);  // Gets the second column
```

## Matrix Operations

### transpose(matrix)
Returns the transpose of the matrix.
```mufi
var m_t = transpose(m);  // Transposes matrix m
```

### reshape(matrix, rows, cols)
Reshapes a matrix/vector to new dimensions (total elements must match).
```mufi
var v = fvec(6);
push(v, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0);
var m = reshape(v, 2, 3);  // Reshapes 6-element vector to 2x3 matrix
```

### matmul(a, b)
Matrix multiplication (a * b). Dimensions must be compatible.
```mufi
var a = matrix(2, 3);  // 2x3 matrix
var b = matrix(3, 4);  // 3x4 matrix
var c = matmul(a, b);  // Result is 2x4 matrix
```

## SIMD Acceleration

All matrix operations are implemented with SIMD acceleration where beneficial:

- **Matrix multiplication**: Inner loop uses SIMD for 4-element chunks
- **Element-wise operations**: Addition, subtraction, multiplication use SIMD
- **Scalar operations**: Matrix scaling uses SIMD
- **Transpose**: Optimized memory access patterns

The SIMD implementation processes 4 elements at a time (Vec4 = @Vector(4, f64)) with fallback for remaining elements.

## Backward Compatibility

Regular 1D vector operations continue to work exactly as before:

```mufi
var v = fvec(5);
push(v, 1.0, 2.0, 3.0, 4.0, 5.0);
var sum_v = sum(v);     // Works as before
var mean_v = mean(v);   // Works as before
```

Internally, 1D vectors are tracked with:
- `cols = 1` (column vector)
- `rows = count` (updated when elements are added)

## Examples

### Matrix Multiplication
```mufi
var a = matrix(2, 3);
mat_set(a, 0, 0, 1.0); mat_set(a, 0, 1, 2.0); mat_set(a, 0, 2, 3.0);
mat_set(a, 1, 0, 4.0); mat_set(a, 1, 1, 5.0); mat_set(a, 1, 2, 6.0);

var b = matrix(3, 2);
mat_set(b, 0, 0, 7.0); mat_set(b, 0, 1, 8.0);
mat_set(b, 1, 0, 9.0); mat_set(b, 1, 1, 10.0);
mat_set(b, 2, 0, 11.0); mat_set(b, 2, 1, 12.0);

var c = matmul(a, b);  // Result: [[58, 64], [139, 154]]
```

### Identity Matrix
```mufi
var id = identity(3);
print id;
// Output:
// [
//   [1.00, 0.00, 0.00],
//   [0.00, 1.00, 0.00],
//   [0.00, 0.00, 1.00]
// ]
```

### Transpose
```mufi
var m = matrix(2, 3);
// ... set values ...
var m_t = transpose(m);  // 3x2 matrix
```

## Performance Considerations

1. **Matrix multiplication** has O(n³) complexity but is SIMD-accelerated
2. **Transpose** requires O(rows × cols) operations with cache-friendly patterns
3. **Element-wise operations** are highly optimized with SIMD
4. Use **reshape** instead of creating new matrices when possible

## Implementation Details

### Memory Layout
Matrices use row-major order in memory:
- Element at (i, j) is stored at index `i * cols + j`
- This enables efficient row access and SIMD operations

### Type Information
- FloatVector struct has `rows` and `cols` fields
- `isMatrix()` returns true if rows > 0 and cols > 0
- `isVector()` returns true if cols == 1 or rows == 0
- All existing vector operations maintain compatibility

### SIMD Implementation
Uses Zig's `@Vector(4, f64)` for 4-wide f64 SIMD operations:
- Processes 4 elements per iteration in inner loops
- Handles remaining elements with scalar operations
- Automatically uses available SIMD instructions on the target platform
