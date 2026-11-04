/* a call through a typedef'd function type's pointer converts its args by the typedef's
 * prototype: a float stays a float, a char narrows, a struct member and a local alike.
 * a variadic typedef keeps the default promotions. exit-code only (28) */
#include <stdarg.h>

typedef float F(float, char);
typedef double V(int, ...);
typedef short S(short, unsigned char);

static float half(float x, char c) { return x / 2 + c; }
static double sum(int n, ...) {
  va_list ap; va_start(ap, n);
  double t = 0;
  while (n--) t += va_arg(ap, double);
  va_end(ap);
  return t;
}
static short wrap(short a, unsigned char b) { return a + b; }

struct T { F *f; V *v; S *s; };

int main(void) {
  struct T t = { half, sum, wrap };
  F *q = half;
  float a = t.f(3.0f, 1);                 /* 2.5 */
  float b = q(5.0f, 1);                   /* 3.5 */
  double c = t.v(2, 1.5f, 2.5);           /* 4.0, the float promoted */
  short d = t.s(30000, 300);              /* 30000 + (unsigned char)300 = 30044 */
  if (a != 2.5f || b != 3.5f || c != 4.0 || d != 30044) return 1;
  return (int)(a * 4 + b * 4 + c);        /* 10 + 14 + 4 = 28 */
}
