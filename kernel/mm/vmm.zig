const arch = @import("arch");
const pmm = @import("pmm.zig");
const log = @import("klog");
const Flags = @import("root.zig").Flags;
const mmap = @import("./memory_map.zig");

var is_paging_enabled: bool = false;
var kernel_directory: u32 = undefined;
var virtual_kernel_directory: usize = undefined;

extern var kernel_vma_start: u8;
extern var kernel_vma_end: u8;

export var kernel_stack: [16384]u8 align(16) = undefined;

pub fn init(kernel_phys: usize) void {
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
            if (current_addr < 0x100000) {
                arch.paging.map(phys_page_dir, current_addr, current_addr, flags) catch
                    @panic("Failed to map page for Identity Mapping!");
            }

            const virt_offset = current_addr + arch.memory.MEMORY_OFFSET;
            arch.paging.map(phys_page_dir, virt_offset, current_addr, flags) catch
                @panic("Failed to map page for higher half mapping!");
        }

        idx += 1;
    }

    log.debug("Regions mapped {d}", .{idx});
    log.info("Mapping Kernel Virtual Memory...", .{});
    mapKernelVma(kernel_phys, phys_page_dir, flags) catch @panic("Failed to map Kernel Virtual Memory!");
    log.ok("Kernel Virtual Memory mapped!", .{});
    log.debug("Loading page directory...", .{});
    kernel_directory = @intCast(phys_page_dir);
    virtual_kernel_directory = phys_page_dir + arch.memory.MEMORY_OFFSET;
    arch.paging.load_page_directory(kernel_directory);
    arch.paging.set_paging_enabled();
    log.ok("(VMM) Virtual Memory Manager initialized successfully!", .{});
}

pub fn get_phys_kernel_dir() u32 {
    return kernel_directory;
}

pub fn get_virtual_kernel_dir() usize {
    return virtual_kernel_directory;
}

fn mapKernelVma(kernel_phys: usize, page_dir: usize, flags: usize) !void {
    const v_start = @intFromPtr(&kernel_vma_start);
    const v_end = @intFromPtr(&kernel_vma_end);
    const p_start = kernel_phys;
    // const kernel_size = v_end - v_start;
    // const p_end = p_start + kernel_size;
    // log.println(" VMA Start: 0x{x}, VMA End: 0x{x}", .{ v_start, v_end });
    // log.println(" LMA Start: 0x{x}, LMA End: 0x{x}", .{ p_start, p_end });
    // log.println(" Kernel Size: {d} bytes", .{kernel_size});

    var vaddr = v_start;
    var paddr = p_start;
    while (vaddr < v_end) : ({
        vaddr += arch.memory.PAGE_SIZE;
        paddr += arch.memory.PAGE_SIZE;
    }) {
        try arch.paging.map(page_dir, vaddr, paddr, flags);
    }
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
