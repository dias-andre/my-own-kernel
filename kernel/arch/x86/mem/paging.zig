const memory = @import("memory.zig");
const log = @import("../../../utils/klog.zig").Logger;

// ==========================================
// CONSTANTES DE PAGINAÇÃO (FLAGS)
// ==========================================
// Bit 0: Presente (A página existe na RAM?)
pub const PAGE_PRESENT: usize = 1;
// Bit 1: Read/Write (0 = Read-only, 1 = Read/Write)
pub const PAGE_RW: usize = 2;
// Bit 2: User/Supervisor (0 = Kernel só, 1 = User mode permitido)
pub const PAGE_USER: usize = 4;
// Bit 3: Write Through (Cache policy)
pub const PAGE_WRITE_THROUGH: usize = 8;
// Bit 4: Cache Disable (Desabilita cache para essa página)
pub const PAGE_CACHE_DISABLE: usize = 16;
// Bit 7: Huge Page (Se setado na PD/PDPT, indica página de 2MB ou 1GB)
pub const PAGE_HUGE: usize = 128;
// Bit 63: No Execute (Impede execução de código nesta página - requer suporte da CPU)
pub const PAGE_NX: usize = 1 << 63;

pub const PAGE_ADDR_MASK: usize = 0x000FFFFFFFFFF000;

pub const PageTable = extern struct {
    entries: [512]u64 align(4096),

    pub fn clear(self: *PageTable) void {
        var i: usize = 0;
        while (i < 512) : (i += 1) {
            self.entries[i] = 0;
        }
    }
};

pub var is_paging_ready: bool = false;
var alloc_phys_page: ?AllocatorFn = null;

const AllocatorFn = *const fn () ?usize;

pub fn map(page_directory: usize, virt: usize, phys: usize, flags: usize) !void {
    if (alloc_phys_page == null) {
        @panic("CRITICAL: alloc_phys_page IS NULL! set_physical_allocator failed.");
    }
    const page_table: *PageTable = @ptrFromInt(page_directory);
    try map_page(page_table, virt, phys, generic_to_arch_flags(flags));
}

pub fn set_paging_enabled() void {
    is_paging_ready = true;
}

pub fn set_physical_allocator(alloc: AllocatorFn) void {
    alloc_phys_page = alloc;
}

pub fn load_page_directory(virt_addr: usize) void {
    const phys_addr = memory.virt_to_phys(virt_addr);

    asm volatile ("mov %[addr], %%cr3"
        :
        : [addr] "r" (phys_addr),
        : .{ .memory = true });
}

pub fn init_page_directory(addr: usize) void {
    const pageTable: *PageTable = @ptrFromInt(addr);
    pageTable.clear();
}

fn get_pml4_index(virt_addr: usize) usize {
    return (virt_addr >> 39) & 0x1FF;
}

fn get_pdpt_index(virt_addr: usize) usize {
    return (virt_addr >> 30) & 0x1FF;
}

fn get_pd_index(virt_addr: usize) usize {
    return (virt_addr >> 21) & 0x1FF;
}

fn get_pt_index(virt_addr: usize) usize {
    return (virt_addr >> 12) & 0x1ff;
}

pub const Flags = struct {
    pub const READABLE: usize = 1 << 0;
    pub const WRITABLE: usize = 1 << 1;
    pub const EXECUTABLE: usize = 1 << 2;
    pub const USER: usize = 1 << 3;
    pub const MMIO: usize = 1 << 4;

    pub const CODE_USER = READABLE | EXECUTABLE | USER;
    pub const DATA_USER = WRITABLE | USER;
    pub const DATA_KERNEL = WRITABLE;
};

fn generic_to_arch_flags(generic: u64) usize {
    var arch_flags: usize = PAGE_PRESENT;

    if ((generic & Flags.WRITABLE) != 0) {
        arch_flags |= PAGE_RW;
    }

    if ((generic & Flags.USER) != 0) {
        arch_flags |= PAGE_USER;
    }

    // if ((generic & Flags.EXECUTABLE) == 0) {
    //     arch_flags |= PAGE_NX;
    // }

    if ((generic & Flags.MMIO) != 0) {
        arch_flags |= (PAGE_CACHE_DISABLE | PAGE_WRITE_THROUGH);
    }

    return arch_flags;
}

