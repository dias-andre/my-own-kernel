const sch = @import("../sch/index.zig");

pub fn handler() void {
    sch.schedule();
}