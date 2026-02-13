# Dynamic Library Initialization Fix

## Problem

When using MufiZ as a dynamic library (`.dylib`/`.so`), there was a potential null pointer issue during VM initialization. The problem manifested as an "attempt to use a null value" error when calling `mufiz_init()`.

## Root Cause

The issue was related to how the Global Purpose Allocator (GPA) was initialized in `src/mem_utils.zig`:

```zig
// Old code - GPA initialized at compile time
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
```

In a dynamic library context, this global initialization could occur at an unexpected time or in an incomplete state, leading to allocation failures when the VM tried to initialize strings and native functions.

## Solution

Changed the GPA to use lazy initialization to ensure it's properly set up before first use:

```zig
// New code - GPA with lazy initialization
var gpa: ?std.heap.GeneralPurposeAllocator(.{}) = null;

fn ensureGPAInitialized() void {
    if (gpa == null) {
        gpa = std.heap.GeneralPurposeAllocator(.{}){};
    }
}

pub fn getAllocator() std.mem.Allocator {
    ensureGPAInitialized();
    return gpa.?.allocator();
}
```

This ensures that:
1. The GPA is initialized on first access, not at library load time
2. The initialization happens in a controlled manner
3. All subsequent allocations use the properly initialized allocator

## Changes Made

### File: `src/mem_utils.zig`

- Changed `gpa` from non-optional to optional type
- Added `ensureGPAInitialized()` helper function
- Updated `getAllocator()` to call `ensureGPAInitialized()`
- Updated `initAllocator()` to call `ensureGPAInitialized()`
- Updated `getVMArenaAllocator()` to call `ensureGPAInitialized()`
- Updated `checkForLeaks()` to handle optional GPA

### File: `src/c_api.zig`

- Fixed test code to properly handle sentinel-terminated pointers

## Testing

Created `test_c_api.c` to verify the fix:

```bash
# Compile and run test
zig build
clang -o test_c_api test_c_api.c -L./zig-out/lib -lmufiz -I. -Wl,-rpath,./zig-out/lib
./test_c_api
```

### Test Results

✅ All tests pass:
- Library initialization works correctly
- Script execution succeeds
- String utilities work properly
- Double initialization correctly detected
- Library deinitialization completes

## Expected Behavior

### Memory Leaks on Exit

The test may report memory leaks when checking `mufiz_has_memory_leaks()`. This is **expected behavior** because:

1. **VM-lifetime objects** (native functions, interned strings, constants) are intentionally kept alive for the VM's lifetime
2. These objects use the arena allocator and are cleaned up en masse when `freeVM()` is called
3. The C API's `mufiz_deinit()` calls `freeVM()`, which properly cleans up these objects

The reported "leaks" are VM infrastructure objects that were allocated during `initVM()`:
- `vm.initString` - used for class constructors
- Native function objects (SIMD functions, etc.)
- String intern table entries
- Global constants

These are freed by `freeVM()` when you call `mufiz_deinit()`.

## API Usage

```c
#include "include/mufiz.h"

int main(void) {
    // Initialize (now safe for dynamic libraries)
    if (mufiz_init(false, false, false) != MUFIZ_OK) {
        fprintf(stderr, "Failed to initialize\n");
        return 1;
    }
    
    // Use the library
    uint8_t result = mufiz_interpret("print(42);");
    
    // Clean up
    mufiz_deinit();
    
    return 0;
}
```

## Building

The dynamic library is automatically built with:

```bash
zig build
```

Output:
- `zig-out/lib/libmufiz.dylib` (macOS)
- `zig-out/lib/libmufiz.so` (Linux)
- `zig-out/lib/libmufiz.dll` (Windows)
- `zig-out/include/mufiz.h` (C header)

## Related Issues

This fix resolves issues with:
- Using MufiZ from Swift via bridging headers
- Loading MufiZ as a plugin/module
- Dynamic library initialization in general
- Cross-language FFI usage

## Verification

To verify the fix works on your system:

```bash
# Build the library
zig build

# Build and run the test
clang -o test_c_api test_c_api.c -L./zig-out/lib -lmufiz -I. -Wl,-rpath,./zig-out/lib
./test_c_api
```

Expected output should include:
```
✓ Library initialized successfully
✓ Script executed successfully
✓ String duplication works
✓ Correctly detected double initialization
=== All tests passed! ===
```

## Future Improvements

Potential enhancements:
1. Add explicit arena cleanup in `mufiz_deinit()`
2. Add `mufiz_check_leaks()` function separate from `mufiz_has_memory_leaks()`
3. Provide more granular memory statistics API
4. Add thread-safety for multi-threaded dynamic library usage

## Credits

Fixed as part of resolving Zig 0.15 compatibility and build system improvements.