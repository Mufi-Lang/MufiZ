/// MufiZ Package Cache Manager
/// Handles efficient storage and retrieval of downloaded packages
const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const Allocator = std.mem.Allocator;

pub const CacheError = error{
    CacheDirectoryCreationFailed,
    PackageNotFound,
    InvalidPackageHash,
    CacheCorrupted,
    GitOperationFailed,
    NetworkError,
};

/// Represents a cached package
pub const CachedPackage = struct {
    name: []const u8,
    version: []const u8,
    url: []const u8,
    hash: []const u8,
    path: []const u8,
    allocator: Allocator,

    pub fn deinit(self: *CachedPackage) void {
        self.allocator.free(self.name);
        self.allocator.free(self.version);
        self.allocator.free(self.url);
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
        const home = std.process.getEnvVarOwned(allocator, "HOME") catch |err| {
            if (err == error.EnvironmentVariableNotFound) {
                // Fallback to current directory
                return try allocator.dupe(u8, ".mufiz/cache");
            }
            return err;
        };
        defer allocator.free(home);

        return try std.fmt.allocPrint(allocator, "{s}/.mufiz/cache/{s}", .{ home, CACHE_VERSION });
    }

    /// Ensure cache directory structure exists
    fn ensureCacheDirectory(cache_dir: []const u8) !void {
        fs.cwd().makePath(cache_dir) catch |err| {
            if (err != error.PathAlreadyExists) {
                std.debug.print("Error creating cache directory: {any}\n", .{err});
                return CacheError.CacheDirectoryCreationFailed;
            }
        };

        // Create subdirectories
        const packages_dir = try std.fmt.allocPrint(std.heap.page_allocator, "{s}/packages", .{cache_dir});
        defer std.heap.page_allocator.free(packages_dir);

        fs.cwd().makePath(packages_dir) catch |err| {
            if (err != error.PathAlreadyExists) return err;
        };

        const git_dir = try std.fmt.allocPrint(std.heap.page_allocator, "{s}/git", .{cache_dir});
        defer std.heap.page_allocator.free(git_dir);

        fs.cwd().makePath(git_dir) catch |err| {
            if (err != error.PathAlreadyExists) return err;
        };
    }

    /// Generate a hash for a package URL and version
    fn generatePackageHash(allocator: Allocator, url: []const u8, version: []const u8) ![]const u8 {
        // Simple hash: combine URL and version, then hash
        const combined = try std.fmt.allocPrint(allocator, "{s}@{s}", .{ url, version });
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
    pub fn isCached(self: *Cache, url: []const u8, version: []const u8) !bool {
        const hash = try generatePackageHash(self.allocator, url, version);
        defer self.allocator.free(hash);

        const pkg_path = try std.fmt.allocPrint(
            self.allocator,
            "{s}/packages/{s}",
            .{ self.cache_dir, hash },
        );
        defer self.allocator.free(pkg_path);

        fs.cwd().access(pkg_path, .{}) catch {
            return false;
        };

        return true;
    }

    /// Get the cached package path
    pub fn getCachedPath(self: *Cache, url: []const u8, version: []const u8) !?[]const u8 {
        if (!try self.isCached(url, version)) {
            return null;
        }

        const hash = try generatePackageHash(self.allocator, url, version);
        defer self.allocator.free(hash);

        return try std.fmt.allocPrint(
            self.allocator,
            "{s}/packages/{s}",
            .{ self.cache_dir, hash },
        );
    }

    /// Download and cache a package from GitHub
    pub fn cachePackage(
        self: *Cache,
        name: []const u8,
        url: []const u8,
        version: []const u8,
    ) !CachedPackage {
        // Check if already cached
        if (try self.isCached(url, version)) {
            return try self.loadCachedPackage(name, url, version);
        }

        std.debug.print("📦 Downloading package: {s} ({s})\n", .{ name, version });

        const hash = try generatePackageHash(self.allocator, url, version);
        defer self.allocator.free(hash);

        const pkg_path = try std.fmt.allocPrint(
            self.allocator,
            "{s}/packages/{s}",
            .{ self.cache_dir, hash },
        );
        errdefer self.allocator.free(pkg_path);

        // Clone the repository (shallow clone to save space)
        try self.cloneRepository(url, version, pkg_path);

        std.debug.print("✅ Package cached: {s}\n", .{name});

        return CachedPackage{
            .name = try self.allocator.dupe(u8, name),
            .version = try self.allocator.dupe(u8, version),
            .url = try self.allocator.dupe(u8, url),
            .hash = try self.allocator.dupe(u8, hash),
            .path = pkg_path,
            .allocator = self.allocator,
        };
    }

    /// Load an already cached package
    fn loadCachedPackage(
        self: *Cache,
        name: []const u8,
        url: []const u8,
        version: []const u8,
    ) !CachedPackage {
        const hash = try generatePackageHash(self.allocator, url, version);
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
            .url = try self.allocator.dupe(u8, url),
            .hash = try self.allocator.dupe(u8, hash),
            .path = pkg_path,
            .allocator = self.allocator,
        };
    }

    /// Clone a git repository (shallow clone)
    fn cloneRepository(self: *Cache, url: []const u8, version: []const u8, dest: []const u8) !void {
        _ = self;

        // Use git command with shallow clone and specific tag/branch
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        const arena_allocator = arena.allocator();

        // Shallow clone with depth 1 and specific branch/tag
        const git_args = [_][]const u8{
            "git",
            "clone",
            "--depth=1",
            "--branch",
            version,
            url,
            dest,
        };

        var child = std.process.Child.init(&git_args, arena_allocator);
        child.stdout_behavior = .Ignore;
        child.stderr_behavior = .Ignore;

        const result = child.spawnAndWait() catch {
            std.debug.print("Error: Failed to clone repository\n", .{});
            return CacheError.GitOperationFailed;
        };

        if (result != .Exited or result.Exited != 0) {
            std.debug.print("Error: Git clone failed for {s}@{s}\n", .{ url, version });
            return CacheError.GitOperationFailed;
        }

        // Remove .git directory to save space
        const git_dir = try std.fmt.allocPrint(arena_allocator, "{s}/.git", .{dest});
        fs.cwd().deleteTree(git_dir) catch |err| {
            std.debug.print("Warning: Could not remove .git directory: {any}\n", .{err});
            // Non-fatal, continue
        };
    }

    /// Clear the entire cache
    pub fn clear(self: *Cache) !void {
        std.debug.print("🗑️  Clearing package cache...\n", .{});

        fs.cwd().deleteTree(self.cache_dir) catch |err| {
            std.debug.print("Error clearing cache: {any}\n", .{err});
            return err;
        };

        // Recreate cache directory structure
        try ensureCacheDirectory(self.cache_dir);

        std.debug.print("✅ Cache cleared\n", .{});
    }

    /// Get cache statistics
    pub fn getStats(self: *Cache, allocator: Allocator) !CacheStats {
        var total_size: u64 = 0;
        var package_count: usize = 0;

        const packages_dir = try std.fmt.allocPrint(
            allocator,
            "{s}/packages",
            .{self.cache_dir},
        );
        defer allocator.free(packages_dir);

        var dir = fs.cwd().openDir(packages_dir, .{ .iterate = true }) catch {
            return CacheStats{
                .total_size = 0,
                .package_count = 0,
            };
        };
        defer dir.close();

        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            if (entry.kind == .directory) {
                package_count += 1;
                const size = try self.getDirectorySize(allocator, packages_dir, entry.name);
                total_size += size;
            }
        }

        return CacheStats{
            .total_size = total_size,
            .package_count = package_count,
        };
    }

    /// Get the size of a directory recursively
    fn getDirectorySize(_: *Cache, allocator: Allocator, base: []const u8, name: []const u8) !u64 {
        var total: u64 = 0;
        const path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ base, name });
        defer allocator.free(path);

        var dir = fs.cwd().openDir(path, .{ .iterate = true }) catch {
            return 0;
        };
        defer dir.close();

        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            if (entry.kind == .file) {
                const file_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ path, entry.name });
                defer allocator.free(file_path);

                const file = fs.cwd().openFile(file_path, .{}) catch continue;
                defer file.close();

                const stat = file.stat() catch continue;
                total += stat.size;
            } else if (entry.kind == .directory) {
                const sub_size = try getDirectorySizeHelper(allocator, path, entry.name);
                total += sub_size;
            }
        }

        return total;
    }

    /// Helper function for recursive directory size calculation
    fn getDirectorySizeHelper(allocator: Allocator, base: []const u8, name: []const u8) !u64 {
        var total: u64 = 0;
        const path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ base, name });
        defer allocator.free(path);

        var dir = fs.cwd().openDir(path, .{ .iterate = true }) catch {
            return 0;
        };
        defer dir.close();

        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            if (entry.kind == .file) {
                const file_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ path, entry.name });
                defer allocator.free(file_path);

                const file = fs.cwd().openFile(file_path, .{}) catch continue;
                defer file.close();

                const stat = file.stat() catch continue;
                total += stat.size;
            } else if (entry.kind == .directory) {
                total += try getDirectorySizeHelper(allocator, path, entry.name);
            }
        }

        return total;
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
