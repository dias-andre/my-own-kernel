#include <memory/memory_manager.h>
#include <memory/liballoc.h>
#include <video/vga_buffer.h>
#include <memory/paging.h>

#define KB 1024
int init_mmu() {
    init_page_allocator(1024);
    heap_init();
    println("MMU: Memory Manager Unit - Started");
}