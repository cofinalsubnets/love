#include "../impl.h"
/* linux's mechanism; off the map, so a bsd kernel answers ENOSYS (sqlite falls back to
   unmap and map again). MREMAP_FIXED's fifth operand rides the varargs */
#include <stdarg.h>
void *mremap(void *a, unsigned long old, unsigned long n, int fl, ...) {
  va_list ap; void *to;
  va_start(ap, fl); to = fl & 2 ? va_arg(ap, void *) : (void *) 0; va_end(ap);
  long r = sc5(NR_mremap, (long) a, (long) old, (long) n, fl, (long) to);
  if ((unsigned long) r > (unsigned long) -4096L) { __errno_v = (int) -r; return (void *) -1; }
  return (void *) r; }
