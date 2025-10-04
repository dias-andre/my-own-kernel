#include <stddef.h>
#include <stdint.h>

typedef struct heap_block {
    size_t size;
    struct heap_block *next;
    int free;
} heap_block_t;

extern uintptr_t heap_top;

extern void heap_init();
extern uintptr_t find_free_block(size_t size);
extern uintptr_t push_block(size_t size);

extern uintptr_t kmalloc(size_t size);
extern int kfree(uintptr_t addr);
//extern uintptr_t krealloc(uintptr_t addr, size_t size);