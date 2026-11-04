extern fn isr_handler_zig(frame: *TrapFrame) callconv(.c) u64;

pub const TrapFrame = extern struct {
    rax: u64,
    rbx: u64,
    rcx: u64,
    rdx: u64,
    rsi: u64,
    rdi: u64,
    rbp: u64,

    r8: u64,
    r9: u64,
    r10: u64,
    r11: u64,
    r12: u64,
    r13: u64,
    r14: u64,
    r15: u64,

    // pushed by stubs
    int_num: u64,
    error_code: u64,

    // pushed by CPU
    rip: u64,
    cs: u64,
    rflags: u64,
    rsp: u64,
    ss: u64,
};

comptime {
    asm (
        \\.intel_syntax noprefix
        \\.global isr_common_stub
        \\isr_common_stub:
        \\  push r15
        \\  push r14
        \\  push r13
        \\  push r12
        \\  push r11
        \\  push r10
        \\  push r9
        \\  push r8
        \\  push rbp
        \\  push rdi
        \\  push rsi
        \\  push rdx
        \\  push rcx
        \\  push rbx
        \\  push rax
        \\
        \\  cld
        \\  mov rdi, rsp
        \\  call isr_handler_zig
        \\
        \\  pop rax
        \\  pop rbx
        \\  pop rcx
        \\  pop rdx
        \\  pop rsi
        \\  pop rdi
        \\  pop rbp
        \\  pop r8
        \\  pop r9
        \\  pop r10
        \\  pop r11
        \\  pop r12
        \\  pop r13
        \\  pop r14
        \\  pop r15
        \\
        \\  add rsp, 16
        \\  iretq
    );
}

fn hasErrorCode(i: u64) bool {
    return switch (i) {
        8, 10...14, 17, 21 => true,
        else => false,
    };
}

fn makeIsr(comptime i: u8) fn () callconv(.naked) void {
    return struct {
        fn handler() callconv(.naked) void {
            asm volatile (
                (if (!hasErrorCode(i)) "push 0\n" else "") ++
                    "push %[idx]\n" ++
                    "jmp isr_common_stub"
                :
                : [idx] "n" (i),
            );
        }
    }.handler;
}

pub const isr_stub_table = blk: {
    var table: [256]*const fn () callconv(.naked) void = undefined;
    for (0..256) |i| {
        table[i] = makeIsr(@intCast(i));
    }
    break :blk table;
};
