/// MufiZ Build Configuration
/// This build script configures the MufiZ interpreter and library with various feature flags
/// and debug options. It supports cross-compilation and WASM targets.
///
/// Artifacts:
/// - libmufiz: Static library exposing core compiler and interpreter functionality
/// - mufiz: Command-line executable for running scripts and REPL
/// - library_usage: Example demonstrating library usage
///
/// Build Options:
/// - enable_net: Enable network functionality (default: true)
/// - enable_fs: Enable file system access (default: true)
/// - sandbox: Restrict to REPL-only mode (default: false)
/// - print_code: Debug option to print opcodes (default: false)
/// - trace_exec: Debug option to trace execution (default: false)
/// - stress_gc: Debug option to stress test garbage collector (default: false)
/// - log_gc: Debug option to log GC allocations (default: false)
///
/// Build Steps:
/// - zig build: Build both library and executable
/// - zig build test: Run library tests
/// - zig build run: Run the executable
/// - zig build example: Build the library usage example
/// - zig build run-example: Build and run the library usage example
/// - zig build docs: Generate documentation
const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

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

    // Add command-line argument parsing dependency
    const clap = b.dependency("clap", .{});

    // Library artifact - can be imported by other Zig projects
    const lib = b.addLibrary(.{
        .name = "mufiz",
        .root_module = b.createModule(.{ .root_source_file = b.path("src/lib.zig"), .target = target, .optimize = optimize }),
    });
    lib.root_module.addOptions("features", options);
    lib.root_module.addOptions("debug", debug_options);
    lib.root_module.addImport("clap", clap.module("clap"));
    b.installArtifact(lib);

    // Main executable artifact
    const exe = b.addExecutable(.{
        .name = "mufiz",
        .root_module = b.createModule(.{ .root_source_file = b.path("src/main.zig"), .target = target, .optimize = optimize }),
    });
    exe.root_module.addOptions("features", options);
    exe.root_module.addOptions("debug", debug_options);
    exe.root_module.addImport("clap", clap.module("clap"));

    // Check-only executable (for 'zig build check')
    const exe_check = b.addExecutable(.{
        .name = "mufiz",
        .root_module = b.createModule(.{ .root_source_file = b.path("src/main.zig"), .target = target, .optimize = optimize }),
    });
    exe_check.root_module.addOptions("features", options);
    exe_check.root_module.addOptions("debug", debug_options);
    exe_check.root_module.addImport("clap", clap.module("clap"));

    // Enable WASM runtime if targeting WASM32
    if (target.query.cpu_arch == .wasm32) {
        b.enable_wasmtime = true;
    }

    b.installArtifact(exe);

    // Documentation generation step
    const install_docs = b.addInstallDirectory(.{
        .source_dir = lib.getEmittedDocs(),
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

    // Test step for running library tests
    const lib_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/lib.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    lib_tests.root_module.addOptions("features", options);
    lib_tests.root_module.addOptions("debug", debug_options);
    lib_tests.root_module.addImport("clap", clap.module("clap"));

    const run_lib_tests = b.addRunArtifact(lib_tests);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_lib_tests.step);

    // Example: Library usage example
    const example_lib_usage = b.addExecutable(.{
        .name = "library_usage",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/library_usage.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    example_lib_usage.root_module.addOptions("features", options);
    example_lib_usage.root_module.addOptions("debug", debug_options);
    example_lib_usage.root_module.addImport("clap", clap.module("clap"));

    const install_example = b.addInstallArtifact(example_lib_usage, .{});
    const example_step = b.step("example", "Build library usage example");
    example_step.dependOn(&install_example.step);

    const run_example = b.addRunArtifact(example_lib_usage);
    const run_example_step = b.step("run-example", "Run library usage example");
    run_example_step.dependOn(&run_example.step);
}
