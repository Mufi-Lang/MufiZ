const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "MufiZ",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    exe.linkLibC();
    exe.addIncludePath(.{ .path = "include" });

    // zig fmt: off
    exe.addCSourceFiles(&.{ 
        "csrc/chunk.c", 
        "csrc/compiler.c", 
        "csrc/debug.c", 
        "csrc/memory.c", 
        "csrc/object.c", 
//        "csrc/pre.c", 
        "csrc/scanner.c", 
        "csrc/table.c", 
       "csrc/vm.c", 
        "csrc/value.c" 
        }, 
&.{ 
        "-Wall", 
       // "-Werror", 
        "-std=c11" 
    });
    const options = b.addOptions();
    const release = b.option(bool, "release", "Compiler in release mode") orelse false;
    options.addOption(bool, "release", release);
    exe.addOptions("config", options);


    // zig fmt: on
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
