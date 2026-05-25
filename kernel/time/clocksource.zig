const std = @import("std");
const arch = @import("arch");

const TimerDescriptor = struct {
    clock_in_hz: u32,
    ticks_per_ms: u32,
    ticks: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),
};

var global_timer = TimerDescriptor{};

pub fn init(clock_in_hz: u32, ticks_per_ms: u32) void {
    global_timer.clock_in_hz = clock_in_hz;
    global_timer.ticks_per_ms = ticks_per_ms;
}

pub fn handle_timer_interrupt() void {
    _ = global_timer.ticks.fetchAdd(1, .monotonic);
}

pub fn get_ticks() u64 {
    return global_timer.ticks.load(.monotonic);
}

pub fn sleep_ms(ms: u64) void {
    const start = global_timer.ticks.load(.monotonic);
    const delay_ms = ms * global_timer.ticks_per_ms;
    while (true) {
        const now = global_timer.ticks.load(.monotonic);
        const elapsed = now -% start;
        if (elapsed >= delay_ms) {
            break;
        }
        arch.cpu.idle();
    }
}

pub fn sleep_us(us: u64) void {
    const start = global_timer.ticks.load(.monotonic);
    const delay_us = us * (global_timer.ticks_per_ms / 1000);
    while (true) {
        const now = global_timer.ticks.load(.monotonic);
        const elapsed = now -% start;
        if (elapsed >= delay_us) {
            break;
        }
        arch.cpu.idle();
    }
}
