const arch = @import("arch");
const Io = @import("./io.zig");

const Writer = Io.Writer;
const FormatWriter = Io.FormatWriter;

pub const LoggerPort = struct {
    fw: FormatWriter,
    ptr: *anyopaque,

    const VTable = struct {
        info: *const fn (ctx: *anyopaque, comptime fmt: []const u8, args: anytype) void,
        debug: *const fn (ctx: *anyopaque, comptime fmt: []const u8, args: anytype) void,
        ok: *const fn (ctx: *anyopaque, comptime fmt: []const u8, args: anytype) void,
        spec: *const fn (ctx: *anyopaque, comptime fmt: []const u8, args: anytype) void,
        failed: *const fn (ctx: *anyopaque, comptime fmt: []const u8, args: anytype) void,
    };

    pub fn create(writer: Writer) LoggerPort {
        const fw = FormatWriter{ .inner = writer };
        return LoggerPort{ .fw = fw, .ptr = undefined };
    }

    pub fn info(self: *LoggerPort, comptime fmt: []const u8, args: anytype) void {
        self.printHeader("INFO");
        self.formatPrint(fmt, args);
    }

    pub fn debug(self: *LoggerPort, comptime fmt: []const u8, args: anytype) void {
        self.printHeader("TRCE");
        self.formatPrint(fmt, args);
    }

    pub fn ok(self: *LoggerPort, comptime fmt: []const u8, args: anytype) void {
        self.printHeader(" OK ");
        self.formatPrint(fmt, args);
    }

    pub fn spec(self: *LoggerPort, comptime fmt: []const u8, args: anytype) void {
        self.printHeader("SPEC");
        self.formatPrint(fmt, args);
    }

    pub fn failed(self: *LoggerPort, comptime fmt: []const u8, args: anytype) void {
        self.printHeader("FAIL");
        self.formatPrint(fmt, args);
    }

    pub fn println(self: *LoggerPort, comptime fmt: []const u8, args: anytype) void {
        self.formatPrint(fmt, args);
    }

    fn printHeader(self: *LoggerPort, comptime value: []const u8) void {
        self.fw.print("[ ");
        self.fw.print(value);
        self.fw.print(" ] ");
    }

    fn formatPrint(self: *LoggerPort, comptime fmt: []const u8, args: anytype) void {
        var i: usize = 0;
        inline for (args) |arg| {
            const start = i;
            while (i < fmt.len) : (i += 1) {
                if (fmt[i] == '{' and i + 1 < fmt.len and fmt[i + 1] == '}') {
                    break;
                }
            }
            self.fw.print(fmt[start..i]);

            self.printArg(arg);

            if (i < fmt.len) {
                i += 2;
            }
        }
        if (i < fmt.len) {
            self.fw.print(fmt[i..]);
        }
        self.fw.print("\n");
    }

    fn printArg(self: *LoggerPort, arg: anytype) void {
        const T = @TypeOf(arg);

        switch (@typeInfo(T)) {
            .int, .comptime_int => {
                self.fw.printDec(@intCast(arg));
            },

            .pointer => |ptr_info| {
                if (ptr_info.size == .slice and ptr_info.child == u8) {
                    self.fw.print(arg);
                } else {
                    self.fw.print("0x");
                    self.fw.printHex(@intFromPtr(arg));
                }
            },

            .bool => {
                if (arg) self.fw.print("true") else self.fw.print("false");
            },

            .optional => {
                if (arg) |val| {
                    self.printArg(val);
                } else {
                    self.fw.print("null");
                }
            },
            else => {
                self.fw.print("?");
            },
        }
    }
};
