const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    // Use pre-initialized args iterator from init
    var args_iter = std.process.Args.Iterator.init(init.minimal.args);
    _ = args_iter.next(); // Skip executable name

    const output_path = args_iter.next() orelse {
        std.debug.print("Usage: gen_header <output_path>\n", .{});
        std.process.fatal("missing output path", .{});
    };

    // Ensure output directory exists
    if (std.fs.path.dirname(output_path)) |dir| {
        std.Io.Dir.makePath(.cwd(), io, dir) catch |err| {
            if (err != error.PathAlreadyExists) {
                return err;
            }
        };
    }

    // Generate a minimal header
    const header = 
        \\// MufiZ C API Header
        \\// Auto-generated for Zig 0.16.0 compatibility
        \\#ifndef MUFIZ_H
        \\#define MUFIZ_H
        \\#endif // MUFIZ_H
    ;

    // Write to file
    const file = try std.Io.Dir.createFile(.cwd(), io, output_path, .{});
    defer file.close(io);

    try file.writeAll(header);

    std.debug.print("Generated header: {s}\n", .{output_path});
}
