// src/love/alloc.c -- the runtime's heap over malloc and free: every pool the collector takes
// comes through alloc. a plain definition, not a weak default: a seat with its own heap
// defines alloc instead of linking this, and linking both collides loudly
#include "love.h"

void *alloc(void *p, size_t n) { return n ? malloc(n) : (free(p), NULL); }
