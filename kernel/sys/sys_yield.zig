const sch = @import("../sch/index.zig");

pub fn sys_yield() void {
    sch.schedule();
}