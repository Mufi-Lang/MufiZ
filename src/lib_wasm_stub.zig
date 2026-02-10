const std = @import("std");

/// Minimal WASM-only stub implementation of the mufiz core API.
///
/// This lightweight module provides just enough of the `mufiz` surface that
/// the C API wrappers expect so we can compile a small wasm-target static
/// archive without pulling in the full runtime (posix/threads, etc.).
///
/// The stub intentionally avoids platform-specific functionality and performs
/// no real interpretation — it is meant for demos/tests and to produce a
/// small, linkable artifact for Emscripten workflows.
pub const InitOptions = extern struct {
    enable_leak_detection: bool,
    enable_tracking: bool,
    enable_safety: bool,
};

pub const LibraryError = error{AlreadyInitialized};

var initialized: bool = false;

/// Initialize the (stub) runtime. Returns `LibraryError.AlreadyInitialized` if
/// called more than once.
pub export fn wasm_init(options: InitOptions) callconv(.c) void {
    _ = options; // silence unused
    if (initialized) return;
    initialized = true;
}

/// Deinitialize the runtime (idempotent).
pub export fn wasm_deinit() callconv(.c) void {
    initialized = false;
}

/// Interpret the provided source string. Returns the length of the string as a test.
/// This stub does not actually execute code yet.
pub export fn wasm_interpret(source: [*]const u8) callconv(.c) u8 {
    var len: usize = 0;
    while (source[len] != 0) : (len += 1) {}
    return @intCast(len & 0xFF);
}

/// Allocate memory in WASM for string passing
pub export fn wasm_alloc(size: usize) callconv(.c) ?[*]u8 {
    const allocator = std.heap.wasm_allocator;
    const buf = allocator.alloc(u8, size) catch return null;
    return buf.ptr;
}

/// Free memory in WASM
pub export fn wasm_free(ptr: [*]u8, size: usize) callconv(.c) void {
    const allocator = std.heap.wasm_allocator;
    allocator.free(ptr[0..size]);
}

/// Whether the last run detected memory leaks (always false for the stub).
pub fn hasMemoryLeaks() bool {
    return false;
}

/// Print memory statistics (no-op for the stub).
pub fn printMemoryStats() void {
    // intentionally empty
}

/// Small success code used by the C API wrappers.
pub const OK: u8 = 0;
