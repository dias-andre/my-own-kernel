const vga = @import("../vga.zig");
const vmm = @import("vmm.zig");
const pmm = @import("pmm.zig");

pub const BlockHeader = packed struct { size: usize, next: ?*BlockHeader, free: bool, magic: u32 };

pub const Heap = struct {
    head: *BlockHeader,
    pml4_phys: u64,
    end_addr: usize,

    pub fn init(start: usize, initial_size: usize, pml4_phys: u64, vmmFlags: usize) Heap {
        var current_virt = start;
        const end_virt = start + initial_size;
        const pml4: *vmm.PageTable = @ptrFromInt(pml4_phys);

        while (current_virt < end_virt) : (current_virt += 4096) {
            const phys = pmm.allocate_page() orelse {
                vga.printError("HEAP CRITICAL: OOM during heap start...");
                while (true) asm volatile ("hlt");
                unreachable;
            };

            vmm.map_page(pml4, current_virt, phys, vmmFlags);
        }

        const first_block: *BlockHeader = @ptrFromInt(start);
        first_block.size = initial_size - @sizeOf(BlockHeader);
        first_block.next = null;
        first_block.free = true;
        first_block.magic = 0xc0ffee;

        return Heap{
            .head = first_block,
            .pml4_phys = pml4_phys,
            .end_addr = end_virt
        };
    }

    pub fn alloc(self: *Heap, size: usize) ?[*]u8 {
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
                    const new_block_addr = @intFromPtr(current) + @sizeOf(BlockHeader) + aligned_size;
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

    pub fn free(_: *Heap, ptr: [*]u8) void {
        const addr = @intFromPtr(ptr);
        const header_addr = addr - @sizeOf(BlockHeader);
        const block: *BlockHeader = @ptrFromInt(header_addr);

        if (block.magic != 0xc0ffee) {
            vga.printError("HEAP CORRUPTION: Invalid pointer passed to free!");
            while (true) asm volatile ("hlt");
        }

        if (block.free) {
            vga.printError("DOUBLE FREE DETECTED: Block already freed!");
            while (true) asm volatile ("hlt");
        }

        if (block.next) |next_block| {
            if (next_block.free) {
                block.size += next_block.size + @sizeOf(BlockHeader);
                block.next = next_block.next;
            }
        }

        block.free = true;
    }
};
