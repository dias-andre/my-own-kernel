const acpi = @import("./acpi.zig");

pub fn init_hardware(rsdp_addr: u64) void {
    acpi.init(rsdp_addr);
}

