.code64

.extern kernel_stack
.extern kernel_entry

.section .text.kernel_boot
.global _start

_start:
  leaq kernel_stack + 16384(%rip), %rsp
  xorq %rbp, %rbp
  call kernel_entry

failsafe:
  cli
  hlt
  jmp failsafe
