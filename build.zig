/// MufiZ Build Configuration
/// This build script configures the MufiZ interpreter with various feature flags
/// and debug options. It supports cross-compilation and WASM targets.
///
/// Build Options:
/// - enable_net: Enable network functionality (default: true)
/// - enable_fs: Enable file system access (default: true)
/// - sandbox: Restrict to REPL-only mode (default: false)
/// - print_code: Debug option to print opcodes (default: false)
/// - trace_exec: Debug option to trace execution (default: false)
/// - stress_gc: Debug option to stress test garbage collector (default: false)
/// - log_gc: Debug option to log GC allocations (default: false)

const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    
    // Main executable artifact
    const exe = b.addExecutable(.{
        .name = "mufiz",
        .root_module = b.createModule(.{ .root_source_file = b.path("src/main.zig"), .target = target, .optimize = optimize }),
    });

    // Check-only executable (for 'zig build check')
    const exe_check = b.addExecutable(.{
        .name = "mufiz",
        .root_module = b.createModule(.{ .root_source_file = b.path("src/main.zig"), .target = target, .optimize = optimize }),
    });

    // Enable WASM runtime if targeting WASM32
    if (target.query.cpu_arch == .wasm32) {
        b.enable_wasmtime = true;
    }

    // Add command-line argument parsing dependency
    const clap = b.dependency("clap", .{});
    exe.root_module.addImport("clap", clap.module("clap"));
    exe_check.root_module.addImport("clap", clap.module("clap"));

    // Feature flags configuration
    const options = b.addOptions();
    const net = b.option(bool, "enable_net", "Enable Network features") orelse true;
    const fs = b.option(bool, "enable_fs", "Enable File System features") orelse true;
    const sandbox = b.option(bool, "sandbox", "Enable Sandbox Mode (REPL only)") orelse false;
    options.addOption(bool, "enable_net", net);
    options.addOption(bool, "enable_fs", fs);
    options.addOption(bool, "sandbox", sandbox);

    // Debug options configuration
    const debug_options = b.addOptions();
    const debug_print_code = b.option(bool, "print_code", "Enables printing the OpCodes for Debugging") orelse false;
    const debug_trace_execution = b.option(bool, "trace_exec", "Enables Tracing for Debugging") orelse false;
    const debug_stress_gc = b.option(bool, "stress_gc", "Enables GC Stressing") orelse false;
    const debug_log_gc = b.option(bool, "log_gc", "Enables Logging the GC allocations") orelse false;

    debug_options.addOption(bool, "print_code", debug_print_code);
    debug_options.addOption(bool, "trace_exec", debug_trace_execution);
    debug_options.addOption(bool, "stress_gc", debug_stress_gc);
    debug_options.addOption(bool, "log_gc", debug_log_gc);

    // Apply options to both executables
    exe.root_module.addOptions("features", options);
    exe.root_module.addOptions("debug", debug_options);

    exe_check.root_module.addOptions("features", options);
    exe_check.root_module.addOptions("debug", debug_options);

    b.installArtifact(exe);

    // Documentation generation step
    const install_docs = b.addInstallDirectory(.{
        .source_dir = exe.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });

    const docs_step = b.step("docs", "Copy documentation artifacts to prefix path");
    docs_step.dependOn(&install_docs.step);

    const check = b.step("check", "Check if MufiZ compiles");
    check.dependOn(&exe_check.step);

    // Run step for executing the built binary
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
