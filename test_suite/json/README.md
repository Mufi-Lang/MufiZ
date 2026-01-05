# JSON Test Suite for MufiZ

This directory contains comprehensive tests for JSON functionality in the MufiZ programming language.

## Directory Structure

```
json/
├── README.md                 # This file
├── json_basic_test.mufi      # Basic JSON functionality tests
├── json_simple_test.mufi     # Simplified JSON tests (passes test suite)
├── working/                  # Tests that work correctly
│   ├── json_basic_test.mufi  # Copy of basic tests
│   └── json_simple_test.mufi # Copy of simple tests
└── problematic/              # Tests with known issues
    ├── json_advanced_test.mufi     # Advanced tests (memory issues)
    ├── json_edge_cases_test.mufi   # Edge cases (variable scope issues)
    └── json_integration_test.mufi  # Integration tests (syntax issues)
```

## Test Coverage

### Working Tests ✅

#### `json_basic_test.mufi`
- **Status**: ✅ Passes when run manually
- **Coverage**: 
  - JSON validation (`json_is_valid`)
  - Primitive parsing (numbers, strings, booleans, null)
  - Array parsing
  - Object parsing
  - Primitive stringification
  - Collection stringification
  - Round-trip conversion
  - JSON get/set operations
  - Edge cases and error handling

#### `json_simple_test.mufi`
- **Status**: ✅ Passes in test suite
- **Coverage**:
  - Basic JSON validation
  - Simple parsing operations
  - Basic stringification
  - JSON object operations
  - Round-trip testing

### Problematic Tests ⚠️

#### `json_advanced_test.mufi`
- **Status**: ❌ Memory panic (Invalid free)
- **Issue**: Memory management issues with string concatenation in loops
- **Coverage**: Large objects, deeply nested structures, arrays of objects

#### `json_edge_cases_test.mufi`
- **Status**: ❌ Variable scope errors
- **Issue**: Variable `i` redeclaration in same function scope
- **Coverage**: Boundary conditions, extreme cases, malformed JSON

#### `json_integration_test.mufi`
- **Status**: ❌ Syntax errors
- **Issue**: Unsupported logical AND (`&&`) operators and ternary expressions
- **Coverage**: JSON with other MufiZ features (hash tables, vectors, etc.)

## JSON Functions Tested

The tests verify the following JSON functions available in MufiZ:

- `json_is_valid(json_string)` - Validates JSON syntax
- `json_parse(json_string)` - Parses JSON string to MufiZ objects
- `json_stringify(object)` - Converts MufiZ objects to JSON string
- `json_get(object, key)` - Gets value from parsed JSON object
- `json_set(object, key, value)` - Sets value in parsed JSON object
- `json_pretty(object)` - Pretty-prints JSON (currently same as stringify)

## Running the Tests

### Individual Test Execution
```bash
# Run basic JSON tests
./zig-out/bin/mufiz -r test_suite/json/json_basic_test.mufi

# Run simple JSON tests
./zig-out/bin/mufiz -r test_suite/json/json_simple_test.mufi
```

### Full Test Suite
```bash
# Run all tests including JSON tests
python3 test_suite.py
```

## Test Results

- **Total JSON Tests**: 5
- **Passing Tests**: 2
- **Problematic Tests**: 3
- **Core Functionality**: ✅ Working
- **Advanced Features**: ⚠️ Need fixes

## Known Issues

### Memory Management
- String concatenation in loops causes "Invalid free" panics
- Memory leaks reported in string allocation paths
- Related to stdlib v2 migration memory handling

### Language Features
- No support for logical AND (`&&`) operator
- No support for ternary expressions (`condition ? true : false`)
- Variable scope restrictions prevent reusing loop counters

### Workarounds
- Use nested if statements instead of logical AND
- Use separate if-else blocks instead of ternary expressions
- Use different variable names for each loop in the same function

## Integration Status

The JSON functionality integrates well with:
- ✅ Hash tables (`hash_table()`, `put()`, `get()`)
- ✅ Float vectors (`{1.0, 2.0, 3.0}`)
- ✅ Linked lists (`linked_list()`, `push()`, `nth()`)
- ✅ Assert statements for testing
- ✅ Basic control flow (if/while loops)
- ✅ Function definitions and calls

## Cleanup Completed

The following debug and testing files were removed from the root directory:
- `debug_json_test.mufi`
- `simple_json_test.mufi`
- `test_json.mufi`
- `test_json_simple.mufi`
- `debug_vec_test.mufi`
- `simple_vec_test.mufi`
- `test_functions.mufi`
- `test_output.txt`

All JSON testing is now consolidated in the `test_suite/json/` directory with proper organization and documentation.

## Recommendations

1. **Priority**: Fix memory management issues in advanced tests
2. **Enhancement**: Add support for logical operators (`&&`, `||`)
3. **Enhancement**: Add support for ternary expressions
4. **Testing**: Expand edge case coverage once syntax issues are resolved
5. **Documentation**: Add more inline documentation to complex test scenarios