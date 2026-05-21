const cpu = @import("arch").cpu;

pub const Spinlock = struct {
    locked: u32 align(4) = 0,

    pub fn acquire(self: *Spinlock) void {
        while (@cmpxchgWeak(u32, &self.locked, 0, 1, .acquire, .monotonic) != null) {
            cpu.pause();
        }
    }

    pub fn release(self: *Spinlock) void {
        @atomicStore(u32, &self.locked, 0, .release);
    }
};
