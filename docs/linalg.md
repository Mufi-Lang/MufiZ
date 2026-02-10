# Linear Algebra Module

The MufiZ standard library provides basic linear algebra capabilities for matrix operations.

## Functions

### `lu(A)`
Calculates the LU decomposition of a square matrix `A` with partial pivoting.

- **Input:** Square `Matrix` A
- **Returns:** A hash table containing:
    - `"L"`: Lower triangular matrix with unit diagonal.
    - `"U"`: Upper triangular matrix.
    - `"P"`: Permutation matrix such that `P * A = L * U`.

**Example:**
```mufi
var A = [[1, 2], [3, 4]];
var res = lu(A);
var L = res["L"];
var U = res["U"];
var P = res["P"];
```

### `solve(A, b)`
Solves a linear system of equations `Ax = b` using LU decomposition.

- **Input:** 
    - `A`: Square coefficient `Matrix`.
    - `b`: Right-hand side `Matrix` (column vector or matrix).
- **Returns:** Solution `Matrix` x such that `Ax = b`.

**Example:**
```mufi
var A = [[1, 2], [3, 4]];
var b = [5; 11];
var x = solve(A, b); // [1; 2]
```

### `inv(A)`
Calculates the inverse of a square matrix `A`.

- **Input:** Square `Matrix` A.
- **Returns:** Inverse `Matrix` of A.

**Example:**
```mufi
var A = [[1, 2], [3, 4]];
var Ai = inv(A);
```

### `det(A)`
Calculates the determinant of a square matrix `A`.

- **Input:** Square `Matrix` A.
- **Returns:** Number (determinant).

**Example:**
```mufi
var A = [[1, 2], [3, 4]];
var d = det(A); // -2.0
```

## Error Handling
Linear algebra functions will return a runtime error if:
- Matrices are not square (for functions requiring square matrices).
- The matrix is singular (for `lu`, `solve`, and `inv`).
- Dimensions are incompatible (e.g., `rows(A) != rows(b)` for `solve`).
