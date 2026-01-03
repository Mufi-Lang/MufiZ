const std = @import("std");
const print = std.debug.print;
const Timer = std.time.Timer;
const Allocator = std.mem.Allocator;

// Import both scanner versions for comparison
const scanner_original = @import("scanner.zig");
const scanner_optimized = @import("scanner_optimized.zig");

// Test data for benchmarking
const BenchmarkData = struct {
    name: []const u8,
    source: []const u8,
    expected_tokens: usize,
    description: []const u8,
};

const BENCHMARK_TESTS = [_]BenchmarkData{
    .{
        .name = "keywords_heavy",
        .source = "if else while for fun let var const and or true false nil class self super return break continue switch case end foreach in item print",
        .expected_tokens = 25,
        .description = "Heavy keyword usage test",
    },
    .{
        .name = "numbers_mixed",
        .source = "123 456 789.123 0.456 1.0 2.5 3+4i 5.5-2.3i 0i 42i 3.14159 2.71828 1e10 1.5e-5",
        .expected_tokens = 14,
        .description = "Mixed number formats including complex",
    },
    .{
        .name = "identifiers_long",
        .source = "very_long_identifier_name another_extremely_long_variable_name some_function_with_a_really_long_name class_with_very_descriptive_name",
        .expected_tokens = 4,
        .description = "Long identifier names",
    },
    .{
        .name = "operators_heavy",
        .source = "+ - * / % == != <= >= < > = += -= *= /= ++ -- -> .. ..= ^ ! && ||",
        .expected_tokens = 22,
        .description = "Heavy operator usage",
    },
    .{
        .name = "strings_complex",
        .source = "\"simple string\" \"string with \\\"escaped quotes\\\"\" \"multi\\nline\\tstring\" f\"formatted {variable} string\" `multiline\nbacktick\nstring`",
        .expected_tokens = 5,
        .description = "Complex string literals",
    },
    .{
        .name = "whitespace_heavy",
        .source = "   \t\n  if   \t\n  (   \t\n  condition   \t\n  )   \t\n  {   \t\n    \t// comment\n    return   \t\n  42   \t\n  ;   \t\n  }   \t\n  ",
        .expected_tokens = 8,
        .description = "Heavy whitespace and comments",
    },
    .{
        .name = "real_code_sample",
        .source =
        \\fun fibonacci(n) {
        \\    if (n <= 1) {
        \\        return n;
        \\    }
        \\    return fibonacci(n - 1) + fibonacci(n - 2);
        \\}
        \\
        \\let result = fibonacci(10);
        \\print("Fibonacci(10) = " + str(result));
        ,
        .expected_tokens = 37,
        .description = "Realistic code sample",
    },
    .{
        .name = "large_program",
        .source =
        \\class Calculator {
        \\    fun init(self) {
        \\        self.memory = 0;
        \\        self.history = linked_list();
        \\    }
        \\
        \\    fun add(self, a, b) {
        \\        let result = a + b;
        \\        push(self.history, result);
        \\        return result;
        \\    }
        \\
        \\    fun multiply(self, a, b) {
        \\        let result = a * b;
        \\        push(self.history, result);
        \\        return result;
        \\    }
        \\
        \\    fun clear_history(self) {
        \\        clear(self.history);
        \\    }
        \\}
        \\
        \\let calc = Calculator();
        \\calc.init();
        \\let sum = calc.add(5, 3);
        \\let product = calc.multiply(sum, 2);
        \\print("Result: " + str(product));
        ,
        .expected_tokens = 79,
        .description = "Large program with classes and methods",
    },
};

const BenchmarkResult = struct {
    name: []const u8,
    original_time_ns: u64,
    optimized_time_ns: u64,
    original_tokens: usize,
    optimized_tokens: usize,
    speedup: f64,
    tokens_per_second_original: f64,
    tokens_per_second_optimized: f64,
};

// Token counting function for original scanner
fn countTokensOriginal(source: []const u8, allocator: Allocator) !usize {
    // Convert to null-terminated string for original scanner
    const source_nt = try allocator.dupeZ(u8, source);
    defer allocator.free(source_nt);

    scanner_original.init_scanner(@ptrCast(source_nt.ptr));

    var count: usize = 0;
    while (true) {
        const token = scanner_original.scanToken();
        count += 1;
        if (token.type == .TOKEN_EOF or token.type == .TOKEN_ERROR) {
            break;
        }
    }

    return count;
}

