const std = @import("std");
const arch = @import("arch");
const log = @import("klog");
const khal = @import("khal");
const sched = @import("sched");
const proc = @import("proc");

const TimerSource = @import("khal").TimerSource;

pub const CpuState = enum { Offline, Online, Halted };

pub const CpuCore = struct {
    logical_id: u64,
    state: CpuState,
    data: arch.cpu.ArchCpuData,
    timer: khal.TimerSource,
    tickCount: std.atomic.Value(u64),
    runQueue: sched.RunQueue = sched.RunQueue{},
};

const MAX_CPUS = 256;
var cpu_cores: [MAX_CPUS]CpuCore = undefined;
var cpu_count: usize = 0;

pub fn enable() void {
    log.info("Starting kernel Symmetric Multiprocessing!", .{});
    log.println(" Found {d} CPU cores.", .{cpu_count});
    log.debug("Preparing to wake up machine cores...", .{});
    arch.smp.prepare();
    log.debug("Start!", .{});
    for (0..cpu_count) |idx| {
        var core = &cpu_cores[idx];
        if (core.logical_id == 0) {
            log.println("Skipping BSP (already awake)", .{});
            core.state = .Online;
            continue;
        }
        log.println("Sending wake-up signal to core {d}", .{core.logical_id});
        arch.smp.wake_up_ap(core.data);
        core.state = .Halted;
        log.println(" - Core {d} is awake and idling!", .{core.logical_id});
    }
    log.ok("Kernel multiprocessing enabled!", .{});
}

pub fn register_cpu(arch_data: arch.cpu.ArchCpuData) void {
    if (cpu_count >= MAX_CPUS) @panic("Too many CPUs!");
    const cpu = &cpu_cores[cpu_count];
    cpu.data = arch_data;
    cpu.state = .Offline;
    cpu.logical_id = cpu_count;
    cpu.tickCount = std.atomic.Value(u64).init(0);
    cpu.timer = arch.smp.getCpuCoreTimerSource(&cpu.tickCount);
    cpu_count += 1;
    proc.prepareCoreRunQueue(cpu.logical_id, &cpu.runQueue);
}

//// Returns the current core
pub fn get_current_core() *CpuCore {
    const cpuid = arch.smp.get_cpuid();
    for (0..cpu_count) |idx| {
        const cpu = cpu_cores[idx];
        if (cpu.logical_id == cpuid) return &cpu_cores[idx];
    }
    @panic("CpuCore not found!");
}

pub fn get_cpus() []const CpuCore {
    return cpu_cores[0..cpu_count];
}
