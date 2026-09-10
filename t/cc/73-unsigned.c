/* stage 7c-ii: hex/suffix literals, unsigned types, and unsigned semantics --
   logical >>, unsigned compare, unsigned divide/modulo, zero-extending loads. */
#include <stdint.h>

static uint32_t hashstep(uint32_t h, uint32_t k) {
  h = h ^ k;
  h = h * 0x01000193U;          /* FNV prime, unsigned wrap */
  return h >> 13;               /* logical shift */
}

int main(void) {
  uint64_t hi = 0x8000000000000000UL;
  uint32_t big = 4000000000U;   /* > INT32_MAX */
  uint8_t  by  = 0xC8;          /* 200, must zero-extend */
  uint16_t hw  = 0xFFFF;        /* 65535 */
  int r = 0;

  r += (int)(hi >> 63);                 /* logical -> 1  (arith -> -1) */
  r += (big > 3000000000U);             /* unsigned compare -> 1 */
  r += (int)(by >> 1);                  /* 200 >> 1 = 100 */
  r += (int)(250UL % 100UL);            /* 50 */
  r += (int)(1000UL / 333UL);           /* 3 */
  r += (int)(hw >> 14);                 /* 65535 >> 14 = 3 */
  r += (int)(hashstep(2166136261U, 42) & 0xF); /* some small unsigned nibble */
  r += (0xFF & 0x0F);                   /* 15 */
  return r & 0xFF;
}
