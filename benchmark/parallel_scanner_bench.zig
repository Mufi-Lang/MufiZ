const std = @import("std");
const parallel = @import("parallel_scanner");
const scanner = @import("scanner");

pub fn main() !void {
    std.debug.print("\n===========================================\n", .{});
    std.debug.print("MufiZ Parallel Scanner Benchmark Suite\n", .{});
    std.debug.print("===========================================\n\n", .{});

    const cpu_count = try std.Thread.getCpuCount();
    std.debug.print("Detected CPU cores: {d}\n\n", .{cpu_count});

    try benchmarkSmallInput();
    try benchmarkMediumInput();
    try benchmarkLargeInput();
    try benchmarkVeryLargeInput();
    try benchmarkSmartScanning();
    try benchmarkScaling();

    std.debug.print("\n===========================================\n", .{});
    std.debug.print("Benchmark Complete\n", .{});
    std.debug.print("===========================================\n", .{});
}

fn benchmarkSmallInput() !void {
    const allocator = std.heap.page_allocator;
    const source = "fun test() { var x = 42; return x; }";

    std.debug.print("Small Input ({d} bytes):\n", .{source.len});

    // Sequential
    var timer = try std.time.Timer.start();
    const iterations: u32 = 10_000;

    var i: u32 = 0;
    while (i < iterations) : (i += 1) {
        var stream = try parallel.scanSequentialOnly(allocator, source);
        stream.deinit();
    }

    const sequential_time = timer.read();
    const sequential_per_scan = @as(f64, @floatFromInt(sequential_time / iterations)) / 1000.0;

    // Smart (should auto-select sequential for small input)
    timer.reset();
    i = 0;
    while (i < iterations) : (i += 1) {
        var stream = try parallel.scanSmart(allocator, source);
        stream.deinit();
    }

    const parallel_time = timer.read();
    const parallel_per_scan = @as(f64, @floatFromInt(parallel_time / iterations)) / 1000.0;

    const speedup = sequential_per_scan / parallel_per_scan;

    std.debug.print("  Sequential: {d:>8.2}μs per scan\n", .{sequential_per_scan});
    std.debug.print("  Smart:      {d:>8.2}μs per scan\n", .{parallel_per_scan});
    std.debug.print("  Speedup:    {d:>8.2}x\n\n", .{speedup});
}

fn benchmarkMediumInput() !void {
    const allocator = std.heap.page_allocator;

    // Generate medium-sized source
    var source_list = try std.ArrayList(u8).initCapacity(allocator, 2048);
    defer source_list.deinit(allocator);

    var i: usize = 0;
    while (i < 50) : (i += 1) {
        try source_list.appendSlice(allocator, "fun test");
        try source_list.writer(allocator).print("{d}", .{i});
        try source_list.appendSlice(allocator, "() { var x = ");
        try source_list.writer(allocator).print("{d}", .{i});
        try source_list.appendSlice(allocator, "; return x; }\n");
    }

    const source = try source_list.toOwnedSlice(allocator);
    defer allocator.free(source);

    std.debug.print("Medium Input ({d} bytes):\n", .{source.len});

    // Sequential
    var timer = try std.time.Timer.start();
    const iterations: u32 = 1_000;

    var j: u32 = 0;
    while (j < iterations) : (j += 1) {
        var stream = try parallel.scanSequentialOnly(allocator, source);
        stream.deinit();
    }

    const sequential_time = timer.read();
    const sequential_per_scan = @as(f64, @floatFromInt(sequential_time / iterations)) / 1000.0;

    // Parallel
    timer.reset();
    j = 0;
    while (j < iterations) : (j += 1) {
        var stream = try parallel.scanSmart(allocator, source);
        stream.deinit();
    }

    const parallel_time = timer.read();
    const parallel_per_scan = @as(f64, @floatFromInt(parallel_time / iterations)) / 1000.0;

    const speedup = sequential_per_scan / parallel_per_scan;

    std.debug.print("  Sequential: {d:>8.2}μs per scan\n", .{sequential_per_scan});
    std.debug.print("  Smart:      {d:>8.2}μs per scan\n", .{parallel_per_scan});
    std.debug.print("  Speedup:    {d:>8.2}x\n\n", .{speedup});
}

