const lib = @import("lib");
const serial = @import("./serial.zig");

const Writer = lib.Io.Writer;
const FormatWriter = lib.Io.FormatWriter;

pub fn createSerialLogger() lib.Logging.LoggerPort {
    return .{
        .ptr = undefined,
        .fw = .{
            .inner = serial.SerialWriter(),
        },
    };
}

pub const Logger = struct {
    var lock = lib.Atomic.Spinlock{};
    var serialWriter = serial.SerialWriter();
    var mainLogger: lib.Logging.LoggerPort = undefined;

    pub fn init() void {
        mainLogger = lib.Logging.LoggerPort.create(serialWriter);
    }

    pub fn info(comptime fmt: []const u8, args: anytype) void {
        lock.acquire();
        defer lock.release();
        mainLogger.info(fmt, args);
    }

    pub fn debug(comptime fmt: []const u8, args: anytype) void {
        lock.acquire();
        defer lock.release();
        mainLogger.debug(fmt, args);
    }

    pub fn ok(comptime fmt: []const u8, args: anytype) void {
        lock.acquire();
        defer lock.release();
        mainLogger.ok(fmt, args);
    }

    pub fn spec(comptime fmt: []const u8, args: anytype) void {
        lock.acquire();
        defer lock.release();
        mainLogger.spec(fmt, args);
    }

    pub fn failed(comptime fmt: []const u8, args: anytype) void {
        lock.acquire();
        defer lock.release();
        mainLogger.failed(fmt, args);
    }

    pub fn println(comptime fmt: []const u8, args: anytype) void {
        lock.acquire();
        defer lock.release();
        mainLogger.println(fmt, args);
    }
};
