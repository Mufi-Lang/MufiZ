/// MufiZ Interpreter Entry Point
/// This is the main entry point for the MufiZ language interpreter.
/// It provides the command-line interface to the MufiZ library.

const std = @import("std");
const builtin = @import("builtin");

const clap = @import("clap");
const features = @import("features");

const mufiz = @import("lib.zig");

// Interpreter exit codes (re-exported from library)
pub const OK: u8 = mufiz.OK;
pub const COMPILE_ERROR: u8 = mufiz.COMPILE_ERROR;
pub const RUNTIME_ERROR: u8 = mufiz.RUNTIME_ERROR;

/// Returns the global allocator used throughout the interpreter
/// This provides a centralized memory management interface
pub fn getGlobalAllocator() std.mem.Allocator {
    return mufiz.getAllocator();
}

// Command-line parameter definitions
const params = clap.parseParamsComptime(
    \\-h, --help             Displays this help and exit.
    \\-v, --version          Prints the version and codename.
    \\-r, --run <str>        Runs a Mufi Script
    \\-l, --link <str>       Link another Mufi Script when interpreting
    \\--repl                 Runs Mufi Repl system
    \\--docs                 Standard Library Documentation
);

/// Main entry point for the MufiZ interpreter
/// Initializes all subsystems and handles command-line arguments
pub fn main() !void {
    // Initialize the MufiZ library with leak detection and safety checks
    try mufiz.init(.{
        .enable_leak_detection = true,
        .enable_tracking = true,
        .enable_safety = true,
    });
    defer mufiz.deinit();
    
    // Check if running in sandbox mode (REPL-only)
    if (features.sandbox) {
        try mufiz.startRepl();
    } else {
        // Parse command-line arguments
        var diag = clap.Diagnostic{};
        var res = clap.parse(clap.Help, &params, clap.parsers.default, .{
            .allocator = getGlobalAllocator(),
            .diagnostic = &diag,
        }) catch |err| {
            std.debug.print("Error: {any}\n", .{err});
            return err;
        };
        defer res.deinit();

        // Handle command-line arguments
        if (res.args.version != 0) {
            mufiz.printVersion();
        } else if (res.args.run) |s| {
            var runner = mufiz.Runner.init(getGlobalAllocator());
            defer runner.deinit();
            try runner.setMain(@constCast(s));
            if (res.args.link) |l| {
                try runner.setLink(@constCast(l));
            }
            try runner.runFile();
        } else if (res.args.repl != 0) {
            try mufiz.startRepl();
        } else if (res.args.docs != 0) {
            mufiz.stdlib.printDocs();
        } else {
            mufiz.printVersion();
            mufiz.printUsage();
            std.debug.print("Use --help for usage information\n", .{});
            return;
        }
    }
}
