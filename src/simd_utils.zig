const std = @import("std");
const builtin = @import("builtin");

/// SIMD capabilities detection
pub const SimdCapabilities = struct {
    available: bool,
    f32_vector_len: usize,
    f64_vector_len: usize,
    u8_vector_len: usize,

    pub fn detect() SimdCapabilities {
        const target = builtin.cpu;
        const arch = builtin.cpu.arch;

        // Determine available SIMD capabilities based on architecture
        var caps = SimdCapabilities{
            .available = false,
            .f32_vector_len = 1,
            .f64_vector_len = 1,
            .u8_vector_len = 1,
        };

        switch (arch) {
            .x86_64 => {
                // Check for AVX2
                if (std.Target.x86.featureSetHas(target.features, .avx2)) {
                    caps.available = true;
                    caps.f32_vector_len = 8; // 256-bit / 32-bit
                    caps.f64_vector_len = 4; // 256-bit / 64-bit
                    caps.u8_vector_len = 32; // 256-bit / 8-bit
                }
                // Check for SSE2 (baseline for x86_64)
                else if (std.Target.x86.featureSetHas(target.features, .sse2)) {
                    caps.available = true;
                    caps.f32_vector_len = 4; // 128-bit / 32-bit
                    caps.f64_vector_len = 2; // 128-bit / 64-bit
                    caps.u8_vector_len = 16; // 128-bit / 8-bit
                }
            },
            .aarch64 => {
                // ARM NEON is always available on AArch64
                caps.available = true;
                caps.f32_vector_len = 4; // 128-bit / 32-bit
                caps.f64_vector_len = 2; // 128-bit / 64-bit
                caps.u8_vector_len = 16; // 128-bit / 8-bit
            },
            .wasm32, .wasm64 => {
                // Check for WASM SIMD
                if (std.Target.wasm.featureSetHas(target.features, .simd128)) {
                    caps.available = true;
                    caps.f32_vector_len = 4;
                    caps.f64_vector_len = 2;
                    caps.u8_vector_len = 16;
                }
            },
            else => {
                // No SIMD support for other architectures
            },
        }

        return caps;
    }
};

/// Get a human-readable architecture name
pub fn getArchitectureName() []const u8 {
    return switch (builtin.cpu.arch) {
        .x86_64 => "x86_64",
        .aarch64 => "ARM64/NEON",
        .wasm32 => "WebAssembly 32-bit",
        .wasm64 => "WebAssembly 64-bit",
        else => "Unknown",
    };
}

// Cached capabilities
var capabilities_cache: ?SimdCapabilities = null;
var capabilities_initialized: bool = false;

/// Get SIMD capabilities (cached after first call)
pub fn getCapabilities() SimdCapabilities {
    if (!capabilities_initialized) {
        capabilities_cache = SimdCapabilities.detect();
        capabilities_initialized = true;
    }
    return capabilities_cache.?;
}

/// SIMD operation configuration
pub const SimdConfig = struct {
    /// Minimum size to use SIMD for vector math operations
    min_simd_size: usize = 32,
    /// Minimum size to use SIMD for memory operations (higher threshold due to overhead)
    /// Memory operations have higher overhead and alignment sensitivity
    min_memory_simd_size: usize = 512,
    /// Whether to force scalar operations (for debugging/testing)
    force_scalar: bool = false,
};

/// Default SIMD configuration
pub var config: SimdConfig = .{};

/// Check if SIMD should be used for a given size
pub inline fn shouldUseSIMD(size: usize) bool {
    if (config.force_scalar) return false;
    const caps = getCapabilities();
    return caps.available and size >= config.min_simd_size;
}

/// Check if SIMD should be used for memory operations
pub inline fn shouldUseMemorySIMD(size: usize) bool {
    if (config.force_scalar) return false;
    const caps = getCapabilities();
    return caps.available and size >= config.min_memory_simd_size;
}

