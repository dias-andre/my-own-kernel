pub const MULTIBOOT_INFO_MEM_MAP = 0x00000040;

pub const MEMORY_AVAILABLE = 1;
pub const MEMORY_RESERVED = 2;
pub const MEMORY_ACPI_RECLAIMABLE = 3;
pub const MEMORY_NVS = 4;
pub const MEMORY_BADRAM = 5;

pub const MultibootInfo = extern struct { flags: u32, mem_lower: u32, mem_upper: u32, boot_device: u32, cmdline: u32, mods_count: u32, mods_addr: u32, syms: [4]u32, mmap_length: u32, mmap_addr: u32 };

pub const MemoryMapEntry = packed struct { size: u32, addr: u64, len: u64, type: u32 };
