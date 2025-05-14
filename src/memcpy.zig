const std = @import("std");

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
    var src = [_]u8{1, 2, 3, 4, 5};
    var dest = [_]u8{0, 0, 0, 0, 0};
    
    _ = memcpy(&dest, &src, src.len);
    
    try std.testing.expectEqualSlices(u8, &src, &dest);
}

test "memcpyFast test" {
    var src = [_]u8{1, 2, 3, 4, 5, 6, 7, 8, 9, 10};
    var dest = [_]u8{0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
    
    _ = memcpyFast(&dest, &src, src.len);
    
    try std.testing.expectEqualSlices(u8, &src, &dest);
}