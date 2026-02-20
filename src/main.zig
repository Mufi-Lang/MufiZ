/// MufiZ Interpreter Entry Point
/// This is the main entry point for the MufiZ language interpreter.
/// It provides the command-line interface to the MufiZ library.
const std = @import("std");
const builtin = @import("builtin");

const clap = @import("clap");
const features = @import("features");

const mufiz = @import("lib.zig");
const pm = @import("pm.zig");

// Interpreter exit codes (re-exported from library)
pub const OK: u8 = mufiz.OK;
pub const COMPILE_ERROR: u8 = mufiz.COMPILE_ERROR;
pub const RUNTIME_ERROR: u8 = mufiz.RUNTIME_ERROR;

/// Returns the global allocator used throughout the interpreter
/// This provides a centralized memory management interface
pub fn getGlobalAllocator() std.mem.Allocator {
    return mufiz.getAllocator() catch unreachable; // Safe because init() is always called first
}

// Command-line parameter definitions
const params = clap.parseParamsComptime(
    \\-h, --help             Displays this help and exit.
    \\-v, --version          Prints the version and codename.
    \\-r, --run <str>        Runs a Mufi Script
    \\-l, --link <str>       Link another Mufi Script when interpreting
    \\--repl                 Runs Mufi Repl system
    \\--docs                 Standard Library Documentation
    \\--fmt <str>            Formats a Mufi Script
    \\--test-gen             Generates synthetic Mufi tests
    \\--analyze-bytecode <str>  Analyze bytecode and show optimization opportunities
    \\--trace-sequences <str>    Trace instruction sequences for optimization analysis
);

/// Main entry point for the MufiZ interpreter
/// Initializes all subsystems and handles command-line arguments
pub fn main() !void {
    // Get arguments
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const gpa_allocator = gpa.allocator();

    const args = try std.process.argsAlloc(gpa_allocator);
    defer std.process.argsFree(gpa_allocator, args);

    // Check for 'pm' command first (before mufiz init)
    if (args.len >= 2 and std.mem.eql(u8, args[1], "pm")) {
        try handlePmCommand(args);
        return;
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
        var diag = clap.Diagnostic{};
        var res = clap.parse(clap.Help, &params, clap.parsers.default, .{
            .allocator = getGlobalAllocator(),
            .diagnostic = &diag,
        }) catch |err| {
            std.debug.print("Error: {any}\n", .{err});
            return err;
        };
        defer res.deinit();

        // Handle command-line arguments
        if (res.args.help != 0) {
            std.debug.print(
                \\MufiZ v{d}.{d}.{d}
                \\-h, --help             Displays this help and exit.
                \\-v, --version          Prints the version and codename.
                \\-r, --run <str>        Runs a Mufi Script
                \\-l, --link <str>       Link another Mufi Script when interpreting
                \\--repl                 Runs Mufi Repl system
                \\--docs                 Standard Library Documentation
                \\--fmt <str>            Formats a Mufi Script
                \\--test-gen             Generates synthetic Mufi tests
                \\--analyze-bytecode <str>  Analyze bytecode and show optimization opportunities
                \\--trace-sequences <str>    Trace instruction sequences for optimization analysis
                \\
                \\PACKAGE MANAGER:
                \\pm <command>           Package manager commands
                \\  new <name>           Create a new MufiZ project
                \\  init <name>          Initialize a MufiZ project in current directory
                \\  info                 Display project information
                \\  run                  Run the current project
                \\  install              Install project dependencies
                \\  add <name> <url> <v> Add a dependency to project
                \\  cache info           View package cache statistics
                \\  cache clear          Clear package cache
                \\  help                 Show package manager help
                \\
            , .{ mufiz.system.MAJOR, mufiz.system.MINOR, mufiz.system.PATCH });
            return;
        } else if (res.args.version != 0) {
            mufiz.printVersion();
        } else if (res.args.run) |s| {
            var runner = mufiz.Runner.init(getGlobalAllocator());
            defer runner.deinit();
            try runner.setMain(@constCast(s));
            if (res.args.link) |l| {
                try runner.setLink(@constCast(l));
            }
            try runner.runFile();
        } else if (res.args.fmt) |s| {
            try mufiz.system.format(s);
        } else if (res.args.@"test-gen" != 0) {
            try mufiz.system.generateTests();
        } else if (res.args.@"analyze-bytecode") |s| {
            try analyzeBytecode(s);
        } else if (res.args.@"trace-sequences") |s| {
            try traceSequences(s);
        } else if (res.args.repl != 0) {
            try mufiz.startRepl();
        } else if (res.args.docs != 0) {
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
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const source = try file.readToEndAlloc(allocator, 10 * 1024 * 1024); // Max 10MB
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
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const source = try file.readToEndAlloc(allocator, 10 * 1024 * 1024); // Max 10MB
    defer allocator.free(source);

    std.debug.print("\n📊 Analyzing bytecode for: {s}\n", .{path});
    std.debug.print("Source size: {d} bytes\n", .{source.len});

    // Compile the source (compiler expects null-terminated string)
    const function = compiler_h.compile(source.ptr);
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
        // Initialize mufiz for running
        try mufiz.init(.{
            .enable_leak_detection = true,
            .enable_tracking = true,
            .enable_safety = true,
        });
        defer mufiz.deinit();
        try pm.run(allocator);
    } else if (std.mem.eql(u8, subcommand, "install")) {
        try pm.install(allocator);
    } else if (std.mem.eql(u8, subcommand, "add")) {
        if (args.len < 6) {
            std.debug.print("Error: 'pm add' requires name, url, and version\n", .{});
            std.debug.print("Usage: mufiz pm add <name> <url> <version>\n", .{});
            return;
        }
        const name = args[3];
        const url = args[4];
        const version = args[5];
        try pm.addDependency(allocator, name, url, version);
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
