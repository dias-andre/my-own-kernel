ENTRY(kernel_boot)

SECTIONS {
  . = 0x100000;
  _start = .;
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

  _end = .;

  /DISCARD/ : {
        *(.eh_frame*)
        *(.note*)
        *(.comment*)
  }
}
