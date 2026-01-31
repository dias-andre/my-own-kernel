const sch = @import("../sch/index.zig");

pub fn sys_exit(code: usize) void {
    const current_thread = sch.get_current_thread();
    if (current_thread) |thread| {
        thread.state = .{ .Zombie = .{ .exit_code = code } };
        sch.schedule();
    }
}
