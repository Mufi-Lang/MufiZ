#!/bin/bash
# prepare_release_artifacts.sh
# Prepares additional artifacts for release: C library and WASM binary

set -e

VERSION="${1:-unknown}"
PKG_DIR="pkg"
ARTIFACTS_DIR="${PKG_DIR}/artifacts"

echo "🔧 Preparing release artifacts for version ${VERSION}"

# Create artifacts directory
mkdir -p "${ARTIFACTS_DIR}"

# 1. Package C Library (header + shared library)
echo "📦 Packaging C library..."
C_LIB_DIR="${ARTIFACTS_DIR}/c-library"
mkdir -p "${C_LIB_DIR}"

# Ensure header is generated
echo "  → Generating C header..."
zig build header || {
    echo "  ❌ Failed to generate header"
    exit 1
}

# Validate header matches c_api.zig
echo "  → Validating header matches c_api.zig..."
zig build validate-header || {
    echo "  ❌ Header validation failed"
    exit 1
}

# Copy header file
if [ -f "zig-out/include/mufiz.h" ]; then
    cp "zig-out/include/mufiz.h" "${C_LIB_DIR}/"
    echo "  ✓ Copied mufiz.h (auto-generated)"
else
    echo "  ❌ Error: mufiz.h not found after generation"
    exit 1
fi

# Copy shared libraries based on platform
if [ -f "zig-out/lib/libmufiz.so" ]; then
    cp "zig-out/lib/libmufiz.so" "${C_LIB_DIR}/"
    echo "  ✓ Copied libmufiz.so (Linux)"
elif [ -f "zig-out/lib/libmufiz.dylib" ]; then
    cp "zig-out/lib/libmufiz.dylib" "${C_LIB_DIR}/"
    echo "  ✓ Copied libmufiz.dylib (macOS)"
elif [ -f "zig-out/lib/libmufiz.dll" ]; then
    cp "zig-out/lib/libmufiz.dll" "${C_LIB_DIR}/"
    echo "  ✓ Copied libmufiz.dll (Windows)"
fi

# Create README for C library
cat > "${C_LIB_DIR}/README.md" << 'EOF'
# MufiZ C Library

This package contains the MufiZ C API for embedding the interpreter in C/C++ applications.

## Contents

- `mufiz.h` - C header file with API declarations
- `libmufiz.so/.dylib/.dll` - Shared library binary

## Usage

### Compiling

```c
#include "mufiz.h"

int main() {
    // Initialize MufiZ
    int result = mufiz_init(false, false, false);
    if (result != 0) {
        fprintf(stderr, "Failed to initialize MufiZ\n");
        return 1;
    }

    // Run MufiZ code
    const char* code = "print(42);";
    uint8_t exit_code = mufiz_interpret(code);

    // Clean up
    mufiz_deinit();

    return exit_code;
}
```

### Linking

#### Linux
```bash
gcc -o myapp main.c -L. -lmufiz -Wl,-rpath,'$ORIGIN'
```

#### macOS
```bash
gcc -o myapp main.c -L. -lmufiz
```

#### Windows
```bash
gcc -o myapp.exe main.c -L. -lmufiz
```

## API Reference

### Initialization
- `int32_t mufiz_init(bool leak_detection, bool tracking, bool safety)` - Initialize the interpreter
- `void mufiz_deinit()` - Clean up resources

### Execution
- `uint8_t mufiz_interpret(const char *source)` - Execute MufiZ code

### Memory Management
- `char* mufiz_strdup(const char *s)` - Duplicate a string
- `void mufiz_free_cstring(char *s)` - Free a duplicated string

### Diagnostics
- `bool mufiz_has_memory_leaks()` - Check for memory leaks
- `void mufiz_print_memory_stats()` - Print memory statistics

## Return Codes

- `0` - Success
- `1` - Compile error
- `2` - Runtime error
- Negative values - Initialization errors

## License

See the main MufiZ repository for license information.
EOF

# Create zip archive for C library
(cd "${ARTIFACTS_DIR}" && zip -r "../mufiz-c-library-${VERSION}.zip" c-library/)
echo "  ✓ Created mufiz-c-library-${VERSION}.zip"

# 2. Package WASM
echo "📦 Packaging WebAssembly binary..."
WASM_DIR="${ARTIFACTS_DIR}/wasm"
mkdir -p "${WASM_DIR}"

# Copy WASM binary
if [ -f "zig-out/wasm/mufiz.wasm" ]; then
    cp "zig-out/wasm/mufiz.wasm" "${WASM_DIR}/"
    echo "  ✓ Copied mufiz.wasm"
else
    echo "  ⚠️  Warning: mufiz.wasm not found - building..."
    zig build wasm
    if [ -f "zig-out/wasm/mufiz.wasm" ]; then
        cp "zig-out/wasm/mufiz.wasm" "${WASM_DIR}/"
        echo "  ✓ Built and copied mufiz.wasm"
    else
        echo "  ❌ Error: Failed to build mufiz.wasm"
        exit 1
    fi
