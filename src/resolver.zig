/// MufiZ Ad-hoc Dependency Resolver
/// Simple topological sort-based dependency resolution
const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;
const cache = @import("cache.zig");
const semver = @import("semver.zig");

pub const ResolverError = error{
    CircularDependency,
    DependencyNotFound,
    InvalidVersion,
    ResolutionFailed,
    VersionConflict,
};

/// Dependency specification from mufi.zon
pub const DependencySpec = struct {
    name: []const u8,
    url: []const u8,
    version: []const u8,
    // Explicit type of the source (enum)
    dep_type: cache.SourceType,
    hash: ?[]const u8 = null,
    allocator: Allocator,

    pub fn init(allocator: Allocator, name: []const u8, url: []const u8, version: []const u8, dep_type: cache.SourceType) !DependencySpec {
        return DependencySpec{
            .name = try allocator.dupe(u8, name),
            .url = try allocator.dupe(u8, url),
            .version = try allocator.dupe(u8, version),
            .dep_type = dep_type,
            .hash = null,
            .allocator = allocator,
        };
    }

    pub fn initAll(allocator: Allocator, name: []const u8, url: []const u8, version: []const u8, dep_type: cache.SourceType, hash: ?[]const u8) !DependencySpec {
        return DependencySpec{
            .name = try allocator.dupe(u8, name),
            .url = try allocator.dupe(u8, url),
            .version = try allocator.dupe(u8, version),
            .dep_type = dep_type,
            .hash = if (hash) |h| try allocator.dupe(u8, h) else null,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *DependencySpec) void {
        self.allocator.free(self.name);
        self.allocator.free(self.url);
        self.allocator.free(self.version);
        if (self.hash) |h| self.allocator.free(h);
    }

    pub fn clone(self: DependencySpec, allocator: Allocator) !DependencySpec {
        return DependencySpec.initAll(allocator, self.name, self.url, self.version, self.dep_type, self.hash);
    }
};

/// Resolved dependency with its dependencies
pub const ResolvedDependency = struct {
    spec: DependencySpec,
    dependencies: ArrayList(DependencySpec),
    depth: usize,
    allocator: Allocator,

    pub fn init(allocator: Allocator, spec: DependencySpec) !ResolvedDependency {
        return ResolvedDependency{
            .spec = try spec.clone(allocator),
            .dependencies = try ArrayList(DependencySpec).initCapacity(allocator, 0),
            .depth = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ResolvedDependency) void {
        self.spec.deinit();
        for (self.dependencies.items) |*dep| {
            dep.deinit();
        }
        self.dependencies.deinit(self.allocator);
    }
};

/// Dependency graph node for resolution
const Node = struct {
    spec: DependencySpec,
    dependencies: ArrayList([]const u8),
    visited: bool,
    in_stack: bool,
    allocator: Allocator,

    pub fn init(allocator: Allocator, spec: DependencySpec) !Node {
        return Node{
            .spec = try spec.clone(allocator),
            .dependencies = try ArrayList([]const u8).initCapacity(allocator, 0),
            .visited = false,
            .in_stack = false,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Node) void {
        self.spec.deinit();
        for (self.dependencies.items) |dep| {
            self.allocator.free(dep);
        }
        self.dependencies.deinit(self.allocator);
    }

    pub fn addDependency(self: *Node, name: []const u8) !void {
        try self.dependencies.append(self.allocator, try self.allocator.dupe(u8, name));
    }
};

/// Ad-hoc dependency resolver
pub const Resolver = struct {
    allocator: Allocator,
    graph: StringHashMap(*Node),
    resolution_order: ArrayList([]const u8),

    /// Try to find a node by name. This tries three forms:
    ///  1) exact name as provided
    ///  2) sanitized form ( '-' -> '_' )
    ///  3) reverse-sanitized form ( '_' -> '-' )
    /// Returns null if not found. This function may allocate temporary buffers so it returns an error on allocation failure.
    pub fn getNodeByName(self: *Resolver, name: []const u8) !?*Node {
        // Try exact match first
        if (self.graph.get(name)) |n| {
            return n;
        }

        // Try sanitized form: '-' -> '_'
        var buf = try self.allocator.alloc(u8, name.len);
        var i: usize = 0;
        while (i < name.len) : (i += 1) {
            const c = name[i];
            if (c == '-') {
                buf[i] = '_';
            } else {
                buf[i] = c;
            }
        }
        const n1 = self.graph.get(buf);
        self.allocator.free(buf);
        if (n1) |nn1| return nn1;

        // Try reverse sanitized: '_' -> '-'
        var buf2 = try self.allocator.alloc(u8, name.len);
        i = 0;
        while (i < name.len) : (i += 1) {
            const c = name[i];
            if (c == '_') {
                buf2[i] = '-';
            } else {
                buf2[i] = c;
            }
        }
        const n2 = self.graph.get(buf2);
        self.allocator.free(buf2);
        if (n2) |nn2| return nn2;

        return null;
    }

    pub fn init(allocator: Allocator) !Resolver {
        return Resolver{
            .allocator = allocator,
            .graph = StringHashMap(*Node).init(allocator),
            .resolution_order = try ArrayList([]const u8).initCapacity(allocator, 0),
        };
    }

    pub fn deinit(self: *Resolver) void {
        var iter = self.graph.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.*.deinit();
            self.allocator.destroy(entry.value_ptr.*);
            self.allocator.free(entry.key_ptr.*);
        }
        self.graph.deinit();

        for (self.resolution_order.items) |name| {
            self.allocator.free(name);
        }
        self.resolution_order.deinit(self.allocator);
    }

    /// Add a dependency to the graph
    pub fn addDependency(self: *Resolver, spec: DependencySpec) !void {
        // If the dependency already exists (in any normalized form), ensure versions are compatible
        if (try self.getNodeByName(spec.name)) |existing| {
            // Check if they are SemVer versions
            const v1_req = semver.VersionRange.parse(self.allocator, spec.version) catch null;
            const v2_actual = semver.Version.parse(self.allocator, existing.spec.version) catch null;

            if (v1_req != null and v2_actual != null) {
                if (!v1_req.?.isSatisfiedBy(v2_actual.?)) {
                    std.debug.print(
                        "⚠️  Version conflict: {s} requires {s} but {s} is already resolved\n",
                        .{ spec.name, spec.version, existing.spec.version },
                    );
                    return ResolverError.VersionConflict;
                }
                return; // Compatible
            }

            // Fallback to exact match for non-semver (branches, etc.)
            if (!std.mem.eql(u8, existing.spec.version, spec.version)) {
                std.debug.print(
                    "⚠️  Version conflict: {s} requires both {s} and {s}\n",
                    .{ spec.name, existing.spec.version, spec.version },
                );
                return ResolverError.VersionConflict;
            }
            return; // Already added with same version
        }

        // Create node and insert using the canonical name (spec.name) as the graph key
        const node = try self.allocator.create(Node);
        node.* = try Node.init(self.allocator, spec);

        const key = try allocator.dupe(u8, spec.name);
        try self.graph.put(key, node);
    }

    /// Add a dependency edge (A depends on B)
    pub fn addEdge(self: *Resolver, from: []const u8, to: []const u8) !void {
        // Resolve both endpoints using normalization-aware lookup
        const from_node_ptr = try self.getNodeByName(from) orelse return ResolverError.DependencyNotFound;
        const to_node_ptr = try self.getNodeByName(to) orelse return ResolverError.DependencyNotFound;

        // Use the canonical name from the target node when creating the edge
        try from_node_ptr.addDependency(to_node_ptr.spec.name);
    }

    /// Resolve dependencies using topological sort
    pub fn resolve(self: *Resolver) !ArrayList(DependencySpec) {
        // Clear previous resolution
        for (self.resolution_order.items) |name| {
            self.allocator.free(name);
        }
        self.resolution_order.clearRetainingCapacity();

        // Reset visited flags
        var iter = self.graph.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.*.visited = false;
            entry.value_ptr.*.in_stack = false;
        }

        // Perform DFS from each unvisited node
        iter = self.graph.iterator();
        while (iter.next()) |entry| {
            if (!entry.value_ptr.*.visited) {
                try self.topologicalSort(entry.key_ptr.*);
            }
        }

        // Build result list in reverse order (dependencies first)
        var result = try ArrayList(DependencySpec).initCapacity(self.allocator, 0);
        errdefer {
            for (result.items) |*item| {
                item.deinit();
            }
            result.deinit(self.allocator);
        }

        // Reverse order: last in resolution_order should be installed first
        var i: usize = self.resolution_order.items.len;
        while (i > 0) {
            i -= 1;
            const name = self.resolution_order.items[i];
            const node = self.graph.get(name) orelse continue;
            try result.append(self.allocator, try node.spec.clone(self.allocator));
        }

        return result;
    }

    /// Topological sort using DFS
    fn topologicalSort(self: *Resolver, name: []const u8) !void {
        // Resolve the node by name using normalization-aware lookup
        const node_ptr = try self.getNodeByName(name) orelse return ResolverError.DependencyNotFound;

        if (node_ptr.in_stack) {
            std.debug.print("❌ Circular dependency detected involving: {s}\n", .{node_ptr.spec.name});
            return ResolverError.CircularDependency;
        }

        if (node_ptr.visited) {
            return;
        }

        // Mark in stack
        node_ptr.in_stack = true;

        // Visit all dependencies first
        for (node_ptr.dependencies.items) |dep_name| {
            try self.topologicalSort(dep_name);
        }

        node_ptr.visited = true;
        node_ptr.in_stack = false;

        // Append canonical name to resolution order (dependencies first)
        try self.resolution_order.append(self.allocator, try self.allocator.dupe(u8, node_ptr.spec.name));
    }

    /// Validate that all dependencies in the graph exist
    pub fn validate(self: *Resolver) !void {
        var iter = self.graph.iterator();
        while (iter.next()) |entry| {
            const node = entry.value_ptr.*;
            for (node.dependencies.items) |dep_name| {
                // Use normalization-aware lookup when checking existence
                if (try self.getNodeByName(dep_name) == null) {
                    std.debug.print(
                        "❌ Missing dependency: {s} requires {s}\n",
                        .{ node.spec.name, dep_name },
                    );
                    return ResolverError.DependencyNotFound;
                }
            }
        }
    }

    /// Print the dependency graph (for debugging)
    pub fn printGraph(self: *Resolver) void {
        std.debug.print("\n📊 Dependency Graph:\n", .{});
        std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});

        var iter = self.graph.iterator();
        while (iter.next()) |entry| {
            const node = entry.value_ptr.*;
            std.debug.print("  {s}@{s}\n", .{ node.spec.name, node.spec.version });
            if (node.dependencies.items.len > 0) {
                for (node.dependencies.items) |dep| {
                    // Try to resolve dependency to canonical name if possible
                    const resolved = self.getNodeByName(dep) catch null;
                    if (resolved) |r| {
                        std.debug.print("    ├─ {s}\n", .{r.spec.name});
                    } else {
                        std.debug.print("    ├─ {s}\n", .{dep});
                    }
                }
            }
        }
        std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n", .{});
    }

    /// Get dependency count
    pub fn getDependencyCount(self: *Resolver) usize {
        return self.graph.count();
    }
};

