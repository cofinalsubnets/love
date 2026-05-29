#include <stddef.h>
#include <stdint.h>
int memcmp(void const *s1, void const *s2, size_t n) {
  const uint8_t *p1 = s1, *p2 = s2;
  for (size_t i = 0; i < n; i++)
    if (p1[i] != p2[i]) return p1[i] < p2[i] ? -1 : 1;
  return 0; }
