const vga = @import("../vga.zig");
const vmm = @import("vmm.zig");
const pmm = @import("pmm.zig");

pub const HEAP_START: usize = 0x02000000;
pub const HEAP_INITIAL_SIZE: usize = 1024 * 1024;

pub const BlockHeader = packed struct { size: usize, next: ?*BlockHeader, free: bool, magic: u32 };

pub const KernelHeap = struct {
    head: *BlockHeader,

    pub fn init() KernelHeap {
        vga.print("\n[HEAP] Initializing Kernel Heap...\n");

        var current_virt = HEAP_START;
        const end_virt = HEAP_START + HEAP_INITIAL_SIZE;
        const pml4 = vmm.kernel_pml4;

        while (current_virt < end_virt) : (current_virt += 4096) {
            const phys = pmm.allocate_page() orelse {
                vga.printError("HEAP CRITICAL: OOM during heap start...");
                while (true) asm volatile ("hlt");
                unreachable;
            };

            vmm.map_page(pml4, current_virt, phys, vmm.PAGE_PRESENT | vmm.PAGE_RW);
        }

        const first_block: *BlockHeader = @ptrFromInt(HEAP_START);
        first_block.size = HEAP_INITIAL_SIZE - @sizeOf(BlockHeader);
        first_block.next = null;
        first_block.free = true;
        first_block.magic = 0xc0ffee;
        vga.print("[HEAP] Created at 0x");
        vga.printHex(HEAP_START);
        vga.print(" (Size: 1MB)\n");

        return KernelHeap{
            .head = first_block,
        };
    }

    pub fn alloc(self: *KernelHeap, size: usize) ?[*]u8 {
        const aligned_size = (size + 7) & ~@as(usize, 7);
        var current = self.head;

        while (true) {
            if (current.magic != 0xc0ffee) {
                vga.printError("HEAP CORRUPTION: Bad magic number!");
                vga.print("Block Addr: 0x");
                vga.printHex(@intFromPtr(current));
                while (true) asm volatile ("hlt");
            }

            if (current.free and current.size >= aligned_size) {
                const space_needed_for_split = aligned_size + @sizeOf(BlockHeader) + 8;
                if (current.size >= space_needed_for_split) {
                    const new_block_addr = @intFromPtr(current) + @sizeOf(BlockHeader);
                    const new_block: *BlockHeader = @ptrFromInt(new_block_addr);

                    new_block.size = current.size - aligned_size - @sizeOf(BlockHeader);
                    new_block.free = true;
                    new_block.next = current.next;
                    new_block.magic = 0xc0ffee;

                    current.size = aligned_size;
                    current.next = new_block;
                }
                current.free = false;
                const data_ptr = @intFromPtr(current) + @sizeOf(BlockHeader);
                return @ptrFromInt(data_ptr);
            }
            if (current.next) |next_blk| {
                current = next_blk;
            } else {
                return null; // OOM (Out of Memory);
            }
        }
    }

    pub fn free(_: *KernelHeap, ptr: [*]u8) void {
        const addr = @intFromPtr(ptr);
        const header_addr = addr - @sizeOf(BlockHeader);
        const block: *BlockHeader = @ptrFromInt(header_addr);

        if (block.magic != 0xc0ffee) {
            vga.printError("HEAP CORRUPTION: Invalid pointer passed to free!");
            while(true) asm volatile("hlt");
        }

        if(block.free) {
            vga.printError("DOUBLE FREE DETECTED: Block alrady freed!");
            while(true) asm volatile("hlt");
        }
        if(block.next) |next_block| {
            block.size += next_block.size + @sizeOf(BlockHeader);
            block.next = next_block.next;
        }
        block.free = true;
    }
};
