#include <stddef.h>
#include <stdint.h>

void *memcpy(void *restrict dest, void const *restrict src, size_t n) {
  uint8_t *restrict pdest = dest;
  uint8_t const *restrict psrc = src;
  for (size_t i = 0; i < n; i++) pdest[i] = psrc[i];
  return dest; }
