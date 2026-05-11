/// MufiZ Interpreter Entry Point
/// This is the main entry point for the MufiZ language interpreter.
/// It provides the command-line interface to the MufiZ library.
const std = @import("std");
const builtin = @import("builtin");

const cli_parser = @import("cli_parser.zig");
const features = @import("features");

const mufiz = @import("lib.zig");
const pm = @import("pm.zig");
const system = @import("system.zig");

// Interpreter exit codes (re-exported from library)
pub const OK: u8 = mufiz.OK;
pub const COMPILE_ERROR: u8 = mufiz.COMPILE_ERROR;
pub const RUNTIME_ERROR: u8 = mufiz.RUNTIME_ERROR;

/// Returns the global allocator used throughout the interpreter
/// This provides a centralized memory management interface
pub fn getGlobalAllocator() std.mem.Allocator {
    return mufiz.getAllocator() catch unreachable; // Safe because init() is always called first
}

/// Main entry point for the MufiZ interpreter
/// Initializes all subsystems and handles command-line arguments
pub fn main(init: std.process.Init) !void {
    const gpa_allocator = init.gpa;
    mufiz.system.global_io = init.io;

    // Convert Args to slice of strings for compatibility with existing code
    var args_list = try std.ArrayList([]const u8).initCapacity(gpa_allocator, 16);
    defer {
        for (args_list.items) |arg| gpa_allocator.free(arg);
        args_list.deinit(gpa_allocator);
    }

    var args_iter = std.process.Args.Iterator.init(init.minimal.args);
    while (args_iter.next()) |arg| {
        try args_list.append(gpa_allocator, try gpa_allocator.dupe(u8, arg));
    }

    // Initialize the MufiZ library with leak detection and safety checks
    try mufiz.init(.{
        .enable_leak_detection = true,
        .enable_tracking = true,
        .enable_safety = true,
    });
    defer mufiz.deinit();

    // Check if running in sandbox mode (REPL-only)
    if (features.sandbox) {
        try mufiz.startRepl();
    } else {
        // Parse command-line arguments
        var args = try cli_parser.parseArgs(gpa_allocator, args_list.items);
        defer args.deinit();

        if (args.full_stdlib) {
            // Compatibility helper: initialize and register all stdlib modules on demand.
            // By default the library init registers a core-only stdlib (for faster startup
            // and lazy-loading). This flag restores legacy behavior for test runs and
            // consumers that expect all stdlib modules to be present immediately.
            try mufiz.stdlib.initializeStdlib();
            mufiz.stdlib.registerWithVM();
        }

        // Handle command-line arguments
        if (args.help) {
            cli_parser.printHelp();
            return;
        } else if (args.version) {
            mufiz.printVersion();
        } else if (args.run) |s| {
            var runner = mufiz.system.Runner.init(gpa_allocator);
            defer runner.deinit();
            try runner.setMain(@constCast(s));
            if (args.link) |l| {
                try runner.setLink(@constCast(l));
            }
            try runner.runFile();
        } else if (args.fmt) |s| {
            try mufiz.system.format(s);
        } else if (args.test_gen) {
            try mufiz.system.generateTests();
        } else if (args.analyze_bytecode) |s| {
            try analyzeBytecode(s);
        } else if (args.trace_sequences) |s| {
            try traceSequences(s);
        } else if (args.repl) {
            try mufiz.startRepl();
        } else if (args.docs) {
            mufiz.stdlib.printDocs();
        } else {
            mufiz.printVersion();
            mufiz.printUsage();
            std.debug.print("Use --help for usage information\n", .{});
            return;
        }
    }
}

/// Trace instruction sequences in a script for optimization analysis
fn traceSequences(path: []const u8) !void {
    const vm_trace = @import("vm_trace.zig");
    const allocator = getGlobalAllocator();

    // Read the file
    const file = try std.Io.Dir.cwd().openFile(mufiz.system.global_io, path, .{});
    defer file.close(mufiz.system.global_io);

    var buf: [4096]u8 = undefined;
    var reader = file.reader(mufiz.system.global_io, &buf);
    const source = try reader.interface.readAlloc(allocator, 10 * 1024 * 1024); // Max 10MB
    defer allocator.free(source);

    // Initialize tracing
    try vm_trace.init(allocator);
    defer vm_trace.deinit();

    // Enable tracing
    vm_trace.enable();

    std.debug.print("\n🔍 Tracing instruction sequences: {s}\n", .{path});
    std.debug.print("Running script with instrumentation enabled...\n\n", .{});

    // Run the script (this will populate trace data)
    const result = mufiz.interpret(source);

    // Disable tracing
    vm_trace.disable();

    // Print results
    if (result == OK) {
        std.debug.print("\n✅ Script completed successfully\n", .{});
        vm_trace.printReport();

        // Optionally export to file
        const trace_file = "vm_trace.csv";
        vm_trace.exportToFile(trace_file) catch |err| {
            std.debug.print("Warning: Could not export trace to file: {}\n", .{err});
        };
        std.debug.print("📁 Trace data exported to: {s}\n", .{trace_file});
    } else {
        std.debug.print("\n❌ Script failed with error code: {d}\n", .{result});
        std.debug.print("Trace data collected before error:\n", .{});
        vm_trace.printReport();
    }
}

