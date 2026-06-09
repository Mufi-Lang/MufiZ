const std = @import("std");
const mem = std.mem;

pub const Args = struct {
    help: bool = false,
    version: bool = false,
    run: ?[]const u8 = null,
    link: ?[]const u8 = null,
    repl: bool = false,
    docs: bool = false,
    fmt: ?[]const u8 = null,
    test_gen: bool = false,
    analyze_bytecode: ?[]const u8 = null,
    trace_sequences: ?[]const u8 = null,
    full_stdlib: bool = false,
    positional: std.ArrayList([]const u8),
    allocator: std.mem.Allocator,

    pub fn deinit(self: *Args) void {
        self.positional.deinit(self.allocator);
    }
};

pub fn parseArgs(allocator: std.mem.Allocator, argv: []const []const u8) !Args {
    var args = Args{
        .positional = try std.ArrayList([]const u8).initCapacity(allocator, argv.len),
        .allocator = allocator,
    };

    var i: usize = 1; // Skip program name
    while (i < argv.len) : (i += 1) {
        const arg = argv[i];

        if (mem.eql(u8, arg, "-h") or mem.eql(u8, arg, "--help")) {
            args.help = true;
        } else if (mem.eql(u8, arg, "-v") or mem.eql(u8, arg, "--version")) {
            args.version = true;
        } else if (mem.eql(u8, arg, "-r") or mem.eql(u8, arg, "--run")) {
            if (i + 1 < argv.len) {
                i += 1;
                args.run = argv[i];
            }
        } else if (mem.eql(u8, arg, "-l") or mem.eql(u8, arg, "--link")) {
            if (i + 1 < argv.len) {
                i += 1;
                args.link = argv[i];
            }
        } else if (mem.eql(u8, arg, "--repl")) {
            args.repl = true;
        } else if (mem.eql(u8, arg, "--docs")) {
            args.docs = true;
        } else if (mem.eql(u8, arg, "--fmt")) {
            if (i + 1 < argv.len) {
                i += 1;
                args.fmt = argv[i];
            }
        } else if (mem.eql(u8, arg, "--test-gen")) {
            args.test_gen = true;
        } else if (mem.eql(u8, arg, "--analyze-bytecode")) {
            if (i + 1 < argv.len) {
                i += 1;
                args.analyze_bytecode = argv[i];
            }
        } else if (mem.eql(u8, arg, "--trace-sequences")) {
            if (i + 1 < argv.len) {
                i += 1;
                args.trace_sequences = argv[i];
            }
        } else if (mem.eql(u8, arg, "--full-stdlib")) {
            args.full_stdlib = true;
        } else if (mem.startsWith(u8, arg, "-")) {
            std.debug.print("Unknown option: {s}\n", .{arg});
        } else {
            try args.positional.append(allocator, arg);
        }
    }

    return args;
}

pub fn printHelp() void {
    const help_text =
        \\Mufi Interpreter
        \\
        \\USAGE:
        \\    mufiz [OPTIONS] [FILE]
        \\
        \\OPTIONS:
        \\    -h, --help                   Displays this help and exit.
        \\    -v, --version                Prints the version and codename.
        \\    -r, --run <str>              Runs a Mufi Script
        \\    -l, --link <str>             Link another Mufi Script when interpreting
        \\    --repl                       Runs Mufi Repl system
        \\    --docs                       Standard Library Documentation
        \\    --fmt <str>                  Formats a Mufi Script
        \\    --test-gen                   Generates synthetic Mufi tests
        \\    --analyze-bytecode <str>     Analyze bytecode and show optimization opportunities
        \\    --trace-sequences <str>      Trace instruction sequences for optimization analysis
        \\    --full-stdlib                Initialize all standard library modules (compat mode)
    ;
    std.debug.print("{s}\n", .{help_text});
}
