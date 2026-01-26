const vga = @import("vga.zig");
const idt = @import("arch/x86/idt.zig");
const mb = @import("multiboot.zig");
const mm = @import("./mm/index.zig");

extern var _start: u8;
extern var _end: u8;

export fn kernel_main(pointer: u64, magic: u64) callconv(.c) noreturn {
    vga.setColor(vga.Color.Green, vga.Color.Black);
    vga.clear();
    vga.print("The execution reached the kernel entry.\n");
    vga.setDefaultColor();
    idt.init();

    // get multiboot info
    const mb_info = mb.init(pointer, magic);

    const kernel_end_addr = @intFromPtr(&_end);
    // vga.print("Kernel ends at: 0x");
    // vga.printHex(kernel_end_addr);
    // vga.print("\n");

    // starts memory management subsystem
    mm.init(mb_info, kernel_end_addr);

    vga.print("\nKernel is alive and paged!\n");
    while (true) {
        asm volatile ("hlt");
    }
}
