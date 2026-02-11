# MufiZ Library API Documentation

**Version:** 0.11.0+  
**Last Updated:** 2024  
**Language:** Zig with C FFI

---

## Overview

MufiZ can be used as both a standalone interpreter and as an embeddable library. This document covers the library API for both Zig and C/C++ integration.

### Use Cases

- **Embedded Scripting** - Add MufiZ as a scripting language to your application
- **Build Tools** - Create custom build tools using MufiZ
- **Testing Frameworks** - Use MufiZ for test scripting
- **Package Management** - Programmatically manage MufiZ projects
- **Code Formatting** - Format MufiZ code from your tools

---

## Zig Library API

### Installation

Add MufiZ as a dependency in your `build.zig.zon`:

```zon
.{
    .name = "my-project",
    .version = "0.1.0",
    .dependencies = .{
        .mufiz = .{
            .url = "https://github.com/Mustafif/MufiZ",
            .hash = "...",
        },
    },
}
```

Then in your `build.zig`:

```zig
const mufiz_dep = b.dependency("mufiz", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("mufiz", mufiz_dep.module("mufiz"));
```

### Basic Usage

```zig
const std = @import("std");
const mufiz = @import("mufiz");

pub fn main() !void {
    // Initialize the library
    try mufiz.init(.{
        .enable_leak_detection = true,
        .enable_tracking = true,
        .enable_safety = true,
    });
    defer mufiz.deinit();

    // Interpret some code
    const result = mufiz.interpret("var x = 42; println(x);");
    
    if (result == mufiz.OK) {
        std.debug.print("Execution successful!\n", .{});
    }
}
```

### Core Functions

#### Initialization

```zig
pub fn init(options: InitOptions) !void
```

Initialize the MufiZ library. Must be called before any other library functions.

**Parameters:**
- `options` - Configuration options for initialization

**Options:**
```zig
pub const InitOptions = struct {
    enable_leak_detection: bool = false,
    enable_tracking: bool = false,
    enable_safety: bool = false,
};
```

**Errors:**
- `LibraryError.AlreadyInitialized` - Library already initialized

**Example:**
```zig
try mufiz.init(.{
    .enable_leak_detection = true,
    .enable_tracking = false,
    .enable_safety = true,
});
```

---

#### Cleanup

```zig
pub fn deinit() void
```

Clean up and deinitialize the library. Should be called when done. Idempotent.

**Example:**
```zig
defer mufiz.deinit();
```

---

#### Interpretation

```zig
pub fn interpret(source: []const u8) u8
```

Interpret MufiZ source code.

**Parameters:**
- `source` - MufiZ source code as a byte slice

**Returns:**
- `OK` (0) - Success
- `COMPILE_ERROR` (65) - Compilation failed
- `RUNTIME_ERROR` (70) - Runtime error

**Example:**
```zig
const source = "var x = 10; println(x);";
const result = mufiz.interpret(source);
if (result != mufiz.OK) {
    std.debug.print("Execution failed with code: {}\n", .{result});
}
```

---

#### Get Allocator

```zig
pub fn getAllocator() !std.mem.Allocator
```

Get the global allocator used by the library.

**Returns:** The allocator instance

**Errors:**
- `LibraryError.NotInitialized` - Library not initialized

**Example:**
```zig
const allocator = try mufiz.getAllocator();
const buffer = try allocator.alloc(u8, 100);
defer allocator.free(buffer);
```

---

### Package Management API

#### Initialize Project

```zig
pub fn pmInit(allocator: std.mem.Allocator, project_name: []const u8) !void
```

Initialize a new MufiZ project in the current directory.

**Example:**
```zig
const allocator = std.heap.page_allocator;
try mufiz.pmInit(allocator, "my-project");
```

---

#### Create New Project

```zig
pub fn pmNew(allocator: std.mem.Allocator, project_name: []const u8) !void
```

Create a new MufiZ project in a new directory.

**Example:**
```zig
try mufiz.pmNew(allocator, "my-new-project");
```

---

#### Install Dependencies

```zig
pub fn pmInstall(allocator: std.mem.Allocator) !void
```

Install all dependencies from mufi.zon.

**Example:**
```zig
try mufiz.pmInstall(allocator);
```

