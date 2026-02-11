# Stdlib Function Extraction and Data Generation

## Overview

This document describes the automatic standard library function extraction system and improved data generation for MufiZ.

## Architecture

### 1. Automatic Function Extraction (`extract_stdlib.py`)

This script automatically extracts all standard library functions from the MufiZ source code and generates a JSON file containing function metadata.

**Features:**
- Parses `DefineFunction` declarations from Zig source files
- Extracts function names, parameter counts, and module associations
- Handles various parameter specification patterns (`NoParams`, `OneNumber`, `TwoNumbers`, custom arrays)
- Generates structured JSON output for consumption by other tools

**Usage:**
```bash
python3 tools/extract_stdlib.py
```

**Output:** `tools/stdlib_functions.json`

**JSON Structure:**
```json
{
  "functions": {
    "sin": 1,
    "cos": 1,
    "push": 2,
    ...
  },
  "by_module": {
    "math": {
      "sin": 1,
      "cos": 1,
      ...
    },
    "collections": {
      "push": 2,
      "pop": 1,
      ...
    }
  },
  "total_count": 146
}
```

### 2. Data Generation (`mufiz_dataset_gen.py`)

The data generator creates valid MufiZ programs for testing and training purposes.

**Improvements:**
- **Automatic stdlib loading**: Reads `stdlib_functions.json` instead of hardcoded function list
- **146 functions across 11 modules**: math, collections, io, types, utils, time, filesystem, network, matrix, json, serde
- **Class support**: Generates classes with methods (20% probability)
- **Fallback mechanism**: Uses a minimal function set if JSON is unavailable

**Features Generated:**
- Variable and constant declarations
- Function definitions with parameters
- Class definitions with methods
- Control flow (if/else, for, foreach, while)
- Standard library function calls
- Expressions with proper precedence
- Collections (vectors, hash tables, matrices)
- **Pair literals** using `=>` operator
- Pair operations (nested pairs, pairs in lists, hash table iteration)

**Usage:**
```bash
# Generate 100 programs
python3 tools/mufiz_dataset_gen.py --count 100 --output ./dataset

# With specific options
python3 tools/mufiz_dataset_gen.py --count 1000 --output ./large_dataset --cores 8
```

## Workflow

### Updating Stdlib Functions

When new standard library functions are added to MufiZ:

1. **Add the function** to the appropriate module in `src/stdlib/*.zig` using `DefineFunction`
2. **Run extraction** to update the JSON:
   ```bash
   python3 tools/extract_stdlib.py
   ```
3. **Verify the output**:
   ```bash
   cat tools/stdlib_functions.json | jq '.total_count'
   ```
4. **Data generator automatically uses new functions** on next run

### Manual Update (if needed)

If the extraction script fails or needs updating, you can manually edit `stdlib_functions.json`:

```json
{
  "functions": {
    "new_function": 2
  }
}
```

## Statistics

Current stdlib coverage (as of last extraction):

| Module      | Function Count |
|-------------|----------------|
| collections | 34             |
| math        | 23             |
| matrix      | 22             |
| types       | 13             |
| filesystem  | 10             |
| network     | 10             |
| serde       | 10             |
| utils       | 8              |
| time        | 8              |
| json        | 6              |
| io          | 4              |
| **TOTAL**   | **146**        |

## Grammar Support

The data generator follows the PEG grammar in `docs/grammar.peg`:

### Supported Declarations
- `class` - Class definitions with inheritance
- `fun` - Function definitions
- `var` - Mutable variable declarations
- `const` - Constant declarations

### Supported Statements
- `print` - Output statements
- `if`/`else` - Conditional execution
- `for` - C-style loops
- `foreach` - Iterator loops
- `while` - Conditional loops
- `return` - Function returns
- `break`/`continue` - Loop control
- `switch`/`case` - Pattern matching

### Supported Expressions
- Arithmetic: `+`, `-`, `*`, `/`, `%`, `^`
- Comparison: `==`, `!=`, `<`, `>`, `<=`, `>=`
- Logical: `and`, `or`, `!`
- Assignment: `=`, `+=`, `-=`, `*=`, `/=`
- Ternary: `condition ? true_val : false_val`
- Range: `..`, `..=`

### Supported Data Types
- Numbers: integers, floats, imaginary (`42`, `3.14`, `2i`)
- Strings: regular, multiline, backtick, f-strings
- Booleans: `true`, `false`
- Nil: `nil`
- Collections: vectors `[1, 2, 3]`, hash tables `#{"key": value}`
- Matrices: `[[1, 2], [3, 4]]`
- **Pairs**: key-value pairs using `=>` operator (`"key" => "value"`, `1 => 2`)
  - Nested pairs: `"outer" => ("inner" => 100)`
  - Pair access: `pair[0]` for key, `pair[1]` for value
  - Pairs in collections: `push(list, "name" => "Alice")`
  - Hash table iteration: `foreach (pair in pairs(hash_table))`

## Troubleshooting

### JSON file not found
```
Warning: stdlib_functions.json not found, using fallback list
```
**Solution:** Run `python3 tools/extract_stdlib.py`

### Function parameter count mismatch
If generated code has incorrect parameter counts:
1. Check the `DefineFunction` declaration in the source
2. Re-run `extract_stdlib.py`
3. Verify the JSON output

### Invalid generated code
If the validator rejects generated programs:
1. Check the grammar in `docs/grammar.peg`
2. Review the generator's function call logic
3. Adjust parameter generation for specific functions

## Pair Statement Examples

The generator creates various pair-related code patterns:

**Simple pairs:**
```mufi
var p1 = "key" => "value";
print(p1[0]);  // prints "key"
print(p1[1]);  // prints "value"
```

**Nested pairs:**
```mufi
var nested = "outer" => ("inner" => 100);
print(nested[1][0]);  // prints "inner"
print(nested[1][1]);  // prints 100
```

**Pairs in collections:**
```mufi
var list = linked_list();
push(list, "name" => "Alice");
push(list, "age" => 30);
var first = nth(list, 0);
print(first[0]);  // prints "name"
```

**Hash table iteration:**
```mufi
var ht = #{"a": 1, "b": 2};
foreach (pair in pairs(ht)) {
    print(pair[0]);  // key
    print(pair[1]);  // value
}
```

## Future Enhancements

Potential improvements:
- [ ] Type-aware parameter generation
- [ ] Cross-function data flow
- [ ] More complex class hierarchies
- [ ] Import statement generation
- [ ] Module system support
- [ ] Property/field access on class instances
- [ ] Super class method calls
- [x] Pair literal syntax and operations

## Contributing

When adding new stdlib functions:
1. Use `DefineFunction` macro in Zig code
2. Document parameter types in `ParamSpec`
3. Run extraction script
4. Test data generation with new functions
5. Update this README if extraction patterns change