const std = @import("std");
const builtin = @import("builtin");
const nostd = @import("build_opts").nostd;
const stdlib = @import("stdlib.zig");
const system = @import("system.zig");
const clap = @import("clap");
const core = @import("core");
const heap = std.heap;

var Global = heap.GeneralPurposeAllocator(.{}){};
pub const GlobalAlloc = Global.allocator();

const params = clap.parseParamsComptime(
    \\-h, --help             Displays this help and exit.
    \\-v, --version          Prints the version and codename.
    \\-r, --run <str>        Runs a Mufi Script
    \\-l, --link <str>       Link another Mufi Script when interpreting 
    \\--repl                 Runs Mufi Repl system
    \\
);

pub fn main() !void {
    core.vm_h.initVM();
    defer core.vm_h.freeVM();
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
        try natives.addTime();
        try natives.addTypes();
        try natives.addOthers();
        try natives.addFs();
        natives.define();
    }

    if (res.args.help != 0) {
        return clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
    } else if (res.args.version != 0) {
        system.vopt.version();
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
        return clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
    }

}
