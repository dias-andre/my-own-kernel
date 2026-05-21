const std = @import("std");
const log = @import("klog").Logger;
const smp = @import("smp");

const ArchCpuData = @import("./root.zig").ArchCpuData;
const SDT_Header = @import("acpi.zig").SDT_Header;

pub const MADT_Descriptor = extern struct {
    header: SDT_Header,
    local_apic_address: u32 align(1),
    flags: u32 align(1),
};

const MADT_EntryHeader = extern struct {
    type: u8,
    length: u8,
};

const MADT_ProcessorLocalAPIC = extern struct {
    header: MADT_EntryHeader,
    acpi_processor_id: u8 align(1),
    apic_id: u8 align(1),
    flags: u32 align(1),
};

const MADT_IO_APIC = extern struct {
    header: MADT_EntryHeader,
    io_apic_id: u8 align(1),
    reserved: u8 align(1),
    io_apic_address: u32 align(1),
    global_system_interrupt_base: u32 align(1),
};

const MADT_Entry = extern union {
    header: MADT_EntryHeader,
    local_apic: MADT_ProcessorLocalAPIC,
    io_apic: MADT_IO_APIC,
};

pub fn map(madt_ptr: u64) void {
    log.debug("SDT Header size: {}", .{@sizeOf(SDT_Header)});
    log.debug("MADT Descriptor size: {}", .{@sizeOf(MADT_Descriptor)});
    log.debug("APIC Offset: {}", .{@offsetOf(MADT_Descriptor, "local_apic_address")});

    const madt: *MADT_Descriptor = @ptrFromInt(madt_ptr);
    log.debug("MADT signature: {}, MADT size: {}", .{ @as([]const u8, madt.header.signature[0..4]), madt.header.length });
    if ((madt.flags & 1) != 0) {
        log.info("Dual 8259 Legacy PICs Installed!", .{});
    }
    parse_madt(madt);
}

fn parse_madt(madt: *MADT_Descriptor) void {
    log.spec("Parsing MADT entries", .{});
    log.println("MADT Size: {} bytes", .{madt.header.length});
    const total_length = madt.header.length;
    var current_offset: usize = 0x2c;
    const raw_madt = @as([*]const u8, @ptrCast(madt));
    while (current_offset < total_length) {
        const entry_header_ptr = @intFromPtr(raw_madt) + current_offset;
        const entry_header = @as(*MADT_EntryHeader, @ptrFromInt(entry_header_ptr));

        if (entry_header.length == 0) {
            log.failed("Corrupted MADT entry at offset {}! Length is 0", .{current_offset});
            break;
        }

        log.println(" Found entry - Type: {}, Length: {}", .{ entry_header.type, entry_header.length });
        const entry: *MADT_Entry = @ptrFromInt(entry_header_ptr);
        switch (entry_header.type) {
            0 => {
                log.println("-> Processor Local APIC found! ACPI Processor ID: {}", .{entry.local_apic.acpi_processor_id});
                const flags = entry.local_apic.flags;
                if ((flags & 1) != 0 or (flags & 2) != 0) {
                    const arch_data = ArchCpuData{
                        .apic_id = entry.local_apic.apic_id,
                        .acpi_id = entry.local_apic.acpi_processor_id,
                    };
                    smp.register_cpu(arch_data);
                }
            },
            1 => {
                log.println("-> I/O APIC found! APIC Address: {}", .{@as([*]u8, @ptrFromInt(entry.io_apic.io_apic_address))});
            },
            else => {},
        }
        current_offset += entry_header.length;
    }
}
