# Import Feature Test Suite

This directory contains test files for the import statement feature in MufiZ.

## Test Files

### Basic Import Tests
- **test_import_simple.mufi** - Tests the exact use case from the problem statement
- **foo.mufiz** - Simple module with an add function

### Comprehensive Tests
- **test_import.mufi** - Tests multiple functions and constants from a module
- **test_module.mufiz** - Module with multiple functions (add, multiply, greet) and constants

### Advanced Tests
- **test_import_advanced.mufi** - Tests recursive functions, multiple parameters, and module caching
- **advanced_module.mufiz** - Module with recursive functions (fibonacci, factorial, power) and constants

### Edge Cases
- **test_import_edge_cases.mufi** - Tests error handling and edge cases
- **empty_module.mufiz** - Empty module for testing
- **constants_module.mufiz** - Module with only constants (no functions)

## Running Tests

To run a test file:
```bash
mufiz -r test_suite/test_import_simple.mufi
```

## Expected Behavior

### test_import_simple.mufi
Expected output:
```
5
```

### test_import.mufi
Expected output:
```
foo.add(2, 3) = 
5
foo.multiply(4, 5) = 
20
Hello, World!
PI from module: 
3.14159
VERSION from module: 
1.0.0
```

### test_import_advanced.mufi
Expected output:
```
Fibonacci(10):
55
Factorial(5):
120
Power(2, 8):
256
E constant:
2.71828
Golden Ratio:
1.61803
Dr. Smith, welcome!
Testing cached import:
720
```

## Notes

- All module files use `.mufiz` extension
- Test files use `.mufi` extension
- Modules are cached after first import
- Imported modules act like objects with properties (functions and constants)
