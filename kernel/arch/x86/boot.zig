const uefi = @import("std").os.uefi;
const multiboot = @import("multiboot.zig");
const mem = @import("mem/memory.zig");
const gdt = @import("cpu/gdt.zig");
const idt = @import("interrupts/idt.zig");
const cpu = @import("cpu/cpu.zig");
const serial = @import("serial.zig");

extern fn kernel_main() noreturn;

// export fn kernel_boot(pointer: u64, magic: u64) callconv(.c) noreturn {
//     const mb_info = multiboot.init(pointer, magic);
//     mem.init(mb_info);
//     gdt.init();
//     idt.init();
//     cpu.enable_sse();
//     kernel_main();
//     unreachable;
// }

export fn kernel_boot(map: [*]uefi.tables.MemoryDescriptor, map_size: usize, desc_size: usize) linksection(".text.kernel_boot") callconv(.c) noreturn {
    _ = map;
    _ = map_size;
    _ = desc_size;

    serial.print("Reached kernel_boot\n");
    gdt.init();
    idt.init();
    cpu.enable_sse();
    serial.print("Call kernel_main\n");
    while (true) {
        asm volatile ("nop");
    }
    kernel_main();
    unreachable;
}
