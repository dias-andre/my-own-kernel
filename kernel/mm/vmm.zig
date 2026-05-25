const arch = @import("arch");
const pmm = @import("pmm.zig");
const log = @import("klog");
const Flags = @import("root.zig").Flags;
const mmap = @import("./memory_map.zig");

pub var is_paging_enabled: bool = false;
pub var kernel_directory: u32 = undefined;

pub fn init() void {
    log.info("(VMM) Initializing Virtual Memory Management", .{});
    const memory_map = arch.memory.memory_map();
    const phys_page_dir = pmm.allocate_page() orelse {
        @panic("Failed to allocate physical page to create page directory.");
    };
    arch.paging.init_page_directory(phys_page_dir);
    log.debug("Page directory initialized!", .{});
    log.debug("VMM: Allocated page directory at physical address: 0x{x}", .{phys_page_dir});
    log.debug("VMM: Is aligned? {any}", .{phys_page_dir % arch.memory.PAGE_SIZE == 0});
    if ((phys_page_dir % arch.memory.PAGE_SIZE) != 0) @panic("VMM -> Page phys not aligned!");

    var idx: usize = 0;
    const flags = Flags.DATA_KERNEL;
    log.debug("Start mapping pages", .{});
    for (memory_map.regions) |region| {
        if (idx >= memory_map.count) break;
        if (region.type == .BadMemory) continue;

        var current_addr: usize = region.base;
        while (current_addr < (region.base + region.len)) : (current_addr += arch.memory.PAGE_SIZE) {
            // Identity Mapping
            arch.paging.map(phys_page_dir, current_addr, current_addr, flags) catch
                @panic("Failed to map page for Identity Mapping!");

            const virt_offset = current_addr + arch.memory.MEMORY_OFFSET;
            arch.paging.map(phys_page_dir, virt_offset, current_addr, flags) catch
                @panic("Failed to map page for higher half mapping!");
        }

        idx += 1;
    }
    log.debug("Regions mapped {d}", .{idx});
    kernel_directory = @intCast(phys_page_dir);
    log.debug("Loading page directory...", .{});
    arch.paging.load_page_directory(kernel_directory);
    arch.paging.set_paging_enabled();
    log.ok("(VMM) Virtual Memory Manager initialized successfully!", .{});
}

fn map_range(root: usize, virt_start: usize, phys_start: usize, size: usize, flags: u32) !void {
    var virt = virt_start;
    var phys = phys_start;
    const end = virt_start + size;

    while (virt < end) {
        try arch.paging.map(root, virt, phys, flags);

        virt += arch.memory.PAGE_SIZE;
        phys += arch.memory.PAGE_SIZE;
    }
}
