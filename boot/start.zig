const std = @import("std");
const uefi = std.os.uefi;

const KERNEL_ENTRY: usize = 0x100000;

fn qemu_debug_print(str: []const u8) void {
    for (str) |char| {
        asm volatile ("outb %[value], %[port]"
            :
            : [value] "{al}" (char),
              [port] "{dx}" (@as(u16, 0xE9)),
        );
    }
}

pub fn main() uefi.Status {
    const boot_services = uefi.system_table.boot_services orelse return .device_error;
    const con_out = uefi.system_table.con_out orelse return .device_error;

    _ = con_out.outputString(&[_:0]u16{ 'S', 't', 'a', 'r', 't', 'i', 'n', 'g', '.', '.', '.', '\n' }) catch return .device_error;
    qemu_debug_print("Starting logs with QEMU");

    _ = con_out.outputString(&[_:0]u16{ 'P', '1', '\n' }) catch return .device_error;
    const pages = boot_services.allocatePages(.{ .address = @ptrFromInt(KERNEL_ENTRY) }, .loader_code, 512) catch {
        return .aborted;
    };

    _ = con_out.outputString(&[_:0]u16{ 'P', '2', '\n' }) catch return .device_error;
    const fs = boot_services.locateProtocol(uefi.protocol.SimpleFileSystem, null) catch return .device_error;
    var root = fs.?.openVolume() catch return .device_error;

    _ = con_out.outputString(&[_:0]u16{ 'P', '3', '\n' }) catch return .device_error;
    var kernel_file = root.open(&[_:0]u16{ 'k', 'e', 'r', 'n', 'e', 'l', '.', 'b', 'i', 'n' }, .read, .{}) catch return .aborted;

    _ = con_out.outputString(&[_:0]u16{ 'P', '4', '\n' }) catch return .device_error;
    const buffer = std.mem.sliceAsBytes(pages);

    _ = con_out.outputString(&[_:0]u16{ 'P', '5', '\n' }) catch return .device_error;
    _ = kernel_file.read(buffer) catch return .device_error;
    kernel_file.close() catch return .device_error;
    root.close() catch return .device_error;

    _ = con_out.outputString(&[_:0]u16{ 'K', 'e', 'r', 'n', 'e', 'l', ' ', 'M', 'a', 'p', 'p', 'e', 'd', '!', '\n' }) catch return .aborted;

    _ = con_out.outputString(&[_:0]u16{ 'P', '6', '\n' }) catch return .device_error;
    var map_buf_ptr = boot_services.allocatePool(.boot_services_data, 16384) catch return .aborted;
    const buf = map_buf_ptr[0..16384];

    _ = con_out.outputString(&[_:0]u16{ 'J', 'U', 'M', 'P', '\n' }) catch return .device_error;
    qemu_debug_print("getMemoryMap");
    const memory_map = boot_services.getMemoryMap(buf) catch {
        return .aborted;
    };

    _ = boot_services.exitBootServices(uefi.handle, memory_map.info.key) catch {
        return .aborted;
    };

    const KernelEntryFn = *const fn (map: [*]uefi.tables.MemoryDescriptor, size: usize, d_size: usize) callconv(.c) noreturn;
    const entry: KernelEntryFn = @ptrFromInt(KERNEL_ENTRY);
    qemu_debug_print("JUMPING TO KERNEL_BOOT");
    entry(@ptrCast(memory_map.ptr), memory_map.info.descriptor_size * memory_map.info.len, memory_map.info.descriptor_size);
}
