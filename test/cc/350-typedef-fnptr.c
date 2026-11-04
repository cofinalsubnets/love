/* a call through a typedef'd function type's pointer converts its args by the typedef's
 * prototype: a float stays a float, a char narrows, a struct member and a local alike.
 * exit-code only (24) */

typedef float F(float, char);
typedef short S(short, unsigned char);

static float half(float x, char c) { return x / 2 + c; }
static short wrap(short a, unsigned char b) { return a + b; }

struct T { F *f; S *s; };

int main(void) {
  struct T t = { half, wrap };
  F *q = half;
  float a = t.f(3.0f, 1);                 /* 2.5 */
  float b = q(5.0f, 1);                   /* 3.5 */
  short d = t.s(30000, 300);              /* 30000 + (unsigned char)300 = 30044 */
  if (a != 2.5f || b != 3.5f || d != 30044) return 1;
  return (int)(a * 4 + b * 4);            /* 10 + 14 = 24 */
}
