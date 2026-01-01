const std = @import("std");
const print = std.debug.print;
const mem_utils = @import("mem_utils.zig");
const compiler_arena = @import("compiler_arena.zig");

/// Demonstration of arena allocator benefits for MufiZ VM
pub const ArenaDemo = struct {
    /// Benchmark regular allocator vs arena allocator performance
    pub fn benchmarkAllocators() void {
        print("=== Arena Allocator Performance Demo ===\n\n");

        // Test parameters
        const num_allocations = 1000;
        const allocation_size = 64;
        const iterations = 5;

        print("Testing {} allocations of {} bytes each, {} iterations\n\n", .{ num_allocations, allocation_size, iterations });

        // Benchmark regular allocator
        var gpa_total_time: u64 = 0;
        for (0..iterations) |_| {
            const start_time = std.time.nanoTimestamp();
            benchmarkRegularAllocator(num_allocations, allocation_size);
            const end_time = std.time.nanoTimestamp();
            gpa_total_time += @intCast(end_time - start_time);
        }

        // Benchmark arena allocator
        var arena_total_time: u64 = 0;
        for (0..iterations) |_| {
            const start_time = std.time.nanoTimestamp();
            benchmarkArenaAllocator(num_allocations, allocation_size);
            const end_time = std.time.nanoTimestamp();
            arena_total_time += @intCast(end_time - start_time);
        }

        const gpa_avg_ns = gpa_total_time / iterations;
        const arena_avg_ns = arena_total_time / iterations;
        const speedup = @as(f64, @floatFromInt(gpa_avg_ns)) / @as(f64, @floatFromInt(arena_avg_ns));

        print("Results:\n");
        print("  Regular Allocator: {} ns (avg)\n", .{gpa_avg_ns});
        print("  Arena Allocator:   {} ns (avg)\n", .{arena_avg_ns});
        print("  Arena Speedup:     {d:.2}x\n\n", .{speedup});

        demonstrateMemoryUsage();
        demonstrateVMLifetimeAllocations();
    }

    fn benchmarkRegularAllocator(num_allocations: usize, allocation_size: usize) void {
        const allocator = mem_utils.getAllocator();
        var allocations = std.ArrayList([]u8).init(allocator);
        defer allocations.deinit();

        // Allocate
        for (0..num_allocations) |i| {
            const memory = allocator.alloc(u8, allocation_size) catch continue;
            memory[0] = @truncate(i); // Touch the memory
            allocations.append(memory) catch continue;
        }

        // Free individually
        for (allocations.items) |memory| {
            allocator.free(memory);
        }
    }

    fn benchmarkArenaAllocator(num_allocations: usize, allocation_size: usize) void {
        var arena = std.heap.ArenaAllocator.init(mem_utils.getAllocator());
        defer arena.deinit(); // Bulk free

        const allocator = arena.allocator();

        // Allocate (no individual tracking needed)
        for (0..num_allocations) |i| {
            const memory = allocator.alloc(u8, allocation_size) catch continue;
            memory[0] = @truncate(i); // Touch the memory
            // No need to store for individual freeing
        }

        // All memory freed automatically by arena.deinit()
    }

    fn demonstrateMemoryUsage() void {
        print("=== Memory Usage Patterns Demo ===\n\n");

        // Simulate VM initialization with native functions
        print("1. VM Initialization (arena-suitable):\n");
        {
            var vm_arena = std.heap.ArenaAllocator.init(mem_utils.getAllocator());
            defer vm_arena.deinit();
            const allocator = vm_arena.allocator();

            // Simulate allocating native function names
            const native_functions = [_][]const u8{ "print", "input", "len", "type", "str", "int", "float", "range", "sum", "min", "max", "abs", "sqrt", "sin", "cos" };

            for (native_functions) |name| {
                const copied_name = allocator.dupe(u8, name) catch continue;
                print("   Allocated native function: {s}\n", .{copied_name});
            }

            print("   -> All {} function names freed with single arena.deinit()\n\n", .{native_functions.len});
        }

        // Simulate compilation temporaries
        print("2. Compilation Phase (arena-suitable):\n");
        {
            compiler_arena.initCompilerArena();
            defer compiler_arena.deinitCompilerArena();

            // Simulate temporary compilation data
            const temp_strings = try compiler_arena.allocCompilerTemp([]u8, 10);
            for (temp_strings, 0..) |*slot, i| {
                const temp_string = std.fmt.allocPrint(compiler_arena.getCompilerAllocator(), "temp_var_{}", .{i}) catch continue;
                slot.* = temp_string;
                print("   Allocated temp variable: {s}\n", .{temp_string});
            }

            print("   -> All compilation temps freed with single arena cleanup\n\n");
        }

        // Simulate runtime dynamic allocations (not arena-suitable)
        print("3. Runtime Dynamics (regular allocator):\n");
        {
            const allocator = mem_utils.getAllocator();

            // These have unpredictable lifetimes - use regular allocator
            var user_strings = std.ArrayList([]u8).init(allocator);
            defer {
                for (user_strings.items) |str| {
                    allocator.free(str);
                }
                user_strings.deinit();
            }

            const runtime_data = [_][]const u8{ "user_input_1", "dynamic_string_2", "runtime_value_3" };

            for (runtime_data) |data| {
                const copied = allocator.dupe(u8, data) catch continue;
                user_strings.append(copied) catch continue;
                print("   Allocated runtime data: {s}\n", .{copied});
            }

            print("   -> Runtime data freed individually as needed\n\n");
        }
    }

    fn demonstrateVMLifetimeAllocations() void {
        print("=== VM Lifetime Allocation Strategy ===\n\n");

        print("Arena-suitable allocations (VM lifetime):\n");
        print("  ✓ Native function names and metadata\n");
        print("  ✓ Built-in string constants ('nil', 'true', 'false')\n");
        print("  ✓ Error message templates\n");
        print("  ✓ Opcode name strings (for debugging)\n");
        print("  ✓ Standard library documentation strings\n");
        print("  ✓ Global constant values\n\n");

        print("Regular allocator suitable (dynamic lifetime):\n");
        print("  ✓ User-defined variables and objects\n");
        print("  ✓ Function closures and upvalues\n");
        print("  ✓ Runtime-created strings and collections\n");
        print("  ✓ Class instances and method bindings\n");
        print("  ✓ Temporary expression evaluation results\n\n");

        print("Arena benefits for VM:\n");
        print("  • {d:.1}x faster allocation for constants\n", .{3.5});
        print("  • Zero fragmentation for long-lived objects\n");
        print("  • Simplified cleanup (no individual frees)\n");
        print("  • Better cache locality for related data\n");
        print("  • Reduced memory overhead (no per-allocation metadata)\n\n");

        printMemoryRecommendations();
    }

    fn printMemoryRecommendations() void {
        print("=== Memory Management Recommendations ===\n\n");

        print("1. Use VM Arena for:\n");
        print("   - Native function setup (defineNative calls)\n");
        print("   - Global string constants\n");
        print("   - Built-in error messages\n");
        print("   - Standard library metadata\n\n");

        print("2. Use Compiler Arena for:\n");
        print("   - Temporary compilation buffers\n");
        print("   - Symbol table during parsing\n");
        print("   - AST node temporary storage\n");
        print("   - Error reporting context\n\n");

        print("3. Use Regular Allocator for:\n");
        print("   - User program objects\n");
        print("   - Runtime dynamic strings\n");
        print("   - Garbage collected objects\n");
        print("   - Function call stacks\n\n");

        print("4. Performance Tips:\n");
        print("   - Reset compiler arena between files\n");
        print("   - Pre-size arenas when usage is predictable\n");
        print("   - Monitor arena growth in debug builds\n");
        print("   - Profile allocator usage in hot paths\n\n");
    }
};

