const log = @import("utils/klog.zig").Logger;
const mb = @import("multiboot.zig");
const mm = @import("mm/index.zig");
const gdt = @import("arch/x86/gdt.zig");
const idt = @import("arch/x86/idt.zig");
const pic = @import("arch/x86/pic.zig");
const cpu = @import("arch/x86/cpu.zig");
const pit = @import("drivers/pit.zig");

extern var _start: u8;
extern var _end: u8;

export fn kernel_main(pointer: u64, magic: u64) callconv(.c) noreturn {
    log.info("The execution reached kernel main", .{});
    
    // get multiboot info
    const mb_info = mb.init(pointer, magic);
    const kernel_end_addr = @intFromPtr(&_end);

    // starts memory management subsystem
    mm.init(mb_info, kernel_end_addr);
    gdt.init();
    idt.init();
    pic.remap();
    pit.init(100);
    cpu.sti();

    while (true) cpu.halt();
}

fn testFaultHandler() void {
    const bad_ptr: *u64 = @ptrFromInt(0xB0000000);
    bad_ptr.* = 0xDEADBEEF;
}

