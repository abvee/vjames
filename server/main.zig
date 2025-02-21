const std = @import("std");
const net = std.net;
const posix = std.posix;
const assert = std.debug.assert;
const stdout = std.io.getStdOut().writer();

// Types
// generic packet structure
const packetData = [12]u8;
const packet = [1 + @sizeOf(packetData)]u8;
// a packet is 1 byte for (id) and the rest of the packet

// globals
var addr = net.Address.initIp4(
	[4]u8{0,0,0,0}, // accept connections from any address
	12271, // default port
);
const MAX_PLAYERS = 16;
var conns: [MAX_PLAYERS]?net.Address = .{null} ** MAX_PLAYERS;
// support a maximum of 10 connections
var positions: [MAX_PLAYERS]packetData =
	[_][@sizeOf(packetData)]u8{[_]u8{0} ** @sizeOf(packetData)} ** MAX_PLAYERS;
// [10][8]u8{0 filled};
var no_conns: u8 = 0; // current number of connections
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

	// start broadcasting
	const broadcast_thread = try std.Thread.spawn(
		.{},
		broadcast_handler,
		.{},
	);
	defer broadcast_thread.join();

	var buf: packet = .{0} ** @sizeOf(packet);
	// packet buffer
	// refer to client networking for packet structure.

	// Wait for new packets
	while (true) {
		var client: net.Address = undefined;
		var client_len: posix.socklen_t = @sizeOf(net.Address);

		_ = try posix.recvfrom(sock, buf[0..], 0, &client.any, &client_len);

		const op_id = buf[0]; // first byte of packet is op + id
		switch (op_id) {
			0xff => {
				const client_id = try add_conn(client);
				// TODO: handle server full use case

				// hi packet. Refer packet datasheet
				const hi = [1]u8{0xf0 + client_id} ++ .{0xff} ** @sizeOf(packetData);

				// NOTE: the id of the player is the address's position in the
				// conns array

				_ = try posix.sendto(
					sock,
					&hi,
					0,
					&client.any,
					client.getOsSockLen(),
				);
			},
			else => update_position(buf, client)
				catch |err| return err, // TODO: handle cheaters
			// TODO: What if that address at that id is null ? Handle that case
		}
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

// broadcast id's position to all other players
fn broadcast(id: u8) !void {
	const pack: packet = [1]u8{id} ++ positions[id];
	for (conns, 0..conns.len) |conn, i| {
		if (i == id or conn == null)
			continue; // skip our player and non existant player
		_ = try posix.sendto(
			sockp.*,
			&pack,
			0,
			&conn.?.any,
			conn.?.getOsSockLen(),
		);
		// TODO: if sending fails, then we shouldn't just return from the
		// program.
	}
}

fn broadcast_handler() !void {
	while (true) {
		// TODO: probably needs like lerp or something with whatever timing we
		// choose. We do this on the client, don't forget to do it.
		std.time.sleep(std.time.ns_per_s * 0.5);
		for (0..MAX_PLAYERS) |i|
			if (conns[i]) |_| try broadcast(@intCast(i));
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
