pub fn read_cr2() usize {
    var value: usize = 0;
    asm volatile ("mov %%cr2, %[ret]"
        : [ret] "=r" (value),
    );
    return value;
}

pub fn halt() void {
    asm volatile ("hlt");
}

pub fn cli() void {
    asm volatile("cli");
}

pub fn sti() void {
    asm volatile("sti");
}

pub fn outb(port: u16, value: u8) void {
    asm volatile ("outb %[value], %[port]"
        :
        : [value] "{al}" (value),
          [port] "{dx}" (port),
    );
}

pub fn inb(port: u16) u8 {
    return asm volatile ("inb %[port], %[ret]"
        : [ret] "={al}" (-> u8),
        : [port] "{dx}" (port),
    );
}

pub fn io_wait() void {
    outb(0x80, 0);
}

