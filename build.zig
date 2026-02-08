const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Feature flags
    const options = b.addOptions();
    const net = b.option(bool, "enable_net", "Enable Network features") orelse true;
    const fs = b.option(bool, "enable_fs", "Enable File System features") orelse true;
    const sandbox = b.option(bool, "sandbox", "Enable Sandbox Mode (REPL only)") orelse false;
    options.addOption(bool, "enable_net", net);
    options.addOption(bool, "enable_fs", fs);
    options.addOption(bool, "sandbox", sandbox);

    // Debug options
    const debug_options = b.addOptions();
    const debug_print_code = b.option(bool, "print_code", "Enables printing the OpCodes for Debugging") orelse false;
    const debug_trace_execution = b.option(bool, "trace_exec", "Enables Tracing for Debugging") orelse false;
    const debug_stress_gc = b.option(bool, "stress_gc", "Enables GC Stressing") orelse false;
    const debug_log_gc = b.option(bool, "log_gc", "Enables Logging the GC allocations") orelse false;

    debug_options.addOption(bool, "print_code", debug_print_code);
    debug_options.addOption(bool, "trace_exec", debug_trace_execution);
    debug_options.addOption(bool, "stress_gc", debug_stress_gc);
    debug_options.addOption(bool, "log_gc", debug_log_gc);

    // Dependencies
    const clap = b.dependency("clap", .{});

    // Main library (Zig consumers)
    const lib = b.addLibrary(.{
        .name = "mufiz",
        .root_module = b.createModule(.{ .root_source_file = b.path("src/lib.zig"), .target = target, .optimize = optimize }),
    });
    lib.root_module.addOptions("features", options);
    lib.root_module.addOptions("debug", debug_options);
    lib.root_module.addImport("clap", clap.module("clap"));
    b.installArtifact(lib);

    // Shared library (C ABI) - root module is `src/c_api.zig`
    const shlib = b.addLibrary(.{
        .name = "mufiz",
        .linkage = .dynamic,
        .root_module = b.createModule(.{ .root_source_file = b.path("src/c_api.zig"), .target = target, .optimize = optimize, .link_libc = true }),
    });
    shlib.root_module.addOptions("features", options);
    shlib.root_module.addOptions("debug", debug_options);
    shlib.root_module.addImport("clap", clap.module("clap"));
    b.installArtifact(shlib);

    // WASM build support
    const wasm_lib = b.addExecutable(.{
        .name = "mufiz_wasm",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/c_api.zig"),
            .target = b.resolveTargetQuery(.{
                .cpu_arch = .wasm32,
                .os_tag = .wasi,
            }),
            .optimize = .ReleaseSmall,
            .link_libc = true,
        }),
    });
    wasm_lib.root_module.addOptions("features", options);
    wasm_lib.root_module.addOptions("debug", debug_options);
    wasm_lib.root_module.addImport("clap", clap.module("clap"));
    wasm_lib.entry = .disabled;
    wasm_lib.rdynamic = true;
    wasm_lib.root_module.export_symbol_names = &[_][]const u8{ "mufiz_init", "mufiz_deinit", "mufiz_interpret" };

    const install_wasm = b.addInstallArtifact(wasm_lib, .{
        .dest_dir = .{ .override = .{ .custom = "wasm" } },
    });
    const wasm_step = b.step("wasm", "Build WebAssembly library");
    wasm_step.dependOn(&install_wasm.step);

    // WASM Demo HTML
    const wasm_demo_html = b.addWriteFiles();
    _ = wasm_demo_html.add("index.html",
        \\<!DOCTYPE html>
        \\<html>
        \\<head>
        \\    <title>MufiZ WASM Demo</title>
        \\    <style>
        \\        body { font-family: monospace; background: #1e1e1e; color: #d4d4d4; padding: 20px; }
        \\        #output { white-space: pre-wrap; border: 1px solid #333; padding: 10px; min-height: 200px; }
        \\    </style>
        \\</head>
        \\<body>
        \\    <h1>MufiZ WebAssembly Demo</h1>
        \\    <div style="margin-bottom: 10px;">
        \\        <textarea id="input" rows="10" style="width: 100%; background: #2d2d2d; color: #fff; border: 1px solid #444; padding: 10px;">print("Hello from MufiZ WASM!");</textarea>
        \\    </div>
        \\        \\    <button id="runBtn" disabled style="padding: 10px 20px; cursor: pointer;">Run Mufi-Lang</button>
        \\    <div id="status" style="margin-top: 10px; color: #888;">Loading MufiZ...</div>
        \\    <div id="output" style="margin-top: 20px; border-top: 1px solid #333; padding-top: 10px;"></div>
        \\
        \\    <script>
        \\        let wasmExports = null;
        \\
        \\        async function init() {
        \\            const status = document.getElementById('status');
        \\            const output = document.getElementById('output');
        \\            const runBtn = document.getElementById('runBtn');
        \\            const input = document.getElementById('input');
        \\
        \\            try {
        \\                status.innerText = 'Fetching mufiz_wasm.wasm...';
        \\                const response = await fetch('mufiz_wasm.wasm');
        \\                if (!response.ok) throw new Error(`HTTP error! status: ${response.status}`);
        \\                
        \\                const bytes = await response.arrayBuffer();
        \\                const results = await WebAssembly.instantiate(bytes, {
        \\                    wasi_snapshot_preview1: {
        \\                        fd_write: (fd, iovs, iovs_len, nwritten) => {
        \\                            // Very simple implementation to capture stdout
        \\                            const view = new DataView(wasmExports.memory.buffer);
        \\                            let total = 0;
        \\                            for (let i = 0; i < iovs_len; i++) {
        \\                                const ptr = view.getUint32(iovs + i * 8, true);
        \\                                const len = view.getUint32(iovs + i * 8 + 4, true);
        \\                                const buf = new Uint8Array(wasmExports.memory.buffer, ptr, len);
        \\                                const text = new TextDecoder().decode(buf);
        \\                                output.innerText += text;
        \\                                total += len;
        \\                            }
        \\                            view.setUint32(nwritten, total, true);
        \\                            return 0;
        \\                        },
        \\                        proc_exit: (code) => { console.log('Exit:', code); },
        \\                        environ_get: () => 0,
        \\                        environ_sizes_get: (n, buf_size) => {
        \\                            const view = new DataView(wasmExports.memory.buffer);
        \\                            view.setUint32(n, 0, true);
        \\                            view.setUint32(buf_size, 0, true);
        \\                            return 0;
        \\                        },
        \\                        fd_close: () => 0,
        \\                        fd_seek: () => 0,
        \\                        fd_fdstat_get: (fd, stat) => 0,
        \\                    }
        \\                });
        \\                wasmExports = results.instance.exports;
        \\
        \\                status.innerText = 'MufiZ WASM Instantiated! Initializing...';
        \\                
        \\                // call mufiz_init(leak_detection, tracking, safety)
        \\                wasmExports.mufiz_init(false, false, false);
        \\
        \\                status.innerText = 'Ready to interpret Mufi-Lang.';
        \\                runBtn.disabled = false;
        \\
        \\                runBtn.onclick = () => {
        \\                    const code = input.value;
        \\                    const encoder = new TextEncoder();
        \\                    const codeBytes = encoder.encode(code + '\0');
        \\                    
        \\                    // Use a simple buffer for now or implement wasm_alloc in c_api.zig
        \\                    // Since we are using WASI and full c_api, we can't use our stub's wasm_alloc.
        \\                    // For this demo, let's just use a fixed large buffer offset if we can find one,
        \\                    // or just use the stack if it's large enough.
        \\                    // Better: use the memory after __heap_base
        \\                    const ptr = wasmExports.__heap_base || 1024 * 64; 
        \\
        \\                    const mem = new Uint8Array(wasmExports.memory.buffer);
        \\                    mem.set(codeBytes, ptr);
        \\
        \\                    output.innerText += `\n> ${code}\n`;
        \\                    const result = wasmExports.mufiz_interpret(ptr);
        \\                    output.innerText += `[Exit Code]: ${result}\n`;
        \\                };
        \\
        \\            } catch (err) {
        \\                status.innerText = 'Error: ' + err.message;
        \\                console.error(err);
        \\            }
        \\        }
        \\</body>
        \\</html>
    );

    const install_demo = b.addInstallDirectory(.{
        .source_dir = wasm_demo_html.getDirectory(),
        .install_dir = .{ .custom = "wasm" },
        .install_subdir = ".",
    });
    wasm_step.dependOn(&install_demo.step);

    // Executable (native)
    const exe = b.addExecutable(.{
        .name = "mufiz",
        .root_module = b.createModule(.{ .root_source_file = b.path("src/main.zig"), .target = target, .optimize = optimize }),
    });
    exe.root_module.addOptions("features", options);
    exe.root_module.addOptions("debug", debug_options);
    exe.root_module.addImport("clap", clap.module("clap"));
    b.installArtifact(exe);

    // Install headers
    const install_headers = b.addInstallDirectory(.{
        .source_dir = b.path("include"),
        .install_dir = .prefix,
        .install_subdir = "include",
    });
    b.getInstallStep().dependOn(&install_headers.step);

    // check-only exe for 'zig build check'
    const exe_check = b.addExecutable(.{
        .name = "mufiz",
        .root_module = b.createModule(.{ .root_source_file = b.path("src/main.zig"), .target = target, .optimize = optimize }),
    });
    exe_check.root_module.addOptions("features", options);
    exe_check.root_module.addOptions("debug", debug_options);
    exe_check.root_module.addImport("clap", clap.module("clap"));

    if (target.query.cpu_arch == .wasm32) {
        b.enable_wasmtime = true;
    }

    // docs install step (keeps behavior from before)
    const install_docs = b.addInstallDirectory(.{
        .source_dir = lib.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });

    const docs_step = b.step("docs", "Copy documentation artifacts to prefix path");
    docs_step.dependOn(&install_docs.step);
    docs_step.dependOn(&install_headers.step);

    const check = b.step("check", "Check if MufiZ compiles");
    check.dependOn(&exe_check.step);

    // Run / Run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Tests
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

    // Example: Library usage
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
