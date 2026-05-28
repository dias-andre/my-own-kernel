const log = @import("klog");
const acpi = @import("./acpi.zig");
const apic = @import("../interrupts/apic.zig");
const cpu = @import("../cpu/cpu.zig");
const smp = @import("../smp/root.zig");
const pic = @import("../interrupts/pic.zig");
const pit = @import("../timers/pit.zig");
const lapic_timer = @import("../timers/lapic_timer.zig");
const ktimer = @import("ktimer");

pub fn init(rsdp_addr: u64) void {
    log.info("Initializing Firmware Module...", .{});
    pit.init(1000); // 1000Hz
    acpi.init(rsdp_addr);
    apic.parse_madt(acpi.get_madt_addr());
    ktimer.setKernelTimer(pit.getTimerSource());
    log.info("Using PIT as kernel timer.", .{});
    log.info("Calibrating Local APIC timer...", .{});
    lapic_timer.calibrate();
    lapic_timer.enable();
    log.debug("Local APIC timer enabled!", .{});
    log.ok("Firmware Module initialized!", .{});
}
