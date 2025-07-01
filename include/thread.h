#ifndef TSS_H
#define TSS_H

#include <stdint.h>

typedef struct
{
  uint64_t rsp0; // Stack para modo kernel (RPL=0)
  uint64_t rsp1; // Reservado
  uint64_t rsp2; // Reservado
  uint64_t reserved1;
  uint64_t ist[7]; // Pilhas para interrupções (IST)
  uint64_t reserved2;
  uint16_t reserved3;
  uint16_t iomap_base; // Offset do I/O bitmap (ou sizeof(tss_t))
} __attribute__((packed, aligned(16))) tss_t;

void tss_init(uint64_t rsp0);
void load_tss();

#endif // TSS_H