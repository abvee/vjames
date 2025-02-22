const std = @import("std");
const rl = @cImport({
	@cInclude("raylib.h");
	@cInclude("raymath.h");
	@cInclude("rlgl.h");
});
const level = @import("level.zig");
const network = @import("network.zig");
const multiplayer = @import("multiplayer.zig");

const screen_width = 1440;
const screen_height = 900;
pub const SIDE = 40;
pub const RADIUS = 10.0;
const SPEED = @as(f32, @floatFromInt(SIDE)) / 400.0;
const RT2 = std.math.sqrt2;

// types
const Player = struct {
	x: f32,
	y: f32,
	box: rl.Rectangle,
};

const Gun = struct{
	center: rl.Vector2,
	radius: f32 = RADIUS,
};

var running: bool = true; // threads running bool

pub fn main() !void {
	// Allocator // TODO: replace with GPA
	var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
	defer arena.deinit();
	const allocator = arena.allocator();

	// Initialise the network
	try network.init();
	defer network.deinit();

	// Init window
	rl.InitWindow(screen_width, screen_height, "game");
	defer rl.CloseWindow();

	// player
	// note that all coords are world space coords, unless it's a reference.
	var player: Player = Player{
		.x = 0,
		.y = 0,
		.box = undefined,
	};
	player.box = rl.Rectangle{
		.x = player.x - SIDE / 2,
		.y = player.y - SIDE / 2,
		.width = SIDE,
		.height = SIDE,
	};

	// gun
	var gun: Gun = Gun{
		.center = undefined, // will be defined later
		.radius = SIDE / 4,
	};
	const gun_circle_radius = RT2 * SIDE / 2.0 + SIDE / 4;

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
		const angle = std.math.atan2((mouse_pos.x - screen_width / 2) , (mouse_pos.y - screen_height / 2));
		gun.center = rl.Vector2{
			.x = gun_circle_radius * std.math.sin(angle) + player.x,
			.y = gun_circle_radius * std.math.cos(angle) + player.y,
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
			// placeholder
			multiplayer.draw_others();
		}
		try draw_references();

	}
}

// constant tick thread
// operations done in it need not be physics related
fn physics() void {
	while (running) {
		const pack = network.recv_packet();
		// TODO: loop through all the buffered packets and make the sockets non
		// blocking
		switch (pack.op) {
			.POS => multiplayer.update_pos(pack),
			else => {},
		}
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
