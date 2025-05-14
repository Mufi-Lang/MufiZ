const std = @import("std");

// General Purpose Allocator instance
var gpa = std.heap.GeneralPurposeAllocator(.{
    .enable_memory_limit = false,
    .safety = true,
    .never_unmap = false,
    .retain_metadata = true,
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
pub fn getGPA() *std.heap.GeneralPurposeAllocator(.{}) {
    return &gpa;
}

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
pub fn realloc(__ptr: ?*anyopaque, __size: c_ulong) ?*anyopaque {
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
pub fn malloc(__size: c_ulong) ?*anyopaque {
    ensureInitialized();
    
    if (__size == 0) return null;
    
    const size = @as(usize, @intCast(__size));
    const allocator = gpa.allocator();
    
    const result = allocator.alloc(u8, size) catch return null;
    
    // Store the allocation size
    allocation_sizes.put(@intFromPtr(result.ptr), size) catch {};
    
    return result.ptr;
}