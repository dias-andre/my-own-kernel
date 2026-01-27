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

fn outb(port: u16, value: u8) void {
    asm volatile ("outb %[value], %[port]"
        :
        : [value] "{al}" (value),
          [port] "{dx}" (port),
    );
}

fn inb(port: u16) u8 {
    return asm volatile ("inb %[port], %[ret]"
        : [ret] "={al}" (-> u8),
        : [port] "{dx}" (port),
    );
}

fn io_wait() void {
    outb(0x80, 0);
}

pub fn remap() void {
    const m1 = inb(PIC1_DATA);
    const m2 = inb(PIC2_DATA);

    // ICW1 - start
    outb(PIC1_CMD, ICW1_INIT | ICW1_ICW4);
    io_wait();
    outb(PIC2_CMD, ICW1_INIT | ICW1_ICW4);
    io_wait();

    // ICW2 - define IDT offsets
    outb(PIC1_DATA, PIC1_OFFSET);
    io_wait();
    outb(PIC2_DATA, PIC2_OFFSET);
    io_wait();

    // ICW3 - (wiring)
    outb(PIC1_DATA, 4);
    io_wait();
    outb(PIC2_DATA, 2);
    io_wait();

    // define mode 8086
    outb(PIC1_DATA, ICW4_8086);
    io_wait();
    outb(PIC2_DATA, ICW4_8086);
    io_wait();

    // final
    outb(PIC1_DATA, 0xfd);
    outb(PIC2_DATA, 0xff);

    outb(PIC1_DATA, m1);
    outb(PIC2_DATA, m2);
}

pub fn sendEOI(irq: u8 ) void {
    if(irq >= 8) {
        outb(PIC2_CMD, 0x20);
    }
    outb(PIC1_CMD, 0x20);
}