/// Get pointer alignment
inline fn getAlignment(ptr: anytype) usize {
    const addr = @intFromPtr(ptr);
    if (addr == 0) return 0;
    // Find the highest power of 2 that divides the address
    var alignment: usize = 1;
    var temp = addr;
    while (temp & 1 == 0) : (temp >>= 1) {
        alignment <<= 1;
    }
    return alignment;
}

/// Check if pointer is aligned to N bytes
inline fn isAligned(ptr: anytype, comptime alignment: usize) bool {
    return @intFromPtr(ptr) % alignment == 0;
}

/// Optimized SIMD memory operations with alignment handling
pub const SimdMemory = struct {
    /// SIMD-optimized memory copy with alignment awareness
    /// For best performance:
    /// - Use for large buffers (>512 bytes)
    /// - Aligned buffers perform better
    /// - Falls back to @memcpy for small sizes
    pub fn copy(dest: [*]u8, src: [*]const u8, count: usize) void {
        // For small sizes, compiler's @memcpy is faster due to:
        // - Inlining opportunities
        // - Optimized small-copy paths
        // - No SIMD setup overhead
        if (!shouldUseMemorySIMD(count)) {
            @memcpy(dest[0..count], src[0..count]);
            return;
        }

        const caps = getCapabilities();
        const vector_len = caps.u8_vector_len;

        // Branch on vector length at comptime
        if (vector_len == 16) {
            copyWithVectorLen(dest, src, count, 16);
        } else if (vector_len == 32) {
            copyWithVectorLen(dest, src, count, 32);
        } else {
            @memcpy(dest[0..count], src[0..count]);
        }
    }

    fn copyWithVectorLen(dest: [*]u8, src: [*]const u8, count: usize, comptime vector_len: usize) void {
        const VecType = @Vector(vector_len, u8);

        // Copy using overlapping vectors
        var i: usize = 0;
        while (i + vector_len <= count) : (i += vector_len) {
            const vec: VecType = src[i..][0..vector_len].*;
            dest[i..][0..vector_len].* = vec;
        }

        // Handle tail with overlapping vector
        if (i < count) {
            const remaining = count - i;
            if (remaining >= vector_len / 2) {
                // Use overlapping vector for tail
                const tail_start = count - vector_len;
                const vec: VecType = src[tail_start..][0..vector_len].*;
                dest[tail_start..][0..vector_len].* = vec;
            } else {
                // Too small for overlap, copy scalar
                @memcpy(dest[i..count], src[i..count]);
            }
        }
    }

    /// Alignment-aware copy for large buffers
    fn copyAligned(dest: [*]u8, src: [*]const u8, count: usize, comptime vector_len: usize) void {
        if (vector_len != 16 and vector_len != 32) {
            @memcpy(dest[0..count], src[0..count]);
            return;
        }

        const VecType = @Vector(vector_len, u8);
        var i: usize = 0;

        // Align destination pointer if misaligned
        const dest_misalignment = @intFromPtr(dest) % vector_len;
        if (dest_misalignment != 0) {
            const align_bytes = vector_len - dest_misalignment;
            const to_align = @min(align_bytes, count);
            @memcpy(dest[0..to_align], src[0..to_align]);
            i = to_align;
        }

        // Check if source is also aligned after aligning dest
        const src_aligned = isAligned(src + i, vector_len);

        if (src_aligned) {
            // Both aligned - fast path
            while (i + vector_len <= count) : (i += vector_len) {
                const vec: VecType = src[i..][0..vector_len].*;
                dest[i..][0..vector_len].* = vec;
            }
        } else {
            // Dest aligned but source isn't - still benefit from aligned stores
            while (i + vector_len <= count) : (i += vector_len) {
                const vec: VecType = src[i..][0..vector_len].*;
                dest[i..][0..vector_len].* = vec;
            }
        }

        // Copy remaining bytes
        if (i < count) {
            @memcpy(dest[i..count], src[i..count]);
        }
    }

    /// SIMD-optimized memory comparison with early exit
    pub fn compare(ptr1: [*]const u8, ptr2: [*]const u8, count: usize) i32 {
        if (count == 0) return 0;

        // For small sizes, use standard library (highly optimized)
        if (!shouldUseMemorySIMD(count)) {
            return scalarCompare(ptr1, ptr2, count);
        }

        const caps = getCapabilities();
        const vector_len = caps.u8_vector_len;

        // Branch on vector length at comptime
        if (vector_len == 16) {
            return compareWithVectorLen(ptr1, ptr2, count, 16);
        } else if (vector_len == 32) {
            return compareWithVectorLen(ptr1, ptr2, count, 32);
        } else {
            return scalarCompare(ptr1, ptr2, count);
        }
    }

    fn compareWithVectorLen(ptr1: [*]const u8, ptr2: [*]const u8, count: usize, comptime vector_len: usize) i32 {
        const VecType = @Vector(vector_len, u8);

        var i: usize = 0;
        while (i + vector_len <= count) : (i += vector_len) {
            const vec1: VecType = ptr1[i..][0..vector_len].*;
            const vec2: VecType = ptr2[i..][0..vector_len].*;

            // Check for inequality
            if (!std.meta.eql(vec1, vec2)) {
                // Found difference, do scalar compare to find exact position
                return scalarCompare(ptr1 + i, ptr2 + i, vector_len);
            }
        }

        // Compare remaining bytes
        if (i < count) {
            return scalarCompare(ptr1 + i, ptr2 + i, count - i);
        }

        return 0;
    }

    /// SIMD-optimized memory set with alignment awareness
    pub fn set(ptr: [*]u8, value: u8, count: usize) void {
        // For small sizes, @memset is highly optimized
        if (!shouldUseMemorySIMD(count)) {
            @memset(ptr[0..count], value);
            return;
        }

        const caps = getCapabilities();
        const vector_len = caps.u8_vector_len;

        // Branch on vector length at comptime
        if (vector_len == 16) {
            setWithVectorLen(ptr, value, count, 16);
        } else if (vector_len == 32) {
            setWithVectorLen(ptr, value, count, 32);
        } else {
            @memset(ptr[0..count], value);
        }
    }

    fn setWithVectorLen(ptr: [*]u8, value: u8, count: usize, comptime vector_len: usize) void {
        const VecType = @Vector(vector_len, u8);
        const fill_vec: VecType = @splat(value);

        var i: usize = 0;

        // Align destination pointer
        const misalignment = @intFromPtr(ptr) % vector_len;
        if (misalignment != 0) {
            const align_bytes = vector_len - misalignment;
            const to_align = @min(align_bytes, count);
            @memset(ptr[0..to_align], value);
            i = to_align;
        }

        // Fill aligned portion with vectors
        while (i + vector_len <= count) : (i += vector_len) {
            ptr[i..][0..vector_len].* = fill_vec;
        }

        // Fill remaining bytes
        if (i < count) {
            @memset(ptr[i..count], value);
        }
    }

    fn scalarCompare(ptr1: [*]const u8, ptr2: [*]const u8, count: usize) i32 {
        const slice1 = ptr1[0..count];
        const slice2 = ptr2[0..count];
        return switch (std.mem.order(u8, slice1, slice2)) {
            .lt => -1,
            .eq => 0,
            .gt => 1,
        };
    }
};