// Token counting function for optimized scanner
fn countTokensOptimized(source: []const u8) usize {
    // Convert to null-terminated string for optimized scanner
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const source_nt = arena.allocator().dupeZ(u8, source) catch return 0;

    scanner_optimized.init_scanner(@ptrCast(source_nt.ptr));

    var count: usize = 0;
    while (true) {
        const token = scanner_optimized.scanToken();
        count += 1;
        if (token.type == .TOKEN_EOF or token.type == .TOKEN_ERROR) {
            break;
        }
    }

    return count;
}

// Benchmark a single test case
fn benchmarkSingle(test_data: BenchmarkData, allocator: Allocator, iterations: usize) !BenchmarkResult {
    print("Benchmarking: {s}...\n", .{test_data.name});

    // Warm up
    _ = try countTokensOriginal(test_data.source, allocator);
    _ = countTokensOptimized(test_data.source);

    // Benchmark original scanner
    var timer = try Timer.start();
    const start_original = timer.lap();

    var original_tokens: usize = 0;
    for (0..iterations) |_| {
        original_tokens = try countTokensOriginal(test_data.source, allocator);
    }

    const end_original = timer.lap();
    const original_time = end_original - start_original;

    // Benchmark optimized scanner
    const start_optimized = timer.lap();

    var optimized_tokens: usize = 0;
    for (0..iterations) |_| {
        optimized_tokens = countTokensOptimized(test_data.source);
    }

    const end_optimized = timer.lap();
    const optimized_time = end_optimized - start_optimized;

    // Calculate metrics
    const speedup = @as(f64, @floatFromInt(original_time)) / @as(f64, @floatFromInt(optimized_time));
    const tokens_per_sec_original = @as(f64, @floatFromInt(original_tokens * iterations)) / (@as(f64, @floatFromInt(original_time)) / 1e9);
    const tokens_per_sec_optimized = @as(f64, @floatFromInt(optimized_tokens * iterations)) / (@as(f64, @floatFromInt(optimized_time)) / 1e9);

    return BenchmarkResult{
        .name = test_data.name,
        .original_time_ns = original_time,
        .optimized_time_ns = optimized_time,
        .original_tokens = original_tokens,
        .optimized_tokens = optimized_tokens,
        .speedup = speedup,
        .tokens_per_second_original = tokens_per_sec_original,
        .tokens_per_second_optimized = tokens_per_sec_optimized,
    };
}

