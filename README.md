# MufiZ

> This project uses the Zig `v0.14.0`

🌐 [mufi-lang.mokareads.org](https://mufi-lang.mokareads.org)

This project aims to integrate the Mufi-Lang compiler with the Zig language by using the
Zig Build system. We hope to integrate more features with this language and see how nicely
we can utilize both languages in unity. The advantage of Zig's Build system is easy cross-compatibility and caching, and as we integrate more,
we can ensure more memory safety.

## Project Structure

MufiZ is structured as both a **library** and an **executable**:

- **Library (`libmufiz`)**: Core compiler and interpreter functionality that can be imported by other Zig projects
- **Executable (`mufiz`)**: Command-line interface for running MufiZ scripts and the REPL

### Using MufiZ as a Library

You can integrate MufiZ into your Zig project by importing it as a library:

```zig
const std = @import("std");
const mufiz = @import("mufiz");

pub fn main() !void {
    // Initialize the MufiZ library
    try mufiz.init(.{
        .enable_leak_detection = true,
        .enable_tracking = true,
        .enable_safety = true,
    });
    defer mufiz.deinit();
    
    // Interpret some MufiZ code
    const result = mufiz.interpret("var x = 42; print(x);");
    
    if (result == mufiz.OK) {
        std.debug.print("Execution successful!\n", .{});
    }
}
```

#### Library API

The library exposes the following key functions:

- `init(options: InitOptions) !void` - Initialize the MufiZ library
- `deinit()` - Clean up and deinitialize the library
- `interpret(source: []const u8) u8` - Interpret MufiZ source code
- `startRepl() !void` - Start the interactive REPL
- `Runner` - Type for running MufiZ scripts from files
- `getAllocator() std.mem.Allocator` - Get the global allocator

Modules available:
- `vm` - Virtual machine internals
- `compiler` - Compiler internals  
- `value` - Value representation
- `object` - Object system
- `chunk` - Bytecode chunks
- `memory` - Memory management
- `stdlib` - Standard library functions

### Building

```shell
# Build both the library and executable
zig build

# Build only the library
zig build install-lib

# Build only the executable  
zig build install

# Run the executable
zig build run

# Run tests
zig build test

# Build and run the library usage example
zig build run-example
```

See `examples/library_usage.zig` for a complete example of using MufiZ as a library.

## C Library / FFI

MufiZ can also be embedded in C/C++ applications via the C API (`libmufiz`). The shared library and header file are generated during the build process.

### Building the C Library

```bash
zig build
# Output: zig-out/lib/libmufiz.{so,dylib,dll}
#         zig-out/include/mufiz.h
```

### Platform-Specific Libraries

The build system automatically generates the correct library format for your platform:
- **macOS**: `libmufiz.dylib` (dynamic library)
- **Linux**: `libmufiz.so` (shared object)
- **Windows**: `libmufiz.dll` (dynamic link library)

### C API Example

```c
#include "mufiz.h"
#include <stdio.h>

int main() {
    // Initialize MufiZ
    if (mufiz_init(false, false, false) != 0) {
        fprintf(stderr, "Failed to initialize MufiZ\n");
        return 1;
    }

    // Run MufiZ code
    const char* code = "var x = 42; print(x);";
    uint8_t result = mufiz_interpret(code);

    // Clean up
    mufiz_deinit();

    return result;
}
```

Compile with:
```bash
# Linux
gcc -o myapp main.c -L./zig-out/lib -lmufiz -Wl,-rpath,'$ORIGIN'

# macOS
gcc -o myapp main.c -L./zig-out/lib -lmufiz

# Windows
gcc -o myapp.exe main.c -L./zig-out/lib -lmufiz
```

### Release Artifacts

🍎 **Important**: Pre-built C library releases are **macOS ARM only** (built on Apple Silicon, includes `libmufiz.dylib` for ARM64).

For Intel Mac, Linux, and Windows users, you must build from source to get the platform-specific library:
- Intel Mac users will get `libmufiz.dylib` (x86_64)
- Linux users will get `libmufiz.so`
- Windows users will get `libmufiz.dll`

The header file (`mufiz.h`) is platform-independent and can be used on all platforms.

## Recent Updates

- **Library/Executable Split**: MufiZ is now structured as a reusable library with a separate executable interface
- **Improved REPL Experience**: The interactive shell now provides a cleaner experience by not echoing characters while typing
- **Hash Table Syntax Change**: Hash tables now use `#{}` syntax to differentiate from float vectors (`{}`)

## Data Structures Syntax:

- **Float Vectors**: Use curly braces `{}` - Example: `var vector = {1, 2, 3, 4, 5}`
- **Hash Tables**: Use hash-prefixed curly braces `#{}` - Example: `var dict = #{"key": "value", "name": "John"}`

## Usage:

```shell
$ mufiz --help
    -h, --help
            Displays this help and exit.

    -v, --version
            Prints the version and codename.

    -r, --run <str>
            Runs a Mufi Script

    -l, --link <str>
            Link another Mufi Script when interpreting

        --repl
            Runs Mufi Repl system
```

## Package Manager

MufiZ includes a built-in package manager for creating and managing projects. Projects use **ZON (Zig Object Notation)** format for configuration, aligning with the Zig ecosystem.

### Quick Start

```shell
# Create a new project
$ mufiz pm new my-project
$ cd my-project

# Or initialize in current directory
$ mufiz pm init my-project

# View project information
$ mufiz pm info

# Run your project
$ mufiz pm run
```

### Project Structure

```
my-project/
├── mufi.zon       # Project metadata (ZON format)
└── src/
    └── main.mufi  # Entry point
```

### Configuration File (mufi.zon)

Projects use ZON format for configuration, which is Zig's native object notation:

```zon
.{
    .package = .{
        .name = "my-project",
        .version = "0.1.0",
        .authors = .{},
        .description = "A MufiZ project",
        .license = "MIT",
    },
    .project = .{
        .entry_point = "src/main.mufi",
    },
}
```

### Why ZON?

- **Native Integration**: Same format as Zig's `build.zig.zon`
- **Type Safety**: Structured data with compile-time validation
- **Consistency**: One format across the entire Zig/MufiZ ecosystem
- **Extensibility**: Easy to add new fields and nested structures

For detailed information about the package manager and ZON format migration, see:
- `docs/ZON_MIGRATION.md` - Migration guide from TOML to ZON
- `docs/PM_ZON_UPDATE_SUMMARY.md` - Complete summary of changes

---

## Goal

> View [MufiZ Project Roadmap](https://github.com/users/Mustafif/projects/1) to see current goals I am currently working on or planning to implement for the current or next versions.

---

## Releases

| Version | Codename                                                                 | Status      |
| ------- | ------------------------------------------------------------------------ | ----------- |
| 0.1.0   | Baloo                                                                    | Archived    |
| 0.2.0   | [Zula](https://github.com/Mustafif/MufiZ/releases/tag/v0.2.0)            | Released    |
| 0.3.0   | [Iris](https://github.com/Mustafif/MufiZ/releases/tag/v0.3.0)            | Released    |
| 0.4.0   | [Voxl](https://github.com/Mustafif/MufiZ/releases/tag/v0.4.0)            | Released    |
| 0.5.0   | [Luna](https://github.com/Mustafif/MufiZ/releases/tag/v0.5.0)            | Released    |
| 0.6.0   | [Mars](https://github.com/Mustafif/MufiZ/releases/tag/v0.6.0)            | Released    |
| 0.7.0   | [Jade](https://github.com/Mustafif/MufiZ/releases/tag/v0.7.0)            | Released    |
| 0.8.0   | [Ruby](https://github.com/Mustafif/MufiZ/releases/tag/v0.8.0)            | Released    |
| 0.9.0   | [Kova](https://github.com/Mustafif/MufiZ/releases/tag/v0.9.0) | Released |
| 0.10.0  | [Echo](https://github.com/Mustafif/MufiZ/releases/tag/v0.10.0) | Latest |

### Release Artifacts

Each release includes:
- **macOS Packages**: `.zip` archives for macOS ARM systems
- **C Library** (`mufiz-c-library-*.zip`): **macOS ARM only** - Contains `libmufiz.dylib` (ARM64) + `mufiz.h`
  - 🍎 Optimized for Apple Silicon (M1/M2/M3/M4)
  - ⚠️ Intel Mac/Linux/Windows users: Build from source with `zig build`
- **WebAssembly** (`mufiz-wasm-*.zip`): Platform-independent WASM binary
- **Documentation**: `ARTIFACTS.md` with checksums and installation instructions

---

## Features

To support various toolchains, we have added the following features to the project, which can be enabled or disabled using the `zig build` command:

- `-Denable_net` - Enables the `net` module for the MufiZ standard library.
- `-Denable_fs` - Enables the `fs` module for the MufiZ standard library.
- `-Dsandbox` - Enables sandbox mode which limits execution to REPL only.

### Echo Release Features (v0.10.0)

- **Enhanced REPL Input**: The interactive shell now features improved input handling with non-echoing input for a cleaner experience
- **Input Visibility**: Commands are displayed after execution to maintain clarity and aid debugging
- **Disabled Echo**: Input characters are no longer echoed back while typing in the REPL, improving readability
- **Simplified Implementation**: Streamlined code for better maintainability and performance
- **Terminal Handling**: Groundwork for native Zig termios operations without C dependencies

### Data Serialization (Serde Interface)

The MufiZ language now includes a comprehensive serialization/deserialization interface supporting multiple data formats:

#### Supported Formats
- **JSON**: Full serialization and deserialization with pretty printing
- **TOML**: Complete implementation with table support and configuration parsing
- **YAML**: Full implementation with flow and block styles, indentation-aware parsing

#### Key Features
- **Format-Agnostic API**: Unified interface for all supported formats
- **Type Safety**: Full support for all MufiZ value types and objects
- **Error Handling**: Comprehensive error reporting with context
- **Auto-Detection**: Automatic format detection based on content
- **Extensible**: Plugin system for adding new formats

#### Usage Examples
```mufi
// Serialize to different formats
let data = #{name: "John", age: 30}
let json = serde_to_json(data)     // {"name":"John","age":30}
let toml = serde_to_toml(data)     // name = "John"\nage = 30
let yaml = serde_to_yaml(data)     // name: John\nage: 30

// Deserialize from strings
let parsed_json = serde_from_json('{"x": 42}')
let parsed_yaml = serde_from_yaml('x: 42')

// Auto-detect format
let format = serde_detect_format(input_string)
let result = serde_deserialize(input_string, format)
```

For detailed documentation, see `docs/serde_interface.md`

### Mathematical Operations

MufiZ provides comprehensive mathematical capabilities for numerical computing:

#### Core Features
- **Standard Math Functions**: Trigonometric, logarithmic, exponential functions
- **Hyperbolic Functions**: sinh, cosh, tanh, and their inverses
- **Vector Operations**: Dot products, norms, vector arithmetic
- **Statistical Functions**: Sum, mean, variance, standard deviation
- **Bitwise Operators**: Efficient bit manipulation with `band`, `bor`, `bxor`, `bnot`, `shl`, `shr`
- **Complex Numbers**: Full support for complex arithmetic
- **Matrix Operations**: Comprehensive linear algebra capabilities

#### Quick Example
```mufi
import math

// Vector operations
let v1 = [1, 2, 3]
let v2 = [4, 5, 6]
let dot_product = dot(v1, v2)    // 32
let magnitude = norm(v1)         // 3.74...

// Statistics
let data = [1, 2, 3, 4, 5]
let average = mean(data)         // 3.0
let deviation = stddev(data)     // 1.58...

// Bitwise operations
let flags = 5 bor 3              // 7 (binary: 0101 | 0011 = 0111)
let shifted = 4 shl 2           // 16 (4 << 2)
```

For comprehensive documentation, see [Mathematical Operations Guide](./docs/math_guide.md)

## Related Repositories

- [homebrew-mufi](https://github.com/Mustafif/homebrew-mufi): The official Homebrew Tap for MufiZ.
- [mufi-bucket](https://github.com/Mustafif/mufi-bucket): The official Scoop bucket for MufiZ.