fn benchmarkLargeInput() !void {
    const allocator = std.heap.page_allocator;

    // Generate large source
    var source_list = try std.ArrayList(u8).initCapacity(allocator, 16384);
    defer source_list.deinit(allocator);

    var i: usize = 0;
    while (i < 500) : (i += 1) {
        try source_list.appendSlice(allocator, "fun test");
        try source_list.writer(allocator).print("{d}", .{i});
        try source_list.appendSlice(allocator, "() {\n");
        try source_list.appendSlice(allocator, "    var x = ");
        try source_list.writer(allocator).print("{d}", .{i});
        try source_list.appendSlice(allocator, ";\n");
        try source_list.appendSlice(allocator, "    var y = ");
        try source_list.writer(allocator).print("{d}", .{i * 2});
        try source_list.appendSlice(allocator, ";\n");
        try source_list.appendSlice(allocator, "    return x + y;\n");
        try source_list.appendSlice(allocator, "}\n\n");
    }

    const source = try source_list.toOwnedSlice(allocator);
    defer allocator.free(source);

    std.debug.print("Large Input ({d} bytes):\n", .{source.len});

    // Sequential
    var timer = try std.time.Timer.start();
    const iterations: u32 = 100;

    var j: u32 = 0;
    while (j < iterations) : (j += 1) {
        var stream = try parallel.scanSequentialOnly(allocator, source);
        stream.deinit();
    }

    const sequential_time = timer.read();
    const sequential_per_scan = @as(f64, @floatFromInt(sequential_time / iterations)) / 1000.0;

    // Parallel
    timer.reset();
    j = 0;
    while (j < iterations) : (j += 1) {
        var stream = try parallel.scanSmart(allocator, source);
        stream.deinit();
    }

    const parallel_time = timer.read();
    const parallel_per_scan = @as(f64, @floatFromInt(parallel_time / iterations)) / 1000.0;

    const speedup = sequential_per_scan / parallel_per_scan;

    std.debug.print("  Sequential: {d:>8.2}μs per scan\n", .{sequential_per_scan});
    std.debug.print("  Smart:      {d:>8.2}μs per scan\n", .{parallel_per_scan});
    std.debug.print("  Speedup:    {d:>8.2}x\n\n", .{speedup});
}

fn benchmarkVeryLargeInput() !void {
    const allocator = std.heap.page_allocator;

    // Generate very large source
    var source_list = try std.ArrayList(u8).initCapacity(allocator, 65536);
    defer source_list.deinit(allocator);

    var i: usize = 0;
    while (i < 2000) : (i += 1) {
        try source_list.appendSlice(allocator, "fun fibonacci");
        try source_list.writer(allocator).print("{d}", .{i});
        try source_list.appendSlice(allocator, "(n) {\n");
        try source_list.appendSlice(allocator, "    if (n <= 1) return n;\n");
        try source_list.appendSlice(allocator, "    return fibonacci");
        try source_list.writer(allocator).print("{d}", .{i});
        try source_list.appendSlice(allocator, "(n - 1) + fibonacci");
        try source_list.writer(allocator).print("{d}", .{i});
        try source_list.appendSlice(allocator, "(n - 2);\n");
        try source_list.appendSlice(allocator, "}\n\n");
    }

    const source = try source_list.toOwnedSlice(allocator);
    defer allocator.free(source);

    std.debug.print("Very Large Input ({d} bytes):\n", .{source.len});

    // Sequential
    var timer = try std.time.Timer.start();
    const iterations: u32 = 20;

    var j: u32 = 0;
    while (j < iterations) : (j += 1) {
        var stream = try parallel.scanSequentialOnly(allocator, source);
        stream.deinit();
    }

    const sequential_time = timer.read();
    const sequential_per_scan = @as(f64, @floatFromInt(sequential_time / iterations)) / 1000.0;

    // Parallel
    timer.reset();
    j = 0;
    while (j < iterations) : (j += 1) {
        var stream = try parallel.scanSmart(allocator, source);
        stream.deinit();
    }

    const parallel_time = timer.read();
    const parallel_per_scan = @as(f64, @floatFromInt(parallel_time / iterations)) / 1000.0;

    const speedup = sequential_per_scan / parallel_per_scan;

    std.debug.print("  Sequential: {d:>8.2}μs per scan\n", .{sequential_per_scan});
    std.debug.print("  Smart:      {d:>8.2}μs per scan\n", .{parallel_per_scan});
    std.debug.print("  Speedup:    {d:>8.2}x\n\n", .{speedup});
}

