const std = @import("std");
const config = @import("config");
const pre = @cImport(@cInclude("pre.h"));
const vm = @cImport(@cInclude("vm.h"));
const value = @cImport(@cInclude("value.h"));
const Value = value.Value;
const VAL_INT = value.VAL_INT;

// NativeFn = ?*const fn (c_int, [*c]Value) callconv(.C) Value

const NativeFn = *const fn (c_int, [*c]Value) callconv(.C) Value;

fn defineNatives(names: []const []const u8, functions: []const NativeFn) void {
    for (names, functions) |n, f| {
        vm.defineNative(@ptrCast(n), @ptrCast(f));
    }
}

fn int_val(i: i32) Value {
    return Value{ .type = VAL_INT, .as = .{ .num_int = i } };
}

fn as_int(v: Value) i32 {
    return v.as.num_int;
}

// Create an add function for integers
fn addi(argc: c_int, args: [*c]Value) callconv(.C) Value {
    if (argc != 2) {
        return int_val(0);
    } else {
        const a = as_int(args[0]);
        const b = as_int(args[1]);
        return int_val(a + b);
    }
}

pub fn main() !void {
    vm.initVM();
    defer vm.freeVM();
    defineNatives(&.{
        "addi",
    }, &.{
        &addi,
    });
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const check = gpa.deinit();
        if (check == .leak) @panic("memory leak!");
    }
    const allocator = gpa.allocator();
    var args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len == 1) {
        pre.repl();
    } else if (args.len == 2) {
        if (std.mem.eql(u8, args[1], "version")) {
            std.debug.print("{d}.{d}.{d} ({s})\n", .{ pre.MAJOR, pre.MINOR, pre.PATCH, pre.CODENAME });
        } else {
            pre.runFile(args[1]);
        }
    } else {
        std.debug.print("Usage: mufi <path>\n", .{});
    }
}
