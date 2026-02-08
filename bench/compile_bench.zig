const std = @import("std");

const mufiz = @import("../src/lib.zig");
const compiler = @import("../src/compiler.zig");
const scanner = @import("../src/scanner_optimized.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Initialize the library (sets up allocators, VM, etc.)
    try mufiz.init(.{ .enable_leak_detection = false, .enable_tracking = false, .enable_safety = false });
    defer mufiz.deinit();

    // Build a synthetic large source to stress tokenization / parsing / emission.
    // Structure: many small functions, each defining many variables (var vX = Y;)
    const functions: usize = 200; // number of functions
    const vars_per_block: usize = 200; // variables per function

    var src_list = std.ArrayList(u8).init(allocator);
    defer src_list.deinit(allocator);

    var tmp: [256]u8 = undefined;

    try src_list.appendSlice("// MufiZ compile benchmark\n");

    var i: usize = 0;
    while (i < functions) : (i += 1) {
        const hdr = std.fmt.bufPrint(&tmp, "fun f{d}() {\n", .{i}) catch unreachable;
        try src_list.appendSlice(hdr);

        var j: usize = 0;
        while (j < vars_per_block) : (j += 1) {
            const line = std.fmt.bufPrint(&tmp, "  var v{d} = {d};\n", .{ i * vars_per_block + j, j }) catch unreachable;
            try src_list.appendSlice(line);
        }

        try src_list.appendSlice("}\n");
    }

    const src_slice = src_list.items[0..src_list.len];

    // Create a null-terminated buffer for the compiler (scanner expects C-style string)
    const buff = try allocator.alloc(u8, src_slice.len + 1);
    std.mem.copy(u8, buff[0..src_slice.len], src_slice);
    buff[src_slice.len] = 0;
    defer allocator.free(buff);

    // Micro-benchmark: compile the generated source multiple times and print stats
    const runs: usize = 5;
    var total_ns: u128 = 0;

    for (0..runs) |r| {
        // Reset instrumentation counters
        scanner.resetScannerStats();
        compiler.resetCompilerStats();

        // Measure compile time
        const start = std.time.nanoTimestamp();
        const fn_ptr = compiler.compile(@ptrCast([*]const u8, buff.ptr));
        const end = std.time.nanoTimestamp();

        if (fn_ptr == null) {
            std.debug.print("Compile failed on run {d}\\n", .{r});
            return;
        }

        const elapsed = @as(u128, end - start);
        total_ns += elapsed;

        std.debug.print("Run {d}: {d} ns\\n", .{ r + 1, elapsed });
        std.debug.print("  Scanner: tokens_scanned={d}, identifiers_scanned={d}\\n", .{ scanner.scanner_stats.tokens_scanned, scanner.scanner_stats.identifiers_scanned });
        std.debug.print("  Compiler: compile_calls={d}, emitted_bytes={d}, constants_added={d}\\n", .{ compiler.compiler_stats.compile_calls, compiler.compiler_stats.emitted_bytes, compiler.compiler_stats.constants_added });
    }

    std.debug.print("Average: {d} ns\\n", .{total_ns / @as(u128, runs)});
}
