const std = @import("std");
const rl = @cImport({
	@cInclude("raylib/include/raylib.h");
	@cInclude("raylib/include/raymath.h");
	@cInclude("raylib/include/rlgl.h");
});
const level = @import("level.zig");

const screen_width = 1440;
const screen_height = 900;
const SIDE = 40;
const SPEED = 0.1;

const Player = struct {
	x: f32,
	y: f32,
	box: rl.Rectangle,
};

pub fn main() !void {
	// Allocator // TODO: replace with GPA
	var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
	defer arena.deinit();
	const allocator = arena.allocator();

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
	const lvl = try level.load(allocator, "lvls/lvl1");

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

		// update camera
		camera.target = rl.Vector2{.x = player.x, .y = player.y};

		rl.BeginDrawing();
		defer rl.EndDrawing();

		rl.ClearBackground(rl.BLACK);

		// camera
		rl.BeginMode2D(camera);
		defer rl.EndMode2D();
		rl.DrawRectangleRec(player.box, rl.RED);
		rl.DrawCircleLinesV(camera.target, 1.41 * 20, rl.SKYBLUE);
		rl.DrawCircleLinesV(camera.target, 1.41 * 20 + 10, rl.PURPLE);

		// draw level
		for (lvl) |l| {
			rl.DrawRectangleRec(l, rl.RAYWHITE);
		}
	}
}
