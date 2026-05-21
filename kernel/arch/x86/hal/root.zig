const log = @import("klog").Logger;
const acpi = @import("./acpi.zig");
const apic = @import("./apic.zig");
const cpu = @import("../cpu/cpu.zig");

pub const ArchCpuData = struct {
    apic_id: u32,
    acpi_id: u32,
};

pub fn init_hardware(rsdp_addr: u64) void {
    asm volatile ("cli");
    cpu.outb(0x21, 0xFF);
    cpu.outb(0xA1, 0xFF);
    log.debug("Legacy PIC disabled!", .{});
    acpi.init(rsdp_addr);
    apic.map(acpi.get_madt_addr());
    asm volatile ("sti");
}
