const std = @import("std");
const arch = @import("../arch/root.zig");
const log = @import("../utils/klog.zig").Logger;

pub const pmm = @import("pmm.zig");
pub const vmm = @import("vmm.zig");
pub const heap = @import("./heap.zig");

var kheap: heap.Heap = undefined;
var kernel_page_directory: u64 = undefined;
var total_ram: usize = undefined;

pub fn init(kernel_end_addr: usize) void {
    log.info("Starting Memory Management Subsystem.", .{});
    pmm.init(kernel_end_addr);
    log.spec("Testing PMM allocation...", .{});
    
    const p1 = pmm.allocate_page();
    const p2 = pmm.allocate_page();
    if (p1) |addr| log.debug("PMM Alloc 1: {}", .{addr})
        else log.failed("PMM Alloc 1 FAILED (NULL)", .{});
    if (p2) |addr| log.debug("PMM Alloc 2: {}", .{addr})
        else log.failed("PMM Alloc 2 FAILED (NULL)", .{});

    pmm.free_page(p1.?);
    pmm.free_page(p2.?);
    log.ok("Physical Page Allocator working!", .{});
    arch.paging.set_physical_allocator(&pmm.allocate_page);
    vmm.init();
    kernel_page_directory = vmm.kernel_directory;
    log.debug("Kernel Page Directory: {}", .{kernel_page_directory});
    init_kernel_heap();
    log.ok("Memory Management Subsystem started successfully!", .{});
}

fn init_kernel_heap() void {
    log.info("Mapping kernel heap", .{});
    const HEAP_START: usize = 0x02000000;
    const HEAP_INITIAL_SIZE: usize = 4096;
    log.debug("Before init: start={}, size={}", .{HEAP_START, HEAP_INITIAL_SIZE});
    kheap = heap.Heap.init(HEAP_START, HEAP_INITIAL_SIZE, kernel_page_directory, Flags.DATA_KERNEL) catch {
        log.failed("Failed to initialize Kernel Heap", .{});
        while(true) arch.cpu.idle();
    };
    log.ok("Kernel heap mapped successfully!", .{});
}

pub fn kernel_allocator() std.mem.Allocator {
    return kheap.allocator();
}

pub fn kernel_pages() u64 {
    return kernel_page_directory;
}

pub const Flags = struct {
    pub const READABLE: usize = 1 << 0;
    pub const WRITABLE: usize = 1 << 1;
    pub const EXECUTABLE: usize = 1 << 2;
    pub const USER: usize = 1 << 3;
    pub const MMIO: usize = 1 << 4;

    pub const CODE_USER = READABLE | EXECUTABLE | USER;
    pub const DATA_USER = READABLE | WRITABLE | USER;
    pub const DATA_KERNEL = WRITABLE;
};