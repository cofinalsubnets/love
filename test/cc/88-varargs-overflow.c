/* varargs past the register file: anonymous args on the caller stack. SysV
   overflows after 6 gp / 8 xmm; AAPCS64 after 8 gp / 8 vr -- so the counts here
   push BOTH ABIs into their stack lane, and the named-double wall (8 named
   doubles) starts the fp walk already exhausted. */
#include <stdarg.h>
long vsum(int n, ...) {
  va_list ap;
  va_start(ap, n);
  long s = 0;
  for (int i = 0; i < n; i++) s += va_arg(ap, long);
  va_end(ap);
  return s;
}
double dwall(double a, double b, double c, double d,
             double e, double f, double g, double h, int n, ...) {
  va_list ap;                          /* fp regs all named: every va_arg double is a stack read */
  va_start(ap, n);
  double s = a + b + c + d + e + f + g + h;
  for (int i = 0; i < n; i++) s += va_arg(ap, double);
  va_end(ap);
  return s;
}
int mixed(int n, ...) {                /* gp and fp walks interleaved across the seam */
  va_list ap;
  va_start(ap, n);
  long acc = 0;
  for (int i = 0; i < n; i++) { int k = va_arg(ap, int); acc += k * (int)va_arg(ap, double); }
  va_end(ap);
  return acc;
}
int main() {
  long a = vsum(10, 1L, 2L, 3L, 4L, 5L, 6L, 7L, 8L, 9L, 10L);  /* 55 -- longs: an int arg read as long is UB on the stack lane */
  double d = dwall(1, 1, 1, 1, 1, 1, 1, 1, 3, 2.0, 3.0, 4.0);  /* 8 + 9 = 17 */
  int m = mixed(5, 1, 2.0, 2, 3.0, 3, 4.0, 4, 5.0, 5, 6.0);    /* 2+6+12+20+30 = 70 */
  return (int)(a + d) + m - 55;                                /* 55 + 17 + 70 - 55 = 87 */
}
