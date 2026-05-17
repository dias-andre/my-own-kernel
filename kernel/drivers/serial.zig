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

fn writeSerial(_: *anyopaque, data: []const u8) void {
    print(data);
}

fn putCharSerial(_: *anyopaque, data: u8) void {
    putChar(data);
}

pub fn SerialWriter() lib.Io.Writer {
    return lib.Io.Writer{ .ptr = undefined, .vtable = &.{
        .write = writeSerial,
        .put = putCharSerial,
    } };
}
