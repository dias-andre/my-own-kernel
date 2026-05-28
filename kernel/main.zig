const std = @import("std");
const arch = @import("arch");
const mm = @import("kmem");
const smp = @import("smp");
const ktimer = @import("ktimer");
const log = @import("klog");
const BootInfo = @import("bootinfo").BootInfo;

extern var _end: u8;

export fn kernel_main(bootinfo: *BootInfo) noreturn {
    log.info("The execution reached kernel main", .{});
    mm.init(@intFromPtr(&_end));

    log.info("Enabling Interrupts...", .{});
    arch.interrupts.init();
    log.ok("Interrupts enabled! ", .{});

    log.info("Enabling System calls...", .{});
    arch.cpu.enable_syscalls();
    log.ok("System calls enabled! ", .{});

    arch.firmware.init(bootinfo.rsdp_addr);
    smp.enable();
    check_per_core_timer();
    log.info("Entering idle loop...", .{});
    while (true) arch.cpu.idle();
}

fn check_per_core_timer() void {
    log.spec("Checking per-core timers", .{});
    log.println(" Waiting 2 seconds using the BSP per-core timer", .{});
    ktimer.PerCoreTimer.sleep_ms(2000);
    for (smp.get_cpus()) |core| {
        const tickCount = core.tickCount.load(.monotonic);
        log.println(" Core {d} has tick count: {d}", .{ core.logical_id, tickCount });
    }
}

pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    // @setCold(true);
    arch.cpu.disable_interrupts();
    log.println("PANIC: {s}", .{msg});
    while (true) arch.cpu.idle();
}

comptime {
    _ = arch.boot;
}
