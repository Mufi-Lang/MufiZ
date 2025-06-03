const std = @import("std");
const enable_net = @import("features").enable_net;
const cURL = if (enable_net) @cImport(@cInclude("curl/curl.h")) else {};

const vm = @import("../vm.zig");
const conv = @import("../conv.zig");
const Value = @import("../value.zig").Value;

// HTTP Requests
pub fn http_get(argc: i32, args: [*]Value) Value {
    if (!enable_net) {
        vm.runtimeError("Network functions are disabled!", .{});
        return Value.init_nil();
    }

    if (argc != 1) return stdlib_error("http_get() expects 1 argument", .{ .argn = argc });
    if (!args[0].is_string()) return stdlib_error("http_get() expects a string URL", .{ .value_type = value_type_str(args[0]) });

    const url = args[0].as_string();
    return http_request("GET", url, null) catch |err| {
        vm.runtimeError("HTTP GET request failed: {s}", .{@errorName(err)});
        return Value.init_nil();
    };
}

pub fn http_post(argc: i32, args: [*]Value) Value {
    if (!enable_net) {
        vm.runtimeError("Network functions are disabled!", .{});
        return Value.init_nil();
    }

    if (argc != 2) return stdlib_error("http_post() expects 2 arguments", .{ .argn = argc });
    if (!args[0].is_string()) return stdlib_error("http_post() expects a string URL", .{ .value_type = value_type_str(args[0]) });
    if (!args[1].is_string()) return stdlib_error("http_post() expects a string data payload", .{ .value_type = value_type_str(args[1]) });

    const url = args[0].as_string();
    const data = args[1].as_string();
    
    return http_request("POST", url, data) catch |err| {
        vm.runtimeError("HTTP POST request failed: {s}", .{@errorName(err)});
        return Value.init_nil();
    };
}

pub fn http_put(argc: i32, args: [*]Value) Value {
    if (!enable_net) {
        vm.runtimeError("Network functions are disabled!", .{});
        return Value.init_nil();
    }

    if (argc != 2) return stdlib_error("http_put() expects 2 arguments", .{ .argn = argc });
    if (!args[0].is_string()) return stdlib_error("http_put() expects a string URL", .{ .value_type = value_type_str(args[0]) });
    if (!args[1].is_string()) return stdlib_error("http_put() expects a string data payload", .{ .value_type = value_type_str(args[1]) });

    const url = args[0].as_string();
    const data = args[1].as_string();
    
    return http_request("PUT", url, data) catch |err| {
        vm.runtimeError("HTTP PUT request failed: {s}", .{@errorName(err)});
        return Value.init_nil();
    };
}

pub fn http_delete(argc: i32, args: [*]Value) Value {
    if (!enable_net) {
        vm.runtimeError("Network functions are disabled!", .{});
        return Value.init_nil();
    }

    if (argc != 1) return stdlib_error("http_delete() expects 1 argument", .{ .argn = argc });
    if (!args[0].is_string()) return stdlib_error("http_delete() expects a string URL", .{ .value_type = value_type_str(args[0]) });

    const url = args[0].as_string();
    
    return http_request("DELETE", url, null) catch |err| {
        vm.runtimeError("HTTP DELETE request failed: {s}", .{@errorName(err)});
        return Value.init_nil();
    };
}

// Helper function to set headers on a request
pub fn set_headers(argc: i32, args: [*]Value) Value {
    if (!enable_net) {
        vm.runtimeError("Network functions are disabled!", .{});
        return Value.init_nil();
    }

    if (argc != 1) return stdlib_error("set_headers() expects 1 argument", .{ .argn = argc });
    if (!args[0].is_obj() or !args[0].is_hash_table()) 
        return stdlib_error("set_headers() expects a hash table", .{ .value_type = value_type_str(args[0]) });
    
    // Store headers in global variable - simplified approach
    // In a real implementation, this would need to be more sophisticated
    vm.runtimeError("set_headers() is not yet fully implemented", .{});
    return Value.init_nil();
}

