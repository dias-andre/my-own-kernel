const arch = @import("../arch/root.zig");
const pmm = @import("pmm.zig");
const log = @import("../utils/klog.zig").Logger;

pub var is_paging_enabled: bool = false;
pub var kernel_directory: usize = undefined;

pub fn init(memory_size: usize) void {
    const page_phys = pmm.allocate_page() orelse  {
        log.failed("Failed to allocate physical pages during VMM start", .{});
        while(true) arch.cpu.idle();
    };
    arch.paging.clear_page_directory(page_phys);

    const aligned_limit = (memory_size + (arch.memory.PAGE_SIZE - 1)) & ~@as(usize, arch.memory.PAGE_SIZE - 1);

    // while(current_addr < aligned_limit) : (current_addr += arch.memory.PAGE_SIZE) {
    //     const flags = arch.paging.Flags.DATA_KERNEL;
    //     arch.paging.map(page_phys, current_addr, current_addr, flags) catch {
    //         log.failed("Failed to allocate physical page during VMM initialization", .{});
    //         while(true) arch.cpu.idle();
    //     };

    //     const virt_offset = current_addr + arch.memory.MEMORY_OFFSET;
    //     arch.paging.map(page_phys, virt_offset, current_addr, flags) catch {
    //         log.failed("Failed to allocate physical page during VMM initialization", .{});
    //         while(true) arch.cpu.idle();
    //     };
    // }

    map_range(page_phys, 0, 0, aligned_limit, Flags.DATA_KERNEL) catch {
        log.failed("Identity Map failed", .{});
        while (true) arch.cpu.idle();
    };

    const hh_start = arch.memory.MEMORY_OFFSET;
    map_range(page_phys, hh_start, 0, aligned_limit, Flags.DATA_KERNEL) catch {
        log.failed("Identity & Higher Half mapped", .{});
        while (true) arch.cpu.idle();
    };

    log.println("- Identity & Higher Half mapped (limit: {}MB)", .{aligned_limit / 1024 / 1024});
    log.println("- Loading page directory...", .{});
    arch.paging.load_page_directory(page_phys);
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

pub const Flags = struct {
    pub const READABLE: u32 = 1 << 0;
    pub const WRITABLE: u32 = 1 << 1;
    pub const EXECUTABLE: u32 = 1 << 2;
    pub const USER: u32 = 1 << 3;
    pub const MMIO: u32 = 1 << 4;

    pub const CODE_USER = READABLE | EXECUTABLE | USER;
    pub const DATA_USER = READABLE | WRITABLE | USER;
    pub const DATA_KERNEL = READABLE | WRITABLE;
};