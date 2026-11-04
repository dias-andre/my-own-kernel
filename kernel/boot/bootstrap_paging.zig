const uefi = @import("std").os.uefi;

pub const PAGE_PRESENT: usize = 1;
pub const PAGE_RW: usize = 2;
pub const PAGE_ADDR_MASK: usize = 0x000FFFFFFFFFF000;

const PageTable = extern struct {
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

fn get_next_table(entry: *u64, boot_services: *uefi.tables.BootServices) !*PageTable {
    const addr = entry.*;

    if ((addr & PAGE_PRESENT) != 0) {
        const phys_addr = addr & PAGE_ADDR_MASK;
        return @as(*PageTable, @ptrFromInt(phys_addr));
    }

    const new_page_ptr = try boot_services.allocatePages(.any, .loader_data, 1);
    const new_table: *PageTable = @ptrCast(@alignCast(new_page_ptr));
    new_table.clear();
    entry.* = @intFromPtr(new_table) | PAGE_PRESENT | PAGE_RW;
    return new_table;
}

pub fn map_page(page_dir: *PageTable, virt_addr: usize, phys_addr: usize, flags: usize, boot_services: *uefi.tables.BootServices) !void {
    const idx_pml4 = get_pml4_index(virt_addr);
    const idx_pdpt = get_pdpt_index(virt_addr);
    const idx_pd = get_pd_index(virt_addr);
    const idx_pt = get_pt_index(virt_addr);

    const pdpt = try get_next_table(&page_dir.entries[idx_pml4], boot_services);
    const pd = try get_next_table(&pdpt.entries[idx_pdpt], boot_services);
    const pt = try get_next_table(&pd.entries[idx_pd], boot_services);

    pt.entries[idx_pt] = (phys_addr & PAGE_ADDR_MASK) | flags;
}
