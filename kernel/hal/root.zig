pub const TimerSource = struct {
    ptr: *anyopaque,
    vtable: *const VTable,
    const VTable = struct {
        implSleepMs: *const fn (ptr: *anyopaque, ms: u64) void,
        implSleepUs: *const fn (ptr: *anyopaque, us: u64) void,
    };

    pub fn sleep_ms(self: *const TimerSource, ms: u64) void {
        self.vtable.implSleepMs(self.ptr, ms);
    }

    pub fn sleep_us(self: *const TimerSource, us: u64) void {
        self.vtable.implSleepUs(self.ptr, us);
    }
};
