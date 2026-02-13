const std = @import("std");
const simd_utils = @import("simd_utils.zig");
const fvec_simd = @import("objects/fvec_simd.zig");

/// Benchmark utilities for comparing SIMD implementations
pub fn main() !void {
    std.debug.print("\n=== MufiZ SIMD Benchmark ===\n\n", .{});

    // Print system capabilities
    std.debug.print("System Information:\n", .{});
    std.debug.print("  Architecture: {s}\n", .{simd_utils.getArchitectureName()});
    const caps = simd_utils.getCapabilities();
    std.debug.print("  SIMD Available: {}\n", .{caps.available});
    std.debug.print("  f64 Vector Length: {}\n", .{caps.f64_vector_len});
    std.debug.print("  u8 Vector Length: {}\n\n", .{caps.u8_vector_len});

    // Run benchmarks
    try benchmarkMemoryOperations();
    try benchmarkVectorOperations();
    try benchmarkStatisticalOperations();

    std.debug.print("\n=== Benchmark Complete ===\n", .{});
}

fn benchmarkMemoryOperations() !void {
    std.debug.print("Memory Operations Benchmark:\n", .{});
    std.debug.print("  (Note: SIMD threshold = {} bytes)\n", .{simd_utils.config.min_memory_simd_size});
    std.debug.print("-" ** 50 ++ "\n", .{});

    const sizes = [_]usize{ 64, 256, 512, 1024, 4096, 16384, 65536 };

    for (sizes) |size| {
        var src: []u8 = try std.heap.page_allocator.alloc(u8, size);
        defer std.heap.page_allocator.free(src);
        var dst: []u8 = try std.heap.page_allocator.alloc(u8, size);
        defer std.heap.page_allocator.free(dst);

        // Initialize source
        for (0..size) |i| {
            src[i] = @intCast(i % 256);
        }

        // Benchmark memcpy
        const iterations: usize = 10000;

        // Scalar version
        var timer = try std.time.Timer.start();
        for (0..iterations) |_| {
            @memcpy(dst, src);
            std.mem.doNotOptimizeAway(&dst);
        }
        const scalar_time = timer.read();

        // SIMD version
        timer.reset();
        for (0..iterations) |_| {
            simd_utils.SimdMemory.copy(dst.ptr, src.ptr, size);
            std.mem.doNotOptimizeAway(&dst);
        }
        const simd_time = timer.read();

        const speedup = @as(f64, @floatFromInt(scalar_time)) / @as(f64, @floatFromInt(simd_time));
        const using_simd = if (size >= simd_utils.config.min_memory_simd_size) "SIMD" else "Scalar";
        std.debug.print("  Size: {d:>6} bytes | Scalar: {d:>8}ns | SIMD: {d:>8}ns | Speedup: {d:.2}x [{s}]\n", .{ size, scalar_time / iterations, simd_time / iterations, speedup, using_simd });
    }
    std.debug.print("\n", .{});

    // Test with lower threshold to show improvement
    std.debug.print("Memory Operations with Aggressive SIMD (threshold=256):\n", .{});
    std.debug.print("-" ** 50 ++ "\n", .{});

    const old_threshold = simd_utils.config.min_memory_simd_size;
    simd_utils.config.min_memory_simd_size = 256;

    const test_sizes = [_]usize{ 256, 512, 1024, 4096, 16384 };
    for (test_sizes) |size| {
        var src: []u8 = try std.heap.page_allocator.alloc(u8, size);
        defer std.heap.page_allocator.free(src);
        var dst: []u8 = try std.heap.page_allocator.alloc(u8, size);
        defer std.heap.page_allocator.free(dst);

        for (0..size) |i| {
            src[i] = @intCast(i % 256);
        }

        const iterations: usize = 10000;

        // Scalar version
        var timer = try std.time.Timer.start();
        for (0..iterations) |_| {
            @memcpy(dst, src);
            std.mem.doNotOptimizeAway(&dst);
        }
        const scalar_time = timer.read();

        // SIMD version
        timer.reset();
        for (0..iterations) |_| {
            simd_utils.SimdMemory.copy(dst.ptr, src.ptr, size);
            std.mem.doNotOptimizeAway(&dst);
        }
        const simd_time = timer.read();

        const speedup = @as(f64, @floatFromInt(scalar_time)) / @as(f64, @floatFromInt(simd_time));
        std.debug.print("  Size: {d:>6} bytes | Scalar: {d:>8}ns | SIMD: {d:>8}ns | Speedup: {d:.2}x\n", .{ size, scalar_time / iterations, simd_time / iterations, speedup });
    }

    // Restore threshold
    simd_utils.config.min_memory_simd_size = old_threshold;
    std.debug.print("\n", .{});
}

