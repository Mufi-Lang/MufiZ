const std = @import("std");
const Value = @cImport(@cInclude("value.h")).Value;
const vm = @cImport(@cInclude("vm.h"));
const conv = @import("conv.zig");

pub const math = @import("stdlib/math.zig");

pub const NativeFn = *const fn (c_int, [*c]Value) callconv(.C) Value;

pub const NativeFunctions = struct {
    map: std.StringArrayHashMap(NativeFn),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{ .map = std.StringArrayHashMap(NativeFn).init(allocator) };
    }

    pub fn deinit(self: *Self) void {
        self.map.deinit();
    }

    pub fn append(self: *Self, name: []const u8, comptime func: NativeFn) !void {
        try self.map.put(name, func);
    }

    pub fn addMath(self: *Self) !void {
        try self.append("log2", &math.log2);
        try self.append("log10", &math.log10);
        try self.append("pi", &math.pi);
        try self.append("sin", &math.sin);
        try self.append("cos", &math.cos);
        try self.append("tan", &math.tan);
        try self.append("asin", &math.asin);
        try self.append("acos", &math.acos);
        try self.append("atan", &math.atan);
    }

    pub fn names(self: Self) []const []const u8 {
        return self.map.keys();
    }
    pub fn functions(self: Self) []const NativeFn {
        return self.map.values();
    }
    pub fn define(self: Self) void {
        for (self.names(), self.functions()) |n, f| {
            vm.defineNative(@ptrCast(n), @ptrCast(f));
        }
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

/// Integer to Double
/// Usage: `i2d(int) double`
pub fn i2d(argc: c_int, args: [*c]Value) callconv(.C) Value {
    if (argc > 1 or !conv.is_int(args[0])) return conv.nil_val();
    const int = conv.as_int(args[0]);
    const double: f64 = @floatFromInt(int);
    return conv.double_val(double);
}

/// Double to Integer
/// Usage: `d2i(double) int`
pub fn d2i(argc: c_int, args: [*c]Value) callconv(.C) Value {
    if (argc > 1 or !conv.is_double(args[0])) return conv.nil_val();
    const double = @ceil(conv.as_double(args[0]));
    const int: i32 = @intFromFloat(double);
    return conv.int_val(int);
}

// String to Integer
// Currently results in segmentation fault
pub fn str2i(argc: c_int, args: [*c]Value) callconv(.C) Value {
    if (argc > 1 or !conv.is_obj(args[0])) return conv.nil_val();
    const str = conv.as_cstring(args[0]);
    const zstr: *[]u8 = @ptrCast(@alignCast(str));
    const int = std.fmt.parseInt(i32, zstr.*, 10) catch |err| {
        std.log.err("{s}\n", .{@errorName(err)});
        return conv.nil_val();
    };
    return conv.int_val(int);
}
