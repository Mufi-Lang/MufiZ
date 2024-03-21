const std = @import("std");
const Value = core.value_h.Value;
const vm = @cImport(@cInclude("vm.h"));
const conv = @import("conv.zig");
const core = @import("core");
const enable_net = @import("features").enable_net;
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

pub fn prelude() void {
    vm.defineNative(@ptrCast("what_is"), @ptrCast(&what_is));
    vm.defineNative(@ptrCast("input"), @ptrCast(&io.input));
    vm.defineNative(@ptrCast("double"), @ptrCast(&types.double));
    vm.defineNative(@ptrCast("int"), @ptrCast(&types.int));
    vm.defineNative(@ptrCast("str"), @ptrCast(&types.str));
}

pub fn addMath() void {
    vm.defineNative(@ptrCast("log2"), @ptrCast(&math.log2));
    vm.defineNative(@ptrCast("log10"), @ptrCast(&math.log10));
    vm.defineNative(@ptrCast("pi"), @ptrCast(&math.pi));
    vm.defineNative(@ptrCast("sin"), @ptrCast(&math.sin));
    vm.defineNative(@ptrCast("cos"), @ptrCast(&math.cos));
    vm.defineNative(@ptrCast("tan"), @ptrCast(&math.tan));
    vm.defineNative(@ptrCast("asin"), @ptrCast(&math.asin));
    vm.defineNative(@ptrCast("acos"), @ptrCast(&math.acos));
    vm.defineNative(@ptrCast("atan"), @ptrCast(&math.atan));
    vm.defineNative(@ptrCast("complex"), @ptrCast(&math.complex));
    vm.defineNative(@ptrCast("abs"), @ptrCast(&math.abs));
    vm.defineNative(@ptrCast("phase"), @ptrCast(&math.phase));
    vm.defineNative(@ptrCast("rand"), @ptrCast(&math.rand));
    vm.defineNative(@ptrCast("pow"), @ptrCast(&math.pow));
    vm.defineNative(@ptrCast("sqrt"), @ptrCast(&math.sqrt));
    vm.defineNative(@ptrCast("ceil"), @ptrCast(&math.ceil));
    vm.defineNative(@ptrCast("floor"), @ptrCast(&math.floor));
    vm.defineNative(@ptrCast("round"), @ptrCast(&math.round));
    vm.defineNative(@ptrCast("max"), @ptrCast(&math.max));
}

pub fn addFs() void {
    if (enable_fs) {
        vm.defineNative(@ptrCast("create_file"), @ptrCast(&fs.create_file));
        vm.defineNative(@ptrCast("read_file"), @ptrCast(&fs.read_file));
        vm.defineNative(@ptrCast("write_file"), @ptrCast(&fs.write_file));
        vm.defineNative(@ptrCast("delete_file"), @ptrCast(&fs.delete_file));
        vm.defineNative(@ptrCast("create_dir"), @ptrCast(&fs.create_dir));
        vm.defineNative(@ptrCast("delete_dir"), @ptrCast(&fs.delete_dir));
    } else {
        std.log.warn("Filesystem functions are disabled!");
    }
}

pub fn addTime() void {
    vm.defineNative(@ptrCast("now"), @ptrCast(&time.now));
    vm.defineNative(@ptrCast("now_ns"), @ptrCast(&time.now_ns));
    vm.defineNative(@ptrCast("now_ms"), @ptrCast(&time.now_ms));
}

pub fn addNet() void {
    if (enable_net) {
        vm.defineNative(@ptrCast("get_req"), @ptrCast(&net_funs.get));
        vm.defineNative(@ptrCast("post_req"), @ptrCast(&net_funs.post));
        vm.defineNative(@ptrCast("put_req"), @ptrCast(&net_funs.put));
        vm.defineNative(@ptrCast("del_req"), @ptrCast(&net_funs.delete));
    } else {
        return std.log.warn("Network functions are disabled!");
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

        var data = net.get(url, @enumFromInt(method), options) catch return conv.nil_val();
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

        var data = net.delete(url, @enumFromInt(method), options) catch return conv.nil_val();
        return conv.string_val(data);
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
