pub const SyscallContext = packed struct {
    r15: usize,
    r14: usize,
    r13: usize,
    r12: usize,
    rbp: usize,
    rbx: usize,

    r11: usize,
    r10: usize,
    r9: usize,
    r8: usize,

    rcx: usize,
    rdx: usize,
    rsi: usize,
    rdi: usize,

    rax: usize,

    rip: usize,
    cs: usize,
    rflags: usize,
    rsp: usize,
    ss: usize,

    pub fn setReturn(self: *SyscallContext, value: usize) void {
        self.rax = value;
    }

    pub fn getArg(self: *SyscallContext, index: u3) usize {
        return switch (index) {
            0 => self.rdi,
            1 => self.rsi,
            2 => self.rdx,
            3 => self.r10,
            4 => self.r8,
            5 => self.r9,
            else => 0,
        };
    }
};
