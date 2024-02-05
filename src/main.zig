const std = @import("std");
const nostd = @import("build_opts").nostd;
const stdlib = @import("stdlib.zig");
const vm = @cImport(@cInclude("vm.h"));
const system = @import("system.zig");
const clap = @import("clap");

var Global = std.heap.GeneralPurposeAllocator(.{}){};
pub const GlobalAlloc = Global.allocator();

const params = clap.parseParamsComptime(
    \\-h, --help        Displays this help and exit.
    \\-v, --version     Prints the version and codename.
    \\-r, --run <str>   Runs a Mufi Script
    \\ -l, --link <str> Links another Mufi Script when interpreting 
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
        try natives.addTime();
        try natives.addTypes();
        try natives.addOthers();
        natives.define();
    }

    if (res.args.help != 0) return clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
    if (res.args.version != 0) system.vopt.version();
    if (res.args.run) |s| {
        if (res.args.link) |l| {
            try system.runLinkFiles(@constCast(l), @constCast(s), GlobalAlloc);
        } else try system.runFile(@constCast(s), GlobalAlloc);
    }
    if (res.args.repl != 0) try system.repl();
}
