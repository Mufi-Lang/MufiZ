//// MufiZ C API wrapper
////
//// This file provides a small, stable C-compatible ABI on top of the
//// Zig `mufiz` library so the library can be built as a shared/dynamic
//// library and linked from languages like Swift (via a bridging header).
////
//// The wrappers are intentionally tiny and do minimal work:
////  - translate C / null-terminated strings to Zig slices
////  - map Zig errors to simple integer return codes
////  - provide helpers to allocate/free C strings using the C allocator
////
//// Usage (from Swift/C):
////  - Call `mufiz_init(...)` once before other functions.
////  - Call `mufiz_interpret("...")` to run code (returns the interpreter exit code).
////  - Call `mufiz_deinit()` once when done.
////  - Use `mufiz_strdup()` / `mufiz_free_cstring()` for C string ownership if needed.
////
const std = @import("std");
const builtin = @import("builtin");
const mufiz = @import("lib.zig");

const allocator = if (builtin.target.cpu.arch == .wasm32)
    std.heap.wasm_allocator
else
    std.heap.c_allocator;

/// C-style error codes returned by `mufiz_init`
pub const MUFIZ_OK: i32 = 0;
pub const MUFIZ_ERR_ALREADY_INITIALIZED: i32 = -1;
pub const MUFIZ_ERR_NOT_INITIALIZED: i32 = -2;
pub const MUFIZ_ERR_GENERIC: i32 = -3;

/// Initialize the library.
/// Returns `MUFIZ_OK` on success or a negative error code on failure.
///
/// C ABI:
///   int32_t mufiz_init(bool enable_leak_detection, bool enable_tracking, bool enable_safety);
export fn mufiz_init(enable_leak_detection: bool, enable_tracking: bool, enable_safety: bool) i32 {
    const options = mufiz.InitOptions{
        .enable_leak_detection = enable_leak_detection,
        .enable_tracking = enable_tracking,
        .enable_safety = enable_safety,
    };

    // propagate a few simple error codes (keep the API tiny and C-friendly)
    mufiz.init(options) catch |err| {
        if (err == mufiz.LibraryError.AlreadyInitialized) {
            return MUFIZ_ERR_ALREADY_INITIALIZED;
        } else {
            return MUFIZ_ERR_GENERIC;
        }
    };
    return MUFIZ_OK;
}

/// Deinitialize the library (idempotent).
///
/// C ABI:
///   void mufiz_deinit(void);
export fn mufiz_deinit() void {
    mufiz.deinit();
}

/// Interpret a null-terminated C string containing MufiZ source.
///
/// C ABI:
///   uint8_t mufiz_interpret(const char *source);
export fn mufiz_interpret(source: [*:0]const u8) u8 {
    // Convert null-terminated C string to a Zig slice
    const slice = std.mem.span(@as([*:0]const u8, @ptrCast(source)));
    return mufiz.interpret(slice);
}

/// WASM-friendly exported wrappers
/// These tiny shims provide stable, demo-friendly symbols for the Emscripten
/// build (the web demo expects `init_wasm` / `interpret` / `deinit_wasm`).
/// They simply forward to the existing C API above so when the full core is
/// linked into the final WASM artifact the wrappers invoke the real logic.
///
/// C ABI:
///   void init_wasm(void);
export fn init_wasm() void {
    // Use conservative defaults for the demo; ignore return code here.
    _ = mufiz_init(false, false, false);
}

/// C ABI:
///   uint8_t interpret(const char *source);
export fn interpret(source: [*:0]const u8) u8 {
    return mufiz_interpret(source);
}

/// C ABI:
///   void deinit_wasm(void);
export fn deinit_wasm() void {
    mufiz_deinit();
}

/// Returns whether the last run detected memory leaks (convenience).
///
/// C ABI:
///   bool mufiz_has_memory_leaks(void);
export fn mufiz_has_memory_leaks() bool {
    return mufiz.hasMemoryLeaks();
}

/// Print memory statistics to stdout (convenience).
///
/// C ABI:
///   void mufiz_print_memory_stats(void);
export fn mufiz_print_memory_stats() void {
    mufiz.printMemoryStats();
}

/// Allocate a nul-terminated C string on the C allocator and return it.
/// The returned pointer must be freed with `mufiz_free_cstring`.
///
/// Returns `null` if allocation fails.
///
/// C ABI:
///   char *mufiz_strdup(const char *s);
export fn mufiz_strdup(src: [*:0]const u8) ?[*:0]u8 {
    const len: usize = std.mem.len(src);
    // allocate len + 1 to store the trailing NUL
    var dst = allocator.alloc(u8, len + 1) catch return null;
    // copy bytes (src is a null-terminated C string; slice it directly)
    var idx: usize = 0;
    while (idx < len) : (idx += 1) {
        dst[idx] = src[idx];
    }
    dst[len] = 0;
    return @as([*:0]u8, @ptrCast(dst.ptr));
}

/// Free a C string previously allocated with `mufiz_strdup`.
///
/// C ABI:
///   void mufiz_free_cstring(char *s);
export fn mufiz_free_cstring(ptr: ?[*:0]u8) void {
    if (ptr == null) return;
    const p = ptr.?; // unwrap optional pointer
    const len: usize = std.mem.len(p);
    // Free the original allocation which was of size len + 1 (includes trailing NUL)
    const slice = @as([]u8, p[0 .. len + 1]);
    allocator.free(slice);
}

test "c api basic init / interpret / deinit" {
    try std.testing.expectEqual(MUFIZ_OK, mufiz_init(false, false, false));
    defer mufiz_deinit();

    const src = @as([*:0]const u8, "1 + 1;");
    const result = mufiz_interpret(src);
    try std.testing.expectEqual(mufiz.OK, result);
}

test "c api strdup and free" {
    const s = @as([*:0]const u8, "hello");
    const dup = mufiz_strdup(s) orelse {
        try std.testing.expect(false); // allocation shouldn't fail in normal test env
        unreachable;
    };
    defer mufiz_free_cstring(dup);

    const len = std.mem.len(s);
    try std.testing.expectEqual(len, std.mem.len(dup));
    // Compare bytes
    var i: usize = 0;
    while (i < len) : (i += 1) {
        try std.testing.expectEqual(s[i], dup[i]);
    }
}

pub fn main() void {}
