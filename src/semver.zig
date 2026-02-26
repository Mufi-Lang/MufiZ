/// MufiZ Semantic Versioning Module
/// Implements SemVer 2.0.0 parsing and compatibility checking
const std = @import("std");

pub const Version = struct {
    major: u32,
    minor: u32,
    patch: u32,
    pre: ?[]const u8 = null,
    build: ?[]const u8 = null,
    allocator: ?std.mem.Allocator = null,

    pub fn parse(allocator: std.mem.Allocator, text: []const u8) !Version {
        var input = text;
        if (input.len > 0 and input[0] == 'v') input = input[1..];

        var it = std.mem.splitScalar(u8, input, '.');
        const major_str = it.next() orelse return error.InvalidVersion;
        const minor_str = it.next() orelse "0";
        const patch_str = it.next() orelse "0";

        // Handle pre-release and build info in patch_str
        var patch_actual = patch_str;
        var pre: ?[]const u8 = null;
        var build: ?[]const u8 = null;

        if (std.mem.indexOf(u8, patch_str, "+")) |build_idx| {
            build = try allocator.dupe(u8, patch_str[build_idx + 1 ..]);
            patch_actual = patch_str[0..build_idx];
        }

        if (std.mem.indexOf(u8, patch_actual, "-")) |pre_idx| {
            pre = try allocator.dupe(u8, patch_actual[pre_idx + 1 ..]);
            patch_actual = patch_actual[0..pre_idx];
        }

        return Version{
            .major = try std.fmt.parseInt(u32, major_str, 10),
            .minor = try std.fmt.parseInt(u32, minor_str, 10),
            .patch = try std.fmt.parseInt(u32, patch_actual, 10),
            .pre = pre,
            .build = build,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Version) void {
        if (self.allocator) |alloc| {
            if (self.pre) |p| alloc.free(p);
            if (self.build) |b| alloc.free(b);
        }
    }

    pub fn compare(self: Version, other: Version) std.math.Order {
        if (self.major != other.major) return std.math.order(self.major, other.major);
        if (self.minor != other.minor) return std.math.order(self.minor, other.minor);
        if (self.patch != other.patch) return std.math.order(self.patch, other.patch);
        return .eq;
    }

    pub fn isCompatible(self: Version, req: VersionRange) bool {
        return req.isSatisfiedBy(self);
    }
};

pub const VersionRange = struct {
    min: Version,
    max: ?Version,
    include_min: bool = true,
    include_max: bool = false,

    /// Parse range like "^1.2.3" or "~1.2.3" or "1.2.3"
    pub fn parse(allocator: std.mem.Allocator, text: []const u8) !VersionRange {
        if (text.len == 0) return error.EmptyRange;

        if (text[0] == '^') {
            // Caret range: ^1.2.3 means >=1.2.3 <2.0.0
            const min = try Version.parse(allocator, text[1..]);
            var max = min;
            max.major += 1;
            max.minor = 0;
            max.patch = 0;
            return VersionRange{ .min = min, .max = max };
        } else if (text[0] == '~') {
            // Tilde range: ~1.2.3 means >=1.2.3 <1.3.0
            const min = try Version.parse(allocator, text[1..]);
            var max = min;
            max.minor += 1;
            max.patch = 0;
            return VersionRange{ .min = min, .max = max };
        } else {
            // Exact version
            const ver = try Version.parse(allocator, text);
            return VersionRange{ .min = ver, .max = ver, .include_max = true };
        }
    }

    pub fn isSatisfiedBy(self: VersionRange, ver: Version) bool {
        const min_cmp = ver.compare(self.min);
        if (self.include_min) {
            if (min_cmp == .lt) return false;
        } else {
            if (min_cmp != .gt) return false;
        }

        if (self.max) |max| {
            const max_cmp = ver.compare(max);
            if (self.include_max) {
                if (max_cmp == .gt) return false;
            } else {
                if (max_cmp != .lt) return false;
            }
        }

        return true;
    }
};
