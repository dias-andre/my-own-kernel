// callee-saved
// RBX, RBP, R12, R13, R14, R15 (e o RSP).

// caller-saved
// RAX, RCX, RDX, RSI, RDI, R8, R9, R10, R11

// rsp = stack_top (onde o código vai ser executado)

// arguments
// fn my_function(rdi, rsi, rdx, rcx, r8, r9, stack) rax, rdx {}

comptime {
    asm(
        \\.intel_syntax noprefix
        \\.global switch_context
        \\switch_context:
        \\  pushfq
        \\  push rbx
        \\  push rbp
        \\  push r12
        \\  push r13
        \\  push r14
        \\  push r15
        \\
        \\  mov [rdi], rsp
        \\  mov rsp, rsi
        \\
        \\  pop r15
        \\  pop r14
        \\  pop r13
        \\  pop r12
        \\  pop rbp
        \\  pop rbx
        \\  popfq
        \\
        \\  ret
    );
}
// salvar os registradores que são (callee-saved)
pub extern fn switch_context(current_rsp_ptr: *u64, next_rsp: u64) void;