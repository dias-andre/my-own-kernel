const kmem = @import("kmem");
const apic = @import("../hal/apic.zig");
const gdt = @import("../cpu/gdt.zig");

pub const ApMailbox = packed struct {
    cr3: u32,
    gdt_limit: u16,
    gdt_base: u32,
    stack_ptr: u64,
    is_awake: u32,
};

pub const mailbox: *volatile ApMailbox = @ptrFromInt(0x7000);

pub fn wake_up_ap(apic_id: u32) void {
    _ = apic_id;
    const gdt_descriptor = gdt.get_gdt_descriptor();
    mailbox.cr3 = kmem.kernel_pages();
    mailbox.gdt_base = @intCast(gdt_descriptor.base);
    mailbox.gdt_limit = gdt_descriptor.limit;
    mailbox.is_awake = 0;
}

export fn smp_cpu_entrypoint() void {
    while (true) {
        asm volatile ("hlt");
    }
}
