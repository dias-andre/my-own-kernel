const uefi = @import("std").os.uefi;
const log = @import("klog");

const mem = @import("mem/memory.zig");
const gdt = @import("cpu/gdt.zig");
const idt = @import("interrupts/idt.zig");
const cpu = @import("cpu/cpu.zig");

const BootInfo = @import("bootinfo").BootInfo;
extern fn kernel_main(bootinfo: *BootInfo) noreturn;

export fn kernel_entry(info: *BootInfo) callconv(.{ .x86_64_sysv = .{} }) noreturn {
    log.init();
    log.debug("Serial logger created!", .{});
    log.info("Reached kernel boot", .{});

    log.info("Initializing UEFI Memory map", .{});
    mem.init_from_uefi(info.map, info.map_size, info.desc_size);
    gdt.init();
    log.info("GDT Initialized!", .{});
    idt.init();
    log.info("IDT Initialized!", .{});
    cpu.enable_sse();
    log.info("SSE enabled!", .{});
    log.debug("Jump to kernel main!", .{});
    // while (true) {
    //     serial.print("halt loop\n");
    //     asm volatile ("hlt");
    // }
    kernel_main(info);
    unreachable;
}
