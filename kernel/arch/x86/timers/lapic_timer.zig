const std = @import("std");
const log = @import("klog");
const apic = @import("../interrupts/apic.zig");
const pit = @import("./pit.zig");

pub fn enable() void {
    log.info("Enabling Local APIC timer...", .{});
    apic.write_reg(.spurious, 0x100 | 0xff);
    apic.write_reg(.timer_divide, 0x03);

    const max_u32 = std.math.maxInt(u32);
    apic.write_reg(.timer_initial_count, max_u32);
    pit.sleep_ms(10);
    const current_lapic_count = apic.read_reg(.timer_current_count);
    const ticks_per_ms = (max_u32 - current_lapic_count) / 10;
    log.println(" - {d} ticks/ms", .{ticks_per_ms});
    apic.write_reg(.lvt_timer, 0x20000 | 254);
    apic.write_reg(.timer_divide, 0x03);
    apic.write_reg(.timer_initial_count, ticks_per_ms);
    log.ok("Local APIC timer enabled for 1000Hz", .{});
}

pub fn send_eoi() void {
    apic.write_reg(.eoi, 0);
}
