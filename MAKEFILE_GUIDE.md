# MufiZ Makefile Guide

A comprehensive Makefile for building, updating, and maintaining the MufiZ compiler and its generated metadata files.

## Quick Start

```bash
# Build the compiler
make build

# Start REPL
make run-repl

# Update all JSON files
make update-all

# Show help
make help
```

## Build Targets

### `make build`
Builds the MufiZ compiler using `zig build`. Creates the binary in `zig-out/bin/mufiz`.

```bash
$ make build
[1/1] Building MufiZ compiler...
Generated header: zig-out/include/mufiz.h
✓ Build complete
```

### `make rebuild`
Cleans and rebuilds the compiler from scratch.

```bash
$ make rebuild
```

### `make clean`
Removes all build artifacts (zig-cache, zig-out, .zig-cache).

```bash
$ make clean
[1/1] Cleaning build artifacts...
✓ Clean complete
```

### `make run-repl`
Starts the interactive REPL shell (builds first if needed).

```bash
$ make run-repl
[1/1] Starting MufiZ REPL...
🚀 Welcome to MufiZ REPL Shell
════════════════════════════════
...
```

### `make test`
Runs the test suite (builds first if needed).

```bash
$ make test
[1/1] Running tests...
```

## JSON Schema Generation Targets

These targets automatically extract metadata from the source code and generate JSON files for IDE support, documentation, and tooling.

### `make update-all`
Updates **all** JSON schema files in one command.

```bash
$ make update-all
[1/3] Extracting standard library functions...
✓ Extracted stdlib functions

[2/3] Generating grammar from source code...
✓ Generated grammar JSON

[3/3] Extracting keywords from source code...
✓ Extracted keywords

════════════════════════════════════════════════════════════
✓ All JSON files updated successfully!
════════════════════════════════════════════════════════════

Updated files:
  • mufiz_stdlib.json    (Standard library functions)
  • mufiz_keywords.json  (Language keywords)
  • lang.json            (Grammar and metadata)
```

### `make update-stdlib`
Extracts all standard library functions and generates `mufiz_stdlib.json`.

**Generated file:** `mufiz_stdlib.json`

Contains organized list of stdlib functions grouped by module:
- io, utils, types, collections, math, matrix, filesystem, time, json, serde, network

```bash
$ make update-stdlib
[1/3] Extracting standard library functions...
✓ Extracted stdlib functions
```

### `make update-grammar`
Generates grammar metadata from the compiler source code.

**Generated files:**
- `lang.json` - Machine-friendly grammar manifest
- `docs/grammar.ebnf` - Human-friendly EBNF grammar

```bash
$ make update-grammar
[2/3] Generating grammar from source code...
✓ Generated grammar JSON
```

### `make update-keywords`
Extracts all keywords and generates `mufiz_keywords.json`.

**Generated file:** `mufiz_keywords.json`

Contains all 31 MufiZ keywords like: if, else, for, while, var, fun, class, etc.

```bash
$ make update-keywords
[3/3] Extracting keywords from source code...
✓ Extracted keywords
```

## Development Targets

### `make fmt`
Formats all Zig source code according to language standards.

```bash
$ make fmt
[1/1] Formatting Zig code...
✓ Format complete
```

### `make lint`
Checks Zig source code for potential issues.

```bash
$ make lint
[1/1] Linting Zig code...
✓ Lint complete
```

### `make check`
Verifies that all required tools (Zig, Python 3) are installed.

```bash
$ make check
Checking required tools...
✓ All required tools found
```

### `make dev-setup`
Sets up the development environment and displays next steps.

```bash
$ make dev-setup
Setting up development environment...
✓ Development environment ready

Next steps:
  1. make build          # Build the compiler
  2. make update-all     # Update JSON files
  3. make run-repl       # Start REPL
```

### `make status`
Shows the current project status including compiler version, JSON file status, and tool availability.

```bash
$ make status
════════════════════════════════════════════════════════════
           MufiZ Project Status
════════════════════════════════════════════════════════════

Build Status:
  ✓ Compiler built: 4.3M

JSON Files Status:
  ✓ mufiz_stdlib.json (148 functions)
  ✓ mufiz_keywords.json (31 keywords)
  ✓ lang.json (Grammar metadata)

Tools Status:
  ✓ Python 3 (3.14.2)
  ✓ Zig (0.15.2)
```

