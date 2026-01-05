/// MufiZ Interpreter Entry Point
/// This is the main entry point for the MufiZ language interpreter.
/// It initializes the VM, memory management, and standard library,
/// then processes command-line arguments to execute scripts or start the REPL.

const std = @import("std");
const builtin = @import("builtin");

const clap = @import("clap");
const features = @import("features");

const stdlib = @import("stdlib_main.zig");
const system = @import("system.zig");
const mem_utils = @import("mem_utils.zig");
const InterpreterError = system.InterpreterError;
pub const vm_h = @import("vm.zig");

// Interpreter exit codes
pub const OK: u8 = vm_h.INTERPRET_OK;
pub const COMPILE_ERROR: u8 = vm_h.INTERPRET_COMPILE_ERROR;
pub const RUNTIME_ERROR: u8 = vm_h.INTERPRET_RUNTIME_ERROR;

/// Returns the global allocator used throughout the interpreter
/// This provides a centralized memory management interface
pub fn getGlobalAlloc() std.mem.Allocator {
    return mem_utils.getAllocator();
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
    // Initialize memory management with leak detection and safety checks
    mem_utils.initAllocator(.{
        .enable_leak_detection = true,
        .enable_tracking = true,
        .enable_safety = true,
    });
    defer {
        if (mem_utils.checkForLeaks()) {
            std.debug.print("Warning: Memory leaks detected!\n", .{});
            mem_utils.printMemStats();
        }
        mem_utils.deinit();
    }

    // Initialize the virtual machine
    vm_h.initVM();
    defer vm_h.freeVM();
    
    // Initialize and register standard library functions
    try stdlib.initializeStdlib();
    stdlib.registerWithVM();
    
    // Check if running in sandbox mode (REPL-only)
    if (features.sandbox) {
        try system.repl();
    } else {
        // Parse command-line arguments
        var diag = clap.Diagnostic{};
        var res = clap.parse(clap.Help, &params, clap.parsers.default, .{
            .allocator = getGlobalAlloc(),
            .diagnostic = &diag,
        }) catch |err| {
            std.debug.print("Error: {any}\n", .{err});
            return err;
        };
        defer res.deinit();

        // Handle command-line arguments
        if (res.args.version != 0) {
            system.version();
        } else if (res.args.run) |s| {
            var runner = system.Runner.init(getGlobalAlloc());
            defer runner.deinit();
            try runner.setMain(@constCast(s));
            if (res.args.link) |l| {
                try runner.setLink(@constCast(l));
            }
            try runner.runFile();
        } else if (res.args.repl != 0) {
            try system.repl();
        } else if (res.args.docs != 0) {
            stdlib.printDocs();
        } else {
            system.version();
            system.usage();
            std.debug.print("Use --help for usage information\n", .{});
            return;
        }
    }
}
