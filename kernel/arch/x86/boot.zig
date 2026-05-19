const uefi = @import("std").os.uefi;
const mem = @import("mem/memory.zig");
const gdt = @import("cpu/gdt.zig");
const idt = @import("interrupts/idt.zig");
const cpu = @import("cpu/cpu.zig");
const serial = @import("serial.zig");

const BootInfo = @import("bootinfo").BootInfo;
extern fn kernel_main(rsdp: u64) noreturn;

// export fn kernel_boot(pointer: u64, magic: u64) callconv(.c) noreturn {
//     const mb_info = multiboot.init(pointer, magic);
//     mem.init(mb_info);
//     gdt.init();
//     idt.init();
//     cpu.enable_sse();
//     kernel_main();
//     unreachable;
// }

export fn kernel_boot(info: *BootInfo) linksection(".text.kernel_boot") callconv(.{ .x86_64_sysv = .{} }) noreturn {
    serial.print("Reached kernel_boot\n");

    serial.print("Initializing UEFI memory map...\n");
    mem.init_from_uefi(info.map, info.map_size, info.desc_size);
    gdt.init();
    serial.print("GDT initialized!\n");
    idt.init();
    serial.print("IDT initialized!\n");
    cpu.enable_sse();
    serial.print("SSE enabled!\n");
    serial.print("Call kernel_main\n");
    // while (true) {
    //     serial.print("halt loop\n");
    //     asm volatile ("hlt");
    // }
    kernel_main(info.rsdp_addr);
    unreachable;
}