fn benchmarkVectorOperations() !void {
    std.debug.print("Vector Operations Benchmark (f64):\n", .{});
    std.debug.print("-" ** 50 ++ "\n", .{});

    const sizes = [_]usize{ 16, 64, 256, 1024, 4096 };

    for (sizes) |size| {
        var a: []f64 = try std.heap.page_allocator.alloc(f64, size);
        defer std.heap.page_allocator.free(a);
        var b: []f64 = try std.heap.page_allocator.alloc(f64, size);
        defer std.heap.page_allocator.free(b);
        var result: []f64 = try std.heap.page_allocator.alloc(f64, size);
        defer std.heap.page_allocator.free(result);

        // Initialize data
        for (0..size) |i| {
            a[i] = @floatFromInt(i);
            b[i] = @floatFromInt(i * 2);
        }

        const iterations: usize = 10000;

        // Benchmark Addition
        {
            // Scalar version
            var timer = try std.time.Timer.start();
            for (0..iterations) |_| {
                for (0..size) |i| {
                    result[i] = a[i] + b[i];
                }
                std.mem.doNotOptimizeAway(&result);
            }
            const scalar_time = timer.read();

            // SIMD version
            timer.reset();
            for (0..iterations) |_| {
                simd_utils.SimdF64.add(result, a, b);
                std.mem.doNotOptimizeAway(&result);
            }
            const simd_time = timer.read();

            const speedup = @as(f64, @floatFromInt(scalar_time)) / @as(f64, @floatFromInt(simd_time));
            std.debug.print("  ADD  | Size: {d:>5} | Scalar: {d:>7}ns | SIMD: {d:>7}ns | Speedup: {d:.2}x\n", .{ size, scalar_time / iterations, simd_time / iterations, speedup });
        }

        // Benchmark Multiplication
        {
            // Scalar version
            var timer = try std.time.Timer.start();
            for (0..iterations) |_| {
                for (0..size) |i| {
                    result[i] = a[i] * b[i];
                }
                std.mem.doNotOptimizeAway(&result);
            }
            const scalar_time = timer.read();

            // SIMD version
            timer.reset();
            for (0..iterations) |_| {
                simd_utils.SimdF64.mul(result, a, b);
                std.mem.doNotOptimizeAway(&result);
            }
            const simd_time = timer.read();

            const speedup = @as(f64, @floatFromInt(scalar_time)) / @as(f64, @floatFromInt(simd_time));
            std.debug.print("  MUL  | Size: {d:>5} | Scalar: {d:>7}ns | SIMD: {d:>7}ns | Speedup: {d:.2}x\n", .{ size, scalar_time / iterations, simd_time / iterations, speedup });
        }

        // Benchmark Scale
        {
            const scalar_val: f64 = 2.5;

            // Scalar version
            var timer = try std.time.Timer.start();
            for (0..iterations) |_| {
                for (0..size) |i| {
                    result[i] = a[i] * scalar_val;
                }
                std.mem.doNotOptimizeAway(&result);
            }
            const scalar_time = timer.read();

            // SIMD version
            timer.reset();
            for (0..iterations) |_| {
                simd_utils.SimdF64.scale(result, a, scalar_val);
                std.mem.doNotOptimizeAway(&result);
            }
            const simd_time = timer.read();

            const speedup = @as(f64, @floatFromInt(scalar_time)) / @as(f64, @floatFromInt(simd_time));
            std.debug.print("  SCALE| Size: {d:>5} | Scalar: {d:>7}ns | SIMD: {d:>7}ns | Speedup: {d:.2}x\n", .{ size, scalar_time / iterations, simd_time / iterations, speedup });
        }

        std.debug.print("\n", .{});
    }
}

fn benchmarkStatisticalOperations() !void {
    std.debug.print("Statistical Operations Benchmark (f64):\n", .{});
    std.debug.print("-" ** 50 ++ "\n", .{});

    const sizes = [_]usize{ 64, 256, 1024, 4096, 16384 };

    for (sizes) |size| {
        var data: []f64 = try std.heap.page_allocator.alloc(f64, size);
        defer std.heap.page_allocator.free(data);

        // Initialize data
        for (0..size) |i| {
            data[i] = @floatFromInt(i);
        }

        const iterations: usize = 10000;

        // Benchmark Sum
        {
            // Scalar version
            var timer = try std.time.Timer.start();
            var result: f64 = 0;
            for (0..iterations) |_| {
                var sum: f64 = 0.0;
                for (data) |val| {
                    sum += val;
                }
                result = sum;
            }
            std.mem.doNotOptimizeAway(&result);
            const scalar_time = timer.read();

            // SIMD version
            timer.reset();
            for (0..iterations) |_| {
                result = simd_utils.SimdF64.sum(data);
            }
            std.mem.doNotOptimizeAway(&result);
            const simd_time = timer.read();

            const speedup = @as(f64, @floatFromInt(scalar_time)) / @as(f64, @floatFromInt(simd_time));
            std.debug.print("  SUM  | Size: {d:>6} | Scalar: {d:>8}ns | SIMD: {d:>8}ns | Speedup: {d:.2}x\n", .{ size, scalar_time / iterations, simd_time / iterations, speedup });
        }

        // Benchmark Variance
        {
            const mean_val = fvec_simd.mean(data);

            // Scalar version
            var timer = try std.time.Timer.start();
            var result: f64 = 0;
            for (0..iterations) |_| {
                var sum_sq: f64 = 0.0;
                for (data) |val| {
                    const diff = val - mean_val;
                    sum_sq += diff * diff;
                }
                result = sum_sq / @as(f64, @floatFromInt(size));
            }
            std.mem.doNotOptimizeAway(&result);
            const scalar_time = timer.read();

            // SIMD version
            timer.reset();
            for (0..iterations) |_| {
                result = simd_utils.SimdF64.variance(data, mean_val);
            }
            std.mem.doNotOptimizeAway(&result);
            const simd_time = timer.read();

            const speedup = @as(f64, @floatFromInt(scalar_time)) / @as(f64, @floatFromInt(simd_time));
            std.debug.print("  VAR  | Size: {d:>6} | Scalar: {d:>8}ns | SIMD: {d:>8}ns | Speedup: {d:.2}x\n", .{ size, scalar_time / iterations, simd_time / iterations, speedup });
        }
    }
    std.debug.print("\n", .{});
}

test "simd benchmark" {
    // This test just ensures the benchmark code compiles
    const testing = std.testing;
    try testing.expect(true);
}
