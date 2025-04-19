const std = @import("std");
const rl = @cImport({
	@cInclude("raylib.h");
	@cInclude("raymath.h");
	@cInclude("rlgl.h");
});
const level = @import("level.zig");
const network = @import("network.zig");
const multiplayer = @import("multiplayer.zig");
const constants = @import("constants.zig");
const stdout = std.io.getStdOut().writer();

const screen_width = 1440;
const screen_height = 900;
const SIDE = constants.SIDE;
const SPEED = @as(f32, @floatFromInt(SIDE)) / 400.0;
const GUN_RADIUS = constants.GUN_RADIUS;
const GUN_CIRCLE_RADIUS = constants.GUN_CIRCLE_RADIUS;
const RT2 = constants.RT2;

// types
const Player = struct {
	x: f32,
	y: f32,
	box: rl.Rectangle,
};

const Gun = struct{
	center: rl.Vector2,
	radius: f32 = GUN_RADIUS,
};

var running: bool = true; // threads running bool
// player
// note that all coords are world space coords, unless it's a reference.
var player: Player = Player{
	.x = 0,
	.y = 0,
	.box = undefined,
};
var gun_angle: f32 = 0.0;

pub fn main() !void {
	// Allocator // TODO: replace with GPA
	var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
	defer arena.deinit();
	const allocator = arena.allocator();

	// Initialise the network
	multiplayer.init(try network.init(allocator));
	defer network.deinit();

	// multiplayer.debug_print();

	// Init window
	rl.InitWindow(screen_width, screen_height, "game");
	defer rl.CloseWindow();

	player.box = rl.Rectangle{
		.x = player.x - SIDE / 2,
		.y = player.y - SIDE / 2,
		.width = SIDE,
		.height = SIDE,
	};

	// gun
	var gun: Gun = Gun{
		.center = undefined, // will be defined later
		.radius = GUN_RADIUS,
	};

	// camera
	var camera: rl.Camera2D = rl.Camera2D{
		.target = rl.Vector2{.x = player.x, .y = player.y},
		.offset = rl.Vector2{
			.x = screen_width / 2, .y = screen_height / 2,
		},
		.rotation = 0,
		.zoom = 1,
	};

	// level
	const lvl = try level.load(allocator, "lvls/lvl2");

	// server reciever thread
	_ = try std.Thread.spawn(.{}, net_recieve, .{});
	// position sender thread
	_ = try std.Thread.spawn(.{}, physics, .{});
	defer running = false;
	// TODO: don't defer join this thread until the socket is non-blocking

	// Main game loop
	while (!rl.WindowShouldClose()) {
		var collision: rl.Rectangle = player.box;

		// player movement
		if (rl.IsKeyDown(rl.KEY_W))
			collision.y -= SPEED
		else if (rl.IsKeyDown(rl.KEY_A))
			collision.x -= SPEED
		else if (rl.IsKeyDown(rl.KEY_S))
			collision.y += SPEED
		else if (rl.IsKeyDown(rl.KEY_D))
			collision.x += SPEED;

		// update player bounding box only if collisions haven't occured
		if (
			// for expression checks if collisions have occured
			for (lvl) |l| {
				if (rl.CheckCollisionRecs(l, collision))
					break false;
			}
			else true
		) {
			player.box = collision;
			player.x = player.box.x + SIDE / 2;
			player.y = player.box.y + SIDE / 2;
		}

		// update gun
		const mouse_pos = rl.GetMousePosition();
		gun_angle = std.math.atan2((mouse_pos.x - screen_width / 2) , (mouse_pos.y - screen_height / 2));
		gun.center = rl.Vector2{
			.x = GUN_CIRCLE_RADIUS * std.math.sin(gun_angle) + player.x,
			.y = GUN_CIRCLE_RADIUS * std.math.cos(gun_angle) + player.y,
		};

		// update camera
		camera.target = rl.Vector2{.x = player.x, .y = player.y};

		rl.BeginDrawing();
		defer rl.EndDrawing();

		rl.ClearBackground(rl.BLACK);

		// camera
		{
			rl.BeginMode2D(camera);
			defer rl.EndMode2D();

			// draw player
			rl.DrawRectangleRec(player.box, rl.RED);
			rl.DrawCircleV(gun.center, gun.radius, rl.BLUE);

			// draw level
			for (lvl) |l| {
				rl.DrawRectangleRec(l, rl.RAYWHITE);
			}
			multiplayer.draw_others();
		}
		try draw_references();
	}
}

// get data from the server
fn net_recieve() void {
	while (running) {
		const p = network.recv_packet();
		if (p.isPosPacket())
			multiplayer.update_positions(p)
		else if (p.isNewPlayerPacket())
			multiplayer.add_player(p);
	}
}

// Thread runs at fixed intervals of time
// Used for position udpates
fn physics() !void {
	while (running) {
		std.time.sleep(std.time.ms_per_s);
		try network.send_pos(player.x, player.y, gun_angle);
	}
}

// draw all references in screen space
inline fn draw_references() !void {
	const center = rl.Vector2{.x = screen_width / 2, .y = screen_height / 2};

	// hit box circumcircle
	rl.DrawCircleLinesV(center, RT2 * SIDE / 2.0, rl.SKYBLUE);

	// gun circle
	// rl.DrawCircleLinesV(center, RT2 * SIDE / 2.0 + (SIDE / 4), rl.PURPLE);

	// gun outer circle
	rl.DrawCircleLinesV(center, RT2 * SIDE / 2.0 + (SIDE / 2), rl.YELLOW);

	const mouse_pos = rl.GetMousePosition();

	// center to mouse position
	rl.DrawLineV(center, mouse_pos, rl.GREEN);

	// debug angle
	const angle = std.math.atan2((mouse_pos.x - center.x) , (mouse_pos.y - center.y));
	var s: [100]u8 = [_]u8{0} ** 100;
	const t: []u8 = try std.fmt.bufPrint(s[0..], "{d}", .{angle * 180 / rl.PI});

	// NOTE: The coordinate system is flipped on it's head. The first quadrant
	// is on the bottom right, the second on the bottom left, the third on the
	// top left and fourth on the top right

	// This is because raylib considers (0,0) to be the top left, and we shift origin to the center.
	// X directions are the same on paper, but Y increases as we go down

	rl.DrawText(@ptrCast(t), screen_width / 2, screen_height - 50, 20, rl.GREEN);
}
