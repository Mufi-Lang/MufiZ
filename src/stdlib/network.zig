const std = @import("std");
const enable_net = @import("features").enable_net;
const net = @import("../net.zig");

const vm = @import("../vm.zig");
const Value = @import("../value.zig").Value;
const stdlib_error = @import("../stdlib.zig").stdlib_error;
const ContentType = net.ContentType;
const GlobalAlloc = @import("../main.zig").GlobalAlloc;
const obj_h = @import("../object.zig");
const table_h = @import("../table.zig");

// HTTP Requests
pub fn http_get(argc: i32, args: [*]Value) Value {
    if (!enable_net) {
        vm.runtimeError("Network functions are disabled!", .{});
        return Value.init_nil();
    }

    if (argc < 1 or argc > 1) return stdlib_error("http_get() expects 1 argument", .{ .argn = argc });
    if (!args[0].is_string()) return stdlib_error("http_get() expects a string URL", .{ .value_type = value_type_str(args[0]) });

    const url_obj = args[0].as_string();
    const url = url_obj.chars[0..url_obj.length];
    
    // Default content type to JSON
    const ct = ContentType.JSON;
    const options = net.Options{};
    
    const result = net.get(url, ct, options) catch |err| {
        vm.runtimeError("HTTP GET request failed: {s}", .{@errorName(err)});
        return Value.init_nil();
    };
    
    return Value.init_obj(@ptrCast(obj_h.copyString(result.ptr, result.len)));
}

pub fn http_post(argc: i32, args: [*]Value) Value {
    if (!enable_net) {
        vm.runtimeError("Network functions are disabled!", .{});
        return Value.init_nil();
    }

    if (argc != 2) return stdlib_error("http_post() expects 2 arguments", .{ .argn = argc });
    if (!args[0].is_string()) return stdlib_error("http_post() expects a string URL", .{ .value_type = value_type_str(args[0]) });
    if (!args[1].is_string()) return stdlib_error("http_post() expects a string data payload", .{ .value_type = value_type_str(args[1]) });

    const url_obj = args[0].as_string();
    const url = url_obj.chars[0..url_obj.length];
    const data_obj = args[1].as_string();
    const data = data_obj.chars[0..data_obj.length];
    
    // Default content type to JSON
    const ct = ContentType.JSON;
    const options = net.Options{};
    
    const result = net.post(url, data, ct, options) catch |err| {
        vm.runtimeError("HTTP POST request failed: {s}", .{@errorName(err)});
        return Value.init_nil();
    };
    
    return Value.init_obj(@ptrCast(obj_h.copyString(result.ptr, result.len)));
}

pub fn http_put(argc: i32, args: [*]Value) Value {
    if (!enable_net) {
        vm.runtimeError("Network functions are disabled!", .{});
        return Value.init_nil();
    }

    if (argc != 2) return stdlib_error("http_put() expects 2 arguments", .{ .argn = argc });
    if (!args[0].is_string()) return stdlib_error("http_put() expects a string URL", .{ .value_type = value_type_str(args[0]) });
    if (!args[1].is_string()) return stdlib_error("http_put() expects a string data payload", .{ .value_type = value_type_str(args[1]) });

    const url_obj = args[0].as_string();
    const url = url_obj.chars[0..url_obj.length];
    const data_obj = args[1].as_string();
    const data = data_obj.chars[0..data_obj.length];
    
    // Default content type to JSON
    const ct = ContentType.JSON;
    const options = net.Options{};
    
    const result = net.put(url, data, ct, options) catch |err| {
        vm.runtimeError("HTTP PUT request failed: {s}", .{@errorName(err)});
        return Value.init_nil();
    };
    
    return Value.init_obj(@ptrCast(obj_h.copyString(result.ptr, result.len)));
}

pub fn http_delete(argc: i32, args: [*]Value) Value {
    if (!enable_net) {
        vm.runtimeError("Network functions are disabled!", .{});
        return Value.init_nil();
    }

    if (argc != 1) return stdlib_error("http_delete() expects 1 argument", .{ .argn = argc });
    if (!args[0].is_string()) return stdlib_error("http_delete() expects a string URL", .{ .value_type = value_type_str(args[0]) });

    const url_obj = args[0].as_string();
    const url = url_obj.chars[0..url_obj.length];
    
    // Default content type to JSON
    const ct = ContentType.JSON;
    const options = net.Options{};
    
    const result = net.delete(url, ct, options) catch |err| {
        vm.runtimeError("HTTP DELETE request failed: {s}", .{@errorName(err)});
        return Value.init_nil();
    };
    
    return Value.init_obj(@ptrCast(obj_h.copyString(result.ptr, result.len)));
}

