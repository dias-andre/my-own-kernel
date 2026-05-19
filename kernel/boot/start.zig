const std = @import("std");
const uefi = std.os.uefi;
const BootInfo = @import("bootinfo").BootInfo;

const KERNEL_ENTRY: usize = 0x100000;

fn serial_print(str: []const u8) void {
    for (str) |char| {
        asm volatile ("outb %[value], %[port]"
            :
            : [value] "{al}" (char),
              [port] "{dx}" (@as(u16, 0xE9)),
        );
    }
}

var boot_info: BootInfo = undefined;

pub fn main() uefi.Status {
    const boot_services = uefi.system_table.boot_services orelse return .device_error;
    const con_out = uefi.system_table.con_out orelse return .device_error;

    _ = con_out.outputString(&[_:0]u16{ 'S', 't', 'a', 'r', 't', 'i', 'n', 'g', '.', '.', '.', '\n' }) catch return .device_error;
    serial_print("Starting logs with QEMU");

    const pages = boot_services.allocatePages(.{ .address = @ptrFromInt(KERNEL_ENTRY) }, .loader_code, 512) catch {
        return .aborted;
    };

    const fs = boot_services.locateProtocol(uefi.protocol.SimpleFileSystem, null) catch return .device_error;
    var root = fs.?.openVolume() catch return .device_error;

    var kernel_file = root.open(&[_:0]u16{ 'k', 'e', 'r', 'n', 'e', 'l', '.', 'b', 'i', 'n' }, .read, .{}) catch return .aborted;

    const buffer = std.mem.sliceAsBytes(pages);

    _ = kernel_file.read(buffer) catch return .device_error;
    kernel_file.close() catch return .device_error;
    root.close() catch return .device_error;

    // Searching RSDP
    var rsdp_address: u64 = 0;
    const acpi_20_guid = uefi.Guid{
        .time_low = 0x8868e871,
        .time_mid = 0xe4f1,
        .time_high_and_version = 0x11d3,
        .clock_seq_high_and_reserved = 0xbc,
        .clock_seq_low = 0x22,
        .node = [_]u8{ 0x00, 0x80, 0xc7, 0x3c, 0x88, 0x81 },
    };

    const config_tables = uefi.system_table.configuration_table;
    const num_tables = uefi.system_table.number_of_table_entries;

    for (config_tables[0..num_tables]) |table| {
        if (std.mem.eql(u8, std.mem.asBytes(&table.vendor_guid), std.mem.asBytes(&acpi_20_guid))) {
            rsdp_address = @intFromPtr(table.vendor_table);
            serial_print("Found RSDP!");
            break;
        }
    }

    if (rsdp_address == 0) {
        serial_print("ALERT: ACPI 2.0 Table not found! (rsdp_address = 0)\n");
    }

    var map_buf_ptr = boot_services.allocatePool(.boot_services_data, 16384) catch return .aborted;
    const buf = map_buf_ptr[0..16384];

    const memory_map = boot_services.getMemoryMap(buf) catch {
        return .aborted;
    };

    _ = boot_services.exitBootServices(uefi.handle, memory_map.info.key) catch {
        return .aborted;
    };

    boot_info.map = @ptrCast(memory_map.ptr);
    boot_info.map_size = memory_map.info.len * memory_map.info.descriptor_size;
    boot_info.desc_size = memory_map.info.descriptor_size;
    boot_info.rsdp_addr = rsdp_address;

    const KernelEntryFn = *const fn (info: *BootInfo) callconv(.{ .x86_64_sysv = .{} }) noreturn;
    const entry: KernelEntryFn = @ptrFromInt(KERNEL_ENTRY);
    serial_print("JUMPING TO KERNEL_BOOT");
    entry(&boot_info);
}
