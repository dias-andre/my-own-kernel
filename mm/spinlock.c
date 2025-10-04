#include "spinlock.h"

// Instrução PAUSE para eficiência (evita busy-wait)
#define CPU_PAUSE() __asm__ volatile("pause")

// Barreira de memória (compiler + hardware)
#define MEMORY_BARRIER() __asm__ volatile("" ::: "memory")

// Função para desabilitar interrupções (simulada)
static inline uint64_t disable_irq() {
    uint64_t flags;
    __asm__ volatile (
        "pushfq\n\t"
        "pop %0\n\t"
        "cli" 
        : "=r" (flags)
        :
        : "memory"
    );
    return flags;
}

// Função para restaurar interrupções
static inline void restore_irq(uint64_t flags) {
    __asm__ volatile (
        "push %0\n\t"
        "popfq"
        :
        : "r" (flags)
        : "memory"
    );
}

// Inicializa o lock
void spinlock_init(spinlock_t *lock, const char *name) {
    lock->locked = 0;
    lock->name = name;
}

// Tenta adquirir o lock (atomicamente)
void spinlock_lock(spinlock_t *lock) {
    while (1) {
        // Tentativa de aquisição atômica
        uint32_t expected = 0;
        __asm__ volatile (
            "lock cmpxchgl %2, %1\n\t"
            : "+a" (expected), "+m" (lock->locked)
            : "r" (1)
            : "memory"
        );

        if (expected == 0) break;  // Sucesso!
        CPU_PAUSE();  // Espera ocupada otimizada
    }
    MEMORY_BARRIER();
}

// Libera o lock
void spinlock_unlock(spinlock_t *lock) {
    MEMORY_BARRIER();
    __atomic_store_n(&lock->locked, 0, __ATOMIC_RELEASE);
}

// Versão que desabilita interrupções
void spinlock_lock_irqsave(spinlock_t *lock, uint64_t *flags) {
    *flags = disable_irq();
    spinlock_lock(lock);
}

// Versão que restaura interrupções
void spinlock_unlock_irqrestore(spinlock_t *lock, uint64_t flags) {
    spinlock_unlock(lock);
    restore_irq(flags);
}