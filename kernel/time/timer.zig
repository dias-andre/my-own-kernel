const khal = @import("khal");

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
