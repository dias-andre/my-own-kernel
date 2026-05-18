const uefi = @import("std").os.uefi;

const arch_mmap = @import("kmem").mmap;
const serial = @import("../serial.zig");

const MemoryRegion = arch_mmap.MemoryRegion;
const MemoryMap = arch_mmap.MemoryMap;
const MemoryKind = arch_mmap.MemoryKind;

pub fn get_memory_map(global_map: *MemoryMap, map: [*]uefi.tables.MemoryDescriptor, map_size: usize, desc_size: usize) usize {
    var offset: usize = 0;
    const base_ptr = @as([*]u8, @ptrCast(map));
    var idx: usize = 0;
    var max_ram: usize = 0;

    while (offset < map_size) : (offset += desc_size) {
        if (idx >= 64) {
            serial.print("IDX reached 64!\n");
            break;
        }
        // const desc: *uefi.tables.MemoryDescriptor = @ptrFromInt(base_ptr + offset);
        const desc = @as(*align(1) uefi.tables.MemoryDescriptor, @ptrCast(base_ptr + offset));

        if (desc.number_of_pages == 0) continue;

        const kind: MemoryKind = switch (desc.type) {
            .conventional_memory => .Free,
            .boot_services_code, .boot_services_data => .Free,
            .loader_code, .loader_data => .Free,

            .acpi_reclaim_memory => .Reserved,
            .acpi_memory_nvs => .Reserved,
            .unusable_memory => .BadMemory,
            else => .Reserved,
        };
        var region = &global_map.regions[idx];
        region.base = desc.physical_start;
        region.type = kind;
        region.page_count = desc.number_of_pages;
        region.len = desc.number_of_pages * 4096;

        const region_end = desc.physical_start + (desc.number_of_pages * 4096);
        if (region_end > max_ram) {
            max_ram = region_end;
        }
        idx += 1;
    }
    global_map.count = idx;
    return max_ram;
}
