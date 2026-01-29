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
    const memory = kheap.alloc(64) orelse {
        vga.printError("[TEST] Failed to allocate kernel heap.\n");
        while(true) asm volatile("hlt");
    };
    const addr1 = @intFromPtr(memory);
    if(addr1 % 16 != 0) {
        vga.printError("[TEST] Failed to allocate memory aligned to 16 bytes");
        while(true) asm volatile("hlt");
    }
    memory[0] = 'c';
    
    const memoryB = kheap.alloc(16) orelse {
        vga.print("[TEST] Failed to allocate kernel heap.\n");
        while(true) asm volatile("hlt");
    };

    const addr2 = @intFromPtr(memoryB);
    if(addr2 % 16 != 0) {
        vga.printError("[TEST] Failed to allocate memory aligned to 16 bytes");
        while(true) asm volatile("hlt");
    }

    memoryB[1] = 'b';
    kheap.free(memory);
    kheap.free(memoryB);
    vga.print("=> Memory tests passed!\n");
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

pub fn kmalloc(space: usize) ?[]u8 {
    const allocated = kheap.alloc(space) orelse return null;
    return allocated[0..space];
}

pub fn kfree(address: [*]u8) void {
    kheap.free(address);
}

pub fn create(comptime T: type) ?*T {
    const raw_ptr = kheap.alloc(@sizeOf(T)) orelse return null;
    const addr = @intFromPtr(raw_ptr);
    
    if (addr % @alignOf(T) != 0) {
        vga.printError("Memória não alinhada ao alocar struct");
        while(true) asm volatile("hlt");
        return null;
    }

    const ptr: *T = @ptrCast(@alignCast(raw_ptr));
    const temp_slice = raw_ptr[0..@sizeOf(T)];
    @memset(temp_slice, 0);
    return ptr;
}