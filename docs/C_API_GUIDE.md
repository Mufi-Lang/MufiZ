# MufiZ C API Guide

This guide explains how to embed the MufiZ interpreter in your C/C++ applications using the C API.

## Table of Contents

- [Installation](#installation)
- [Quick Start](#quick-start)
- [API Reference](#api-reference)
- [Examples](#examples)
- [Building and Linking](#building-and-linking)
- [Error Handling](#error-handling)
- [Memory Management](#memory-management)
- [Advanced Usage](#advanced-usage)
- [Troubleshooting](#troubleshooting)

## Installation

### From Release Package

1. Download the C library package from the releases page:
   ```bash
   wget https://github.com/mustafif/MufiZ/releases/download/vX.X.X/mufiz-c-library-X.X.X.zip
   unzip mufiz-c-library-X.X.X.zip
   cd c-library
   ```

2. Install the library and header:

   **Linux:**
   ```bash
   sudo cp libmufiz.so /usr/local/lib/
   sudo cp mufiz.h /usr/local/include/
   sudo ldconfig
   ```

   **macOS:**
   ```bash
   sudo cp libmufiz.dylib /usr/local/lib/
   sudo cp mufiz.h /usr/local/include/
   ```

   **Windows:**
   ```cmd
   copy libmufiz.dll C:\Windows\System32\
   copy mufiz.h C:\Program Files\MufiZ\include\
   ```

### Building from Source

```bash
git clone https://github.com/mustafif/MufiZ.git
cd MufiZ
zig build
# Library will be in zig-out/lib/
# Header will be in zig-out/include/
```

## Quick Start

Here's a minimal example that runs MufiZ code from C:

```c
#include <stdio.h>
#include <mufiz.h>

int main() {
    // Initialize the interpreter
    int32_t init_result = mufiz_init(false, false, false);
    if (init_result != 0) {
        fprintf(stderr, "Failed to initialize MufiZ: %d\n", init_result);
        return 1;
    }

    // Run some MufiZ code
    const char* code = "print(42 + 58);";
    uint8_t exit_code = mufiz_interpret(code);

    // Clean up
    mufiz_deinit();

    return exit_code;
}
```

Compile and run:
```bash
gcc -o example example.c -lmufiz
./example
```

Output:
```
100
```

## API Reference

### Initialization and Cleanup

#### `mufiz_init`

```c
int32_t mufiz_init(bool enable_leak_detection, 
                   bool enable_tracking, 
                   bool enable_safety);
```

Initialize the MufiZ interpreter.

**Parameters:**
- `enable_leak_detection` - Enable memory leak detection
- `enable_tracking` - Enable object tracking
- `enable_safety` - Enable additional safety checks

**Returns:**
- `0` (MUFIZ_OK) - Success
- `-1` (MUFIZ_ERR_ALREADY_INITIALIZED) - Already initialized
- `-3` (MUFIZ_ERR_GENERIC) - Generic error

**Example:**
```c
// Basic initialization (recommended for most cases)
int result = mufiz_init(false, false, false);

// Development mode with leak detection
int result = mufiz_init(true, true, true);
```

#### `mufiz_deinit`

```c
void mufiz_deinit(void);
```

Clean up the MufiZ interpreter and free all resources. Safe to call multiple times.

**Example:**
```c
mufiz_deinit();
```

### Code Execution

#### `mufiz_interpret`

```c
uint8_t mufiz_interpret(const char *source);
```

Execute MufiZ source code.

**Parameters:**
- `source` - Null-terminated string containing MufiZ code

**Returns:**
- `0` - Success
- `1` - Compile error (syntax error)
- `2` - Runtime error
- Other values - Internal errors

**Example:**
```c
const char* code = 
    "var x = 10;\n"
    "var y = 20;\n"
    "print(x + y);";

uint8_t result = mufiz_interpret(code);
if (result != 0) {
    fprintf(stderr, "Execution failed with code: %d\n", result);
}
```

### Memory Utilities

#### `mufiz_strdup`

```c
char* mufiz_strdup(const char *s);
```

Duplicate a string using MufiZ's allocator.

**Parameters:**
- `s` - Null-terminated string to duplicate

**Returns:**
- Pointer to duplicated string, or NULL on failure

**Example:**
```c
char* copy = mufiz_strdup("Hello, World!");
if (copy) {
    printf("%s\n", copy);
    mufiz_free_cstring(copy);
}
```

#### `mufiz_free_cstring`

```c
void mufiz_free_cstring(char *s);
```

Free a string allocated by `mufiz_strdup`.

**Parameters:**
- `s` - String to free (can be NULL)

### Diagnostics

#### `mufiz_has_memory_leaks`

```c
bool mufiz_has_memory_leaks(void);
```

Check if memory leaks were detected (only if leak detection is enabled).

**Returns:**
- `true` if leaks detected
- `false` otherwise

**Example:**
```c
mufiz_init(true, false, false);  // Enable leak detection
mufiz_interpret("var x = 10;");
mufiz_deinit();

if (mufiz_has_memory_leaks()) {
    printf("Memory leaks detected!\n");
}
```

#### `mufiz_print_memory_stats`

```c
void mufiz_print_memory_stats(void);
```

Print memory allocation statistics to stdout.

**Example:**
```c
mufiz_print_memory_stats();
```

### WASM-Specific Functions

These are convenience wrappers for WebAssembly builds:

#### `init_wasm`

```c
void init_wasm(void);
```

Initialize with default settings (all features disabled).

#### `interpret`

```c
uint8_t interpret(const char *source);
```

Alias for `mufiz_interpret`.

#### `deinit_wasm`

```c
void deinit_wasm(void);
```

Alias for `mufiz_deinit`.

## Examples

### Example 1: Simple Calculator

```c
#include <stdio.h>
#include <mufiz.h>

int main() {
    mufiz_init(false, false, false);

    const char* expressions[] = {
        "print(10 + 20);",
        "print(50 - 15);",
        "print(7 * 8);",
        "print(100 / 4);",
        NULL
    };

    for (int i = 0; expressions[i] != NULL; i++) {
        printf("Executing: %s\n", expressions[i]);
        uint8_t result = mufiz_interpret(expressions[i]);
        if (result != 0) {
            fprintf(stderr, "Error: %d\n", result);
        }
    }

    mufiz_deinit();
    return 0;
}
```

### Example 2: Script from File

```c
#include <stdio.h>
#include <stdlib.h>
#include <mufiz.h>

char* read_file(const char* filename) {
    FILE* file = fopen(filename, "r");
    if (!file) return NULL;

    fseek(file, 0, SEEK_END);
    long size = ftell(file);
    fseek(file, 0, SEEK_SET);

    char* buffer = malloc(size + 1);
    fread(buffer, 1, size, file);
    buffer[size] = '\0';

    fclose(file);
    return buffer;
}

int main(int argc, char** argv) {
    if (argc != 2) {
        fprintf(stderr, "Usage: %s <script.mufi>\n", argv[0]);
        return 1;
    }

    char* source = read_file(argv[1]);
    if (!source) {
        fprintf(stderr, "Failed to read file: %s\n", argv[1]);
        return 1;
    }

    mufiz_init(false, false, false);
    uint8_t result = mufiz_interpret(source);
    mufiz_deinit();

    free(source);
    return result;
}
```

### Example 3: REPL (Interactive Shell)

```c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <mufiz.h>

#define MAX_INPUT 1024

int main() {
    char input[MAX_INPUT];

    printf("MufiZ REPL (type 'exit' to quit)\n");
    printf(">>> ");

    mufiz_init(false, false, false);

    while (fgets(input, MAX_INPUT, stdin)) {
        // Remove trailing newline
        input[strcspn(input, "\n")] = 0;

        if (strcmp(input, "exit") == 0) {
            break;
        }

        if (strlen(input) > 0) {
            mufiz_interpret(input);
        }

        printf(">>> ");
    }

    mufiz_deinit();
    printf("\nGoodbye!\n");
    return 0;
}
```

### Example 4: Error Handling

```c
#include <stdio.h>
#include <mufiz.h>

void execute_safe(const char* code) {
    uint8_t result = mufiz_interpret(code);
    
    switch (result) {
        case 0:
            printf("✓ Success\n");
            break;
        case 1:
            printf("✗ Compile error (syntax)\n");
            break;
        case 2:
            printf("✗ Runtime error\n");
            break;
        default:
            printf("✗ Unknown error: %d\n", result);
            break;
    }
}

int main() {
    mufiz_init(false, false, false);

    // Valid code
    execute_safe("print(42);");

    // Syntax error
    execute_safe("print(");

    // Runtime error
    execute_safe("print(undefined_var);");

    mufiz_deinit();
    return 0;
}
```

### Example 5: Multi-threaded Usage (ADVANCED)

**Note:** MufiZ is not thread-safe by default. For multi-threaded applications, you need separate interpreter instances per thread.

```c
#include <stdio.h>
#include <pthread.h>
#include <mufiz.h>

void* worker_thread(void* arg) {
    int thread_id = *(int*)arg;
    
    // Each thread gets its own interpreter instance
    mufiz_init(false, false, false);
    
    char code[128];
    snprintf(code, sizeof(code), "print(\"Thread %d: \" + %d);", 
             thread_id, thread_id * 10);
    
    mufiz_interpret(code);
    mufiz_deinit();
    
    return NULL;
}

int main() {
    pthread_t threads[4];
    int thread_ids[4];

    for (int i = 0; i < 4; i++) {
        thread_ids[i] = i;
        pthread_create(&threads[i], NULL, worker_thread, &thread_ids[i]);
    }

    for (int i = 0; i < 4; i++) {
        pthread_join(threads[i], NULL);
    }

    return 0;
}
```

## Building and Linking

### GCC/Clang

```bash
# Simple linking
gcc -o myapp main.c -lmufiz

# With optimization
gcc -O2 -o myapp main.c -lmufiz

# Specify library path
gcc -o myapp main.c -L/usr/local/lib -lmufiz

# Static linking
gcc -o myapp main.c -static -lmufiz
```

### CMake

```cmake
cmake_minimum_required(VERSION 3.10)
project(MyApp C)

find_library(MUFIZ_LIB mufiz REQUIRED)
find_path(MUFIZ_INCLUDE mufiz.h REQUIRED)

add_executable(myapp main.c)
target_include_directories(myapp PRIVATE ${MUFIZ_INCLUDE})
target_link_libraries(myapp ${MUFIZ_LIB})
```

### Makefile

```makefile
CC = gcc
CFLAGS = -Wall -O2
LDFLAGS = -lmufiz

myapp: main.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

clean:
	rm -f myapp
```

### Dynamic Loading (dlopen)

```c
#include <stdio.h>
#include <dlfcn.h>

typedef int32_t (*mufiz_init_fn)(bool, bool, bool);
typedef uint8_t (*mufiz_interpret_fn)(const char*);
typedef void (*mufiz_deinit_fn)(void);

int main() {
    void* handle = dlopen("libmufiz.so", RTLD_LAZY);
    if (!handle) {
        fprintf(stderr, "Failed to load library: %s\n", dlerror());
        return 1;
    }

    mufiz_init_fn init = dlsym(handle, "mufiz_init");
    mufiz_interpret_fn interpret = dlsym(handle, "mufiz_interpret");
    mufiz_deinit_fn deinit = dlsym(handle, "mufiz_deinit");

    if (!init || !interpret || !deinit) {
        fprintf(stderr, "Failed to load symbols\n");
        dlclose(handle);
        return 1;
    }

    init(false, false, false);
    interpret("print(42);");
    deinit();

    dlclose(handle);
    return 0;
}
```

## Error Handling

### Error Codes

| Code | Constant | Meaning |
|------|----------|---------|
| 0 | MUFIZ_OK | Success |
| -1 | MUFIZ_ERR_ALREADY_INITIALIZED | Already initialized |
| -2 | MUFIZ_ERR_NOT_INITIALIZED | Not initialized |
| -3 | MUFIZ_ERR_GENERIC | Generic error |
| 1 | - | Compile error |
| 2 | - | Runtime error |

### Best Practices

```c
// Always check initialization
int32_t result = mufiz_init(false, false, false);
if (result != 0) {
    handle_init_error(result);
    return 1;
}

// Check execution results
uint8_t exit_code = mufiz_interpret(code);
if (exit_code != 0) {
    handle_runtime_error(exit_code);
}

// Always clean up
mufiz_deinit();
```

## Memory Management

### Rules

1. **Initialization:** Call `mufiz_init()` once before any other API calls
2. **Cleanup:** Call `mufiz_deinit()` when done (idempotent)
3. **String Ownership:** Strings passed to API are not owned by MufiZ
4. **String Duplication:** Use `mufiz_strdup()` and `mufiz_free_cstring()` for MufiZ-allocated strings
5. **Thread Safety:** Not thread-safe; use separate instances per thread

### Memory Leak Detection

```c
// Enable leak detection
mufiz_init(true, false, false);

// Your code here
mufiz_interpret("var x = 10;");

// Check for leaks before cleanup
if (mufiz_has_memory_leaks()) {
    printf("Warning: Memory leaks detected!\n");
    mufiz_print_memory_stats();
}

mufiz_deinit();
```

## Advanced Usage

### Embedding in C++ Applications

```cpp
#include <iostream>
#include <string>
extern "C" {
    #include <mufiz.h>
}

class MufiZInterpreter {
private:
    bool initialized;

public:
    MufiZInterpreter() : initialized(false) {
        if (mufiz_init(false, false, false) == 0) {
            initialized = true;
        }
    }

    ~MufiZInterpreter() {
        if (initialized) {
            mufiz_deinit();
        }
    }

    bool execute(const std::string& code) {
        if (!initialized) return false;
        return mufiz_interpret(code.c_str()) == 0;
    }
};

int main() {
    MufiZInterpreter interp;
    interp.execute("print(42);");
    return 0;
}
```

### Rust FFI

```rust
use std::ffi::CString;
use std::os::raw::c_char;

#[link(name = "mufiz")]
extern "C" {
    fn mufiz_init(leak_detection: bool, tracking: bool, safety: bool) -> i32;
    fn mufiz_interpret(source: *const c_char) -> u8;
    fn mufiz_deinit();
}

fn main() {
    unsafe {
        mufiz_init(false, false, false);
        
        let code = CString::new("print(42);").unwrap();
        let result = mufiz_interpret(code.as_ptr());
        
        println!("Exit code: {}", result);
        
        mufiz_deinit();
    }
}
```

### Python ctypes

```python
import ctypes

# Load library
lib = ctypes.CDLL('libmufiz.so')

# Define function signatures
lib.mufiz_init.argtypes = [ctypes.c_bool, ctypes.c_bool, ctypes.c_bool]
lib.mufiz_init.restype = ctypes.c_int32

lib.mufiz_interpret.argtypes = [ctypes.c_char_p]
lib.mufiz_interpret.restype = ctypes.c_uint8

lib.mufiz_deinit.argtypes = []
lib.mufiz_deinit.restype = None

# Use the API
lib.mufiz_init(False, False, False)
result = lib.mufiz_interpret(b"print(42);")
print(f"Exit code: {result}")
lib.mufiz_deinit()
```

## Troubleshooting

### Library Not Found

**Error:** `error while loading shared libraries: libmufiz.so: cannot open shared object file`

**Solution:**
```bash
# Add to library path
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH

# Or update cache
sudo ldconfig
```

### Undefined Symbols

**Error:** `undefined reference to 'mufiz_init'`

**Solution:**
```bash
# Make sure you're linking the library
gcc main.c -lmufiz

# Check if library exports the symbol
nm -D /usr/local/lib/libmufiz.so | grep mufiz_init
```

### Crashes on macOS

**Error:** Segmentation fault or bus error

**Solution:**
```bash
# On macOS, you may need to set the library path
export DYLD_LIBRARY_PATH=/usr/local/lib:$DYLD_LIBRARY_PATH
```

### Header Not Found

**Error:** `mufiz.h: No such file or directory`

**Solution:**
```bash
# Specify include path
gcc -I/usr/local/include main.c -lmufiz
```

## Resources

- **GitHub Repository:** https://github.com/mustafif/MufiZ
- **Language Documentation:** See main MufiZ docs
- **Examples:** Check the `examples/` directory in the repository
- **Issue Tracker:** https://github.com/mustafif/MufiZ/issues

## License

The MufiZ C API follows the same license as the main MufiZ project. See LICENSE file for details.

---

**Version:** Compatible with MufiZ v0.11.0+  
**Last Updated:** February 2026