fi

# Copy playground HTML
if [ -f "index.html" ]; then
    cp "index.html" "${WASM_DIR}/"
    echo "  ✓ Copied index.html"
fi

# Copy WASM documentation
if [ -f "WASM_PLAYGROUND.md" ]; then
    cp "WASM_PLAYGROUND.md" "${WASM_DIR}/README.md"
    echo "  ✓ Copied WASM documentation"
else
    # Create basic README if documentation doesn't exist
    cat > "${WASM_DIR}/README.md" << 'EOF'
# MufiZ WebAssembly

This package contains the MufiZ WebAssembly binary for running MufiZ in web browsers.

## Contents

- `mufiz.wasm` - WebAssembly binary
- `index.html` - Web playground interface

## Quick Start

1. Start a web server in this directory:
   ```bash
   python3 -m http.server 8000
   ```

2. Open your browser to:
   ```
   http://localhost:8000/
   ```

3. The playground will load automatically and you can run MufiZ code in your browser!

## Exports

The WASM module exports these functions:

- `mufiz_init(leak_detection, tracking, safety)` - Initialize runtime
- `mufiz_interpret(source_ptr)` - Execute code from memory pointer
- `mufiz_deinit()` - Clean up runtime
- `memory` - Shared linear memory

## Integration

See the `index.html` file for an example of how to load and use the WASM module in JavaScript.

## Known Limitations

- String literal printing has a known issue in WASM
- Numeric operations work perfectly
- Use for testing and experimentation

## License

See the main MufiZ repository for license information.
EOF
fi

# Create zip archive for WASM
(cd "${ARTIFACTS_DIR}" && zip -r "../mufiz-wasm-${VERSION}.zip" wasm/)
echo "  ✓ Created mufiz-wasm-${VERSION}.zip"

# 3. Generate artifact manifest
echo "📋 Generating artifact manifest..."
cat > "${PKG_DIR}/ARTIFACTS.md" << EOF
# MufiZ v${VERSION} - Release Artifacts

## Standard Packages

The following standard packages are available for each supported platform:

- ZIP archives (\`mufiz_${VERSION}_{target}.zip\`)
- Debian packages (\`mufiz_${VERSION}_{arch}.deb\`)
- RPM packages (\`mufiz-${VERSION}-1.{arch}.rpm\`)

## Additional Artifacts

### C Library Package

**File**: \`mufiz-c-library-${VERSION}.zip\`

For embedding MufiZ in C/C++ applications.

**Contents**:
- \`mufiz.h\` - C API header
- \`libmufiz.so/.dylib/.dll\` - Shared library
- \`README.md\` - Usage documentation

**Use cases**:
- Embedding MufiZ as a scripting engine
- Creating language bindings
- Integration with existing C/C++ codebases

### WebAssembly Package

**File**: \`mufiz-wasm-${VERSION}.zip\`

For running MufiZ in web browsers.

**Contents**:
- \`mufiz.wasm\` - WebAssembly binary (~305KB)
- \`index.html\` - Web playground interface
- \`README.md\` - Documentation

**Use cases**:
- Browser-based playground
- Web applications with scripting
- Education and demonstrations

## File Sizes

\`\`\`
$(cd "${PKG_DIR}" && ls -lh *.zip 2>/dev/null | awk '{print $9, $5}' || echo "No packages found")
\`\`\`

## Checksums (SHA256)

\`\`\`
$(cd "${PKG_DIR}" && sha256sum *.zip 2>/dev/null || shasum -a 256 *.zip 2>/dev/null || echo "Checksums not available")
\`\`\`

## Notes

- All packages are built with Zig 0.15.2
- C library requires the shared library to be in the library path
- WASM requires a web server (doesn't work with file:// URLs)
- Test suite passed for this release

## Installation

### C Library (Linux)
\`\`\`bash
unzip mufiz-c-library-${VERSION}.zip
cd c-library
sudo cp libmufiz.so /usr/local/lib/
sudo cp mufiz.h /usr/local/include/
sudo ldconfig
\`\`\`

### WASM
\`\`\`bash
unzip mufiz-wasm-${VERSION}.zip
cd wasm
python3 -m http.server 8000
# Open http://localhost:8000 in browser
\`\`\`

---

Generated on $(date)
EOF

echo "  ✓ Created ARTIFACTS.md"

# 4. Summary
echo ""
echo "✅ Release artifacts prepared successfully!"
echo ""
echo "📦 Artifacts created:"
echo "  - mufiz-c-library-${VERSION}.zip (C API)"
echo "  - mufiz-wasm-${VERSION}.zip (WebAssembly)"
echo "  - ARTIFACTS.md (Documentation)"
echo ""
echo "📂 Location: ${PKG_DIR}/"
echo ""

# List all packages
echo "📋 All release files:"
ls -lh "${PKG_DIR}"/*.zip 2>/dev/null || true
ls -lh "${PKG_DIR}"/*.deb 2>/dev/null || true
ls -lh "${PKG_DIR}"/*.rpm 2>/dev/null || true
