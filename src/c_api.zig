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

// ============================================================================
// Package Management C API
// ============================================================================

/// Initialize a new MufiZ project in the current directory
/// Returns MUFIZ_OK on success or a negative error code on failure.
///
/// C ABI:
///   int32_t mufiz_pm_init(const char *project_name);
export fn mufiz_pm_init(project_name: [*:0]const u8) i32 {
    const slice = std.mem.span(@as([*:0]const u8, @ptrCast(project_name)));
    mufiz.pmInit(allocator, slice) catch {
        return MUFIZ_ERR_GENERIC;
    };
    return MUFIZ_OK;
}

/// Create a new MufiZ project in a new directory
/// Returns MUFIZ_OK on success or a negative error code on failure.
///
/// C ABI:
///   int32_t mufiz_pm_new(const char *project_name);
export fn mufiz_pm_new(project_name: [*:0]const u8) i32 {
    const slice = std.mem.span(@as([*:0]const u8, @ptrCast(project_name)));
    mufiz.pmNew(allocator, slice) catch {
        return MUFIZ_ERR_GENERIC;
    };
    return MUFIZ_OK;
}

/// Display information about the current project
/// Returns MUFIZ_OK on success or a negative error code on failure.
///
/// C ABI:
///   int32_t mufiz_pm_info(void);
export fn mufiz_pm_info() i32 {
    mufiz.pmInfo(allocator) catch {
        return MUFIZ_ERR_GENERIC;
    };
    return MUFIZ_OK;
}

/// Run the current project
/// Returns MUFIZ_OK on success or a negative error code on failure.
///
/// C ABI:
///   int32_t mufiz_pm_run(void);
export fn mufiz_pm_run() i32 {
    mufiz.pmRun(allocator) catch {
        return MUFIZ_ERR_GENERIC;
    };
    return MUFIZ_OK;
}

/// Install project dependencies
/// Returns MUFIZ_OK on success or a negative error code on failure.
///
/// C ABI:
///   int32_t mufiz_pm_install(void);
export fn mufiz_pm_install() i32 {
    mufiz.pmInstall(allocator) catch {
        return MUFIZ_ERR_GENERIC;
    };
    return MUFIZ_OK;
}

/// Add a dependency to the project
/// Returns MUFIZ_OK on success or a negative error code on failure.
///
/// C ABI:
///   int32_t mufiz_pm_add_dependency(const char *name, const char *url, const char *version);
export fn mufiz_pm_add_dependency(
    name: [*:0]const u8,
    url: [*:0]const u8,
    version: [*:0]const u8,
) i32 {
    const name_slice = std.mem.span(@as([*:0]const u8, @ptrCast(name)));
    const url_slice = std.mem.span(@as([*:0]const u8, @ptrCast(url)));
    const version_slice = std.mem.span(@as([*:0]const u8, @ptrCast(version)));

    mufiz.pmAddDependency(allocator, name_slice, url_slice, version_slice) catch {
        return MUFIZ_ERR_GENERIC;
    };
    return MUFIZ_OK;
}

/// Get package cache statistics
/// Returns MUFIZ_OK on success or a negative error code on failure.
///
/// C ABI:
///   int32_t mufiz_pm_cache_info(void);
export fn mufiz_pm_cache_info() i32 {
    mufiz.pmCacheInfo(allocator) catch {
        return MUFIZ_ERR_GENERIC;
    };
    return MUFIZ_OK;
}

/// Clear the package cache
/// Returns MUFIZ_OK on success or a negative error code on failure.
///
/// C ABI:
///   int32_t mufiz_pm_cache_clear(void);
export fn mufiz_pm_cache_clear() i32 {
    mufiz.pmCacheClear(allocator) catch {
        return MUFIZ_ERR_GENERIC;
    };
    return MUFIZ_OK;
}

// ============================================================================
// Formatting C API
// ============================================================================

/// Format a MufiZ source string and return the formatted result
/// The returned string must be freed with mufiz_free_cstring()
/// Returns NULL on error
///
/// C ABI:
///   char *mufiz_format_source(const char *source);
export fn mufiz_format_source(source: [*:0]const u8) ?[*:0]u8 {
    const slice = std.mem.span(@as([*:0]const u8, @ptrCast(source)));

    const formatted = mufiz.formatSource(allocator, slice) catch {
        return null;
    };

    // Convert to null-terminated C string
    const c_str = allocator.allocSentinel(u8, formatted.len, 0) catch {
        allocator.free(formatted);
        return null;
    };

    @memcpy(c_str[0..formatted.len], formatted);
    allocator.free(formatted);

    return @as([*:0]u8, @ptrCast(c_str.ptr));
}

/// Format a MufiZ file in-place
/// Returns MUFIZ_OK on success or a negative error code on failure.
///
/// C ABI:
///   int32_t mufiz_format_file(const char *filepath);
export fn mufiz_format_file(filepath: [*:0]const u8) i32 {
    const slice = std.mem.span(@as([*:0]const u8, @ptrCast(filepath)));
    mufiz.formatFile(allocator, slice) catch {
        return MUFIZ_ERR_GENERIC;
    };
    return MUFIZ_OK;
}

/// Check if a source string needs formatting
/// Returns 1 if formatting would change the source, 0 if already formatted, -1 on error
///
/// C ABI:
///   int32_t mufiz_needs_formatting(const char *source);
export fn mufiz_needs_formatting(source: [*:0]const u8) i32 {
    const slice = std.mem.span(@as([*:0]const u8, @ptrCast(source)));
    const needs = mufiz.needsFormatting(allocator, slice) catch {
        return -1;
    };
    return if (needs) 1 else 0;
}

pub fn main() void {}
