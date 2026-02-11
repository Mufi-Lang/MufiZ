# ZON Migration Guide

## Overview

MufiZ Package Manager has migrated from TOML to ZON (Zig Object Notation) for project configuration files. This change brings better integration with the Zig ecosystem and provides a more native experience for Zig developers.

## What Changed

### File Format

**Before (TOML):**
```toml
[package]
name = "my-project"
version = "0.1.0"
authors = []
description = "A MufiZ project"
license = "MIT"

[project]
entry_point = "src/main.mufi"
```

**After (ZON):**
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

### File Name

- **Old:** `mufi.toml`
- **New:** `mufi.zon`

## What is ZON?

ZON (Zig Object Notation) is a textual file format that is a subset of Zig's syntax. It provides:

- **Simplicity**: Easy to read and write
- **Native Support**: Built into Zig's standard library
- **Type Safety**: Structured data with compile-time validation
- **Consistency**: Same format used by Zig's build system

### ZON Features

ZON supports the following Zig primitives:
- Boolean literals (`true`, `false`)
- Number literals (including `nan` and `inf`)
- Character literals
- Enum literals
- `null` literals
- String literals
- Multiline string literals
- Anonymous struct literals
- Anonymous tuple literals

## Migration Steps

### For Existing Projects

If you have an existing project with `mufi.toml`, you can manually migrate to `mufi.zon`:

1. **Backup your current file:**
   ```bash
   cp mufi.toml mufi.toml.backup
   ```

2. **Create `mufi.zon` with the new format:**
   ```zon
   .{
       .package = .{
           .name = "your-project-name",
           .version = "0.1.0",
           .authors = .{},
           .description = "Your project description",
           .license = "MIT",
       },
       .project = .{
           .entry_point = "src/main.mufi",
       },
   }
   ```

3. **Update the values** to match your project's metadata from `mufi.toml`

4. **Test the migration:**
   ```bash
   mufiz pm info
   mufiz pm run
   ```

5. **Remove the old file** once confirmed:
   ```bash
   rm mufi.toml
   ```

### For New Projects

New projects created with `mufiz pm new` or `mufiz pm init` will automatically use the ZON format:

```bash
# Create a new project
mufiz pm new my-awesome-project

# Or initialize in current directory
mufiz pm init my-project
```

## ZON Structure Reference

### Required Fields

```zon
.{
    .package = .{
        .name = "project-name",           // String: Project identifier
        .version = "0.1.0",               // String: Semantic version
        .authors = .{},                   // Array: List of author names
        .description = "Description",     // String: Project description
        .license = "MIT",                 // String: License identifier
    },
    .project = .{
        .entry_point = "src/main.mufi",  // String: Main file path
    },
}
```

### Field Types

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `package.name` | String | Project name (kebab-case recommended) | `"my-project"` |
| `package.version` | String | Semantic versioning (major.minor.patch) | `"1.2.3"` |
| `package.authors` | Array of Strings | List of project authors | `.{"Alice", "Bob"}` |
| `package.description` | String | Short project description | `"A web server"` |
| `package.license` | String | SPDX license identifier | `"MIT"`, `"Apache-2.0"` |
| `project.entry_point` | String | Path to main MufiZ file | `"src/main.mufi"` |

### Example with Multiple Authors

```zon
.{
    .package = .{
        .name = "advanced-project",
        .version = "2.5.1",
        .authors = .{
            "Jane Developer",
            "John Contributor",
            "Team MufiZ",
        },
        .description = "An advanced MufiZ application with multiple features",
        .license = "Apache-2.0",
    },
    .project = .{
        .entry_point = "src/main.mufi",
    },
}
```

## Benefits of ZON

1. **Native Integration**: ZON is Zig's native format, used by `build.zig.zon`
2. **Better Tooling**: Zig's parser provides better error messages and validation
3. **Consistency**: One format across the entire Zig/MufiZ ecosystem
4. **Extensibility**: Easy to add new fields and nested structures
5. **Type Safety**: Compile-time validation ensures correctness

## Common Issues and Solutions

### Syntax Errors

**Problem:** Parse errors when reading `mufi.zon`

**Solution:** Check for common syntax issues:
- Missing commas between fields
- Missing dots before field names (`.field_name`)
- Missing dots before struct literals (`.{`)
- Incorrect string escaping

**Example of Correct Syntax:**
```zon
.{
    .package = .{        // Note the dots
        .name = "test",  // Comma after each field
        .version = "1.0.0",
    },                   // Trailing comma is allowed
}
```

### Empty Arrays

**Problem:** How to represent empty lists (e.g., no authors)

**Solution:** Use `.{}` for empty tuples/arrays:
```zon
.authors = .{},  // Empty list
```

### Special Characters in Strings

**Problem:** String contains quotes or special characters

**Solution:** Use proper escaping:
```zon
.description = "A \"quoted\" string",  // Escaped quotes
```

Or multiline strings:
```zon
.description =
    \\A long description
    \\that spans multiple lines
    \\and doesn't need escaping
,
```

## Package Manager Commands

All package manager commands now work with ZON files:

### Create New Project
```bash
mufiz pm new my-project
```
Creates a new directory with `mufi.zon`

### Initialize Current Directory
```bash
mufiz pm init my-project
```
Creates `mufi.zon` in the current directory

### Display Project Info
```bash
mufiz pm info
```
Reads and displays the contents of `mufi.zon`

### Run Project
```bash
mufiz pm run
```
Executes the entry point specified in `mufi.zon`

### Help
```bash
mufiz pm help
```
Shows package manager usage information

## Future Enhancements

The ZON format will enable future features:

1. **Dependencies**: Proper dependency management with version constraints
   ```zon
   .dependencies = .{
       .http = .{
           .url = "https://github.com/user/mufiz-http",
           .version = "1.0.0",
       },
   },
   ```

2. **Build Configuration**: Custom build settings
   ```zon
   .build = .{
       .target = "wasm32-wasi",
       .optimize = .ReleaseFast,
   },
   ```

3. **Testing Configuration**: Test-specific settings
   ```zon
   .test = .{
       .directory = "tests",
       .timeout = 30,
   },
   ```

4. **Scripts**: Custom commands and scripts
   ```zon
   .scripts = .{
       .build = "zig build",
       .test = "zig build test",
   },
   ```

## Resources

- [Zig ZON Documentation](https://ziglang.org/documentation/master/#zon)
- [MufiZ Documentation](https://github.com/mufiz-lang/mufiz)
- [Semantic Versioning](https://semver.org/)
- [SPDX License List](https://spdx.org/licenses/)

## Feedback

If you encounter any issues with the ZON migration or have suggestions for improvements, please open an issue on the [MufiZ GitHub repository](https://github.com/mufiz-lang/mufiz/issues).

---

**Last Updated:** 2024 (MufiZ v0.11.0)