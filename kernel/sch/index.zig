const log = @import("../utils/klog.zig").Logger;
const ctx = @import("context.zig");
const mem = @import("../mm/index.zig");
const Thread = @import("thread.zig").Thread;
const proc = @import("../proc/manager.zig");

const HHDM_OFFSET = 0xFFFF800000000000;

var current_thread: ?*Thread = null;

pub fn push_thread(new_thread: *Thread) void {
    if (current_thread) |curr| {
        new_thread.next = curr.next;
        curr.next = new_thread;
    } else {
        new_thread.next = new_thread;
        current_thread = new_thread;
    }
}

pub fn schedule() void {
    if (current_thread) |prev| {
        var next = prev.next;

        if (next == null) next = prev;

        if (next == prev) return;

        current_thread = next;

        ctx.switch_context(&prev.rsp, next.?.rsp);
    }
}
