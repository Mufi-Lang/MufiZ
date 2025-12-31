const std = @import("std");
const mem_utils = @import("mem_utils.zig");

/// Arena allocator specifically for compilation-time temporary allocations
/// These are allocations that live only during the compilation phase and can
/// be freed all at once when compilation is complete.
pub const CompilerArena = struct {
    arena: std.heap.ArenaAllocator,
    initialized: bool = false,

    const Self = @This();

    /// Initialize the compiler arena using the global allocator as backing
    pub fn init(self: *Self) void {
        self.arena = std.heap.ArenaAllocator.init(mem_utils.getAllocator());
        self.initialized = true;
    }

    /// Deinitialize and free all arena memory at once
    pub fn deinit(self: *Self) void {
        if (self.initialized) {
            self.arena.deinit();
            self.initialized = false;
        }
    }

    /// Get the arena allocator for temporary compilation allocations
    pub fn allocator(self: *Self) std.mem.Allocator {
        std.debug.assert(self.initialized);
        return self.arena.allocator();
    }

    /// Reset the arena (free all allocations but keep the arena ready for reuse)
    pub fn reset(self: *Self) void {
        if (self.initialized) {
            self.arena.deinit();
            self.arena = std.heap.ArenaAllocator.init(mem_utils.getAllocator());
        }
    }

    /// Allocate memory for compilation temporaries
    pub fn alloc(self: *Self, comptime T: type, count: usize) ![]T {
        return try self.allocator().alloc(T, count);
    }

    /// Duplicate data in the compilation arena
    pub fn dupe(self: *Self, comptime T: type, data: []const T) ![]T {
        return try self.allocator().dupe(T, data);
    }

    /// Create a string copy in the compilation arena
    pub fn dupeString(self: *Self, str: []const u8) ![]u8 {
        return try self.dupe(u8, str);
    }

    /// Allocate and zero-initialize memory
    pub fn allocZ(self: *Self, comptime T: type, count: usize) ![]T {
        const result = try self.alloc(T, count);
        @memset(std.mem.asBytes(result), 0);
        return result;
    }
};

/// Global compilation arena instance
var compiler_arena: CompilerArena = .{
    .arena = undefined,
    .initialized = false,
};

/// Initialize the global compiler arena
pub fn initCompilerArena() void {
    compiler_arena.init();
}

/// Deinitialize the global compiler arena
pub fn deinitCompilerArena() void {
    compiler_arena.deinit();
}

/// Reset the global compiler arena
pub fn resetCompilerArena() void {
    compiler_arena.reset();
}

/// Get allocator for compilation temporaries
pub fn getCompilerAllocator() std.mem.Allocator {
    return compiler_arena.allocator();
}

/// Allocate compilation temporary memory
pub fn allocCompilerTemp(comptime T: type, count: usize) ![]T {
    return try compiler_arena.alloc(T, count);
}

/// Duplicate data in compilation arena
pub fn dupeCompilerTemp(comptime T: type, data: []const T) ![]T {
    return try compiler_arena.dupe(T, data);
}

/// Create string copy for compilation temporaries
pub fn dupeCompilerString(str: []const u8) ![]u8 {
    return try compiler_arena.dupeString(str);
}

/// Statistics about the compiler arena usage
pub const CompilerArenaStats = struct {
    total_allocated: usize = 0,
    peak_usage: usize = 0,
    allocations_count: u32 = 0,
};

// Simple stats tracking (could be enhanced)
var stats = CompilerArenaStats{};

/// Get compiler arena statistics
pub fn getCompilerArenaStats() CompilerArenaStats {
    return stats;
}

/// Print compiler arena statistics
pub fn printCompilerArenaStats() void {
    std.debug.print("Compiler Arena Statistics:\n", .{});
    std.debug.print("  Total allocated: {} bytes\n", .{stats.total_allocated});
    std.debug.print("  Peak usage: {} bytes\n", .{stats.peak_usage});
    std.debug.print("  Allocations: {}\n", .{stats.allocations_count});
}

/// Usage examples and patterns:
///
/// During compilation:
/// ```zig
/// initCompilerArena();
/// defer deinitCompilerArena();
///
/// // Allocate temporary compilation data
/// const temp_buffer = try allocCompilerTemp(u8, 1024);
/// const temp_string = try dupeCompilerString("temporary string");
///
/// // All memory freed automatically when arena is deinitialized
/// ```
///
/// For multiple compilation units:
/// ```zig
/// initCompilerArena();
/// defer deinitCompilerArena();
///
/// for (files) |file| {
///     // Use arena for this file
///     const temp_data = try allocCompilerTemp(u8, file.size);
///     compileFile(file, temp_data);
///
///     // Reset arena between files to prevent memory buildup
///     resetCompilerArena();
/// }
/// ```
