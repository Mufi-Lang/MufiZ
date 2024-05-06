const std = @import("std");
const Value = core.value_h.Value;
const vm = @cImport(@cInclude("vm.h"));
const conv = @import("conv.zig");
const core = @import("core.zig");
const enable_net = @import("features").enable_net;
const enable_curl = @import("features").enable_curl;
const enable_fs = @import("features").enable_fs;
const net = if (enable_net) @import("net.zig") else {};
const GlobalAlloc = @import("main.zig").GlobalAlloc;
const cstd = core.cstd_h;

pub const math = @import("stdlib/math.zig");
pub const time = @import("stdlib/time.zig");
pub const types = @import("stdlib/types.zig");
pub const fs = @import("stdlib/fs.zig");
pub const io = @import("stdlib/io.zig");

pub const NativeFn = *const fn (c_int, [*c]Value) callconv(.C) Value;

fn defineNative(name: []const u8, fun: NativeFn) void {
    vm.defineNative(conv.cstr(@constCast(name)), @ptrCast(fun));
}

pub fn prelude() void {
    defineNative("what_is", &what_is);
    defineNative("input", &io.input);
    defineNative("double", &types.double);
    defineNative("int", &types.int);
    defineNative("str", &types.str);
}

pub fn addMath() void {
    defineNative("log2", &math.log2);
    defineNative("log10", &math.log10);
    defineNative("pi", &math.pi);
    defineNative("sin", &math.sin);
    defineNative("cos", &math.cos);
    defineNative("tan", &math.tan);
    defineNative("asin", &math.asin);
    defineNative("acos", &math.acos);
    defineNative("atan", &math.atan);
    defineNative("complex", &math.complex);
    defineNative("abs", &math.abs);
    defineNative("phase", &math.phase);
    defineNative("sfc", &math.sfc);
    defineNative("rand", &math.rand);
    defineNative("randn", &math.randn);
    defineNative("pow", &math.pow);
    defineNative("sqrt", &math.sqrt);
    defineNative("ceil", &math.ceil);
    defineNative("floor", &math.floor);
    defineNative("round", &math.round);
    defineNative("max", &math.max);
    defineNative("min", &math.min);
}

pub fn addFs() void {
    if (enable_fs) {
        defineNative("create_file", &fs.create_file);
        defineNative("read_file", &fs.read_file);
        defineNative("write_file", &fs.write_file);
        defineNative("delete_file", &fs.delete_file);
        defineNative("create_dir", &fs.create_dir);
        defineNative("delete_dir", &fs.delete_dir);
    } else {
        std.log.warn("Filesystem functions are disabled!", .{});
    }
}

pub fn addTime() void {
    defineNative("now", &time.now);
    defineNative("now_ns", &time.now_ns);
    defineNative("now_ms", &time.now_ms);
}

pub fn addNet() void {
    if (enable_net) {
        defineNative("get_req", &net_funs.get);
        defineNative("post_req", &net_funs.post);
        defineNative("put_req", &net_funs.put);
        defineNative("del_req", &net_funs.delete);
        defineNative("open", &net_funs.open);
    } else {
        return std.log.warn("Network functions are disabled!", .{});
    }
}

pub fn what_is(argc: c_int, args: [*c]Value) callconv(.C) Value {
    if (argc != 1) return stdlib_error("what_is() expects 1 argument!", .{ .argn = argc });

    const str = conv.what_is(args[0]);
    std.debug.print("Type: {s}\n", .{str});

    return conv.nil_val();
}

const net_funs = if (enable_net) struct {
    pub fn get(argc: c_int, args: [*c]Value) callconv(.C) Value {
        // expects `(url, method)`
        if (argc < 2) return stdlib_error("get() expects at least 2 arguments!", .{ .argn = argc });
        const url = conv.as_zstring(args[0]);
        const method: u8 = @intCast(conv.as_int(args[1]));
        var options = net.Options{};

        if (argc >= 3) {
            options.user_agent = conv.as_zstring(args[2]);
        }
        if (argc == 4) {
            options.authorization_token = conv.as_zstring(args[3]);
        }

        const data = net.get(url, @enumFromInt(method), options) catch return conv.nil_val();
        return conv.string_val(data);
    }

    pub fn post(argc: c_int, args: [*c]Value) callconv(.C) Value {
        // expects `(url, method)`
        if (argc < 3) return stdlib_error("get() expects at least 2 arguments!", .{ .argn = argc });
        const url = conv.as_zstring(args[0]);
        const data = conv.as_zstring(args[1]);
        const method: u8 = @intCast(conv.as_int(args[2]));
        var options = net.Options{};

        if (argc >= 4) {
            options.user_agent = conv.as_zstring(args[3]);
        }
        if (argc == 5) {
            options.authorization_token = conv.as_zstring(args[4]);
        }

        const resp = net.post(url, data, @enumFromInt(method), options) catch return conv.nil_val();
        return conv.string_val(resp);
    }

    pub fn put(argc: c_int, args: [*c]Value) callconv(.C) Value {
        // expects `(url, method)`
        if (argc < 3) return stdlib_error("get() expects at least 2 arguments!", .{ .argn = argc });
        const url = conv.as_zstring(args[0]);
        const data = conv.as_zstring(args[1]);
        const method: u8 = @intCast(conv.as_int(args[2]));
        var options = net.Options{};

        if (argc >= 4) {
            options.user_agent = conv.as_zstring(args[3]);
        }
        if (argc == 5) {
            options.authorization_token = conv.as_zstring(args[4]);
        }

        const resp = net.put(url, data, @enumFromInt(method), options) catch return conv.nil_val();
        return conv.string_val(resp);
    }

    pub fn delete(argc: c_int, args: [*c]Value) callconv(.C) Value {
        // expects `(url, method)`
        if (argc < 2) return stdlib_error("get() expects at least 2 arguments!", .{ .argn = argc });
        const url = conv.as_zstring(args[0]);
        const method: u8 = @intCast(conv.as_int(args[1]));
        var options = net.Options{};

        if (argc >= 3) {
            options.user_agent = conv.as_zstring(args[2]);
        }
        if (argc == 4) {
            options.authorization_token = conv.as_zstring(args[3]);
        }

        const data = net.delete(url, @enumFromInt(method), options) catch return conv.nil_val();
        return conv.string_val(data);
    }

    pub fn open(argc: c_int, args: [*c]Value) callconv(.C) Value {
        if (argc != 1) return stdlib_error("open() expects 1 argument", .{ .argn = argc });
        const url = conv.as_zstring(args[0]);
        const op = net.Open.init(url);
        _ = op.that() catch {};
        return conv.nil_val();
    }
};

const Got = union(enum) {
    value_type: []const u8,
    argn: i32,
};

pub fn stdlib_error(message: []const u8, got: Got) Value {
    std.log.err("{s}", .{message});
    switch (got) {
        .value_type => |v| std.log.err("Got a {s} type...", .{v}),
        .argn => |n| std.log.err("Got {d} arguments...", .{n}),
    }
    return conv.nil_val();
}
