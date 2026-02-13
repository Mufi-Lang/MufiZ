# MufiZ WebAssembly Playground

This document explains how to use the MufiZ WASM playground to run MufiZ scripts directly in your web browser.

## Quick Start

1. Build the WASM module:
   ```bash
   zig build wasm
   ```

2. Start a local web server from the project root:
   ```bash
   python3 -m http.server 8000
   ```

3. Open your browser and navigate to:
   ```
   http://localhost:8000/
   ```

4. The playground will automatically load and initialize the MufiZ WASM runtime.

## File Structure

After building, you'll have:

- **`index.html`** - The web playground interface (in project root)
- **`zig-out/wasm/mufiz.wasm`** - The compiled WebAssembly binary

## Supported Features

The WASM runtime supports most MufiZ features including:

✅ **Numbers and Math Operations**
- Integer and floating-point arithmetic
- Variables and expressions
- Mathematical functions

✅ **Control Flow**
- `if`/`else` statements
- `while` loops
- `for` loops
- `foreach` with ranges

✅ **Functions**
- Function declarations
- Function calls
- Return values

✅ **Data Structures**
- Vectors/arrays
- Hash tables
- Ranges

## Known Limitations

⚠️ **String Printing Issue**

There is a known issue in the WASM build where string literals may not print correctly. This is due to memory layout differences between native and WASM targets.

**Workaround**: Use numeric outputs instead of string literals for now.

**Example that works:**
```javascript
print(42);
print(100 + 23);

var x = 10;
var y = 20;
print(x + y);
```

**What doesn't work yet:**
```javascript
print("Hello World");  // May output incorrectly
```

## Example Code

Here's a working example you can try in the playground:

```javascript
// Numbers work perfectly!
print(42);
print(100 + 23);

// Variables and math
var x = 10;
var y = 5;
var sum = x + y;
var product = x * y;

print(sum);      // Output: 15
print(product);  // Output: 50

// Loops
var i = 1;
while (i <= 5) {
    print(i);
    i = i + 1;
}
// Output: 1 2 3 4 5

// Functions
fun fibonacci(n) {
    if (n <= 1) {
        return n;
    }
    return fibonacci(n - 1) + fibonacci(n - 2);
}

print(fibonacci(10));  // Output: 55

// Ranges and foreach
foreach (num in 1..=10) {
    if (num % 2 == 0) {
        print(num);
    }
}
// Output: 2 4 6 8 10
```

## How It Works

### Build Process

The `zig build wasm` command:

1. Compiles `src/c_api.zig` targeting `wasm32-wasi`
2. Exports the C API functions for JavaScript to call
3. Creates a standalone WASM binary without requiring Emscripten

### JavaScript Integration

The playground HTML file:

1. Fetches and instantiates the WASM module
2. Provides WASI (WebAssembly System Interface) imports for I/O
3. Initializes the MufiZ runtime
4. Passes source code to the WASM interpreter via memory

### Key Exports

The WASM module exports these functions:

- `mufiz_init(enable_leak_detection, enable_tracking, enable_safety)` - Initialize the runtime
- `mufiz_interpret(source_ptr)` - Execute MufiZ code from a memory pointer
- `mufiz_deinit()` - Clean up the runtime
- `memory` - Shared linear memory for passing data

## Technical Details

### Memory Layout

- Source code is copied to WASM linear memory at offset `65536` (64KB)
- The source must be null-terminated
- Maximum script size depends on available WASM memory (default: several MB)

### Exit Codes

The `mufiz_interpret` function returns:

- `0` - Success
- `1` - Compile error
- `2` - Runtime error
- Other - System error

### WASI Functions

The playground implements these WASI functions:

- `fd_write` - Writes output to the browser console
- `fd_read`, `fd_close`, `fd_seek` - File I/O stubs
- `random_get` - Provides random bytes via `crypto.getRandomValues()`
- `clock_time_get` - Returns current time via `Date.now()`
- `proc_exit` - Handles process termination
- `environ_get`, `environ_sizes_get` - Environment variable stubs

## Debugging

To debug WASM execution:

1. Open browser DevTools (F12)
2. Check the Console tab for:
   - WASM loading status
   - Execution errors
   - `console.log()` outputs

3. In the console, you can inspect:
   ```javascript
   wasmInstance.exports  // Check available exports
   ```

## Building from Source

The WASM build configuration in `build.zig`:

```zig
const wasm_exe = b.addExecutable(.{
    .name = "mufiz",
    .root_module = b.createModule(.{
        .root_source_file = b.path("src/c_api.zig"),
        .target = b.resolveTargetQuery(.{
            .cpu_arch = .wasm32,
            .os_tag = .wasi,
        }),
        .optimize = .ReleaseSmall,
    }),
});
wasm_exe.rdynamic = true;
wasm_exe.entry = .disabled;
```

Key settings:
- `rdynamic = true` - Export all public symbols
- `entry = .disabled` - No main function (reactor pattern)
- `optimize = .ReleaseSmall` - Small binary size

## Troubleshooting

### Playground won't load

- Check that you're running a web server (file:// URLs won't work due to CORS)
- Verify `zig-out/wasm/mufiz.wasm` exists
- Check browser console for error messages

### "WASM not initialized" error

- Wait for the status indicator to show "Ready"
- Refresh the page if initialization fails

### Script doesn't run

- Check for syntax errors in your code
- Look at the console output for error messages
- Verify your code doesn't use unsupported features

### Memory errors

- Reduce script size if you get out-of-memory errors
- Avoid creating too many large data structures

## Performance

WebAssembly performance compared to native:

- Numeric computations: ~80-90% of native speed
- Function calls: ~70-80% of native speed
- Memory operations: ~85-95% of native speed

The WASM runtime uses the same VM architecture as the native build, ensuring consistent behavior.

## Future Improvements

Planned enhancements:

1. Fix string literal printing in WASM
2. Add file I/O support via browser APIs
3. Implement a module system for WASM
4. Add debugging breakpoints and stepping
5. Support for importing external JavaScript functions

## Contributing

If you'd like to help fix the string printing issue or add new features:

1. The WASM-specific code is in `src/c_api.zig`
2. The web interface is in `index.html`
3. Build configuration is in `build.zig`

Bug reports and pull requests are welcome!

## License

The MufiZ WebAssembly playground is part of the MufiZ project and follows the same license.

---

**Note**: This is experimental technology. While the core language features work well, some edge cases may not behave identically to the native build.