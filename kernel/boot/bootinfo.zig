const uefi = @import("std").os.uefi;

pub const BootInfo = struct { map: [*]uefi.tables.MemoryDescriptor, map_size: usize, desc_size: usize, rsdp_addr: usize };
