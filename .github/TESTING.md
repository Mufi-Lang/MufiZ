# Testing with test_suite.py on Next Branch

This document explains how the existing `test_suite.py` is integrated with GitHub Actions for the `next` branch.

## Overview

The MufiZ project uses `test_suite.py` as the primary testing framework. This Python script automatically builds MufiZ (if needed) and runs all test files in the `test_suite/` directory.

## GitHub Workflows

### 1. `test_suite_next.yml` - Single Platform Testing
- **Trigger**: Push/PR to `next` branch
- **Platform**: Ubuntu Latest
- **Runtime**: ~5-10 minutes
- **Purpose**: Fast feedback using your existing test suite

### 2. `test_suite_multiplatform.yml` - Cross-Platform Testing  
- **Trigger**: Push/PR to `next` branch
- **Platforms**: Ubuntu, macOS, Windows
- **Runtime**: ~15-20 minutes
- **Purpose**: Ensure cross-platform compatibility

## What the Workflows Do

1. **Checkout** your code from the `next` branch
2. **Setup Zig** version 0.15.2 
3. **Setup Python** 3.x
4. **Cache** Zig build artifacts for faster subsequent runs
5. **Run** your `test_suite.py` script
6. **Upload artifacts** on failure for debugging
7. **Generate summary** with results

## Your test_suite.py Features (Preserved)

✅ **Automatic Building**: Builds MufiZ if `./zig-out/bin/mufiz` doesn't exist  
✅ **Comprehensive Testing**: Tests all `.mufi` files in `test_suite/` directory  
✅ **Expected Failures**: Handles tests that should fail (const reassignment)  
✅ **Timeout Protection**: 30-second timeout per test  
✅ **Colored Output**: Success/failure indicators with ANSI colors  
✅ **Detailed Logging**: Timestamps and error information  
✅ **Memory Safety**: Detects segfaults and assertion failures  
✅ **Basic Functionality Check**: Tests interpreter before running full suite  

## Running Locally

Your existing workflow remains unchanged:

```bash
# Run the full test suite (will build if needed)
python3 test_suite.py

# Or build first, then test
zig build -Doptimize=ReleaseSafe -Dstress_gc=false
python3 test_suite.py
```

## Test Structure

Your test suite covers:

```
test_suite/
├── *.mufi                    # Individual test files
├── class/                    # Object-oriented tests  
├── function/                 # Function tests
├── hash_table/               # Hash table tests
├── if/                       # Conditional tests
├── loops/                    # Loop tests
├── math/                     # Math operation tests
├── string/                   # String tests
└── ... (other categories)
```

## Expected Failures

Your script correctly handles these expected failure cases:
- `test_suite/test_const.mufi` - Tests const reassignment errors
- `test_suite/test_const_vs_var.mufi` - Tests const vs var behavior

## Viewing Results

### In GitHub Actions:
1. Go to **Actions** tab in your repository
2. Click on the workflow run
3. View the **Run test_suite.py** step for detailed output
4. Check **Test Results Summary** for overview

### On Failure:
- Download **test-suite-failure-artifacts** for debugging
- Review the colored output in the workflow logs
- Your script provides helpful debugging information

## Adding New Tests

Simply add `.mufi` files to the `test_suite/` directory or subdirectories. Your script will automatically discover and run them.

For tests that should fail, add them to the `expected_failures` list in `test_suite.py`.

## Debugging Failed Tests

When tests fail in CI:

1. **Check the workflow output** - Your script provides detailed error info
2. **Download artifacts** - Contains test files and build output  
3. **Run locally** - Use the same `python3 test_suite.py` command
4. **Individual test** - Run specific failing tests: `./zig-out/bin/mufiz -r test_suite/failing_test.mufi`

## Build Configuration

Your script uses this build command:
```bash
zig build -Doptimize=ReleaseSafe -Dstress_gc=false
```

The workflows use the same configuration to ensure consistency.

## Benefits of CI Integration

- ✅ **Automatic testing** on every push to `next` branch
- ✅ **Cross-platform validation** (Linux, macOS, Windows)  
- ✅ **No changes required** to your existing test suite
- ✅ **Artifact preservation** for debugging failures
- ✅ **Caching** for faster build times
- ✅ **Detailed reporting** in GitHub interface

Your `test_suite.py` script continues to work exactly as before, but now runs automatically in CI/CD!