const std = @import("std");
const mem_utils = @import("mem_utils.zig");
const object_h = @import("object.zig");
const ObjType = object_h.ObjType;

/// Allocation strategy for different object types
pub const AllocationStrategy = enum {
    arena, // Use arena allocator for VM-lifetime objects
    dynamic, // Use GPA for dynamic objects
};

/// Determine allocation strategy based on object type and context
pub fn getStrategyForObject(obj_type: ObjType) AllocationStrategy {
    return switch (obj_type) {
        // VM-lifetime objects that should use arena
        .OBJ_NATIVE => .arena,

        // String literals and constants should use arena
        .OBJ_STRING => .arena, // Note: We'll need context to distinguish literals from dynamic strings

        // Dynamic objects that should use GPA
        .OBJ_FUNCTION => .dynamic,
        .OBJ_CLOSURE => .dynamic,
        .OBJ_UPVALUE => .dynamic,
        .OBJ_CLASS => .dynamic,
        .OBJ_INSTANCE => .dynamic,
        .OBJ_BOUND_METHOD => .dynamic,
        .OBJ_FVECTOR => .dynamic,
        .OBJ_HASH_TABLE => .dynamic,
        .OBJ_LINKED_LIST => .dynamic,
        .OBJ_PAIR => .dynamic,
        .OBJ_RANGE => .dynamic,
        .OBJ_MATRIX => .dynamic,
    };
}

/// Allocate object using appropriate strategy
pub fn allocateObject(size: usize, obj_type: ObjType) !*object_h.Obj {
    const strategy = getStrategyForObject(obj_type);
    const allocator = switch (strategy) {
        .arena => mem_utils.getVMArenaAllocator(),
        .dynamic => mem_utils.getAllocator(),
    };

    const mem = try allocator.alloc(u8, size);

    // Zero out the allocated memory to prevent uninitialized data issues
    @memset(mem, 0);

    const object: *object_h.Obj = @ptrCast(@alignCast(mem.ptr));
    object.type = obj_type;
    object.next = null;

    return object;
}

/// Allocate a native function object (always uses arena)
pub fn allocateNative() !*object_h.ObjNative {
    const obj = try allocateObject(@sizeOf(object_h.ObjNative), .OBJ_NATIVE);
    return @ptrCast(@alignCast(obj));
}

/// Allocate string with explicit strategy
pub fn allocateString(size: usize, strategy: AllocationStrategy) ![]u8 {
    const allocator = switch (strategy) {
        .arena => mem_utils.getVMArenaAllocator(),
        .dynamic => mem_utils.getAllocator(),
    };

    return try allocator.alloc(u8, size);
}

/// Allocate string for native function names (uses arena)
pub fn allocateNativeFunctionName(name: []const u8) ![]u8 {
    return try mem_utils.dupeVMString(name);
}

/// Allocate string for literals and constants (uses arena)
pub fn allocateConstantString(content: []const u8) ![]u8 {
    return try mem_utils.dupeVMString(content);
}

/// Allocate string for dynamic/runtime strings (uses GPA)
pub fn allocateDynamicString(size: usize) ![]u8 {
    const allocator = mem_utils.getAllocator();
    return try allocator.alloc(u8, size);
}

/// Context-aware string allocation helper
pub const StringContext = enum {
    native_function_name,
    string_literal,
    constant,
    dynamic_runtime,
    temporary,
};

pub fn allocateStringWithContext(size: usize, context: StringContext) ![]u8 {
    return switch (context) {
        .native_function_name, .string_literal, .constant => try allocateString(size, .arena),
        .dynamic_runtime, .temporary => try allocateString(size, .dynamic),
    };
}

/// Copy string with appropriate allocation strategy based on context
pub fn copyStringWithContext(chars: []const u8, context: StringContext) ![]u8 {
    const allocator = switch (context) {
        .native_function_name, .string_literal, .constant => mem_utils.getVMArenaAllocator(),
        .dynamic_runtime, .temporary => mem_utils.getAllocator(),
    };

    return try allocator.dupe(u8, chars);
}

/// Statistics about allocation strategies
pub const AllocationStats = struct {
    arena_objects: u32 = 0,
    dynamic_objects: u32 = 0,
    total_arena_bytes: usize = 0,
    total_dynamic_bytes: usize = 0,
};

var stats = AllocationStats{};

/// Get current allocation statistics
pub fn getStats() AllocationStats {
    return stats;
}

/// Reset allocation statistics
pub fn resetStats() void {
    stats = AllocationStats{};
}

/// Print allocation statistics for debugging
pub fn printStats() void {
    std.debug.print("VM Allocation Statistics:\n", .{});
    std.debug.print("  Arena objects: {}\n", .{stats.arena_objects});
    std.debug.print("  Dynamic objects: {}\n", .{stats.dynamic_objects});
    std.debug.print("  Arena bytes: {}\n", .{stats.total_arena_bytes});
    std.debug.print("  Dynamic bytes: {}\n", .{stats.total_dynamic_bytes});
}

/// Update statistics when allocating
fn updateStats(strategy: AllocationStrategy, size: usize) void {
    switch (strategy) {
        .arena => {
            stats.arena_objects += 1;
            stats.total_arena_bytes += size;
        },
        .dynamic => {
            stats.dynamic_objects += 1;
            stats.total_dynamic_bytes += size;
        },
    }
}
