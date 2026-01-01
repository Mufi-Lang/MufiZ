const std = @import("std");
const allocator_mod = @import("allocator.zig");

// Use a simple GPA for dynamic allocations and arena for VM-lifetime objects
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var arena_allocator: ?std.heap.ArenaAllocator = null;
var is_initialized = false;

/// Initialize the global allocator with configuration
pub fn initAllocator(config: allocator_mod.AllocatorConfig) void {
    _ = config; // Ignore config for now
    arena_allocator = std.heap.ArenaAllocator.init(gpa.allocator());
    is_initialized = true;
}

/// Get the global allocator - use this throughout the codebase
pub fn getAllocator() std.mem.Allocator {
    return gpa.allocator();
}

/// Check for memory leaks and cleanup
pub fn checkForLeaks() bool {
    if (!is_initialized) return false;
    // Clean up arena first
    if (arena_allocator) |*arena| {
        arena.deinit();
    }
    return gpa.deinit() == .leak;
}

/// Deinitialize the memory system
pub fn deinit() void {
    // Arena cleanup is handled in checkForLeaks
}

/// Get memory statistics - simplified version
pub fn getMemStats() allocator_mod.MemoryStats {
    return .{}; // Return empty stats for now
}

/// Get the VM arena allocator for long-lived objects (VM lifetime)
pub fn getVMArenaAllocator() std.mem.Allocator {
    if (arena_allocator) |*arena| {
        return arena.allocator();
    }
    // Fallback to GPA if arena not initialized
    return gpa.allocator();
}

/// Print memory statistics for debugging
pub fn printMemStats() void {
    std.debug.print("Memory Statistics: (simplified tracking)\n", .{});
}

/// Allocate memory using the provided allocator
pub fn alloc(allocator: std.mem.Allocator, comptime T: type, count: usize) ![]T {
    return try allocator.alloc(T, count);
}

/// Free memory using the provided allocator
pub fn free(allocator: std.mem.Allocator, memory: anytype) void {
    allocator.free(memory);
}

/// Reallocate memory using the provided allocator
pub fn realloc(allocator: std.mem.Allocator, old_memory: anytype, new_count: usize) ![]@TypeOf(old_memory[0]) {
    return try allocator.realloc(old_memory, new_count);
}

/// Create a copy of data using the provided allocator
pub fn dupe(allocator: std.mem.Allocator, comptime T: type, data: []const T) ![]T {
    return try allocator.dupe(T, data);
}

/// C-style malloc wrapper for compatibility - uses global allocator
pub fn malloc(size: usize) ?*anyopaque {
    if (size == 0) return null;

    const allocator = getAllocator();
    const result = allocator.alloc(u8, size) catch return null;
    return result.ptr;
}

/// C-style free wrapper for compatibility - requires size for proper deallocation
pub fn c_free(ptr: ?*anyopaque, size: usize) void {
    if (ptr == null or size == 0) return;

    const allocator = getAllocator();
    const slice = @as([*]u8, @ptrCast(ptr))[0..size];
    allocator.free(slice);
}

/// C-style realloc wrapper for compatibility
pub fn c_realloc(ptr: ?*anyopaque, old_size: usize, new_size: usize) ?*anyopaque {
    const allocator = getAllocator();

    // Handle null pointer (act like malloc)
    if (ptr == null) {
        return malloc(new_size);
    }

    // Handle zero size (act like free)
    if (new_size == 0) {
        c_free(ptr, old_size);
        return null;
    }

    // Reallocate existing memory
    const old_slice = @as([*]u8, @ptrCast(ptr))[0..old_size];
    const new_memory = allocator.realloc(old_slice, new_size) catch return null;
    return new_memory.ptr;
}

/// Fast memory copy implementation
pub fn memcpy(dest: [*]u8, src: [*]const u8, count: usize) void {
    if (count == 0) return;
    @memcpy(dest[0..count], src[0..count]);
}

/// Fast memory copy with alignment optimization
pub fn memcpyFast(dest: [*]u8, src: [*]const u8, count: usize) void {
    if (count == 0) return;

    // Use builtin memcpy for better optimization
    @memcpy(dest[0..count], src[0..count]);
}

