const uefi = @import("std").os.uefi;
const mmap = @import("kmem").mmap;
const serial = @import("../serial.zig");

const MemoryRegion = mmap.MemoryRegion;
const MemoryMap = mmap.MemoryMap;
const MemoryKind = mmap.MemoryKind;

pub fn get_memory_map(global_map: *MemoryMap, map: [*]uefi.tables.MemoryDescriptor, map_size: usize, desc_size: usize) usize {
    var offset: usize = 0;
    const base_ptr = @as([*]u8, @ptrCast(map));
    var idx: usize = 0;
    var max_ram: usize = 0;

    while (offset < map_size) : (offset += desc_size) {
        if (idx >= global_map.regions.len) {
            serial.print("IDX reached regions limit!");
            break;
        }
        // const desc: *uefi.tables.MemoryDescriptor = @ptrFromInt(base_ptr + offset);
        const desc = @as(*align(1) uefi.tables.MemoryDescriptor, @ptrCast(base_ptr + offset));

        if (desc.number_of_pages == 0) continue;

        const kind: MemoryKind = switch (desc.type) {
            .conventional_memory => .Free,
            .boot_services_code, .boot_services_data => .Reserved,
            .loader_code, .loader_data => .Kernel,

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
        if (kind == .Free or kind == .Kernel) {
            const region_end = desc.physical_start + (desc.number_of_pages * 4096);
            if (region_end > max_ram) {
                max_ram = region_end;
            }
        }
        idx += 1;
    }
    global_map.count = idx;
    return max_ram;
}
