const std = @import("std");
const net = std.net;
const posix = std.posix;
const assert = std.debug.assert;
const stdout = std.io.getStdOut().writer();

// Types
const packet = packed struct {
	op: u8,
	id: u8,
	x: f32,
	y: f32,
	angle: f32,
};

const packetData = struct {
	x: f32,
	y: f32,
	angle: f32,
};

const ops = enum(u8) {
	HELLO_HI = 0xff,
	NP_NPACK = 0xee, // new player ack
	POS = 0x00,
};

// constants
const MAX_PLAYERS = 16;
// a large number for large buffers that cannot possibly overflow
const BIG_BOI = 2048;

// globals
var addr = net.Address.initIp4(
	[4]u8{0,0,0,0}, // accept connections from any address
	12271, // default port
);
var conns: [MAX_PLAYERS]?net.Address = .{null} ** MAX_PLAYERS;
var no_conns: u8 = 0;
var positions: [MAX_PLAYERS]packetData =
	[_]packetData{packetData{.x=0,.y=0,.angle=0}} ** MAX_PLAYERS;
var sockp: *const posix.socket_t = undefined;
var running = true;

const ParameterError = error{IncorrectArguments};
pub fn main() !void {

	// get port from cmdline
	if (get_port()) |port| addr.setPort(port)
	else |err| switch (err) {
		ParameterError.IncorrectArguments => {},
		else => return err,
	}
	stdout.print("Using port: {}\n", .{addr.getPort()})
		catch {};
	// socket
	const sock = try posix.socket(
		posix.AF.INET,
		posix.SOCK.DGRAM,
		posix.IPPROTO.UDP,
	);
	sockp = &sock;
	defer posix.close(sock);
	// bind
	try posix.bind(sock, &addr.any, addr.getOsSockLen());

	// Start a thread for sending positions
	_ = try std.Thread.spawn(.{}, broadcaster, .{});
	defer running = false;

	// reading buffer
	var buf: [@sizeOf(packet)]u8 = .{0} ** @sizeOf(packet);

	// Wait for new packets
	while (true) {
		var client: net.Address = undefined;
		var client_len: posix.socklen_t = @sizeOf(net.Address);

		_ = try posix.recvfrom(
			sock,
			buf[0..],
			0,
			&client.any,
			&client_len,
		);

		// get operation from first byte
		const op: ops = @enumFromInt(buf[0]);

		// TODO:
		// Try the new labelled switch thing here, eliminate that while loop up above
		switch (op) {
			.HELLO_HI => {
				const client_id = try add_conn(client);
				stdout.print("Client ID: {}\n", .{client_id})
					catch {};
				// TODO: handle server full use case

				// buffer for hi packet
				var hi: [BIG_BOI]u8 = undefined;
				const hi_len = make_hi_pkt(client_id, &hi);

				// NOTE: the id of the player is the address's position in the
				// conns array
				_ = try posix.sendto(
					sock,
					hi[0..hi_len],
					0,
					&client.any,
					client.getOsSockLen(),
				);

				// new player packet
				const new_player: packet = packet{
					.op = @intFromEnum(ops.NP_NPACK),
					.id = client_id, // id of the new player
					.x = 0,
					.y = 0,
					.angle = 0,
				};
				// TODO: spawn locations for players. Don't just dump them at
				// 0,0

				broadcast(client_id, new_player) catch {};
				// TODO: do something if the broadcast fails ?
				// will that even be the server's concern at that point ?
			},
			.NP_NPACK => {
				// TODO: do something about making sure everyone acknoledges
				// the new player
			},
			.POS => {
				// Update the player list thing
				const id = buf[1];
				const data: packetData = packetData{
					.x = 0,
					.y = 0,
					.angle = 0,
				};

				var thing:[4]u8 = [_]u8{0} ** 4;

				comptime var i = 2;
				inline for (@typeInfo(packetData).@"struct".fields) |field| {
					std.mem.copyForwards(u8, &thing, buf[i..i+4]);
					@field(data[id], field.name)
						= @bitCast(std.mem.readInt(u32, &thing, .little));
					i+=4;
				}
				update_position(id, data, client);
			},
		}
	}
}

