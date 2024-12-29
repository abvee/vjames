const std = @import("std");
const fs = std.fs;
const rl = @cImport({
	@cInclude("raylib/include/raylib.h");
	@cInclude("raylib/include/raymath.h");
	@cInclude("raylib/include/rlgl.h");
});

const MAX = 1024; // temporary maximum variable

// the level doesn't ever need to change, so just cast it to const.
pub fn load(allocator: std.mem.Allocator, path: []const u8) ![]rl.Rectangle {
	const file = try fs.cwd().openFile(path, .{});
	defer file.close();
	const reader = file.reader();

	// Number of rectangles in the level
	const number = patoi(u32, try reader.readUntilDelimiterAlloc(allocator, '\n', MAX));
	// the actual rectangles to be returned
	const rects: []rl.Rectangle = try allocator.alloc(rl.Rectangle, number);
	var i: u8 = 0; // rects index

	while (i < number):(i += 1) {
		const line = try reader.readUntilDelimiterAlloc(allocator, '\n', MAX);
		var j: u8 = 0; // line index
		var k: u8 = 0; // index of previous segment

		while (line[j] != ',') : (j += 1) {}
		rects[i].x = patoi(f32, line[k..j]);
		j += 1;
		k = j;

		while (line[j] != ',') : (j += 1) {}
		rects[i].y = patoi(f32, line[k..j]);
		j += 1;
		k = j;

		while (line[j] != ',') : (j += 1) {}
		rects[i].width = patoi(f32, line[k..j]);
		j += 1;
		k = j;

		while (j < line.len and line[j] != ',') : (j += 1) {}
		rects[i].height = patoi(f32, line[k..j]);
		j += 1;
		k = j;
	}
	return rects;
}
test "level loading test" {
	std.debug.print("--LEVEL LOADING--\n", .{});
	// Allocator
	var arena = std.heap.ArenaAllocator.init(
		std.heap.page_allocator
	);
	defer arena.deinit();
	const allocator = arena.allocator();
	try load(allocator, "lvls/lvl1");
}

// Basic Atoi function for positive integers
fn patoi(T: type, s: []const u8) T {
	var ret: T = 0;
	for (s) |i| {
		ret *= 10;

		if (T == f32)
			ret += @as(T, @floatFromInt(i - '0'))
		else
			ret += i - '0';
	}
	return ret;
}
test "patoi" {
	std.debug.print("--PATOI--\n", .{});
	std.debug.print("{d}\n", .{patoi(f32, "40") + 0.1});
}
