#include <memory/paging.h>
#include <memory/memory_manager.h>
#include <video/vga_buffer.h>
#include "stdint.h"
#include "stddef.h"
#include "string.h"

static uint8_t *bitmap;
static size_t total_pages;

// PML4 by CR3
uint64_t get_pml4()
{
  uint64_t cr3;
  asm volatile("mov %%cr3, %0" : "=r"(cr3));
  return cr3;
}

uintptr_t get_physaddr(uintptr_t virt)
{
  uint64_t pml4_idx = (virt >> 39) & 0x1FF;
  uint64_t pdp_idx = (virt >> 30) & 0x1FF;
  uint64_t pd_idx = (virt >> 21) & 0x1FF;
  uint64_t pt_idx = (virt >> 12) & 0x1FF;

  pte_t *pml4 = (pte_t *)get_pml4();
  pte_t *pdp = (pte_t *)(pml4[pml4_idx] & ~0xFFF);
  pte_t *pd = (pte_t *)(pdp[pdp_idx] & ~0xFFF);
  pte_t *pt = (pte_t *)(pd[pd_idx] & ~0xFFF);

  return (uintptr_t)((pt[pt_idx] & ~0xFFF) + ((unsigned long)virt & 0xFFF));
}

void map_page(uint64_t virt, uint64_t phys, uint64_t flags)
{
  // Extrair índices dos níveis da tabela de páginas
  uint64_t pml4_idx = (virt >> 39) & 0x1FF;
  uint64_t pdp_idx = (virt >> 30) & 0x1FF;
  uint64_t pd_idx = (virt >> 21) & 0x1FF;
  uint64_t pt_idx = (virt >> 12) & 0x1FF;

  // Obter tabela PML4 (nível 4)
  uint64_t *pml4 = (uint64_t *)get_pml4();

  // Verificar/criar PDPT (nível 3)
  if (!(pml4[pml4_idx] & 1))
  {
    pml4[pml4_idx] = alloc_physical_page() | 0x03; // Presente + Read/Write
  }
  uint64_t *pdp = (uint64_t *)(pml4[pml4_idx] & ~0xFFF);

  // Verificar/criar PD (nível 2)
  if (!(pdp[pdp_idx] & 1))
  {
    pdp[pdp_idx] = alloc_physical_page() | 0x03;
  }
  uint64_t *pd = (uint64_t *)(pdp[pdp_idx] & ~0xFFF);

  // Verificar/criar PT (nível 1)
  if (!(pd[pd_idx] & 1))
  {
    pd[pd_idx] = alloc_physical_page() | 0x03;
  }
  uint64_t *pt = (uint64_t *)(pd[pd_idx] & ~0xFFF);

  // Mapear a página física
  pt[pt_idx] = (phys & ~0xFFF) | flags | 0x01; // Presente + flags

  // Invalidar entrada no TLB
  asm volatile("invlpg (%0)" : : "r" (virt) : "memory");
}

void init_page_allocator(uint64_t total_memory_bytes)
{
  total_pages = total_memory_bytes / PAGE_SIZE;
  size_t bitmap_size = (total_pages + 7) / 8;

  bitmap = (uint8_t *)0x10000;
  memset(bitmap, 0, bitmap_size);
}

static void set_bit(size_t index)
{
  bitmap[index / 8] |= (1 << (index % 8));
}

static void clear_bit(size_t index)
{
  bitmap[index / 8] &= ~(1 << (index % 8));
}

static int is_bit_set(size_t index)
{
  return bitmap[index / 8] & (1 << (index % 8));
}

uintptr_t alloc_physical_page()
{
  for (size_t i = 0; i < total_pages; i++)
  {
    if (!is_bit_set(i))
    {
      set_bit(i);
      uint64_t addr = i * PAGE_SIZE;
      if (addr & 0xFFF)
        println("Unaligned physical page");
      return addr;
    }
  }
  println("Out of memory");
}

void free_physical_page(uint64_t phys_addr)
{
  size_t page_index = phys_addr / PAGE_SIZE;
  if (page_index >= total_pages)
    return;
  clear_bit(page_index);
}

void *alloc_virtual_page(uint64_t virt_addr, uint64_t flags)
{
  uint64_t phys = alloc_physical_page();
  map_page(virt_addr, phys, flags);
  return (void *)virt_addr;
}