// Print detailed results
fn printResults(results: []const BenchmarkResult) void {
    print("\n" ++ "=" ** 120 ++ "\n", .{});
    print("SCANNER BENCHMARK RESULTS\n", .{});
    print("=" ** 120 ++ "\n", .{});

    // Header
    print("{s:<20} {s:>12} {s:>12} {s:>10} {s:>15} {s:>15} {s:>10}\n", .{ "Test Name", "Original(μs)", "Optimized(μs)", "Speedup", "Orig Tok/sec", "Opt Tok/sec", "Tokens" });
    print("-" ** 120 ++ "\n", .{});

    var total_speedup: f64 = 0;
    var total_original_time: u64 = 0;
    var total_optimized_time: u64 = 0;

    for (results) |result| {
        const orig_us = @as(f64, @floatFromInt(result.original_time_ns)) / 1000.0;
        const opt_us = @as(f64, @floatFromInt(result.optimized_time_ns)) / 1000.0;

        print("{s:<20} {d:>12.1} {d:>12.1} {d:>10.2}x {d:>15.0} {d:>15.0} {d:>10}\n", .{
            result.name,
            orig_us,
            opt_us,
            result.speedup,
            result.tokens_per_second_original,
            result.tokens_per_second_optimized,
            result.original_tokens,
        });

        total_speedup += result.speedup;
        total_original_time += result.original_time_ns;
        total_optimized_time += result.optimized_time_ns;

        // Verify token counts match
        if (result.original_tokens != result.optimized_tokens) {
            print("   ⚠️  Token count mismatch! Original: {}, Optimized: {}\n", .{ result.original_tokens, result.optimized_tokens });
        }
    }

    print("-" ** 120 ++ "\n", .{});

    const avg_speedup = total_speedup / @as(f64, @floatFromInt(results.len));
    const overall_speedup = @as(f64, @floatFromInt(total_original_time)) / @as(f64, @floatFromInt(total_optimized_time));

    print("SUMMARY:\n", .{});
    print("  Average Speedup:  {d:.2}x\n", .{avg_speedup});
    print("  Overall Speedup:  {d:.2}x\n", .{overall_speedup});
    print("  Total Time Saved: {d:.1}ms\n", .{@as(f64, @floatFromInt(total_original_time - total_optimized_time)) / 1e6});

    // Performance analysis
    print("\nPERFORMANCE ANALYSIS:\n", .{});
    if (overall_speedup >= 2.5) {
        print("  🚀 Excellent performance improvement!\n", .{});
    } else if (overall_speedup >= 2.0) {
        print("  ✅ Very good performance improvement!\n", .{});
    } else if (overall_speedup >= 1.5) {
        print("  👍 Good performance improvement!\n", .{});
    } else if (overall_speedup >= 1.1) {
        print("  📈 Modest performance improvement.\n", .{});
    } else {
        print("  ⚠️  Performance improvement is minimal.\n", .{});
    }

    print("\nBEST PERFORMING TESTS:\n", .{});
    var best_speedup: f64 = 0;
    var best_test: []const u8 = "";
    for (results) |result| {
        if (result.speedup > best_speedup) {
            best_speedup = result.speedup;
            best_test = result.name;
        }
    }
    print("  {s}: {d:.2}x speedup\n", .{ best_test, best_speedup });
}

// Memory usage profiler
fn profileMemoryUsage(allocator: Allocator) !void {
    print("\nMEMORY USAGE ANALYSIS:\n", .{});
    print("-" ** 50 ++ "\n", .{});

    const test_source = "if while for class fun let var const and or true false nil";

    // Profile original scanner memory usage
    const original_start = try allocator.dupeZ(u8, test_source);
    defer allocator.free(original_start);

    print("Original Scanner:\n", .{});
    print("  Source storage: {} bytes (null-terminated)\n", .{original_start.len});
    print("  HashMap overhead: ~2KB\n", .{});
    print("  Total estimated: ~{}KB\n", .{(original_start.len + 2048) / 1024});

    print("\nOptimized Scanner:\n", .{});
    print("  Source storage: {} bytes (slice)\n", .{test_source.len});
    print("  Lookup tables: 768 bytes (3×256)\n", .{});
    print("  Keyword table: ~512 bytes\n", .{});
    print("  Total estimated: ~{}KB\n", .{(test_source.len + 768 + 512) / 1024});

    const memory_savings = @as(f64, @floatFromInt(2048 - (768 + 512))) / 2048.0 * 100.0;
    print("  Memory savings: {d:.1}%\n", .{memory_savings});
}

// Feature compatibility test
fn testCompatibility(allocator: Allocator) !void {
    print("\nCOMPATIBILITY TEST:\n", .{});
    print("-" ** 50 ++ "\n", .{});

    const compatibility_tests = [_]struct { source: []const u8, description: []const u8 }{
        .{ .source = "123", .description = "Integer literal" },
        .{ .source = "123.456", .description = "Float literal" },
        .{ .source = "3+4i", .description = "Complex number" },
        .{ .source = "\"hello world\"", .description = "String literal" },
        .{ .source = "identifier_name", .description = "Identifier" },
        .{ .source = "if", .description = "Keyword" },
        .{ .source = "// comment", .description = "Single-line comment" },
        .{ .source = "/# multi\nline\ncomment #/", .description = "Multi-line comment" },
        .{ .source = "+ - * / %", .description = "Arithmetic operators" },
        .{ .source = "== != <= >=", .description = "Comparison operators" },
        .{ .source = "f\"format {var}\"", .description = "F-string" },
        .{ .source = "`multiline\nstring`", .description = "Backtick string" },
    };

    var all_compatible = true;

    for (compatibility_tests) |test_case| {
        const original_count = countTokensOriginal(test_case.source, allocator) catch |err| {
            print("  ❌ {s}: Original scanner error: {}\n", .{ test_case.description, err });
            all_compatible = false;
            continue;
        };

        const optimized_count = countTokensOptimized(test_case.source);

        if (original_count == optimized_count) {
            print("  ✅ {s}: {} tokens\n", .{ test_case.description, original_count });
        } else {
            print("  ❌ {s}: Original={}, Optimized={}\n", .{ test_case.description, original_count, optimized_count });
            all_compatible = false;
        }
    }

    if (all_compatible) {
        print("\n🎉 All compatibility tests passed!\n", .{});
    } else {
        print("\n⚠️  Some compatibility issues detected.\n", .{});
    }
}