## Installation

### `make install`
Installs MufiZ to the system (requires `zig build install` support).

```bash
$ make install
[1/1] Installing MufiZ...
✓ Installation complete
```

## Quick Aliases

For convenience, single-letter aliases are available:

| Alias | Target | Purpose |
|-------|--------|---------|
| `make b` | `make build` | Build compiler |
| `make r` | `make run-repl` | Start REPL |
| `make u` | `make update-all` | Update all schemas |
| `make uk` | `make update-keywords` | Update keywords only |
| `make ug` | `make update-grammar` | Update grammar only |
| `make us` | `make update-stdlib` | Update stdlib only |

```bash
$ make b         # Quick build
$ make r         # Quick REPL
$ make u         # Quick schema update
```

## Typical Workflow

### Initial Setup
```bash
# 1. Set up development environment
make dev-setup

# 2. Build the compiler
make build

# 3. Update all JSON schemas
make update-all
```

### Daily Development
```bash
# Format code
make fmt

# Build and test
make build
make test

# If you modify source that affects schemas
make update-all
```

### Before Committing
```bash
# Check everything is good
make status
make lint
make test

# Make sure schemas are up-to-date
make update-all
```

### Running REPL
```bash
# Quick start
make r

# Or verbose
make run-repl
```

## Generated Files

### `mufiz_stdlib.json`
**Purpose:** Standard library function catalog

**Contains:**
- Functions organized by module (io, utils, types, etc.)
- Function names and signatures
- Module descriptions

**Used by:** IDE completion, documentation, code generation

### `mufiz_keywords.json`
**Purpose:** Language keywords catalog

**Contains:**
- All 31 MufiZ keywords
- Keyword categorization

**Used by:** Syntax highlighting, IDE support

### `lang.json`
**Purpose:** Grammar and language metadata

**Contains:**
- Token definitions
- Operator precedence
- Grammar rules

**Used by:** Parsers, analyzers, language servers

### `docs/grammar.ebnf`
**Purpose:** Human-readable grammar specification

**Contains:**
- EBNF (Extended Backus-Naur Form) notation
- Language syntax rules

**Used by:** Documentation, language specification

## Troubleshooting

### Build fails with Zig errors
```bash
# Clean and rebuild from scratch
make clean
make build
```

### JSON generation fails
```bash
# Ensure Python 3 is installed
python3 --version

# Manually run the tool
python3 tools/extract_stdlib.py
python3 tools/generate_grammar.py
python3 tools/generate_metadata.py
```

### Tools not found
```bash
# Check what's missing
make check

# Install Zig: https://ziglang.org/download/
# Install Python 3: https://www.python.org/downloads/
```

## Advanced Usage

### Updating only specific schemas
```bash
# Update only stdlib
make us

# Update only grammar
make ug

# Update only keywords
make uk
```

### Running REPL with debugging
```bash
# After building, run directly
./zig-out/bin/mufiz --repl

# Or with custom flags
MUFIZ_DEBUG=1 make r
```

### Custom build configurations
The Makefile uses `zig build` by default. To use custom configurations:

```bash
# Modify the Makefile's build target or run directly
zig build -Doptimize=ReleaseSafe
```

## Contributing

When modifying the MufiZ source code:

1. **If you change keywords:** Run `make update-keywords` to regenerate `mufiz_keywords.json`
2. **If you add stdlib functions:** Run `make update-stdlib` to regenerate `mufiz_stdlib.json`
3. **If you modify grammar:** Run `make update-grammar` to regenerate `lang.json` and `docs/grammar.ebnf`
4. **Before committing:** Run `make update-all` to ensure everything is in sync

## Performance Notes

- **`make build`**: ~5-30 seconds depending on system
- **`make update-stdlib`**: ~1-2 seconds
- **`make update-grammar`**: ~1-2 seconds
- **`make update-keywords`**: ~1-2 seconds
- **`make update-all`**: ~5-10 seconds total

## See Also

- [TYPE_REFERENCE.md](TYPE_REFERENCE.md) - MufiZ type system reference
- [BUILD.md](build.zig.zon) - Zig build configuration
- [README.md](README.md) - Project overview
