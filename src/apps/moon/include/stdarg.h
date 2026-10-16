/* stdarg.h for mooncc: the target's real va_list, laid as gcc's so variadics link across
 * compilers. an array of one, so it decays to a pointer; aapcs64's offsets are negative. */
#ifndef _CC_STDARG_H
#define _CC_STDARG_H

/* gcc/clang's builtins insist on their own va_list; mooncc claims __GNUC__ but lays its own */
#if (defined(__GNUC__) || defined(__clang__)) && !defined(__mooncc__)
typedef __builtin_va_list __gnuc_va_list;
#else
#ifdef __aarch64__
typedef struct {
  void *__stack;                 /* the next anonymous arg on the caller stack */
  void *__gr_top;                /* one past the x0..x7 save area */
  void *__vr_top;                /* one past the q0..q7 save area */
  int __gr_offs;                 /* -(unnamed gp slots)*8, rising by 8 to 0 */
  int __vr_offs;                 /* -(unnamed vr slots)*16, rising by 16 to 0 */
} __va_list_tag;
#elif defined(__arm__) || defined(__i386__)
typedef struct {                 /* aapcs32: one pointer; r0-r3 pushed contiguous with stack args */
  void *__ap;
} __va_list_tag;
#elif defined(__riscv)
typedef struct {                 /* lp64: one pointer, 8-byte slots, gp registers only */
  void *__ap;
} __va_list_tag;
#else
typedef struct {
  int gp_offset;
  int fp_offset;
  void *overflow_arg_area;
  void *reg_save_area;
} __va_list_tag;
#endif

typedef __va_list_tag __gnuc_va_list[1];
#endif

/* glibc headers we do not carry spell the type __gnuc_va_list */
#ifndef __GNUC_VA_LIST
#define __GNUC_VA_LIST
#endif
typedef __gnuc_va_list va_list;

#define va_start(ap, last) __builtin_va_start(ap, last)
#define va_arg(ap, type)   __builtin_va_arg(ap, type)
#define va_end(ap)         __builtin_va_end(ap)
#if (defined(__GNUC__) || defined(__clang__)) && !defined(__mooncc__)
#define va_copy(dst, src)  __builtin_va_copy(dst, src)
#else
#define va_copy(dst, src)  ((dst)[0] = (src)[0])
#endif

#endif
