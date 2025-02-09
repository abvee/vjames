const std = @import("std");
const net = std.net;
const posix = std.posix;
const assert = std.debug.assert;

const PORT = 12271; // default port
var sock: ?posix.socket_t  = null; // client socket
var addr: net.Address = undefined; // server's address
var server: std.fs.File = undefined; // read and write to server's file.

const netArgsErrors = error {NoAddress, NoPort};

pub fn init() !void {
	assert(sock == null);
	if (std.os.argv.len < 2) {
		return error.NoAddress;
	}

	// make struct sockaddr
	const ip = get_ip(std.os.argv[1]);
	addr = try net.Address.parseIp(
		ip,
		try get_port(std.os.argv[1] + ip.len), // you can do this in zig ??
	);
	std.debug.print("Connecting to {}:{}", .{ip, addr.getPort()});

	// socket and connect
	sock = try posix.socket(
		posix.AF.INET,
		posix.SOCK.DGRAM,
		posix.IPPROTO.UDP,
	);
	try posix.connect(sock.?, &addr.any, @sizeOf(addr));

	// open the file
	server = std.fs.File{
		.handle = sock.?,
	};
}

// parse command line arguments
// They should be in this format:
// skrr <ip>:<port>

fn get_ip(s: [*:0]const u8) []const u8 {
	var i: u8 = 0;
	while (s[i] != 0 and s[i] != ':') : (i += 1) {}
	return s[0..i];
}

// i is the index of the ':' in the ip
inline fn get_port(s: [*:0]const u8) !u16 {
	var i: u8 = 1;
	if (s[i] == 0) {
		return netArgsErrors.NoPort;
	}
	assert(s[i - 1] == ':');
	while (s[i] != 0) : (i += 1) {}
	return std.fmt.parseInt(u16, s[1..i], 10);
}
test "get_port" {
	const str: [*:0]const u8 = "127.0.0.1:12271";
	const ip = get_ip(str);
	std.debug.print(
		"{}\n",
		.{try get_port(str + ip.len)}
	);
}

// all public to interact with the server
