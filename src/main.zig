const std = @import("std");
const rl = @cImport({
	@cInclude("raylib/include/raylib.h");
	@cInclude("raylib/include/raymath.h");
	@cInclude("raylib/include/rlgl.h");
});

const screen_width = 1440;
const screen_height = 900;

pub fn main() void {

	// Init window
	rl.InitWindow(screen_width, screen_height, "game");
	defer rl.CloseWindow();

	// Main game loop
	while (!rl.WindowShouldClose()) {
		rl.BeginDrawing();
		defer rl.EndDrawing();

		// Do C enums become raylib enums ? No
		rl.ClearBackground(rl.BLACK);
		rl.DrawText("Hello world", screen_width / 2, screen_height / 2, 20, rl.LIGHTGRAY);
	}
}
