ENTRY(kernel_boot)

KERNEL_VMA = 0xFFFFFFFF80000000;
KERNEL_PHYS = 0x100000;
SECTIONS {
  . = KERNEL_PHYS + KERNEL_VMA;
  kernel_vma_start = .;
  kernel_lma_start = . - KERNEL_VMA;
  .text : AT(ADDR(.text) - KERNEL_VMA) ALIGN(4K) {
    KEEP(*(.text.kernel_boot))
    *(.text*)
  }

  .rodata : AT(ADDR(.rodata) - KERNEL_VMA) ALIGN(4K) {
    *(.rodata*)
  }

  .data : AT(ADDR(.data) - KERNEL_VMA) ALIGN(4K) { 
    *(.data*) 
  }
  
  .bss : AT(ADDR(.bss) - KERNEL_VMA) ALIGN(4K) { 
    *(COMMON)
    *(.bss*) 
  }
  kernel_vma_end = .;
  kernel_lma_end = . - KERNEL_VMA;

  /DISCARD/ : {
        *(.eh_frame*)
        *(.note*)
        *(.comment*)
  }
}
