#define PAGE_SIZE 4096

#include "stdint.h"
#include "stddef.h"

#define PAGE_SIZE 4096

#define PHYSICAL_BASE  0x00000000  // Endereço real onde começa a memória física

#define KERNEL_CODE 0xFFFFFFFF80000000
#define KERNEL_HEAP_BASE 0xFFFF800000000000ULL
#define MMAP 0xFFFF880000000000
#define USER_HEAP 0x0000700000000000
extern int init_mmu();
