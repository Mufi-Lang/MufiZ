# WASM Build Fix Summary

## Problem

The WASM build was failing with compilation errors when trying to build `zig build wasm`:

```
error: the target operating system cannot spawn processes
referenced by:
    spawnAndWait: std/process/Child.zig:259:19
    cloneRepository: src/cache.zig:246:42
```

The issue occurred because the package manager (PM) functionality, which includes:
- Git repository cloning
- File system operations
- Process spawning

...was being compiled into the WASM binary, but WASM doesn't support these operations.

## Root Cause

The `src/lib.zig` module unconditionally imported and exposed the PM modules:

```zig
pub const pm = @import("pm.zig");
pub const cache = @import("cache.zig");
pub const resolver = @import("resolver.zig");
```

When building for WASM (`wasm32-wasi` target), these modules were still compiled, causing the build to fail because they use OS-specific features like:
- `std.process.Child` - Process spawning
- File system operations that aren't available in WASM

## Solution

### 1. Conditional Module Imports

Modified `src/lib.zig` to conditionally import PM modules based on target architecture:

```zig
const builtin = @import("builtin");
pub const pm = if (builtin.target.cpu.arch != .wasm32) @import("pm.zig") else struct {};
pub const cache = if (builtin.target.cpu.arch != .wasm32) @import("cache.zig") else struct {};
pub const resolver = if (builtin.target.cpu.arch != .wasm32) @import("resolver.zig") else struct {};
```

This ensures that for WASM builds, empty structs are used instead of the actual modules, preventing compilation of unsupported code.

### 2. Runtime Guards for PM Functions

Added runtime checks at the beginning of all PM and file-related functions:

```zig
pub fn pmInit(allocator: std.mem.Allocator, project_name: []const u8) !void {
    if (builtin.target.cpu.arch == .wasm32) return error.NotSupportedInWasm;
    try pm.initProject(allocator, project_name);
}
```

This approach:
- Returns early with a clear error for WASM targets
- Allows the code to compile for WASM (dead code elimination removes the PM calls)
- Provides clear error message if somehow called in WASM context
- Keeps the API surface consistent across platforms

### Functions with WASM Guards

**Package Management (8 functions)**:
- `pmInit()` - Initialize project
- `pmNew()` - Create new project
- `pmInfo()` - Display project info
- `pmRun()` - Run project
- `pmInstall()` - Install dependencies
- `pmAddDependency()` - Add dependency
- `pmCacheInfo()` - Cache statistics
- `pmCacheClear()` - Clear cache

**File Operations (1 function)**:
- `formatFile()` - Format file in-place (requires FS access)

**Note**: `formatSource()` still works in WASM since it operates on in-memory strings.

## Results

### Before Fix
```bash
$ zig build wasm
error: the target operating system cannot spawn processes
        @compileError("the target operating system cannot spawn processes");
        ^~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Build Summary: 2/5 steps succeeded; 1 failed
```

### After Fix
```bash
$ zig build wasm
# Success!

$ ls -lh zig-out/wasm/
-rwxr--r--  313K  mufiz.wasm

$ file zig-out/wasm/mufiz.wasm
zig-out/wasm/mufiz.wasm: WebAssembly (wasm) binary module version 0x1 (MVP)
```

## WASM API Limitations

When using MufiZ in WASM, the following functions are **not available** and will return `error.NotSupportedInWasm`:

### ❌ Not Available in WASM
- Package Management: All `mufiz_pm_*` functions
- File Operations: `mufiz_format_file()`

### ✅ Available in WASM
- Core interpreter: `mufiz_init()`, `mufiz_interpret()`, `mufiz_deinit()`
- Memory management: `mufiz_has_memory_leaks()`, `mufiz_print_memory_stats()`
- String utilities: `mufiz_strdup()`, `mufiz_free_cstring()`
- Source formatting: `mufiz_format_source()` (in-memory only)
- WASM wrappers: `init_wasm()`, `interpret()`, `deinit_wasm()`

## Testing

### Build Verification
```bash
# Test WASM build
zig build wasm
# ✅ Success

# Test regular build
zig build
# ✅ Success

# Test header validation
zig build validate-header
# ✅ SUCCESS: All exported functions have header declarations!
#    Total functions validated: 21
```

### Runtime Behavior

In WASM environment, calling unsupported functions returns an error:

```c
// This works in WASM
int result = mufiz_init(false, false, false);
uint8_t exit_code = mufiz_interpret("var x = 42;");

// These return MUFIZ_ERR_GENERIC in WASM (wraps error.NotSupportedInWasm)
int pm_result = mufiz_pm_init("my-project");
// pm_result will be MUFIZ_ERR_GENERIC (-3)
```

## File Changes

### Modified
- `src/lib.zig` - Added conditional imports and runtime guards

### Result
- ✅ WASM builds successfully
- ✅ Native builds work normally
- ✅ Clear error handling for unsupported operations
- ✅ Consistent API across platforms
- ✅ All 21 functions still present in C header

## Benefits

1. **WASM Support**: MufiZ now builds for WebAssembly targets
2. **Clear Boundaries**: Explicit separation of WASM-compatible vs OS-specific code
3. **Graceful Degradation**: Unsupported functions return clear errors
4. **Maintainable**: Easy to understand which features work in WASM
5. **No Duplication**: Single codebase handles both native and WASM

## Future Considerations

### Potential Enhancements
- Add WASM-specific implementations using browser APIs where applicable
- Consider virtual file system for WASM (e.g., using IndexedDB)
- Explore WASI features for more functionality in WASM

### Alternative Approaches Considered
1. **Separate WASM module**: Would require code duplication
2. **Feature flags**: More complex build system
3. **Stub implementations**: Less clear than explicit errors

The chosen approach (conditional compilation with runtime guards) provides the best balance of:
- Simplicity
- Clarity
- Maintainability
- Error handling

## Related Documentation

- `docs/HEADER_GENERATION.md` - C header generation system
- `docs/HEADER_VALIDATION_COMPLETE.md` - Header validation implementation
- `C_API_GUIDE.md` - Complete C API documentation

---

**Fixed**: February 12, 2024
**Zig Version**: 0.15.2
**WASM Binary Size**: ~313KB
**Status**: ✅ RESOLVED