pub const ClockSource = struct {
    ptr: *anyopaque,
    vtable: *const VTable,
    const VTable = struct {
        implSleepMs: *fn (ptr: *anyopaque, ms: u64) void,
        implSleepUs: *fn (ptr: *anyopaque, us: u64) void,
    };

    pub fn sleep_ms(self: *ClockSource, ms: u64) void {
        self.vtable.implSleepMs(self.ptr, ms);
    }

    pub fn sleep_us(self: *ClockSource, us: u64) void {
        self.vtable.implSleepUs(self.ptr, us);
    }
};
