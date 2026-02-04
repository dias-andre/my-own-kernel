pub const mb = @import("../multiboot.zig");

pub const PAGE_SIZE = 4096;
pub const MEMORY_OFFSET = 0xFFFF800000000000;

pub const MemoryRegion = struct {
    base: usize,
    len: usize,
    type: enum { Free, Reserved, Kernel }
};

pub const MemoryMap = struct {
    regions: [64]MemoryRegion = undefined,
    count: usize = 0
};

var total_ram: usize = 0;
var memory_regions_count: usize = 0;

var global_memory_map: MemoryMap = .{};

pub fn init(mb_info: *mb.MultibootInfo) void {
    init_memory_map(mb_info);
}

pub fn get_total_ram() usize {
    return total_ram;
}

pub fn memory_map() MemoryMap {
    return global_memory_map;
}

pub fn memory_regions() []MemoryRegion {
    return global_memory_map.regions[0..global_memory_map.count];
}

pub fn phys_to_virt(phys: usize) usize {
    return phys + MEMORY_OFFSET;
}

pub fn virt_to_phys(virt: usize) usize {
    if(virt < MEMORY_OFFSET) {
        return virt;
    }
    return virt - MEMORY_OFFSET;
}

pub fn phys_to_ptr(comptime T: type, phys: usize) *T {
    return @ptrFromInt(phys_to_virt(phys));
}

fn init_memory_map(mb_info: *const mb.MultibootInfo) void {
    var max_addr: usize = 0;

    var current_addr = mb_info.mmap_addr;
    const end_addr = mb_info.mmap_addr + mb_info.mmap_length;

    var i: usize = 0;
    while (current_addr < end_addr) : (i += 1) {
        var region = global_memory_map.regions[i];

        const entry_ptr: *align(1) const mb.MemoryMapEntry = @ptrFromInt(current_addr);
        const entry = entry_ptr.*;
        const potential_max = entry.addr + entry.len;

        region.base = entry.addr;
        region.len = entry.len;

        if (entry.type == 1 and potential_max > max_addr) {
            region.type = .Free;
            max_addr = potential_max;
        } else {
            region.type = .Reserved;
        }

        if (entry.size == 0) break;
        current_addr += entry.size + 4;
    }

    total_ram = max_addr;
}