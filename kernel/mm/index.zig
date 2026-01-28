const mb = @import("../multiboot.zig");
const vga = @import("../vga.zig");

pub const pmm = @import("./pmm.zig");
pub const vmm = @import("./vmm.zig");
pub const heap = @import("./heap.zig");

pub var kheap: heap.Heap = undefined;

pub fn init(mb_info: *mb.MultibootInfo, kernel_end_addr: usize) void {
    vga.print("\n[MM] Starting Memory Management Subsystem...\n");
    pmm.init(mb_info, kernel_end_addr);
    vmm.init();
    init_kernel_heap();
    vga.print("[MM] Memory Management initialized successfully.\n");
}

fn init_kernel_heap() void {
    vga.print("Initializing Kernel Heap\n");
    vga.print("-> Initial size: 1mb\n");
    const HEAP_START: usize = 0x02000000;
    const HEAP_INITIAL_SIZE: usize = 1024 * 1024;
    const pml4_phys: u64 = @intFromPtr(vmm.kernel_pml4);
    kheap = heap.Heap.init(HEAP_START, HEAP_INITIAL_SIZE, pml4_phys, vmm.PAGE_PRESENT | vmm.PAGE_RW);
}

pub fn kmalloc(space: usize) ![]u8 {
    return kheap.alloc(space);
}

pub fn kfree(address: [*]u8) void {
    kheap.free(address);
}

pub fn create(comptime T: type) ?*T {
    const slice = kheap.alloc(@sizeOf(T));
    const ptr: *T = @ptrCast(@alignCast(slice.ptr));
    @memset(slice, 0);
    return ptr;
}