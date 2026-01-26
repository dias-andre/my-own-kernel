const vga = @import("vga.zig");
const idt = @import("arch/x86/idt.zig");
const mb = @import("multiboot.zig");

export fn kernel_main(pointer: u64, magic: u64) callconv(.c) noreturn {
    vga.setColor(vga.Color.Green, vga.Color.Black);
    vga.clear();

    vga.print("Zig kernel loaded sucessfully!\n");

    vga.setColor(vga.Color.White, vga.Color.Black);
    vga.print("Hello world!");
    idt.init();

    vga.print("\n--- Checking Multiboot ---\n");

    if (magic != 0x2BADB002) {
        vga.setColor(vga.Color.Red, vga.Color.Black);
        vga.print("ERROR: kernel was not initialized via multiboot!\n");
        printHex(magic);
        vga.print("\n");
        while (true) {
            asm volatile ("hlt");
        }
    } else {
        vga.print("Bootloader detected sucessfully.\n");
    }

    const mb_info: *mb.MultibootInfo = @ptrFromInt(pointer);

    vga.print("Magic number ok! Reading memory map...\n");

    vga.print("MMap Addr: 0x");
    printHex(mb_info.mmap_addr);
    vga.print(" | Len: 0x");
    printHex(mb_info.mmap_length);
    vga.print("\n--- RAM MAP ---\n");

    var current_addr = mb_info.mmap_addr;
    const end_addr = mb_info.mmap_addr + mb_info.mmap_length;

    var i: usize = 0;
    while (current_addr < end_addr) : (i += 1) {
        // [Safety] Check boundary before reading
        if (current_addr + @sizeOf(mb.MemoryMapEntry) > end_addr) {
            vga.print("End of buffer reached (insufficient bytes).\n");
            break;
        }
        
        const entry_ptr: *align(1) const mb.MemoryMapEntry = @ptrFromInt(current_addr);
        const entry = entry_ptr.*;

        vga.print("#");
        printHex(i); // Index
        vga.print(" Offset: 0x");
        printHex(current_addr);

        if (entry.type == 1) {
            vga.print(" [FREE] ");
        } else {
            vga.print(" [RESV] ");
        }

        vga.print("Base: 0x");
        printHex(entry.addr);
        vga.print(" Len: 0x");
        printHex(entry.len);
        vga.print(" Type: 0x");
        printHex(entry.type);
        vga.print("\n");

        if (entry.size == 0) {
            vga.print("CRITICAL ERROR: Entry size is 0. Aborting loop.\n");
            break;
        }

        current_addr += entry.size + 4;
    }

    vga.print("Memory map iteration finished.\n");

    while (true) {
        asm volatile ("hlt");
    }
}

fn printHex(value: u64) void {
    const hex_chars = "0123456789ABCDEF";
    var v = value;

    if (v == 0) {
        vga.print("0");
        return;
    }

    var buffer: [20]u8 = undefined;
    var index: usize = 0;

    while (v > 0) {
        const nibble = v % 16;
        buffer[index] = hex_chars[nibble];
        index += 1;
        v = v / 16;
    }

    while (index > 0) {
        index -= 1;
        const char_slice = buffer[index .. index + 1];
        vga.print(char_slice);
    }
}