// Set content type for requests
pub fn set_content_type(argc: i32, args: [*]Value) Value {
    if (!enable_net) {
        vm.runtimeError("Network functions are disabled!", .{});
        return Value.init_nil();
    }

    if (argc != 1) return stdlib_error("set_content_type() expects 1 argument", .{ .argn = argc });
    if (!args[0].is_string()) return stdlib_error("set_content_type() expects a string", .{ .value_type = value_type_str(args[0]) });

    const content_type_obj = args[0].as_string();
    const content_type_str = content_type_obj.chars[0..content_type_obj.length];
    
    // Create a hash table with the available content types for reference
    // Store the provided content type for reference
    _ = content_type_str;
    const result = obj_h.newHashTable();
    _ = obj_h.putHashTable(result, obj_h.copyString("text", 4), Value.init_obj(@ptrCast(obj_h.copyString("text/plain", 10))));
    _ = obj_h.putHashTable(result, obj_h.copyString("html", 4), Value.init_obj(@ptrCast(obj_h.copyString("text/html", 9))));
    _ = obj_h.putHashTable(result, obj_h.copyString("json", 4), Value.init_obj(@ptrCast(obj_h.copyString("application/json", 16))));
    _ = obj_h.putHashTable(result, obj_h.copyString("xml", 3), Value.init_obj(@ptrCast(obj_h.copyString("application/xml", 15))));
    
    return Value.init_obj(@ptrCast(result));
}

// Set headers for requests
pub fn set_auth(argc: i32, args: [*]Value) Value {
    if (!enable_net) {
        vm.runtimeError("Network functions are disabled!", .{});
        return Value.init_nil();
    }

    if (argc != 1) return stdlib_error("set_auth() expects 1 argument", .{ .argn = argc });
    if (!args[0].is_string()) return stdlib_error("set_auth() expects a string token", .{ .value_type = value_type_str(args[0]) });

    // This is a placeholder - in a real implementation we'd store this in a global state
    // that gets passed to subsequent requests
    return Value.init_bool(true);
}

// URL parsing
pub fn parse_url(argc: i32, args: [*]Value) Value {
    if (!enable_net) {
        vm.runtimeError("Network functions are disabled!", .{});
        return Value.init_nil();
    }

    if (argc != 1) return stdlib_error("parse_url() expects 1 argument", .{ .argn = argc });
    if (!args[0].is_string()) return stdlib_error("parse_url() expects a string URL", .{ .value_type = value_type_str(args[0]) });

    const url_obj = args[0].as_string();
    const url = url_obj.chars[0..url_obj.length];
    
    // Use Zig's std.Uri for parsing
    const uri = std.Uri.parse(url) catch {
        vm.runtimeError("Failed to parse URL: {s}", .{url});
        return Value.init_nil();
    };
    
    // Create a hash table to hold the parsed URL parts
    const result = obj_h.newHashTable();
    
    // Add the parsed components to the hash table
    if (uri.scheme.len > 0) {
        _ = obj_h.putHashTable(result, obj_h.copyString("scheme", 6), Value.init_obj(@ptrCast(obj_h.copyString(uri.scheme.ptr, uri.scheme.len))));
    }
    if (uri.user) |user| {
        _ = obj_h.putHashTable(result, obj_h.copyString("user", 4), Value.init_obj(@ptrCast(obj_h.copyString(switch (user) {
            .raw => |raw| raw.ptr,
            .percent_encoded => |encoded| encoded.ptr,
        }, switch (user) {
            .raw => |raw| raw.len,
            .percent_encoded => |encoded| encoded.len,
        }))));
    }
    if (uri.password) |password| {
        _ = obj_h.putHashTable(result, obj_h.copyString("password", 8), Value.init_obj(@ptrCast(obj_h.copyString(switch (password) {
            .raw => |raw| raw.ptr,
            .percent_encoded => |encoded| encoded.ptr,
        }, switch (password) {
            .raw => |raw| raw.len,
            .percent_encoded => |encoded| encoded.len,
        }))));
    }
    if (uri.host) |host| {
        _ = obj_h.putHashTable(result, obj_h.copyString("host", 4), Value.init_obj(@ptrCast(obj_h.copyString(switch (host) {
            .raw => |raw| raw.ptr,
            .percent_encoded => |encoded| encoded.ptr,
        }, switch (host) {
            .raw => |raw| raw.len,
            .percent_encoded => |encoded| encoded.len,
        }))));
    }
    if (uri.port != null) {
        _ = obj_h.putHashTable(result, obj_h.copyString("port", 4), Value.init_int(@intCast(uri.port.?)));
    }
    // Path is non-optional Component type
    {
        const path = uri.path;
        _ = obj_h.putHashTable(result, obj_h.copyString("path", 4), Value.init_obj(@ptrCast(obj_h.copyString(switch (path) {
            .raw => |raw| raw.ptr,
            .percent_encoded => |encoded| encoded.ptr,
        }, switch (path) {
            .raw => |raw| raw.len,
            .percent_encoded => |encoded| encoded.len,
        }))));
    }
    if (uri.query) |query| {
        _ = obj_h.putHashTable(result, obj_h.copyString("query", 5), Value.init_obj(@ptrCast(obj_h.copyString(switch (query) {
            .raw => |raw| raw.ptr,
            .percent_encoded => |encoded| encoded.ptr,
        }, switch (query) {
            .raw => |raw| raw.len,
            .percent_encoded => |encoded| encoded.len,
        }))));
    }
    if (uri.fragment) |fragment| {
        _ = obj_h.putHashTable(result, obj_h.copyString("fragment", 8), Value.init_obj(@ptrCast(obj_h.copyString(switch (fragment) {
            .raw => |raw| raw.ptr,
            .percent_encoded => |encoded| encoded.ptr,
        }, switch (fragment) {
            .raw => |raw| raw.len,
            .percent_encoded => |encoded| encoded.len,
        }))));
    }
    
    return Value.init_obj(@ptrCast(result));
}

