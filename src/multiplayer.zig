const std = @import("std");
const rl = @cImport({
	@cInclude("raylib.h");
	@cInclude("raymath.h");
	@cInclude("rlgl.h");
});
const network = @import("network.zig");
// This file contains all the drawing and parsing stuff for other players
// This code will not have any network requests. the Client stuff will be in
// network.zig.

const MAX_PLAYERS = 16;

// list of other players
var others: [MAX_PLAYERS]?rl.Vector2 =
	.{null} ** MAX_PLAYERS;
// angles of the other players
var angles: [MAX_PLAYERS]f32 = [_]f32{0.0} ** MAX_PLAYERS;
