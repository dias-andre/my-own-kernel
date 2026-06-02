ENTRY(kernel_boot)

KERNEL_VMA = 0xFFFFFFFF80000000;
KERNEL_PHYS = 0x100000;
SECTIONS {
  . = KERNEL_VMA;
  kernel_vma_start = .;
  .text : ALIGN(4K) {
    KEEP(*(.text.kernel_boot))
    *(.text*)
  }

  .rodata : ALIGN(4K) {
    *(.rodata*)
  }

  .data : ALIGN(4K) { 
    *(.data*) 
  }
  
  .bss : ALIGN(4K) { 
    *(COMMON)
    *(.bss*) 
  }
  kernel_vma_end = .;

  /DISCARD/ : {
        *(.eh_frame*)
        *(.note*)
        *(.comment*)
  }
}
