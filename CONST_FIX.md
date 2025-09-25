# MufiZ `const` Keyword Fix

## Problem Description

The `const` keyword in MufiZ was not working properly for global variables. While local constants were correctly enforced, global constants could be reassigned without any error, effectively behaving like `var` declarations.

### Original Behavior (Broken)
```mufi
const a = 5;
print(a);  // Output: 5
a = 6;     // Should fail but didn't
print(a);  // Output: 6 (incorrect!)
```

### Expected Behavior
```mufi
const a = 5;
print(a);  // Output: 5
a = 6;     // Should produce runtime error
// Error: Cannot assign to constant variable 'a'
```

## Root Cause Analysis

The issue was in the compiler and VM architecture:

1. **Local constants** were properly tracked using the `isConst` field in the `Local` struct
2. **Global constants** were treated identically to regular global variables
3. Both `const` and `var` global declarations emitted the same `OP_DEFINE_GLOBAL` opcode
4. The runtime had no way to distinguish between global constants and variables
5. Assignment checks in `namedVariable()` only applied to local variables (`arg != -1`)

### Technical Details

In `compiler.zig`:
- `defineVariable()` and `defineConstVariable()` both emitted `OP_DEFINE_GLOBAL`
- No distinction was made between constants and variables at the VM level
- Global constants were stored in the same table as regular globals without any const flag

## Solution Implementation

### 1. Added Global Constants Tracking

**VM Structure Enhancement** (`src/vm.zig`):
```zig
pub const VM = struct {
    // ... existing fields ...
    globals: Table,
    globalConstants: Table,  // NEW: Track which globals are constants
    // ... rest of fields ...
};
```

### 2. New Opcode for Constant Definitions

**Added `OP_DEFINE_CONST_GLOBAL`** (`src/chunk.zig`):
- New opcode specifically for defining global constants
- Renumbered all subsequent opcodes to accommodate the addition

### 3. Compiler Changes

**Updated `defineConstVariable()`** (`src/compiler.zig`):
```zig
pub fn defineConstVariable(global: u8) void {
    // ... scope checks ...
    emitBytes(@intCast(@intFromEnum(OpCode.OP_DEFINE_CONST_GLOBAL)), global);
}
```

### 4. Runtime Enforcement

**VM Runtime Checks** (`src/vm.zig`):
```zig
.OP_DEFINE_CONST_GLOBAL => {
    const name: *ObjString = @ptrCast(@alignCast(constant.?.as.obj));
    _ = tableSet(&vm.globals, name, peek(0));
    // Mark this variable as a constant
    _ = tableSet(&vm.globalConstants, name, Value.init_bool(true));
    _ = pop();
    continue;
},

.OP_SET_GLOBAL => {
    // Check if this is a global constant
    var dummy_value: Value = undefined;
    if (tableGet(&vm.globalConstants, name, &dummy_value)) {
        const varName = zstr(name);
        runtimeError("Cannot assign to constant variable '{s}'.", .{varName});
        return .INTERPRET_RUNTIME_ERROR;
    }
    // ... rest of assignment logic ...
},
```

### 5. Debug Support

**Updated debug module** (`src/debug.zig`):
- Added support for the new `OP_DEFINE_CONST_GLOBAL` opcode
- Updated all opcode numbers in the debug switch statement

## Verification and Testing

### Test Results

**Script Execution Test**:
```bash
$ ./zig-out/bin/mufiz --run test_const.mufi
PI = 3.14159
Language: MufiZ
PI * 2 = 6.28318
Cannot assign to constant variable 'PI'.
[line 14] in script
error: RuntimeError
```

**REPL Test**:
```bash
(mufi) >> const x = 5;
(mufi) >> print(x);
5
(mufi) >> x = 10;
Cannot assign to constant variable 'x'.
[line 1] in script
(mufi) >> var y = 5;
(mufi) >> y = 10;
(mufi) >> print(y);
10
```

### Comprehensive Test Cases

1. ✅ **Const Declaration**: `const PI = 3.14159;` works
2. ✅ **Const Usage**: `print(PI);` works  
3. ✅ **Const in Expressions**: `PI * 2` works
4. ✅ **Const Reassignment Prevention**: `PI = 2.71;` fails with error
5. ✅ **Var Declaration**: `var x = 5;` works
6. ✅ **Var Reassignment**: `x = 10;` works
7. ✅ **Mixed Usage**: const and var can coexist properly
8. ✅ **REPL Support**: All functionality works in interactive mode
9. ✅ **Script Support**: All functionality works in script execution mode

## Files Modified

### Core Implementation
- `src/vm.zig`: Added `globalConstants` table and runtime checks
- `src/chunk.zig`: Added `OP_DEFINE_CONST_GLOBAL` opcode
- `src/compiler.zig`: Updated `defineConstVariable()` to use new opcode
- `src/debug.zig`: Added debug support for new opcode

### Test Files Created
- `test_const.mufi`: Basic const functionality test
- `test_var.mufi`: Var functionality verification
- `test_const_vs_var.mufi`: Comprehensive comparison test
- `test_repl_const.sh`: REPL-specific const testing

## Backward Compatibility

✅ **Fully backward compatible**:
- Existing `var` declarations work exactly as before
- Existing `const` local variables continue to work
- Only global `const` behavior has been fixed
- No breaking changes to existing code

## Performance Impact

**Minimal performance overhead**:
- One additional table lookup during global variable assignment
- Constant declarations have negligible additional cost
- No impact on local variable performance
- Memory overhead: One additional hash table for global constants tracking

## Future Considerations

1. **Optimization**: Could combine globals and globalConstants into a single table with metadata
2. **Error Messages**: Could enhance error messages with suggestions for alternatives
3. **Type System**: Foundation for future type checking enhancements
4. **Compile-time Checking**: Potential for compile-time constant validation

## Summary

The `const` keyword now works correctly for both local and global variables in MufiZ:

- **Local constants**: Already worked (unchanged)
- **Global constants**: Now properly enforced (fixed)
- **Variables (`var`)**: Continue to work as expected (unchanged)
- **Error reporting**: Clear error messages when attempting to reassign constants
- **REPL support**: Full interactive mode functionality
- **Script support**: Works in both file execution and REPL modes

The fix ensures that `const` declarations are truly immutable as expected in the language specification, providing proper constant semantics while maintaining full backward compatibility.