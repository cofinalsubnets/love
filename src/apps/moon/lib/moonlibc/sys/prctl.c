#include "../impl.h"
#include <stdarg.h>

/* linux's alone: the BSDs answer ENOSYS */
int prctl(int op, ...) {
  if (__love_osv >= 2) { errno = ENOSYS; return -1; }
  va_list ap;
  va_start(ap, op);
  long a = va_arg(ap, long), b = va_arg(ap, long), c = va_arg(ap, long), d = va_arg(ap, long);
  va_end(ap);
  return (int) er(sc5(NR_prctl, op, a, b, c, d)); }
