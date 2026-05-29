#include <stddef.h>
void *memchr(void const *s, int c, size_t n) {
  for (unsigned char const *p = s; n-- ; p++)
    if (*p == (int) c) return (void*) p;
  return NULL; }
