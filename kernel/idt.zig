const vga = @import("vga.zig");
const cpu = @import("cpu.zig");
const vmm = @import("mm/vmm.zig");

const PanicWriter = vga.PanicWriter;

const interrupts = @import("interrupts.zig");

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
    vga.print("\n[IDT] Creating new IDT entries...\n");
    for(0..256) |i| {
        idt[i].set(interrupts.isr_stub_table[i]);
    }
    const idt_ptr = IdtPtr{
        .limit = @sizeOf(@TypeOf(idt)) - 1,
        .base = @intFromPtr(&idt),
    };

    vga.print("- Running lidt...\n");
    asm volatile ("lidt (%[ptr])"
        :
        : [ptr] "r" (&idt_ptr),
    );

    vga.print("[IDT] Loaded successfully!\n");
}

export fn isr_handler_zig(ctx: *interrupts.TrapFrame) void {
    switch (ctx.int_num) {
        14 => pageFaultHandler(ctx),
        else => {
            PanicWriter.cleanError();
            PanicWriter.print("Unhandled Interrupt: ");
            PanicWriter.printHex(ctx.int_num);
            PanicWriter.print("\n");
            PanicWriter.print("System halted.");
            while (true) asm volatile("hlt");
        }
    }
}

pub fn pageFaultHandler(ctx: *interrupts.TrapFrame) void {
    const fault_addr = cpu.read_cr2();
    PanicWriter.cleanError();
    
    PanicWriter.print("Faulting Address (CR2): 0x");
    PanicWriter.printHex(fault_addr);
    PanicWriter.print("\n");

    const error_code = ctx.error_code;

    if ((error_code & 1) == 0) {
        PanicWriter.print("[Not Present] ");
    } else {
        PanicWriter.print(" [Protection Violation] ");
    }

    if ((error_code & 2) != 0) {
        PanicWriter.print(" [Write operation] ");
    } else {
        PanicWriter.print(" [Read Operation] ");
    }

    if ((error_code & 4) != 0) {
        PanicWriter.print(" [User Mode]");
    } else {
        PanicWriter.print(" [Kernel Mode] ");
    }
    PanicWriter.print("\n");

    PanicWriter.print("System Halted.");
    while (true) {
        asm volatile ("hlt");
    }
}