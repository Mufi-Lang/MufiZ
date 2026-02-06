# Import System Test Suite

This directory contains test files for the new Python-style import system in MufiZ.

## Test Files

### Module Import Tests

- **`import_module_test.mufi`**: Tests basic module import syntax
  ```mufi
  import math;
  var x = sin(3.14159);
  ```

- **`import_from_test.mufi`**: Tests selective function import
  ```mufi
  from math import sin, cos, sqrt;
  var x = sin(3.14159);
  ```

### File Import Tests

- **`helper_module.mufi`**: Helper module with utility functions
- **`import_file_test.mufi`**: Tests importing and using functions from another MufiZ file

### Multiple Modules

- **`import_multiple_modules.mufi`**: Tests importing and using multiple modules in the same script

### Lazy Loading

- **`import_lazy_loading.mufi`**: Demonstrates lazy loading behavior (modules only loaded when imported)

## Running Tests

### Run all tests
```bash
python3 test_suite.py
```

### Run individual test
```bash
zig build run -- -r test_suite/import_module_test.mufi
```

### Run with debugging
```bash
zig build -Dprint_code=true run -- -r test_suite/import_module_test.mufi
```

## Expected Behavior

All import tests should:
1. Successfully parse the import statements
2. Load the required modules at runtime
3. Execute functions from the imported modules
4. Produce the expected output

## Troubleshooting

If tests fail:
1. Check that you're using Zig 0.15.2
2. Clean build artifacts: `rm -rf zig-cache .zig-cache`
3. Rebuild: `zig build`
4. Run tests again

## Adding New Tests

When adding new import-related tests:
1. Place test files in this directory
2. Name them descriptively (e.g., `import_feature_name.mufi`)
3. Add documentation here
4. Verify they work with `test_suite.py`
