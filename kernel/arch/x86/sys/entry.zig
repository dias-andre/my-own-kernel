const SyscallContext = @import("context.zig").SyscallContext;

export fn syscall_dispatcher(ctx: *SyscallContext) void {
    _ = ctx;
}

comptime {
    asm (
        \\.intel_syntax noprefix
        \\.global syscall_entry
        \\syscall_entry:
        \\  swapgs
        \\  mov qword ptr gs:[0x08], rsp
        \\  mov rsp, qword ptr gs:[0x00]
        \\
        \\  push qword ptr 0x18
        \\  push qword ptr gs:[0x08]
        \\  push r11
        \\  push qword ptr 0x20
        \\  push rcx
        \\
        \\  push rax
        \\  push rdi
        \\  push rsi
        \\  push rdx
        \\  push rcx
        \\  push r8
        \\  push r9
        \\  push r10
        \\  push r11
        \\  push r12
        \\  push r13
        \\  push r14
        \\  push r15
        \\
        \\  mov rdi, rsp
        \\
        \\  call syscall_dispatcher
        \\
        \\  pop r15
        \\  pop r14
        \\  pop r13
        \\  pop r12
        \\  pop r11
        \\  pop r10
        \\  pop r9
        \\  pop r8
        \\  pop rcx
        \\  pop rdx
        \\  pop rsi
        \\  pop rdi
        \\  
        \\  add rsp, 8
        \\  
        \\  pop rcx
        \\  add rsp, 8
        \\  pop r11
        \\
        \\  mov rsp, qword ptr gs:[0x08]
        \\
        \\  swapgs
        \\  sysretq
    );
}

pub extern fn syscall_entry() void;