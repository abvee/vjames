const std = @import("std");
const targets: ?[]const std.Target.Query = &.{
    .{ .cpu_arch = .aarch64, .os_tag = .macos },
    .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .gnu },
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{
		.whitelist = targets,
	});
    const optimize = b.standardOptimizeOption(.{});

	// Build the main executable
    const exe = b.addExecutable(.{
        .name = "skrr",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

	// statically link raylib
	if (target.result.os.tag == .macos) {
		exe.addIncludePath(b.path("raylib-5.5_macos/include"));
		exe.addObjectFile(b.path("raylib-5.5_macos/lib/libraylib.a"));

		// According to the raylib wiki, we need all this
		exe.linkFramework("CoreVideo");
		exe.linkFramework("IOKit");
		exe.linkFramework("Cocoa");
		exe.linkFramework("GLUT");
		exe.linkFramework("OpenGL");
	}
	else {
		exe.addIncludePath(b.path("raylib-5.5_linux_amd64/include"));
		exe.addObjectFile(b.path("raylib-5.5_linux_amd64/lib/libraylib.a"));
	}
	exe.linkLibC(); // does this work on macOS ??
    b.installArtifact(exe);

	// run step
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
