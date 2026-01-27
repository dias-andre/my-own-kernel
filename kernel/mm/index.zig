const mb = @import("../multiboot.zig");
const vga = @import("../vga.zig");

pub const pmm = @import("./pmm.zig");
pub const vmm = @import("./vmm.zig");
pub const heap = @import("./heap.zig");

pub var kheap: heap.KernelHeap = undefined;

pub fn init(mb_info: *mb.MultibootInfo, kernel_end_addr: usize) void {
  vga.print("\n[MM] Starting Memory Management Subsystem...\n");
  pmm.init(mb_info, kernel_end_addr);
  vmm.init();
  kheap = heap.KernelHeap.init();
  vga.print("[MM] Memory Management initialized successfully.\n");
}