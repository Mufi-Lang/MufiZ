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

    // For large data (>64 bytes), automatically use SIMD optimization
    if (__n >= 64) {
        return memcpySIMD(__dest, __src, __n);
    }

    const dest_bytes: [*]u8 = @ptrCast(__dest.?);
    const src_bytes: [*]const u8 = @ptrCast(__src.?);

    // For small copies, use simple word-sized copying
    if (__n < 8) {
        for (0..@min(__n, std.math.maxInt(usize))) |i| {
            dest_bytes[i] = src_bytes[i];
        }
        return __dest;
    }

    // Use word-sized copies for medium data
    const word_size = @sizeOf(usize);
    const words = __n / word_size;
    var offset: usize = 0;

    if (words > 0) {
        const dest_usize: [*]usize = @ptrCast(@alignCast(dest_bytes));
        const src_usize: [*]const usize = @ptrCast(@alignCast(src_bytes));

        // Copy word-sized chunks
        for (0..words) |i| {
            dest_usize[i] = src_usize[i];
        }
        offset = words * word_size;
    }

    // Copy any remaining bytes
    const remaining_bytes = __n - offset;
    if (remaining_bytes > 0) {
        for (0..remaining_bytes) |i| {
            dest_bytes[offset + i] = src_bytes[offset + i];
        }
    }

    return __dest;
}

// SIMD-optimized memory copy for aligned data
pub fn memcpySIMD(__dest: ?*anyopaque, __src: ?*const anyopaque, __n: usize) ?*anyopaque {
    if (__dest == null or __src == null or __n == 0) return __dest;

    const dest_bytes: [*]u8 = @ptrCast(__dest.?);
    const src_bytes: [*]const u8 = @ptrCast(__src.?);

    // For unaligned data, fall back to regular copy for safety
    if ((__n < 64) or
        (@intFromPtr(dest_bytes) % 16 != 0) or
        (@intFromPtr(src_bytes) % 16 != 0))
    {
        @memcpy(dest_bytes[0..__n], src_bytes[0..__n]);
        return __dest;
    }

    // Use 128-bit vectors (16 bytes) for aligned data only
    const Vec16 = @Vector(16, u8);
    const vec_size = 16;

    var offset: usize = 0;

    // Process 64-byte chunks (4 vectors) for better cache utilization
    const chunk_size = vec_size * 4; // 64 bytes
    const chunks = __n / chunk_size;

    for (0..chunks) |_| {
        const dest_ptr: *Vec16 = @ptrCast(@alignCast(dest_bytes + offset));
        const src_ptr: *const Vec16 = @ptrCast(@alignCast(src_bytes + offset));

        // Copy 4 vectors at once
        dest_ptr[0] = src_ptr[0];
        (dest_ptr + 1)[0] = (src_ptr + 1)[0];
        (dest_ptr + 2)[0] = (src_ptr + 2)[0];
        (dest_ptr + 3)[0] = (src_ptr + 3)[0];

        offset += chunk_size;
    }

    // Process remaining 16-byte vectors
    const remaining = __n - offset;
    const remaining_vecs = remaining / vec_size;

    for (0..remaining_vecs) |_| {
        const dest_ptr: *Vec16 = @ptrCast(@alignCast(dest_bytes + offset));
        const src_ptr: *const Vec16 = @ptrCast(@alignCast(src_bytes + offset));
        dest_ptr.* = src_ptr.*;
        offset += vec_size;
    }

    // Copy any remaining bytes
    const final_remaining = __n - offset;
    if (final_remaining > 0) {
        @memcpy(dest_bytes[offset .. offset + final_remaining], src_bytes[offset .. offset + final_remaining]);
    }

    return __dest;
}

pub fn memcmp(__s1: ?*const anyopaque, __s2: ?*const anyopaque, __n: usize) i32 {
    if (__s1 == null or __s2 == null) return 0;
    if (__n == 0) return 0;

    // Only use SIMD for larger aligned data to avoid alignment issues
    const s1_bytes: [*]const u8 = @ptrCast(__s1.?);
    const s2_bytes: [*]const u8 = @ptrCast(__s2.?);

    if (__n >= 128 and
        @intFromPtr(s1_bytes) % 16 == 0 and
        @intFromPtr(s2_bytes) % 16 == 0)
    {
        return memcmpSIMD(__s1, __s2, __n);
    }

    // Use standard byte-by-byte comparison for unaligned or small data
    var i: usize = 0;
    while (i < __n) : (i += 1) {
        if (s1_bytes[i] != s2_bytes[i]) {
            return if (s1_bytes[i] < s2_bytes[i]) -1 else 1;
        }
    }

    return 0;
}

