# MufiZ Matrix Test Suite

This directory contains comprehensive tests for the matrix implementation in MufiZ, covering all matrix operations and Octave-compatible functionality.

## Test Files Overview

### Core Test Files

- **`test_matrix_creation.mufi`** - Tests matrix creation functions (eye, ones, zeros, rand, randn)
- **`test_matrix_arithmetic.mufi`** - Tests arithmetic operations (+, -, *, scalar operations)
- **`test_matrix_properties.mufi`** - Tests matrix properties (det, trace, norm, transpose, inv)
- **`test_matrix_advanced.mufi`** - Tests advanced operations (LU decomposition, concatenation, complex expressions)
- **`test_matrix_errors.mufi`** - Tests error handling and edge cases
- **`test_matrix_integration.mufi`** - Tests integration with other MufiZ features

### Test Runner

- **`run_all_matrix_tests.mufi`** - Master test runner that executes all test suites

## Running Tests

### Individual Test Files
```bash
# Run specific test suite
./zig-out/bin/mufiz -r test_suite/matrix/test_matrix_creation.mufi
./zig-out/bin/mufiz -r test_suite/matrix/test_matrix_arithmetic.mufi
./zig-out/bin/mufiz -r test_suite/matrix/test_matrix_properties.mufi
```

### All Tests
```bash
# Run complete matrix test suite
./zig-out/bin/mufiz -r test_suite/matrix/run_all_matrix_tests.mufi
```

## Test Coverage

### Matrix Creation Functions
- ✅ `eye(n)` - Identity matrices
- ✅ `ones(m,n)` - Matrices of ones
- ✅ `zeros(m,n)` - Matrices of zeros
- ✅ `rand(m,n)` - Random uniform matrices
- ✅ `randn(m,n)` - Random normal matrices

### Arithmetic Operations
- ✅ Matrix addition (`A + B`)
- ✅ Matrix subtraction (`A - B`)
- ✅ Matrix multiplication (`A * B`)
- ✅ Scalar multiplication (`k * A`)
- ✅ Mixed arithmetic expressions

### Matrix Properties
- ✅ `det(A)` - Determinant calculation
- ✅ `trace(A)` - Trace (sum of diagonal elements)
- ✅ `norm(A)` - Frobenius norm
- ✅ `transpose(A)` - Matrix transpose
- ✅ `inv(A)` - Matrix inverse
- ✅ `size(A)` - Matrix dimensions

### Advanced Operations
- ✅ `horzcat(A,B)` - Horizontal concatenation
- ✅ `vertcat(A,B)` - Vertical concatenation
- ✅ `reshape(A,m,n)` - Matrix reshaping
- ✅ LU decomposition (internal)
- ✅ Complex matrix expressions

### Error Handling
- ✅ Dimension mismatch detection
- ✅ Singular matrix handling
- ✅ Numerical precision edge cases
- ✅ Large number handling
- ✅ Memory management

### Integration Testing
- ✅ Matrix variables and assignment
- ✅ Matrix operations in functions
- ✅ Matrix operations in conditionals
- ✅ Matrix operations in loops
- ✅ Integration with other MufiZ features

## Test Structure

All tests follow a consistent pattern using the `assert` function:

```mufi
fun test_example() {
    print "\n[Test N] Description";
    
    var A = eye(2);
    var B = ones(2, 2);
    var result = A + B;
    
    assert(trace(result), 4.0);  // Expected: 4.0
    assert(det(result) > 0.0, true);  // Boolean assertion
    
    print "✓ Test description passed";
}
```

## Octave Compatibility

The tests verify that MufiZ matrix operations produce results compatible with Octave:

- **Storage Format**: Column-major order (Fortran-style)
- **Function Names**: Identical to Octave (`eye`, `ones`, `zeros`, etc.)
- **Algorithms**: LU decomposition for determinant and inverse
- **Mathematical Properties**: All standard linear algebra identities
- **Error Handling**: Similar behavior for edge cases

## Test Results Verification

### Expected Behavior
- All assertions should pass without errors
- Matrix operations should complete without crashes
- Results should match mathematical expectations
- Memory management should work correctly

### Performance Characteristics
- Matrix creation: O(mn) for m×n matrices
- Addition/Subtraction: O(mn)  
- Multiplication: O(mnp) for (m×n) × (n×p)
- Determinant/Inverse: O(n³) using LU decomposition

## Adding New Tests

To add new matrix tests:

1. Create test functions following the naming pattern `test_description()`
2. Use descriptive assertions with expected values
3. Include both positive and negative test cases
4. Test edge cases and error conditions
5. Add the new test to the appropriate test file
6. Update this README if adding new test categories

## Dependencies

The matrix tests require:
- MufiZ with matrix module enabled (`stdlib.addMatrix()`)
- All matrix functions registered in stdlib
- Assert function available in the runtime

## Known Limitations

- Trace function returns 0 for non-square matrices (Octave compatibility)
- Random number generation is seeded by timestamp (not deterministic)
- Floating-point precision may cause minor variations in results
- Very large matrices may hit memory limits

## Troubleshooting

### Common Issues
1. **Assertion failures**: Check expected values match actual matrix behavior
2. **Memory errors**: Ensure proper matrix cleanup in long-running tests  
3. **Precision errors**: Use tolerance-based assertions for floating-point comparisons

### Debug Tips
- Use `print matrix_variable;` to inspect matrix contents
- Check `det()`, `trace()`, and `norm()` values for debugging
- Verify matrix dimensions with `size()` function