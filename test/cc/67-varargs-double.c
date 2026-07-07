/* variadic with double args and a named double param before the ... */
#include <stdarg.h>
double dsum(double base, int n, ...) {
  va_list ap;
  va_start(ap, n);
  double s = base;
  for (int i = 0; i < n; i++) s += va_arg(ap, double);
  va_end(ap);
  return s;
}
int tagged(int n, ...) {                /* mixed int/double, selected by a tag */
  va_list ap;
  va_start(ap, n);
  long acc = 0;
  for (int i = 0; i < n; i++) {
    int tag = va_arg(ap, int);
    if (tag == 0) acc += va_arg(ap, int);
    else acc += (int)va_arg(ap, double);
  }
  va_end(ap);
  return acc;
}
int main() {
  double d = dsum(1.5, 3, 2.5, 3.0, 4.0);   /* 1.5+2.5+3+4 = 11.0 */
  int t = tagged(3, 0, 10, 1, 5.5, 0, 20);  /* 10 + 5 + 20 = 35 */
  return (int)d + t;                         /* 11 + 35 = 46 */
}
