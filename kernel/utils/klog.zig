const lib = @import("lib");
const serial = lib.Serial;

pub const Logger = struct {
    var lock = lib.Atomic.Spinlock{};
    var serialWriter = serial.getSerialWriter();
    var mainLogger: lib.Logging.LoggerPort = undefined;

    pub fn init() void {
        mainLogger = lib.Logging.LoggerPort.create(&serialWriter.interface);
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
