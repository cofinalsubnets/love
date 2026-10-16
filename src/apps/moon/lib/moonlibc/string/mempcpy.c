#include "../impl.h"

/* gnu: memcpy answering its end */
void *mempcpy(void *d, void const *s, size_t n) { return (char *) memcpy(d, s, n) + n; }
