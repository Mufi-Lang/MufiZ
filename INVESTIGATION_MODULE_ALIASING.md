# Module Aliasing Investigation Summary

## Overview
This document outlines the current module import system in MufiZ and provides a detailed analysis for implementing proper module aliasing with dot notation (e.g., `import math as m; m.PI`).

## Current State Analysis

### 1. Files Involved in Module System

#### Core Files:
- **`src/compiler.zig`** - Handles parsing and bytecode emission for import statements
- **`src/vm.zig`** - Executes import-related opcodes and handles module loading at runtime
- **`src/module_registry.zig`** - Manages module discovery, loading, and population
- **`src/objects/module.zig`** - Defines the `ObjModule` structure for module objects
- **`src/stdlib_main.zig`** - Registers stdlib functions (math, io, types, etc.)
- **`src/stdlib/math.zig`** - Implements math module functions
- **`src/object.zig`** - High-level object management and module creation
- **`src/chunk.zig`** - Defines opcodes including `OP_IMPORT_MODULE_AS` and `OP_GET_PROPERTY`

### 2. Current Import Statement Handling

#### Compiler Side (`src/compiler.zig`)

**Import Syntax Support:**
- `import math;` → `OP_IMPORT_MODULE` opcode
- `import math as m;` → `OP_IMPORT_MODULE_AS` opcode
- `import "file.mufi";` → `OP_IMPORT_FILE` opcode
- `import "file.mufi" as alias;` → `OP_IMPORT_FILE_AS` opcode
- `from math import sin, cos;` → `OP_IMPORT_SPECIFIC` opcodes

**Key Functions:**
- `importStatement()` - Routes to file or module import
- `moduleImportStatement()` - Parses module imports with optional `as` clause
- `fileImportStatement()` - Parses file imports with optional `as` clause
- `fromImportStatement()` - Parses selective imports

**Current Limitation:** The `as` clause is already parsed, but it's only used to create a module alias. Direct access to module members requires dot notation, which currently works BUT the module must be stored as a module object with populated members.

#### VM Side (`src/vm.zig`)

**Opcode Handlers:**
- `opImportModule()` - Loads a module by name and registers it as a global
  - Creates an `ObjModule` object
  - Populates it with module members via `populateModuleMembers()`
  - Stores it as a global variable with the module name
  
- `opImportModuleAs()` - Loads a module and stores it with an alias name
  - Similar to `opImportModule()` but uses the alias as the global name
  - **This is the key operation for supporting `import math as m`**
  
- `opGetProperty()` - Handles dot notation property access
  - Already checks for `OBJ_MODULE` type and retrieves members
  - Uses `module.getMember()` to access module members
  
- `opGetModuleMember()` - Alternative module member access (less commonly used)

**Current State:** Both `OP_IMPORT_MODULE_AS` and `OP_GET_PROPERTY` work correctly for module aliasing!

### 3. Module Object Structure

#### `src/objects/module.zig`
```zig
pub const Module = struct {
    obj: Obj,
    name: *ObjString,
    members: std.StringHashMap(Value),
    allocator: std.mem.Allocator,

    pub fn getMember(self: *Module, name: []const u8) ?Value
    pub fn setMember(self: *Module, name: []const u8, value: Value) !void
    pub fn hasMember(self: *Module, name: []const u8) bool
};
```

**Properties:**
- Uses a `StringHashMap` to store members (constants and functions)
- Has `get`, `set`, and `has` methods for member access
- Properly initialized with an allocator
- Can be garbage collected as a regular object

### 4. How Module Members Are Populated

#### `src/module_registry.zig` - `populateModuleMembers()`

**For Built-in Modules (math, io, etc.):**
```
1. Check module registry to see if it's a built-in
2. For "math" specifically:
   - Manually add constants: PI, E, TAU, PHI, SQRT2, LN2, LN10
   - Iterate through global variables and add functions of type OBJ_NATIVE
3. For other modules: Similar filtering by type
```

