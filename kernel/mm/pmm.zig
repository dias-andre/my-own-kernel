const log = @import("klog").Logger;
const arch = @import("arch");
const MemoryMap = @import("./memory_map.zig").MemoryMap;

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
    if (addr % arch.memory.PAGE_SIZE == 0) return addr;
    return (addr + arch.memory.PAGE_SIZE) - (addr % arch.memory.PAGE_SIZE);
}

pub fn init(kernel_end: usize) void {
    log.info("(PMM) Initializing physical memory manager...", .{});
    const memory_map = arch.memory.memory_map();
    total_pages = arch.memory.max_ram() / arch.memory.PAGE_SIZE;

    bitmap_size = (total_pages + 7) / 8;

    const bitmap_phys_addr = align_up(kernel_end);
    bitmap = @ptrFromInt(bitmap_phys_addr);

    // DEBUG INFO
    log.debug("- Total RAM: {}", .{arch.memory.max_ram()});
    log.debug("- Bitmap size: {} bytes", .{bitmap_size});
    log.debug("- Regions count: {}", .{memory_map.count});
    log.debug("- Total pages: {}", .{total_pages});

    // @memset
    fill_memory(bitmap, 0xff, bitmap_size);
    for (memory_map.regions[0..memory_map.count]) |region| {
        if (region.type == .Free) {
            init_region(region.base, region.len);
        }
    }

    const final_reserved_addr = bitmap_phys_addr + bitmap_size;
    deinit_region(0, final_reserved_addr);

    log.ok("(PMM) Done! ", .{});
}

fn init_region(base: u64, length: u64) void {
    var page_idx = base / arch.memory.PAGE_SIZE;
    const page_count = length / arch.memory.PAGE_SIZE;
    var i: usize = 0;
    while (i < page_count) : (i += 1) {
        clear_bit(page_idx);
        page_idx += 1;
    }
}

fn deinit_region(base: u64, length: u64) void {
    var page_idx = base / arch.memory.PAGE_SIZE;
    const page_count = (length + arch.memory.PAGE_SIZE - 1) / arch.memory.PAGE_SIZE;
    var i: usize = 0;
    while (i < page_count) : (i += 1) {
        set_bit(page_idx);
        page_idx += 1;
    }
}

fn fill_memory(ptr: [*]u8, value: u8, len: usize) void {
    var v_ptr: [*]volatile u8 = ptr;
    var i: usize = 0;
    while (i < len) : (i += 1) {
        v_ptr[i] = value;
    }
}

pub fn allocate_page() ?usize {
    var i: usize = 0;
    while (i < total_pages) : (i += 1) {
        if (!test_bit(i)) {
            set_bit(i);
            return i * arch.memory.PAGE_SIZE;
        }
    }
    return null;
}

pub fn free_page(addr: usize) void {
    const page_idx = addr / arch.memory.PAGE_SIZE;
    if (page_idx < total_pages) {
        clear_bit(page_idx);
    }
}
