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
    const parent_table_ptr = phys_to_virt(parent_pml4_phys);
    const child_table_ptr = phys_to_virt(child_pml4_phys);

    const parent_table: *vmm.PageTable = @ptrFromInt(parent_table_ptr);
    const child_table: *vmm.PageTable = @ptrFromInt(child_table_ptr);

    for (0..512) |i| {
        const entry = parent_table.entries[i];

        if((entry | vmm.PAGE_PRESENT) == 0) continue;

        if(i >= 256) {
            child_table.entries[i] = entry;
        } else {
            // chlid_table[i] = try clone_pdpt()
        }
    }
}