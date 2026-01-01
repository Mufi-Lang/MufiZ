# MufiZ Memory Management and Allocator Design

## Overview

MufiZ has been refactored to use Zig's modern allocator pattern for better memory management, debugging capabilities, and performance. This document describes the new unified allocator system and how to use it effectively.

## Architecture

### Core Components

1. **`allocator.zig`** - Central allocator management system
2. **`mem_utils.zig`** - Unified memory utilities and global allocator access
3. **`memory.zig`** - Garbage collection and object memory management
4. **`features.zig`** - Feature flags and configuration

### Key Design Principles

- **Single Source of Truth**: One global allocator instance managed centrally
- **Explicit Allocator Passing**: Allocators are passed as parameters rather than accessed globally
- **Memory Tracking**: Optional allocation tracking and statistics
- **Safety First**: Memory safety checks enabled by default
- **Performance**: SIMD-optimized memory operations where available

## Usage Guide

### Basic Memory Allocation

```zig
const mem_utils = @import("mem_utils.zig");

// Get the global allocator
const allocator = mem_utils.getAllocator();

// Allocate memory
const memory = try allocator.alloc(u8, 1024);
defer allocator.free(memory);

// Or use the convenience functions
const memory2 = try mem_utils.alloc(allocator, u8, 1024);
defer mem_utils.free(allocator, memory2);
```

### Memory Statistics and Debugging

```zig
const mem_utils = @import("mem_utils.zig");

// Initialize with tracking enabled
mem_utils.initAllocator(.{
    .enable_leak_detection = true,
    .enable_tracking = true,
    .enable_safety = true,
});

// ... your code ...

// Check for leaks and print statistics
if (mem_utils.checkForLeaks()) {
    std.debug.print("Memory leaks detected!\n", .{});
}
mem_utils.printMemStats();
mem_utils.deinit();
```

### Advanced Memory Operations

```zig
const mem_utils = @import("mem_utils.zig");

// Fast memory copy (uses SIMD when available)
mem_utils.memcpyFast(dest.ptr, src.ptr, size);

// SIMD-optimized memory set
mem_utils.memsetSIMD(buffer.ptr, 0xFF, size);

// Memory comparison
const result = mem_utils.memcmp(ptr1, ptr2, size);
```

### Legacy C-style Functions

For compatibility with existing code, C-style functions are still available:

```zig
const mem_utils = @import("mem_utils.zig");

// C-style allocation (requires size tracking)
const ptr = mem_utils.malloc(1024);
defer mem_utils.c_free(ptr, 1024);

// C-style reallocation
const new_ptr = mem_utils.c_realloc(ptr, 1024, 2048);
defer mem_utils.c_free(new_ptr, 2048);
```

## Configuration Options

### AllocatorConfig

```zig
const allocator_mod = @import("allocator.zig");

const config = allocator_mod.AllocatorConfig{
    .enable_leak_detection = true,   // Detect memory leaks
    .enable_tracking = true,         // Track allocation statistics
    .enable_safety = true,           // Enable safety checks
    .never_unmap = false,           // For debugging - never unmap memory
    .retain_metadata = true,        // Keep metadata for debugging
};
```

### Feature Flags

```zig
const features = @import("features.zig");

// Check available features
if (features.enable_simd) {
    // Use SIMD optimizations
}

if (features.hasSimdSupport()) {
    // Runtime SIMD detection
}
```

## Migration Guide

### From Old System

**Before:**
```zig
const GlobalAlloc = @import("main.zig").GlobalAlloc;
const memory = try GlobalAlloc.alloc(u8, size);
defer GlobalAlloc.free(memory);
```

**After:**
```zig
const mem_utils = @import("mem_utils.zig");
const allocator = mem_utils.getAllocator();
const memory = try allocator.alloc(u8, size);
defer allocator.free(memory);
```

### Best Practices

1. **Initialize Early**: Call `mem_utils.initAllocator()` at program start
2. **Check for Leaks**: Always call `mem_utils.checkForLeaks()` before exit
3. **Pass Allocators**: Pass allocators as parameters to functions that need them
4. **Use Defer**: Always use `defer` to ensure cleanup
5. **Enable Tracking**: Use tracking in debug builds for leak detection

## Performance Considerations

### SIMD Optimizations

The new system includes SIMD-optimized memory operations:

