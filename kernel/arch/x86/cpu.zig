const MSR_EFER  = 0xC0000080;
const MSR_STAR  = 0xC0000081;
const MSR_LSTAR = 0xC0000082;
const MSR_SFMASK= 0xC0000084;

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

pub fn enable_syscalls(syscall_handler_addr: u64) void {
    var efer = rdmsr(MSR_EFER);
    efer |= 1; 
    wrmsr(MSR_EFER, efer);

    const star_val: u64 = (@as(u64, 0x10) << 48) | (@as(u64, 0x08) << 32);
    wrmsr(MSR_STAR, star_val);

    wrmsr(MSR_LSTAR, syscall_handler_addr);

    wrmsr(MSR_SFMASK, 0x200);
}

pub fn rdmsr(msr: u32) u64 {
    var low: u32 = undefined;
    var high: u32 = undefined;

    asm volatile (
        "rdmsr"
        : [low] "={eax}" (low),
          [high] "={edx}" (high)
        : [msr] "{ecx}" (msr)
    );

    return (@as(u64, high) << 32) | low;
}

pub fn wrmsr(msr: u32, value: u64) void {
    const low = @as(u32, @truncate(value));
    const high = @as(u32, @truncate(value >> 32));

    asm volatile (
        "wrmsr"
        : // Sem outputs
        : [msr] "{ecx}" (msr),
          [low] "{eax}" (low),
          [high] "{edx}" (high)
    );
}

