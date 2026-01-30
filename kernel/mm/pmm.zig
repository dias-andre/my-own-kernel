const mb = @import("../multiboot.zig");
const log = @import("../utils/klog.zig").Logger;

pub const PAGE_SIZE: usize = 4096;

var bitmap: [*]u8 = undefined;
var bitmap_size: usize = 0;
var max_phys_addr: usize = 0;
var total_pages: usize = 0;
var free_memory_start: usize = 0;

fn set_bit(bit: usize) void {
    bitmap[bit / 8] |= @as(u8, 1) << @intCast(bit % 8);
}

fn clear_bit(bit: usize) void {
    const mask = @as(u8, 1) << @intCast(bit % 8);
    bitmap[bit / 8] &= ~mask;
}

fn test_bit(bit: usize) bool {
    return (bitmap[bit / 8] & (@as(u8, 1) << @intCast(bit % 8))) != 0;
}

fn align_up(addr: usize) usize {
    if (addr % PAGE_SIZE == 0) return addr;
    return (addr + PAGE_SIZE) - (addr % PAGE_SIZE);
}

pub fn init(mb_info: *const mb.MultibootInfo, kernel_end: usize) void {
    log.info("(PMM) Initializing physical memory manager...", .{});

    max_phys_addr = calculateTotalMemory(mb_info);
    total_pages = max_phys_addr / PAGE_SIZE;

    bitmap_size = total_pages / 8;

    const bitmap_phys_addr = align_up(kernel_end);
    bitmap = @ptrFromInt(bitmap_phys_addr);

    // DEBUG INFO
    log.println("- Total RAM: {}mb", .{max_phys_addr / 1024 / 1024});
    log.println("- Bitmap size: {} bytes", .{bitmap_size});

    // Security: mark all as used (memset 0xFF)
    fill_memory(bitmap, 0xff, bitmap_size);

    // nows, read multiboot info and mark only available regions
    var current_addr = mb_info.mmap_addr;
    const end_addr = mb_info.mmap_addr + mb_info.mmap_length;

    var i: usize = 0;
    while (current_addr < end_addr) : (i += 1) {
        if (current_addr + @sizeOf(mb.MemoryMapEntry) > end_addr) break;

        const entry_ptr: *align(1) const mb.MemoryMapEntry = @ptrFromInt(current_addr);
        const entry = entry_ptr.*;

        // available memory (type = 1)
        if (entry.type == 1) {
            init_region(entry.addr, entry.len);
        }

        if (entry.size == 0) break;
        current_addr += entry.size + 4;
    }

    const final_reserved_addr = bitmap_phys_addr + bitmap_size;
    deinit_region(0, final_reserved_addr);

    log.ok("(PMM) Done! ", .{});
}

fn init_region(base: u64, length: u64) void {
    var page_idx = base / PAGE_SIZE;
    const page_count = length / PAGE_SIZE;
    var i: usize = 0;
    while (i < page_count) : (i += 1) {
        clear_bit(page_idx);
        page_idx += 1;
    }
}

fn deinit_region(base: u64, length: u64) void {
    var page_idx = base / PAGE_SIZE;
    const page_count = (length + PAGE_SIZE - 1) / PAGE_SIZE;
    var i: usize = 0;
    while (i < page_count) : (i += 1) {
        set_bit(page_idx);
        page_idx += 1;
    }
}

fn calculateTotalMemory(mb_info: *const mb.MultibootInfo) usize {
    var max_addr: usize = 0;

    var current_addr = mb_info.mmap_addr;
    const end_addr = mb_info.mmap_addr + mb_info.mmap_length;

    var i: usize = 0;
    while (current_addr < end_addr) : (i += 1) {
        const entry_ptr: *align(1) const mb.MemoryMapEntry = @ptrFromInt(current_addr);
        const entry = entry_ptr.*;
        const potential_max = entry.addr + entry.len;

        if (entry.type == 1 and potential_max > max_addr) {
            max_addr = potential_max;
        }

        if (entry.size == 0) break;
        current_addr += entry.size + 4;
    }

    return max_addr;
}

fn fill_memory(ptr: [*]u8, value: u8, len: usize) void {
    var i: usize = 0;
    while (i < len) : (i += 1) {
        ptr[i] = value;
    }
}

pub fn allocate_page() !usize {
    var i: usize = 0;
    while (i < total_pages) : (i += 1) {
        if (!test_bit(i)) {
            set_bit(i);
            return i * PAGE_SIZE;
        }
    }
    return error.NoPhysicalPages;
}

pub fn free_page(addr: usize) void {
    const page_idx = addr / PAGE_SIZE;
    if (page_idx < total_pages) {
        clear_bit(page_idx);
    }
}