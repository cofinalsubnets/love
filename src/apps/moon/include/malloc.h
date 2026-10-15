#ifndef _LOVE_MALLOC_H
#define _LOVE_MALLOC_H
#include <stdlib.h>
void  *memalign(size_t, size_t);
size_t malloc_usable_size(void*);
#endif
