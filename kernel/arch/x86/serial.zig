const io = @import("io.zig");
const COM1: u16 = 0x3F8;

pub fn putChar(c: u8) void {
    while (io.read(COM1 + 5) & 0x20 == 0) {}
    io.write(COM1, c);
}

pub fn print(str: []const u8) void {
    for (str) |c| {
        if (c == '\n') putChar('\r');
        putChar(c);
    }
}
