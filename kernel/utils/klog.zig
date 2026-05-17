const video = @import("../drivers/vga.zig");
const lib = @import("lib");
const serial = @import("../drivers/serial.zig");

const Writer = lib.Io.Writer;
const FormatWriter = lib.Io.FormatWriter;

pub var screen = video.VGA.init(80, 25, 0xb8000);

var vgaWriter = screen.writer();
var serialWriter = serial.SerialWriter();

fn writeLog(_: *anyopaque, data: []const u8) void {
    vgaWriter.write(data);
    serialWriter.write(data);
}

fn putLog(_: *anyopaque, data: u8) void {
    vgaWriter.put(data);
    serialWriter.put(data);
}

var multiWriter = lib.Io.Writer{ .ptr = undefined, .vtable = &.{
    .write = &writeLog,
    .put = &putLog,
} };

var formatWriter: lib.Io.FormatWriter = undefined;

var debugLogger: *LoggerPort = undefined;
var multiWriterLogger: *LoggerPort = undefined;

pub fn init() void {
    formatWriter = .{
        .inner = multiWriter,
    };
    debugLogger = LoggerPort.create(serialWriter);
    multiWriterLogger = LoggerPort.create(multiWriter);
}

pub const LoggerPort = struct {
    fw: lib.Io.FormatWriter,

    const VTable = struct {
        info: *const fn (ctx: *anyopaque, comptime fmt: []const u8, args: anytype) void,
        debug: *const fn (ctx: *anyopaque, comptime fmt: []const u8, args: anytype) void,
        ok: *const fn (ctx: *anyopaque, comptime fmt: []const u8, args: anytype) void,
        spec: *const fn (ctx: *anyopaque, comptime fmt: []const u8, args: anytype) void,
        failed: *const fn (ctx: *anyopaque, comptime fmt: []const u8, args: anytype) void,
    };

    pub fn create(writer: Writer) *LoggerPort {
        const fw = FormatWriter{ .inner = writer };
        return @constCast(&LoggerPort{ .fw = fw });
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
                    printArg(val);
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

pub const Logger = struct {
    pub fn info(comptime fmt: []const u8, args: anytype) void {
        printHeader("INFO", video.Color.Cyan);
        formatPrint(fmt, args);
        formatWriter.print("\n");
    }

    pub fn debug(comptime fmt: []const u8, args: anytype) void {
        printHeader("INFO", video.Color.LightGray);
        formatPrint(fmt, args);
        formatWriter.print("\n");
    }

    pub fn ok(comptime fmt: []const u8, args: anytype) void {
        printHeader(" OK ", video.Color.Green);
        formatPrint(fmt, args);
        formatWriter.print("\n");
    }

    pub fn spec(comptime fmt: []const u8, args: anytype) void {
        printHeader("TEST", video.Color.Blue);
        formatPrint(fmt, args);
        formatWriter.print("\n");
    }

    pub fn failed(comptime fmt: []const u8, args: anytype) void {
        printHeader("FAIL", video.Color.Red);
        formatPrint(fmt, args);
        formatWriter.print("\n");
    }

    pub fn println(comptime fmt: []const u8, args: anytype) void {
        formatWriter.print(" ");
        formatPrint(fmt, args);
        formatWriter.print("\n");
    }

    fn printHeader(text: []const u8, color: video.Color) void {
        formatWriter.print("[ ");
        screen.setColor(color, video.Color.Black);
        formatWriter.print(text);
        screen.setDefaultColor();
        formatWriter.print(" ] ");
    }

    fn formatPrint(comptime fmt: []const u8, args: anytype) void {
        var i: usize = 0;
        inline for (args) |arg| {
            const start = i;
            while (i < fmt.len) : (i += 1) {
                if (fmt[i] == '{' and i + 1 < fmt.len and fmt[i + 1] == '}') {
                    break;
                }
            }
            formatWriter.print(fmt[start..i]);

            printArg(arg);

            if (i < fmt.len) {
                i += 2;
            }
        }
        if (i < fmt.len) {
            formatWriter.print(fmt[i..]);
        }
    }

    fn printArg(arg: anytype) void {
        const T = @TypeOf(arg);

        switch (@typeInfo(T)) {
            .int, .comptime_int => {
                formatWriter.printDec(@intCast(arg));
            },

            .pointer => |ptr_info| {
                if (ptr_info.size == .slice and ptr_info.child == u8) {
                    formatWriter.print(arg);
                } else {
                    formatWriter.print("0x");
                    formatWriter.printHex(@intFromPtr(arg));
                }
            },

            .bool => {
                if (arg) formatWriter.print("true") else screen.print("false");
            },

            .optional => {
                if (arg) |val| {
                    printArg(val);
                } else {
                    formatWriter.print("null");
                }
            },
            else => {
                formatWriter.print("?");
            },
        }
    }
};
