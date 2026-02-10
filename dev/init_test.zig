const std = @import("std");
const mufiz = @import("../src/lib.zig");

pub fn main() !void {
    const out = std.io.getStdOut().writer();

    try out.print("init_test: about to init\n", .{});

    // Try to initialize the library and report any error
    mufiz.init(.{
        .enable_leak_detection = true,
        .enable_tracking = true,
        .enable_safety = true,
    }) catch |err| {
        try out.print("init_test: init returned error: {any}\n", .{err});
        return;
    };

    defer {
        try out.print("init_test: deferred deinit - starting\n", .{});
        mufiz.deinit();
        try out.print("init_test: deferred deinit - done\n", .{});
    };

    try out.print("init_test: init succeeded\n", .{});

    // Optionally keep the process alive briefly for debugging/inspection:
    // std.time.sleep(1_000_000_000); // 1 second in nanoseconds
}
