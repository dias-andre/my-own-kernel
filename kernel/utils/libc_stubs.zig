const arch = @import("../arch/root.zig");
const std = @import("std");
const log = @import("klog.zig").Logger;

export fn memcpy(dest: [*]u8, src: [*]const u8, n: usize) callconv(.c) ?[*]u8 {
    var i: usize = 0;
    while (i < n) : (i += 1) {
        dest[i] = src[i];
    }
    return dest;
}

export fn memset(dest: [*]u8, val: u8, n: usize) callconv(.c) ?[*]u8 {
    var i: usize = 0;
    while (i < n) : (i += 1) {
        dest[i] = val;
    }
    return dest;
}

export fn memmove(dest: [*]u8, src: [*]const u8, n: usize) callconv(.c) ?[*]u8 {
    if (@intFromPtr(dest) < @intFromPtr(src)) {
        return memcpy(dest, src, n);
    }

    var i: usize = n;
    while (i > 0) {
        i -= 1;
        dest[i] = src[i];
    }
    return dest;
}

pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    // @setCold(true);
    arch.cpu.disable_interrupts();

    log.failed("!!! KERNEL PANIC !!!", .{});
    log.println("{s}", .{msg});

    while (true) arch.cpu.idle();
}