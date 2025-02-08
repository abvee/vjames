const std = @import("std");
const net = std.net;
const posix = std.posix;

var addr = net.Address.initIp4(
	[4]u8{0,0,0,0}, // accept connections from any address
	12271, // default port
);

pub fn main() !void {
	const sock = try posix.socket(
		posix.AF.INET,
		posix.SOCK.DGRAM,
		posix.IPPROTO.UDP,
	);
	defer posix.close(sock);

	// bind
	try posix.bind(sock, &addr.any, addr.getOsSockLen());

	// recvfrom single client
	var buf: [1024]u8 = .{0} ** 1024;

	var client: net.Address = undefined;
    var client_len: posix.socklen_t = @sizeOf(net.Address);

	_ = try posix.recvfrom(sock, buf[0..], 0, &client.any, &client_len);
	std.debug.print("{s}\n", .{buf});

	// sendto
	_ = try posix.sendto(sock, "bye bye world", 0, &client.any, @sizeOf(net.Address));
}
