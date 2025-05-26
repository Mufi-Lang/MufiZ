const std = @import("std");

// General Purpose Allocator instance
var gpa = std.heap.GeneralPurposeAllocator(.{
    // .enable_memory_limit = false,
    // .safety = true,
    // .never_unmap = false,
    // .retain_metadata = true,
}){};

// Track allocations with this global map
var allocation_sizes = std.AutoHashMap(usize, usize).init(gpa.allocator());

// Check for memory leaks
pub fn checkForLeaks() bool {
    return gpa.deinit() == .leak;
}

// Initialize the map
var is_initialized = false;

fn ensureInitialized() void {
    if (!is_initialized) {
        is_initialized = true;
    }
}

// Get the GPA instance for debugging or configuration
// pub fn getGPA() *std.heap.GeneralPurposeAllocator(.{}) {
//     return &gpa;
// }

///
/// Reallocates the given memory block with a new size, preserving the contents.
///
/// If `__ptr` is NULL, this function behaves like malloc and allocates a new block of memory.
/// If `__size` is 0 and `__ptr` is not NULL, the memory block is freed and NULL is returned.
/// Otherwise, it attempts to resize the memory block pointed to by `__ptr` to `__size` bytes.
///
/// @param __ptr   Pointer to previously allocated memory block, or NULL
/// @param __size  New size in bytes
///
/// @return Pointer to the reallocated memory block, which may be different
///         from __ptr, or NULL if the request fails or __size is 0.
///
pub fn realloc(__ptr: ?*anyopaque, __size: usize) ?*anyopaque {
    ensureInitialized();

    const allocator = gpa.allocator();
    const size = @as(usize, @intCast(__size));

    // Handle null pointer (act like malloc)
    if (__ptr == null) {
        if (size == 0) return null;

        // Allocate memory with c_allocator
        const result = allocator.alloc(u8, size) catch return null;

        // Store the allocation size
        allocation_sizes.put(@intFromPtr(result.ptr), size) catch {};

        return result.ptr;
    }

    // Handle zero size (act like free)
    if (size == 0) {
        free(__ptr);
        return null;
    }

    // Get the original allocation size
    const ptr_addr = @intFromPtr(__ptr);
    const old_size = allocation_sizes.get(ptr_addr) orelse 0;

    if (old_size == 0) {
        // If we don't know the old size, we can't safely reallocate
        // Just allocate new memory without copying
        const result = allocator.alloc(u8, size) catch return null;
        allocation_sizes.put(@intFromPtr(result.ptr), size) catch {};
        return result.ptr;
    }

    // Try to resize in place if possible
    if (allocator.resize(@as([*]u8, @ptrCast(__ptr))[0..old_size], size)) {
        // Successful resize
        allocation_sizes.put(ptr_addr, size) catch {};
        return __ptr;
    }

    // Allocate new memory
    const new_mem = allocator.alloc(u8, size) catch return null;

    // Copy the data (only up to the old size)
    const copy_size = @min(old_size, size);
    if (copy_size > 0) {
        const src_bytes = @as([*]const u8, @ptrCast(__ptr));
        @memcpy(new_mem[0..copy_size], src_bytes[0..copy_size]);
    }

    // Free the old memory
    const old_slice = @as([*]u8, @ptrCast(__ptr))[0..old_size];
    allocator.free(old_slice);
    _ = allocation_sizes.remove(ptr_addr);

    // Store the new allocation size
    allocation_sizes.put(@intFromPtr(new_mem.ptr), size) catch {};

    return new_mem.ptr;
}

///
/// Frees the memory space pointed to by ptr.
///
/// If ptr is NULL, no operation is performed.
///
/// @param __ptr  Pointer to the memory to free
///
pub fn free(__ptr: ?*anyopaque) void {
    ensureInitialized();

    if (__ptr == null) return;

    const allocator = gpa.allocator();
    const ptr_addr = @intFromPtr(__ptr);

    // Get the allocation size
    const size = allocation_sizes.get(ptr_addr) orelse return;

    // Free the memory
    const slice = @as([*]u8, @ptrCast(__ptr))[0..size];
    allocator.free(slice);

    // Remove from the tracking map
    _ = allocation_sizes.remove(ptr_addr);
}

///
/// Allocates memory for an object of size `__size`.
///
/// @param __size  Size of memory to allocate
///
/// @return Pointer to the allocated memory, or NULL if the request fails
///
pub fn malloc(__size: usize) ?*anyopaque {
    ensureInitialized();

    if (__size == 0) return null;

    const size = @as(usize, @intCast(__size));
    const allocator = gpa.allocator();

    const result = allocator.alloc(u8, size) catch return null;

    // Store the allocation size
    allocation_sizes.put(@intFromPtr(result.ptr), size) catch {};

    return result.ptr;
}
///
/// Copies `n` bytes from memory area `src` to memory area `dest`.
/// The memory areas must not overlap.
///
/// Returns a pointer to `dest`.
///
/// Note: For overlapping memory blocks, use `memmove` instead.
///
pub fn memcpy(__dest: ?*anyopaque, __src: ?*const anyopaque, __n: usize) ?*anyopaque {
    if (__dest == null or __src == null or __n == 0) return __dest;

    const dest_bytes: [*]u8 = @ptrCast(__dest.?);
    const src_bytes: [*]const u8 = @ptrCast(__src.?);

    // Simple copy by iterating over each byte
    for (0..@min(__n, std.math.maxInt(usize))) |i| {
        dest_bytes[i] = src_bytes[i];
    }

    return __dest;
}

