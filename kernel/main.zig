const vga = @import("vga.zig");
const idt = @import("arch/x86/idt.zig");
const mb = @import("multiboot.zig");
const pmm = @import("mm/pmm.zig");

extern var _start: u8;
extern var _end: u8;

export fn kernel_main(pointer: u64, magic: u64) callconv(.c) noreturn {
    vga.setColor(vga.Color.Green, vga.Color.Black);
    vga.clear();
    vga.print("Execution reached kernel main!!\n");
    vga.setDefaultColor();
    idt.init();

    // get multiboot info
    const mb_info = mb.init(pointer, magic);

    const kernel_end_addr = @intFromPtr(&_end);
    vga.print("Kernel ends at: 0x");
    vga.printHex(kernel_end_addr);
    vga.print("\n");

    pmm.init(mb_info, kernel_end_addr);
    while (true) {
        asm volatile ("hlt");
    }
}
