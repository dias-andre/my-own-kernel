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
    total_ram = pmm.init(kernel_end_addr);
    vmm.init(total_ram);
    init_kernel_heap();
    log.ok("Memory Management Subsystem started successfully!", .{});
}

fn init_kernel_heap() void {
    log.info("Mapping kernel heap", .{});
    log.println("-> Initial size: 1MB", .{});
    const HEAP_START: usize = 0x02000000;
    const HEAP_INITIAL_SIZE: usize = 1024 * 1024;
    kheap = heap.Heap.init(HEAP_START, HEAP_INITIAL_SIZE, kernel_page_directory, vmm.Flags.DATA_KERNEL) catch {
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