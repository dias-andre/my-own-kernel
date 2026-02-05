const cpu = @import("cpu/cpu.zig");

pub fn write(port: u16, value: u8) void {
    cpu.outb(port, value);
}

pub fn read(port: u16) u8 {
    return cpu.inb(port);
}