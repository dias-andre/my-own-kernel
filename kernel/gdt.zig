const vga = @import("vga.zig");
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
};

pub fn init() void {
    vga.print("\n[GDT] Loading new GDT...\n");
    const gdt_ptr = GdtDescriptor{ .limit = @sizeOf(@TypeOf(gdt_entries)) - 1, .base = @intFromPtr(&gdt_entries) };
    vga.print("- Running lgdt...\n");
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
    vga.print("\n[GDT] New GDT loaded successfully!\n");
}
