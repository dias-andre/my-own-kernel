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

pub fn get_cpus() []const CpuCore {
    return cpu_list.items;
}