- `memcpySIMD()` - Vectorized memory copy for large blocks
- `memsetSIMD()` - Vectorized memory initialization
- `memcmpSIMD()` - Vectorized memory comparison

These functions automatically fall back to standard implementations on unsupported platforms.

### Memory Alignment

The allocator ensures proper memory alignment for optimal performance. SIMD functions work best with aligned memory addresses.

### Allocation Strategies

- Small allocations: Direct allocator usage
- Large allocations: Consider using arena allocators for batch operations
- Temporary allocations: Use stack allocators where possible

## Debugging and Profiling

### Memory Leak Detection

```zig
// Enable at startup
mem_utils.initAllocator(.{
    .enable_leak_detection = true,
    .enable_tracking = true,
});

// Check at shutdown
defer {
    if (mem_utils.checkForLeaks()) {
        std.debug.print("Warning: Memory leaks detected!\n", .{});
        mem_utils.printMemStats();
    }
    mem_utils.deinit();
}
```

### Statistics Tracking

```zig
const stats = mem_utils.getMemStats();
std.debug.print("Current allocations: {d}\n", .{stats.current_allocations});
std.debug.print("Current bytes: {d}\n", .{stats.current_bytes});
std.debug.print("Peak bytes: {d}\n", .{stats.peak_bytes});
```

## Integration with Garbage Collector

The allocator system works seamlessly with MufiZ's garbage collector:

- Object allocations are tracked by the GC
- Memory pressure triggers garbage collection
- Statistics help tune GC thresholds
- SIMD optimizations accelerate mark/sweep operations

## Error Handling

The allocator system provides robust error handling:

```zig
const memory = allocator.alloc(u8, size) catch |err| switch (err) {
    error.OutOfMemory => {
        // Handle OOM gracefully
        std.debug.print("Out of memory!\n", .{});
        return err;
    },
};
```

## Platform Considerations

### Zig Version Compatibility

- Minimum Zig version: 0.15.0
- Tested with Zig 0.15.2
- Uses modern Zig allocator interface

### Operating System Support

- macOS: Full support including SIMD optimizations
- Linux: Full support including SIMD optimizations  
- Windows: Basic support (SIMD detection may vary)
- WASM: Basic support without SIMD

## Future Improvements

### Planned Features

1. **Arena Allocators**: For batch allocations
2. **Pool Allocators**: For fixed-size objects
3. **Stack Allocators**: For temporary allocations
4. **Memory Profiling**: Detailed allocation profiling
5. **Custom Allocators**: Plugin system for specialized allocators

### Performance Optimizations

1. **Lock-free Allocations**: For multi-threaded scenarios
2. **NUMA Awareness**: For multi-socket systems
3. **Cache-optimized Layouts**: Better memory locality
4. **Compression**: Optional memory compression for large objects

## Troubleshooting

### Common Issues

1. **Memory Leaks**: Enable tracking to identify leak sources
2. **Performance Issues**: Check if SIMD is being utilized
3. **Alignment Errors**: Ensure proper type alignment
4. **OOM Errors**: Monitor allocation statistics

### Debug Tips

1. Use `mem_utils.printMemStats()` to monitor usage
2. Enable safety checks in debug builds
3. Use `never_unmap` option for debugging use-after-free
4. Track allocation patterns with statistics

## Examples

### Complete Example

```zig
const std = @import("std");
const mem_utils = @import("mem_utils.zig");

pub fn main() !void {
    // Initialize allocator with debugging
    mem_utils.initAllocator(.{
        .enable_leak_detection = true,
        .enable_tracking = true,
        .enable_safety = true,
    });

    defer {
        if (mem_utils.checkForLeaks()) {
            std.debug.print("Warning: Memory leaks detected!\n", .{});
            mem_utils.printMemStats();
        }
        mem_utils.deinit();
    }

    const allocator = mem_utils.getAllocator();

    // Allocate some memory
    const buffer = try allocator.alloc(u8, 1024);
    defer allocator.free(buffer);

    // Use SIMD operations
    mem_utils.memsetSIMD(buffer.ptr, 0x42, buffer.len);

    // Print statistics
    mem_utils.printMemStats();
}
```

This new allocator system provides a solid foundation for MufiZ's memory management needs while maintaining compatibility with existing code and providing room for future optimizations.