/// Generic SIMD vector operations for floating point
pub fn SimdVector(comptime T: type) type {
    if (T != f32 and T != f64) {
        @compileError("SimdVector only supports f32 and f64");
    }

    return struct {
        /// Get optimal vector length for this type
        pub fn getVectorLength() usize {
            const caps = getCapabilities();
            return if (T == f32) caps.f32_vector_len else caps.f64_vector_len;
        }

        /// Sum all elements in a slice using SIMD
        pub fn sum(data: []const T) T {
            if (!shouldUseSIMD(data.len * @sizeOf(T))) {
                return scalarSum(data);
            }

            const vec_len = comptime if (T == f64)
                (std.simd.suggestVectorLength(f64) orelse 4)
            else
                (std.simd.suggestVectorLength(f32) orelse 4);
            const VecType = @Vector(vec_len, T);
            var sum_vec: VecType = @splat(@as(T, 0.0));

            const vec_iterations = data.len / vec_len;
            var i: usize = 0;
            while (i < vec_iterations) : (i += 1) {
                const offset = i * vec_len;
                const data_vec: VecType = data[offset..][0..vec_len].*;
                sum_vec += data_vec;
            }

            // Reduce vector to scalar
            var result: T = 0.0;
            for (0..vec_len) |j| {
                result += sum_vec[j];
            }

            // Add remaining elements
            const remaining_start = vec_iterations * vec_len;
            for (data[remaining_start..]) |val| {
                result += val;
            }

            return result;
        }

        /// Element-wise addition: result[i] = a[i] + b[i]
        pub fn add(dest: []T, a: []const T, b: []const T) void {
            const len = @min(@min(dest.len, a.len), b.len);
            if (!shouldUseSIMD(len * @sizeOf(T))) {
                for (0..len) |i| {
                    dest[i] = a[i] + b[i];
                }
                return;
            }

            const vec_len = comptime if (T == f64)
                (std.simd.suggestVectorLength(f64) orelse 4)
            else
                (std.simd.suggestVectorLength(f32) orelse 4);
            const VecType = @Vector(vec_len, T);

            const vec_iterations = len / vec_len;
            var i: usize = 0;
            while (i < vec_iterations) : (i += 1) {
                const offset = i * vec_len;
                const vec_a: VecType = a[offset..][0..vec_len].*;
                const vec_b: VecType = b[offset..][0..vec_len].*;
                dest[offset..][0..vec_len].* = vec_a + vec_b;
            }

            // Handle remaining elements
            const remaining_start = vec_iterations * vec_len;
            for (remaining_start..len) |j| {
                dest[j] = a[j] + b[j];
            }
        }

        /// Element-wise subtraction: result[i] = a[i] - b[i]
        pub fn sub(dest: []T, a: []const T, b: []const T) void {
            const len = @min(@min(dest.len, a.len), b.len);
            if (!shouldUseSIMD(len * @sizeOf(T))) {
                for (0..len) |i| {
                    dest[i] = a[i] - b[i];
                }
                return;
            }

            const vec_len = comptime if (T == f64)
                (std.simd.suggestVectorLength(f64) orelse 4)
            else
                (std.simd.suggestVectorLength(f32) orelse 4);
            const VecType = @Vector(vec_len, T);

            const vec_iterations = len / vec_len;
            var i: usize = 0;
            while (i < vec_iterations) : (i += 1) {
                const offset = i * vec_len;
                const vec_a: VecType = a[offset..][0..vec_len].*;
                const vec_b: VecType = b[offset..][0..vec_len].*;
                dest[offset..][0..vec_len].* = vec_a - vec_b;
            }

            // Handle remaining elements
            const remaining_start = vec_iterations * vec_len;
            for (remaining_start..len) |j| {
                dest[j] = a[j] - b[j];
            }
        }

        /// Element-wise multiplication: result[i] = a[i] * b[i]
        pub fn mul(dest: []T, a: []const T, b: []const T) void {
            const len = @min(@min(dest.len, a.len), b.len);
            if (!shouldUseSIMD(len * @sizeOf(T))) {
                for (0..len) |i| {
                    dest[i] = a[i] * b[i];
                }
                return;
            }

            const vec_len = comptime if (T == f64)
                (std.simd.suggestVectorLength(f64) orelse 4)
            else
                (std.simd.suggestVectorLength(f32) orelse 4);
            const VecType = @Vector(vec_len, T);

            const vec_iterations = len / vec_len;
            var i: usize = 0;
            while (i < vec_iterations) : (i += 1) {
                const offset = i * vec_len;
                const vec_a: VecType = a[offset..][0..vec_len].*;
                const vec_b: VecType = b[offset..][0..vec_len].*;
                dest[offset..][0..vec_len].* = vec_a * vec_b;
            }

            // Handle remaining elements
            const remaining_start = vec_iterations * vec_len;
            for (remaining_start..len) |j| {
                dest[j] = a[j] * b[j];
            }
        }

        /// Element-wise division: result[i] = a[i] / b[i]
        pub fn div(dest: []T, a: []const T, b: []const T) void {
            const len = @min(@min(dest.len, a.len), b.len);
            if (!shouldUseSIMD(len * @sizeOf(T))) {
                for (0..len) |i| {
                    dest[i] = a[i] / b[i];
                }
                return;
            }

            const vec_len = comptime if (T == f64)
                (std.simd.suggestVectorLength(f64) orelse 4)
            else
                (std.simd.suggestVectorLength(f32) orelse 4);
            const VecType = @Vector(vec_len, T);

            const vec_iterations = len / vec_len;
            var i: usize = 0;
            while (i < vec_iterations) : (i += 1) {
                const offset = i * vec_len;
                const vec_a: VecType = a[offset..][0..vec_len].*;
                const vec_b: VecType = b[offset..][0..vec_len].*;
                dest[offset..][0..vec_len].* = vec_a / vec_b;
            }

            // Handle remaining elements
            const remaining_start = vec_iterations * vec_len;
            for (remaining_start..len) |j| {
                dest[j] = a[j] / b[j];
            }
        }

        /// Scale: result[i] = a[i] * scalar
        pub fn scale(dest: []T, a: []const T, scalar: T) void {
            const len = @min(dest.len, a.len);
            if (!shouldUseSIMD(len * @sizeOf(T))) {
                for (0..len) |i| {
                    dest[i] = a[i] * scalar;
                }
                return;
            }

            const vec_len = comptime if (T == f64)
                (std.simd.suggestVectorLength(f64) orelse 4)
            else
                (std.simd.suggestVectorLength(f32) orelse 4);
            const VecType = @Vector(vec_len, T);
            const scalar_vec: VecType = @splat(scalar);

            const vec_iterations = len / vec_len;
            var i: usize = 0;
            while (i < vec_iterations) : (i += 1) {
                const offset = i * vec_len;
                const vec_a: VecType = a[offset..][0..vec_len].*;
                dest[offset..][0..vec_len].* = vec_a * scalar_vec;
            }

            // Handle remaining elements
            const remaining_start = vec_iterations * vec_len;
            for (remaining_start..len) |j| {
                dest[j] = a[j] * scalar;
            }
        }

        /// Add scalar: result[i] = a[i] + scalar
        pub fn addScalar(dest: []T, a: []const T, scalar: T) void {
            const len = @min(dest.len, a.len);
            if (!shouldUseSIMD(len * @sizeOf(T))) {
                for (0..len) |i| {
                    dest[i] = a[i] + scalar;
                }
                return;
            }

            const vec_len = comptime if (T == f64)
                (std.simd.suggestVectorLength(f64) orelse 4)
            else
                (std.simd.suggestVectorLength(f32) orelse 4);
            const VecType = @Vector(vec_len, T);
            const scalar_vec: VecType = @splat(scalar);

            const vec_iterations = len / vec_len;
            var i: usize = 0;
            while (i < vec_iterations) : (i += 1) {
                const offset = i * vec_len;
                const vec_a: VecType = a[offset..][0..vec_len].*;
                dest[offset..][0..vec_len].* = vec_a + scalar_vec;
            }

            // Handle remaining elements
            const remaining_start = vec_iterations * vec_len;
            for (remaining_start..len) |j| {
                dest[j] = a[j] + scalar;
            }
        }

        /// Compute variance with SIMD
        pub fn variance(data: []const T, mean_val: T) T {
            if (!shouldUseSIMD(data.len * @sizeOf(T))) {
                return scalarVariance(data, mean_val);
            }

            const vec_len = comptime if (T == f64)
                (std.simd.suggestVectorLength(f64) orelse 4)
            else
                (std.simd.suggestVectorLength(f32) orelse 4);
            const VecType = @Vector(vec_len, T);
            const mean_vec: VecType = @splat(mean_val);
            var sum_vec: VecType = @splat(@as(T, 0.0));

            const vec_iterations = data.len / vec_len;
            var i: usize = 0;
            while (i < vec_iterations) : (i += 1) {
                const offset = i * vec_len;
                const data_vec: VecType = data[offset..][0..vec_len].*;
                const diff_vec = data_vec - mean_vec;
                sum_vec += diff_vec * diff_vec;
            }

            // Reduce vector to scalar
            var result: T = 0.0;
            for (0..vec_len) |j| {
                result += sum_vec[j];
            }

            // Add remaining elements
            const remaining_start = vec_iterations * vec_len;
            for (data[remaining_start..]) |val| {
                const diff = val - mean_val;
                result += diff * diff;
            }

            return result / @as(T, @floatFromInt(data.len));
        }

        /// Scalar helper for sum
        fn scalarSum(data: []const T) T {
            var result: T = 0.0;
            for (data) |val| {
                result += val;
            }
            return result;
        }

        /// Scalar helper for variance
        fn scalarVariance(data: []const T, mean_val: T) T {
            var sum_sq: T = 0.0;
            for (data) |val| {
                const diff = val - mean_val;
                sum_sq += diff * diff;
            }
            return sum_sq / @as(T, @floatFromInt(data.len));
        }
    };
}