// SIMD-optimized memory comparison
pub fn memcmpSIMD(__s1: ?*const anyopaque, __s2: ?*const anyopaque, __n: usize) i32 {
    if (__s1 == null or __s2 == null) return 0;
    if (__n == 0) return 0;

    const s1_bytes: [*]const u8 = @ptrCast(__s1.?);
    const s2_bytes: [*]const u8 = @ptrCast(__s2.?);

    // For small comparisons, use byte-by-byte
    if (__n < 16) {
        for (0..__n) |i| {
            if (s1_bytes[i] != s2_bytes[i]) {
                return if (s1_bytes[i] < s2_bytes[i]) -1 else 1;
            }
        }
        return 0;
    }

    const Vec16 = @Vector(16, u8);
    const vec_size = 16;
    var offset: usize = 0;

    // Process 16-byte chunks using unaligned reads
    const vecs = __n / vec_size;
    for (0..vecs) |_| {
        // Use unaligned loads by reading bytes into vector
        var v1_bytes: [16]u8 = undefined;
        var v2_bytes: [16]u8 = undefined;

        @memcpy(&v1_bytes, s1_bytes[offset .. offset + 16]);
        @memcpy(&v2_bytes, s2_bytes[offset .. offset + 16]);

        const v1: Vec16 = v1_bytes;
        const v2: Vec16 = v2_bytes;

        if (!@reduce(.And, v1 == v2)) {
            // Found difference, find the exact byte
            for (0..vec_size) |i| {
                const idx = offset + i;
                if (s1_bytes[idx] != s2_bytes[idx]) {
                    return if (s1_bytes[idx] < s2_bytes[idx]) -1 else 1;
                }
            }
        }
        offset += vec_size;
    }

    // Compare remaining bytes
    for (offset..__n) |i| {
        if (s1_bytes[i] != s2_bytes[i]) {
            return if (s1_bytes[i] < s2_bytes[i]) -1 else 1;
        }
    }

    return 0;
}

