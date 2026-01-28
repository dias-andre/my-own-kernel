const cpu = @import("cpu.zig");

const PIC1_CMD = 0x20; // master command port
const PIC1_DATA = 0x21; // master data port
const PIC2_CMD = 0xA0; // slave command port
const PIC2_DATA = 0xA1; // slave data port

// init commands
const ICW1_INIT = 0x10;
const ICW1_ICW4 = 0x01;
const ICW4_8086 = 0x01; // mode 8086/88

const PIC1_OFFSET = 0x20;
const PIC2_OFFSET = 0x28;

pub fn remap() void {
    // ICW1 - start
    cpu.outb(PIC1_CMD, ICW1_INIT | ICW1_ICW4);
    cpu.io_wait();
    cpu.outb(PIC2_CMD, ICW1_INIT | ICW1_ICW4);
    cpu.io_wait();

    // ICW2 - define IDT offsets
    cpu.outb(PIC1_DATA, PIC1_OFFSET);
    cpu.io_wait();
    cpu.outb(PIC2_DATA, PIC2_OFFSET);
    cpu.io_wait();

    // ICW3 - (wiring)
    cpu.outb(PIC1_DATA, 4);
    cpu.io_wait();
    cpu.outb(PIC2_DATA, 2);
    cpu.io_wait();

    // define mode 8086
    cpu.outb(PIC1_DATA, ICW4_8086);
    cpu.io_wait();
    cpu.outb(PIC2_DATA, ICW4_8086);
    cpu.io_wait();

    // final
    cpu.outb(PIC1_DATA, 0xfe);
    cpu.outb(PIC2_DATA, 0xff);

    //outb(PIC1_DATA, m1);
    //outb(PIC2_DATA, m2);
}

pub fn sendEOI(irq: u8) void {
    if (irq >= 8) {
        cpu.outb(PIC2_CMD, 0x20);
    }
    cpu.outb(PIC1_CMD, 0x20);
}
