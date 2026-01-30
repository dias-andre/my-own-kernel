const log = @import("utils/klog.zig").Logger;

pub const MULTIBOOT_INFO_MEM_MAP = 0x00000040;

pub const MEMORY_AVAILABLE = 1;
pub const MEMORY_RESERVED = 2;
pub const MEMORY_ACPI_RECLAIMABLE = 3;
pub const MEMORY_NVS = 4;
pub const MEMORY_BADRAM = 5;

pub const MultibootInfo = extern struct { flags: u32, mem_lower: u32, mem_upper: u32, boot_device: u32, cmdline: u32, mods_count: u32, mods_addr: u32, syms: [4]u32, mmap_length: u32, mmap_addr: u32 };

pub const MemoryMapEntry = packed struct { size: u32, addr: u64, len: u64, type: u32 };

pub fn init(mb_pointer: u64, mb_magic: u64) *MultibootInfo {
  log.info("Checking Multiboot", .{});
    if (mb_magic != 0x2BADB002) {
        log.failed("ERROR: kernel was not initialized via multiboot!", .{});
        while (true) {
            asm volatile ("hlt");
        }
    } else {
      log.ok("Bootloader detected successfully.", .{});
    }

    const mb_info: *MultibootInfo = @ptrFromInt(mb_pointer);

    var current_addr = mb_info.mmap_addr;
    const end_addr = mb_info.mmap_addr + mb_info.mmap_length;
    
    var i: usize = 0;
    while(current_addr < end_addr) : (i += 1) {
      if(current_addr + @sizeOf(MemoryMapEntry) > end_addr) {
        //End of buffer reached (insufficient bytes).
        break;
      }

      const entry_ptr: *align(1) const MemoryMapEntry = @ptrFromInt(current_addr);
      const entry = entry_ptr.*;

      if(entry.size == 0) {
        break;
      }

      current_addr += entry.size + 4;
    }
    return mb_info;
}
