const cpu = @import("cpu/cpu.zig");
const pic = @import("interrupts/pic.zig");

const BASE_FREQUENCY = 1193180;
const COMMAND_PORT = 0x43;
const DATA_PORT_0 = 0x40;

var ticks: u64 = 0;
var handler: *const fn () void = undefined;

pub fn init(freq: u32, func: *const fn () void) void {
    const divisor = BASE_FREQUENCY / freq;
    cpu.outb(COMMAND_PORT, 0x36);

    const l = @as(u8, @truncate(divisor));
    const h = @as(u8, @truncate(divisor >> 8));

    cpu.outb(DATA_PORT_0, l);
    cpu.outb(DATA_PORT_0, h);
    handler = func;
}

pub fn handle_irq() void {
    ticks += 1;
}

pub fn get_ticks() u64 {
    return ticks;
}