// Main benchmark function
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    print("MufiZ Scanner Benchmark Suite\n", .{});
    print("============================\n\n", .{});

    // Get command line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var iterations: usize = 1000;
    if (args.len > 1) {
        iterations = std.fmt.parseInt(usize, args[1], 10) catch 1000;
    }

    print("Running {} iterations per test...\n\n", .{iterations});

    // Run compatibility test first
    try testCompatibility(allocator);

    // Run benchmarks
    var results: [BENCHMARK_TESTS.len]BenchmarkResult = undefined;

    for (BENCHMARK_TESTS, 0..) |test_data, i| {
        const result = try benchmarkSingle(test_data, allocator, iterations);
        results[i] = result;
    }

    printResults(&results);

    // Memory analysis
    try profileMemoryUsage(allocator);

    print("\n" ++ "=" ** 120 ++ "\n", .{});
    print("Benchmark completed successfully!\n", .{});
    print("Usage: zig run scanner_benchmark.zig -- [iterations]\n", .{});
    print("=" ** 120 ++ "\n", .{});
}

// Stress test function for long-running performance analysis
pub fn stressTest(allocator: Allocator, duration_seconds: u64) !void {
    print("\nSTRESS TEST ({} seconds):\n", .{duration_seconds});
    print("-" ** 50 ++ "\n");

    const large_source =
        \\// Large program for stress testing
        \\class LargeClass {
        \\    fun method1(self, param1, param2, param3) {
        \\        if (param1 > param2) {
        \\            for (let i = 0; i < param3; i++) {
        \\                let result = param1 + param2 * i;
        \\                if (result > 100) {
        \\                    break;
        \\                }
        \\                print("Result: " + str(result));
        \\            }
        \\        } else {
        \\            while (param2 < param3) {
        \\                param2 = param2 + param1;
        \\                if (param2 % 2 == 0) {
        \\                    continue;
        \\                }
        \\                print("Even: " + str(param2));
        \\            }
        \\        }
        \\        return param1 + param2 + param3;
        \\    }
        \\}
    ;

    var timer = try Timer.start();
    const end_time = timer.read() + duration_seconds * std.time.ns_per_s;

    var original_iterations: u64 = 0;
    var optimized_iterations: u64 = 0;

    print("Running stress test...\n", .{});

    while (timer.read() < end_time) {
        // Test original scanner
        const start = timer.read();
        _ = try countTokensOriginal(large_source, allocator);
        const original_time = timer.read() - start;

        // Test optimized scanner
        const start2 = timer.read();
        _ = countTokensOptimized(large_source);
        const optimized_time = timer.read() - start2;

        original_iterations += 1;

        // Run optimized scanner multiple times to match original time
        while (optimized_time * optimized_iterations < original_time * original_iterations) {
            _ = countTokensOptimized(large_source);
            optimized_iterations += 1;
        }
    }

    const actual_duration = @as(f64, @floatFromInt(timer.read())) / std.time.ns_per_s;
    const original_rate = @as(f64, @floatFromInt(original_iterations)) / actual_duration;
    const optimized_rate = @as(f64, @floatFromInt(optimized_iterations)) / actual_duration;
    const stress_speedup = optimized_rate / original_rate;

    print("Stress test completed!\n", .{});
    print("  Duration: {d:.1}s\n", .{actual_duration});
    print("  Original: {d:.0} scans/sec\n", .{original_rate});
    print("  Optimized: {d:.0} scans/sec\n", .{optimized_rate});
    print("  Speedup: {d:.2}x\n", .{stress_speedup});
}
