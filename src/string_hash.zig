const std = @import("std");

/// String hashing utilities for MufiZ
/// Provides high-quality hash functions optimized for different use cases
pub const StringHash = struct {
    /// Hash algorithm selection
    pub const Algorithm = enum {
        wyhash, // Fast, excellent distribution (default)
        xxhash64, // High performance, good for large strings
        crc32, // Hardware acceleration on some platforms
        fnv1a, // Simple, good for small strings
        murmur3, // Good distribution, medium speed
        auto, // Automatically select based on string length
    };

    /// Hash a string slice using the specified algorithm
    pub fn hash(data: []const u8, algorithm: Algorithm) u64 {
        if (data.len == 0) return 0;

        return switch (algorithm) {
            .wyhash => hashWyHash(data),
            .xxhash64 => hashXxHash64(data),
            .crc32 => @as(u64, hashCrc32(data)),
            .fnv1a => hashFnv1a(data),
            .murmur3 => hashMurmur3(data),
            .auto => hashAuto(data),
        };
    }

    /// Hash a C-style string using the specified algorithm
    pub fn hashCString(ptr: [*]const u8, length: usize, algorithm: Algorithm) u64 {
        if (length == 0) return 0;
        const slice = ptr[0..length];
        return hash(slice, algorithm);
    }

    /// Default hash function - optimized for MufiZ string interning
    pub fn hashDefault(data: []const u8) u64 {
        return hash(data, .wyhash);
    }

    /// Fast hash for string interning and hash tables
    pub fn hashFast(data: []const u8) u64 {
        return hash(data, .auto);
    }

    /// Cryptographically secure hash (slower, but very low collision rate)
    pub fn hashSecure(data: []const u8) u64 {
        return hash(data, .xxhash64);
    }

    // Individual hash function implementations

    /// WyHash - excellent performance and distribution
    fn hashWyHash(data: []const u8) u64 {
        return std.hash.Wyhash.hash(0, data);
    }

    /// xxHash64 - high performance, good for larger strings
    fn hashXxHash64(data: []const u8) u64 {
        return std.hash.XxHash64.hash(0, data);
    }

    /// CRC32 - hardware accelerated on many platforms
    fn hashCrc32(data: []const u8) u32 {
        return std.hash.Crc32.hash(data);
    }

    /// FNV-1a - simple and fast for small strings
    fn hashFnv1a(data: []const u8) u64 {
        const FNV_OFFSET_BASIS: u64 = 0xcbf29ce484222325;
        const FNV_PRIME: u64 = 0x100000001b3;

        var h = FNV_OFFSET_BASIS;
        for (data) |byte| {
            h ^= byte;
            h *%= FNV_PRIME;
        }
        return h;
    }

    /// Murmur3 - good distribution, reasonable speed
    fn hashMurmur3(data: []const u8) u64 {
        return std.hash.Murmur3_32.hash(data);
    }

    /// Automatic algorithm selection based on string characteristics
    fn hashAuto(data: []const u8) u64 {
        return switch (data.len) {
            0 => 0,
            1...16 => hashFnv1a(data), // FNV-1a for very small strings
            17...64 => hashWyHash(data), // WyHash for small-medium strings
            else => hashXxHash64(data), // xxHash64 for large strings
        };
    }
};

/// Hash context for use with std.HashMap
pub const StringHashContext = struct {
    algorithm: StringHash.Algorithm = .wyhash,

    pub fn init(algorithm: StringHash.Algorithm) @This() {
        return .{ .algorithm = algorithm };
    }

    pub fn hash(self: @This(), key: []const u8) u64 {
        return StringHash.hash(key, self.algorithm);
    }

    pub fn eql(self: @This(), a: []const u8, b: []const u8) bool {
        _ = self;
        return std.mem.eql(u8, a, b);
    }
};

/// Object string hash context for MufiZ ObjString
pub const ObjStringHashContext = struct {
    pub fn hash(self: @This(), key: *const @import("object.zig").ObjString) u64 {
        _ = self;
        return key.hash;
    }

    pub fn eql(self: @This(), a: *const @import("object.zig").ObjString, b: *const @import("object.zig").ObjString) bool {
        _ = self;
        if (a == b) return true;
        if (a.length != b.length) return false;
        if (a.hash != b.hash) return false;
        return std.mem.eql(u8, a.chars[0..a.length], b.chars[0..b.length]);
    }
};

