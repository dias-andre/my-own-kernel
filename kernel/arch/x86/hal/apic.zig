const std = @import("std");
const log = @import("klog").Logger;
const smp = @import("smp");
const paging = @import("../mem/paging.zig");
const kmem = @import("kmem");
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

var local_apic_address: u64 = undefined;

pub fn parse_madt(madt_ptr: u64) void {
    log.debug("SDT Header size: {d}", .{@sizeOf(SDT_Header)});
    log.debug("MADT Descriptor size: {d}", .{@sizeOf(MADT_Descriptor)});
    log.debug("APIC Offset: 0x{x}", .{@offsetOf(MADT_Descriptor, "local_apic_address")});

    const madt: *MADT_Descriptor = @ptrFromInt(madt_ptr);
    log.debug("MADT signature: {s}, MADT size: {d}", .{ @as([]const u8, &madt.header.signature), madt.header.length });
    if ((madt.flags & 1) != 0) {
        log.info("Dual 8259 Legacy PICs Installed!", .{});
    }
    log.info("Local APIC Address found at: 0x{x}", .{madt.local_apic_address});
    local_apic_address = madt.local_apic_address;
    paging.map(kmem.kernel_pages(), local_apic_address, local_apic_address, kmem.Flags.WRITABLE | kmem.Flags.NO_CACHE) catch {
        log.failed("Failed to map Local APIC Address to kernel directory!", .{});
        @panic("Failed to map Local APIC to virtual memory");
    };
    log.spec("Parsing MADT entries", .{});
    log.println("MADT Size: {d} bytes", .{madt.header.length});
    const total_length = madt.header.length;
    var current_offset: usize = 0x2c;
    const raw_madt = @as([*]const u8, @ptrCast(madt));
    while (current_offset < total_length) {
        const entry_header_ptr = @intFromPtr(raw_madt) + current_offset;
        const entry_header = @as(*MADT_EntryHeader, @ptrFromInt(entry_header_ptr));

        if (entry_header.length == 0) {
            log.failed("Corrupted MADT entry at offset 0x{x}! Length is 0", .{current_offset});
            break;
        }

        const entry: *MADT_Entry = @ptrFromInt(entry_header_ptr);
        switch (entry_header.type) {
            0 => {
                log.println(" Processor Local APIC found! ACPI Processor ID: {d}", .{entry.local_apic.acpi_processor_id});
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
                log.println(" I/O APIC found! APIC Address: 0x{x}", .{entry.io_apic.io_apic_address});
            },
            else => {},
        }
        current_offset += entry_header.length;
    }
    log.ok("MADT parsing finished!", .{});
}

pub const LapicRegister = enum(u32) {
    id = 0x020,
    eoi = 0x0b0,
    spurious = 0x0f0,
    lvt_timer = 0x320,
    timer_initial_count = 0x380,
    timer_current_count = 0x390,
    timer_divide = 0x3e0,
    icr_low = 0x300,
    icr_high = 0x310,
};

pub fn lapic_write(reg: LapicRegister, value: u32) void {
    const addr = local_apic_address + @intFromEnum(reg);
    const ptr = @as(*volatile u32, @ptrFromInt(addr));
    ptr.* = value;
}

pub fn lapic_read(reg: LapicRegister) u32 {
    const addr = local_apic_address + @intFromEnum(reg);
    const ptr = @as(*volatile u32, @ptrFromInt(addr));
    return ptr.*;
}

pub fn send_eoi() void {
    lapic_write(.eoi, 0);
}

pub fn enable_lapic_timer() void {
    lapic_write(.spurious, 0x100 | 0xFF);
    lapic_write(.timer_divide, 0x03);
    lapic_write(.lvt_timer, 0x20000 | 32);
    lapic_write(.timer_initial_count, 10000000);
}