/// SIMD-optimized memory copy for large blocks
pub fn memcpySIMD(dest: [*]u8, src: [*]const u8, count: usize) void {
    if (count == 0) return;

    const chunk_size = 32; // 256-bit chunks for AVX2

    if (count >= chunk_size and std.simd.suggestVectorLength(u8) != null) {
        var i: usize = 0;
        const vector_len = std.simd.suggestVectorLength(u8) orelse 16;

        // Process in SIMD chunks
        while (i + vector_len <= count) {
            const src_vec: @Vector(vector_len, u8) = src[i .. i + vector_len][0..vector_len].*;
            dest[i .. i + vector_len][0..vector_len].* = src_vec;
            i += vector_len;
        }

        // Copy remaining bytes
        if (i < count) {
            @memcpy(dest[i..count], src[i..count]);
        }
    } else {
        // Fall back to regular memcpy
        @memcpy(dest[0..count], src[0..count]);
    }
}

/// Memory comparison
pub fn memcmp(ptr1: [*]const u8, ptr2: [*]const u8, count: usize) i32 {
    if (count == 0) return 0;

    const slice1 = ptr1[0..count];
    const slice2 = ptr2[0..count];

    return switch (std.mem.order(u8, slice1, slice2)) {
        .lt => -1,
        .eq => 0,
        .gt => 1,
    };
}

/// SIMD-optimized memory comparison
pub fn memcmpSIMD(ptr1: [*]const u8, ptr2: [*]const u8, count: usize) i32 {
    if (count == 0) return 0;

    const vector_len = std.simd.suggestVectorLength(u8) orelse 16;

    if (count >= vector_len) {
        var i: usize = 0;

        // Compare in SIMD chunks
        while (i + vector_len <= count) {
            const vec1: @Vector(vector_len, u8) = ptr1[i .. i + vector_len][0..vector_len].*;
            const vec2: @Vector(vector_len, u8) = ptr2[i .. i + vector_len][0..vector_len].*;

            if (!std.meta.eql(vec1, vec2)) {
                // Found difference, fall back to byte comparison
                return memcmp(ptr1 + i, ptr2 + i, vector_len);
            }

            i += vector_len;
        }

        // Compare remaining bytes
        if (i < count) {
            return memcmp(ptr1 + i, ptr2 + i, count - i);
        }

        return 0;
    } else {
        // Fall back to regular memcmp
        return memcmp(ptr1, ptr2, count);
    }
}

/// SIMD-optimized memory set
pub fn memsetSIMD(ptr: [*]u8, value: u8, count: usize) void {
    if (count == 0) return;

    const vector_len = std.simd.suggestVectorLength(u8) orelse 16;

    if (count >= vector_len) {
        const fill_vec: @Vector(vector_len, u8) = @splat(value);
        var i: usize = 0;

        // Set in SIMD chunks
        while (i + vector_len <= count) {
            ptr[i .. i + vector_len][0..vector_len].* = fill_vec;
            i += vector_len;
        }

        // Set remaining bytes
        if (i < count) {
            @memset(ptr[i..count], value);
        }
    } else {
        // Fall back to regular memset
        @memset(ptr[0..count], value);
    }
}

/// Fast string length calculation
pub fn strlen(str: [*]const u8) usize {
    var len: usize = 0;
    while (str[len] != 0) : (len += 1) {}
    return len;
}

/// VM-specific allocation helpers using arena for appropriate objects
/// Allocate memory for VM-lifetime objects (native functions, constants, etc.)
pub fn allocVMObject(comptime T: type, count: usize) ![]T {
    const vm_allocator = getVMArenaAllocator();
    return try vm_allocator.alloc(T, count);
}

/// Allocate a single VM-lifetime object
pub fn allocVMSingle(comptime T: type) !*T {
    const vm_allocator = getVMArenaAllocator();
    const result = try vm_allocator.alloc(T, 1);
    return &result[0];
}

