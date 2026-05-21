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
        lock.acquire();
        mainLogger = lib.Logging.LoggerPort.create(serialWriter);
        lock.release();
    }

    pub fn info(comptime fmt: []const u8, args: anytype) void {
        lock.acquire();
        mainLogger.info(fmt, args);
        lock.release();
    }

    pub fn debug(comptime fmt: []const u8, args: anytype) void {
        lock.acquire();
        mainLogger.debug(fmt, args);
        lock.release();
    }

    pub fn ok(comptime fmt: []const u8, args: anytype) void {
        lock.acquire();
        mainLogger.ok(fmt, args);
        lock.release();
    }

    pub fn spec(comptime fmt: []const u8, args: anytype) void {
        lock.acquire();
        mainLogger.spec(fmt, args);
        lock.release();
    }

    pub fn failed(comptime fmt: []const u8, args: anytype) void {
        lock.acquire();
        mainLogger.failed(fmt, args);
        lock.release();
    }

    pub fn println(comptime fmt: []const u8, args: anytype) void {
        lock.acquire();
        mainLogger.println(fmt, args);
        lock.release();
    }
};
