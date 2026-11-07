// a constant float expression answers as the same arithmetic at run time, float casts rounding where written
#ifdef SHOW
#include <stdio.h>
#endif
static unsigned long long hash = 14695981039346656037ULL;
static void bits(const void *p, int n) {
  const unsigned char *b = p;
#ifdef SHOW
  for (int i = n - 1; i >= 0; i--) printf("%02x", b[i]);
  puts("");
#endif
  for (int i = 0; i < n; i++) hash = (hash ^ b[i]) * 1099511628211ULL; }
typedef float flo_t;
volatile double a = 32.0, b = 255.0, c = 1e9, z = 0.0, t3 = 3.0, big = 1e39;
volatile float f1 = 1.0f, f3 = 3.0f;
#define F(x) do { float v_ = (x); bits(&v_, sizeof v_); } while (0)
#define D(x) do { double v_ = (x); bits(&v_, sizeof v_); } while (0)
int main(void) {
  F((flo_t) -1e9); F((flo_t) -c);
  F((flo_t) (32.0 / 255)); F((flo_t) (a / b));
  D(32.0 / 255); D(a / b);
  D(1.0 / 3 + 2.5 * 4 - 1); D(1.0 / t3 + 2.5 * 4 - 1);
  D(-0.0); D(0.0 * -1.0); D(-z); D(z * -1.0);
  F((float) 1e39); F((float) big);
  D(1.0 / 0.0 > 0 ? 1.0 : 2.0);
  D((1.0f / 3) * 3.0); D((f1 / f3) * t3);
  F((float) (1.0 / 3)); F((float) (f1 / t3));
  F(1.0f / 3); F(f1 / f3);
  F((float) 1.00000005960464477539); F((float) (1.0 + 5.9604644775390625e-8));
  D(-0.1); D(-1.0 / 3); D(-z - 0.1); D(0.0 - 1.0 / t3); F((float) -0.1); F((float) -a / 320.0f);
  D(0.1 + 0.2); D((1 + 2) * 1.5); D(1 / 2 * 3.0); D(7 / 2.0);
  return (int) ((hash ^ hash >> 32) % 251);
}
