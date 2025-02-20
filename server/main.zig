const std = @import("std");
const net = std.net;
const posix = std.posix;
const assert = std.debug.assert;
const stdout = std.io.getStdOut().writer();

var addr = net.Address.initIp4(
	[4]u8{0,0,0,0}, // accept connections from any address
	12271, // default port
);

// generic packet structure
const Packet = [9]u8;

var conns: [10]?struct{
	id: u8,
	addr: net.Address
} = .{null} ** 10;
// support a maximum of 10 connections
var no_conns: u8 = 0; // current number of connections

var biggest_id: u8 = 0; // largest id till now

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

	var buf: Packet = .{0} ** 9;
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
				const hi: Packet = .{new_id()} ++ .{0xff} ** 8;
				posix.sendto(
					sock,
					hi[0..],
					0,
					&client.any,
					client.getOsSockLen(),
				);

				// TODO: handle full server
				add_conn(hi[0], client) catch {};
			},
			else => update_position()
				catch |err| return err,
		}
	}
}

// TODO: Long lived server will need to keep track which ids have already been
// taken.
inline fn new_id() u8 {
	biggest_id += 1;
	return biggest_id;
}

inline fn update_position(id: u8, client: net.Address) !void {
	_ = id;
	_ = client;
	return void;
}

const LobbyErrors = error{ServerFull};
// Add to the conns array
inline fn add_conn(id: u8, client: net.Address) LobbyErrors!void {
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
			break;
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
