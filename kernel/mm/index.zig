const mb = @import("../multiboot.zig");
const log = @import("../utils/klog.zig").Logger;

pub const pmm = @import("./pmm.zig");
pub const vmm = @import("./vmm.zig");
pub const heap = @import("./heap.zig");

pub var kheap: heap.Heap = undefined;

pub fn init(mb_info: *mb.MultibootInfo, kernel_end_addr: usize) void {
    log.info("Starting Memory Management Subsystem.", .{});
    pmm.init(mb_info, kernel_end_addr);
    vmm.init();
    init_kernel_heap();
    log.ok("Memory Management Subsystem started successfully!", .{});
}

fn init_kernel_heap() void {
    log.info("Mapping kernel heap", .{});
    log.println("-> Initial size: 1MB", .{});
    const HEAP_START: usize = 0x02000000;
    const HEAP_INITIAL_SIZE: usize = 1024 * 1024;
    const pml4_phys: u64 = @intFromPtr(vmm.kernel_pml4);
    kheap = heap.Heap.init(HEAP_START, HEAP_INITIAL_SIZE, pml4_phys, vmm.PAGE_PRESENT | vmm.PAGE_RW) catch |err| {
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