fn map_page(pml4: *PageTable, virt_addr: usize, phys_addr: usize, flags: usize) !void {
    const idx_pml4 = get_pml4_index(virt_addr);
    const idx_pdpt = get_pdpt_index(virt_addr);
    const idx_pd = get_pd_index(virt_addr);
    const idx_pt = get_pt_index(virt_addr);
    // _ = pml4;
    // _ = phys_addr;
    // _ = flags;
    // _ = idx_pml4;
    // _ = idx_pdpt;
    // _ = idx_pd;
    // _ = idx_pt;

    // TODO: implement page walk

    // level 3 -> 4
    const pdpt = try get_next_table(&pml4.entries[idx_pml4]);

    // level 3 -> 2
    const pd = try get_next_table(&pdpt.entries[idx_pdpt]);

    // level 2 -> 1
    const pt = try get_next_table(&pd.entries[idx_pd]);

    pt.entries[idx_pt] = (phys_addr & PAGE_ADDR_MASK) | flags;
}

fn get_next_table(entry: *u64) !*PageTable {
    const addr = entry.*;
    const allocator = alloc_phys_page orelse {
        @panic("PAGING ERROR: Paging allocator not configured!");
    };

    if ((addr & PAGE_PRESENT) == 0) {
        const new_table_phys = allocator() orelse return error.OutOfMemory;
        const new_table_ptr: *PageTable = @ptrFromInt(new_table_phys);

        entry.* = new_table_phys | PAGE_PRESENT | PAGE_RW;
        new_table_ptr.clear();
        return new_table_ptr;
    }

    const phys_addr = addr & PAGE_ADDR_MASK;
    // return @ptrFromInt(phys_addr);
    // return index.phys_to_ptr(PageTable, phys_addr);
    if (is_paging_ready) {
        return memory.phys_to_ptr(PageTable, phys_addr);
    } else {
        return @ptrFromInt(phys_addr);
    }
}

pub fn clone_pml4(parent_pml4_phys: usize) !usize {
    const allocator = alloc_phys_page orelse {
        @panic("PAGING ERROR: Paging allocator not configured!");
    };
    const child_pml4_phys = allocator() orelse return error.OutOfMemory;
    const parent_table = memory.phys_to_ptr(PageTable, parent_pml4_phys);
    const child_table = memory.phys_to_ptr(PageTable, child_pml4_phys);

    child_table.clear();
    for (0..512) |i| {
        const entry = parent_table.entries[i];

        if ((entry & PAGE_PRESENT) == 0) continue;

        if (i >= 256) {
            child_table.entries[i] = entry;
        } else {
            const child_pdpt_phys = try clone_table(entry, 3);
            const flags = entry & ~PAGE_ADDR_MASK;
            child_table.entries[i] = child_pdpt_phys | flags;
        }
    }

    return child_pml4_phys;
}

fn clone_table(parent_entry: u64, level: u8) !usize {
    const parent_phys = parent_entry & PAGE_ADDR_MASK;
    const parent_table = memory.phys_to_ptr(PageTable, parent_phys);

    const child_table_phys = alloc_phys_page();
    const child_table = memory.phys_to_ptr(PageTable, child_table_phys);

    for (0..512) |i| {
        const entry = parent_table.entries[i];
        if ((entry & PAGE_PRESENT) == 0) continue;

        const flags = entry & ~PAGE_ADDR_MASK;
        if (level == 2) {
            const child_pt_phys = try clone_page_table(entry);
            child_table.entries[i] = child_pt_phys | flags;
        } else {
            const child_next_phys = try clone_table(entry, level - 1);
            child_table.entries[i] = child_next_phys | flags;
        }
    }
    return child_table_phys;
}

fn clone_page_table(parent_pt_entry: u64) !usize {
    const parent_pt_phys = parent_pt_entry & PAGE_ADDR_MASK;
    const parent_pt = memory.phys_to_ptr(PageTable, parent_pt_phys);
    const child_pt_phys = alloc_phys_page();
    const child_pt = memory.phys_to_ptr(PageTable, child_pt_phys);
    child_pt.clear();

    for (0..512) |i| {
        const entry = parent_pt.entries[i];
        if ((entry & PAGE_PRESENT) == 0) continue;

        const flags = entry & ~PAGE_ADDR_MASK;
        const parent_page_phys = entry & PAGE_ADDR_MASK;
        const child_page_phys = alloc_phys_page();
        const src_ptr = memory.phys_to_ptr([4096]u8, parent_page_phys);
        const dst_ptr = memory.phys_to_ptr([4096]u8, child_page_phys);

        @memcpy(dst_ptr, src_ptr);

        child_pt.entries[i] = child_page_phys | flags;
    }
    return child_pt_phys;
}
