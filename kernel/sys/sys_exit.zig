const sch = @import("../sch/index.zig");

pub fn sys_exit(code: usize) void {
    const current_thread = sch.get_current_thread();
    current_thread.state = .{ .Zombie = .{ .exit_code = code } };
    sch.schedule();
}
