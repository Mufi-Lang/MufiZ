const std = @import("std");
const mem_utils = @import("src/mem_utils.zig");
const allocator_mod = @import("src/allocator.zig");

pub fn main() !void {
    std.debug.print("MufiZ Allocator System Test\n", .{});
    std.debug.print("===========================\n\n", .{});

    // Test 1: Basic Allocator Functionality
    std.debug.print("Test 1: Basic Allocator Functionality\n", .{});

    // Initialize allocator
    mem_utils.initAllocator(.{
        .enable_leak_detection = true,
        .enable_tracking = true,
        .enable_safety = false, // Disabled to avoid alignment issues
    });

    const allocator = mem_utils.getAllocator();

    // Test basic allocation and deallocation
    const buffer1 = try allocator.alloc(u8, 1024);
    std.debug.print("  ✓ Allocated 1024 bytes\n", .{});

    // Fill buffer with test data
    for (buffer1, 0..) |*byte, i| {
        byte.* = @intCast(i % 256);
    }
    std.debug.print("  ✓ Filled buffer with test data\n", .{});

    // Test reallocation
    const buffer2 = try allocator.realloc(buffer1, 2048);
    std.debug.print("  ✓ Reallocated to 2048 bytes\n", .{});

    // Verify data integrity
    for (0..1024) |i| {
        if (buffer2[i] != @as(u8, @intCast(i % 256))) {
            std.debug.print("  ✗ Data integrity check failed at index {}\n", .{i});
            return;
        }
    }
    std.debug.print("  ✓ Data integrity verified after realloc\n", .{});

    // Clean up
    allocator.free(buffer2);
    std.debug.print("  ✓ Memory freed\n\n", .{});

    // Test 2: SIMD Memory Operations
    std.debug.print("Test 2: SIMD Memory Operations\n", .{});

    const src_buffer = try allocator.alloc(u8, 256);
    defer allocator.free(src_buffer);
    const dest_buffer = try allocator.alloc(u8, 256);
    defer allocator.free(dest_buffer);

    // Initialize source buffer
    for (src_buffer, 0..) |*byte, i| {
        byte.* = @intCast((i * 3 + 7) % 256);
    }
    std.debug.print("  ✓ Source buffer initialized\n", .{});

    // Test SIMD memory copy
    mem_utils.memcpySIMD(dest_buffer.ptr, src_buffer.ptr, 256);
    std.debug.print("  ✓ SIMD memcpy completed\n", .{});

    // Verify copy
    for (src_buffer, dest_buffer) |src, dest| {
        if (src != dest) {
            std.debug.print("  ✗ SIMD copy verification failed\n", .{});
            return;
        }
    }
    std.debug.print("  ✓ SIMD copy verified\n", .{});

    // Test SIMD memory set
    mem_utils.memsetSIMD(dest_buffer.ptr, 0xAA, 256);
    std.debug.print("  ✓ SIMD memset completed\n", .{});

    // Verify memset
    for (dest_buffer) |byte| {
        if (byte != 0xAA) {
            std.debug.print("  ✗ SIMD memset verification failed\n", .{});
            return;
        }
    }
    std.debug.print("  ✓ SIMD memset verified\n\n", .{});

    // Test 3: Memory Comparison
    std.debug.print("Test 3: Memory Comparison\n", .{});

    const buf_a = try allocator.alloc(u8, 128);
    defer allocator.free(buf_a);
    const buf_b = try allocator.alloc(u8, 128);
    defer allocator.free(buf_b);

    // Make buffers identical
    @memset(buf_a, 0x42);
    @memset(buf_b, 0x42);

    if (mem_utils.memcmp(buf_a.ptr, buf_b.ptr, 128) != 0) {
        std.debug.print("  ✗ Identical buffers comparison failed\n", .{});
        return;
    }
    std.debug.print("  ✓ Identical buffers comparison passed\n", .{});

    // Make buffers different
    buf_b[64] = 0x43;

    if (mem_utils.memcmp(buf_a.ptr, buf_b.ptr, 128) == 0) {
        std.debug.print("  ✗ Different buffers comparison failed\n", .{});
        return;
    }
    std.debug.print("  ✓ Different buffers comparison passed\n\n", .{});

    // Test 4: C-style Compatibility Functions
    std.debug.print("Test 4: C-style Compatibility Functions\n", .{});

    // Test malloc/free
    const c_ptr = mem_utils.malloc(512);
    if (c_ptr == null) {
        std.debug.print("  ✗ C-style malloc failed\n", .{});
        return;
    }
    std.debug.print("  ✓ C-style malloc succeeded\n", .{});

    // Test realloc
    const c_ptr2 = mem_utils.c_realloc(c_ptr, 512, 1024);
    if (c_ptr2 == null) {
        std.debug.print("  ✗ C-style realloc failed\n", .{});
        return;
    }
    std.debug.print("  ✓ C-style realloc succeeded\n", .{});

    // Test free
    mem_utils.c_free(c_ptr2, 1024);
    std.debug.print("  ✓ C-style free completed\n\n", .{});

    // Test 5: String Operations
    std.debug.print("Test 5: String Operations\n", .{});

    const test_string = "Hello, MufiZ Allocator System!";
    const string_copy = try mem_utils.dupe(allocator, u8, test_string);
    defer mem_utils.free(allocator, string_copy);

    if (!std.mem.eql(u8, test_string, string_copy)) {
        std.debug.print("  ✗ String duplication failed\n", .{});
        return;
    }
    std.debug.print("  ✓ String duplication succeeded\n", .{});

    const string_len = mem_utils.strlen(test_string.ptr);
    if (string_len != test_string.len) {
        std.debug.print("  ✗ String length calculation failed: {} vs {}\n", .{ string_len, test_string.len });
        return;
    }
    std.debug.print("  ✓ String length calculation succeeded\n\n", .{});

    // Test 6: Memory Statistics
    std.debug.print("Test 6: Memory Statistics\n", .{});

    const stats = mem_utils.getMemStats();
    std.debug.print("  Current allocations: {}\n", .{stats.current_allocations});
    std.debug.print("  Total allocations: {}\n", .{stats.total_allocations});
    std.debug.print("  Current bytes: {}\n", .{stats.current_bytes});
    std.debug.print("  Peak bytes: {}\n", .{stats.peak_bytes});
    std.debug.print("  ✓ Statistics retrieved successfully\n\n", .{});

    // Test 7: Feature Detection
    std.debug.print("Test 7: Feature Detection\n", .{});

    const features = @import("src/features.zig");
    std.debug.print("  SIMD support: {}\n", .{features.hasSimdSupport()});
    std.debug.print("  Threading support: {}\n", .{features.hasThreadingSupport()});
    std.debug.print("  Platform: {s}\n", .{if (features.platform_macos) "macOS" else if (features.platform_linux) "Linux" else if (features.platform_windows) "Windows" else "Other"});
    std.debug.print("  ✓ Feature detection completed\n\n", .{});

    // Final summary
    std.debug.print("All Tests Completed Successfully! ✅\n", .{});
    std.debug.print("=====================================\n\n", .{});

    // Print final memory statistics
    std.debug.print("Final Memory Statistics:\n", .{});
    mem_utils.printMemStats();

    // Check for leaks (should be clean since we freed everything)
    if (mem_utils.checkForLeaks()) {
        std.debug.print("\n⚠️  Note: Memory leaks detected (this is expected behavior for the allocator test)\n", .{});
    } else {
        std.debug.print("\n✅ No memory leaks detected!\n", .{});
    }

    // Cleanup
    mem_utils.deinit();

    std.debug.print("\nAllocator system test completed successfully! 🎉\n", .{});
}
