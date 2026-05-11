/// MufiZ Package Cache Manager
/// Handles efficient storage and retrieval of downloaded packages
const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const Allocator = std.mem.Allocator;

// Compatibility wrapper for Zig 0.16+
// In 0.16+, file system operations require an Io instance
// For now, we provide stub implementations that don't perform actual file operations
const file_ops_available = false;

fn cwd_compat() std.Io.Dir {
    return std.Io.Dir.cwd();
}

/// Source type for dependencies
pub const SourceType = enum {
    Git,
    Local,
    Http,
};

pub const CacheError = error{
    CacheDirectoryCreationFailed,
    PackageNotFound,
    InvalidPackageHash,
    CacheCorrupted,
    GitOperationFailed,
    NetworkError,
    RenameFailed,
};

/// Represents a cached package
pub const CachedPackage = struct {
    name: []const u8,
    version: []const u8,
    src: []const u8,
    hash: []const u8,
    path: []const u8,
    allocator: Allocator,

    pub fn deinit(self: *CachedPackage) void {
        self.allocator.free(self.name);
        self.allocator.free(self.version);
        self.allocator.free(self.src);
        self.allocator.free(self.hash);
        self.allocator.free(self.path);
    }
};

/// Package cache manager
pub const Cache = struct {
    allocator: Allocator,
    cache_dir: []const u8,

    const CACHE_VERSION = "v1";

    /// Initialize the cache manager
    pub fn init(allocator: Allocator) !Cache {
        const cache_dir = try getCacheDirectory(allocator);
        errdefer allocator.free(cache_dir);

        // Ensure cache directory exists
        try ensureCacheDirectory(cache_dir);

        return Cache{
            .allocator = allocator,
            .cache_dir = cache_dir,
        };
    }

    /// Clean up cache resources
    pub fn deinit(self: *Cache) void {
        self.allocator.free(self.cache_dir);
    }

    /// Get the cache directory path (~/.mufiz/cache)
    fn getCacheDirectory(allocator: Allocator) ![]const u8 {
        var home: []const u8 = undefined;
        
        if (std.c.getenv("HOME")) |home_ptr| {
            const home_len = std.mem.len(home_ptr);
            home = home_ptr[0..home_len];
        } else {
            // Fallback to current directory
            return try allocator.dupe(u8, ".mufiz/cache");
        }

        return try std.fmt.allocPrint(allocator, "{s}/.mufiz/cache/{s}", .{ home, CACHE_VERSION });
    }

    /// Ensure cache directory structure exists
    fn ensureCacheDirectory(cache_dir: []const u8) !void {
        // Stub implementation for Zig 0.16+ compatibility
        // File operations would require Io parameter not available in library context
        _ = cache_dir;
        return;
    }

    /// Generate a hash for a package source and version
    fn generatePackageHash(allocator: Allocator, src: []const u8, version: []const u8) ![]const u8 {
        // Simple hash: combine source and version, then hash
        const combined = try std.fmt.allocPrint(allocator, "{s}@{s}", .{ src, version });
        defer allocator.free(combined);

        var hasher = std.crypto.hash.Blake3.init(.{});
        hasher.update(combined);
        var hash_bytes: [32]u8 = undefined;
        hasher.final(&hash_bytes);

        // Convert to hex string (first 16 bytes for shorter hash)
        const hash_bytes_slice = hash_bytes[0..16];
        const hash_hex = try allocator.alloc(u8, 32);
        const hex_result = std.fmt.bytesToHex(hash_bytes_slice, .lower);
        @memcpy(hash_hex, &hex_result);
        return hash_hex;
    }

    /// Check if a package is already cached
    pub fn isCached(self: *Cache, src: []const u8, version: []const u8) !bool {
        _ = self;
        _ = src;
        _ = version;
        // Stub for Zig 0.16+ compatibility
        return false;
    }

    /// Get the cached package path
    pub fn getCachedPath(self: *Cache, src: []const u8, version: []const u8) !?[]const u8 {
        if (!try self.isCached(src, version)) {
            return null;
        }

        const hash = try generatePackageHash(self.allocator, src, version);
        defer self.allocator.free(hash);

        return try std.fmt.allocPrint(
            self.allocator,
            "{s}/packages/{s}",
            .{ self.cache_dir, hash },
        );
    }

    /// Download and cache a package from a source (git/file/other)
    pub fn cachePackage(
        self: *Cache,
        name: []const u8,
        src: []const u8,
        src_type: SourceType,
        version: []const u8,
    ) !CachedPackage {
        _ = src_type;
        // Stub for Zig 0.16+ compatibility - file operations not available in library context
        const hash = try generatePackageHash(self.allocator, src, version);
        defer self.allocator.free(hash);

        const path = try std.fmt.allocPrint(
            self.allocator,
            "{s}/packages/{s}",
            .{ self.cache_dir, hash },
        );

        return CachedPackage{
            .name = try self.allocator.dupe(u8, name),
            .version = try self.allocator.dupe(u8, version),
            .src = try self.allocator.dupe(u8, src),
            .hash = try self.allocator.dupe(u8, hash),
            .path = path,
            .allocator = self.allocator,
        };
    }

    /// Load an already cached package
    fn loadCachedPackage(
        self: *Cache,
        name: []const u8,
        src: []const u8,
        version: []const u8,
    ) !CachedPackage {
        const hash = try generatePackageHash(self.allocator, src, version);
        defer self.allocator.free(hash);

        const pkg_path = try std.fmt.allocPrint(
            self.allocator,
            "{s}/packages/{s}",
            .{ self.cache_dir, hash },
        );
        errdefer self.allocator.free(pkg_path);

        std.debug.print("♻️  Using cached: {s} ({s})\n", .{ name, version });

        return CachedPackage{
            .name = try self.allocator.dupe(u8, name),
            .version = try self.allocator.dupe(u8, version),
            .src = try self.allocator.dupe(u8, src),
            .hash = try self.allocator.dupe(u8, hash),
            .path = pkg_path,
            .allocator = self.allocator,
        };
    }

    /// Check if string looks like a Git SHA1 (40 hex chars)
    fn isGitSha(s: []const u8) bool {
        if (s.len != 40) return false;
        for (s) |c| {
            if (!std.ascii.isHex(c)) return false;
        }
        return true;
    }

    /// Check if a file/dir name should be ignored during local copy
    fn shouldIgnore(name: []const u8) bool {
        const ignore_list = [_][]const u8{
            ".git",
            "zig-cache",
            "zig-out",
            "node_modules",
            ".DS_Store",
            ".vscode",
            ".idea",
            "build", // common build dir
            "dist", // common dist dir
        };
        for (ignore_list) |ignored| {
            if (std.mem.eql(u8, name, ignored)) return true;
        }
        return false;
    }

    /// Recursively copy a directory, ignoring build artifacts
    fn copyDirRecursively(allocator: Allocator, srcPath: []const u8, destPath: []const u8) !void {
        _ = allocator;
        _ = srcPath;
        _ = destPath;
        // Stub for Zig 0.16+ compatibility
        return;
    }

    /// Clone or fetch a source (git shallow clone or handle local file paths)
    fn cloneRepository(self: *Cache, src: []const u8, src_type: SourceType, version: []const u8, dest: []const u8) !void {
        _ = self;
        _ = src;
        _ = src_type;
        _ = version;
        _ = dest;
        // Stub for Zig 0.16+ compatibility - file operations not available in library context
        return;
    }

    /// Clear the entire cache
    pub fn clear(self: *Cache) !void {
        _ = self;
        std.debug.print("🗑️  Clearing package cache (stub for Zig 0.16+)...\n", .{});
    }

    /// Get cache statistics
    pub fn getStats(self: *Cache, allocator: Allocator) !CacheStats {
        _ = self;
        _ = allocator;
        // Stub for Zig 0.16+ compatibility
        return CacheStats{
            .total_size = 0,
            .package_count = 0,
        };
    }

    /// Get the size of a directory recursively
    fn getDirectorySize(_: *Cache, allocator: Allocator, base: []const u8, name: []const u8) !u64 {
        _ = allocator;
        _ = base;
        _ = name;
        // Stub for Zig 0.16+ compatibility
        return 0;
    }

    /// Helper function for recursive directory size calculation
    fn getDirectorySizeHelper(allocator: Allocator, base: []const u8, name: []const u8) !u64 {
        _ = allocator;
        _ = base;
        _ = name;
        // Stub for Zig 0.16+ compatibility
        return 0;
    }
};

/// Cache statistics
pub const CacheStats = struct {
    total_size: u64,
    package_count: usize,

    /// Format size in human-readable format
    pub fn formatSize(self: CacheStats, allocator: Allocator) ![]const u8 {
        const size = self.total_size;
        if (size < 1024) {
            return try std.fmt.allocPrint(allocator, "{d} B", .{size});
        } else if (size < 1024 * 1024) {
            return try std.fmt.allocPrint(allocator, "{d:.2} KB", .{@as(f64, @floatFromInt(size)) / 1024.0});
        } else if (size < 1024 * 1024 * 1024) {
            return try std.fmt.allocPrint(allocator, "{d:.2} MB", .{@as(f64, @floatFromInt(size)) / (1024.0 * 1024.0)});
        } else {
            return try std.fmt.allocPrint(allocator, "{d:.2} GB", .{@as(f64, @floatFromInt(size)) / (1024.0 * 1024.0 * 1024.0)});
        }
    }
};
