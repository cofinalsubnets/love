/* stdarg.h -- crew/cc's own, for `aicc`. cc implements the three __builtin_va_*
 * forms directly, over the System V AMD64 va_list: a 24-byte struct that cc's
 * variadic prologue feeds from a register save area. it is an array of one so it
 * DECAYS to a pointer when passed to another function (the C `va_list` habit --
 * ai.c's gvzprintf/ai_pushr take one), and va_arg mutates the shared state. the
 * offset fields are `int` (cc has no `unsigned` yet; the values are 0..176).
 * this MATCHES gcc's ABI, so a cc-compiled variadic function (ai_push) is callable
 * from the gcc-built host objects and vice versa. */
#ifndef _CC_STDARG_H
#define _CC_STDARG_H

typedef struct {
  int gp_offset;
  int fp_offset;
  void *overflow_arg_area;
  void *reg_save_area;
} __va_list_tag;

typedef __va_list_tag va_list[1];

#define va_start(ap, last) __builtin_va_start(ap, last)
#define va_arg(ap, type)   __builtin_va_arg(ap, type)
#define va_end(ap)         __builtin_va_end(ap)
#define va_copy(dst, src)  ((dst)[0] = (src)[0])

#endif
