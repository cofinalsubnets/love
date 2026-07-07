/* stdarg.h -- crew/cc's own, for `au cc`. the compiler implements the three
 * __builtin_va_* forms directly; a va_list is just a cursor over the caller's
 * stack argument block (cc's simplified variadic ABI -- see doc/cc.md stage 6c).
 * gcc uses its OWN <stdarg.h> in the differential; both are self-consistent. */
#ifndef _CC_STDARG_H
#define _CC_STDARG_H

typedef char *va_list;

#define va_start(ap, last) __builtin_va_start(ap, last)
#define va_arg(ap, type)   __builtin_va_arg(ap, type)
#define va_end(ap)         __builtin_va_end(ap)
#define va_copy(dst, src)  ((dst) = (src))

#endif
