# Specification: Comprehensive Standard Library Foundation

## Goal
Establish a robust base for Mufi-Lang's standard library by implementing core I/O and File System modules. This will provide the necessary primitives for building more complex applications and libraries.

## Scope
- **Standard I/O:**
    - `io.print(value)`: Print a value to stdout.
    - `io.println(value)`: Print a value followed by a newline.
    - `io.readln()`: Read a line from stdin.
- **File System:**
    - `fs.readFile(path)`: Read the entire content of a file.
    - `fs.writeFile(path, content)`: Write content to a file.
    - `fs.exists(path)`: Check if a path exists.
    - `fs.listDir(path)`: List entries in a directory.

## Technical Approach
- Leverage Zig's `std.io` and `std.fs` for performance and safety.
- Expose these capabilities to Mufi-Lang through the existing stdlib registration mechanism (likely in `src/stdlib_main.zig`).
- Ensure all operations handle errors gracefully and provide meaningful messages to the Mufi-Lang user.
