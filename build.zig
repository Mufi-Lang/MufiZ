const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Feature flags
    const features = createFeatureOptions(b);
    const debug = createDebugOptions(b);

    // Main library (Zig consumers)
    const lib = createStaticLibrary(b, "mufiz", "src/lib.zig", target, optimize);
    configureModule(lib.root_module, features, debug);
    b.installArtifact(lib);

    // Shared library (C ABI)
    const shlib = createSharedLibrary(b, "mufiz", "src/c_api.zig", target, optimize);
    configureModule(shlib.root_module, features, debug);
    b.installArtifact(shlib);

    // // Generate C header file
    // const gen_header = b.addExecutable(.{
    //     .name = "gen_header",
    //     .root_module = b.createModule(.{
    //         .root_source_file = b.path("scripts/gen_header.zig"),
    //         .target = target,
    //         .optimize = optimize,
    //     }),
    // });

    // const run_gen_header = b.addRunArtifact(gen_header);
    // run_gen_header.addArg("zig-out/include/mufiz.h");

    // const header_step = b.step("header", "Generate C header file");
    // header_step.dependOn(&run_gen_header.step);

    // Validate header matches c_api.zig
    // const validate_header = b.addExecutable(.{
    //     .name = "validate_header",
    //     .root_module = b.createModule(.{
    //         .root_source_file = b.path("scripts/validate_header.zig"),
    //         .target = target,
    //         .optimize = optimize,
    //     }),
    // });

    // const run_validate = b.addRunArtifact(validate_header);
    // run_validate.step.dependOn(&run_gen_header.step);

    // const validate_step = b.step("validate-header", "Validate C header matches c_api.zig");
    // validate_step.dependOn(&run_validate.step);

    // // Ensure header is generated when building shared library
    // b.getInstallStep().dependOn(&run_gen_header.step);

    // // WASM build support
    // const wasm_exe = createWasmExecutable(b, "mufiz", "src/c_api.zig");
    // configureModule(wasm_exe.root_module, features, debug);

    // const install_wasm = b.addInstallArtifact(wasm_exe, .{
    //     .dest_dir = .{ .override = .{ .custom = "wasm" } },
    // });
    // const wasm_step = b.step("wasm", "Build WebAssembly library");
    // wasm_step.dependOn(&install_wasm.step);

    // Executable (native)
    const exe = createExecutable(b, "mufiz", "src/main.zig", target, optimize);
    configureModule(exe.root_module, features, debug);
    b.installArtifact(exe);

    // Check-only exe for 'zig build check'
    const exe_check = createExecutable(b, "mufiz", "src/main.zig", target, optimize);
    configureModule(exe_check.root_module, features, debug);

    if (target.query.cpu_arch == .wasm32) {
        b.enable_wasmtime = true;
    }

    // Check step
    const check = b.step("check", "Check if MufiZ compiles");
    check.dependOn(&exe_check.step);

    // Run step
    setupRunStep(b, exe);

    // Tests
    setupTests(b, target, optimize, features, debug);
}

fn createFeatureOptions(b: *std.Build) *std.Build.Step.Options {
    const options = b.addOptions();
    options.addOption(bool, "enable_net", b.option(bool, "enable_net", "Enable Network features") orelse true);
    options.addOption(bool, "enable_fs", b.option(bool, "enable_fs", "Enable File System features") orelse true);
    options.addOption(bool, "sandbox", b.option(bool, "sandbox", "Enable Sandbox Mode (REPL only)") orelse false);
    return options;
}

fn createDebugOptions(b: *std.Build) *std.Build.Step.Options {
    const options = b.addOptions();
    options.addOption(bool, "print_code", b.option(bool, "print_code", "Enables printing the OpCodes for Debugging") orelse false);
    options.addOption(bool, "trace_exec", b.option(bool, "trace_exec", "Enables Tracing for Debugging") orelse false);
    options.addOption(bool, "stress_gc", b.option(bool, "stress_gc", "Enables GC Stressing") orelse false);
    options.addOption(bool, "log_gc", b.option(bool, "log_gc", "Enables Logging the GC allocations") orelse false);
    return options;
}

