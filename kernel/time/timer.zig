const khal = @import("khal");
const ksmp = @import("smp");
var global_timer: ?khal.TimerSource = null;

pub fn setKernelTimer(timersource: khal.TimerSource) void {
    global_timer = timersource;
}

pub fn sleep_ms(ms: u64) void {
    if (global_timer) |timer| {
        timer.sleep_ms(ms);
    }
}

pub fn sleep_us(us: u64) void {
    if (global_timer) |timer| {
        timer.sleep_us(us);
    }
}

pub fn isKernelTimerEnabled() bool {
    return global_timer != null;
}

pub const PerCoreTimer = struct {
    pub fn get() khal.TimerSource {
        return ksmp.get_current_core().timer;
    }

    pub fn sleep_ms(ms: u64) void {
        ksmp.get_current_core().timer.sleep_ms(ms);
    }
};