// URL encoding
pub fn url_encode(argc: i32, args: [*]Value) Value {
    if (!enable_net) {
        vm.runtimeError("Network functions are disabled!", .{});
        return Value.init_nil();
    }

    if (argc != 1) return stdlib_error("url_encode() expects 1 argument", .{ .argn = argc });
    if (!args[0].is_string()) return stdlib_error("url_encode() expects a string", .{ .value_type = value_type_str(args[0]) });

    const input_obj = args[0].as_string();
    const input = input_obj.chars[0..input_obj.length];
    var buffer_array = std.ArrayList(u8).init(std.heap.page_allocator);
    defer buffer_array.deinit();
    
    const allocator = std.heap.page_allocator;
    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();
    
    // URL encoding (RFC 3986)
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
    
    return Value.init_obj(@ptrCast(obj_h.copyString(buffer.items.ptr, buffer.items.len)));
}

// URL decoding
pub fn url_decode(argc: i32, args: [*]Value) Value {
    if (!enable_net) {
        vm.runtimeError("Network functions are disabled!", .{});
        return Value.init_nil();
    }

    if (argc != 1) return stdlib_error("url_decode() expects 1 argument", .{ .argn = argc });
    if (!args[0].is_string()) return stdlib_error("url_decode() expects a string", .{ .value_type = value_type_str(args[0]) });

    const input_obj = args[0].as_string();
    const input = input_obj.chars[0..input_obj.length];
    var buffer = std.ArrayList(u8).init(std.heap.page_allocator);
    defer buffer.deinit();
    
    var i: usize = 0;
    while (i < input.len) {
        const c = input[i];
        if (c == '%' and i + 2 < input.len) {
            const hex1 = input[i + 1];
            const hex2 = input[i + 2];
            const digit1 = std.fmt.charToDigit(hex1, 16) catch 0;
            const digit2 = std.fmt.charToDigit(hex2, 16) catch 0;
            const value = (digit1 << 4) + digit2;
            buffer.append(value) catch return Value.init_nil();
            i += 3;
        } else if (c == '+') {
            buffer.append(' ') catch return Value.init_nil();
            i += 1;
        } else {
            buffer.append(c) catch return Value.init_nil();
            i += 1;
        }
    }
    
    return Value.init_obj(@ptrCast(obj_h.copyString(buffer.items.ptr, buffer.items.len)));
}

// Open URL in browser
pub fn open_url(argc: i32, args: [*]Value) Value {
    if (!enable_net) {
        vm.runtimeError("Network functions are disabled!", .{});
        return Value.init_nil();
    }

    if (argc != 1) return stdlib_error("open_url() expects 1 argument", .{ .argn = argc });
    if (!args[0].is_string()) return stdlib_error("open_url() expects a string URL", .{ .value_type = value_type_str(args[0]) });

    const url_obj = args[0].as_string();
    const url = url_obj.chars[0..url_obj.length];
    
    // Allocate memory for URL that we can pass to Open
    const url_copy = GlobalAlloc.dupe(u8, url) catch {
        vm.runtimeError("Memory allocation failed", .{});
        return Value.init_nil();
    };
    
    // Create Open instance and open URL
    const opener = net.Open.init(url_copy);
    opener.that() catch {
        vm.runtimeError("Failed to open URL: {s}", .{url});
        return Value.init_nil();
    };
    
    return Value.init_bool(true);
}

fn value_type_str(value: Value) []const u8 {
    if (value.is_nil()) return "nil";
    if (value.is_bool()) return "boolean";
    if (value.is_int() or value.is_double() or value.is_complex()) return "number";
    if (value.is_string()) return "string";
    if (value.is_obj()) return "object";
    return "unknown";
}