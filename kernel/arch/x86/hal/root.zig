const log = @import("klog").Logger;
const acpi = @import("./acpi.zig");
const apic = @import("./apic.zig");
const cpu = @import("../cpu/cpu.zig");
const smp = @import("../smp/root.zig");
const pic = @import("../interrupts/pic.zig");
const pit = @import("../pit.zig");

pub const ArchCpuData = struct {
    apic_id: u32,
    acpi_id: u32,
};

pub fn init_hardware(rsdp_addr: u64) void {
    pic.remap();
    pit.init(1000);
    log.info("Legacy PIC and PIT enabled!", .{});
    asm volatile ("sti");
    acpi.init(rsdp_addr);
    apic.parse_madt(acpi.get_madt_addr());
    log.info("Passed {d} ticks", .{pit.get_ticks()});
    apic.enable_lapic_timer();
    log.ok("Local APIC Timer enabled!", .{});
    smp.init();
}
