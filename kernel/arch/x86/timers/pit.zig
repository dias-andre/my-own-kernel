const std = @import("std");
const khal = @import("khal");
const cpu = @import("../cpu/cpu.zig");
const pic = @import("../interrupts/pic.zig");

const BASE_FREQUENCY = 1193180;
const COMMAND_PORT = 0x43;
const DATA_PORT_0 = 0x40;

var tickCount = std.atomic.Value(u64).init(0);
var timer_enabled: bool = false;

pub fn init(freq: u32) void {
    const divisor = BASE_FREQUENCY / freq;
    cpu.outb(COMMAND_PORT, 0x36);

    const l = @as(u8, @truncate(divisor));
    const h = @as(u8, @truncate(divisor >> 8));

    cpu.outb(DATA_PORT_0, l);
    cpu.outb(DATA_PORT_0, h);
    timer_enabled = true;
}

pub fn handle_irq() void {
    _ = tickCount.fetchAdd(1, .monotonic);
    send_eoi();
}

fn implSleepMs(ptr: *anyopaque, ms: u64) void {
    const counter: *std.atomic.Value(u64) = @ptrCast(@alignCast(ptr));
    const start = counter.load(.monotonic);
    while (true) {
        const now = counter.load(.monotonic);
        const elapsed = now -% start;
        if (elapsed >= ms) {
            break;
        }
        asm volatile ("hlt");
    }
}

pub fn getTimerSource() khal.TimerSource {
    return .{
        .ptr = &tickCount,
        .vtable = &.{
            .implSleepMs = &implSleepMs,
            .implSleepUs = &implSleepUs,
        },
    };
}

pub fn implSleepUs(_: *anyopaque, _: u64) void {}

pub fn get_ticks() u64 {
    return tickCount.load(.monotonic);
}

pub fn send_eoi() void {
    pic.sendEOI(0);
}
