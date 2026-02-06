# Import System Tests

This directory contains tests for the Python-style import system with lazy-loading.

## Test Files

### Module Imports
- **test_module_imports.mufi**: Tests basic module imports (`import math;`)
- **test_from_imports.mufi**: Tests selective function imports (`from math import sqrt, abs;`)
- **test_lazy_loading.mufi**: Tests that modules are only loaded when imported
- **test_comprehensive.mufi**: Comprehensive test covering all import features

### File Imports
- **test_file_imports.mufi**: Tests file imports (`import "path/to/file.mufi";`)
- **math_helper.mufi**: Helper module with math functions
- **helper.mufi**: Simple helper module for testing

## Import Syntax

### Module Import
```python
import math;
var x = sin(3.14);
```

### Selective Import
```python
from math import sin, cos, sqrt;
var x = sin(3.14);
```

### File Import
```python
import "path/to/module.mufi";
```

## Available Modules

- **math**: Mathematical functions (sin, cos, tan, sqrt, abs, etc.)
- **collections**: Data structures (linked_list, hash_table, fvec, etc.)
- **time**: Time functions (now, now_ms, now_ns)
- **fs**: File system operations (create_file, read_file, write_file, etc.)
- **utils**: Utility functions (assert, exit, sleep, panic, format)
- **network**: Network operations (http_get, http_post, etc.)
- **matrix**: Matrix operations (eye, ones, zeros, transpose, det, inv, etc.)

## Running Tests

To run a specific test:
```bash
./mufiz --run test_suite/imports/test_module_imports.mufi
```

To run all tests:
```bash
for f in test_suite/imports/test_*.mufi; do
    echo "Running $f..."
    ./mufiz --run "$f"
done
```
