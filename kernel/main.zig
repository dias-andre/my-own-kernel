const std = @import("std");
const arch = @import("arch");
const klog = @import("klog");

const mm = @import("kmem");
const apic = @import("apic/root.zig");

const sys_exit = @import("sys/sys_exit.zig").sys_exit;
const log = klog.Logger;

extern var _start: u8;
extern var _end: u8;

export fn kernel_main() noreturn {
    log.init();
    log.info("The execution reached kernel main", .{});
    mm.init(@intFromPtr(&_end));

    log.info("Enabling Interrupts...", .{});
    arch.interrupts.init();
    log.ok("Interrupts enabled! ", .{});
    // arch.timer.init(100, &timer_driver.handler);
    apic.init();

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
        log.failed("Failed to map physical address {} to virtual address {}", .{ vga_physical, vga_virtual });
        while (true) arch.cpu.idle();
    };
    log.ok("VGA mapped to {}", .{@as(*u64, @ptrFromInt(vga_virtual))});
}

pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    // @setCold(true);
    asm volatile ("cli");
    log.failed("PANIC! {}", .{msg});
    while (true) asm volatile ("hlt");
}

comptime {
    _ = arch.boot;
}
