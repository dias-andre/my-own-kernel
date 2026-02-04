const arch = @import("arch/root.zig");

const klog = @import("utils/klog.zig");
const log = @import("utils/klog.zig").Logger;

const mm = @import("mm/index.zig");
const timer_driver = @import("drivers/timer.zig");
// const proc = @import("proc/manager.zig");

const sys_exit = @import("sys/sys_exit.zig").sys_exit;

const stubs = @import("utils/libc_stubs.zig");

extern var _start: u8;
extern var _end: u8;

comptime {
    _ = stubs;
    _ = arch.boot;
}

export fn kernel_main() noreturn {
    log.info("The execution reached kernel main", .{});
    mm.init(@intFromPtr(&_end));

    log.info("Enabling Interrupts...", .{});
    arch.interrupts.init();
    arch.timer.init(100, &timer_driver.handler);
    log.ok("Interrupts enabled! ", .{});
    
    log.info("Enabling System calls...", .{});
    arch.cpu.enable_syscalls();
    log.ok("System calls enabled! ", .{});

    map_video_address();
    while (true) arch.cpu.idle();
}

fn map_video_address() void {
    const vga_physical = 0xb8000;
    const vga_virtual = 0xC0000000 + vga_physical;
    log.debug("Mapping VGA to a virtual address", .{});
    arch.paging.map(mm.kernel_pages(), vga_virtual, vga_physical, mm.Flags.DATA_KERNEL) catch {
        log.failed("Failed to map physical address {} to virtual address {}", .{vga_physical, vga_virtual});
        while(true) arch.cpu.idle();
    };
    klog.screen.video_address = vga_virtual;
    log.ok("VGA mapped to {}", .{@as(*u64, @ptrFromInt(vga_virtual))});
}

fn testFaultHandler() void {
    const bad_ptr: *u64 = @ptrFromInt(0xB0000000);
    bad_ptr.* = 0xDEADBEEF;
}
