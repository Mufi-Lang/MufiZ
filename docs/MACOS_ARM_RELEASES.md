# macOS ARM Release Platform Documentation

## Overview

Starting with the enhanced error diagnostics phase, MufiZ releases now target **macOS ARM (Apple Silicon)** as the primary platform for pre-built C library artifacts.

## Platform Details

### ✅ Supported (Pre-built)

**macOS ARM (Apple Silicon)**
- **Architecture**: ARM64 (aarch64)
- **Chips**: M1, M2, M3, M4 and future Apple Silicon chips
- **Runner**: `macos-14` (GitHub Actions)
- **Library**: `libmufiz.dylib` (ARM64 dynamic library)
- **Header**: `mufiz.h` (platform-independent)

### ⚠️ Requires Building from Source

**Intel Mac (x86_64)**
- Must build with `zig build` to get x86_64 version of `libmufiz.dylib`

**Linux (x86_64 / ARM64)**
- Must build with `zig build` to get `libmufiz.so`

**Windows (x86_64 / ARM64)**
- Must build with `zig build` to get `libmufiz.dll`

## Why macOS ARM?

1. **Developer Platform**: The primary development and testing platform is macOS ARM
2. **Modern Hardware**: Apple Silicon represents the current generation of Mac hardware
3. **Performance**: Native ARM64 builds provide optimal performance on Apple Silicon
4. **GitHub Actions**: macOS-14 runners provide reliable Apple Silicon builds

## Release Artifacts

Each release includes the following artifacts:

### 1. macOS Packages (`mufiz_*.zip`)
- Command-line executable for macOS ARM
- Optimized for Apple Silicon

### 2. C Library (`mufiz-c-library-*.zip`)
Contains:
- `libmufiz.dylib` - ARM64 dynamic library
- `mufiz.h` - C API header (platform-independent)
- `README.md` - Documentation with build instructions for other platforms

**Key Features:**
- Native ARM64 code for M1/M2/M3/M4 Macs
- Direct integration with C/C++ projects
- Full MufiZ interpreter embedding capabilities

### 3. WebAssembly (`mufiz-wasm-*.zip`)
- Platform-independent WASM binary
- Works on all platforms with WebAssembly support
- Includes web playground interface

## Building for Other Platforms

### Intel Mac

```bash
git clone https://github.com/Mustafif/MufiZ
cd MufiZ
zig build
# Output: zig-out/lib/libmufiz.dylib (x86_64)
#         zig-out/include/mufiz.h
```

### Linux

```bash
git clone https://github.com/Mustafif/MufiZ
cd MufiZ
zig build
# Output: zig-out/lib/libmufiz.so
#         zig-out/include/mufiz.h
```

### Windows

```bash
git clone https://github.com/Mustafif/MufiZ
cd MufiZ
zig build
# Output: zig-out/lib/libmufiz.dll
#         zig-out/include/mufiz.h
```

## Installation

### macOS ARM (Apple Silicon) - Pre-built

```bash
# Download from GitHub releases
curl -LO https://github.com/Mustafif/MufiZ/releases/latest/download/mufiz-c-library-*.zip

# Extract
unzip mufiz-c-library-*.zip
cd c-library

# Install system-wide (recommended)
sudo cp libmufiz.dylib /usr/local/lib/
sudo cp mufiz.h /usr/local/include/

# Or use locally
# gcc -o myapp main.c -L. -lmufiz
```

### Other Platforms - Build from Source

```bash
# Clone repository
git clone https://github.com/Mustafif/MufiZ
cd MufiZ

# Ensure Zig 0.15.2+ is installed
# Download from: https://ziglang.org/download/

# Build
zig build

# Libraries are in: zig-out/lib/
# Headers are in: zig-out/include/
```

## C API Example

The C API works identically across all platforms:

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

**Compile on macOS ARM (pre-built):**
```bash
gcc -o myapp main.c -L/usr/local/lib -lmufiz
```

**Compile on Intel Mac (after building):**
```bash
gcc -o myapp main.c -L./zig-out/lib -lmufiz
```

**Compile on Linux (after building):**
```bash
gcc -o myapp main.c -L./zig-out/lib -lmufiz -Wl,-rpath,'$ORIGIN'
```

**Compile on Windows (after building):**
```bash
gcc -o myapp.exe main.c -L./zig-out/lib -lmufiz
```

## GitHub Actions Workflow

The release workflow uses:

```yaml
jobs:
  build-macos:
    name: Create macOS ARM Release
    runs-on: macos-14  # Apple Silicon runner
```

**Key Points:**
- `macos-14` provides Apple Silicon (ARM64) runners
- Native ARM64 compilation without cross-compilation
- Full Zig 0.15.2 support
- Includes all standard library features

## System Requirements

### macOS ARM (Pre-built)
- macOS 12.0 (Monterey) or later
- Apple Silicon chip (M1/M2/M3/M4)
- ARM64 architecture
- No additional dependencies

### Other Platforms (Build from Source)
- Zig 0.15.2 or later
- Platform-specific C compiler (optional, for testing)
- Git for cloning repository

## Checksums & Verification

Each release includes SHA256 checksums in `ARTIFACTS.md`:

```bash
# Download release and verify
shasum -a 256 -c ARTIFACTS.md
```

## FAQs

### Q: Can I use the pre-built library on Intel Mac?
**A:** No, you must build from source for Intel Mac. The pre-built library is ARM64 only.

### Q: Why not provide universal binaries?
**A:** To keep release artifacts simple and focused. Universal binaries are larger and most Mac users now have Apple Silicon. Intel users can easily build from source.

### Q: Will there be Linux/Windows pre-built releases?
**A:** Currently, the focus is on macOS ARM. Users on other platforms can build from source with `zig build`, which is straightforward with Zig's excellent cross-platform support.

### Q: How do I check if I have Apple Silicon or Intel?
**A:** Run in Terminal:
```bash
uname -m
# arm64 = Apple Silicon (use pre-built)
# x86_64 = Intel (build from source)
```

### Q: Can I cross-compile for other platforms?
**A:** Yes! Zig supports cross-compilation:
```bash
# Build for Linux from macOS
zig build -Dtarget=x86_64-linux-gnu

# Build for Windows from macOS
zig build -Dtarget=x86_64-windows-gnu
```

## Support

- **GitHub Issues**: [MufiZ Issues](https://github.com/Mustafif/MufiZ/issues)
- **Documentation**: [MufiZ Docs](https://github.com/Mustafif/MufiZ/tree/main/docs)
- **Build Help**: See `README.md` for detailed build instructions

## Version History

- **v0.10.0+**: macOS ARM (Apple Silicon) releases
- **Pre-v0.10.0**: Linux (Ubuntu) releases

---

*This platform choice reflects the current development environment and provides the best experience for Apple Silicon Mac users. All platforms are equally supported through source builds.*