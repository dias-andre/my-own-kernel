const mb = @import("../multiboot.zig");
const log = @import("../utils/klog.zig").Logger;

pub const pmm = @import("./pmm.zig");
pub const vmm = @import("./vmm.zig");
pub const heap = @import("./heap.zig");

pub const HHDM_OFFSET = 0xFFFF800000000000;

pub var kheap: heap.Heap = undefined;
pub var kernel_page_directory: u64 = undefined;
pub var total_ram: usize = undefined;

pub fn init(mb_info: *mb.MultibootInfo, kernel_end_addr: usize) void {
    log.info("Starting Memory Management Subsystem.", .{});
    total_ram = pmm.init(mb_info, kernel_end_addr);
    vmm.init(total_ram);
    kernel_page_directory = @intFromPtr(vmm.kernel_pml4);
    init_kernel_heap();
    log.ok("Memory Management Subsystem started successfully!", .{});
}

fn init_kernel_heap() void {
    log.info("Mapping kernel heap", .{});
    log.println("-> Initial size: 1MB", .{});
    const HEAP_START: usize = 0x02000000;
    const HEAP_INITIAL_SIZE: usize = 1024 * 1024;
    kheap = heap.Heap.init(HEAP_START, HEAP_INITIAL_SIZE, kernel_page_directory, vmm.PAGE_PRESENT | vmm.PAGE_RW) catch |err| {
        switch (err) {
            error.NoPhysicalPages => {
                log.failed("No physical pages during kernel heap initialization!", .{});
            }
        }
        while(true) asm volatile("hlt");
    };
    log.ok("Kernel heap mapped successfully!", .{});
}

pub fn kmalloc(space: usize) ![]u8 {
    const allocated = try kheap.alloc(space);
    return allocated[0..space];
}

pub fn kfree(address: [*]u8) !void {
    try kheap.free(address);
}

pub fn create(comptime T: type) !*T {
    const raw_ptr = try kheap.alloc(@sizeOf(T));
    const addr = @intFromPtr(raw_ptr);
    
    if (addr % @alignOf(T) != 0) {
        return error.InvalidAlignment;
    }

    const ptr: *T = @ptrCast(@alignCast(raw_ptr));
    const temp_slice = raw_ptr[0..@sizeOf(T)];
    @memset(temp_slice, 0);
    return ptr;
}

pub fn map_addr(page_directory: usize, virt: usize, phys: usize, flags: usize) !void {
    const page: *vmm.PageTable = @ptrFromInt(page_directory);
    try vmm.map_page(page, virt, phys, flags);
}

pub fn alloc_physical_page() !usize {
    return try pmm.allocate_page();
}

pub fn free_physical_page(addr: usize) void {
    pmm.free_page(addr);
}

pub fn phys_to_virt(phys: usize) usize {
    return phys + HHDM_OFFSET;
}

pub fn virt_phys(virt: usize) usize {
    if(virt < HHDM_OFFSET) {
        return virt;
    }
    return virt - HHDM_OFFSET;
}

pub fn phys_to_ptr(comptime T: type, phys: usize) *T {
    return @ptrFromInt(phys_to_virt(phys));
}

pub fn clone_pml4(parent_pml4_phys: usize) !usize {
    const child_pml4_phys = try pmm.allocate_page();
    const parent_table = phys_to_ptr(vmm.PageTable, parent_pml4_phys);
    const child_table = phys_to_ptr(vmm.PageTable, child_pml4_phys);

    child_table.clear();
    for (0..512) |i| {
        const entry = parent_table.entries[i];

        if((entry & vmm.PAGE_PRESENT) == 0) continue;

        if(i >= 256) {
            child_table.entries[i] = entry;
        } else {
            const child_pdpt_phys = try clone_table(entry, 3);
            const flags = entry & ~vmm.PAGE_ADDR_MASK;
            child_table.entries[i] = child_pdpt_phys | flags;
        }
    }

    return child_pml4_phys;
}

fn clone_table(parent_entry: u64, level: u8) !usize {
    const parent_phys = parent_entry & vmm.PAGE_ADDR_MASK;
    const parent_table = phys_to_ptr(vmm.PageTable, parent_phys);

    const child_table_phys = try pmm.allocate_page();
    const child_table = phys_to_ptr(vmm.PageTable, child_table_phys);

    for(0..512) |i| {
        const entry = parent_table.entries[i];
        if ((entry & vmm.PAGE_PRESENT) == 0) continue;

        const flags = entry & ~vmm.PAGE_ADDR_MASK;
        if(level == 2) {
            const child_pt_phys = try clone_page_table(entry);
            child_table.entries[i] = child_pt_phys | flags;
        } else {
            const child_next_phys = try clone_table(entry, level - 1);
            child_table.entries[i] = child_next_phys | flags;
        }
    }
    return child_table_phys;
}

fn clone_page_table(parent_pt_entry: u64) !usize {
    const parent_pt_phys = parent_pt_entry & vmm.PAGE_ADDR_MASK;
    const parent_pt = phys_to_ptr(vmm.PageTable, parent_pt_phys);
    const child_pt_phys = try pmm.allocate_page();
    const child_pt = phys_to_ptr(vmm.PageTable, child_pt_phys);
    child_pt.clear();

    for(0..512) |i| {
        const entry = parent_pt.entries[i];
        if ((entry & vmm.PAGE_PRESENT) == 0) continue;

        const flags = entry & ~vmm.PAGE_ADDR_MASK;
        const parent_page_phys = entry & vmm.PAGE_ADDR_MASK;
        const child_page_phys = try pmm.allocate_page();
        const src_ptr = phys_to_ptr([4096]u8, parent_page_phys);
        const dst_ptr = phys_to_ptr([4096]u8, child_page_phys);

        @memcpy(dst_ptr, src_ptr);

        child_pt.entries[i] = child_page_phys | flags;
    }
    return child_pt_phys;
}