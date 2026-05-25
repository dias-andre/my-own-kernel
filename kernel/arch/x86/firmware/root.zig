const log = @import("klog");
const acpi = @import("./acpi.zig");
const apic = @import("../interrupts/apic.zig");
const cpu = @import("../cpu/cpu.zig");
const smp = @import("../smp/root.zig");
const pic = @import("../interrupts/pic.zig");
const pit = @import("../timers/pit.zig");
const lapic_timer = @import("../timers/lapic_timer.zig");

// pub const ArchCpuData = struct {
//     apic_id: u32,
//     acpi_id: u32,
// };

pub fn init(rsdp_addr: u64) void {
    log.info("Initializing Firmware Module...", .{});
    pic.remap();
    pit.init(1000);
    log.info("Legacy PIC and PIT enabled!", .{});
    asm volatile ("sti");
    acpi.init(rsdp_addr);
    apic.parse_madt(acpi.get_madt_addr());
    lapic_timer.enable();
    pic.disable();
    log.ok("Firmware Module initialized!", .{});
}
