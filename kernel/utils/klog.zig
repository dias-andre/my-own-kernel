const lib = @import("lib");
const video = @import("./vga.zig");
const serial = @import("./serial.zig");

const Writer = lib.Io.Writer;
const FormatWriter = lib.Io.FormatWriter;

pub const Logger = struct {
    var serialWriter = serial.SerialWriter();
    var mainLogger: lib.Logging.LoggerPort = undefined;

    pub fn init() void {
        mainLogger = lib.Logging.LoggerPort.create(serialWriter);
    }

    pub fn info(comptime fmt: []const u8, args: anytype) void {
        mainLogger.info(fmt, args);
    }

    pub fn debug(comptime fmt: []const u8, args: anytype) void {
        mainLogger.debug(fmt, args);
    }

    pub fn ok(comptime fmt: []const u8, args: anytype) void {
        mainLogger.ok(fmt, args);
    }

    pub fn spec(comptime fmt: []const u8, args: anytype) void {
        mainLogger.spec(fmt, args);
    }

    pub fn failed(comptime fmt: []const u8, args: anytype) void {
        mainLogger.failed(fmt, args);
    }

    pub fn println(comptime fmt: []const u8, args: anytype) void {
        mainLogger.println(fmt, args);
    }
};
