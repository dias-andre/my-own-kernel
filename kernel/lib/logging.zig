const std = @import("std");
const arch = @import("arch");

pub const LoggerPort = struct {
    writer: *std.Io.Writer,

    pub fn create(writer: *std.Io.Writer) LoggerPort {
        return LoggerPort{
            .writer = writer,
        };
    }

    pub fn info(self: *LoggerPort, comptime fmt: []const u8, args: anytype) void {
        self.writer.writeAll("[ INFO ] ") catch @panic("Failed to print");
        self.writer.print(fmt, args) catch @panic("Failed to print");
        self.writer.writeAll("\n") catch @panic("Failed to print");
    }

    pub fn debug(self: *LoggerPort, comptime fmt: []const u8, args: anytype) void {
        self.writer.writeAll("[ TRCE ] ") catch @panic("Failed to print");
        self.writer.print(fmt, args) catch @panic("Failed to print");
        self.writer.writeAll("\n") catch @panic("Failed to print");
    }

    pub fn ok(self: *LoggerPort, comptime fmt: []const u8, args: anytype) void {
        self.writer.writeAll("[  OK  ] ") catch @panic("Failed to print");
        self.writer.print(fmt, args) catch @panic("Failed to print");
        self.writer.writeAll("\n") catch @panic("Failed to print");
    }

    pub fn spec(self: *LoggerPort, comptime fmt: []const u8, args: anytype) void {
        self.writer.writeAll("[ SPEC ] ") catch @panic("Failed to print");
        self.writer.print(fmt, args) catch @panic("Failed to print");
        self.writer.writeAll("\n") catch @panic("Failed to print");
    }

    pub fn failed(self: *LoggerPort, comptime fmt: []const u8, args: anytype) void {
        self.writer.writeAll("[ FAIL ] ") catch @panic("Failed to print");
        self.writer.print(fmt, args) catch @panic("Failed to print");
        self.writer.writeAll("\n") catch @panic("Failed to print");
    }

    pub fn println(self: *LoggerPort, comptime fmt: []const u8, args: anytype) void {
        self.writer.print(fmt, args) catch @panic("Failed to print");
        self.writer.writeAll("\n") catch @panic("Failed to print");
    }
};
