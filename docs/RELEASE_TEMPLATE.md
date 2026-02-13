# MufiZ v{VERSION} Release

🚀 **New Release Available!**

## 📦 Release Artifacts

This release includes several distribution formats:

### Standard Packages
- **ZIP Archives** - Cross-platform binaries for all supported targets
- **Debian Packages (.deb)** - For Debian/Ubuntu Linux distributions
- **RPM Packages (.rpm)** - For RedHat/Fedora/CentOS distributions

### New: C Library Package
- **mufiz-c-library-{VERSION}.zip** - C API for embedding MufiZ
  - `mufiz.h` - C header file
  - `libmufiz.so/.dylib/.dll` - Shared library
  - Complete API documentation
  - Usage examples

### New: WebAssembly Package
- **mufiz-wasm-{VERSION}.zip** - Run MufiZ in web browsers
  - `mufiz.wasm` - WebAssembly binary (~305KB)
  - `index.html` - Interactive web playground
  - Full WASM documentation
  - No installation required!

## 🎯 What's New

### Features
- {LIST_NEW_FEATURES}

### Improvements
- {LIST_IMPROVEMENTS}

### Bug Fixes
- {LIST_BUG_FIXES}

## 📚 Documentation

- **[C API Guide](C_API_GUIDE.md)** - Complete guide for C/C++ integration
- **[WASM Playground](WASM_PLAYGROUND.md)** - WebAssembly usage documentation
- **[Main Documentation](README.md)** - Language reference and getting started

## 🚀 Quick Start

### Native Binary
```bash
# Download and extract for your platform
unzip mufiz_{VERSION}_{your-target}.zip
cd bin
./mufiz --help
```

### C Library
```bash
unzip mufiz-c-library-{VERSION}.zip
cd c-library
# See README.md for installation instructions
```

### WebAssembly
```bash
unzip mufiz-wasm-{VERSION}.zip
cd wasm
python3 -m http.server 8000
# Open http://localhost:8000 in your browser
```

## 🔧 C API Example

```c
#include <stdio.h>
#include <mufiz.h>

int main() {
    // Initialize
    mufiz_init(false, false, false);
    
    // Execute code
    const char* code = "print(42);";
    uint8_t result = mufiz_interpret(code);
    
    // Cleanup
    mufiz_deinit();
    
    return result;
}
```

Compile with: `gcc -o myapp main.c -lmufiz`

## 🌐 WASM Playground

Try MufiZ directly in your browser! The WASM package includes a full-featured web playground:

- No installation required
- Instant execution
- Perfect for learning and testing
- Works on all modern browsers

**Features:**
- ✅ Numeric operations (full support)
- ✅ Variables and functions
- ✅ Control flow (if/while/for/foreach)
- ✅ Data structures (vectors, hash tables)
- ⚠️ String literals (known issue in WASM)

## 📊 Supported Platforms

### Native Binaries
- Linux (x86_64, x86, aarch64, arm, riscv64, mips*)
- macOS (x86_64, aarch64)
- Windows (x86_64, x86)

### C Library
- Linux (.so)
- macOS (.dylib)
- Windows (.dll)

### WebAssembly
- All browsers with WASM support
- Node.js with WASI support

## 🔐 Checksums

See `ARTIFACTS.md` in the release for SHA256 checksums of all packages.

## ⚙️ Build Information

- **Zig Version:** 0.15.2
- **Optimization:** ReleaseSmall for WASM, ReleaseFast for native
- **Testing:** All test suite tests passed ✅

## 📝 Installation Guide

### Linux (Debian/Ubuntu)
```bash
# Download the .deb package
wget https://github.com/mustafif/MufiZ/releases/download/v{VERSION}/mufiz_{VERSION}_amd64.deb
sudo dpkg -i mufiz_{VERSION}_amd64.deb
```

### Linux (RHEL/Fedora/CentOS)
```bash
# Download the .rpm package
wget https://github.com/mustafif/MufiZ/releases/download/v{VERSION}/mufiz-{VERSION}-1.x86_64.rpm
sudo rpm -i mufiz-{VERSION}-1.x86_64.rpm
```

### macOS
```bash
# Download and extract
unzip mufiz_{VERSION}_aarch64-macos.zip
cd bin
sudo cp mufiz /usr/local/bin/
```

### Windows
```bash
# Download and extract
unzip mufiz_{VERSION}_x86_64-windows.zip
# Add bin directory to PATH
```

## 🛠️ For Developers

### Embedding MufiZ

The C library package makes it easy to embed MufiZ in your applications:

**C/C++:**
```c
#include <mufiz.h>
// See C_API_GUIDE.md for full documentation
```

**Rust:**
```rust
#[link(name = "mufiz")]
extern "C" {
    fn mufiz_init(bool, bool, bool) -> i32;
    fn mufiz_interpret(*const c_char) -> u8;
    fn mufiz_deinit();
}
```

**Python:**
```python
import ctypes
lib = ctypes.CDLL('libmufiz.so')
# See C_API_GUIDE.md for full examples
```

### WebAssembly Integration

Integrate MufiZ WASM into your web apps:

```javascript
const response = await fetch('mufiz.wasm');
const bytes = await response.arrayBuffer();
const wasm = await WebAssembly.instantiate(bytes, imports);

// Initialize
wasm.instance.exports.mufiz_init(0, 0, 0);

// Execute code
const result = wasm.instance.exports.mufiz_interpret(code_ptr);
```

## 🐛 Known Issues

### WASM String Printing
String literals may not print correctly in the WASM build due to memory layout differences. Numeric operations work perfectly. This is being actively investigated.

**Workaround:** Use numeric outputs for critical WASM applications.

## 🔗 Links

- **GitHub Repository:** https://github.com/mustafif/MufiZ
- **Documentation:** https://github.com/mustafif/MufiZ/blob/main/README.md
- **Issue Tracker:** https://github.com/mustafif/MufiZ/issues
- **Discussions:** https://github.com/mustafif/MufiZ/discussions

## 📧 Feedback

We'd love to hear from you! Please:
- Report bugs via [GitHub Issues](https://github.com/mustafif/MufiZ/issues)
- Discuss features in [GitHub Discussions](https://github.com/mustafif/MufiZ/discussions)
- Contribute via Pull Requests

## 🙏 Acknowledgments

Thank you to all contributors and users who helped make this release possible!

## 📄 License

MufiZ is released under {LICENSE}. See LICENSE file for details.

---

**Download Now:** [MufiZ v{VERSION}](https://github.com/mustafif/MufiZ/releases/tag/v{VERSION})