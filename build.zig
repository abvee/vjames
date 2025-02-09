const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

	// Build the main executable
    const exe = b.addExecutable(.{
        .name = "skrr",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
	// statically link raylib
	exe.addIncludePath(b.path("raylib-5.5_linux_amd64/include"));
	exe.addObjectFile(b.path("raylib-5.5_linux_amd64/lib/libraylib.a"));
	exe.linkLibC();
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the game client");
    run_step.dependOn(&run_cmd.step);

	// Build the server
	const server = b.addExecutable(.{
		.name = "skrr-server",
		.root_source_file = b.path("server/main.zig"),
		.target = target,
		.optimize = optimize,
	});
	b.installArtifact(server);
	// server run artifact
	const serve_cmd = b.addRunArtifact(server);
    serve_cmd.step.dependOn(b.getInstallStep());
	if (b.args) |args| {
		serve_cmd.addArgs(args);
	}
	// serve step
	const serve_step = b.step("serve", "Run the server");
	serve_step.dependOn(&serve_cmd.step);
}
