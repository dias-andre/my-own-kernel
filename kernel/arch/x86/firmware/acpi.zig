const std = @import("std");
const log = @import("klog");

const RSDP_Descriptor = extern struct {
    signature: [8]u8 align(1), //length 8
    checksum: u8 align(1),
    oemid: [6]u8 align(1), // length 6
    revision: u8 align(1),
    rsdt_address: u32 align(1),
    length: u32 align(1),
    xsdt_address: u64 align(1),
    extended_checksum: u8 align(1),
    reserved: [3]u8 align(1),
};

pub const SDT_Header = extern struct {
    signature: [4]u8 align(1),
    length: u32 align(1),
    revision: u8 align(1),
    checksum: u8 align(1),
    OEMID: [6]u8 align(1),
    OEMTableID: [8]u8 align(1),
    OEMRevision: u32 align(1),
    creatorId: u32 align(1),
    creatorRevision: u32 align(1),
};

const RSDT_Table = extern struct {
    header: SDT_Header align(1),
    entries: [*]u32 align(1),
};

const XSDT_Table = extern struct {
    header: SDT_Header align(1),
    entries: [*]u64 align(1),
};

fn verify_sdt_checksum(header: *SDT_Header) bool {
    var sum: u8 = 0;
    for (0..header.length) |i| {
        sum +%= @as([*]u8, @ptrCast(@alignCast(header)))[i];
    }
    return sum == 0;
}

var madt: u64 = 0;
pub fn init(ptr: u64) void {
    const rsdp: *RSDP_Descriptor = @ptrFromInt(ptr);
    if (!std.mem.eql(u8, &rsdp.signature, "RSD PTR ")) {
        @panic("RSDP signature is invalid!");
    }
    log.ok("RSDP signature found at 0x{x}", .{@intFromPtr(rsdp)});
    log.info("RSDP Revision: {d}", .{rsdp.revision});

    var sdt_header: *SDT_Header = undefined;
    var expected_sig: []const u8 = undefined;

    if (rsdp.revision >= 2) {
        sdt_header = @ptrFromInt(rsdp.xsdt_address);
        expected_sig = "XSDT";
        log.info("Using XSDT", .{});
    } else {
        sdt_header = @ptrFromInt(rsdp.rsdt_address);
        expected_sig = "RSDT";
        log.info("Using RSDT", .{});
    }

    if (!std.mem.eql(u8, &sdt_header.signature, expected_sig)) {
        log.failed("Signature error: expected {s}, found {s}", .{ expected_sig, &sdt_header.signature });
        @panic("Root System Description Table signature is invalid!");
    }

    log.ok("{s} signature found at 0x{x}", .{ expected_sig, @intFromPtr(sdt_header) });
    log.spec("Verifying checksum...", .{});

    if (!verify_sdt_checksum(sdt_header)) {
        @panic("SDT checksum failed!");
    }
    log.ok("Checksum finished! Table is ok!", .{});
    madt = find_madt_with_xsdt(@intFromPtr(sdt_header)) orelse {
        @panic("MADT (APIC) not found!");
    };
}

fn find_madt_with_xsdt(ptr: u64) ?u64 {
    log.info("Searching MADT with XSDT...", .{});
    const xsdt_table: *XSDT_Table = @ptrFromInt(ptr);
    const entries = (xsdt_table.header.length - @sizeOf(SDT_Header)) / 8;
    const pointers_array_addr = @intFromPtr(xsdt_table) + @sizeOf(SDT_Header);
    const pointers = @as([*]align(1) const u64, @ptrFromInt(pointers_array_addr));

    for (0..entries) |i| {
        const entry = @as(*SDT_Header, @ptrFromInt(pointers[i]));
        if (std.mem.eql(u8, &entry.signature, "APIC")) {
            log.ok("MADT (APIC) found at: 0x{x}", .{@intFromPtr(entry)});
            return pointers[i];
        } else {
            log.debug("Ignored table: {s}", .{@as([]const u8, entry.signature[0..4])});
        }
    }

    return null;
}

pub fn get_madt_addr() u64 {
    if (madt == 0) @panic("MADT not found! (madt = 0)");
    return madt;
}
