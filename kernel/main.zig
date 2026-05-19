const std = @import("std");
const arch = @import("arch");
const klog = @import("klog");

const mm = @import("kmem");

const sys_exit = @import("sys/sys_exit.zig").sys_exit;
const log = klog.Logger;

extern var _start: u8;
extern var _end: u8;

export fn kernel_main(rsdp: u64) noreturn {
    log.init();
    log.info("The execution reached kernel main", .{});
    mm.init(@intFromPtr(&_end));

    log.info("Enabling Interrupts...", .{});
    arch.interrupts.init();
    log.ok("Interrupts enabled! ", .{});

    log.info("Enabling System calls...", .{});
    arch.cpu.enable_syscalls();
    log.ok("System calls enabled! ", .{});

    log.info("RSDP at {}", .{rsdp});
    const str = @as([*]u8, @ptrFromInt(rsdp))[0..8];
    log.info("{}", .{@as([]u8, str)});
    while (true) arch.cpu.idle();
}

pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    // @setCold(true);
    asm volatile ("cli");
    log.println("==> @panic: {}", .{msg});
    while (true) asm volatile ("hlt");
}

comptime {
    _ = arch.boot;
}
