const std = @import("std");
const builtin = @import("builtin");
const stdlib = @import("stdlib.zig");
const system = @import("system.zig");
const clap = @import("clap");
const core = @import("core.zig");
const features = @import("features");
const conv = @import("conv.zig");
const heap = std.heap;
pub const vm_h = core.vm_h;
const testing = std.testing;
const fs = std.fs;
const InterpreterError = system.InterpreterError;

pub const OK: u8 = core.vm_h.INTERPRET_OK;
pub const COMPILE_ERROR: u8 = core.vm_h.INTERPRET_COMPILE_ERROR;
pub const RUNTIME_ERROR: u8 = core.vm_h.INTERPRET_RUNTIME_ERROR;

var Global = heap.GeneralPurposeAllocator(.{}){};
pub const GlobalAlloc = if (builtin.target.isWasm()) heap.page_allocator else Global.allocator();

const params = clap.parseParamsComptime(
    \\-h, --help             Displays this help and exit.
    \\-v, --version          Prints the version and codename.
    \\-r, --run <str>        Runs a Mufi Script
    \\-l, --link <str>       Link another Mufi Script when interpreting 
    \\--repl                 Runs Mufi Repl system
    \\
);
/// Main function
pub fn main() !void {
    vm_h.initVM();
    defer vm_h.freeVM();
    stdlib.prelude();
    stdlib.addMath();
    stdlib.addTime();
    stdlib.addFs();
    stdlib.addNet();
    vm_h.importCollections();
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
        } else {
            system.version();
            system.usage();
            return clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
        }
    }
}

// fn c2ir(ir: u8) InterpreterError {
//     switch (ir) {
//         core.vm_h.INTERPRET_OK => return InterpreterError.OK,
//         core.vm_h.INTERPRET_COMPILE_ERROR => return InterpreterError.CompileError,
//         core.vm_h.INTERPRET_RUNTIME_ERROR => return InterpreterError.RuntimeError,
//         else => unreachable,
//     }
// }

// fn test_run(path: []const u8, ir: u8) anyerror!void {
//     const error_type = c2ir(ir);
//     const str = try fs.cwd().readFileAlloc(GlobalAlloc, path, @intCast(std.math.maxInt(u16)));
//     defer GlobalAlloc.free(str);
//     const cstr = conv.cstr(str);
//     const result = core.vm_h.interpret(cstr);
//     if (result != ir) return error_type;
// }

// test "vector-slice" {
//     var runner = system.Runner.init(testing.allocator);
//     defer runner.deinit();

//     try runner.setMain(@constCast("test_suite/vec/slice.mufi"));
//     try runner.runFile();
// }
