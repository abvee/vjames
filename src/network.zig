const std = @import("std");
const net = std.net;
const posix = std.posix;
const constants = @import("constants.zig");
const assert = std.debug.assert;
const stdout = std.io.getStdOut().writer();
// This file contains all the client side networking code. It is not
// responsible for how the networked data is draw, that is up to
// multiplayer.zig

const MAX_PLAYERS = constants.MAX_PLAYERS;
const PORT = 12271; // default port
const BIG_BOI = 2048; // big array number that will never overflow

var sock: ?posix.socket_t  = null; // client socket
var addr: net.Address = net.Address.initIp4(
	[4]u8{127,0,0,1},
	PORT,
); // server's default address
var server: std.fs.File = undefined; // read and write to server's file.
var server_writer: std.fs.File.Writer = undefined; // read and write to server's file.
var server_id: u8 = undefined; // id assigned by the server

// generic packet
pub const packet = packed struct {
	op: u8, // refer packet datasheet
	id: u8,
	x: f32,
	y: f32,
	angle: f32, // gun rotation angle

	pub inline fn isNewPlayerPacket(self: packet) bool {
		if (self.op == @intFromEnum(ops.NP_NPACK))
			return true;
		return false;
	}
	pub inline fn isPosPacket(self: packet) bool {
		if (self.op == @intFromEnum(ops.POS))
			return true;
		return false;
	}
};

const ops = enum(u8) {
	HELLO_HI = 0xff,
	NP_NPACK = 0xee, // new player
	POS = 0x00, // position of player
};

// init does the following things:
// sends HELLO pkt
// recieve HI pkt
// return HI pkt
pub fn init(allocator: std.mem.Allocator) ![]u8 {
	assert(sock == null); // stops init() from being called twice

	// set cmdline sockaddr
	if (std.os.argv.len < 2)
		stdout.print("No Address specified, using default\n", .{})
			catch {}
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

	stdout.print("Connecting to {}\n", .{addr}) catch {};

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
	try hello();

	// hi packet
	var hipkt: [BIG_BOI]u8 = [_]u8{0} ** BIG_BOI;
	const hipkt_len = try server.read(hipkt[0..]);

	assert(hipkt[0] == @intFromEnum(ops.HELLO_HI));
	std.debug.print("hipkt: {x}\n", .{hipkt[0..hipkt_len]});
	// TODO: make sure if we get another packet before the HI packet, we don't
	// shid ourselves. here we just assume it's the first packet the client
	// gets.

	// client id
	server_id = hipkt[1];
	stdout.print("Your id is {x}\n", .{server_id}) catch {};
	assert(server_id < MAX_PLAYERS);

	const hi: []u8 = try allocator.alloc(u8, hipkt_len);
	std.mem.copyForwards(u8, hi, hipkt[0..hipkt_len]);
	return hi;
}

inline fn hello() !void {
	const hello_packet: packet = packet{
		.op = 0xff,
		.id = 0,
		.x = 0,
		.y = 0,
		.angle = 0,
	};

	// TODO: send a username here
	try server_writer.writeStruct(hello_packet);
}

pub fn deinit() void {
	assert(sock != null); // make sure deinit() is not called before init
	// posix.close(sock.?);
	sock = null; // this will maybe be required when we want to reconnect
	server.close(); // will this close the server writer ???
}

// get another player's packets from the server
pub fn recv_packet() packet {

	// Due to alignment, this is 16 bytes
	var buf: [@bitSizeOf(packet)/8]u8 = .{0} ** (@bitSizeOf(packet)/8);

	// hence we need a recive buffer that's 13 bytes
	_ = server.read(&buf) catch {};
	// TODO: this is going to crash if we get an incomplete packet

	return @bitCast(buf);
}

pub fn send_pos(x: f32, y: f32, angle: f32) !void {
	const p: packet = packet{
		.op = @intFromEnum(ops.POS),
		.id = server_id,
		.x = x,
		.y = y,
		.angle = angle,
	};
	_ = try server.write(std.mem.asBytes(&p));
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
