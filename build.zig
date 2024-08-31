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
    const exe = b.addExecutable(.{
        .name = "mufiz",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const exe_check = b.addExecutable(.{
        .name = "mufiz",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    if (target.query.cpu_arch == .wasm32) {
        b.enable_wasmtime = true;
    }

    const clap = b.dependency("clap", .{ .target = target, .optimize = .ReleaseSafe });

    exe.root_module.addImport("clap", clap.module("clap"));
    exe_check.root_module.addImport("clap", clap.module("clap"));

    const options = b.addOptions();
    const net = b.option(bool, "enable_net", "Enable Network features") orelse true;
    const fs = b.option(bool, "enable_fs", "Enable File System features") orelse true;
    const sandbox = b.option(bool, "sandbox", "Enable Sandbox Mode (REPL only)") orelse false;
    options.addOption(bool, "enable_net", net);
    options.addOption(bool, "enable_fs", fs);
    options.addOption(bool, "sandbox", sandbox);

    const debug_options = b.addOptions();
    const debug_print_code = b.option(bool, "print_code", "Enables printing the OpCodes for Debugging") orelse false;
    const debug_trace_execution = b.option(bool, "trace_exec", "Enables Tracing for Debugging") orelse false;
    const debug_stress_gc = b.option(bool, "stress_gc", "Enables GC Stressing") orelse false;
    const debug_log_gc = b.option(bool, "log_gc", "Enables Logging the GC allocations") orelse false;

    debug_options.addOption(bool, "print_code", debug_print_code);
    debug_options.addOption(bool, "trace_exec", debug_trace_execution);
    debug_options.addOption(bool, "stress_gc", debug_stress_gc);
    debug_options.addOption(bool, "log_gc", debug_log_gc);

    exe.root_module.addOptions("features", options);
    exe.root_module.addOptions("debug", debug_options);

    exe_check.root_module.addOptions("features", options);
    exe_check.root_module.addOptions("debug", debug_options);

    // zig fmt: on
    b.installArtifact(exe);

    const install_docs = b.addInstallDirectory(.{
        .source_dir = exe.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });

    const docs_step = b.step("docs", "Copy documentation artifacts to prefix path");
    docs_step.dependOn(&install_docs.step);

    const check = b.step("check", "Check if MufiZ compiles");
    check.dependOn(&exe_check.step);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_test = b.addTest(.{ .root_source_file = b.path("lib/main.zig"), .target = target, .optimize = optimize });
    exe_test.linkLibC();
    //  exe_test.addCSourceFiles(.{ .root = b.path("core"), .files = c_files, .flags = c_flags });
    // exe_test.linkLibrary(lib_scanner);
    // exe_test.linkLibrary(lib_table);
    //   exe_test.addIncludePath(b.path("include"));
    const run_exe_test = b.addRunArtifact(exe_test);

    const test_step = b.step("test", "Run Test Suite");
    test_step.dependOn(&run_exe_test.step);
}
