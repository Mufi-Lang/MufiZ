// This file provides HTTP related helpers
const std = @import("std");
const Uri = std.Uri;
const http = std.http;
const Headers = http.Headers;
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

    pub fn addToHeaders(self: Self, headers: *Headers) !void {
        try headers.append("Content-Type", self.to_str());
    }
};

pub const Options = struct {
    user_agent: ?[]const u8 = null,
    authorization_token: ?[]const u8 = null,

    const Self = @This();

    pub fn addToHeaders(self: Self, headers: *Headers) !void {
        if (self.user_agent) |ua| {
            try headers.append("User-Agent", ua);
        }
        if (self.authorization_token) |a| {
            try headers.append("Authorization", a);
        }
    }
};

pub fn get(url: []const u8, ct: ContentType, op: Options) ![]u8 {
    var client = Client{ .allocator = GlobalAlloc };
    defer client.deinit();
    const method = http.Method.GET;
    const uri = try Uri.parse(url);
    var headers = Headers.init(GlobalAlloc);
    defer headers.deinit();
    try ct.addToHeaders(&headers);
    try op.addToHeaders(&headers);

    var req = try client.request(method, uri, headers, .{});
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
    const uri = try Uri.parse(url);
    var headers = Headers.init(GlobalAlloc);
    defer headers.deinit();
    try ct.addToHeaders(&headers);
    try op.addToHeaders(&headers);

    var req = try client.request(method, uri, headers, .{});
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
    const uri = try Uri.parse(url);
    var headers = Headers.init(GlobalAlloc);
    defer headers.deinit();
    try ct.addToHeaders(&headers);
    try op.addToHeaders(&headers);

    var req = try client.request(method, uri, headers, .{});
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
    const uri = try Uri.parse(url);
    var headers = Headers.init(GlobalAlloc);
    defer headers.deinit();
    try ct.addToHeaders(&headers);
    try op.addToHeaders(&headers);

    var req = try client.request(method, uri, headers, .{});
    defer req.deinit();

    try req.start();
    try req.wait();
    var buffer: [100000]u8 = undefined;

    const pos = try req.readAll(&buffer);
    return buffer[0..pos];
}
