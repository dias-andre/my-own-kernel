const std = @import("std");
const arch = @import("arch");
const lib = @import("lib");

const COM1: u16 = 0x3F8;

pub fn putChar(c: u8) void {
    while (arch.io.read(COM1 + 5) & 0x20 == 0) {}
    arch.io.write(COM1, c);
}

pub fn print(str: []const u8) void {
    for (str) |c| {
        if (c == '\n') putChar('\r');
        putChar(c);
    }
}

const WriteFailed = error{};

pub const SerialWriter = struct {
    interface: std.Io.Writer,

    pub fn init() SerialWriter {
        return .{
            .interface = .{
                .buffer = &.{},
                .vtable = &.{
                    .drain = &drain,
                },
            },
        };
    }

    fn drain(w: *std.Io.Writer, data: []const []const u8, splat: usize) WriteFailed!usize {
        _ = splat;
        _ = w;
        const bytes = data[0];

        for (bytes) |byte| {
            arch.io.write(COM1, byte);
        }

        return bytes.len;
    }
};

pub fn getSerialWriter() SerialWriter {
    return SerialWriter.init();
}
