const Process = @import("../proc/process.zig").Process;
const ctx = @import("context.zig");
const std = @import("std");
const kmem = @import("../mm/index.zig");

pub const ThreadState = union(enum) { Ready, Running, Blocked: struct {
    reason: []const u8,
}, Sleeping: struct {
    wake_at_tick: usize,
}, Zombie: struct {
    exit_code: usize,
} };

pub const Thread = struct {
    id: usize,
    rsp: usize,
    stack_base: usize,
    
    next: ?*Thread,
    state: ThreadState,

    // created for process controller
    next_sibling: ?*Thread,
    process: ?*Process,

    pub fn init(self: *Thread, entry_point: usize) void {
        const stack_top = self.stack_base + 4096;
        var sp = stack_top;

        sp -= @sizeOf(ctx.SwitchContext);
        const sc: *ctx.SwitchContext = @ptrFromInt(sp);

        const sc_bytes = @as([*]u8, @ptrCast(sc))[0..@sizeOf(ctx.SwitchContext)];
        @memset(sc_bytes, 0);
        sc.rip = entry_point;
        sc.rflags = 0x202;

        self.rsp = sp;
    }

    pub fn init_user_mode(self: *Thread, entry_point: usize, user_stack: usize) void {
        const stack_top = self.stack_base + 4096;
        var sp = stack_top;

        sp -= @sizeOf(ctx.InterruptFrame);
        const frame: *ctx.InterruptFrame = @ptrFromInt(sp);
        frame.ss = 0x23;
        frame.rsp = user_stack;
        frame.rflags = 0x202;
        frame.cs = 0x1B;
        frame.rip = entry_point;

        sp -= @sizeOf(ctx.SwitchContext);
        const sc: *ctx.SwitchContext = @ptrFromInt(sp);
        const sc_bytes = @as([*]u8, @ptrCast(sc))[0..@sizeOf(ctx.SwitchContext)];
        @memset(sc_bytes, 0);

        sc.rip = @intFromPtr(&interrupt_return_stub);
        sc.rflags = 0x202;
        self.rsp = sp;
    }

    pub fn create(allocator: std.mem.Allocator) !*Thread {
        const new_thread = try allocator.create(Thread);
        @memset(std.mem.asBytes(new_thread), 0 );
        
        const phys_stack = try kmem.alloc_physical_page();
        new_thread.stack_base = kmem.phys_to_virt(phys_stack);
        new_thread.id = 0;
        new_thread.state = .Ready;

        return new_thread;
    }

    pub fn destroy(self: *Thread, allocator: std.mem.Allocator) void {
        if(self.process) |owner| {
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

pub fn interrupt_return_stub() callconv(.naked) void {
    asm volatile ("iretq");
}