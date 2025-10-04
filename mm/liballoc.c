#include <memory/memory_manager.h>
#include <memory/liballoc.h>
#include <memory/paging.h>
#include <stddef.h>
#include <stdint.h>
#include <video/vga_buffer.h>
#include <memory/spinlock.h>

uintptr_t heap_top = 0;
uintptr_t lastblock = 0;

#define ALIGN_16(x) (((x) + 15) & ~15)

static spinlock_t heap_lock;

void heap_init()
{
  spinlock_init(&heap_lock, "heap");
  heap_block_t *heap_start = (heap_block_t *)KERNEL_HEAP_BASE;
  heap_start->size = ALIGN_16(size_t); // Alinha o tamanho do bloco
  heap_start->next = NULL;
  heap_start->free = 1;
  heap_top = (uintptr_t)heap_start;
  lastblock = heap_top;
  uintptr_t a = push_block(8);
  println("MMU: Heap Initialized!");
}

uintptr_t find_free_block(size_t size)
{
  heap_block_t *block = (heap_block_t *)heap_top;

  while (block->next != NULL)
  {
    if (block->free && block->size >= size)
    {
      block->free = 0;
      return (uintptr_t)block;
    }
    block = block->next;
  }
  return NULL;
}

uintptr_t find_block(uintptr_t address)
{
  heap_block_t *block = (heap_block_t *)heap_top;
  while (block != NULL)
  {
    if ((uintptr_t)(block) + sizeof(heap_block_t) == address)
    {
      return (uintptr_t)block;
    }
    block = block->next;
  }

  return NULL;
}

uintptr_t return_memory(heap_block_t *block)
{
  return (uintptr_t)(sizeof(heap_block_t) + (uintptr_t)(block));
}

// Exemplo de modificação em push_block()
uintptr_t push_block(size_t size)
{
  spinlock_lock(&heap_lock);

  size = ALIGN_16(size); // Alinha o tamanho
  heap_block_t *block = (heap_block_t *)lastblock;

  uintptr_t new_block_addr = (uintptr_t)block + block->size + sizeof(heap_block_t);

  // Trata overflow de endereço
  if (new_block_addr < (uintptr_t)block)
  {
    uintptr_t new_page = alloc_page();
    if (!new_page)
      return 0; // Falha
    new_block_addr = new_page;
  }

  heap_block_t *new_block = (heap_block_t *)new_block_addr;
  new_block->size = size;
  new_block->next = NULL;
  new_block->free = 1;

  block->next = new_block;
  lastblock = (uintptr_t)new_block;

  spinlock_unlock(&heap_lock);
  return (uintptr_t)(new_block + 1); // Retorna endereço após o cabeçalho
}

uintptr_t kmalloc(size_t size)
{
  // Does thie header have an End of Memory Status?
  uintptr_t free_addr = find_free_block(size);
  // Yes: Allocate more blocks
  if (free_addr == NULL)
  {
    heap_block_t *new_block = (heap_block_t *)push_block(size);
    new_block->free = 0;
    return return_memory(new_block);
  }
  return return_memory((heap_block_t *)free_addr);
}

int kfree(uintptr_t address)
{
  uintptr_t block_addr = find_block(address);
  if (block_addr == NULL)
  {
    return -1;
  }

  heap_block_t *block = (heap_block_t *)block_addr;
  block->free = 1;
  return 0;
}

uintptr_t alloc_page(void)
{
  // Aloca uma página física
  uintptr_t phys = alloc_physical_page();
  if (!phys)
  {
    return 0; // Falha ao alocar página física
  }

  // Obtém o endereço virtual atual
  uintptr_t virt = lastblock;

  // Mapeia a página física no endereço virtual
  lastblock += PAGE_SIZE;
  map_page(virt, phys, PAGE_PRESENT | PAGE_WRITABLE);
  return virt;
}