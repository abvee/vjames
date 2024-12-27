const std = @import("std");
const fs = std.fs;
// const rl = @cImport({
// 	@cInclude("raylib/include/raylib.h");
// 	@cInclude("raylib/include/raymath.h");
// 	@cInclude("raylib/include/rlgl.h");
// });

const MAX = 1024; // temporary maximum variable

// the level doesn't ever need to change, so just cast it to const.
pub fn load(allocator: std.mem.Allocator, path: []const u8) !void {
	const file = try fs.cwd().openFile(path, .{});
	defer file.close();
	const reader = file.reader();

	// Number of rectangles in the level
	const number = atoi(try reader.readUntilDelimiterAlloc(allocator, '\n', MAX));
	std.debug.print("{d}\n", .{number + 1});
}
test "level loading test" {
	// Allocator
	var arena = std.heap.ArenaAllocator.init(
		std.heap.page_allocator
	);
	defer arena.deinit();
	const allocator = arena.allocator();
	try load(allocator, "lvls/lvl1");
}

// Basic Atoi function for positive integers
fn atoi(s: []const u8) u32 {
	var ret: u32 = 0;
	for (s) |i| {
		ret *= 10;
		ret += i - '0';
	}
	return ret;
}