// Socket functions
pub fn create_socket(argc: i32, args: [*]Value) Value {
    _ = argc;
    _ = args;
    if (!enable_net) {
        vm.runtimeError("Network functions are disabled!", .{});
        return Value.init_nil();
    }

    vm.runtimeError("Socket functions not yet implemented", .{});
    return Value.init_nil();
}

pub fn connect(argc: i32, args: [*]Value) Value {
    _ = argc;
    _ = args;
    if (!enable_net) {
        vm.runtimeError("Network functions are disabled!", .{});
        return Value.init_nil();
    }

    vm.runtimeError("Socket functions not yet implemented", .{});
    return Value.init_nil();
}

pub fn send(argc: i32, args: [*]Value) Value {
    _ = argc;
    _ = args;
    if (!enable_net) {
        vm.runtimeError("Network functions are disabled!", .{});
        return Value.init_nil();
    }

    vm.runtimeError("Socket functions not yet implemented", .{});
    return Value.init_nil();
}

pub fn receive(argc: i32, args: [*]Value) Value {
    _ = argc;
    _ = args;
    if (!enable_net) {
        vm.runtimeError("Network functions are disabled!", .{});
        return Value.init_nil();
    }

    vm.runtimeError("Socket functions not yet implemented", .{});
    return Value.init_nil();
}

pub fn close_socket(argc: i32, args: [*]Value) Value {
    _ = argc;
    _ = args;
    if (!enable_net) {
        vm.runtimeError("Network functions are disabled!", .{});
        return Value.init_nil();
    }

    vm.runtimeError("Socket functions not yet implemented", .{});
    return Value.init_nil();
}

// URL parsing
pub fn parse_url(argc: i32, args: [*]Value) Value {
    if (!enable_net) {
        vm.runtimeError("Network functions are disabled!", .{});
        return Value.init_nil();
    }

    if (argc != 1) return stdlib_error("parse_url() expects 1 argument", .{ .argn = argc });
    if (!args[0].is_string()) return stdlib_error("parse_url() expects a string URL", .{ .value_type = value_type_str(args[0]) });

    const url = args[0].as_string();
    
    // Simple URL parsing
    // In a real implementation, this would be more robust
    const result = vm.newHashTable();
    
    // Find scheme (http, https, etc)
    const scheme_end: usize = blk: {
        for (url, 0..) |c, i| {
            if (c == ':') {
                break :blk i;
            }
        }
        break :blk 0;
    };
    
    if (scheme_end > 0) {
        const scheme = url[0..scheme_end];
        vm.hashTableSet(result, Value.init_string(vm.copyString("scheme")), Value.init_string(vm.copyString(scheme)));
    }
    
    return Value.init_obj(result);
}

// URL encoding/decoding
pub fn url_encode(argc: i32, args: [*]Value) Value {
    if (!enable_net) {
        vm.runtimeError("Network functions are disabled!", .{});
        return Value.init_nil();
    }

    if (argc != 1) return stdlib_error("url_encode() expects 1 argument", .{ .argn = argc });
    if (!args[0].is_string()) return stdlib_error("url_encode() expects a string", .{ .value_type = value_type_str(args[0]) });

    const input = args[0].as_string();
    var arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    defer arena.deinit();
    
    const allocator = arena.allocator();
    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();
    
    // Simple URL encoding (not complete)
    for (input) |c| {
        if (std.ascii.isAlphanumeric(c) or c == '-' or c == '_' or c == '.' or c == '~') {
            buffer.append(c) catch return Value.init_nil();
        } else if (c == ' ') {
            buffer.append('%') catch return Value.init_nil();
            buffer.append('2') catch return Value.init_nil();
            buffer.append('0') catch return Value.init_nil();
        } else {
            buffer.append('%') catch return Value.init_nil();
            
            const hex_chars = "0123456789ABCDEF";
            buffer.append(hex_chars[(c >> 4) & 0xF]) catch return Value.init_nil();
            buffer.append(hex_chars[c & 0xF]) catch return Value.init_nil();
        }
    }
    
    return Value.init_string(vm.copyString(buffer.items));
}

