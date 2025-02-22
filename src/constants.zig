// All constants needed by everyone including main go in this file
// This is mainly to stop some file from importing main.zig

const std = @import("std");

pub const SIDE = 40;
pub const GUN_RADIUS = 10.0;
pub const MAX_PLAYERS = 16;
pub const RT2 = std.math.sqrt2;
pub const GUN_CIRCLE_RADIUS =  RT2 * SIDE / 2.0 + SIDE / 4;
