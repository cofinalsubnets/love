/* SysV varargs: a va_list handed to a helper (the love.c gvzprintf/ai_pushr shape),
   mixed int/double variadic reads through the register save area, and an array
   parameter decaying to a pointer. */
#include <stdarg.h>
int drain(int n, va_list ap) {          /* a va_list PARAMETER (decays to a pointer) */
  long s = 0;
  for (int i = 0; i < n; i++) s += va_arg(ap, int);
  return s;
}
int isum(int n, ...) {
  va_list ap;
  va_start(ap, n);
  int r = drain(n, ap);                 /* pass the va_list on */
  va_end(ap);
  return r;
}
double dmix(int n, ...) {               /* alternating int tag then a double */
  va_list ap;
  va_start(ap, n);
  double acc = 0.0;
  for (int i = 0; i < n; i++) { int k = va_arg(ap, int); acc += k * va_arg(ap, double); }
  va_end(ap);
  return acc;
}
int asum(int a[], int n) {              /* an array parameter -> a pointer */
  int s = 0;
  for (int i = 0; i < n; i++) s += a[i];
  return s;
}
int main() {
  int r = isum(4, 1, 2, 3, 4);              /* 10 */
  r = r + (int)dmix(2, 3, 2.0, 2, 5.0);     /* 3*2 + 2*5 = 16 -> 26 */
  int x[3] = {5, 6, 5};
  r = r + asum(x, 3);                       /* +16 = 42 */
  return r;
}
