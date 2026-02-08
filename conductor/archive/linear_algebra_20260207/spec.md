# Specification - LU Decomposition and Matrix Inversion

## Overview
This track aims to enhance the MufiZ standard library's linear algebra capabilities. While some basic matrix operations exist, we need to robustly expose LU decomposition (including permutation) and provide a high-level solver for linear systems.

## Requirements

### 1. LU Decomposition
- **Function:** `lu(A)`
- **Input:** A square matrix `A`.
- **Output:** A tuple or object containing:
    - `L`: Lower triangular matrix with unit diagonal.
    - `U`: Upper triangular matrix.
    - `P`: Permutation matrix or vector such that `P * A = L * U`.
- **Implementation:** Enhance the existing `luDecomposition` in `src/objects/matrix.zig` to handle and return permutations.

### 2. Linear System Solver
- **Function:** `solve(A, b)`
- **Input:** 
    - `A`: A square coefficient matrix.
    - `b`: A column vector (or matrix) representing the right-hand side.
- **Output:** A vector (or matrix) `x` such that `A * x = b`.
- **Algorithm:** Use the LU decomposition of `A` followed by forward and backward substitution.

### 3. Matrix Inversion Refinement
- Ensure the existing `inv(A)` implementation is robust and uses the improved LU decomposition.
- Add better error handling for singular matrices.

## User Experience
Users should be able to perform these operations easily from Mufi-Lang:
```mufi
var A = [[1, 2], [3, 4]];
var b = [5; 11];

// Solve Ax = b
var x = solve(A, b);

// Explicit LU
var [L, U, P] = lu(A);
```
*(Note: Current tuple/destructuring support in MufiZ might vary, will check and adapt syntax accordingly.)*
