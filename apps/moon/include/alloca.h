#ifndef _AI_ALLOCA_H
#define _AI_ALLOCA_H
#include <stddef.h>      /* size_t */
/* nolibc's alloca is gnulib's C_ALLOCA scheme (malloc-backed, depth-GC'd
   on the next call) -- a plain function, no builtin, so a prototype is
   the whole header. without this the <> resolver falls through to
   glibc's alloca.h and its <features.h> machinery (m4-1.4 regex.c). */
void *alloca(size_t);
#endif
