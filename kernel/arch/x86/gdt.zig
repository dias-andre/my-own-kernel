const tss_mod = @import("tss.zig");
const log = @import("../../utils/klog.zig").Logger;

const GdtEntry = packed struct(u64) {
    limit_low: u16 = 0, // bits 0-15
    base_low: u24 = 0, // bits 16-39
    accessed: bool = false, // bit 40
    rw: bool = false, // bit 41 (r/w)
    dc: bool = false, // bits 42 (dc) direction/conforming
    executable: bool = false, // bit 43 (e) - 1 for code, 0 data
    descriptor_type: bool = true, // bit 44 (s)
    dpl: u2 = 0, // bits 45-46 (dpl) - ring level (0=Kernel, 3=user)
    present: bool = false, // bit 47 (p) - must be 1
    limit_high: u4 = 0, // bits 48-51
    reserved: u1 = 0,
    long_mode: bool = false, // bit 53: 1 - 64 bit
    db: bool = false, // bit 54 (db) 0=64-bit, 1=32-bit
    granularity: bool = false, // bit 55 (g) - 1=limit * 4096,
    base_high: u8 = 0, // bits 56-63
};

const GdtDescriptor = packed struct { limit: u16, base: u64 };

var gdt_entries = [_]GdtEntry{
    .{},

    // kernel code (offset 0x08)
    .{
        .present = true,
        .descriptor_type = true,
        .executable = true,
        .rw = true,
        .long_mode = true,
    },

    // kernel data (offset 0x10)
    .{
        .present = true,
        .descriptor_type = true,
        .executable = false, // data segment,
        .rw = true, // writable
        .long_mode = false,
    },

    // TODO: User Code, User Data, TSS

    // User Data
    .{
        .present = true,
        .descriptor_type = true,
        .executable = false,
        .rw = true,
        .long_mode = false,
        .dpl = 3
    },

    // User Code,
    .{
        .present = true,
        .descriptor_type = true,
        .executable = true,
        .rw = true,
        .long_mode = true,
        .dpl = 3
    },

    .{},

    .{}
};

pub fn init() void {
    log.info("[GDT] Loading new GDT.", .{});
    const tss_base = @intFromPtr(&tss_mod.tss);
    const tss_limit = @sizeOf(tss_mod.TaskStateSegment);

    setTssEntry(5, tss_base, tss_limit);
    const gdt_ptr = GdtDescriptor{ .limit = @sizeOf(@TypeOf(gdt_entries)) - 1, .base = @intFromPtr(&gdt_entries) };
    asm volatile (
        \\lgdt (%[ptr])
        // reload segment registers
        \\ mov $0x10, %ax
        \\ mov %ax, %ds
        \\ mov %ax, %es
        \\ mov %ax, %fs
        \\ mov %ax, %gs
        \\ mov %ax, %ss
        // far jump
        \\ pushq $0x08
        \\ pushq $1f
        \\ lretq
        \\ 1:
        :
        : [ptr] "r" (&gdt_ptr),
        : .{ .memory = true }
    );
    asm volatile(
        \\ ltr %ax
        :
        : [selector] "{ax}" (@as(u16, 0x28))
    );
    log.ok("[GDT] New GDT loaded successfully!", .{});
}

fn setTssEntry(index: usize, base: u64, limit: u64) void {
    gdt_entries[index] = .{
        .limit_low = @truncate(limit),
        .base_low = @truncate(base),
        .base_high = @truncate(base >> 24),
        .present = true,
        .dpl = 0,
        .descriptor_type = false,
        .executable = true,
        .accessed = true,
        .rw = false,
        .limit_high = @truncate(limit >> 16),
        .granularity = false,
    };

    const high_part = @as(u64, base >> 32);
    const ptr_entry: *u64 = @ptrCast(&gdt_entries[index + 1]);
    ptr_entry.* = high_part;
}
