const std = @import("std");
const uefi = std.os.uefi;

const KERNEL_ENTRY: usize = 0x100000;

pub fn main() uefi.Status {
    const boot_services = uefi.system_table.boot_services orelse return .device_error;
    const con_out = uefi.system_table.con_out orelse return .device_error;

    _ = con_out.outputString(&[_:0]u16{ 'S', 't', 'a', 'r', 't', 'i', 'n', 'g', '.', '.', '.', '\n' }) catch return .device_error;

    var buf: [16384]u8 align(@alignOf(uefi.tables.MemoryDescriptor)) = undefined;

    const memory_map = boot_services.getMemoryMap(&buf) catch {
        return .aborted;
    };

    _ = boot_services.exitBootServices(uefi.handle, memory_map.info.key) catch {
        return .aborted;
    };

    const KernelEntryFn = *const fn (map: [*]uefi.tables.MemoryDescriptor, size: usize, d_size: usize) callconv(.c) noreturn;
    const entry: KernelEntryFn = @ptrFromInt(KERNEL_ENTRY);

    entry(@ptrCast(memory_map.ptr), memory_map.info.descriptor_size * @sizeOf(uefi.tables.MemoryDescriptor), @sizeOf(uefi.tables.MemoryDescriptor));
}
