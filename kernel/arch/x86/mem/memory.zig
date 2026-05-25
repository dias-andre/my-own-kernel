const uefi = @import("std").os.uefi;

const arch_mmap = @import("kmem").mmap;
const uefi_mem = @import("./uefi.zig");

pub const PAGE_SIZE = 4096;
pub const MEMORY_OFFSET = 0xFFFF800000000000;

pub const MemoryRegion = arch_mmap.MemoryRegion;
pub const MemoryMap = arch_mmap.MemoryMap;

var max_ram_address: usize = 0;
var memory_regions_count: usize = 0;

var global_memory_map: MemoryMap = .{};

pub fn init_from_uefi(map: [*]uefi.tables.MemoryDescriptor, map_size: usize, desc_size: usize) void {
    max_ram_address = uefi_mem.get_memory_map(&global_memory_map, map, map_size, desc_size);
}

pub fn max_ram() usize {
    return max_ram_address;
}

pub fn memory_map() *MemoryMap {
    return &global_memory_map;
}

pub fn memory_regions() []MemoryRegion {
    return global_memory_map.regions[0..global_memory_map.count];
}

pub fn phys_to_virt(phys: usize) usize {
    return phys + MEMORY_OFFSET;
}

pub fn virt_to_phys(virt: usize) usize {
    if (virt < MEMORY_OFFSET) {
        return virt;
    }
    return virt - MEMORY_OFFSET;
}

pub fn phys_to_ptr(comptime T: type, phys: usize) *T {
    return @ptrFromInt(phys_to_virt(phys));
}
