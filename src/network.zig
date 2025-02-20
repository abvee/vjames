const std = @import("std");
const net = std.net;
const posix = std.posix;
const assert = std.debug.assert;
const stdout = std.io.getStdOut().writer();

const PORT = 12271; // default port
var sock: ?posix.socket_t  = null; // client socket
var addr: net.Address = net.Address.initIp4(
	[4]u8{127,0,0,1},
	PORT,
); // default server's address
var server: std.fs.File = undefined; // read and write to server's file.
var server_writer: std.fs.File.Writer = undefined; // read and write to server's file.

pub fn init() !void {
	assert(sock == null); // stops init() from being called twice

	// set cmdline sockaddr
	if (std.os.argv.len < 2)
		try stdout.print("No Address specified, using default\n", .{})
	else {
		const ip = get_ip(std.os.argv[1]);
		addr = try net.Address.parseIp(
			ip,
			get_port(std.os.argv[1] + ip.len)
				catch |err| switch (err) {
					netArgsErrors.NoPort => PORT,
					else => return err,
				},
		);
	}

	std.debug.print("Connecting to {}\n", .{addr});

	// socket and connect
	sock = try posix.socket(
		posix.AF.INET,
		posix.SOCK.DGRAM,
		posix.IPPROTO.UDP,
	);
	errdefer posix.close(sock.?);
	try posix.connect(
		sock.?,
		&addr.any,
		addr.getOsSockLen(),
	);

	// open the file
	server = std.fs.File{
		.handle = sock.?,
	};
	server_writer = server.writer();

	// send hello and wait for hi
	// hello();
}

// generic packet
const Packet = packed struct {
	x: f32,
	y: f32,
};
// generally used for position data, hence the .x and .y fields
// The hello and hi packets are all filled with 1s

pub fn deinit() void {
	assert(sock != null); // make sure deinit() is not called before init
	// posix.close(sock.?);
	server.close(); // will this close the server writer ???
}

// send player position
pub fn send_pos(x: f32, y: f32) !void {
	const pos: Packet = Packet{.x = x, .y = y};
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

const netArgsErrors = error{NoPort};

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
