const memory = @import("memory.zig");
const kmem = @import("kmem");
const Flags = kmem.Flags;

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
        var volatile_arr: [*]volatile u64 = @ptrCast(&self.entries);
        var i: usize = 0;
        while (i < 512) : (i += 1) {
            // self.entries[i] = 0;
            volatile_arr[i] = 0;
        }
    }
};

pub var is_paging_ready: bool = false;

pub fn map(page_directory: usize, virt: usize, phys: usize, flags: usize) !void {
    const page_table: *PageTable = @ptrFromInt(page_directory);
    try map_page(page_table, virt, phys, generic_to_arch_flags(flags));
}

pub fn set_paging_enabled() void {
    is_paging_ready = true;
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
        arch_flags |= (PAGE_CACHE_DISABLE | PAGE_WRITE_THROUGH | PAGE_RW);
    }

    if ((generic & Flags.NO_CACHE) != 0) {
        arch_flags |= PAGE_CACHE_DISABLE;
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

    if ((addr & PAGE_PRESENT) == 0) {
        const new_table_phys = try kmem.alloc_page();
        const new_table_virt = if (is_paging_ready) new_table_phys + memory.MEMORY_OFFSET else new_table_phys;
        const new_table_ptr: *PageTable = @ptrFromInt(new_table_virt);

        entry.* = new_table_phys | PAGE_PRESENT | PAGE_RW;
        new_table_ptr.clear();
        return new_table_ptr;
    }

    const phys_addr = addr & PAGE_ADDR_MASK;
    if (is_paging_ready) {
        return memory.phys_to_ptr(PageTable, phys_addr);
    } else {
        return @ptrFromInt(phys_addr);
    }
}
