#pragma once
#include <stdint.h>

typedef struct {
    volatile uint32_t locked;  // 0 = livre, 1 = travado
    const char* name;         // Para debug (opcional)
} spinlock_t;

// Inicialização
void spinlock_init(spinlock_t *lock, const char *name);

// Operações básicas
void spinlock_lock(spinlock_t *lock);
void spinlock_unlock(spinlock_t *lock);

// Versões com controle de interrupções (para kernel)
void spinlock_lock_irqsave(spinlock_t *lock, uint64_t *flags);
void spinlock_unlock_irqrestore(spinlock_t *lock, uint64_t flags);