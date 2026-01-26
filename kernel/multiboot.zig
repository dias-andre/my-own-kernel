const vga = @import("./vga.zig");

pub const MULTIBOOT_INFO_MEM_MAP = 0x00000040;

pub const MEMORY_AVAILABLE = 1;
pub const MEMORY_RESERVED = 2;
pub const MEMORY_ACPI_RECLAIMABLE = 3;
pub const MEMORY_NVS = 4;
pub const MEMORY_BADRAM = 5;

pub const MultibootInfo = extern struct { flags: u32, mem_lower: u32, mem_upper: u32, boot_device: u32, cmdline: u32, mods_count: u32, mods_addr: u32, syms: [4]u32, mmap_length: u32, mmap_addr: u32 };

pub const MemoryMapEntry = packed struct { size: u32, addr: u64, len: u64, type: u32 };

pub fn init(mb_pointer: u64, mb_magic: u64) *MultibootInfo {
  vga.print("\n--- Checking Multiboot ---\n");
    if (mb_magic != 0x2BADB002) {
        vga.setColor(vga.Color.Red, vga.Color.Black);
        vga.print("ERROR: kernel was not initialized via multiboot!\n");
        vga.printHex(mb_magic);
        vga.print("\n");
        while (true) {
            asm volatile ("hlt");
        }
    } else {
      vga.print("Bootloader detected successfully.\n");
    }

    const mb_info: *MultibootInfo = @ptrFromInt(mb_pointer);

    vga.print("Magic number ok! Reading memory map...\n");
    vga.print("MMap Addr: 0x");
    vga.printHex(mb_info.mmap_addr);
    vga.print(" | Len: ");
    vga.printDec(mb_info.mmap_length);
    vga.print(" bytes (struct len)\n");

    var current_addr = mb_info.mmap_addr;
    const end_addr = mb_info.mmap_addr + mb_info.mmap_length;
    
    var i: usize = 0;
    while(current_addr < end_addr) : (i += 1) {
      if(current_addr + @sizeOf(MemoryMapEntry) > end_addr) {
        vga.print("\nEnd of buffer reached (insufficient bytes).\n");
        break;
      }

      const entry_ptr: *align(1) const MemoryMapEntry = @ptrFromInt(current_addr);
      const entry = entry_ptr.*;
      
      vga.print("#");
      vga.printDec(i);
      vga.print(" Offset: 0x");
      vga.printHex(current_addr);

      if(entry.type == 1) {
        vga.print(" [FREE] ");
      } else {
        vga.print(" [RESV] ");
      }

      vga.print("Base: 0x");
      vga.printHex(entry.addr);
      vga.print(" Len: ");
      vga.printDec(entry.len / 1024 );
      vga.print("kb Type: 0x");
      vga.printHex(entry.type);
      vga.print("\n");

      if(entry.size == 0) {
        vga.print("CRITICAL ERROR: Entry size is 0. Aborting loop\n");
        break;
      }

      current_addr += entry.size + 4;
    }

    vga.print("Memory map iteration finished.\n\n");
    return mb_info;
}