fn benchmarkSmartScanning() !void {
    const allocator = std.heap.page_allocator;

    // Generate medium-large source (~150KB, above smart threshold)
    var source_list = try std.ArrayList(u8).initCapacity(allocator, 160000);
    defer source_list.deinit(allocator);

    var i: usize = 0;
    while (i < 3000) : (i += 1) {
        try source_list.appendSlice(allocator, "fun test");
        try source_list.writer(allocator).print("{d}", .{i});
        try source_list.appendSlice(allocator, "() {\n");
        try source_list.appendSlice(allocator, "    var x = ");
        try source_list.writer(allocator).print("{d}", .{i});
        try source_list.appendSlice(allocator, ";\n");
        try source_list.appendSlice(allocator, "    return x * 2;\n");
        try source_list.appendSlice(allocator, "}\n\n");
    }

    const source = try source_list.toOwnedSlice(allocator);
    defer allocator.free(source);

    std.debug.print("Smart Scanning Above Threshold ({d} bytes):\n", .{source.len});

    // Sequential baseline
    var timer = try std.time.Timer.start();
    const iterations: u32 = 20;

    var j: u32 = 0;
    while (j < iterations) : (j += 1) {
        var stream = try parallel.scanSequentialOnly(allocator, source);
        stream.deinit();
    }

    const sequential_time = timer.read();
    const sequential_per_scan = @as(f64, @floatFromInt(sequential_time / iterations)) / 1000.0;

    // Smart (should use parallel automatically)
    timer.reset();
    j = 0;
    while (j < iterations) : (j += 1) {
        var stream = try parallel.scanSmart(allocator, source);
        stream.deinit();
    }

    const smart_time = timer.read();
    const smart_per_scan = @as(f64, @floatFromInt(smart_time / iterations)) / 1000.0;

    const speedup = sequential_per_scan / smart_per_scan;

    std.debug.print("  Sequential: {d:>8.2}μs per scan\n", .{sequential_per_scan});
    std.debug.print("  Smart:      {d:>8.2}μs per scan (auto-parallel)\n", .{smart_per_scan});
    std.debug.print("  Speedup:    {d:>8.2}x\n\n", .{speedup});
}

fn benchmarkScaling() !void {
    const allocator = std.heap.page_allocator;

    // Generate large source for scaling test
    var source_list = try std.ArrayList(u8).initCapacity(allocator, 32768);
    defer source_list.deinit(allocator);

    var i: usize = 0;
    while (i < 1000) : (i += 1) {
        try source_list.appendSlice(allocator, "fun test");
        try source_list.writer(allocator).print("{d}", .{i});
        try source_list.appendSlice(allocator, "() {\n");
        try source_list.appendSlice(allocator, "    var x = ");
        try source_list.writer(allocator).print("{d}", .{i});
        try source_list.appendSlice(allocator, ";\n");
        try source_list.appendSlice(allocator, "    return x * 2;\n");
        try source_list.appendSlice(allocator, "}\n\n");
    }

    const source = try source_list.toOwnedSlice(allocator);
    defer allocator.free(source);

    std.debug.print("Thread Scaling ({d} bytes):\n", .{source.len});

    const thread_counts = [_]usize{ 1, 2, 4, 8 };
    const iterations: u32 = 50;

    for (thread_counts) |thread_count| {
        const config = parallel.ParallelConfig{
            .num_threads = thread_count,
            .min_chunk_size = 32768, // 32KB
            .target_chunk_size = 131072, // 128KB
            .parallel_threshold = 0, // Force parallel regardless of size
        };

        var timer = try std.time.Timer.start();

        var j: u32 = 0;
        while (j < iterations) : (j += 1) {
            var stream = try parallel.scanParallel(allocator, source, config);
            stream.deinit();
        }

        const elapsed = timer.read();
        const per_scan = @as(f64, @floatFromInt(elapsed / iterations)) / 1000.0;

        std.debug.print("  {d} thread(s): {d:>8.2}μs per scan\n", .{ thread_count, per_scan });
    }

    std.debug.print("\n", .{});
}
