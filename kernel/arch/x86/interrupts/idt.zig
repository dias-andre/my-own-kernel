const serial = @import("../serial.zig");
const lib = @import("lib");
const cpu = @import("../cpu/cpu.zig");
const pic = @import("pic.zig");

const pit = @import("../pit.zig");

const isr_table = @import("isr_stub_table.zig");

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
    switch (ctx.int_num) {
        14 => {
            pageFaultHandler(ctx);
        },
        32 => {
            pic.sendEOI(0);
            pit.handle_irq();
        },
        33 => {
            pic.sendEOI(1);
        },
        else => {
            var panicWriter = getPanicWriter();
            panicWriter.print("Interrupt ");
            panicWriter.printDec(ctx.int_num);
            panicWriter.print("\n");
            @panic("Unhandled interrupt!\n");
        },
    }
}

fn pageFaultHandler(ctx: *isr_table.TrapFrame) void {
    const cr2 = asm volatile ("mov %%cr2, %[ret]"
        : [ret] "=r" (-> u64),
    );
    var panicWriter = getPanicWriter();

    panicWriter.print("[PAGE FAULT] ");
    panicWriter.print("Failed to access memory at: 0x");
    panicWriter.printHex(cr2);
    panicWriter.print("\n");

    panicWriter.print("-> [RIP]: 0x");
    panicWriter.printHex(ctx.rip);

    panicWriter.print(", [ERROR_CODE]: ");
    panicWriter.printHex(ctx.error_code);
    panicWriter.print("\n");
    @panic(".");
}

fn getPanicWriter() lib.Io.FormatWriter {
    return lib.Io.FormatWriter{
        .inner = lib.Io.Writer{
            .ptr = undefined,
            .vtable = &.{
                .write = &writeChar,
                .put = &putChar,
            },
        },
    };
}

fn putChar(_: *anyopaque, data: u8) void {
    serial.putChar(data);
}

fn writeChar(_: *anyopaque, data: []const u8) void {
    serial.print(data);
}