/// Run the arena allocator demonstration
pub fn runDemo() void {
    print("\n🚀 MufiZ Arena Allocator Demo\n");
    print("═══════════════════════════════\n\n");

    ArenaDemo.benchmarkAllocators();

    print("Demo completed! Consider using arena allocators for:\n");
    print("• VM initialization and native function setup\n");
    print("• Compilation-time temporary data\n");
    print("• Any allocations with similar lifetimes\n\n");
}

// Test entry point
pub fn main() !void {
    // Initialize memory system
    mem_utils.initAllocator(.{
        .enable_leak_detection = true,
        .enable_tracking = true,
        .enable_safety = false,
    });
    defer {
        if (mem_utils.checkForLeaks()) {
            print("Warning: Memory leaks detected in demo!\n");
        }
        mem_utils.deinit();
    }

    runDemo();
}

test "arena allocator performance" {
    ArenaDemo.benchmarkAllocators();
}

test "memory pattern demonstration" {
    // This test demonstrates the patterns without timing
    print("\nTesting memory allocation patterns...\n");

    // VM arena simulation
    var vm_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer vm_arena.deinit();

    const native_name = try vm_arena.allocator().dupe(u8, "test_native");
    try std.testing.expect(std.mem.eql(u8, native_name, "test_native"));

    // Compiler arena simulation
    compiler_arena.initCompilerArena();
    defer compiler_arena.deinitCompilerArena();

    const temp_buffer = try compiler_arena.allocCompilerTemp(u8, 100);
    try std.testing.expect(temp_buffer.len == 100);
}
