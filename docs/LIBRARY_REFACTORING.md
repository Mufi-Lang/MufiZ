# MufiZ Library/Executable Refactoring Summary

## Overview

This refactoring splits the MufiZ compiler into two components:
1. **Library** (`libmufiz`) - Core compiler and interpreter functionality
2. **Executable** (`mufiz`) - Command-line interface that uses the library

This aligns with modern Zig project practices and enables external tooling integration.

## Changes Made

### 1. New Library Module (`src/lib.zig`)

Created a new library module that:
- Exports core modules (vm, compiler, value, object, chunk, memory, etc.)
- Provides a clean public API with initialization/cleanup functions
- Re-exports commonly used types (Value, VM, Chunk, OpCode)
- Includes documentation and usage examples
- Adds basic tests for library functionality

Key API functions:
```zig
pub fn init(options: InitOptions) !void
pub fn deinit() void
pub fn interpret(source: []const u8) u8
pub fn startRepl() !void
pub fn getAllocator() std.mem.Allocator
pub const Runner = system.Runner
```

### 2. Refactored Main Entry Point (`src/main.zig`)

Simplified the main entry point to:
- Import the library module instead of individual components
- Use library functions for initialization and cleanup
- Keep only CLI-specific logic (argument parsing, command handling)
- Reduce code duplication

Changes:
- Replaced direct imports with `const mufiz = @import("lib.zig")`
- Changed `mem_utils.initAllocator()` to `mufiz.init()`
- Changed `vm_h.initVM()` calls to library functions
- Simplified cleanup logic using library's `deinit()`

### 3. Updated Build System (`build.zig`)

Enhanced the build script to:
- Build both a static library and executable
- Support library tests
- Add example build targets
- Maintain all existing build options and features

New build artifacts:
- `libmufiz.a` - Static library
- `mufiz` - Executable (uses the library)
- `library_usage` - Example demonstrating library usage

New build commands:
```bash
zig build              # Build library and executable
zig build test         # Run library tests
zig build example      # Build library usage example
zig build run-example  # Build and run the example
```

### 4. Documentation Updates (`README.md`)

Added comprehensive documentation:
- New "Project Structure" section explaining library/executable split
- "Using MufiZ as a Library" section with code examples
- Library API reference
- Updated build instructions
- Added information about available modules

### 5. Example Code (`examples/library_usage.zig`)

Created a practical example demonstrating:
- Library initialization with custom options
- Interpreting MufiZ code programmatically
- Error handling
- Memory leak detection
- Multiple execution scenarios

## Benefits

### For Users
- **Existing workflow unchanged**: The `mufiz` executable works exactly as before
- **All features preserved**: All build options, features, and functionality maintained

### For Developers
- **Code reuse**: Library can be imported by other Zig projects
- **Better testing**: Library functions can be tested independently
- **Tooling integration**: Enables LSP servers, formatters, linters to use MufiZ
- **Cleaner architecture**: Clear separation between CLI and core functionality
- **Easier maintenance**: Modular structure simplifies updates

### For the Ecosystem
- **Plugin development**: Third-party tools can use the library
- **Educational use**: Library provides clean API for learning
- **Integration**: Can be embedded in larger applications
- **Standardization**: Follows common Zig project patterns

## File Structure

```
MufiZ/
├── src/
│   ├── lib.zig          # NEW: Library module (public API)
│   ├── main.zig         # MODIFIED: CLI entry point (uses library)
│   ├── vm.zig           # Core VM (unchanged)
│   ├── compiler.zig     # Core compiler (unchanged)
│   └── ...              # Other modules (unchanged)
├── examples/
│   └── library_usage.zig # NEW: Library usage example
├── build.zig            # MODIFIED: Builds library + executable
└── README.md            # MODIFIED: Added library documentation
```

## Backward Compatibility

✅ **Fully backward compatible**
- Executable behavior unchanged
- All command-line options work as before
- All build options preserved
- No breaking changes to existing workflows

## Testing

The refactoring includes:
- Unit tests in `src/lib.zig` for library initialization and basic interpretation
- Example code that demonstrates library usage
- Build system support for running tests (`zig build test`)

## Next Steps

To verify the changes work correctly:
1. Build the project: `zig build`
2. Run the executable: `zig build run`
3. Run the library tests: `zig build test`
4. Run the example: `zig build run-example`

## Migration Guide for External Projects

To use MufiZ as a library in your Zig project:

1. Add MufiZ as a dependency in your `build.zig.zon`
2. Import it in your code: `const mufiz = @import("mufiz")`
3. Initialize: `try mufiz.init(.{})`
4. Use the API: `_ = mufiz.interpret("print(42);")`
5. Cleanup: `defer mufiz.deinit()`

See `examples/library_usage.zig` for a complete example.
