const pmm = @import("./pmm.zig");
const log = @import("../utils/klog.zig").Logger;
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
        @memset(&self.entries, 0);
    }
};

pub var kernel_pml4: *PageTable = undefined;

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

pub fn init() void {
    log.info("(VMM) Initializing Virtual Memory Manager.", .{});

    const pml4_phys = pmm.allocate_page() catch |err| {
        switch (err) {
            error.NoPhysicalPages => {
                log.failed("No physical pages during VMM initialization!", .{});
            },
        }
        while (true) asm volatile ("hlt");
    };

    kernel_pml4 = @ptrFromInt(pml4_phys);
    kernel_pml4.clear();

    log.println("- Kernel PML4 allocated at: {}", .{kernel_pml4});

    // TODO: identity mapping
    var current_addr: usize = 0;
    const max_addr: usize = 0x1000000;

    while (current_addr < max_addr) : (current_addr += 4096) {
        const flags = PAGE_PRESENT | PAGE_RW;
        map_page(kernel_pml4, current_addr, current_addr, flags) catch {
            log.failed("Failed to allocate physical page during VMM initialization", .{});
            while(true) asm volatile("hlt");
        };
    }
    log.println("- Identity mapped first 16MB", .{});
    log.println("- Loading CR3...", .{});

    load_pml4(kernel_pml4);
    log.ok("(VMM) Paging enabled successfully!", .{});
}

pub fn map_page(pml4: *PageTable, virt_addr: usize, phys_addr: usize, flags: usize) !void {
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
        const new_table_phys = try pmm.allocate_page();
        const new_table_ptr: *PageTable = @ptrFromInt(new_table_phys);
        new_table_ptr.clear();

        entry.* = new_table_phys | PAGE_PRESENT | PAGE_RW;
        return new_table_ptr;
    }

    const phys_addr = addr & PAGE_ADDR_MASK;
    return @ptrFromInt(phys_addr);
}

pub fn load_pml4(pml4: *PageTable) void {
    const addr = @intFromPtr(pml4);
    asm volatile ("mov %[addr], %%cr3"
        :
        : [addr] "r" (addr),
        : .{ .memory = true });
}