---

#### Add Dependency

```zig
pub fn pmAddDependency(
    allocator: std.mem.Allocator,
    name: []const u8,
    url: []const u8,
    version: []const u8,
) !void
```

Add a dependency to mufi.zon.

**Example:**
```zig
try mufiz.pmAddDependency(
    allocator,
    "http",
    "https://github.com/user/mufiz-http",
    "v1.0.0",
);
```

---

### Formatting API

#### Format Source

```zig
pub fn formatSource(allocator: std.mem.Allocator, source: []const u8) ![]const u8
```

Format MufiZ source code. Returns allocated string (caller must free).

**Example:**
```zig
const source = "var x=10+20;";
const formatted = try mufiz.formatSource(allocator, source);
defer allocator.free(formatted);
std.debug.print("Formatted: {s}\n", .{formatted});
```

---

#### Format File

```zig
pub fn formatFile(allocator: std.mem.Allocator, filepath: []const u8) !void
```

Format a MufiZ file in-place.

**Example:**
```zig
try mufiz.formatFile(allocator, "src/main.mufi");
```

---

#### Check Formatting

```zig
pub fn needsFormatting(allocator: std.mem.Allocator, source: []const u8) !bool
```

Check if source needs formatting.

**Example:**
```zig
const source = "var x=10;";
const needs = try mufiz.needsFormatting(allocator, source);
if (needs) {
    std.debug.print("File needs formatting\n", .{});
}
```

---

### Advanced Usage

#### Running Scripts from Files

```zig
const mufiz = @import("mufiz");

pub fn main() !void {
    try mufiz.init(.{});
    defer mufiz.deinit();
    
    const allocator = try mufiz.getAllocator();
    var runner = mufiz.Runner.init(allocator);
    defer runner.deinit();
    
    try runner.setMain(@constCast("script.mufi"));
    try runner.runFile();
}
```

---

#### REPL Integration

```zig
const mufiz = @import("mufiz");

pub fn main() !void {
    try mufiz.init(.{});
    defer mufiz.deinit();
    
    try mufiz.startRepl();
}
```

---

## C/C++ Library API

### Building the Shared Library

```bash
zig build -Doptimize=ReleaseFast
# Creates libmufiz.so (Linux), libmufiz.dylib (macOS), or mufiz.dll (Windows)
```

### Header File

Include the MufiZ header:

```c
#include "mufiz.h"
```

### Basic Usage (C)

```c
#include "mufiz.h"
#include <stdio.h>

int main(void) {
    // Initialize
    if (mufiz_init(false, false, false) != MUFIZ_OK) {
        fprintf(stderr, "Failed to initialize MufiZ\n");
        return 1;
    }

    // Run code
    uint8_t result = mufiz_interpret("println(\"Hello from C!\");");
    
    if (result != MUFIZ_INTERPRET_OK) {
        fprintf(stderr, "Execution failed\n");
    }

    // Cleanup
    mufiz_deinit();
    return 0;
}
```

Compile:
```bash
gcc -o myapp myapp.c -lmufiz -L./zig-out/lib
```

---

### Basic Usage (C++)

```cpp
#include "mufiz.h"
#include <iostream>
#include <memory>

class MufizWrapper {
    bool initialized = false;
public:
    MufizWrapper() {
        if (mufiz_init(false, false, false) == MUFIZ_OK) {
            initialized = true;
        }
    }
    
    ~MufizWrapper() {
        if (initialized) {
            mufiz_deinit();
        }
    }
    
    bool interpret(const char* source) {
        if (!initialized) return false;
        return mufiz_interpret(source) == MUFIZ_INTERPRET_OK;
    }
};

int main() {
    MufizWrapper mufiz;
    
    if (!mufiz.interpret("var x = 42; println(x);")) {
        std::cerr << "Execution failed\n";
        return 1;
    }
    
    return 0;
}
```

Compile:
```bash
g++ -o myapp myapp.cpp -lmufiz -L./zig-out/lib
```

---

### C API Functions

#### Core Functions

##### mufiz_init

```c
int32_t mufiz_init(bool enable_leak_detection, 
                   bool enable_tracking, 
                   bool enable_safety);
```

