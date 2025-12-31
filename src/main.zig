const std = @import("std");
const heap = std.heap;
const fs = std.fs;
const builtin = @import("builtin");

const clap = @import("clap");
const features = @import("features");

const conv = @import("conv.zig");
const stdlib = @import("stdlib.zig");
const system = @import("system.zig");
const mem_utils = @import("mem_utils.zig");
const InterpreterError = system.InterpreterError;
pub const vm_h = @import("vm.zig");
pub const OK: u8 = vm_h.INTERPRET_OK;
pub const COMPILE_ERROR: u8 = vm_h.INTERPRET_COMPILE_ERROR;
pub const RUNTIME_ERROR: u8 = vm_h.INTERPRET_RUNTIME_ERROR;

// Use the unified allocator from mem_utils - get it at runtime to avoid comptime issues
pub fn getGlobalAlloc() std.mem.Allocator {
    return mem_utils.getAllocator();
}

const params = clap.parseParamsComptime(
    \\-h, --help             Displays this help and exit.
    \\-v, --version          Prints the version and codename.
    \\-r, --run <str>        Runs a Mufi Script
    \\-l, --link <str>       Link another Mufi Script when interpreting
    \\--repl                 Runs Mufi Repl system
    \\--docs                 Standard Library Documentation
);
/// Main function
pub fn main() !void {
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

    vm_h.initVM();
    defer vm_h.freeVM();
    stdlib.prelude();
    stdlib.addMath();
    stdlib.addCollections();
    stdlib.addTime();
    stdlib.addFs();
    stdlib.addUtils();
    stdlib.addNet();
    stdlib.addMatrix();
    if (features.sandbox) {
        try system.repl();
    } else {
        var diag = clap.Diagnostic{};
        var res = clap.parse(clap.Help, &params, clap.parsers.default, .{
            .allocator = getGlobalAlloc(),
            .diagnostic = &diag,
        }) catch |err| {
            std.debug.print("Error: {any}\n", .{err});
            return err;
        };
        defer res.deinit();

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
            @import("stdlib.zig").printDocs();
        } else {
            system.version();
            system.usage();
            std.debug.print("Use --help for usage information\n", .{});
            return;
        }
    }
}
