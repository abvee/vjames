const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "skrr",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
	// statically link raylib
	exe.addIncludePath(b.path(".")); // Will this work ?
	exe.addObjectFile(b.path("raylib/lib/libraylib.a"));
	exe.linkLibC();
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