**For User-Defined Modules (file imports):**
```
1. Take a snapshot of current globals
2. Execute the imported file
3. Capture new globals added by the file
4. Add only "pub" (public) members to the module object
```

**Key Constants in Math Module:**
- `PI` = 3.141592653589793
- `E` = 2.718281828459045
- `TAU` = 6.283185307179586
- `PHI` = 1.618033988749895
- `SQRT2` = 1.4142135623730951
- `LN2` = 0.6931471805599453
- `LN10` = 2.302585092994046

### 5. How Property Access Works

#### Dot Notation in Compiler (`src/compiler.zig` - `dot()`)
```
1. Parse: `receiver.property`
2. Get the property name identifier
3. Emit `OP_GET_PROPERTY` (or `OP_SET_PROPERTY` if assignment)
4. Pass the property name as a constant index
```

#### Property Access in VM (`src/vm.zig` - `opGetProperty()`)
```
1. Check if receiver is OBJ_MODULE:
   - If yes: Call module.getMember() and return value
   - Properly handles module aliasing!
2. Check if receiver is OBJ_INSTANCE:
   - Standard instance property access with inline caching
3. Otherwise: Runtime error
```

## Current Import System Flow

### Example: `import math as m; m.PI`

1. **Compilation Phase:**
   - `import math as m;` → Parser calls `moduleImportStatement()`
   - Emits: `OP_IMPORT_MODULE_AS` with constants: "math" and "m"
   - `m.PI` → Parser calls `dot()` with receiver being the identifier "m"
   - Emits: `OP_GET_PROPERTY` with constant: "PI"

2. **Runtime Phase:**
   - `OP_IMPORT_MODULE_AS` executes:
     - Loads math module via registry
     - Creates ObjModule object
     - Populates with math constants and functions
     - Registers as global variable named "m"
   - Variable lookup for "m" returns the module object
   - `OP_GET_PROPERTY` executes:
     - Pops module object from stack
     - Calls module.getMember("PI")
     - Pushes the result (3.141592653589793)

### Current Limitations

The system **MOSTLY WORKS** but has some issues:

1. **No `m.PI` Without Import As:**
   - Current: `import math;` loads functions directly into globals
   - Cannot do: `math.PI` after `import math;` (functions are global, not in module)
   - Only works with: `import math as math; math.PI;`

2. **Constants Not Always Available:**
   - Math constants (PI, E, etc.) are hardcoded in `populateModuleMembers()`
   - Not accessible via `from math import PI;` without special handling

3. **Module Member Registration:**
   - Built-in modules manually add constants in `populateModuleMembers()`
   - No unified system for declaring module constants

## Recommended Approach

### Phase 1: Enable Direct Module Reference (Priority: HIGH)
**Goal:** Allow `import math; math.PI` without requiring alias

**Changes Needed:**

1. **Modify `opImportModule()` in `src/vm.zig`:**
   ```
   Current: Creates module object but doesn't store it globally
   Proposed: Store module object as global with module name
   ```
   - Change from injecting functions into globals
   - To: Creating module object and registering it as global
   - Example: After `import math;`, variable `math` should reference the module

2. **Update `populateModuleMembers()` in `src/module_registry.zig`:**
   - Already handles constants for math module
   - Ensure all built-in modules populate their constants properly

**Example After Implementation:**
```mufi
import math;
print(math.PI);    // 3.14159...
print(math.sin(0)); // 0
```

### Phase 2: Unified Module Constants Declaration (Priority: MEDIUM)
**Goal:** Define module constants in a declarative way

**Changes Needed:**

1. **Create Module Constant Registry in `stdlib_core.zig`:**
   ```zig
   pub const ModuleConstant = struct {
       name: []const u8,
       module: []const u8,
       value: Value,
   };
   
   pub fn registerModuleConstant(constant: ModuleConstant) !void
   ```