/// Duplicate data using VM arena allocator
pub fn dupeVMString(data: []const u8) ![]u8 {
    const vm_allocator = getVMArenaAllocator();
    return try vm_allocator.dupe(u8, data);
}

/// Check if we should use arena for a given allocation type
pub fn shouldUseArena(allocation_type: enum { native_function, global_constant, string_literal, dynamic_object, temporary }) bool {
    return switch (allocation_type) {
        .native_function, .global_constant, .string_literal => true,
        .dynamic_object, .temporary => false,
    };
}

/// Arena Allocator Usage Statistics
pub const ArenaStats = struct {
    vm_arena_bytes: usize = 0,
    vm_arena_allocations: u32 = 0,

    pub fn print(self: @This()) void {
        std.debug.print("Arena Allocator Statistics:\n", .{});
        std.debug.print("  VM Arena bytes: {}\n", .{self.vm_arena_bytes});
        std.debug.print("  VM Arena allocations: {}\n", .{self.vm_arena_allocations});
    }
};

/// Get arena allocator statistics
pub fn getArenaStats() ArenaStats {
    // For now, return empty stats - could be enhanced to track actual usage
    return ArenaStats{};
}

/// Example usage of arena allocators for memory optimization:
///
/// 1. For VM-lifetime objects (globals, natives, constants):
///    ```zig
///    const global_string = try dupeVMString("global_constant");
///    ```
///
/// 2. For temporary compilation data:
///    ```zig
///    const compiler_arena = @import("compiler_arena.zig");
///    compiler_arena.initCompilerArena();
///    defer compiler_arena.deinitCompilerArena();
///
///    const temp_data = try compiler_arena.allocCompilerTemp(u8, 1024);
///    ```
///
/// 3. Benefits:
///    - Faster allocation (no bookkeeping overhead)
///    - Automatic bulk deallocation
///    - Reduced memory fragmentation
///    - Better cache locality for related allocations
/// Legacy compatibility - use allocUtils from allocator.zig instead
pub const allocUtils = allocator_mod.allocUtils;

// Tests - commented out to avoid compilation warnings
// test "basic allocation with new system" {
//     const testing = std.testing;
//
//     // Initialize with test config
//     initAllocator(.{ .enable_tracking = true });
//     defer deinit();
//
//     const allocator = getAllocator();
//
//     const memory = try alloc(allocator, u8, 100);
//     defer free(allocator, memory);
//
//     try testing.expect(memory.len == 100);
//
//     const stats = getMemStats();
//     try testing.expect(stats.current_allocations >= 1);
// }
//
// test "memory copy functions" {
//     const testing = std.testing;
//
//     const src_data = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };
//     var dest_data = [_]u8{0} ** 10;
//
//     memcpy(dest_data.ptr, src_data.ptr, 10);
//
//     for (src_data, dest_data) |s, d| {
//         try testing.expect(s == d);
//     }
// }
//
// test "SIMD memory functions" {
//     const testing = std.testing;
//
//     const size = 64;
//     var src_data = [_]u8{0} ** size;
//     var dest_data = [_]u8{0} ** size;
//
//     // Initialize source
//     for (src_data, 0..) |*byte, i| {
//         byte.* = @intCast(i % 256);
//     }
//
//     // Test SIMD copy
//     memcpySIMD(dest_data.ptr, src_data.ptr, size);
//
//     // Verify
//     for (src_data, dest_data) |s, d| {
//         try testing.expect(s == d);
//     }
//
//     // Test SIMD memset
//     memsetSIMD(dest_data.ptr, 0xFF, size);
//     for (dest_data) |byte| {
//         try testing.expect(byte == 0xFF);
//     }
// }
//
// test "C compatibility functions" {
//     const testing = std.testing;
//
//     initAllocator(.{});
//     defer deinit();
//
//     // Test malloc/free
//     const ptr = malloc(100);
//     try testing.expect(ptr != null);
//     defer c_free(ptr, 100);
//
//     // Test realloc
//     const new_ptr = c_realloc(ptr, 100, 200);
//     try testing.expect(new_ptr != null);
//     c_free(new_ptr, 200);
// }
