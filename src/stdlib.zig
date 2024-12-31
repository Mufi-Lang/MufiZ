const std = @import("std");
const Value = core.value_h.Value;
const vm = @import("vm.zig");
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
    vm.defineNative(@ptrCast(@constCast(name)), @ptrCast(fun));
}

pub fn prelude() void {
    defineNative("what_is", &what_is);
    // defineNative("import", &import);
    defineNative("input", &io.input);
    defineNative("double", &types.double);
    defineNative("int", &types.int);
    defineNative("str", &types.str);
}

pub fn addMath() void {
    defineNative("ln", &math.ln);
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

    return Value.init_nil();
}

// pub fn import(argc: c_int, args: [*c]Value) callconv(.C) Value {
//     if (argc != 1) return stdlib_error("import() expects 1 argument!", .{ .argn = argc });

//     const module = args[0].as_zstring();
//     const eql = std.mem.eql;
//     if (eql(u8, module, "math")) {
//         addMath();
//     } else if (eql(u8, module, "fs")) {
//         addFs();
//     } else if (eql(u8, module, "time")) {
//         addTime();
//     } else if (eql(u8, module, "net")) {
//         addNet();
//     } else {
//         std.log.warn("Unknown module: {s}", .{module});
//     }
//     return Value.init_nil();
// }

const net_funs = if (enable_net) struct {
    pub fn get(argc: c_int, args: [*c]Value) callconv(.C) Value {
        // expects `(url, method)`
        if (argc < 2) return stdlib_error("get() expects at least 2 arguments!", .{ .argn = argc });
        const url = args[0].as_zstring();
        const method: u8 = @intCast(args[1].as_int());
        var options = net.Options{};

        if (argc >= 3) {
            options.user_agent = args[2].as_zstring();
        }
        if (argc == 4) {
            options.authorization_token = args[3].as_zstring();
        }

        const data = net.get(url, @enumFromInt(method), options) catch return Value.init_nil();
        return Value.init_string(data);
    }

    pub fn post(argc: c_int, args: [*c]Value) callconv(.C) Value {
        // expects `(url, method)`
        if (argc < 3) return stdlib_error("get() expects at least 2 arguments!", .{ .argn = argc });
        const url = args[0].as_zstring();
        const data = args[1].as_zstring();
        const method: u8 = @intCast(args[2].as_int());
        var options = net.Options{};

        if (argc >= 4) {
            options.user_agent = args[3].as_zstring();
        }
        if (argc == 5) {
            options.authorization_token = args[4].as_zstring();
        }

        const resp = net.post(url, data, @enumFromInt(method), options) catch return Value.init_nil();
        return Value.init_string(resp);
    }

    pub fn put(argc: c_int, args: [*c]Value) callconv(.C) Value {
        // expects `(url, method)`
        if (argc < 3) return stdlib_error("get() expects at least 2 arguments!", .{ .argn = argc });
        const url = args[0].as_zstring();
        const data = args[1].as_zstring();
        const method: u8 = @intCast(args[2].as_int());
        var options = net.Options{};

        if (argc >= 4) {
            options.user_agent = args[3].as_zstring();
        }
        if (argc == 5) {
            options.authorization_token = args[4].as_zstring();
        }

        const resp = net.put(url, data, @enumFromInt(method), options) catch return Value.init_nil();
        return Value.init_string(resp);
    }

    pub fn delete(argc: c_int, args: [*c]Value) callconv(.C) Value {
        // expects `(url, method)`
        if (argc < 2) return stdlib_error("get() expects at least 2 arguments!", .{ .argn = argc });
        const url = args[0].as_zstring();
        const method: u8 = @intCast(args[1].as_int());
        var options = net.Options{};

        if (argc >= 3) {
            options.user_agent = args[2].as_zstring();
        }
        if (argc == 4) {
            options.authorization_token = args[3].as_zstring();
        }

        const data = net.delete(url, @enumFromInt(method), options) catch return Value.init_nil();
        return Value.init_string(data);
    }

    pub fn open(argc: c_int, args: [*c]Value) callconv(.C) Value {
        if (argc != 1) return stdlib_error("open() expects 1 argument", .{ .argn = argc });
        const url = args[0].as_zstring();
        const op = net.Open.init(@constCast(url));
        _ = op.that() catch {};
        return Value.init_nil();
    }
};

const Got = union(enum) {
    value_type: []const u8,
    argn: i32,
};

pub fn stdlib_error(message: []const u8, got: Got) Value {
    switch (got) {
        .value_type => |v| {
            vm.runtimeError("{s} Got {s} type...", .{ message, v });
        },
        .argn => |n| {
            vm.runtimeError("{s} Got {d} arguments...", .{ message, n });
        },
    }
    return Value.init_nil();
}