fn configureModule(
    module: *std.Build.Module,
    features: *std.Build.Step.Options,
    debug: *std.Build.Step.Options,
) void {
    module.addOptions("features", features);
    module.addOptions("debug", debug);
}

fn createStaticLibrary(
    b: *std.Build,
    name: []const u8,
    root_source: []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    return b.addLibrary(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(root_source),
            .target = target,
            .optimize = optimize,
        }),
    });
}

fn createSharedLibrary(
    b: *std.Build,
    name: []const u8,
    root_source: []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    return b.addLibrary(.{
        .name = name,
        .linkage = .dynamic,
        .root_module = b.createModule(.{
            .root_source_file = b.path(root_source),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
}

fn createExecutable(
    b: *std.Build,
    name: []const u8,
    root_source: []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    return b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(root_source),
            .target = target,
            .optimize = optimize,
        }),
    });
}

fn createWasmExecutable(
    b: *std.Build,
    name: []const u8,
    root_source: []const u8,
) *std.Build.Step.Compile {
    const wasm_exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(root_source),
            .target = b.resolveTargetQuery(.{
                .cpu_arch = .wasm32,
                .os_tag = .wasi,
            }),
            .optimize = .ReleaseSmall,
        }),
    });
    wasm_exe.rdynamic = true;
    wasm_exe.entry = .disabled;
    return wasm_exe;
}

fn setupRunStep(b: *std.Build, exe: *std.Build.Step.Compile) void {
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}

fn setupTests(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    features: *std.Build.Step.Options,
    debug: *std.Build.Step.Options,
) void {
    const lib_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/lib.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    configureModule(lib_tests.root_module, features, debug);

    const run_lib_tests = b.addRunArtifact(lib_tests);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_lib_tests.step);
}

// fn setupBenchmarks(
//     b: *std.Build,
//     target: std.Build.ResolvedTarget,
//     features: *std.Build.Step.Options,
//     debug: *std.Build.Step.Options,
// ) void {
//     const scanner_bench = b.addExecutable(.{
//         .name = "scanner_bench",
//         .root_module = b.createModule(.{
//             .root_source_file = b.path("benchmark/scanner_bench.zig"),
//             .target = target,
//             .optimize = .ReleaseFast,
//         }),
//     });
//     configureModule(scanner_bench.root_module, features, debug);

//     // Add scanner module as import
//     scanner_bench.root_module.addAnonymousImport("scanner", .{
//         .root_source_file = b.path("src/scanner_optimized.zig"),
//     });

//     const run_scanner_bench = b.addRunArtifact(scanner_bench);
//     const bench_step = b.step("bench-scanner", "Run scanner benchmarks");
//     bench_step.dependOn(&run_scanner_bench.step);

//     // Parallel scanner benchmark
//     const parallel_scanner_bench = b.addExecutable(.{
//         .name = "parallel_scanner_bench",
//         .root_module = b.createModule(.{
//             .root_source_file = b.path("benchmark/parallel_scanner_bench.zig"),
//             .target = target,
//             .optimize = .ReleaseFast,
//         }),
//     });
//     configureModule(parallel_scanner_bench.root_module, features, debug);

//     // Create scanner module
//     const scanner_module = b.createModule(.{
//         .root_source_file = b.path("src/scanner_optimized.zig"),
//     });

//     // Add scanner module as import
//     parallel_scanner_bench.root_module.addImport("scanner", scanner_module);

//     // Create parallel scanner module with scanner dependency
//     const parallel_scanner_module = b.createModule(.{
//         .root_source_file = b.path("src/parallel/scanner_parallel.zig"),
//     });
//     parallel_scanner_module.addImport("../scanner_optimized.zig", scanner_module);

//     // Add parallel scanner module as import
//     parallel_scanner_bench.root_module.addImport("parallel_scanner", parallel_scanner_module);

//     const run_parallel_scanner_bench = b.addRunArtifact(parallel_scanner_bench);
//     const parallel_bench_step = b.step("bench-parallel", "Run parallel scanner benchmarks");
//     parallel_bench_step.dependOn(&run_parallel_scanner_bench.step);
// }