Initialize the library.

**Returns:**
- `MUFIZ_OK` (0) on success
- `MUFIZ_ERR_ALREADY_INITIALIZED` (-1) if already initialized
- `MUFIZ_ERR_GENERIC` (-3) on other errors

---

##### mufiz_deinit

```c
void mufiz_deinit(void);
```

Deinitialize the library. Idempotent.

---

##### mufiz_interpret

```c
uint8_t mufiz_interpret(const char *source);
```

Interpret MufiZ source code.

**Returns:**
- `MUFIZ_INTERPRET_OK` (0) - Success
- `MUFIZ_INTERPRET_COMPILE_ERROR` (65) - Compilation error
- `MUFIZ_INTERPRET_RUNTIME_ERROR` (70) - Runtime error

---

#### Package Management Functions

##### mufiz_pm_init

```c
int32_t mufiz_pm_init(const char *project_name);
```

Initialize a project in current directory.

**Example:**
```c
if (mufiz_pm_init("my-project") != MUFIZ_OK) {
    fprintf(stderr, "Failed to initialize project\n");
}
```

---

##### mufiz_pm_new

```c
int32_t mufiz_pm_new(const char *project_name);
```

Create a new project in a new directory.

---

##### mufiz_pm_install

```c
int32_t mufiz_pm_install(void);
```

Install all dependencies from mufi.zon.

**Example:**
```c
printf("Installing dependencies...\n");
if (mufiz_pm_install() == MUFIZ_OK) {
    printf("Dependencies installed successfully!\n");
}
```

---

##### mufiz_pm_add_dependency

```c
int32_t mufiz_pm_add_dependency(const char *name,
                                const char *url,
                                const char *version);
```

Add a dependency to mufi.zon.

**Example:**
```c
mufiz_pm_add_dependency(
    "http",
    "https://github.com/user/mufiz-http",
    "v1.0.0"
);
```

---

#### Formatting Functions

##### mufiz_format_source

```c
char *mufiz_format_source(const char *source);
```

Format source code. Returns allocated string (must free with `mufiz_free_cstring`).

**Example:**
```c
const char *source = "var x=10+20;";
char *formatted = mufiz_format_source(source);
if (formatted) {
    printf("Formatted: %s\n", formatted);
    mufiz_free_cstring(formatted);
}
```

---

##### mufiz_format_file

```c
int32_t mufiz_format_file(const char *filepath);
```

Format a file in-place.

**Example:**
```c
if (mufiz_format_file("src/main.mufi") == MUFIZ_OK) {
    printf("File formatted successfully\n");
}
```

---

##### mufiz_needs_formatting

```c
int32_t mufiz_needs_formatting(const char *source);
```

Check if source needs formatting.

**Returns:**
- `1` - Needs formatting
- `0` - Already formatted
- `-1` - Error

---

#### String Utilities

##### mufiz_strdup

```c
char *mufiz_strdup(const char *src);
```

Duplicate a string using MufiZ allocator. Must free with `mufiz_free_cstring`.

---

##### mufiz_free_cstring

```c
void mufiz_free_cstring(char *ptr);
```

Free a string allocated by MufiZ.

---

### Complete C Example

```c
#include "mufiz.h"
#include <stdio.h>
#include <stdlib.h>

int main(void) {
    // Initialize library
    if (mufiz_init(true, true, true) != MUFIZ_OK) {
        fprintf(stderr, "Initialization failed\n");
        return EXIT_FAILURE;
    }
    
    // Create a project
    printf("Creating new project...\n");
    if (mufiz_pm_new("demo-project") != MUFIZ_OK) {
        fprintf(stderr, "Failed to create project\n");
        goto cleanup;
    }
    
    // Add a dependency
    printf("Adding dependency...\n");
    mufiz_pm_add_dependency(
        "utils",
        "https://github.com/example/mufiz-utils",
        "v1.0.0"
    );
    
    // Format some code
    const char *messy = "var x=1+2;var y=3+4;";
    char *clean = mufiz_format_source(messy);
    if (clean) {
        printf("Formatted code:\n%s\n", clean);
        mufiz_free_cstring(clean);
    }
    
    // Run code
    uint8_t result = mufiz_interpret(
        "var greeting = \"Hello from MufiZ!\";\n"
        "println(greeting);"
    );
    
    if (result != MUFIZ_INTERPRET_OK) {
        fprintf(stderr, "Interpretation failed\n");
        goto cleanup;
    }
    
    // Check for memory leaks
    if (mufiz_has_memory_leaks()) {
        printf("Warning: Memory leaks detected!\n");
        mufiz_print_memory_stats();
    }
    
cleanup:
    mufiz_deinit();
    return EXIT_SUCCESS;
}
```

