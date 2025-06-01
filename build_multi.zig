const std = @import("std");
const builtin = @import("builtin");

const zig_version = "0.13.0";

comptime {
    const supported_version = std.SemanticVersion.parse(zig_version) catch unreachable;
    if (builtin.zig_version.order(supported_version) != .eq) {
        @compileError(std.fmt.comptimePrint("Unsupported Zig version ({}). Required Zig version 0.13.0.", .{builtin.zig_version}));
    }
}

// zig fmt: off

const targets: []const std.Target.Query = &.{
    .{ .cpu_arch = .aarch64, .os_tag = .linux, .abi = .gnu },
    .{ .cpu_arch = .aarch64, .os_tag = .linux, .abi = .musl },
    .{ .cpu_arch = .aarch64, .os_tag = .linux },
    .{ .cpu_arch = .arm, .os_tag = .linux, .abi = .gnueabihf },
    .{ .cpu_arch = .arm, .os_tag = .linux, .abi = .musleabihf },
    .{ .cpu_arch = .arm, .os_tag = .linux, .abi = .gnueabi },
    .{ .cpu_arch = .arm, .os_tag = .linux, .abi = .musleabi },
    .{ .cpu_arch = .aarch64, .os_tag = .macos },
    .{ .cpu_arch = .aarch64, .os_tag = .windows },
    .{ .cpu_arch = .aarch64, .os_tag = .windows, .abi = .gnu },
    .{ .cpu_arch = .mips64, .os_tag = .linux, .abi = .musl },
    .{ .cpu_arch = .mips64el, .os_tag = .linux, .abi = .musl },
    .{ .cpu_arch = .mipsel, .os_tag = .linux, .abi = .musl },
    .{ .cpu_arch = .mips, .os_tag = .linux, .abi = .musl },
    .{ .cpu_arch = .powerpc64, .os_tag = .linux, .abi = .gnu },
    .{ .cpu_arch = .powerpc64, .os_tag = .linux, .abi = .musl },
    .{ .cpu_arch = .powerpc64, .os_tag = .linux },
    .{ .cpu_arch = .powerpc, .os_tag = .linux, .abi = .musl },
    .{ .cpu_arch = .powerpc, .os_tag = .linux },
    .{ .cpu_arch = .powerpc64le, .os_tag = .linux, .abi = .gnu },
    .{ .cpu_arch = .powerpc64le, .os_tag = .linux, .abi = .musl },
    .{ .cpu_arch = .powerpc64le, .os_tag = .linux },
    .{ .cpu_arch = .riscv64, .os_tag = .linux, .abi = .musl },
    .{ .cpu_arch = .riscv64, .os_tag = .linux },
    .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .gnu },
    .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .musl },
    .{ .cpu_arch = .x86_64, .os_tag = .linux },
    .{.cpu_arch = .x86, .os_tag = .linux, .abi = .gnu},
    .{.cpu_arch = .x86, .os_tag = .linux, .abi = .musl},
    .{.cpu_arch = .x86, .os_tag = .linux},
    .{.cpu_arch = .x86, .os_tag = .windows, .abi = .gnu},
    .{ .cpu_arch = .x86_64, .os_tag = .macos },
    .{ .cpu_arch = .x86_64, .os_tag = .windows },
    .{ .cpu_arch = .x86_64, .os_tag = .windows, .abi = .gnu },
    .{ .cpu_arch = .sparc64, .os_tag = .linux },
    .{.cpu_arch = .loongarch64, .os_tag = .linux}
};

// zig fmt: on
pub fn build(b: *std.Build) !void {
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

    for (targets) |target| {
        try buildTarget(b, target, options, debug_options);
    }
}

fn buildTarget(b: *std.Build, target: std.Target.Query, options: *std.Build.Step.Options, debug_opts: *std.Build.Step.Options) !void {
    const exe = b.addExecutable(.{ .name = "mufiz", .root_module = b.createModule(.{ .root_source_file = b.path("src/main.zig"), .optimize = .ReleaseFast, .target = b.resolveTargetQuery(target) }) });

    if (target.cpu_arch == .wasm32) {
        b.enable_wasmtime = true;
    }

    const clap = b.dependency("clap", .{ .target = b.resolveTargetQuery(target), .optimize = .ReleaseSafe });

    exe.root_module.addImport("clap", clap.module("clap"));

    exe.root_module.addOptions("features", options);
    exe.root_module.addOptions("debug", debug_opts);

    const target_output = b.addInstallArtifact(exe, .{
        .dest_dir = .{
            .override = .{
                .custom = try target.zigTriple(b.allocator),
            },
        },
    });
    // zig fmt: on
    b.installArtifact(exe);
    b.getInstallStep().dependOn(&target_output.step);
}