// SIMD-optimized memory set
pub fn memsetSIMD(__s: ?*anyopaque, __c: i32, __n: usize) ?*anyopaque {
    if (__s == null or __n == 0) return __s;

    const s_bytes: [*]u8 = @ptrCast(__s.?);
    const byte_val: u8 = @intCast(__c & 0xFF);

    // For small sets, use simple loop
    if (__n < 32) {
        for (0..__n) |i| {
            s_bytes[i] = byte_val;
        }
        return __s;
    }

    const Vec16 = @Vector(16, u8);
    const splat_vec: Vec16 = @splat(byte_val);
    const vec_size = 16;

    var offset: usize = 0;

    // Process 32-byte chunks (2 vectors)
    const chunk_size = vec_size * 2;
    const chunks = __n / chunk_size;

    for (0..chunks) |_| {
        @as([*]Vec16, @ptrCast(@alignCast(s_bytes + offset)))[0] = splat_vec;
        @as([*]Vec16, @ptrCast(@alignCast(s_bytes + offset + vec_size)))[0] = splat_vec;
        offset += chunk_size;
    }

    // Process remaining 16-byte vectors
    const remaining = __n - offset;
    const remaining_vecs = remaining / vec_size;

    for (0..remaining_vecs) |_| {
        @as([*]Vec16, @ptrCast(@alignCast(s_bytes + offset)))[0] = splat_vec;
        offset += vec_size;
    }

    // Set any remaining bytes
    for (offset..__n) |i| {
        s_bytes[i] = byte_val;
    }

    return __s;
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
// pub fn strlen(s: [*]const u8) usize {
//     const start_ptr = s;
//     var ptr = s;

//     // Fast path for short strings (avoid SIMD setup overhead)
//     // Check first 8 bytes directly
//     inline for (0..8) |i| {
//         if (ptr[i] == 0) {
//             return i;
//         }
//     }

//     // String is longer than 8 bytes
//     ptr = s + 8;

//     // If CPU supports AVX-2/SSE, use SIMD approach
//     if (@hasDecl(std.simd, "suggestVectorLength")) {
//         // Use SIMD vector operations
//         const Vec16 = @Vector(16, u8);
//         const zeros: Vec16 = @splat(0);

//         // Align to 16-byte boundary for optimal SIMD performance
//         const alignment_offset = @intFromPtr(ptr) & 0xF;
//         if (alignment_offset != 0) {
//             // Process bytes until aligned
//             const to_align = 16 - alignment_offset;
//             for (0..to_align) |_| {
//                 if (ptr[0] == 0) {
//                     return @intFromPtr(ptr) - @intFromPtr(start_ptr);
//                 }
//                 ptr += 1;
//             }
//         }

//         // Main SIMD loop - process 16 bytes at a time
//         while (true) {
//             // Load 16 bytes and compare with zeros
//             const chunk = @as(*align(1) const Vec16, @ptrCast(ptr)).*;
//             const mask = chunk == zeros;

//             // Check if any byte is zero
//             if (@reduce(.Or, mask)) {
//                 // Find which byte is zero
//                 inline for (0..16) |i| {
//                     if (mask[i]) {
//                         return @intFromPtr(ptr) - @intFromPtr(start_ptr) + i;
//                     }
//                 }
//             }

//             ptr += 16;
//         }
//     } else {
//         // Fallback to word-size optimized approach for platforms without SIMD
//         const uword = if (@sizeOf(usize) == 8) u64 else u32;
//         const word_size = @sizeOf(uword);

//         // Align to word boundary
//         while (@intFromPtr(ptr) & (word_size - 1) != 0) {
//             if (ptr[0] == 0) return @intFromPtr(ptr) - @intFromPtr(start_ptr);
//             ptr += 1;
//         }

//         // Process word at a time
//         const word_ptr = @as([*]const uword, @ptrCast(@alignCast(ptr)));
//         var idx: usize = 0;
//         while (true) {
//             // This magic detects null bytes in a word
//             const word = word_ptr[idx];
//             // (word - 0x01..) & ~word & 0x80.. detects null bytes
//             const has_zero = ((word -% comptime repeatedByte(0x01, word_size)) &
//                 ~word & comptime repeatedByte(0x80, word_size)) != 0;

//             if (has_zero) {
//                 // Found a null byte in this word
//                 ptr = @ptrCast(word_ptr + idx);
//                 // Find exact position
//                 for (0..word_size) |i| {
//                     if (ptr[i] == 0) {
//                         return @intFromPtr(ptr) + i - @intFromPtr(start_ptr);
//                     }
//                 }
//             }
//             idx += 1;
//         }
//     }
// }

// /// Helper function to create a word with repeated bytes
// fn repeatedByte(byte: u8, size: usize) usize {
//     var result: usize = 0;
//     var i: usize = 0;
//     while (i < size) : (i += 1) {
//         result = (result << 8) | byte;
//     }
//     return result;
// }
pub fn strlen(s: [*]const u8) usize {
    const start_ptr = s;
    var ptr = s;

    // Fast path for first 8 bytes
    inline for (0..8) |i| {
        if (ptr[i] == 0) {
            return i;
        }
    }

    ptr += 8;

    if (@hasDecl(std.simd, "suggestVectorLength")) {
        const Vec16 = @Vector(16, u8);
        const zeros: Vec16 = @splat(0);

        // Align pointer to 16 bytes
        const alignment_offset = @intFromPtr(ptr) & 0xF;
        if (alignment_offset != 0) {
            const to_align = 16 - alignment_offset;
            for (0..to_align) |_| {
                if (ptr[0] == 0) {
                    return @intFromPtr(ptr) - @intFromPtr(start_ptr);
                }
                ptr += 1;
            }
        }

        // Main SIMD loop
        while (true) {
            const chunk_ptr = @as(*align(1) const Vec16, @ptrCast(ptr));
            const chunk = chunk_ptr.*;
            const mask = chunk == zeros;

            if (@reduce(.Or, mask)) {
                inline for (0..16) |i| {
                    if (mask[i]) {
                        return @intFromPtr(ptr) - @intFromPtr(start_ptr) + i;
                    }
                }
            }
            ptr += 16;
        }
    } else {
        // Fallback using word-sized chunks
        const uword = if (@sizeOf(usize) == 8) u64 else u32;
        const word_size = @sizeOf(uword);

        // Align to word boundary
        while ((@intFromPtr(ptr) & (word_size - 1)) != 0) {
            if (ptr[0] == 0) {
                return @intFromPtr(ptr) - @intFromPtr(start_ptr);
            }
            ptr += 1;
        }

        const word_ptr = @as([*]const uword, @ptrCast(@alignCast(ptr)));
        var idx: usize = 0;
        while (true) {
            const word = word_ptr[idx];

            const has_zero = ((word -% comptime repeatedByte(0x01, word_size)) &
                ~word & comptime repeatedByte(0x80, word_size)) != 0;

            if (has_zero) {
                ptr = @ptrCast(word_ptr + idx);
                for (0..word_size) |i| {
                    if (ptr[i] == 0) {
                        return @intFromPtr(ptr) - @intFromPtr(start_ptr) + i;
                    }
                }
            }

            idx += 1;
        }
    }
}

// Helper to create a repeated byte pattern
fn repeatedByte(byte: u8, len: usize) u64 {
    var val: u64 = 0;
    inline for (0..len) |i| {
        val |= (@as(u64, byte) << @intCast(i * 8));
    }
    return val;
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
