const std = @import("std");

/// Allocator configuration options
pub const AllocatorConfig = struct {
    /// Enable memory leak detection
    enable_leak_detection: bool = true,
    /// Enable memory usage tracking
    enable_tracking: bool = true,
    /// Enable safety checks
    enable_safety: bool = true,
    /// Never unmap memory for debugging
    never_unmap: bool = false,
    /// Retain metadata for debugging
    retain_metadata: bool = true,
};

/// Memory statistics for tracking allocations
pub const MemoryStats = struct {
    total_allocations: u64 = 0,
    total_deallocations: u64 = 0,
    current_allocations: u64 = 0,
    peak_allocations: u64 = 0,
    bytes_allocated: u64 = 0,
    bytes_deallocated: u64 = 0,
    current_bytes: u64 = 0,
    peak_bytes: u64 = 0,

    pub fn reset(self: *MemoryStats) void {
        self.* = .{};
    }

    pub fn recordAllocation(self: *MemoryStats, bytes: u64) void {
        self.total_allocations += 1;
        self.current_allocations += 1;
        self.bytes_allocated += bytes;
        self.current_bytes += bytes;

        if (self.current_allocations > self.peak_allocations) {
            self.peak_allocations = self.current_allocations;
        }
        if (self.current_bytes > self.peak_bytes) {
            self.peak_bytes = self.current_bytes;
        }
    }

    pub fn recordDeallocation(self: *MemoryStats, bytes: u64) void {
        self.total_deallocations += 1;
        if (self.current_allocations > 0) {
            self.current_allocations -= 1;
        }
        self.bytes_deallocated += bytes;
        if (self.current_bytes >= bytes) {
            self.current_bytes -= bytes;
        } else {
            self.current_bytes = 0;
        }
    }

    pub fn print(self: *const MemoryStats) void {
        std.debug.print("Memory Statistics:\n", .{});
        std.debug.print("  Allocations: {d} total, {d} current, {d} peak\n", .{
            self.total_allocations,
            self.current_allocations,
            self.peak_allocations,
        });
        std.debug.print("  Deallocations: {d}\n", .{self.total_deallocations});
        std.debug.print("  Bytes: {d} allocated, {d} deallocated\n", .{
            self.bytes_allocated,
            self.bytes_deallocated,
        });
        std.debug.print("  Current: {d} bytes, {d} allocations\n", .{
            self.current_bytes,
            self.current_allocations,
        });
        std.debug.print("  Peak: {d} bytes, {d} allocations\n", .{
            self.peak_bytes,
            self.peak_allocations,
        });

        if (self.current_allocations > 0) {
            std.debug.print("  WARNING: {d} unfreed allocations detected!\n", .{self.current_allocations});
        }
    }
};

/// Thread-safe allocator manager
pub const AllocatorManager = struct {
    gpa: std.heap.GeneralPurposeAllocator(.{
        .safety = true,
        .never_unmap = false,
        .retain_metadata = true,
    }),
    config: AllocatorConfig,
    stats: MemoryStats,
    mutex: std.Thread.Mutex,
    initialized: bool,

    const Self = @This();

    /// Initialize the allocator manager
    pub fn init(config: AllocatorConfig) Self {
        return Self{
            .gpa = std.heap.GeneralPurposeAllocator(.{
                .safety = false,
                .never_unmap = false,
                .retain_metadata = true,
            }){},
            .config = config,
            .stats = .{},
            .mutex = .{},
            .initialized = true,
        };
    }

    /// Deinitialize and check for leaks
    pub fn deinit(self: *Self) bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.config.enable_tracking) {
            self.stats.print();
        }

        const has_leak = self.gpa.deinit() == .leak;
        if (has_leak and self.config.enable_leak_detection) {
            std.debug.print("Memory leaks detected!\n", .{});
        }

        self.initialized = false;
        return has_leak;
    }

    /// Get the underlying allocator
    pub fn allocator(self: *Self) std.mem.Allocator {
        if (!self.initialized) {
            @panic("Allocator manager not initialized");
        }
        return self.gpa.allocator();
    }

    /// Get current memory statistics
    pub fn getStats(self: *Self) MemoryStats {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.stats;
    }

    /// Reset memory statistics
    pub fn resetStats(self: *Self) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.stats.reset();
    }

    /// Record an allocation (internal use)
    pub fn recordAllocation(self: *Self, bytes: u64) void {
        if (!self.config.enable_tracking) return;
        self.mutex.lock();
        defer self.mutex.unlock();
        self.stats.recordAllocation(bytes);
    }

    /// Record a deallocation (internal use)
    pub fn recordDeallocation(self: *Self, bytes: u64) void {
        if (!self.config.enable_tracking) return;
        self.mutex.lock();
        defer self.mutex.unlock();
        self.stats.recordDeallocation(bytes);
    }
};

/// Global allocator manager instance
var global_manager: ?AllocatorManager = null;
var global_mutex = std.Thread.Mutex{};

