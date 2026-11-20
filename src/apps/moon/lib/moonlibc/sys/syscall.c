#include "../impl.h"
#include <stdarg.h>

/* the kernel's own number, raw: no translation on a BSD, -1 and errno on an error */
long syscall(long n, ...) {
  va_list ap;
  va_start(ap, n);
  long a = va_arg(ap, long), b = va_arg(ap, long), c = va_arg(ap, long),
       d = va_arg(ap, long), e = va_arg(ap, long), f = va_arg(ap, long);
  va_end(ap);
  long r = __love_osv >= 2 ? __love_fb(n, a, b, c, d, e, f) : __love_call(n, a, b, c, d, e, f);   /* inle answers below */
  return er(r); }