/// Type aliases for common SIMD vector types
pub const SimdF32 = SimdVector(f32);
pub const SimdF64 = SimdVector(f64);

/// Helper to check if current platform has SIMD support
pub fn hasSIMD() bool {
    return getCapabilities().available;
}

test "SIMD capabilities detection" {
    const caps = getCapabilities();
    try std.testing.expect(caps.f32_vector_len >= 1);
    try std.testing.expect(caps.f64_vector_len >= 1);
    try std.testing.expect(caps.u8_vector_len >= 1);
}

test "SimdMemory.copy basic" {
    var src = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };
    var dst = [_]u8{0} ** 10;

    SimdMemory.copy(&dst, &src, 10);

    try std.testing.expectEqualSlices(u8, &src, &dst);
}

test "SimdMemory.compare equal" {
    var buf1 = [_]u8{ 1, 2, 3, 4, 5 };
    var buf2 = [_]u8{ 1, 2, 3, 4, 5 };

    const result = SimdMemory.compare(&buf1, &buf2, 5);
    try std.testing.expectEqual(@as(i32, 0), result);
}

test "SimdMemory.set" {
    var buf = [_]u8{0} ** 20;
    SimdMemory.set(&buf, 42, 20);

    for (buf) |byte| {
        try std.testing.expectEqual(@as(u8, 42), byte);
    }
}

test "SimdF64.add" {
    var a = [_]f64{ 1.0, 2.0, 3.0, 4.0 };
    var b = [_]f64{ 5.0, 6.0, 7.0, 8.0 };
    var result = [_]f64{0.0} ** 4;

    SimdF64.add(&result, &a, &b);

    try std.testing.expectEqual(@as(f64, 6.0), result[0]);
    try std.testing.expectEqual(@as(f64, 8.0), result[1]);
    try std.testing.expectEqual(@as(f64, 10.0), result[2]);
    try std.testing.expectEqual(@as(f64, 12.0), result[3]);
}

test "SimdF64.sum" {
    var data = [_]f64{ 1.0, 2.0, 3.0, 4.0, 5.0 };
    const result = SimdF64.sum(&data);
    try std.testing.expectEqual(@as(f64, 15.0), result);
}