/// Initialize the global allocator manager
pub fn initGlobal(config: AllocatorConfig) void {
    global_mutex.lock();
    defer global_mutex.unlock();

    if (global_manager != null) {
        @panic("Global allocator manager already initialized");
    }

    global_manager = AllocatorManager.init(config);
}

/// Deinitialize the global allocator manager
pub fn deinitGlobal() bool {
    global_mutex.lock();
    defer global_mutex.unlock();

    if (global_manager == null) {
        return false;
    }

    const has_leak = global_manager.?.deinit();
    global_manager = null;
    return has_leak;
}

/// Get the global allocator
pub fn getGlobalAllocator() std.mem.Allocator {
    global_mutex.lock();
    defer global_mutex.unlock();

    if (global_manager == null) {
        // Auto-initialize with default config if not already initialized
        global_manager = AllocatorManager.init(.{});
    }

    return global_manager.?.allocator();
}

/// Get global memory statistics
pub fn getGlobalStats() MemoryStats {
    global_mutex.lock();
    defer global_mutex.unlock();

    if (global_manager) |*manager| {
        return manager.getStats();
    }
    return .{};
}

/// Print global memory statistics
pub fn printGlobalStats() void {
    const stats = getGlobalStats();
    stats.print();
}

/// Allocator wrapper that tracks allocations
pub const TrackingAllocator = struct {
    underlying_allocator: std.mem.Allocator,
    manager: *AllocatorManager,

    const Self = @This();

    pub fn init(underlying_allocator: std.mem.Allocator, manager: *AllocatorManager) Self {
        return Self{
            .underlying_allocator = underlying_allocator,
            .manager = manager,
        };
    }

    pub fn allocator(self: *Self) std.mem.Allocator {
        return std.mem.Allocator{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .free = free,
            },
        };
    }

    fn alloc(ctx: *anyopaque, len: usize, log2_ptr_align: u8, ret_addr: usize) ?[*]u8 {
        const self: *Self = @ptrCast(@alignCast(ctx));
        const result = self.underlying_allocator.rawAlloc(len, log2_ptr_align, ret_addr);
        if (result != null) {
            self.manager.recordAllocation(len);
        }
        return result;
    }

    fn resize(ctx: *anyopaque, buf: []u8, log2_buf_align: u8, new_len: usize, ret_addr: usize) bool {
        const self: *Self = @ptrCast(@alignCast(ctx));
        const old_len = buf.len;
        const success = self.underlying_allocator.rawResize(buf, log2_buf_align, new_len, ret_addr);

        if (success) {
            if (new_len > old_len) {
                self.manager.recordAllocation(new_len - old_len);
            } else if (old_len > new_len) {
                self.manager.recordDeallocation(old_len - new_len);
            }
        }

        return success;
    }

    fn free(ctx: *anyopaque, buf: []u8, log2_buf_align: u8, ret_addr: usize) void {
        const self: *Self = @ptrCast(@alignCast(ctx));
        self.manager.recordDeallocation(buf.len);
        self.underlying_allocator.rawFree(buf, log2_buf_align, ret_addr);
    }
};

/// Convenience functions for common allocation patterns
pub const allocUtils = struct {
    /// Allocate and zero-initialize memory
    pub fn allocZero(allocator_impl: std.mem.Allocator, comptime T: type, count: usize) ![]T {
        const memory = try allocator_impl.alloc(T, count);
        @memset(std.mem.asBytes(memory), 0);
        return memory;
    }

    /// Allocate a single item
    pub fn allocOne(allocator_impl: std.mem.Allocator, comptime T: type) !*T {
        const memory = try allocator_impl.alloc(T, 1);
        return &memory[0];
    }

    /// Allocate and initialize a single item
    pub fn allocOneInit(allocator_impl: std.mem.Allocator, comptime T: type, init_value: T) !*T {
        const item = try allocOne(allocator_impl, T);
        item.* = init_value;
        return item;
    }

    /// Reallocate with potential shrinking
    pub fn reallocShrink(allocator_impl: std.mem.Allocator, old_memory: anytype, new_count: usize) ![]@TypeOf(old_memory[0]) {
        if (new_count == 0) {
            allocator_impl.free(old_memory);
            return &[_]@TypeOf(old_memory[0]){};
        }

        if (new_count <= old_memory.len) {
            // Try to shrink in place
            if (allocator_impl.resize(old_memory, new_count)) {
                return old_memory[0..new_count];
            }
        }

        // Need to allocate new memory
        return try allocator_impl.realloc(old_memory, new_count);
    }

    /// Safe string duplication with length limit
    pub fn dupeStringLimited(allocator_impl: std.mem.Allocator, str: []const u8, max_len: usize) ![]u8 {
        const actual_len = @min(str.len, max_len);
        return try allocator_impl.dupe(u8, str[0..actual_len]);
    }
};