///
/// Optimized memcpy implementation that handles different sizes more efficiently.
/// Uses word-sized copies when possible for better performance, but with the same
/// signature as the standard memcpy.
///
pub fn memcpyFast(__dest: ?*anyopaque, __src: ?*const anyopaque, __n: usize) ?*anyopaque {
    if (__dest == null or __src == null or __n == 0) return __dest;

    const dest_bytes: [*]u8 = @ptrCast(__dest.?);
    const src_bytes: [*]const u8 = @ptrCast(__src.?);

    // For small copies, byte-by-byte is fine
    if (__n < 8) {
        for (0..@min(__n, std.math.maxInt(usize))) |i| {
            dest_bytes[i] = src_bytes[i];
        }
        return __dest;
    }

    // Check alignment for word-sized copies
    const alignment_mask = @sizeOf(usize) - 1;
    const dest_align = @intFromPtr(dest_bytes) & alignment_mask;
    const src_align = @intFromPtr(src_bytes) & alignment_mask;

    // If alignment differs, fall back to byte-by-byte copy
    if (dest_align != src_align) {
        for (0..@min(__n, std.math.maxInt(usize))) |i| {
            dest_bytes[i] = src_bytes[i];
        }
        return __dest;
    }

    // Handle unaligned prefix
    var offset: usize = 0;
    if (dest_align != 0) {
        const prefix = @sizeOf(usize) - dest_align;
        const prefix_len = @min(prefix, __n);
        for (0..prefix_len) |i| {
            dest_bytes[i] = src_bytes[i];
        }
        offset = prefix_len;
    }

    // Use usize to copy word-sized chunks for better performance
    const remaining = __n - offset;
    const word_size = @sizeOf(usize);
    const words = remaining / word_size;

    if (words > 0) {
        const dest_usize: [*]usize = @ptrCast(@alignCast(dest_bytes + offset));
        const src_usize: [*]const usize = @ptrCast(@alignCast(src_bytes + offset));

        // Copy word-sized chunks
        for (0..words) |i| {
            dest_usize[i] = src_usize[i];
        }
    }

    // Copy any remaining bytes
    const bytes_copied = offset + (words * word_size);
    const remaining_bytes = __n - bytes_copied;
    if (remaining_bytes > 0) {
        for (0..remaining_bytes) |i| {
            dest_bytes[bytes_copied + i] = src_bytes[bytes_copied + i];
        }
    }

    return __dest;
}

test "basic memcpy test" {
    var src = [_]u8{ 1, 2, 3, 4, 5 };
    var dest = [_]u8{ 0, 0, 0, 0, 0 };

    _ = memcpy(&dest, &src, src.len);

    try std.testing.expectEqualSlices(u8, &src, &dest);
}

test "memcpyFast test" {
    var src = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };
    var dest = [_]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };

    _ = memcpyFast(&dest, &src, src.len);

    try std.testing.expectEqualSlices(u8, &src, &dest);
}

///
/// Computes the length of a null-terminated string.
/// Uses a highly optimized approach with SIMD instructions for maximum performance.
///
/// @param s  Pointer to the null-terminated string
///
/// @return Length of the string, not including the null terminator
///
pub fn strlen(s: [*]const u8) usize {
    const start_ptr = s;
    var ptr = s;

    // Fast path for short strings (avoid SIMD setup overhead)
    // Check first 8 bytes directly
    inline for (0..8) |i| {
        if (ptr[i] == 0) {
            return i;
        }
    }

    // String is longer than 8 bytes
    ptr = s + 8;

    // If CPU supports AVX-2/SSE, use SIMD approach
    if (@hasDecl(std.simd, "suggestVectorLength")) {
        // Use SIMD vector operations
        const Vec16 = @Vector(16, u8);
        const zeros: Vec16 = @splat(0);

        // Align to 16-byte boundary for optimal SIMD performance
        const alignment_offset = @intFromPtr(ptr) & 0xF;
        if (alignment_offset != 0) {
            // Process bytes until aligned
            const to_align = 16 - alignment_offset;
            for (0..to_align) |_| {
                if (ptr[0] == 0) {
                    return @intFromPtr(ptr) - @intFromPtr(start_ptr);
                }
                ptr += 1;
            }
        }

        // Main SIMD loop - process 16 bytes at a time
        while (true) {
            // Load 16 bytes and compare with zeros
            const chunk = @as(*align(1) const Vec16, @ptrCast(ptr)).*;
            const mask = chunk == zeros;

            // Check if any byte is zero
            if (@reduce(.Or, mask)) {
                // Find which byte is zero
                inline for (0..16) |i| {
                    if (mask[i]) {
                        return @intFromPtr(ptr) - @intFromPtr(start_ptr) + i;
                    }
                }
            }

            ptr += 16;
        }
    } else {
        // Fallback to word-size optimized approach for platforms without SIMD
        const uword = if (@sizeOf(usize) == 8) u64 else u32;
        const word_size = @sizeOf(uword);

        // Align to word boundary
        while (@intFromPtr(ptr) & (word_size - 1) != 0) {
            if (ptr[0] == 0) return @intFromPtr(ptr) - @intFromPtr(start_ptr);
            ptr += 1;
        }

        // Process word at a time
        const word_ptr = @as([*]const uword, @ptrCast(@alignCast(ptr)));
        var idx: usize = 0;
        while (true) {
            // This magic detects null bytes in a word
            const word = word_ptr[idx];
            // (word - 0x01..) & ~word & 0x80.. detects null bytes
            const has_zero = ((word -% comptime repeatedByte(0x01, word_size)) &
                ~word & comptime repeatedByte(0x80, word_size)) != 0;

            if (has_zero) {
                // Found a null byte in this word
                ptr = @ptrCast(word_ptr + idx);
                // Find exact position
                for (0..word_size) |i| {
                    if (ptr[i] == 0) {
                        return @intFromPtr(ptr) + i - @intFromPtr(start_ptr);
                    }
                }
            }
            idx += 1;
        }
    }
}

