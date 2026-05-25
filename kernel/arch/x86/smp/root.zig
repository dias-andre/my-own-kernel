const kmem = @import("kmem");
const log = @import("klog").Logger;
const ksmp = @import("smp");
const apic = @import("../interrupts/apic.zig");
const gdt = @import("../cpu/gdt.zig");

pub const ApMailbox = packed struct {
    cr3: u32,
    gdt_limit: u16,
    gdt_base: u32,
    stack_ptr: u64,
    is_awake: u64,
};

const MAIL_BOX_ADDRESS: usize = 0x7000;
const TRAMPOLINE_PHYS_ADDR: usize = 0x8000;

pub const mailbox: *volatile ApMailbox = @ptrFromInt(MAIL_BOX_ADDRESS);
extern var ap_trampoline_start: u8;
extern var ap_trampoline_end: u8;

pub fn init() void {
    log.info("Copy trampoline to low memory: 0x{x} -> 0x{x}", .{ @intFromPtr(&ap_trampoline_start), TRAMPOLINE_PHYS_ADDR });
    copy_trampoline_to_low_memory();
    log.ok("Copy finished!", .{});
    wake_up_ap(ksmp.get_cpus()[1].data.apic_id);
}

pub fn wake_up_ap(apic_id: u32) void {
    const gdt_descriptor = gdt.get_gdt_descriptor();
    mailbox.cr3 = @intCast(kmem.kernel_pages());
    mailbox.gdt_base = @intCast(gdt_descriptor.base);
    mailbox.gdt_limit = gdt_descriptor.limit;
    mailbox.is_awake = 0;
    const stack_allocated = kmem.pmm.allocate_page() orelse @panic("OOM: failed to allocate page to CPU stack.");
    mailbox.stack_ptr = stack_allocated + 4096;
    log.println(" Mailbox: {any}", .{mailbox});
    log.info("Sending wake up to core {d}", .{apic_id});

    while (mailbox.is_awake == 0) {}
    log.ok("Core with APIC_ID {d} is online!", .{apic_id});
}

pub fn copy_trampoline_to_low_memory() void {
    const size = @intFromPtr(&ap_trampoline_end) - @intFromPtr(&ap_trampoline_start);
    log.println(" Trampoline size: {d} bytes", .{size});
    const src = @as([*]const u8, @ptrCast(&ap_trampoline_start))[0..size];
    const dst = @as([*]const u8, @ptrFromInt(TRAMPOLINE_PHYS_ADDR))[0..size];
    @memcpy(@constCast(dst), src);
}

export fn cpu_smp_entrypoint() void {
    while (true) {
        asm volatile ("hlt");
    }
}
