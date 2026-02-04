const multiboot = @import("multiboot.zig");
const mem = @import("mem/memory.zig");
const gdt = @import("gdt.zig");
const idt = @import("idt.zig");

extern fn kernel_main() noreturn;

export fn kernel_boot(pointer: u64, magic: u64) callconv(.c) noreturn {
    const mb_info = multiboot.init(pointer, magic);
    mem.init(mb_info);
    gdt.init();
    idt.init();
    kernel_main();
    unreachable;
}