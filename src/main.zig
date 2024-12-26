const std = @import("std");
const rl = @cImport({
	@cInclude("raylib/include/raylib.h");
	@cInclude("raylib/include/raymath.h");
	@cInclude("raylib/include/rlgl.h");
});

const screen_width = 1440;
const screen_height = 900;
const SIDE = 40;
const SPEED = 0.03;

const Player = struct {
	x: f32,
	y: f32,
	box: rl.Rectangle,
};

pub fn main() void {

	// Init window
	rl.InitWindow(screen_width, screen_height, "game");
	defer rl.CloseWindow();

	// player
	// world space coords
	var player: Player = Player{
		.x = 0,
		.y = 0,
		.box = rl.Rectangle{
			.x = 0 - SIDE / 2,
			.y = 0 - SIDE / 2,
			.width = SIDE,
			.height = SIDE,
		}
	};

	// camera
	const camera: rl.Camera2D = rl.Camera2D{
		.target = rl.Vector2{.x = player.x, .y = player.y},
		.offset = rl.Vector2{
			.x = screen_width / 2, .y = screen_height / 2,
		},
		.rotation = 0,
		.zoom = 1,
	};

	// Main game loop
	while (!rl.WindowShouldClose()) {
		// movement
		if (rl.IsKeyDown(rl.KEY_W))
			player.y -= SPEED
		else if (rl.IsKeyDown(rl.KEY_A))
			player.x -= SPEED
		else if (rl.IsKeyDown(rl.KEY_S))
			player.y += SPEED
		else if (rl.IsKeyDown(rl.KEY_D))
			player.x += SPEED;

		// update player bounding box
		player.box.x = player.x;
		player.box.y = player.y;

		rl.BeginDrawing();
		defer rl.EndDrawing();

		rl.ClearBackground(rl.BLACK);

		// camera
		rl.BeginMode2D(camera);
		defer rl.EndMode2D();
		rl.DrawRectangleRec(player.box, rl.RED);

		// context
		const context: [2]rl.Rectangle = [_]rl.Rectangle{
			rl.Rectangle{.x = SIDE, .y = SIDE, .width = SIDE, .height = SIDE},
			rl.Rectangle{.x = 2 * SIDE, .y = 2 * SIDE, .width = SIDE, .height = SIDE},
		};
		rl.DrawRectangleRec(context[0], rl.RAYWHITE);
		rl.DrawRectangleRec(context[1], rl.RAYWHITE);
	}
}
