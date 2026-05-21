.section .ap_trampoline, "awx"
.code16

.global ap_trampoline_start
ap_trampoline_start:
  cli
  xorw %ax, %ax
  movw %ax, %ds
  movw %ax, %es
  movw %ax, %ss

  # load temp GDT
  lgdtl (ap_gdt_ptr - ap_trampoline_start + 0x8000)

  # enable protected mode
  movl %cr0, %eax
  orl $0x1, %eax
  movl %eax, %cr0

  ljmpl $0x08, $(ap_trampoline_32 - ap_trampoline_start + 0x8000)

.code32
ap_trampoline_32:
  movw $0x10, %ax
  movw %ax, %ds
  movw %ax, %es
  movw %ax, %ss

  # enable PAE
  movl %cr4, %eax
  orl $(1 << 5), %eax
  movl %eax, %cr4

  # load cr3
  movl (ap_cr3_value - ap_trampoline_start + 0x8000), %eax
  movl %eax, %cr3

  # enable EFER.LME
  movl $0xC0000080, %ecx
  rdmsr
  orl $(1 << 8), %eax
  wrmsr

  # enable paging + protected mode
  movl %cr0, %eax
  orl $0x80000001, %eax
  movl %eax, %cr0

  ljmpl $0x08, $(ap_trampoline_64 - ap_trampoline_start + 0x8000)

.code64
ap_trampoline_64:
  # reload real kernel GDT
  lgdt (kernel_gdt_ptr)

  # set stack
  movq (ap_stack_top - ap_trampoline_start + 0x8000), %rsp

  # call entrypoint
  movq (ap_entry_fn - ap_trampoline_start + 0x8000), %rax
  callq *%rax

  cli
  hlt


.align 8
ap_cr3_value:   .long 0
ap_stack_top:   .quad 0
ap_entry_fn:    .quad 0

.align 8
ap_gdt_start:
  .quad 0x0000000000000000    # null
  .quad 0x00cf9a000000ffff    # 32-bit code
  .quad 0x00cf92000000ffff    # 32-bit data
  .quad 0x00af9a000000ffff    # 64-bit code (L=1)
  .quad 0x00af92000000ffff    # 64-bit data
ap_gdt_end:

ap_gdt_ptr:
  .word ap_gdt_end - ap_gdt_start - 1
  .long ap_gdt_start - ap_trampoline_start + 0x8000

.global ap_trampoline_end
ap_trampoline_end:
