# Import Statement Implementation - Technical Summary

## Problem Statement
Implement an import statement expression into the MufiZ language to allow importing modules that act like classes/objects:

```mufi
const foo = import("foo.mufiz"); 
const res = foo.add(2,3);
```

## Solution Overview

The import functionality is implemented as a **native function** that:
1. Reads and executes a MufiZ source file
2. Captures all global functions and constants defined in that file
3. Returns them as an ObjInstance (object) with accessible properties

## Technical Implementation

### 1. Lexical Analysis (scanner.zig)
- **Added**: `TOKEN_IMPORT` (token type 51)
- **Modified**: Keyword map to recognize "import" keyword
- **Impact**: All subsequent token numbers shifted by 1

### 2. Parsing (compiler.zig)
- **Added**: Parse rule for `TOKEN_IMPORT` using the `variable` prefix function
- **Effect**: `import` can be used as an identifier that references a native function

### 3. Runtime System (stdlib/module.zig)
New module implementing the core import functionality:

#### Key Components:
- **Module Cache**: `StringHashMap(*ObjInstance)` to store loaded modules
- **import()**: Main native function that implements the import logic

#### Import Process:
```
1. Validate input (must be single string argument)
2. Check cache for previously loaded module
3. Read file contents from disk
4. Save current VM globals table
5. Create new empty globals table for module
6. Execute module code in isolated scope
7. Capture module's globals table
8. Restore original globals table
9. Create ObjClass and ObjInstance for the module
10. Copy all module globals to instance fields
11. Cache the instance
12. Return the instance as a Value
```

### 4. Standard Library Registration (stdlib.zig)
- **Added**: Import of `module` submodule
- **Modified**: `CORE_FUNCTIONS` array to include `import` function

## How It Works

### Module Execution Isolation
When a module is imported:
1. The current VM global table is saved
2. A fresh empty table is created for the module
3. The module code executes in this isolated environment
4. After execution, globals from the module are copied to an instance
5. The original globals are restored

This ensures:
- Modules don't interfere with the importing script's globals
- Module code executes in a clean environment
- All defined functions/constants are captured

### Property Access Mechanism
The returned module is an `ObjInstance`:
- Functions and constants are stored as **fields** in the instance
- When accessing `foo.add`, the VM's `OP_GET_PROPERTY` opcode:
  1. Checks the instance's fields table
  2. Returns the function value if found
  3. The function can then be called normally

### Function Calls
When calling `foo.add(2, 3)`:
1. `foo` is resolved to an ObjInstance
2. `.add` accesses the `add` field (which contains a closure)
3. `(2, 3)` invokes the closure with those arguments
4. The VM's existing call mechanism handles execution

## Data Structures

### ObjInstance Structure
```zig
pub const Instance = struct {
    obj: Obj,
    klass: *ObjClass,
    fields: Table,  // Contains imported functions/constants
}
```

### Module Cache
```zig
var module_cache: ?std.StringHashMap(*ObjInstance) = null;
```
- Key: File path (string)
- Value: Pointer to loaded module instance

## Memory Management
- Modules are GC-managed as ObjInstance objects
- The module cache holds references, preventing premature collection
- Loaded modules persist for the lifetime of the program
- File contents are temporarily allocated and freed after compilation

## Error Handling
- **File not found**: Returns `nil`, prints error message
- **Compilation error**: Returns `nil`, prints error message
- **Invalid argument**: Returns stdlib error value
- **Wrong argument count**: Returns stdlib error value

## Performance Characteristics
- **First import**: O(n) where n is file size + compilation time
- **Cached import**: O(1) hash table lookup
- **Property access**: O(1) hash table lookup in instance fields
- **Function calls**: Same overhead as regular function calls

## Limitations & Design Decisions

### Current Design
- Modules are executed at import time (not lazily)
- All globals become exported (no explicit export syntax)
- Module path is relative to current working directory
- Modules cannot import other modules (no recursive imports yet)

### Why ObjInstance?
1. Reuses existing property access mechanism
2. No new VM opcodes required
3. Works with existing GC
4. Familiar syntax for users (same as class instances)

### Why Not ObjClass?
- Classes are for defining types, not holding data
- Instances naturally hold fields (our exports)
- Methods would require binding, adding complexity

## Testing Strategy

### Test Coverage
1. **Basic**: Simple function import
2. **Multiple Exports**: Functions and constants
3. **Recursion**: Recursive functions in modules
4. **Multi-param**: Functions with multiple parameters
5. **Caching**: Same module imported twice
6. **Edge Cases**: Empty modules, constants-only, non-existent files

### Test Files Structure
- `*.mufiz`: Module files (to be imported)
- `test_*.mufi`: Test scripts (that import modules)
- `import_tests_README.md`: Test documentation

## Future Enhancements

Potential improvements:
1. **Explicit Exports**: `export fun add(a, b) { ... }`
2. **Module Aliases**: `const m = import("module.mufiz") as myModule`
3. **Circular Import Detection**: Prevent infinite import loops
4. **Relative Imports**: `import("./utils.mufiz")` vs `import("utils.mufiz")`
5. **Module Reload**: Force reload of cached modules
6. **Import Specific Items**: `const { add, multiply } = import("math.mufiz")`

## Security Considerations
- File system access required (controlled by `enable_fs` flag)
- No path traversal protection yet
- Modules execute with full language capabilities
- Consider sandboxing for untrusted modules

## Compatibility
- Works with all existing MufiZ features
- No breaking changes to existing code
- Compatible with REPL mode
- Works with all data types (numbers, strings, objects, etc.)

## Summary
The import statement successfully enables modular code organization in MufiZ by:
- Leveraging existing VM infrastructure
- Providing intuitive object-like module access
- Maintaining language simplicity
- Supporting the exact use case specified in the problem statement
