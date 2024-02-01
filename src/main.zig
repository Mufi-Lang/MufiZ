const std = @import("std");
const nostd = @import("build_opts").nostd;
const stdlib = @import("stdlib.zig");
const vm = @cImport(@cInclude("vm.h"));
const builtin = @import("builtin");
const system = @import("system.zig");

/// Because Windows hangs on `system.repl()`
pub const pre = if (builtin.os.tag == .windows) @cImport(@cInclude("pre.h")) else {};

var Global = std.heap.GeneralPurposeAllocator(.{}){};
pub const GlobalAlloc = Global.allocator();

pub fn main() !void {
    vm.initVM();
    defer vm.freeVM();
    defer {
        const check = Global.deinit();
        if (check == .leak) @panic("memory leak!");
    }

    if (!nostd) {
        var natives = stdlib.NativeFunctions.init(GlobalAlloc);
        defer natives.deinit();
        try natives.addMath();
        try natives.append("str2i", &stdlib.str2i);
        natives.define();
    }

    var args = try std.process.argsAlloc(GlobalAlloc);
    defer std.process.argsFree(GlobalAlloc, args);

    if (args.len == 1) {
        if (builtin.os.tag == .windows) pre.repl() else try system.repl();
    } else if (args.len == 2) {
        if (std.mem.eql(u8, args[1], "version")) {
            system.vopt.version();
        } else {
            try system.runFile(args[1], GlobalAlloc);
        }
    } else {
        std.debug.print("Usage: mufiz <path>\n", .{});
    }
}
