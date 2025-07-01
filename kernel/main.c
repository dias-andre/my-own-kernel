#include <video/vga_buffer.h>
#include <video/colors.h>
#include <memory/memory_manager.h>
#include <thread.h>

#ifndef DEBUG
//#define DEBUG
#endif

extern void load_idt(void);

int verify_long_mode() {
  uint64_t cr0;
  asm volatile("mov %%cr0, %0" : "=r" (cr0));

  if(!(cr0 & (1 << 31))) {
    println("Paging disabled.");
    return 1;
  }

  uint64_t cr4;
  asm volatile("mov %%cr4, %0" : "=r" (cr4));

  if(!(cr4 & (1 << 5))) {
    println("PAE disabled.");
    return 1;
  }

  uint32_t efer;
  asm volatile("rdmsr": "=a" (efer) : "c" (0xC0000080));

  if(!(efer & (1 << 8))) {
    println("Long mode disabled.");
    return 1;
  }

  uint16_t cs;
  asm volatile("mov %%cs, %0" : "=r" (cs));

  // O bit L está no bit 1 do atributo do segmento (não diretamente no seletor)
  // Precisamos verificar o descritor na GDT
  uint64_t cs_descriptor;
  asm volatile("sgdt %0" : "=m" (cs_descriptor));
  // Implementação mais robusta seria necessária para verificar o descritor
    
  // Alternativa simplificada (pode não ser 100% confiável)
  if (!(efer & (1 << 10))) {  // Verifica EFER.LMA (indica que o modo longo está ativo)
      println("The CPU is not running in long mode.");
      return 1;
  }

  return 0;
}

void kernel_main() {
  vga_init();

  int long_mode = verify_long_mode();
  if (long_mode != 0) {
    while( 1 );
  }

  println("64-Bit Mode");
  println("Paging initialized!");
  println("GDT Loaded!");
  load_idt();
  println("IDT Loaded!");
  init_mmu();

  set_vga_color_code(color_code(Black, LightGreen));
  println("Kernel Ready!");

  while( 1 );
}
