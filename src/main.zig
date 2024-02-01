const std = @import("std");
const nostd = @import("build_opts").nostd;
const stdlib = @import("stdlib.zig");
const vm = @cImport(@cInclude("vm.h"));
const builtin = @import("builtin");
const system = @import("system.zig");
const clap = @import("clap");
const debug = std.debug;

/// Because Windows hangs on `system.repl()`
pub const pre = if (builtin.os.tag == .windows) @cImport(@cInclude("pre.h")) else {};

var Global = std.heap.GeneralPurposeAllocator(.{}){};
pub const GlobalAlloc = Global.allocator();

const params = clap.parseParamsComptime(
    \\-h, --help        Displays this help and exit.
    \\-v, --version     Prints the version and codename.
    \\-r, --run <str>   Runs a Mufi Script
    \\--repl            Runs Mufi Repl system (Windows uses C bindings)
    \\
);

pub fn main() !void {
    vm.initVM();
    defer vm.freeVM();
    defer {
        const check = Global.deinit();
        if (check == .leak) @panic("memory leak!");
    }

    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, clap.parsers.default, .{
        .allocator = GlobalAlloc,
        .diagnostic = &diag,
    }) catch |err| {
        try diag.report(std.io.getStdErr().writer(), err);
        return err;
    };
    defer res.deinit();

    if (!nostd) {
        var natives = stdlib.NativeFunctions.init(GlobalAlloc);
        defer natives.deinit();
        try natives.addMath();
        try natives.append("clock", &stdlib.clock);
        natives.define();
    }

    if (res.args.help != 0) return clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
    if (res.args.version != 0) system.vopt.version();
    if (res.args.run) |s| try system.runFile(@constCast(s), GlobalAlloc);
    if (res.args.repl != 0) if (builtin.os.tag == .windows) pre.repl() else try system.repl();

    // if (args.len == 1) {
    //     if (builtin.os.tag == .windows) pre.repl() else try system.repl();
    // } else if (args.len == 2) {
    //     if (std.mem.eql(u8, args[1], "version")) {
    //         system.vopt.version();
    //     } else {
    //         try system.runFile(args[1], GlobalAlloc);
    //     }
    // } else {
    //     debug.print("Usage: mufiz <path>\n", .{});
    // }
}
