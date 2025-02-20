const std = @import("std");
const net = std.net;
const posix = std.posix;
const assert = std.debug.assert;
const stdout = std.io.getStdOut().writer();

var addr = net.Address.initIp4(
	[4]u8{0,0,0,0}, // accept connections from any address
	12271, // default port
);

const MAX_PLAYERS = 10;

// generic packet structure
const packetData = [8]u8;
const packet = [1 + packetData.len]u8;
// a packet is 1 byte for (id) and the rest of the packet

var conns: [MAX_PLAYERS]?net.Address = .{null} ** MAX_PLAYERS;
// support a maximum of 10 connections
var positions: [MAX_PLAYERS]packetData = .{0} ** packetData.len ** MAX_PLAYERS;
var no_conns: u8 = 0; // current number of connections

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
	defer posix.close(sock);

	// bind
	try posix.bind(sock, &addr.any, addr.getOsSockLen());

	var buf: packet = .{0} ** 9;
	// packet buffer
	// refer to client networking for packet structure.

	// wait for packets
	while (true) {
		var client: net.Address = undefined;
		var client_len: posix.socklen_t = @sizeOf(net.Address);

		_ = try posix.recvfrom(sock, buf[0..], 0, &client.any, &client_len);

		const id = buf[0]; // first byte of output is id
		switch (id) {
			0xff => {
				const client_id = add_conn(client);
				const hi = .{client_id} ++ .{0xff} ** 8;
				// hi packet

				// NOTE: the id of the player is the address's position in the
				// conns array

				posix.sendto(
					sock,
					hi[0..],
					0,
					&client.any,
					client.getOsSockLen(),
				);
			},
			else => update_position(buf, client)
				catch |err| return err, // TODO: handle cheaters
		}
	}
}

const PossibleCheaters = error{Impersonation};
// Change global position data for client
inline fn update_position(data: packet, client: net.Address) PossibleCheaters!void {
	// perform sanity check that the clients are the same
	const id = data[0];
	if (conns[id].eql(client) == false)
		return PossibleCheaters.Impersonation;

	positions[id] = data;
	return void;
}

const LobbyErrors = error{ServerFull};
// Add to the conns array
inline fn add_conn(id: u8, client: net.Address) LobbyErrors!u8 {
	if (no_conns > 10)
		return LobbyErrors.ServerFull;

	for (conns, 0..conns.len) |con, i| {
		if (con) |_| {}
		else {
			conns[i] = .{
				.id = id,
				.addr = client,
			};
			no_conns += 1;
			return i;
		}
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
