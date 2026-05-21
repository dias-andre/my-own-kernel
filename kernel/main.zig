const std = @import("std");
const arch = @import("arch");
const klog = @import("klog");

const mm = @import("kmem");
const smp = @import("smp");
const sys_exit = @import("sys/sys_exit.zig").sys_exit;
const log = klog.Logger;
const BootInfo = @import("bootinfo").BootInfo;

extern var _end: u8;

export fn kernel_main(bootinfo: *BootInfo) noreturn {
    log.info("The execution reached kernel main", .{});
    mm.init(@intFromPtr(&_end));
    smp.init(mm.kernel_allocator());

    log.info("Enabling Interrupts...", .{});
    arch.interrupts.init();
    log.ok("Interrupts enabled! ", .{});

    log.info("Enabling System calls...", .{});
    arch.cpu.enable_syscalls();
    log.ok("System calls enabled! ", .{});

    log.info("Initializing Hardware Abstraction Layer (HAL)", .{});
    arch.hal.init_hardware(bootinfo.rsdp_addr);
    log.info("Idle loop...", .{});
    while (true) arch.cpu.idle();
}

pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    // @setCold(true);
    arch.cpu.disable_interrupts();
    log.println("PANIC: {}", .{msg});
    while (true) arch.cpu.idle();
}

comptime {
    _ = arch.boot;
}