/// Parse dependencies from a ZON structure
pub fn parseDependencies(
    allocator: Allocator,
    zon_content: []const u8,
) !ArrayList(DependencySpec) {
    // For now, we'll use a simple parser
    // In a full implementation, this would use std.zon.parse
    _ = zon_content;

    const deps = try ArrayList(DependencySpec).initCapacity(allocator, 0);
    // TODO: Implement actual ZON parsing when needed
    return deps;
}

/// Simple version comparator
pub fn compareVersions(v1: []const u8, v2: []const u8) std.math.Order {
    // Simple lexicographic comparison for now
    // In production, use semantic versioning
    return std.mem.order(u8, v1, v2);
}

/// Check if a version string is valid
pub fn isValidVersion(version: []const u8) bool {
    if (version.len == 0) return false;

    // Accept semantic versions (x.y.z) or git tags
    // Simple validation: check if it contains only valid characters
    for (version) |c| {
        if (!std.ascii.isAlphanumeric(c) and c != '.' and c != '-' and c != '_') {
            return false;
        }
    }

    return true;
}

/// Extract repository name from GitHub URL
pub fn extractRepoName(allocator: Allocator, url: []const u8) ![]const u8 {
    // Example: https://github.com/user/repo -> repo
    // Or: https://github.com/user/repo.git -> repo

    // Find last slash
    const last_slash = std.mem.lastIndexOf(u8, url, "/") orelse return error.InvalidUrl;
    var name = url[last_slash + 1 ..];

    // Remove .git suffix if present
    if (std.mem.endsWith(u8, name, ".git")) {
        name = name[0 .. name.len - 4];
    }

    return try allocator.dupe(u8, name);
}

