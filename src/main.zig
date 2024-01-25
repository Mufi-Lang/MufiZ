const std = @import("std");
const nostd = @import("build_opts").nostd;
const stdlib = @import("stdlib.zig");
const vm = @cImport(@cInclude("vm.h"));
const builtin = @import("builtin");
const system = @import("system.zig");

/// Because Windows has error with `getStdIn().reader()`
pub const pre = if (builtin.os.tag == .windows) @cImport(@cInclude("pre.h")) else {};

pub fn main() !void {
    vm.initVM();
    defer vm.freeVM();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const check = gpa.deinit();
        if (check == .leak) @panic("memory leak!");
    }
    const allocator = gpa.allocator();
    if (!nostd) {
        var natives = stdlib.NativeFunctions.init(allocator);
        defer natives.deinit();
        try natives.addMath();
        natives.define();
    }

    var args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len == 1) {
        if (builtin.os.tag == .windows) pre.repl() else try system.repl();
    } else if (args.len == 2) {
        if (std.mem.eql(u8, args[1], "version")) {
            system.vopt.version();
        } else {
            try system.runFile(args[1], allocator);
        }
    } else {
        std.debug.print("Usage: mufiz <path>\n", .{});
    }
}
