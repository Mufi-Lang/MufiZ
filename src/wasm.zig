const std = @import("std");
const mufiz = @import("lib.zig");

// Ensure dependencies are used
const features = @import("features");
const debug = @import("debug");

/// WebAssembly-compatible version of InitOptions
pub const WasmInitOptions = extern struct {
    enable_leak_detection: bool = false,
    enable_tracking: bool = false,
    enable_safety: bool = false,
};

/// Exported init function for WebAssembly
pub export fn wasm_init(options: WasmInitOptions) callconv(.c) void {
    _ = features;
    _ = debug;
    mufiz.init(.{
        .enable_leak_detection = options.enable_leak_detection,
        .enable_tracking = options.enable_tracking,
        .enable_safety = options.enable_safety,
    }) catch {};
}

/// Exported deinit function for WebAssembly
pub export fn wasm_deinit() callconv(.c) void {
    mufiz.deinit();
}

/// Exported interpret function for WebAssembly
pub export fn wasm_interpret(source: [*]const u8) callconv(.c) u8 {
    return mufiz.interpret(source);
}