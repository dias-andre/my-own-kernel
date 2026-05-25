const arch = @import("arch");
const std = @import("std");
const klog = @import("klog");
const log = klog;

pub const pmm = @import("pmm.zig");
pub const vmm = @import("vmm.zig");
pub const heap = @import("heap.zig");
pub const mmap = @import("memory_map.zig");

var kheap: heap.Heap = undefined;
var kernel_page_directory: u32 = undefined;
var total_ram: usize = undefined;

pub fn init(kernel_end_addr: usize) void {
    log.info("Starting Memory Management Subsystem.", .{});
    pmm.init(kernel_end_addr);
    log.spec("Testing PMM allocation...", .{});

    const p1 = pmm.allocate_page();
    const p2 = pmm.allocate_page();
    if (p1) |addr| log.debug("PMM Alloc 1: {x}", .{addr}) else log.failed("PMM Alloc 1 FAILED (NULL)", .{});
    if (p2) |addr| log.debug("PMM Alloc 2: {x}", .{addr}) else log.failed("PMM Alloc 2 FAILED (NULL)", .{});

    pmm.free_page(p1.?);
    pmm.free_page(p2.?);
    log.ok("Physical Page Allocator working!", .{});
    arch.paging.set_physical_allocator(&pmm.allocate_page);
    vmm.init();
    kernel_page_directory = vmm.kernel_directory;
    init_kernel_heap();
    log.ok("Memory Management Subsystem started successfully!", .{});
}

fn init_kernel_heap() void {
    log.info("Mapping kernel heap", .{});
    const HEAP_START: usize = 0x02000000;
    const HEAP_INITIAL_SIZE: usize = 4096;
    log.debug("Before init: start=0x{x}, size={d}", .{ HEAP_START, HEAP_INITIAL_SIZE });
    kheap = heap.Heap.init(HEAP_START, HEAP_INITIAL_SIZE, kernel_page_directory, Flags.DATA_KERNEL) catch {
        log.failed("Failed to initialize Kernel Heap", .{});
        while (true) arch.cpu.idle();
    };
    log.ok("Kernel heap mapped successfully!", .{});
    log.spec("Testing kernel heap!", .{});
    const addr = kheap.alloc(4) catch {
        @panic("Failed to alloc 4 bytes on heap");
    };
    log.debug("Allocated heap memory at: 0x{x}", .{@intFromPtr(addr)});
    addr[0] = 23;
    log.println(" -> Block[0] = {d}", .{addr[0]});
    log.spec("Try free block with address: 0x{x}", .{@intFromPtr(addr)});
    kheap.free(addr) catch {
        @panic("Failed to free 4 bytes on heap");
    };
    log.debug("Block free passed!", .{});
    log.ok("Heap working!", .{});
}

pub fn kernel_allocator() std.mem.Allocator {
    return kheap.allocator();
}

pub fn kernel_pages() u64 {
    return kernel_page_directory;
}

pub fn get_page() ?usize {
    return pmm.allocate_page();
}

pub fn free_page(addr: usize) void {
    pmm.free_page(addr);
}

pub const Flags = struct {
    pub const READABLE: usize = 1 << 0;
    pub const WRITABLE: usize = 1 << 1;
    pub const EXECUTABLE: usize = 1 << 2;
    pub const USER: usize = 1 << 3;
    pub const MMIO: usize = 1 << 4;
    pub const NO_CACHE: usize = 1 << 5;

    pub const CODE_USER = READABLE | EXECUTABLE | USER;
    pub const DATA_USER = READABLE | WRITABLE | USER;
    pub const DATA_KERNEL = WRITABLE;
};
