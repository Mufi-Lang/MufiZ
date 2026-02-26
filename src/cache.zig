/// MufiZ Package Cache Manager
/// Handles efficient storage and retrieval of downloaded packages
const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const Allocator = std.mem.Allocator;

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
        const subdirs = [_][]const u8{ "packages", "git", "tmp" };
        for (subdirs) |subdir| {
            const dir_path = try std.fmt.allocPrint(std.heap.page_allocator, "{s}/{s}", .{ cache_dir, subdir });
            defer std.heap.page_allocator.free(dir_path);

            fs.cwd().makePath(dir_path) catch |err| {
                if (err != error.PathAlreadyExists) return err;
            };
        }
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
        const hash = try generatePackageHash(self.allocator, src, version);
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
        // Check if already cached
        if (try self.isCached(src, version)) {
            return try self.loadCachedPackage(name, src, version);
        }

        std.debug.print("📦 Downloading package: {s} ({s})\n", .{ name, version });

        const hash = try generatePackageHash(self.allocator, src, version);
        defer self.allocator.free(hash);

        // Define paths
        const final_path = try std.fmt.allocPrint(
            self.allocator,
            "{s}/packages/{s}",
            .{ self.cache_dir, hash },
        );
        errdefer self.allocator.free(final_path);

        // Use a unique temp path to avoid collisions
        // Format: .mufiz/cache/tmp/pkg_<hash>_<random>
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        const tmp_path = try std.fmt.allocPrint(
            self.allocator,
            "{s}/tmp/pkg_{s}_{x}",
            .{ self.cache_dir, hash, seed },
        );
        defer self.allocator.free(tmp_path);

        // Ensure temp directory is clean (though it should be unique)
        fs.cwd().deleteTree(tmp_path) catch {};

        // Clone into temp directory
        try self.cloneRepository(src, src_type, version, tmp_path);

        // Atomic rename from tmp to final
        // If final path exists now (race condition), we accept it and clean up tmp
        fs.cwd().rename(tmp_path, final_path) catch |err| {
            if (err == error.PathAlreadyExists or err == error.AccessDenied) {
                // Another process might have finished downloading it
                fs.cwd().deleteTree(tmp_path) catch {};
                if (try self.isCached(src, version)) {
                    std.debug.print("✅ Package cached (by another process): {s}\n", .{name});
                    return self.loadCachedPackage(name, src, version);
                }
            }
            // Real error
            std.debug.print("Error renaming temp to final cache: {any}\n", .{err});
            fs.cwd().deleteTree(tmp_path) catch {};
            return CacheError.RenameFailed;
        };

        std.debug.print("✅ Package cached: {s}\n", .{name});

        return CachedPackage{
            .name = try self.allocator.dupe(u8, name),
            .version = try self.allocator.dupe(u8, version),
            .src = try self.allocator.dupe(u8, src),
            .hash = try self.allocator.dupe(u8, hash),
            .path = final_path,
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
        // Ensure destination directory exists
        fs.cwd().makePath(destPath) catch |err| {
            if (err != error.PathAlreadyExists) return CacheError.GitOperationFailed;
        };

        // Open source directory for iteration
        var dir = fs.cwd().openDir(srcPath, .{ .iterate = true }) catch {
            return CacheError.GitOperationFailed;
        };
        defer dir.close();

        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            if (shouldIgnore(entry.name)) continue;

            // Build child source and destination paths
            const child_src = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ srcPath, entry.name });
            defer allocator.free(child_src);
            const child_dest = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ destPath, entry.name });
            defer allocator.free(child_dest);

            if (entry.kind == .directory) {
                // Recurse into subdirectory
                try copyDirRecursively(allocator, child_src, child_dest);
            } else if (entry.kind == .file) {
                // Copy file contents
                fs.cwd().copyFile(child_src, fs.cwd(), child_dest, .{}) catch |err| {
                    std.debug.print("Warning: failed to copy file {s}: {any}\n", .{ child_src, err });
                    // Continue on error
                };
            }
        }
    }

    /// Clone or fetch a source (git shallow clone or handle local file paths)
    fn cloneRepository(self: *Cache, src: []const u8, src_type: SourceType, version: []const u8, dest: []const u8) !void {
        _ = self;

        // Use git command with shallow clone and specific tag/branch when src_type is Git
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        const arena_allocator = arena.allocator();

        // Debug: show the incoming source and version
        std.debug.print("pm: cloneRepository called with src='{s}' version='{s}' dest='{s}' type={any}\\n", .{ src, version, dest, src_type });

        // Handle local Mufi project directory copy when src_type is Local
        if (src_type == .Local) {
            std.debug.print("pm: treating src as local path: {s}\\n", .{src});
            try copyDirRecursively(arena_allocator, src, dest);
            std.debug.print("pm: copy of local source complete\\n", .{});
            return;
        }
        // Handle HTTP Tarballs/Zips
        if (src_type == .Http) {
            std.debug.print("pm: downloading http archive from {s}\n", .{src});
            fs.cwd().makePath(dest) catch {};

            // 1. Download to temporary file
            const tar_path = try std.fmt.allocPrint(arena_allocator, "{s}/download.tar.gz", .{dest});
            {
                const args = [_][]const u8{ "curl", "-L", "-o", tar_path, src };
                var child = std.process.Child.init(&args, arena_allocator);
                child.stdout_behavior = .Ignore;
                child.stderr_behavior = .Ignore;
                const term = try child.spawnAndWait();
                if (term != .Exited or term.Exited != 0) {
                    std.debug.print("Error: curl failed for {s}\n", .{src});
                    return CacheError.NetworkError;
                }
            }

            // 2. Extract
            {
                // Detect format? For now assume tar.gz or zip based on extension if possible, or just try tar
                // Simple approach: try tar -xf
                const args = [_][]const u8{ "tar", "-xf", tar_path, "-C", dest, "--strip-components=1" };
                var child = std.process.Child.init(&args, arena_allocator);
                child.stdout_behavior = .Ignore;
                child.stderr_behavior = .Ignore;
                const term = try child.spawnAndWait();
                if (term != .Exited or term.Exited != 0) {
                    // Try unzip if tar failed?
                    std.debug.print("Warning: tar failed, trying unzip...\n", .{});
                    const zip_args = [_][]const u8{ "unzip", "-o", tar_path, "-d", dest };
                    var zip_child = std.process.Child.init(&zip_args, arena_allocator);
                    zip_child.stdout_behavior = .Ignore;
                    zip_child.stderr_behavior = .Ignore;
                    const zip_term = try zip_child.spawnAndWait();
                    if (zip_term != .Exited or zip_term.Exited != 0) {
                        std.debug.print("Error: Failed to extract archive {s}\n", .{src});
                        return CacheError.CacheCorrupted;
                    }
                }
            }

            // 3. Cleanup archive
            fs.cwd().deleteFile(tar_path) catch {};
            std.debug.print("pm: http download and extraction complete\n", .{});
            return;
        }

        // Git Handling        // Strategy depends on whether version is a SHA or a ref (tag/branch)
        if (isGitSha(version)) {
            // SHA Strategy: init -> remote add -> fetch depth=1 SHA -> checkout
            std.debug.print("pm: detected SHA version, using fetch strategy\n", .{});

            fs.cwd().makePath(dest) catch {};

            // 1. git init
            {
                const args = [_][]const u8{ "git", "init" };
                var child = std.process.Child.init(&args, arena_allocator);
                child.cwd = dest;
                child.stdout_behavior = .Ignore;
                child.stderr_behavior = .Ignore;
                _ = try child.spawnAndWait();
            }

            // 2. git remote add origin <url>
            {
                const args = [_][]const u8{ "git", "remote", "add", "origin", src };
                var child = std.process.Child.init(&args, arena_allocator);
                child.cwd = dest;
                child.stdout_behavior = .Ignore;
                child.stderr_behavior = .Ignore;
                _ = try child.spawnAndWait();
            }

            // 3. git fetch --depth=1 origin <sha>
            {
                const args = [_][]const u8{ "git", "fetch", "--depth=1", "origin", version };
                var child = std.process.Child.init(&args, arena_allocator);
                child.cwd = dest;
                child.stdout_behavior = .Ignore;
                child.stderr_behavior = .Ignore;
                const term = try child.spawnAndWait();
                if (term != .Exited or term.Exited != 0) {
                    std.debug.print("Error: Git fetch failed for SHA {s}\n", .{version});
                    return CacheError.GitOperationFailed;
                }
            }

            // 4. git checkout FETCH_HEAD
            {
                const args = [_][]const u8{ "git", "checkout", "FETCH_HEAD" };
                var child = std.process.Child.init(&args, arena_allocator);
                child.cwd = dest;
                child.stdout_behavior = .Ignore;
                child.stderr_behavior = .Ignore;
                _ = try child.spawnAndWait();
            }
        } else {
            // Tag/Branch Strategy: clone --depth=1 --branch <ver>
            // We can clone directly into dest since it is a tmp path now
            const git_args = [_][]const u8{
                "git",
                "clone",
                "--depth=1",
                "--branch",
                version,
                src,
                dest,
            };

            std.debug.print("pm: running git clone for src: {s} branch: {s}\\n", .{ src, version });
            var child = std.process.Child.init(&git_args, arena_allocator);
            child.stdout_behavior = .Ignore;
            child.stderr_behavior = .Ignore;

            const result = child.spawnAndWait() catch {
                std.debug.print("Error: Failed to clone repository or source\\n", .{});
                return CacheError.GitOperationFailed;
            };

            if (result != .Exited or result.Exited != 0) {
                std.debug.print("Error: Git clone failed for {s}@{s}\\n", .{ src, version });
                return CacheError.GitOperationFailed;
            }
        }

        // Remove .git directory to save space (common for both strategies)
        const git_dir = try std.fmt.allocPrint(arena_allocator, "{s}/.git", .{dest});
        fs.cwd().deleteTree(git_dir) catch |err| {
            std.debug.print("Warning: Could not remove .git directory: {any}\\n", .{err});
        };
        std.debug.print("pm: git operation complete and .git removed\\n", .{});
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
