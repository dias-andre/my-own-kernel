#include <memory/memory_manager.h>
#include <memory/liballoc.h>
#include <stddef.h>
#include <stdint.h>
#include <memory/page_allocator.h>
#include <video/vga_buffer.h>

uintptr_t heap_top = 0;
uintptr_t lastblock = 0;

void heap_init(uintptr_t start) {
    heap_block_t *heap_start = (heap_block_t *)start;
    heap_start->size = 8;
    heap_start->next = NULL;
    heap_start->free = 1;
    heap_top = (uintptr_t)heap_start;
    lastblock = heap_top;
    uintptr_t a = push_block(8);
    println("MMU: Heap Initialized!");
}

uintptr_t find_free_block(size_t size) {
    heap_block_t *block = (heap_block_t*)heap_top;

    while(block->next != NULL) {
        if(block->free && block->size >= size) {
            block->free = 0;
            return (uintptr_t)block;
        }
        block = block->next;
    }
    return NULL;
}

uintptr_t find_block(uintptr_t address) {
    heap_block_t *block = (heap_block_t*)heap_top;
    while(block != NULL) {
        if((uintptr_t)(block) + sizeof(heap_block_t) == address) {
            return (uintptr_t)block;
        }
        block = block->next;
    }

    return NULL;
}

uintptr_t return_memory(heap_block_t *block) {
    return (uintptr_t)(sizeof(heap_block_t) + (uintptr_t)(block));
}

uintptr_t push_block(size_t size) {
    heap_block_t *block = (heap_block_t *)heap_top;

    // Se não encontrou bloco livre, expandir a heap
    int memory_needed = size + sizeof(heap_block_t);
    uintptr_t new_block_addr = (uintptr_t)(block) + block->size + sizeof(heap_block_t);

    // Se passar do limite da página, alocar nova página
    if (new_block_addr + memory_needed > heap_top + PAGE_SIZE) {
        uintptr_t new_page = alloc_page();
        if (new_page == 0) {
            return 0;  // Falha ao alocar nova página
        }
        new_block_addr = new_page;
    }

    heap_block_t *new_block = (heap_block_t *)new_block_addr;
    new_block->size = size;
    new_block->next = NULL;
    new_block->free = 1;

    block->next = new_block;  // Conectar novo bloco
    lastblock = new_block;  // Atualizar último bloco

    return (uintptr_t)(new_block);
}

uintptr_t kmalloc(size_t size) {
    // Does thie header have an End of Memory Status?
    uintptr_t free_addr = find_free_block(size);
    // Yes: Allocate more blocks
    if(free_addr == NULL) {
        heap_block_t *new_block = (heap_block_t*)push_block(size);
        new_block->free = 0;
        return return_memory(new_block);
    }
    return return_memory((heap_block_t*)free_addr);
}

int kfree(uintptr_t address) {
    uintptr_t block_addr = find_block(address);
    if(block_addr == NULL) {
        return -1;
    }

    heap_block_t *block = (heap_block_t*)block_addr;
    block->free = 1;
    return 0;
}

