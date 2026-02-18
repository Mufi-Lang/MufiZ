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
const analysis = @import("analysis.zig");

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

/// Generate documentation for the project
/// Returns MUFIZ_OK on success or a negative error code on failure.
///
/// C ABI:
///   int32_t mufiz_pm_docs(void);
export fn mufiz_pm_docs() i32 {
    mufiz.pmDocs(allocator) catch {
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

// ============================================================================
// Analysis Context API (LSP Support)
// ============================================================================

/// Create a context for static analysis (does not execute code).
/// Returns an opaque pointer to the analysis context, or NULL on failure.
///
/// C ABI:
///   void* mufiz_create_analysis_context(void);
export fn mufiz_create_analysis_context() ?*anyopaque {
    const ctx = allocator.create(analysis.AnalysisContext) catch {
        return null;
    };
    ctx.* = analysis.AnalysisContext.init(allocator);
    return @ptrCast(ctx);
}

/// Destroy an analysis context and free all associated resources.
///
/// C ABI:
///   void mufiz_destroy_analysis_context(void* context);
export fn mufiz_destroy_analysis_context(context: ?*anyopaque) void {
    if (context == null) return;
    const ctx: *analysis.AnalysisContext = @ptrCast(@alignCast(context));
    ctx.deinit();
    allocator.destroy(ctx);
}

/// Update the source code in the analysis context (triggers re-parsing).
/// Returns true if parsing was successful (no fatal errors).
///
/// C ABI:
///   bool mufiz_update_source(void* context, const char* filename, const char* source);
export fn mufiz_update_source(
    context: ?*anyopaque,
    filename: [*:0]const u8,
    source: [*:0]const u8,
) bool {
    if (context == null) return false;
    const ctx: *analysis.AnalysisContext = @ptrCast(@alignCast(context));

    _ = filename; // Currently unused, but kept for API compatibility
    const source_slice = std.mem.span(@as([*:0]const u8, @ptrCast(source)));

    ctx.updateSource(source_slice) catch {
        return false;
    };

    return true;
}

// ============================================================================
// Diagnostics (Linting)
// ============================================================================

/// Get the number of diagnostics (syntax/semantic errors and warnings).
///
/// C ABI:
///   int32_t mufiz_get_diagnostic_count(void* context);
export fn mufiz_get_diagnostic_count(context: ?*anyopaque) i32 {
    if (context == null) return 0;
    const ctx: *analysis.AnalysisContext = @ptrCast(@alignCast(context));
    return @intCast(ctx.diagnostics.items.len);
}

/// Get a specific diagnostic by index.
/// The returned pointer is valid until the next call to mufiz_update_source.
/// Returns NULL if the index is out of bounds.
///
/// C ABI:
///   const MufizDiagnostic* mufiz_get_diagnostic(void* context, int32_t index);
export fn mufiz_get_diagnostic(context: ?*anyopaque, index: i32) ?*const analysis.MufizDiagnostic {
    if (context == null) return null;
    if (index < 0) return null;

    const ctx: *analysis.AnalysisContext = @ptrCast(@alignCast(context));
    const idx: usize = @intCast(index);

    if (idx >= ctx.diagnostics.items.len) return null;
    return &ctx.diagnostics.items[idx];
}

// ============================================================================
// Autocompletion & Hover
// ============================================================================

/// Compute completion items at a specific cursor position.
/// Returns the number of completion items found.
///
/// C ABI:
///   int32_t mufiz_compute_completions(void* context, uint32_t line, uint32_t column);
export fn mufiz_compute_completions(
    context: ?*anyopaque,
    line: u32,
    column: u32,
) i32 {
    if (context == null) return 0;
    const ctx: *analysis.AnalysisContext = @ptrCast(@alignCast(context));

    const count = ctx.computeCompletions(line, column) catch {
        return 0;
    };

    return @intCast(count);
}

/// Get a specific completion item by index (after calling mufiz_compute_completions).
/// The returned pointer is valid until the next call to mufiz_compute_completions.
/// Returns NULL if the index is out of bounds.
///
/// C ABI:
///   const MufizCompletionItem* mufiz_get_completion_item(void* context, int32_t index);
export fn mufiz_get_completion_item(context: ?*anyopaque, index: i32) ?*const analysis.MufizCompletionItem {
    if (context == null) return null;
    if (index < 0) return null;

    const ctx: *analysis.AnalysisContext = @ptrCast(@alignCast(context));
    const idx: usize = @intCast(index);

    if (idx >= ctx.completion_results.items.len) return null;
    return &ctx.completion_results.items[idx];
}

/// Get hover information (type/documentation) for the symbol at the cursor position.
/// The returned pointer is valid until the next call to mufiz_get_hover_info.
/// Returns NULL if no symbol is found at the position.
///
/// C ABI:
///   const MufizCompletionItem* mufiz_get_hover_info(void* context, uint32_t line, uint32_t column);
export fn mufiz_get_hover_info(
    context: ?*anyopaque,
    line: u32,
    column: u32,
) ?*const analysis.MufizCompletionItem {
    if (context == null) return null;
    const ctx: *analysis.AnalysisContext = @ptrCast(@alignCast(context));

    // Free previous hover info if it exists
    if (ctx.last_hover) |*item| {
        allocator.free(std.mem.span(item.name));
        allocator.free(std.mem.span(item.type_name));
        allocator.free(std.mem.span(item.doc_string));
        ctx.last_hover = null;
    }

    const hover = ctx.getHover(line, column) catch {
        return null;
    };

    if (hover) |h| {
        ctx.last_hover = h;
        return &ctx.last_hover.?;
    }

    return null;
}

pub fn main() void {}
