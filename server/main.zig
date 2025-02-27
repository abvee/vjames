const std = @import("std");
const net = std.net;
const posix = std.posix;
const assert = std.debug.assert;
const stdout = std.io.getStdOut().writer();

// Types
const packet = packed struct {
	op: u4,
	id: u4,
	x: f32,
	y: f32,
	angle: f32,
};
const packetData = struct {
	x: f32,
	y: f32,
	angle: f32,
};

const ops = enum(u4) {
	HELLO_HI = 0xf,
	NP_NPACK = 0xe, // new player ack
	POS = 0x0,
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

const ParameterError = error{IncorrectArguments};
pub fn main() !void {

	// get port from cmdline
	if (get_port()) |port| addr.setPort(port)
	else |err| switch (err) {
		ParameterError.IncorrectArguments => {},
		else => return err,
	}
	try stdout.print("Using port: {}\n", .{addr.getPort()});
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
		const op: ops = @enumFromInt(buf[0] >> 4);

		switch (op) {
			.HELLO_HI => {
				const client_id = try add_conn(client);
				std.debug.print("Client ID: {}\n", .{client_id});
				// TODO: handle server full use case

				// buffer for hi packet
				var hi: [BIG_BOI]u8 = undefined;
				const n = make_hi_pkt(client_id, &hi);

				// NOTE: the id of the player is the address's position in the
				// conns array
				_ = try posix.sendto(
					sock,
					hi[0..n],
					0,
					&client.any,
					client.getOsSockLen(),
				);

				// new player packet
				const new_player: packet = packet{
					.op = @intFromEnum(ops.NP_NPACK),
					.id = @intCast(client_id & 0x0f), // id of the new player
					.x = 0,
					.y = 0,
					.angle = 0,
				};
				broadcast(client_id, new_player) catch {};
				// TODO: do something if the broadcast fails ?
				// will that even be our concern at that point ?
				// Idk just redo it ig ?
			},
			.NP_NPACK => {
				// TODO: do something about making sure everyone acknoledges
				// the new player
			},
			.POS => {
				// TODO:
				// something something position thread
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
			std.debug.print("Added client: {}\n", .{client});
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

	// the first byte is still op:id
	buf[0] = @intFromEnum(ops.HELLO_HI);
	buf[0] = (buf[0] << 4) + id;

	var j: u8 = 1; // buf index
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
	const n = make_hi_pkt(0x1, &hi);
	std.debug.print("the entire hi packet:\n{x}\n", .{hi[0..n]});
	std.debug.print("length: {}\n", .{n});
}

// broadcast packet to everyone but id
fn broadcast(id: u8, pack: packet) !void {
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

const PossibleCheaters = error{Impersonation};
// Change global position data for client
inline fn update_position(data: packet, client: net.Address) PossibleCheaters!void {
	const id = data[0];

	// check if a client even exists are that specified address
	if (conns[id] == null)
		return PossibleCheaters.Impersonation;

	// perform sanity check that the clients are the same
	if (conns[id].?.eql(client) == false)
		return PossibleCheaters.Impersonation;

	std.mem.copyForwards(u8, positions[id][0..], data[1..]);

	std.debug.print("client: {}, position: {any}\n", .{client, positions[id]});
	return;
}

// position broadcaster thread
fn position_broadcaster() !void {
	while (true) {
		// TODO: probably needs like lerp or something with whatever timing we
		// choose. We do this on the client, don't forget to do it.
		std.time.sleep(std.time.ns_per_s * 0.5);
		for (0..MAX_PLAYERS) |i|
			if (conns[i]) |_| {
				const pack = [_]u8{@intCast(i)} ++ positions[i];
				try broadcast(@intCast(i), pack);
			};
		// TODO: don't shit yourself if a single packet fails to send
	}
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
