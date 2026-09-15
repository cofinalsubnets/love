/* C11 6.5.15p6: in a conditional expression one operand being a NULL POINTER
 * CONSTANT gives the result the OTHER operand's type -- and a cast is a null
 * pointer constant only when its operand is a constant expression. that is the
 * whole of the kernel's __is_constexpr (include/linux/compiler.h), which
 * const_true() and min()/max() ask before they choose a lane. held to gcc. */
#include <stdio.h>

#define ISCE(x) (sizeof(int) == sizeof(*(8 ? ((void *) ((long) (x) * 0l)) : (int *) 8)))
#define CT(x)   __builtin_choose_expr(ISCE(x), x, 0)

static int nonconst(int v) { return ISCE(v > 3); }

int main(void)
{
  int v = 5;
  int a = ISCE(4 > 3);                  /* a constant operand: the int * type */
  int b = nonconst(v);                  /* not: plain void *, so sizeof(void) */
  int c = CT(4 > 3);                    /* the true arm */
  int d = CT(v > 3);                    /* .. and the false one */
  /* the plain shapes of the same paragraph */
  int e = (int) sizeof(*(1 ? (int *) 8 : (void *) 0));
  int f = (int) sizeof(*(1 ? (void *) 0 : (char *) 8));
  int g = (int) sizeof(1 ? (void *) 8 : (char *) 8);   /* both real: a pointer either way */
  int h = (int) sizeof(v ? 1 : 2L);                    /* the arithmetic lane still meets by uac */
  printf("%d %d %d %d %d %d %d %d\n", a, b, c, d, e, f, g, h);
  return (a + b + c + d + e + f + g + h) & 0x7f;
}