const LobbyErrors = error{ServerFull};
// Add to the conns array, return client's id.
inline fn add_conn(client: net.Address) LobbyErrors!u8 {
	if (no_conns >= MAX_PLAYERS)
		return LobbyErrors.ServerFull;

	for (conns, 0..conns.len) |con, i| {
		if (con) |_| {}
		else {
			conns[i] = client;
			no_conns += 1;
			stdout.print("Added client: {}\n", .{client})
				catch {};
			return @intCast(i);
		}
	}

	// this should never be reached
	return LobbyErrors.ServerFull;
}

// make hi packet for that client 
// return length of that packet
fn make_hi_pkt(id: u8, buf: []u8) u8 {
	assert(id < MAX_PLAYERS);

	// the first 2 byte are still op:id
	buf[0] = @intFromEnum(ops.HELLO_HI); // op
	buf[1] = id; // id

	var j: u8 = 2; // buf index
	// we then add each player's position
	for (conns, 0..) |conn, i| {
		if (i == id) continue; // skip our player

		if (conn) |_| {
			buf[j] = @intCast(i); // id of existing player
			std.mem.copyForwards(
				u8,
				buf[j..],
				std.mem.asBytes(&positions[i]),
			);
			j += @sizeOf(packetData) + 1;
		}
	}
	return j; // return that index
}
test "make_hi_pkt" {
	var hi: [BIG_BOI]u8 = undefined;
	const n = make_hi_pkt(0x01, &hi);
	std.debug.print("the entire hi packet:\n{x}\n", .{hi[0..n]});
	std.debug.print("length: {}\n", .{n});
}

// broadcast packet to everyone but id
fn broadcast(id: u8, pack: packet) !void {
	assert(conns[id] != null);
	for (conns, 0..conns.len) |conn, i| {
		if (i == id or conn == null)
			continue; // skip our player and non existant player
		_ = try posix.sendto(
			sockp.*,
			std.mem.asBytes(&pack),
			0,
			&conn.?.any,
			conn.?.getOsSockLen(),
		);
	}
}

fn broadcaster() void {
	while (running) {
		for (conns, 0..conns.len) |conn, i| {
			if (conn == null)
				continue;
			const p: packet = packet{
				.op = @intFromEnum(ops.POS),
				.id = i,
				.x = positions[i].x,
				.y = positions[i].y,
				.angle = positions[i].angle,
			};
			try broadcast(i, p);
			// TODO: fix something about this
		}
		std.time.sleep(std.time.ns_per_s * 0.5);
	}
}

const PossibleCheaters = error{Impersonation};
// Change global position data for client
inline fn update_position(id: u8, data: packetData, client: net.Address) PossibleCheaters!void {

	// check if a client even exists are that specified address
	if (conns[id] == null)
		return PossibleCheaters.Impersonation;

	// perform sanity check that the clients are the same
	if (conns[id].?.eql(client) == false)
		return PossibleCheaters.Impersonation;

	positions[id] = data;
	std.debug.print("client: {}, position: {any}\n", .{client, positions[id]});
	return;
}

// get port from the command line and return it
inline fn get_port() !u16 {
	switch (std.os.argv.len) {
		1 => {
			try stdout.print("No arguments found, using default port: {}\n", .{addr.getPort()});
			return addr.getPort();
		},
		3 => {
			if (!std.mem.orderZ(u8, std.os.argv[1], "-p").compare(.eq)) {
				try stdout.print("Unkown argument, using default port: {}\n", .{addr.getPort()});
				return ParameterError.IncorrectArguments;
			}
			if (std.fmt.parseInt(
					u16, std.os.argv[2][0..std.mem.len(std.os.argv[2])],10
				)
			) |port| return port
			else |err| return err;
		},
		else => {
			std.debug.print(
				"Incorrect number of commandline argument found, using default port: {}\n",
				.{addr.getPort()},
			);
			return ParameterError.IncorrectArguments;
		},
	}
}
test "get_port" {
	if (get_port()) |port|
		std.debug.print("{}\n", .{port})
	else |err| return err;
}
