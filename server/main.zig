const std = @import("std");
const net = std.net;
const posix = std.posix;
const stdout = std.io.getStdOut().writer();

var addr = net.Address.initIp4(
	[4]u8{0,0,0,0}, // accept connections from any address
	12271, // default port
);

var conns: [8]std.Thread = [_]std.Thread{} ** 8;
// max of 8 people. Should make this changeable ?

const ParameterError = error {IncorrectArguments};
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
	@compileLog(@TypeOf(sock));

	// bind
	try posix.bind(sock, &addr.any, addr.getOsSockLen());

	// We start here
	var buf: [8]u8 = .{0} ** 8;

	// wait for hello packets forever
	while (true) {
		var client: net.Address = undefined;
		var client_len: posix.socklen_t = @sizeOf(net.Address);

		// client hello packet
		_ = try posix.recvfrom(sock, buf[0..], 0, &client.any, &client_len);
		// server hi packet
		_ = try posix.sendto(sock, "hi", 0, &client.any, client.getOsSockLen());
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
