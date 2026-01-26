const pmm = @import("./pmm.zig");
const vmm = @import("./vmm.zig");
const mb = @import("../multiboot.zig");
const vga = @import("../vga.zig");


pub fn init(mb_info: *mb.MultibootInfo, kernel_end_addr: usize) void {
  vga.print("\n[MM] Starting Memory Management Subsystem...\n");
  pmm.init(mb_info, kernel_end_addr);
  vmm.init();
  vmm.map_page(vmm.kernel_pml4, 0x40000000, 0xb8000, vmm.PAGE_PRESENT | vmm.PAGE_RW);
  vga.print("[MM] Memory Management initialized successfully.\n");
}