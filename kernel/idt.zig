const vga = @import("vga.zig");
const cpu = @import("cpu.zig");
const vmm = @import("mm/vmm.zig");

const PanicWriter = vga.PanicWriter;

const IdtEntry = extern struct {
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

const InterruptFrame = extern struct { ip: u64, cs: u64, flags: u64, sp: u64, ss: u64 };

pub fn init() void {
    vga.print("\n[IDT] Creating new IDT entries...\n");
    idt[0].set(&divideByZeroHandler);
    idt[8].set(&panicHandler);
    idt[13].set(&panicHandler);
    idt[14].set(&pageFaultHandler);

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

pub fn pageFaultHandler(_: *InterruptFrame, error_code: u64) callconv(.{ .x86_64_interrupt = .{} }) void {
    const fault_addr = cpu.read_cr2();
    PanicWriter.cleanError();
    
    PanicWriter.print("Faulting Address (CR2): 0x");
    PanicWriter.printHex(fault_addr);
    PanicWriter.print("\n");

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


fn divideByZeroHandler(frame: *InterruptFrame) callconv(.{ .x86_64_interrupt = .{} }) void {
    _ = frame;
    const video: [*]volatile u16 = @ptrFromInt(0xb8000);
    video[0] = 0x4f21;

    while (true) {
        asm volatile ("hlt");
    }
}

fn panicHandler(frame: *InterruptFrame, error_code: u64) callconv(.{ .x86_64_interrupt = .{} }) void {
    _ = frame;
    _ = error_code;
    vga.PanicWriter.printAt("P", 79, 24);
    // vga.PanicWriter.cleanError();
    // vga.PanicWriter.printAt("!!! KERNEL PANIC !!!", 30, 10);
    // vga.PanicWriter.printAt("Exception: DOUBLE FAULT / ERROR", 25, 12);

    // vga.PanicWriter.printAt("Error Code: ", 28, 11);
    // vga.PanicWriter.printHexAt(error_code, 42, 11);

    // vga.PanicWriter.printAt("RIP: ", 28, 12);
    // vga.PanicWriter.printHexAt(frame.ip, 35, 12);

    while (true) {
        asm volatile ("hlt");
    }
}
