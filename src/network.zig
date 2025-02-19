const std = @import("std");
const net = std.net;
const posix = std.posix;
const assert = std.debug.assert;

const PORT = 12271; // default port
var sock: ?posix.socket_t  = null; // client socket
var addr: net.Address = undefined; // server's address
var server: std.fs.File = undefined; // read and write to server's file.
var server_writer: std.fs.File.Writer = undefined; // read and write to server's file.

const netArgsErrors = error {NoAddress, NoPort};

pub fn init() !void {
	assert(sock == null); // stops init() from being called twice

	if (std.os.argv.len < 2) {
		return error.NoAddress;
	}

	// make struct sockaddr
	const ip = get_ip(std.os.argv[1]);
	addr = try net.Address.parseIp(
		ip,
		try get_port(std.os.argv[1] + ip.len), // you can do this in zig ??
	);
	std.debug.print("Connecting to {s}:{}\n", .{ip, addr.getPort()});

	// socket and connect
	sock = try posix.socket(
		posix.AF.INET,
		posix.SOCK.DGRAM,
		posix.IPPROTO.UDP,
	);
	errdefer posix.close(sock);
	try posix.connect(sock.?, &addr.any, @sizeOf(@TypeOf(addr)));

	// open the file
	server = std.fs.File{
		.handle = sock.?,
	};
	server_writer = server.writer();
}

pub fn deinit() void {
	assert(sock != null); // make sure deinit() is not called before init
	// posix.close(sock.?);
	server.close(); // will this close the server writer ???
}

// send player position
pub fn send_pos(x: f32, y: f32) !void {
	const pos: packed struct {
		x: f32,
		y: f32,
	} = .{.x = x, .y = y};
	try server_writer.writeStruct(pos);
}

// for now, singular get position, does not get the position of all the
// players, just one
pub fn recv_pos() struct{x: f32, y: f32} {
	var buf: [8]u8 = .{0} ** 8;
	const n = server.read(buf[0..]);
	assert(n == 8);

	// What the hell is this
	const x: f32 = @as(*f32, @alignCast(@ptrCast(&buf[0]))).*;
	const y: f32 = @as(*f32, @alignCast(@ptrCast(&buf[4]))).*;
	return .{.x = x, .y = y};
}
// Okay, I think I need to explain this ^
// We read from the socket into the buffer of 8 bytes
// then we cast the first 4 bytes and the last 4 bytes
// I'm dereferencing the *f32 we get immediately in the hopes that all this
// stuff stays in the registers so that alignment isn't broken.
var buffer: [1024]u8 = .{0} ** 1024;
pub fn recv_test() ![]u8 {
	const n = try server.read(buffer[0..]);
	return buffer[0..n];
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
