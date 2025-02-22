const std = @import("std");
const rl = @cImport({
	@cInclude("raylib.h");
	@cInclude("raymath.h");
	@cInclude("rlgl.h");
});
const assert = std.debug.assert;
const packet = @import("network.zig").packet;
// This file contains all the drawing and parsing stuff for other players
// This code will not have any network requests. the Client stuff will be in
// network.zig.

const MAX_PLAYERS = 16;
const SIDE = @import("main.zig").SIDE;
const RADIUS = @import("main.zig").RADIUS;

// list of other players
var others: [MAX_PLAYERS]?rl.Vector2 =
	.{null} ** MAX_PLAYERS;
// angles of the other players
var angles: [MAX_PLAYERS]f32 = [_]f32{0.0} ** MAX_PLAYERS;

pub fn update(p: packet) void {
	const id: u8 = @intCast(p.id);

	// Make sure that the player we're talking about hasn't disconnected
	if (others[id] == null) return;

	others[id] = rl.Vector2{p.x, p.y};
	angles[id] = p.angle;
}

pub inline fn add_player(pac: packet) void {
	// TODO: verify that the packet is actually correct

	assert(others[pac.id] == null);
	// TODO: for this assert to not trigger, disconnecting packets will have to
	// be made
	others[pac.id] = rl.Vector2{.x = pac.x, .y = pac.y};
	angles[pac.id] = pac.angle;
	std.debug.print("A player has been added !\n", .{});
}

// rl draw all the other players
pub inline fn draw_others() void {
	for (others) |player| {
		if (player == null) continue;

		const pos: rl.Vector2 = rl.Vector2{
			.x = player.?.x - SIDE / 2,
			.y = player.?.y - SIDE / 2,
		};
		rl.DrawRectangleV(pos, .{.x=SIDE,.y=SIDE}, rl.ORANGE);
		rl.DrawCircleV(player.?, RADIUS, rl.BLUE);
	}
}
