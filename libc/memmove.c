#include <stddef.h>
#include <stdint.h>

void *memmove(void *dest, void const *src, size_t n) {
  uint8_t *pdest = dest;
  const uint8_t *psrc = src;
  if (src > dest)
    for (size_t i = 0; i < n; i++) pdest[i] = psrc[i];
  else if (src < dest)
    for (size_t i = n; i > 0; i--) pdest[i-1] = psrc[i-1];
  return dest; }