/// Analyze bytecode from a script file
fn analyzeBytecode(path: []const u8) !void {
    const bytecode_analyzer = @import("bytecode_analyzer.zig");
    const compiler_h = @import("compiler.zig");
    const allocator = getGlobalAllocator();

    // Read the file
    const file = try std.Io.Dir.cwd().openFile(mufiz.system.global_io, path, .{});
    defer file.close(mufiz.system.global_io);

    var buf: [4096]u8 = undefined;
    var reader = file.reader(mufiz.system.global_io, &buf);
    const source = try reader.interface.readAlloc(allocator, 10 * 1024 * 1024); // Max 10MB
    defer allocator.free(source);

    std.debug.print("\n📊 Analyzing bytecode for: {s}\n", .{path});
    std.debug.print("Source size: {d} bytes\n", .{source.len});

    // Compile the source (compiler expects null-terminated string)
    const function = compiler_h.compile(source.ptr, path);
    if (function == null) {
        std.debug.print("❌ Compilation failed. Cannot analyze bytecode.\n", .{});
        return;
    }

    // Analyze the compiled bytecode
    try bytecode_analyzer.analyzeAndReport(&function.?.chunk, allocator);
}

/// Handle package manager commands
fn handlePmCommand(args: [][:0]u8) !void {
    if (args.len < 3) {
        pm.printHelp();
        return;
    }

    const subcommand = args[2];
    const allocator = std.heap.page_allocator;

    if (std.mem.eql(u8, subcommand, "new")) {
        if (args.len < 4) {
            std.debug.print("Error: 'pm new' requires a project name\n", .{});
            std.debug.print("Usage: mufiz pm new <project_name>\n", .{});
            return;
        }
        const project_name = args[3];
        try pm.newProject(allocator, project_name);
    } else if (std.mem.eql(u8, subcommand, "init")) {
        if (args.len < 4) {
            std.debug.print("Error: 'pm init' requires a project name\n", .{});
            std.debug.print("Usage: mufiz pm init <project_name>\n", .{});
            return;
        }
        const project_name = args[3];
        try pm.initProject(allocator, project_name);
    } else if (std.mem.eql(u8, subcommand, "info")) {
        try pm.info(allocator);
    } else if (std.mem.eql(u8, subcommand, "run")) {
        try pm.run(allocator);
    } else if (std.mem.eql(u8, subcommand, "install")) {
        try pm.install(allocator);
    } else if (std.mem.eql(u8, subcommand, "update")) {
        try pm.update(allocator);
    } else if (std.mem.eql(u8, subcommand, "add")) {
        if (args.len < 7) {
            std.debug.print("Error: 'pm add' requires name, src, type, and version\n", .{});
            std.debug.print("Usage: mufiz pm add <name> <src> <type> <version>\n", .{});
            return;
        }
        const name = args[3];
        const src = args[4];
        const dep_type = args[5];
        const version = args[6];
        try pm.addDependency(allocator, name, src, dep_type, version);
    } else if (std.mem.eql(u8, subcommand, "cache")) {
        if (args.len < 4) {
            std.debug.print("Error: 'pm cache' requires a subcommand (info|clear)\n", .{});
            return;
        }
        const cache_cmd = args[3];
        if (std.mem.eql(u8, cache_cmd, "info")) {
            try pm.cacheInfo(allocator);
        } else if (std.mem.eql(u8, cache_cmd, "clear")) {
            try pm.cacheClear(allocator);
        } else {
            std.debug.print("Error: Unknown cache command: {s}\n", .{cache_cmd});
            std.debug.print("Available: info, clear\n", .{});
        }
    } else if (std.mem.eql(u8, subcommand, "docs")) {
        try pm.docs(allocator);
    } else if (std.mem.eql(u8, subcommand, "help")) {
        pm.printHelp();
    } else {
        std.debug.print("Error: Unknown pm command: {s}\n", .{subcommand});
        pm.printHelp();
    }
}
