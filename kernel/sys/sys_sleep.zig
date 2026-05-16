const sch = @import("../sch/index.zig");
const pit = @import("../drivers/pit.zig");

pub fn sys_sleep(ms: usize) void {
    const current = sch.get_current_thread();
    if (current) |thread| {
        const wake_tick = pit.get_ticks() + ms;
        thread.state = .{ .Sleeping = .{ .wake_at_tick = wake_tick } };
        sch.schedule();
    }
}