#include <stdint.h>
typedef uint64_t pte_t;

typedef struct {
  pte_t entries[512];
} pt_table_t;

extern uintptr_t get_physaddr(uintptr_t);
extern void init_page_allocator(uint64_t);
extern void map_page(uint64_t, uint64_t, uint64_t);
extern uintptr_t alloc_physical_page(void);
extern uintptr_t alloc_page(void);

// Bits padrão (presentes em PML4, PDP, PD, PT)
#define PAGE_PRESENT     0x001   // Bit 0: Página presente
#define PAGE_WRITABLE    0x002   // Bit 1: Leitura/escrita
#define PAGE_USER        0x004   // Bit 2: Acesso em user mode
#define PAGE_PWT         0x008   // Bit 3: Write-Through caching
#define PAGE_PCD         0x010   // Bit 4: Cache disable
#define PAGE_ACCESSED    0x020   // Bit 5: Acessado (setado pela CPU)
#define PAGE_DIRTY       0x040   // Bit 6: Modificado (apenas em PTEs)
#define PAGE_PAT         0x080   // Bit 7: Page Attribute Table (uso geral)
#define PAGE_GLOBAL      0x100   // Bit 8: Página global (TLB)

// Uso especial em PDP/PD (quando PS=1)
#define PAGE_HUGE        0x080   // Bit 7: Páginas de 1GB (PDP) ou 2MB (PD)

// Bit 63 (NX/XD - No eXecute)
#define PAGE_NX          0x8000000000000000ULL  // ULL para 64 bits