const arch = @import("../arch/root.zig");
const pmm = @import("pmm.zig");
const log = @import("../utils/klog.zig").Logger;
const Flags = @import("index.zig").Flags;

pub var is_paging_enabled: bool = false;
pub var kernel_directory: usize = undefined;

pub fn init() void {
    log.info("(VMM) Initializing Virtual Memory Management", .{});
    const memory_size = arch.memory.max_ram();
    const page_phys = pmm.allocate_page() orelse  {
        log.failed("Failed to allocate physical pages during VMM start", .{});
        while(true) arch.cpu.idle();
    };

    arch.paging.init_page_directory(page_phys);
    log.println("- Directory initialized!", .{});

    log.debug("VMM: Allocated page directory at phys: {}", .{@as(*u64, @ptrFromInt(page_phys))});
    log.debug("VMM: Is aligned? {}", .{page_phys % 4096});
    if((page_phys % arch.memory.PAGE_SIZE) != 0) @panic("VMM PANIC: Page phys not aligned!");

    const aligned_limit = (memory_size + (arch.memory.PAGE_SIZE - 1)) & ~@as(usize, arch.memory.PAGE_SIZE - 1);
    var current_addr: usize = 0;
    const flags = Flags.DATA_KERNEL;

    while(current_addr < aligned_limit) : (current_addr += arch.memory.PAGE_SIZE) {    
        arch.paging.map(page_phys, current_addr, current_addr, flags) catch {
            log.failed("Failed to allocate physical page during VMM initialization", .{});
            while(true) arch.cpu.idle();
        };

        const virt_offset = current_addr + arch.memory.MEMORY_OFFSET;
        arch.paging.map(page_phys, virt_offset, current_addr, flags) catch {
            log.failed("Failed to allocate physical page during VMM initialization", .{});
            while(true) arch.cpu.idle();
        };
    }

    log.println("- Identity & Higher Half mapped (limit: {}MB)", .{aligned_limit / 1024 / 1024});
    log.println("- Loading page directory...", .{});
    kernel_directory = page_phys;
    arch.paging.load_page_directory(page_phys);
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

