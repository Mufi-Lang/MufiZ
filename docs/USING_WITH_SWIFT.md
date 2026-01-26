MufiZ/docs/USING_WITH_SWIFT.md#L1-240
# Using MufiZ from Swift

This document shows practical steps to build the MufiZ library as a *dynamic/shared* library and use it from Swift (Xcode or Swift Package Manager). The repository already contains:

- Zig-side C-compatible wrapper: `src/c_api.zig`
- Public C header for the wrappers: `include/mufiz.h`
- A build step that emits a dynamic library artifact (macOS: `libmufiz.dylib`) when you run the project build.

Keep in mind:
- The exported C API is intentionally tiny and C-friendly: `mufiz_init`, `mufiz_deinit`, `mufiz_interpret`, etc.
- The header `include/mufiz.h` declares the functions and convenience helpers.

---

## Quick start (recommended)

1. Build the project (this builds the shared library and other artifacts):

```/dev/null/BUILD.md#L1-6
cd MufiZ
# Recommended: build optimized for release
zig build -Doptimize=ReleaseFast
```

2. Locate the shared library and header (examples):

```/dev/null/BUILD.md#L7-12
# Find the produced shared library (macOS -> .dylib)
find zig-out -type f -name "libmufiz.*"

# The public header lives in the repo:
ls include/mufiz.h
```

Notes:
- The build script also installs `include/mufiz.h` when you run `zig build install` (to an install prefix). For local dev you can point your Swift/Xcode project at `MufiZ/include` directly.

---

## How the C API maps to Swift types

The main exported functions (from `include/mufiz.h`) are:

- `int32_t mufiz_init(bool enable_leak_detection, bool enable_tracking, bool enable_safety);`
- `void mufiz_deinit(void);`
- `uint8_t mufiz_interpret(const char *source);`
- `bool mufiz_has_memory_leaks(void);`
- `void mufiz_print_memory_stats(void);`
- `char *mufiz_strdup(const char *s);`
- `void mufiz_free_cstring(char *s);`

Swift type mapping (rough):

- `int32_t` -> `Int32`
- `uint8_t` -> `UInt8`
- `const char *` -> `UnsafePointer<CChar>` (Swift `String` is commonly bridged; prefer `.withCString` to be explicit)
- `bool` -> `Bool`

Example call pattern:

```/dev/null/example.swift#L1-20
import Foundation

// Initialize
guard mufiz_init(true, true, true) == 0 else {
    fatalError("mufiz_init failed")
}
defer { mufiz_deinit() }

// Interpret code (use withCString for safety)
"print(\"Hello from MufiZ\")".withCString { cstr in
    let rc = mufiz_interpret(cstr)
    if rc != 0 {
        print("interpret returned code \(rc)")
    }
}
```

---

## Xcode integration (Bridging Header)

Steps:

1. Add `mufiz.h` to your project or point to it via Header Search Paths:
   - Build Settings → Header Search Paths → add the path to `MufiZ/include` (e.g. `$(PROJECT_DIR)/../MufiZ/include`).

2. Add a bridging header file (if you don't have one already), e.g. `YourApp-Bridging-Header.h`:

```/dev/null/YourApp-Bridging-Header.h#L1-3
#import "mufiz.h"
```

3. Link the binary:
   - Add the built library `libmufiz.dylib` to **Link Binary With Libraries** and set **Embed & Sign** (or **Do Not Embed** if you install the dylib system-wide).
   - Make sure the dylib is copied into the app's runtime bundle (e.g. into `Frameworks/`) or set an appropriate runpath so it's discoverable at runtime.

4. Ensure the run-time search path includes `@executable_path/../Frameworks` (set in Build Settings → Runpath Search Paths).

5. Use the Swift snippet above to call the C API directly from Swift.

Troubleshooting tips:
- If you get `Library not loaded: ...` at runtime, check Runpath Search Paths / embedding.
- If you get undefined symbol errors, ensure the library you linked is the same architecture (e.g. arm64 vs x86_64).

---

## Swift Package Manager (SPM) integration

Two common options:

### A) System library (recommended if you install `libmufiz` system-wide)

1. Create `Clibs/mufiz/include/mufiz.h` (or add `include` to your package):
2. Provide a `module.modulemap`:

```/dev/null/Clibs/mufiz/module.modulemap#L1-6
module mufiz [system] {
    header "mufiz.h"
    link "mufiz"
    export *
}
```

3. Add a system library target in `Package.swift`:

```/dev/null/Package.swift#L1-20
// Example snippet
.systemLibrary(
    name: "mufiz"
),
```

4. Ensure at runtime the `libmufiz.dylib` is on the library search path (install to `/usr/local/lib`, or set `LIBRARY_PATH` appropriately on Linux, or embed the dylib in your product bundle on macOS).

### B) Add a binary target (xcframework)
- Build an `.xcframework` for macOS/iOS and add it as a `binaryTarget` in `Package.swift`. This approach packages the prebuilt library for SPM consumption.

---

## Common pitfalls & debugging

- Architecture mismatch:
  - Check binary arch: `file libmufiz.dylib` (macOS) or `lipo -info`.
  - Build for correct target: `zig build -Dtarget=aarch64-macos` or `-Dtarget=x86_64-macos`.

- Missing header: make sure Xcode/SWIFT compiler has `Header Search Paths` including `MufiZ/include`.

- Symbols not exported:
  - Confirm exported names with `nm -gU libmufiz.dylib | grep mufiz` (macOS) or `nm -D libmufiz.so` (Linux).
  - `export` in Zig and `export` functions in `src/c_api.zig` ensure C ABI availability.

- Runtime load errors:
  - Check `otool -L libmufiz.dylib` (macOS) to see `install_name` and dependencies.
  - Use proper embedding (Embed & Sign) or set `@rpath`/`Runpath Search Paths`.

- Swift bridging of macros:
  - `#define` macros may or may not show up as Swift constants depending on how you import; you can test or use explicit numeric checks (e.g. `== 0` for success codes), or add typed `static const` or `enum` constants in the header if you want guaranteed Swift-visible constants.

---

## Extra tips

- Quick one-off shared library build:
```/dev/null/BUILD.md#L13-16
# If you want to build just the wrapper as a shared lib (one-off)
# (may require you to ensure other dependencies are visible to the compiler)
zig build-lib src/c_api.zig -dynamic -O ReleaseFast
```
- Inspect exported C header: `include/mufiz.h` — it documents the small C surface you can call from Swift.
- If you plan to ship the library to others, consider producing an `.xcframework` or installing header + dylib to standard locations and publishing a small SPM package with a `systemLibrary` module.

---

If you'd like, I can:
- Add a sample Xcode starter project (or Swift Package example) to this repo that demonstrates building, embedding the dylib, and calling the API from Swift.
- Add a small Swift test target that exercises `mufiz_init`, `mufiz_interpret`, and `mufiz_deinit`.

Tell me which option you'd prefer and I can produce the scaffolding and examples.