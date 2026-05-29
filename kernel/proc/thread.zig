const std = @import("std");
const kmem = @import("kmem");
const arch = @import("arch");
const Process = @import("process.zig").Process;

pub const ThreadState = union(enum) { Ready, Running, Blocked: struct {
    reason: []const u8,
}, Sleeping: struct {
    wake_at_tick: usize,
}, Zombie: struct {
    exit_code: usize,
} };

pub const Thread = struct {
    id: usize,
    ctx: arch.ctx.ThreadData,

    next: ?*Thread,
    state: ThreadState,

    // created for process controller
    next_sibling: ?*Thread,
    process: ?*Process,

    // pub fn init(self: *Thread, entry_point: usize) void {
    //     const stack_top = self.stack_base + 4096;
    //     var sp = stack_top;
    //
    //     sp -= @sizeOf(ctx.SwitchContext);
    //     const sc: *ctx.SwitchContext = @ptrFromInt(sp);
    //
    //     const sc_bytes = @as([*]u8, @ptrCast(sc))[0..@sizeOf(ctx.SwitchContext)];
    //     @memset(sc_bytes, 0);
    //     sc.rip = entry_point;
    //     sc.rflags = 0x202;
    //
    //     self.rsp = sp;
    // }

    pub fn create(allocator: std.mem.Allocator) !*Thread {
        const new_thread = try allocator.create(Thread);
        @memset(std.mem.asBytes(new_thread), 0);

        const phys_stack = try kmem.alloc_physical_page();
        new_thread.stack_base = kmem.phys_to_virt(phys_stack);
        new_thread.id = 0;
        new_thread.state = .Ready;

        return new_thread;
    }

    pub fn destroy(self: *Thread, allocator: std.mem.Allocator) void {
        if (self.process) |owner| {
            owner.ref_count = @atomicRmw(usize, &owner.ref_count, .Sub, 1, .monotonic);
        }
        kmem.free_physical_page(kmem.virt_to_phys(self.stack_base));
        allocator.destroy(self);
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