// Internal helpers
fn http_request(method: []const u8, url: []const u8, data: ?[]const u8) !Value {
    var arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    // global curl init, or fail
    if (cURL.curl_global_init(cURL.CURL_GLOBAL_ALL) != cURL.CURLE_OK)
        return error.CURLGlobalInitFailed;
    defer cURL.curl_global_cleanup();

    // curl easy handle init, or fail
    const handle = cURL.curl_easy_init() orelse return error.CURLHandleInitFailed;
    defer cURL.curl_easy_cleanup(handle);

    var response_buffer = std.ArrayList(u8).init(allocator);
    defer response_buffer.deinit();

    // setup curl options
    if (cURL.curl_easy_setopt(handle, cURL.CURLOPT_URL, conv.cstr(@constCast(url))) != cURL.CURLE_OK)
        return error.CouldNotSetURL;

    // Set HTTP method and data
    if (std.mem.eql(u8, method, "POST")) {
        if (data) |d| {
            if (cURL.curl_easy_setopt(handle, cURL.CURLOPT_POSTFIELDS, conv.cstr(@constCast(d))) != cURL.CURLE_OK or
                cURL.curl_easy_setopt(handle, cURL.CURLOPT_POSTFIELDSIZE, @intCast(d.len)) != cURL.CURLE_OK) {
                return error.CouldNotSetPostData;
            }
        }
    } else if (std.mem.eql(u8, method, "PUT")) {
        if (cURL.curl_easy_setopt(handle, cURL.CURLOPT_CUSTOMREQUEST, conv.cstr("PUT")) != cURL.CURLE_OK)
            return error.CouldNotSetMethod;
        
        if (data) |d| {
            if (cURL.curl_easy_setopt(handle, cURL.CURLOPT_POSTFIELDS, conv.cstr(@constCast(d))) != cURL.CURLE_OK or
                cURL.curl_easy_setopt(handle, cURL.CURLOPT_POSTFIELDSIZE, @intCast(d.len)) != cURL.CURLE_OK) {
                return error.CouldNotSetPostData;
            }
        }
    } else if (std.mem.eql(u8, method, "DELETE")) {
        if (cURL.curl_easy_setopt(handle, cURL.CURLOPT_CUSTOMREQUEST, conv.cstr("DELETE")) != cURL.CURLE_OK)
            return error.CouldNotSetMethod;
    }

    // set write function callbacks
    if (cURL.curl_easy_setopt(handle, cURL.CURLOPT_WRITEFUNCTION, writeToArrayListCallback) != cURL.CURLE_OK)
        return error.CouldNotSetWriteCallback;
    if (cURL.curl_easy_setopt(handle, cURL.CURLOPT_WRITEDATA, &response_buffer) != cURL.CURLE_OK)
        return error.CouldNotSetWriteCallback;

    // perform request
    if (cURL.curl_easy_perform(handle) != cURL.CURLE_OK)
        return error.FailedToPerformRequest;
        
    return Value.init_string(vm.copyString(response_buffer.items));
}

fn writeToArrayListCallback(data: *anyopaque, size: c_uint, nmemb: c_uint, user_data: *anyopaque) callconv(.C) c_uint {
    var buffer: *std.ArrayList(u8) = @alignCast(@ptrCast(user_data));
    var typed_data: [*]u8 = @ptrCast(data);
    buffer.appendSlice(typed_data[0 .. nmemb * size]) catch return 0;
    return nmemb * size;
}

fn value_type_str(value: Value) []const u8 {
    if (value.is_nil()) return "nil";
    if (value.is_bool()) return "boolean";
    if (value.is_number()) return "number";
    if (value.is_string()) return "string";
    if (value.is_obj()) return "object";
    return "unknown";
}

const Got = union(enum) {
    value_type: []const u8,
    argn: i32,
};

fn stdlib_error(message: []const u8, got: Got) Value {
    switch (got) {
        .value_type => |v| {
            vm.runtimeError("{s} Got {s} type.", .{ message, v });
        },
        .argn => |n| {
            vm.runtimeError("{s}. Got {d} arguments.", .{ message, n });
        },
    }
    return Value.init_nil();
}