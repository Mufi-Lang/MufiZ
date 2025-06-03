const std = @import("std");
const heap = std.heap;
const fs = std.fs;
const builtin = @import("builtin");

const clap = @import("clap");
const features = @import("features");

const conv = @import("conv.zig");
const stdlib = @import("stdlib.zig");
const system = @import("system.zig");
const InterpreterError = system.InterpreterError;
pub const vm_h = @import("vm.zig");
pub const OK: u8 = vm_h.INTERPRET_OK;
pub const COMPILE_ERROR: u8 = vm_h.INTERPRET_COMPILE_ERROR;
pub const RUNTIME_ERROR: u8 = vm_h.INTERPRET_RUNTIME_ERROR;

var Global = heap.GeneralPurposeAllocator(.{}){};
pub const GlobalAlloc = Global.allocator();

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
    vm_h.initVM();
    defer vm_h.freeVM();
    stdlib.prelude();
    stdlib.addMath();
    stdlib.addCollections();
    stdlib.addTime();
    stdlib.addFs();
    stdlib.addUtils();
    stdlib.addNet();
    defer {
        const check = Global.deinit();
        if (check == .leak) @panic("memory leak!");
    }
    if (features.sandbox) {
        try system.repl();
    } else {
        var diag = clap.Diagnostic{};
        var res = clap.parse(clap.Help, &params, clap.parsers.default, .{
            .allocator = GlobalAlloc,
            .diagnostic = &diag,
        }) catch |err| {
            try diag.report(std.io.getStdErr().writer(), err);
            return err;
        };
        defer res.deinit();

        if (res.args.version != 0) {
            system.version();
        } else if (res.args.run) |s| {
            var runner = system.Runner.init(GlobalAlloc);
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
            return clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
        }
    }
}
