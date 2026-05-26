const std = @import("std");
const arch = @import("arch");
const log = @import("klog");

pub const CpuState = enum { Offline, Online, Halted };
pub const CpuCore = struct {
    logical_id: u64,
    state: CpuState,
    data: arch.cpu.ArchCpuData,
};

var cpu_list: std.ArrayList(CpuCore) = .empty;
var allocator: std.mem.Allocator = undefined;

pub fn init(alloc: std.mem.Allocator) void {
    allocator = alloc;
}

pub fn register_cpu(arch_data: arch.cpu.ArchCpuData) void {
    const next_id = cpu_list.items.len;
    cpu_list.append(allocator, .{
        .data = arch_data,
        .state = .Offline,
        .logical_id = next_id,
    }) catch |err| {
        log.failed("ArrayList.append error {d}", .{@intFromError(err)});
        @panic("Failed to register CPU data!");
    };
}

pub fn enable() void {
    log.info("Starting kernel Symmetric Multiprocessing!", .{});
    const cpu_count = cpu_list.items.len;
    log.println(" Found {d} CPU cores.", .{cpu_count});
    log.debug("Prepare to Wake Up machine cores...", .{});
    arch.smp.prepare();
    log.debug("Start!", .{});
    for (0..cpu_count) |idx| {
        var core = cpu_list.items.ptr[idx];
        if (core.logical_id == 0) {
            log.println("BSP ignored.", .{});
            core.state = .Online;
            continue;
        }
        log.println("Sending wake up signal to core {d}", .{core.logical_id});
        arch.smp.wake_up_ap(core.data);
        core.state = .Halted;
        log.println(" - Finished! Core {d} halted!", .{core.logical_id});
    }
    log.ok("Kernel multiprocessing enabled!", .{});
}

pub fn get_cpus() []const CpuCore {
    return cpu_list.items;
}