2. **Update each stdlib module to register constants:**
   - `math.zig`: Register PI, E, TAU, etc. via registry
   - Other modules: Declare their own constants
   - Auto-populate module objects from registry

**Benefit:** Single source of truth for module constants

### Phase 3: Support `from math import PI` (Priority: MEDIUM)
**Goal:** Allow selective import of module constants

**Changes Needed:**

1. **Enhance `opImportSpecific()` in `src/vm.zig`:**
   - Currently only handles functions
   - Extend to handle module constants
   - Check both functions and constants in module

2. **Update `fromImportStatement()` in `src/compiler.zig`:**
   - Already parses the syntax correctly
   - Just needs runtime support

**Example:**
```mufi
from math import PI, E, sin, cos;
print(PI);      // 3.14159...
print(sin(0));  // 0
```

### Phase 4: Support Object Literals in Module Objects (Priority: LOW)
**Goal:** Allow modules to define complex data structures

**Changes Needed:**

1. **Extend `ObjModule` to support nested structures**
2. **Implement module namespacing for constants**

## Implementation Checklist

### Immediate Actions (For `import math as m; m.PI` support)

- [x] Compiler already parses `import math as m;` syntax
- [x] VM already has `OP_IMPORT_MODULE_AS` opcode
- [x] Module object structure exists with member access
- [x] Dot notation property access works for modules
- [ ] **Test and verify the complete flow works**

### Near-term Actions (For `import math; math.PI` support)

- [ ] Modify `opImportModule()` to store module as global variable
- [ ] Update test cases to verify both syntaxes
- [ ] Documentation update

### Recommended Minimal Implementation

**If you want `import math as m; m.PI` to work TODAY:**

1. Create a simple test file:
```mufi
import math as m;
print(m.PI);
print(m.E);
print(m.sin(0));
```

2. Run it - it should already work! If not, check:
   - Is `opImportModuleAs()` being called?
   - Is `populateModuleMembers()` adding constants to the module?
   - Is `opGetProperty()` finding the members?

**If you want `import math; math.PI` to work:**

1. Modify `opImportModule()` in `src/vm.zig` at line ~3296:
   - Change: Injecting module functions directly to globals
   - To: Store the module object as a global variable
   - Then direct reference like `math.PI` will work automatically

## Key Insights

1. **The Infrastructure Already Exists:**
   - Module aliasing is already implemented!
   - The `OP_IMPORT_MODULE_AS` opcode and `ObjModule` system are ready
   - Just needs testing and possibly enabling for standard imports

2. **Dot Notation Works for Modules:**
   - `opGetProperty()` explicitly checks for `OBJ_MODULE` type
   - Module member lookup is already implemented
   - No compiler changes needed

3. **Constants Are Hardcoded:**
   - Math constants hardcoded in `populateModuleMembers()`
   - Better approach: Register as module metadata
   - Could be unified across all stdlib modules

4. **Two Import Styles Now Possible:**
   - Style 1: `import math as m; m.PI` (namespace isolation)
   - Style 2: `import math; PI` (flat namespace - current)
   - With modification: `import math; math.PI` (best of both)

## Files Modified Summary

| File | Changes | Priority |
|------|---------|----------|
| `src/vm.zig` | Modify `opImportModule()` to store module as global | HIGH |
| `src/module_registry.zig` | Possibly refactor constant registration | MEDIUM |
| `src/stdlib/math.zig` | Register constants via registry (optional) | LOW |
| Test files | Add test cases for module aliasing | HIGH |

## Testing Strategy

1. **Test Case 1:** `import math as m; print(m.PI);`
2. **Test Case 2:** `import math; print(math.sin(0));`
3. **Test Case 3:** `from math import PI; print(PI);`
4. **Test Case 4:** Multiple module imports with different styles
5. **Test Case 5:** Verify no namespace pollution with aliases

---

**Status:** Ready for implementation
**Confidence Level:** High - infrastructure is in place
**Estimated Effort:** 2-4 hours for Phase 1