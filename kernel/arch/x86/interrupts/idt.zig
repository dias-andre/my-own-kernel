const std = @import("std");
const serial = @import("../serial.zig");
const lib = @import("lib");
const cpu = @import("../cpu/cpu.zig");

const isr_table = @import("isr_stub_table.zig");
const lapic_timer = @import("../timers/lapic_timer.zig");
const pit = @import("../timers/pit.zig");

const IdtEntry = packed struct {
    offset_low: u16,
    selector: u16,
    ist: u8,
    type_attr: u8,
    offset_mid: u16,
    offset_high: u32,
    reserved: u32,

    pub fn set(self: *IdtEntry, handler: anytype) void {
        const addr = @intFromPtr(handler);
        self.offset_low = @as(u16, @truncate(addr));
        self.selector = 0x08;
        self.ist = 0;
        self.type_attr = 0x8e;
        self.offset_mid = @as(u16, @truncate(addr >> 16));
        self.offset_high = @as(u32, @truncate(addr >> 32));
        self.reserved = 0;
    }
};

const IdtPtr = packed struct {
    limit: u16,
    base: u64,
};

var idt: [256]IdtEntry align(16) = undefined;

pub fn init() void {
    for (0..256) |i| {
        idt[i].set(isr_table.isr_stub_table[i]);
    }
    const idt_ptr = IdtPtr{
        .limit = @sizeOf(@TypeOf(idt)) - 1,
        .base = @intFromPtr(&idt),
    };

    asm volatile ("lidt (%[ptr])"
        :
        : [ptr] "r" (&idt_ptr),
    );
}

export fn isr_handler_zig(ctx: *isr_table.TrapFrame) void {
    const vector = @as(u8, @truncate(ctx.int_num));
    switch (vector) {
        14 => {
            pageFaultHandler(ctx);
        },
        32 => {
            pit.handle_irq();
            // apic.send_eoi();
        },
        254 => {
            lapic_timer.send_eoi();
        },
        else => {
            var panicWriter = getPanicWriter();
            panicWriter.print("Interrupt: {d}\n", .{ctx.int_num}) catch @panic("IDT PanicWriter failed!");
            @panic("Unhandled interrupt!\n");
        },
    }
}

fn pageFaultHandler(ctx: *isr_table.TrapFrame) void {
    const cr2 = asm volatile ("mov %%cr2, %[ret]"
        : [ret] "=r" (-> u64),
    );
    var panicWriter = getPanicWriter();

    panicWriter.print("[PAGE FAULT] Failed to access memory at: 0x{x}\n", .{cr2}) catch @panic("IDT PanicWriter failed!");
    panicWriter.print("-> [RIP]: 0x{x}, [ERROR_CODE] {d}\n", .{ ctx.rip, ctx.error_code }) catch @panic("IDT PanicWriter failed!");
    @panic(".");
}

fn getPanicWriter() std.Io.Writer {
    return lib.Serial.getSerialWriter().interface;
}

fn putChar(_: *anyopaque, data: u8) void {
    serial.putChar(data);
}

fn writeChar(_: *anyopaque, data: []const u8) void {
    serial.print(data);
}
