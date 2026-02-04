section .text
bits 32
extern kernel_boot

global start

start:
  mov esp, stack_top
  
  ; save multiboot state
  mov [mb_magic_store], eax
  mov [mb_addr_store], ebx

  call enable_sse
  mov word [0xb8000], 0x0248 ; H

  call long_mode_paging
  jmp enter_long_mode


enable_sse:
  mov eax, cr0
  and ax, 0xfffb
  or ax, 0x2
  mov cr0, eax

  mov eax, cr4
  or ax, (3 << 9)
  mov cr4, eax
  ret

long_mode_paging:
    ; Point the first entry of the level 4 page table to the first entry in the
    ; p3 table
    mov eax, p3_table
    or eax, 0b11
    mov dword [p4_table + 0], eax

    ; Point the first entry of the level 3 page table to the first entry in the
    ; p2 table
    mov eax, p2_table
    or eax, 0b11
    mov dword [p3_table + 0], eax

    ; point each page table level two entry to a page
    mov ecx, 0         ; counter variable
.map_p2_table:
    mov eax, 0x200000  ; 2MiB
    mul ecx
    or eax, 0b10000011
    mov [p2_table + ecx * 8], eax

    inc ecx
    cmp ecx, 512       ; Mapeia 1GB de RAM (512 * 2MB)
    jne .map_p2_table

    ; move page table address to cr3
    mov eax, p4_table
    mov cr3, eax

    ; enable PAE
    mov eax, cr4
    or eax, 1 << 5
    mov cr4, eax

    ; set the long mode bit
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 << 8
    wrmsr

    ; enable paging
    mov eax, cr0
    or eax, 1 << 31
    or eax, 1 << 16
    mov cr0, eax

    ret

enter_long_mode:
    ; Set up the GDT for long mode
    cli
    lgdt [gdt_descriptor]

    ; Far jump to 64-bit mode
    jmp 0x08:kernel_entry

; 64-bit kernel entry point
bits 64

kernel_entry:
  ; Clear segment registers
  xor ax, ax
  mov ds, ax
  mov es, ax  ; <--- CORRIGIDO (Tinha uma vírgula aqui)
  mov fs, ax
  mov gs, ax
  mov ss, ax
  
  ; Configura a stack 64-bit
  mov rsp, stack64_top
  
  ; Garante alinhamento de 16 bytes (exigido pela ABI do Zig/C)
  and rsp, -16

  ; Restaura os argumentos para passar pro Zig
  mov edi, [mb_addr_store]
  mov esi, [mb_magic_store]

  call kernel_boot
  hlt

section .bss

mb_magic_store:
  resd 1
mb_addr_store:
  resd 1

alignb 4096

p4_table:
  resb 4096
p3_table:
  resb 4096
p2_table:
  resb 4096

stack_bottom:
  resb 4096
stack_top:

stack64_bottom:
  resb 16384 ;  16KB 
stack64_top:

section .data
align 8

gdt:
  .null dq 0
  .code dq (1<<44) | (1<<47) | (1<<41) | (1<<43) | (1<<53) ; 64-bit code
  .data dq (1<<44) | (1<<47) | (1<<41) ; Data segment
  .unused dq 0 
  .unused2 dq 0
  .tss_low dq 0
  .tss_high dq 0
  .end:

gdt_descriptor:
  dw gdt.end - gdt - 1
  dq gdt

section .text
global gdt_set_entry

gdt_set_entry:
  mov eax, edx 
  and eax, 0xFFFF
  movzx r9d, cx
  shl r9d, 16
  or eax, r9d
  mov [gdt + rdi * 8], eax

  mov eax, esi
  shr eax, 16
  and eax, 0xFF
  movzx r9d, r8b
  shl r9d, 8
  or eax, r9d
  mov [gdt + rdi * 8 + 4], eax

  mov rax, rsi
  shr rax, 24
  mov [gdt + rdi * 8 + 8], eax
  ret