/* variadic functions: the va_list walk over integer and pointer args */
#include <stdarg.h>
int isum(int n, ...) {
  va_list ap;
  va_start(ap, n);
  long s = 0;
  for (int i = 0; i < n; i++) s += va_arg(ap, int);
  va_end(ap);
  return s;
}
int slen(int n, ...) {                 /* total length of n strings */
  va_list ap;
  va_start(ap, n);
  int t = 0;
  for (int i = 0; i < n; i++) {
    char *p = va_arg(ap, char *);
    while (*p) { t++; p++; }
  }
  va_end(ap);
  return t;
}
int main() {
  int a = isum(5, 1, 2, 3, 4, 5);       /* 15 */
  int b = isum(2, 100, 200);            /* 300 -- even count exercises the align pad path too */
  int c = slen(3, "ab", "cde", "f");    /* 2+3+1 = 6 */
  return a + b + c - 300;               /* 15 + 300 + 6 - 300 = 21 */
}
