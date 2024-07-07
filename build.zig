const std = @import("std");
const builtin = @import("builtin");

comptime {
    const supported_version = std.SemanticVersion.parse("0.13.0") catch unreachable;
    if (builtin.zig_version.order(supported_version) != .eq) {
        @compileError(std.fmt.comptimePrint("Unsupported Zig version ({}). Required Zig version 0.13.0.", .{builtin.zig_version}));
    }
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    var c_flags: []const []const u8 = undefined;
    const query = target.query;
    if (query.cpu_arch == .x86_64) {
        c_flags = &.{
            "-Wall",                "-O3",    "-ffast-math",
            "-Wno-unused-function", "-mavx2",
        };
    } else {
        c_flags = &.{
            "-Wall",
            "-O3",
            "-ffast-math",
            "-Wno-unused-function",
        };
    }

    try common(optimize);

    const exe = b.addExecutable(.{
        .name = "mufiz",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    if (query.cpu_arch == .wasm32) {
        b.enable_wasmtime = true;
    }

    const lib_scanner = b.addStaticLibrary(.{
        .name = "libmufiz_scanner",
        .root_source_file = b.path("src/scanner.zig"),
        .target = target,
        .optimize = .ReleaseFast,
        .link_libc = true,
    });

    const lib_table = b.addStaticLibrary(.{
        .name = "libmufiz_table",
        .target = target,
        .optimize = .ReleaseFast,
        .link_libc = true,
        .root_source_file = b.path("src/table.zig"),
    });

    lib_table.addCSourceFiles(.{ .root = b.path("core"), .files = &.{
        "value.c",
        "memory.c",
        "object.c",
    }, .flags = c_flags });

    lib_table.addIncludePath(b.path("include"));

    exe.linkLibrary(lib_table);

    exe.linkLibrary(lib_scanner);

    // zig fmt: off
    exe.addCSourceFiles(.{
        .root = b.path("core"),
        .files = &.{
        "chunk.c",
        "compiler.c",
        "debug.c",
        "vm.c",
        "cstd.c",
        },
        .flags = c_flags
    });
    exe.addIncludePath(b.path("include"));
    exe.linkSystemLibrary("m");

    const clap = b.dependency("clap", .{
        .target = target,
        .optimize = .ReleaseSafe
    });

    exe.root_module.addImport("clap", clap.module("clap"));

    const options = b.addOptions();
    const net  = b.option(bool, "enable_net", "Enable Network features") orelse true;
    const fs = b.option(bool, "enable_fs", "Enable File System features") orelse true;
    const sandbox = b.option(bool, "sandbox", "Enable Sandbox Mode (REPL only)") orelse false;
    options.addOption(bool, "enable_net", net);
    options.addOption(bool, "enable_fs", fs);
    options.addOption(bool, "sandbox", sandbox);
    exe.root_module.addOptions("features", options);

    // zig fmt: on
    b.installArtifact(exe);

    const install_docs = b.addInstallDirectory(.{
        .source_dir = exe.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });

    const docs_step = b.step("docs", "Copy documentation artifacts to prefix path");
    docs_step.dependOn(&install_docs.step);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_test = b.addTest(.{ .root_source_file = b.path("src/main.zig"), .target = target, .optimize = optimize });
    exe_test.linkLibC();
    exe_test.addCSourceFiles(.{ .root = b.path("core"), .files = &.{
        "chunk.c",
        "compiler.c",
        "debug.c",
        "vm.c",
        "cstd.c",
    }, .flags = c_flags });
    exe_test.linkLibrary(lib_scanner);
    exe_test.linkLibrary(lib_table);
    exe_test.addIncludePath(b.path("include"));
    const run_exe_test = b.addRunArtifact(exe_test);

    const test_step = b.step("test", "Run Test Suite");
    test_step.dependOn(&run_exe_test.step);
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
    \\
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
