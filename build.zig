const std = @import("std");
const builtin = @import("builtin");
pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    try common(optimize);

    const exe = b.addExecutable(.{
        .name = "mufiz",
        .root_source_file = .{ .path = "src/main.zig" },
        .version = .{ .major = 0, .minor = 4, .patch = 0 },
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const c_flags = &.{"-Wall"};

    const lib_scanner = b.addStaticLibrary(.{
        .name = "libmufiz_scanner",
        .root_source_file = .{ .path = "src/scanner.zig" },
        .target = target,
        .optimize = .ReleaseFast,
        .link_libc = true,
    });

    // exe.linkLibrary(lib_memory);
    exe.linkLibrary(lib_scanner);

    exe.addIncludePath(.{ .path = "include" });
    // zig fmt: off
    exe.addCSourceFiles(&.{ 
        "csrc/chunk.c", 
        "csrc/compiler.c", 
        "csrc/debug.c", 
        "csrc/memory.c", 
        "csrc/object.c", 
        "csrc/table.c", 
        "csrc/vm.c", 
        "csrc/value.c" 
    }, c_flags);

    if(builtin.os.tag == .windows){
        exe.addCSourceFile(.{.file = .{.path = "csrc/pre.c"}, .flags = c_flags});
    }

    const clap = b.dependency("clap", .{
        .target = target, 
        .optimize = .ReleaseSafe
    });

    exe.addModule("clap", clap.module("clap"));

    const options = b.addOptions();
    const nostd = b.option(bool, "nostd", "Run Mufi without Standard Library") orelse false;
    options.addOption(bool, "nostd", nostd);
    exe.addOptions("build_opts", options);

    // zig fmt: on
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}

const common_path = "include/common.h";
const common_debug =
    \\/* 
    \\ * File:   common.h
    \\ * Author: Mustafif Khan
    \\ * Brief:  Common imports and preprocessors
    \\ *
    \\ * This program is free software; you can redistribute it and/or modify
    \\ * it under the terms of the GNU General Public License version 2 as
    \\ * published by the Free Software Foundation.
    \\ */
    \\
    \\//> All common imports and preprocessor macros defined here 
    \\#ifndef mufi_common_h 
    \\#define mufi_common_h 
    \\
    \\#include <stdbool.h>
    \\#include <stddef.h>
    \\#include<stdint.h>
    \\#include <stdlib.h>
    \\
    \\#define DEBUG_PRINT_CODE
    \\#define DEBUG_TRACE_EXECUTION
    \\#define DEBUG_STRESS_GC
    \\#define DEBUG_LOG_GC
    \\
    \\#define UINT8_COUNT (UINT8_MAX + 1)
    \\
    \\#endif
    \\
;
const undef_macros =
    \\// In production, we want these debugging to be off
    \\#undef DEBUG_TRACE_EXECUTION
    \\#undef DEBUG_PRINT_CODE
    \\#undef DEBUG_STRESS_GC
    \\#undef DEBUG_LOG_GC
;

const common_release = common_debug ++ undef_macros;

fn common(optimize: std.builtin.OptimizeMode) !void {
    var file = try std.fs.cwd().createFile(common_path, .{});
    defer file.close();
    if (optimize == .Debug) {
        try file.writeAll(common_debug);
    } else {
        try file.writeAll(common_release);
    }
}
