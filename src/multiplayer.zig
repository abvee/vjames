const std = @import("std");
const rl = @cImport({
	@cInclude("raylib.h");
	@cInclude("raymath.h");
	@cInclude("rlgl.h");
});
const constants = @import("constants.zig");
const assert = std.debug.assert;
// This file contains all the drawing and parsing stuff for other players
// This code will not have any network requests. the Client stuff will be in
// network.zig.

// consts
const MAX_PLAYERS = constants.MAX_PLAYERS;
const SIDE = constants.SIDE;
const RT2 = constants.RT2;

// list of other players
var others: [MAX_PLAYERS]?rl.Vector2 =
	.{null} ** MAX_PLAYERS;
// angles of the other players
var angles: [MAX_PLAYERS]f32 = [_]f32{0.0} ** MAX_PLAYERS;

// take a hi packet and initialise the others list
pub fn init(hi: []const u8) void {
	var i: usize = 0; // hi index

	while (i < hi.len) {
		const id = hi[i]; // id of that client
		i += 1;

		// this avoid us accessing null later
		others[id] = rl.Vector2{.x=0,.y=0};

		var buf: [4]u8 = .{0} ** 4;

		// I like to have some meta programming fun
		inline for (@typeInfo(rl.Vector2).Struct.fields) |field| {
			std.mem.copyForwards(u8, &buf, hi[i..i+4]);
			@field(others[id].?, field.name)
				= @bitCast(std.mem.readInt(u32, &buf, .little));
			i+=4;
		}
		// This ^ basically deserializes that byte into the correct fields of
		// rl.Vector 2

		std.mem.copyForwards(u8, &buf, hi[i..i+4]);
		angles[id] = @bitCast(std.mem.readInt(u32, &buf, .little));
		i+=4;
	}
}
test "init" {
	const hi = [_]u8{
		1,
		0x01,0x00,0x00,0x00,
		0x01,0x00,0x00,0x00,
		0x01,0x00,0x00,0x00,
	};
	std.debug.print("{d}\n", .{@sizeOf(@TypeOf(hi))});
	init(hi[0..]);
	std.debug.print("{any}\n{}\n", .{
		others[1],
		angles[1],
	});
}

// rl draw all the other players
pub inline fn draw_others() void {
	for (others, 0..) |o, i|
		if (o) |_| {
			// other player rectangle
			const p = rl.Rectangle{
				.x = o.?.x - SIDE/2,
				.y = o.?.y - SIDE/2,
				.width = SIDE,
				.height = SIDE,
			};
			rl.DrawRectangleRec(p, rl.ORANGE);

			const gun_circle_radius = RT2 * SIDE / 2.0 + SIDE / 4;
			rl.DrawCircleV(
				rl.Vector2{
					.x = gun_circle_radius * std.math.sin(angles[i]) + p.x,
					.y = gun_circle_radius * std.math.cos(angles[i]) + p.y,
				},
				constants.RADIUS,
				rl.BLUE,
			);
		};
}

pub inline fn debug_print() void {
	for (others) |o|
		std.debug.print("{any}\n", .{o});
}
