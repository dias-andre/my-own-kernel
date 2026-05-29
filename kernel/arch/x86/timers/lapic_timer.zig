const sched = @import("sched");
const std = @import("std");
const log = @import("klog");
const khal = @import("khal");
const ksmp = @import("smp");
const ktimer = @import("ktimer");
const apic = @import("../interrupts/apic.zig");

var ticks_per_ms: u32 = undefined;

pub fn calibrate() void {
    apic.write_reg(.spurious, 0x100 | 0xff);
    apic.write_reg(.timer_divide, 0x03);
    const max_u32 = std.math.maxInt(u32);
    apic.write_reg(.timer_initial_count, max_u32);
    ktimer.sleep_ms(10);
    const current_lapic_count = apic.read_reg(.timer_current_count);
    ticks_per_ms = (max_u32 - current_lapic_count) / 10;
    log.debug("Local APIC Timer: {d} ticks/ms", .{ticks_per_ms});
}

pub fn enable() void {
    apic.write_reg(.lvt_timer, 0x20000 | 254);
    apic.write_reg(.timer_divide, 0x03);
    apic.write_reg(.timer_initial_count, ticks_per_ms); // 1000Hz
}

pub fn implSleepMs(ptr: *anyopaque, ms: u64) void {
    const ticks: *std.atomic.Value(u64) = @ptrCast(@alignCast(ptr));
    const start = ticks.load(.monotonic);
    while (true) {
        const now = ticks.load(.monotonic);
        const elapsed = now -% start;

        if (elapsed >= ms) {
            break;
        }
        asm volatile ("hlt");
    }
}

pub fn implSleepUs(_: *anyopaque, _: u64) void {}

pub fn getLAPIC_TimerSource(tickPtr: *std.atomic.Value(u64)) khal.TimerSource {
    return .{
        .ptr = tickPtr,
        .vtable = &.{
            .implSleepMs = &implSleepMs,
            .implSleepUs = &implSleepUs,
        },
    };
}

pub fn handle_interrupt() void {
    const current_core = ksmp.get_current_core();
    _ = current_core.tickCount.fetchAdd(1, .monotonic);
    sched.schedule(current_core);
    apic.write_reg(.eoi, 0);
}
