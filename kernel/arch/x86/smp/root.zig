const std = @import("std");
const kmem = @import("kmem");
const log = @import("klog");
const ksmp = @import("smp");
const ktimer = @import("ktimer");
const khal = @import("khal");
const lapic_timer = @import("../timers/lapic_timer.zig");
const idt = @import("../interrupts/idt.zig");
const apic = @import("../interrupts/apic.zig");
const cpu = @import("../cpu/cpu.zig");
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

pub fn prepare() void {
    log.info("Copying trampoline to low memory: 0x{x} -> 0x{x}", .{ @intFromPtr(&ap_trampoline_start), TRAMPOLINE_PHYS_ADDR });
    copy_trampoline_to_low_memory();
    log.ok("Copy finished!", .{});
}

pub fn get_cpuid() u32 {
    return apic.read_reg(.id) >> 24;
}

pub fn wake_up_ap(data: cpu.ArchCpuData) void {
    const gdt_descriptor = gdt.get_gdt_descriptor();
    mailbox.cr3 = @intCast(kmem.kernel_pages());
    mailbox.gdt_base = @intCast(gdt_descriptor.base);
    mailbox.gdt_limit = gdt_descriptor.limit;
    mailbox.is_awake = 0;
    const stack_allocated = kmem.pmm.allocate_page() orelse @panic("OOM: failed to allocate page to CPU stack.");
    mailbox.stack_ptr = stack_allocated + 4096;
    // log.println(" Mailbox: {any}", .{mailbox});
    // log.info("Sending wake up to core {d}", .{data.apic_id});
    const sipi_vector: u32 = @intCast(TRAMPOLINE_PHYS_ADDR >> 12);
    const id_shift = data.apic_id << 24;
    // send IPI
    apic.write_reg(.icr_high, id_shift);
    apic.write_reg(.icr_low, 0x00004500);
    ktimer.sleep_ms(10);

    apic.write_reg(.icr_high, id_shift);
    apic.write_reg(.icr_low, 0x00004600 | sipi_vector);
    ktimer.sleep_ms(1);

    apic.write_reg(.icr_high, id_shift);
    apic.write_reg(.icr_low, 0x00004600 | sipi_vector);
    while (mailbox.is_awake == 0) {
        ktimer.sleep_ms(1);
    }
}

fn copy_trampoline_to_low_memory() void {
    const size = @intFromPtr(&ap_trampoline_end) - @intFromPtr(&ap_trampoline_start);
    log.println(" Trampoline size: {d} bytes", .{size});
    const src = @as([*]const u8, @ptrCast(&ap_trampoline_start))[0..size];
    const dst = @as([*]const u8, @ptrFromInt(TRAMPOLINE_PHYS_ADDR))[0..size];
    @memcpy(@constCast(dst), src);
}

pub fn getCpuCoreTimerSource(tickPtr: *std.atomic.Value(u64)) khal.TimerSource {
    return .{
        .ptr = tickPtr,
        .vtable = &.{
            .implSleepMs = &lapic_timer.implSleepMs,
            .implSleepUs = &lapic_timer.implSleepUs,
        },
    };
}

// Each core has the same CR3 and the same GDT
export fn cpu_smp_entrypoint(_: u64) void {
    cpu.enable_sse();
    idt.init();
    cpu.enable_interrupts();
    apic.enable_hardware_msr();
    apic.enable();
    lapic_timer.enable(); // enable per processor timer
    mailbox.is_awake = 1;
    while (true) {
        asm volatile ("hlt");
    }
}
