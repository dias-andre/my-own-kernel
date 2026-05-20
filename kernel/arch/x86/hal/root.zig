const acpi = @import("./acpi.zig");
const apic = @import("./apic.zig");

pub fn init_hardware(rsdp_addr: u64) void {
    acpi.init(rsdp_addr);
    apic.map(acpi.get_madt_addr());
}
