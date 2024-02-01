const std = @import("std");
const builtin = @import("builtin");
pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const exe = b.addExecutable(.{
        .name = "mufiz",
        .root_source_file = .{ .path = "src/main.zig" },
        .version = .{ .major = 0, .minor = 3, .patch = 0 },
        .target = target,
        .optimize = .ReleaseSafe,
        .link_libc = true,
    });

    const c_flags = &.{ "-Wall", "-std=c11" };

    const lib_scanner = b.addStaticLibrary(.{
        .name = "libmufiz_scanner",
        .root_source_file = .{ .path = "src/scanner.zig" },
        .target = target,
        .optimize = .ReleaseFast,
        .link_libc = true,
    });

    // const lib_memory = b.addStaticLibrary(.{
    //     .name = "libmufiz_memory",
    //     .root_source_file = .{ .path = "src/memory.zig" },
    //     .target = target,
    //     .optimize = .ReleaseFast,
    //     .link_libc = true,
    // });

    // lib_memory.addIncludePath(.{ .path = "include" });
    // lib_memory.addCSourceFiles(&.{
    //     "csrc/vm.c", 
    //     "csrc/compiler.c", 
    //     "csrc/object.c",
    //     "csrc/value.c", 
    //     "csrc/table.c", 
    //     "csrc/chunk.c",
    // }, c_flags);

    // exe.linkLibrary(lib_memory);
    exe.linkLibrary(lib_scanner);

    exe.addIncludePath(.{ .path = "include" });
    // zig fmt: off
    exe.addCSourceFiles(&.{ 
        "csrc/chunk.c", 
       "csrc/compiler.c", 
        "csrc/debug.c", 
        "csrc/memory.c", 
        "csrc/object.c", 
        "csrc/table.c", 
       "csrc/vm.c", 
       "csrc/value.c" 
        }, c_flags);

    if(builtin.os.tag == .windows){
        exe.addCSourceFile(.{.file = .{.path = "csrc/pre.c"}, .flags = c_flags});
    }

    const options = b.addOptions();
    const nostd = b.option(bool, "nostd", "Run Mufi without Standard Library") orelse false;
    options.addOption(bool, "nostd", nostd);
    exe.addOptions("build_opts", options);

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
