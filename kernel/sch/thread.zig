const Process = @import("../proc/process.zig").Process;
const SwitchContext = @import("context.zig").SwitchContext;

pub const ThreadState = union(enum) { Ready, Running, Blocked: struct {
    reason: []const u8,
}, Sleeping: struct {
    wake_at_tick: usize,
}, Zombie: struct {
    exit_code: usize,
} };

pub const Thread = struct {
    rsp: usize,
    stack_base: usize,
    id: usize,
    next: ?*Thread,
    process: ?*Process,
    state: ThreadState,

    pub fn init(self: *Thread, entry_point: usize) void {
        const stack_top = self.stack_base + 4096;
        var sp = stack_top;

        sp -= @sizeOf(SwitchContext);
        const sc: *SwitchContext = @ptrFromInt(sp);

        const sc_bytes = @as([*]u8, @ptrCast(sc))[0..@sizeOf(SwitchContext)];
        @memset(sc_bytes, 0);
        sc.rip = entry_point;
        sc.rflags = 0x202;

        self.rsp = sp;
    }

    pub fn is_ready(self: *Thread) bool {
        return self.state == .Ready;
    }

    pub fn is_blocked(self: *Thread) bool {
        switch (self.state) {
            .Blocked, .Sleeping => return true,
            else => return false,
        }
    }
};
