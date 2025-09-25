// This file provides HTTP related helpers
const std = @import("std");
const Uri = std.Uri;
const http = std.http;
const Header = http.Header;
const Client = http.Client;
const GlobalAlloc = @import("main.zig").GlobalAlloc;
const builtin = @import("builtin");
const cp = std.process.Child;

pub const ContentType = enum(u8) {
    PlainText = 0,
    HTML = 1,
    JSON = 2,
    XML = 3,
    PDF = 4,
    JPEG = 5,
    PNG = 6,

    const Self = @This();

    pub fn to_str(self: Self) []const u8 {
        return switch (self) {
            .PlainText => "text/plain",
            .HTML => "text/html",
            .JSON => "application/json",
            .XML => "application/xml",
            .PDF => "application/pdf",
            .JPEG => "image/jpeg",
            .PNG => "image/png",
        };
    }

    pub fn header(self: Self) Header {
        return .{ .name = "Content-Type", .value = self.to_str() };
    }
};

pub const Options = struct {
    user_agent: ?[]const u8 = null,
    authorization_token: ?[]const u8 = null,

    const Self = @This();

    pub fn ua(self: Self) []const u8 {
        return self.user_agent orelse "Zig HTTP Client";
    }

    pub fn auth(self: Self) []const u8 {
        return self.authorization_token orelse "";
    }
};

pub fn get(url: []const u8, ct: ContentType, op: Options) ![]u8 {
    _ = url; _ = ct; _ = op;
    // HTTP client disabled for Zig 0.15 compatibility
    return try GlobalAlloc.dupe(u8, "HTTP functionality disabled");
}

pub fn post(url: []const u8, data: []const u8, ct: ContentType, op: Options) ![]u8 {
    _ = url; _ = data; _ = ct; _ = op;
    // HTTP client disabled for Zig 0.15 compatibility
    return try GlobalAlloc.dupe(u8, "HTTP functionality disabled");
}

pub fn put(url: []const u8, data: []const u8, ct: ContentType, op: Options) ![]u8 {
    _ = url; _ = data; _ = ct; _ = op;
    // HTTP client disabled for Zig 0.15 compatibility
    return try GlobalAlloc.dupe(u8, "HTTP functionality disabled");
}

pub fn delete(url: []const u8, ct: ContentType, op: Options) ![]u8 {
    _ = url; _ = ct; _ = op;
    // HTTP client disabled for Zig 0.15 compatibility
    return try GlobalAlloc.dupe(u8, "HTTP functionality disabled");
}

/// Inspired by `open-rs`
pub const Open = struct {
    url: []u8,
    os: std.Target.Os.Tag = builtin.target.os.tag,

    pub fn init(url: []u8) Open {
        return .{ .url = url };
    }

    fn os_cmd(self: Open) []const u8 {
        switch (self.os) {
            .windows => return "start",
            .linux => return "xdg-open",
            .macos => return "open",
            else => unreachable, // we only compile for windows, mac and linux
        }
    }

    pub fn that(self: Open) !void {
        var proc = cp.init(&.{ self.os_cmd(), self.url }, GlobalAlloc);
        try proc.spawn();
    }
};