test "resolver basic" {
    const testing = std.testing;
    var resolver = try Resolver.init(testing.allocator);
    defer resolver.deinit();

    var spec1 = try DependencySpec.init(
        testing.allocator,
        "pkg1",
        "https://github.com/user/pkg1",
        "1.0.0",
        .Git,
    );
    defer spec1.deinit();
    try resolver.addDependency(spec1);

    try testing.expectEqual(@as(usize, 1), resolver.getDependencyCount());
}

test "circular dependency detection" {
    const testing = std.testing;
    var resolver = try Resolver.init(testing.allocator);
    defer resolver.deinit();

    var spec1 = try DependencySpec.init(
        testing.allocator,
        "pkg1",
        "https://github.com/user/pkg1",
        "1.0.0",
        .Git,
    );
    defer spec1.deinit();
    try resolver.addDependency(spec1);

    var spec2 = try DependencySpec.init(
        testing.allocator,
        "pkg2",
        "https://github.com/user/pkg2",
        "1.0.0",
        .Git,
    );
    defer spec2.deinit();
    try resolver.addDependency(spec2);

    // Create circular dependency: pkg1 -> pkg2 -> pkg1
    try resolver.addEdge("pkg1", "pkg2");
    try resolver.addEdge("pkg2", "pkg1");

    const result = resolver.resolve();
    try testing.expectError(ResolverError.CircularDependency, result);
}

test "version validation" {
    const testing = std.testing;
    try testing.expect(isValidVersion("1.0.0"));
    try testing.expect(isValidVersion("v2.1.3"));
    try testing.expect(isValidVersion("main"));
    try testing.expect(isValidVersion("feature-branch"));
    try testing.expect(!isValidVersion(""));
    try testing.expect(!isValidVersion("v1.0.0@bad"));
}

test "extract repo name" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const name1 = try extractRepoName(allocator, "https://github.com/user/myrepo");
    defer allocator.free(name1);
    try testing.expectEqualStrings("myrepo", name1);

    const name2 = try extractRepoName(allocator, "https://github.com/user/myrepo.git");
    defer allocator.free(name2);
    try testing.expectEqualStrings("myrepo", name2);
}
