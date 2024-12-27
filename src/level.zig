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
	const number = patoi(try reader.readUntilDelimiterAlloc(allocator, '\n', MAX));

	var i: u8 = 0;
	while (i < number):(i += 1) {
		const line = try reader.readUntilDelimiterAlloc(allocator, '\n', MAX);

		var p: [*]const u8 = @ptrCast(line);
		var j: u8 = 0; // iterator
		for (line) |l| {
			if (l == ',') {
				std.debug.print("{d} ", .{delim_atoi(p[0..j], ',') + 1});
				p = @ptrCast(&line[j + 1]);
			}
			else
				j += 1;
		}
		std.debug.print("\n", .{});
	}
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
fn patoi(s: []const u8) u32 {
	var ret: u32 = 0;
	for (s) |i| {
		ret *= 10;
		ret += i - '0';
	}
	return ret;
}

// atoi until a delimiter
inline fn delim_atoi(s: []const u8, delim: u8) f32 {
	var r: f32 = 0;
	for (s) |i| {
		if (i == delim)
			return r;
		r = (r * 10) + @as(f32, @floatFromInt(i - '0'));
	}
	return r;
}
