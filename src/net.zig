// This file provides HTTP related helpers
const std = @import("std");
const Uri = std.Uri;
const http = std.http;
const Header = http.Header;
const Client = http.Client;
const GlobalAlloc = @import("main.zig").GlobalAlloc;
const builtin = @import("builtin");

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
    var client = Client{ .allocator = GlobalAlloc };
    defer client.deinit();
    const method = http.Method.GET;

    var req = try client.fetch(.{ .method = method, .headers = .{
        .host = .{ .override = url },
        .authorization = .{ .override = op.auth() },
        .user_agent = .{ .override = op.ua() },
        .content_type = .{ .override = ct.to_str() },
    } });
    defer req.deinit();
    try req.start();
    try req.wait();

    var buffer: [100000]u8 = undefined;

    const pos = try req.readAll(&buffer);
    return buffer[0..pos];
}

pub fn post(url: []const u8, data: []const u8, ct: ContentType, op: Options) ![]u8 {
    var client = Client{ .allocator = GlobalAlloc };
    defer client.deinit();
    const method = http.Method.POST;
    var req = try client.fetch(.{ .method = method, .headers = .{
        .host = .{ .override = url },
        .authorization = .{ .override = op.auth() },
        .user_agent = .{ .override = op.ua() },
        .content_type = .{ .override = ct.to_str() },
    } });
    defer req.deinit();

    req.transfer_encoding = .chunked;

    try req.start();

    try req.writer().writeAll(data);
    try req.finish();

    try req.wait();
    var buffer: [100000]u8 = undefined;

    const pos = try req.readAll(&buffer);
    return buffer[0..pos];
}

pub fn put(url: []const u8, data: []const u8, ct: ContentType, op: Options) ![]u8 {
    var client = Client{ .allocator = GlobalAlloc };
    defer client.deinit();
    const method = http.Method.PUT;
    var req = try client.fetch(.{ .method = method, .headers = .{
        .host = .{ .override = url },
        .authorization = .{ .override = op.auth() },
        .user_agent = .{ .override = op.ua() },
        .content_type = .{ .override = ct.to_str() },
    } });
    defer req.deinit();

    req.transfer_encoding = .chunked;

    try req.start();

    try req.writer().writeAll(data);
    try req.finish();

    try req.wait();
    var buffer: [100000]u8 = undefined;

    const pos = try req.readAll(&buffer);
    return buffer[0..pos];
}

pub fn delete(url: []const u8, ct: ContentType, op: Options) ![]u8 {
    var client = Client{ .allocator = GlobalAlloc };
    defer client.deinit();
    const method = http.Method.DELETE;
    var req = try client.fetch(.{ .method = method, .headers = .{
        .host = .{ .override = url },
        .authorization = .{ .override = op.auth() },
        .user_agent = .{ .override = op.ua() },
        .content_type = .{ .override = ct.to_str() },
    } });
    defer req.deinit();

    try req.start();
    try req.wait();
    var buffer: [100000]u8 = undefined;

    const pos = try req.readAll(&buffer);
    return buffer[0..pos];
}
