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
```

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

## Related Repositories

- [homebrew-mufi](https://github.com/Mustafif/homebrew-mufi): The official Homebrew Tap for MufiZ.
- [mufi-bucket](https://github.com/Mustafif/mufi-bucket): The official Scoop bucket for MufiZ.
