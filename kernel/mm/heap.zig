const vga = @import("../vga.zig");
const vmm = @import("vmm.zig");
const pmm = @import("pmm.zig");

pub const BlockHeader = packed struct { size: usize, next: ?*BlockHeader, free: bool, magic: u32 };

pub fn alignUp(addr: usize, alignment: usize) usize {
    return (addr + alignment - 1) & ~(alignment - 1);
}

pub fn alignDown(addr: usize, alignment: usize) usize {
    return addr & ~(alignment - 1);
}

pub fn isAligned(addr: usize, alignment: usize) bool {
    return (addr & (alignment - 1)) == 0;
}

const HEADER_SIZE = alignUp(@sizeOf(BlockHeader), 16);

pub const Heap = struct {
    head: *BlockHeader,
    pml4_phys: u64,
    end_addr: usize,

    pub fn init(start: usize, initial_size: usize, pml4_phys: u64, vmmFlags: usize) !Heap {
        var current_virt = start;
        const end_virt = start + initial_size;
        const pml4: *vmm.PageTable = @ptrFromInt(pml4_phys);

        while (current_virt < end_virt) : (current_virt += 4096) {
            const phys = try pmm.allocate_page();

            try vmm.map_page(pml4, current_virt, phys, vmmFlags);
        }

        const first_block: *BlockHeader = @ptrFromInt(start);
        first_block.size = initial_size - HEADER_SIZE;
        first_block.next = null;
        first_block.free = true;
        first_block.magic = 0xc0ffee;

        return Heap{ .head = first_block, .pml4_phys = pml4_phys, .end_addr = end_virt };
    }

    pub fn allocAligned(self: *Heap, size: usize, alignment: usize) ![*]u8 {
        if (alignment == 0 or (alignment & (alignment - 1)) != 0) {
            return error.InvalidAlignment;
        }

        var current = self.head;

        while (true) {
            if (current.magic != 0xc0ffee) {
                vga.printError("HEAP CORRUPTION: Bad magic number!\n");
                vga.print("Block addr: 0x");
                vga.printHex(@intFromPtr(current));
                while (true) asm volatile ("hlt");
            }

            if (current.free) {
                const data_start = @intFromPtr(current) + @sizeOf(BlockHeader);
                const aligned_data = alignUp(data_start, alignment);
                const padding = aligned_data - data_start;
                const total_size = padding + size;

                if (current.size >= total_size) {
                    const space_needed_for_split = total_size + HEADER_SIZE + 16;
                    if (current.size >= space_needed_for_split) {
                        const new_block_addr = @intFromPtr(current) + HEADER_SIZE + total_size;
                        const new_block: *BlockHeader = @ptrFromInt(new_block_addr);
                        new_block.size = current.size - total_size - HEADER_SIZE;
                        new_block.free = true;
                        new_block.next = current.next;
                        new_block.magic = 0xc0ffee;

                        current.size = total_size;
                        current.next = new_block;
                    }
                    current.free = false;
                    return @ptrFromInt(aligned_data);
                }
            }

            if (current.next) |next_blk| {
                current = next_blk;
            } else {
                return error.OutOfMemory;
            }
        }
    }

    pub fn alloc(self: *Heap, size: usize) ![*]u8 {
        return try self.allocAligned(size, 16);
    }

    pub fn free(_: *Heap, ptr: [*]u8) !void {
        const addr = @intFromPtr(ptr);
        var search_addr = alignDown(addr - HEADER_SIZE, 16);
        const min_addr = search_addr -| 64;

        while (search_addr >= min_addr) : (search_addr -= 16) {
            const potential_header: *BlockHeader = @ptrFromInt(search_addr);
            if (potential_header.magic == 0xc0ffee) {
                const header_data_start = search_addr + @sizeOf(BlockHeader);
                const header_data_end = header_data_start + potential_header.size;

                if (addr >= header_data_start and addr < header_data_end) {
                    if (potential_header.free) {
                        return error.DoubleFree;
                    }
                    if (potential_header.next) |next_block| {
                        if (next_block.free) {
                            potential_header.size += next_block.size + HEADER_SIZE;
                            potential_header.next = next_block.next;
                        }
                    }

                    potential_header.free = true;
                    return;
                }
            }
        }
        return error.InvalidPointer;
    }
};