/// Helper function to create a word with repeated bytes
fn repeatedByte(byte: u8, size: usize) usize {
    var result: usize = 0;
    var i: usize = 0;
    while (i < size) : (i += 1) {
        result = (result << 8) | byte;
    }
    return result;
}

test "strlen test" {
    const str1 = "Hello";
    const str2 = "Hello, World!";
    const str3 = "";
    const str4 = "This is a longer string that should exercise the SIMD path properly";
    const str5 = "123";
    const str6 = "12345678"; // Test exactly 8 bytes
    const str7 = "123456789"; // Test just over 8 bytes
    const str8 = "A string with exactly 36 characters."; // Test 36 bytes
    const str9 = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"; // 62 chars

    try std.testing.expectEqual(@as(usize, 5), strlen(str1));
    try std.testing.expectEqual(@as(usize, 13), strlen(str2));
    try std.testing.expectEqual(@as(usize, 0), strlen(str3));
    try std.testing.expectEqual(@as(usize, 67), strlen(str4));
    try std.testing.expectEqual(@as(usize, 3), strlen(str5));
    try std.testing.expectEqual(@as(usize, 8), strlen(str6));
    try std.testing.expectEqual(@as(usize, 9), strlen(str7));
    try std.testing.expectEqual(@as(usize, 36), strlen(str8));
    try std.testing.expectEqual(@as(usize, 62), strlen(str9));

    // Make sure null pointer is handled
    try std.testing.expectEqual(@as(usize, 0), strlen(null));
}

pub fn memcmp(s1: ?*const anyopaque, s2: ?*const anyopaque, n: usize) i32 {
    const str1: [*]const u8 = @ptrCast(s1.?);
    const str2: [*]const u8 = @ptrCast(s2.?);
    const num: usize = @intCast(n);

    if (num == 0) return 0;

    const ptr1 = @as([*]const u8, @ptrCast(str1));
    const ptr2 = @as([*]const u8, @ptrCast(str2));
    var offset: usize = 0;

    // SIMD comparison using vector types (16 bytes at once)
    const Vec16 = @Vector(16, u8);
    while (offset + 16 <= num) {
        const v1 = @as(*align(1) const Vec16, @ptrCast(ptr1 + offset)).*;
        const v2 = @as(*align(1) const Vec16, @ptrCast(ptr2 + offset)).*;

        // Compare 16 bytes at once
        const mask = v1 != v2;
        if (@reduce(.Or, mask)) {
            // Find first differing byte in the SIMD vector
            inline for (0..16) |i| {
                if (mask[i]) {
                    return @as(i32, @intCast(@as(i16, @intCast(ptr1[offset + i])) - @as(i16, @intCast(ptr2[offset + i]))));
                }
            }
        }
        offset += 16;
    }

    // Process 8 bytes at a time for the remainder
    while (offset + 8 <= num) {
        const v1 = @as(*align(1) const u64, @ptrCast(ptr1 + offset)).*;
        const v2 = @as(*align(1) const u64, @ptrCast(ptr2 + offset)).*;
        if (v1 != v2) {
            // Find first differing byte
            inline for (0..8) |i| {
                const byte1 = @as(u8, @truncate(v1 >> @as(u6, @intCast(i * 8))));
                const byte2 = @as(u8, @truncate(v2 >> @as(u6, @intCast(i * 8))));
                if (byte1 != byte2) {
                    return @as(i32, @intCast(@as(i16, @intCast(byte1)) - @as(i16, @intCast(byte2))));
                }
            }
        }
        offset += 8;
    }

    // Handle remaining bytes
    while (offset < num) {
        if (ptr1[offset] != ptr2[offset]) {
            return @as(i32, @intCast(@as(i16, @intCast(ptr1[offset])) - @as(i16, @intCast(ptr2[offset]))));
        }
        offset += 1;
    }

    return 0;
}