---

## Language Bindings

### Python (via ctypes)

```python
import ctypes
import os

# Load the library
mufiz = ctypes.CDLL('./zig-out/lib/libmufiz.so')

# Define function signatures
mufiz.mufiz_init.argtypes = [ctypes.c_bool, ctypes.c_bool, ctypes.c_bool]
mufiz.mufiz_init.restype = ctypes.c_int32

mufiz.mufiz_interpret.argtypes = [ctypes.c_char_p]
mufiz.mufiz_interpret.restype = ctypes.c_uint8

mufiz.mufiz_deinit.argtypes = []
mufiz.mufiz_deinit.restype = None

# Initialize
if mufiz.mufiz_init(False, False, False) != 0:
    raise RuntimeError("Failed to initialize MufiZ")

try:
    # Run code
    code = b"println('Hello from Python!');"
    result = mufiz.mufiz_interpret(code)
    
    if result != 0:
        print(f"Execution failed with code: {result}")
finally:
    # Cleanup
    mufiz.mufiz_deinit()
```

---

### Rust (via FFI)

```rust
use std::ffi::CString;
use std::os::raw::{c_char, c_int};

#[link(name = "mufiz")]
extern "C" {
    fn mufiz_init(leak: bool, track: bool, safety: bool) -> c_int;
    fn mufiz_deinit();
    fn mufiz_interpret(source: *const c_char) -> u8;
}

fn main() {
    unsafe {
        if mufiz_init(false, false, false) != 0 {
            eprintln!("Failed to initialize MufiZ");
            return;
        }

        let code = CString::new("println(\"Hello from Rust!\");").unwrap();
        let result = mufiz_interpret(code.as_ptr());

        if result != 0 {
            eprintln!("Execution failed");
        }

        mufiz_deinit();
    }
}
```

---

## Best Practices

### Memory Management

1. **Always call deinit()**: Use `defer` in Zig or RAII in C++
2. **Free returned strings**: Use `mufiz_free_cstring()` for C strings
3. **Enable leak detection** in development:
   ```zig
   try mufiz.init(.{ .enable_leak_detection = true });
   ```

### Error Handling

1. **Check return values**: Always check error codes
2. **Use proper cleanup**: Ensure cleanup runs even on errors
3. **Log errors**: Provide meaningful error messages

### Thread Safety

**Current Status:** MufiZ is **NOT** thread-safe.

- Use one instance per thread, or
- Implement external synchronization

**Future:** Thread-safe API planned for v0.12.0

---

## Performance Considerations

### Initialization Overhead

- ~1-2ms on modern hardware
- Initialize once, reuse for multiple interpretations

### Interpretation Performance

- ~10-50x slower than native code (typical for interpreters)
- Optimized for developer productivity, not raw speed
- JIT compilation planned for future releases

### Memory Usage

- Base: ~2-5 MB
- Per script: ~100-500 KB
- Enable tracking to monitor usage

---

## Troubleshooting

### Library Not Found

**Linux/macOS:**
```bash
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:./zig-out/lib
```

**Windows:**
Add `zig-out\lib` to PATH

### Symbol Not Found

Ensure you're linking against the correct library:
```bash
nm -D libmufiz.so | grep mufiz_
```

### Crashes on Init

Check Zig version compatibility:
- Requires Zig 0.15.2+
- Rebuild if Zig version changed

---

## Resources

- **GitHub**: https://github.com/Mustafif/MufiZ
- **Documentation**: https://mufi-lang.mokareads.org
- **Examples**: See `examples/` directory
- **Header File**: `include/mufiz.h`

---

**Version:** 0.11.0+  
**Last Updated:** 2024  
**License:** MIT