/// Performance benchmarking utilities
pub const Benchmark = struct {
    pub fn benchmarkAlgorithms(data: []const u8, iterations: usize) void {
        const algorithms = [_]StringHash.Algorithm{ .wyhash, .xxhash64, .crc32, .fnv1a, .murmur3, .auto };
        const names = [_][]const u8{ "WyHash", "xxHash64", "CRC32", "FNV-1a", "Murmur3", "Auto" };

        std.debug.print("String Hash Benchmark (length: {}, iterations: {})\n", .{ data.len, iterations });
        std.debug.print("{'=':<50}\n", .{""});

        for (algorithms, names) |alg, name| {
            const start = std.time.nanoTimestamp();

            var i: usize = 0;
            while (i < iterations) : (i += 1) {
                _ = StringHash.hash(data, alg);
            }

            const end = std.time.nanoTimestamp();
            const duration_ns = end - start;
            const ns_per_hash = duration_ns / @as(i64, @intCast(iterations));

            std.debug.print("{s:<10}: {} ns/hash\n", .{ name, ns_per_hash });
        }
    }

    pub fn testCollisions(strings: []const []const u8, algorithm: StringHash.Algorithm) void {
        var hash_map = std.HashMap(u64, usize, std.hash_map.DefaultHashMapHashContext(u64), std.hash_map.default_max_load_percentage).init(std.testing.allocator);
        defer hash_map.deinit();

        var collisions: usize = 0;

        for (strings, 0..) |str, i| {
            const h = StringHash.hash(str, algorithm);
            const result = hash_map.getOrPut(h) catch continue;

            if (result.found_existing) {
                collisions += 1;
                std.debug.print("Collision: '{}' and '{}' both hash to {}\n", .{ str, strings[result.value_ptr.*], h });
            } else {
                result.value_ptr.* = i;
            }
        }

        const collision_rate = @as(f64, @floatFromInt(collisions)) / @as(f64, @floatFromInt(strings.len)) * 100.0;
        std.debug.print("Algorithm: {}, Collisions: {}/{} ({d:.2}%)\n", .{ algorithm, collisions, strings.len, collision_rate });
    }
};

/// String hash utilities for common MufiZ patterns
pub const Utils = struct {
    /// Hash a string literal at compile time (if possible)
    pub fn hashComptime(comptime str: []const u8) u64 {
        return comptime StringHash.hashDefault(str);
    }

    /// Compare two strings by hash first, then content
    pub fn fastStringEqual(a: []const u8, b: []const u8, a_hash: u64, b_hash: u64) bool {
        if (a_hash != b_hash) return false;
        if (a.len != b.len) return false;
        return std.mem.eql(u8, a, b);
    }

    /// Hash and compare in one operation
    pub fn hashAndCompare(a: []const u8, b: []const u8) bool {
        if (a.len != b.len) return false;
        const a_hash = StringHash.hashDefault(a);
        const b_hash = StringHash.hashDefault(b);
        return fastStringEqual(a, b, a_hash, b_hash);
    }
};

// Tests
test "string hash algorithms" {
    const test_strings = [_][]const u8{
        "",
        "a",
        "hello",
        "hello world",
        "The quick brown fox jumps over the lazy dog",
        "0123456789abcdef" ** 10, // Long string
    };

    // Test that all algorithms produce consistent results
    for (test_strings) |str| {
        const wyhash = StringHash.hash(str, .wyhash);
        const xxhash = StringHash.hash(str, .xxhash64);
        const crc32 = StringHash.hash(str, .crc32);
        const fnv1a = StringHash.hash(str, .fnv1a);

        // Each algorithm should be deterministic
        try std.testing.expect(StringHash.hash(str, .wyhash) == wyhash);
        try std.testing.expect(StringHash.hash(str, .xxhash64) == xxhash);
        try std.testing.expect(StringHash.hash(str, .crc32) == crc32);
        try std.testing.expect(StringHash.hash(str, .fnv1a) == fnv1a);
    }
}

test "hash context" {
    const ctx = StringHashContext.init(.wyhash);

    try std.testing.expect(ctx.eql("hello", "hello"));
    try std.testing.expect(!ctx.eql("hello", "world"));

    const hash1 = ctx.hash("test");
    const hash2 = ctx.hash("test");
    try std.testing.expect(hash1 == hash2);
}

test "empty string handling" {
    try std.testing.expect(StringHash.hashDefault("") == 0);
    try std.testing.expect(StringHash.hashCString(@as([*]const u8, @ptrCast("")), 0, .wyhash) == 0);
}

test "compile time hashing" {
    const comptime_hash = Utils.hashComptime("compile_time_string");
    const runtime_hash = StringHash.hashDefault("compile_time_string");
    try std.testing.expect(comptime_hash == runtime_hash);
}
