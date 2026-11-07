// a 16-bit element read by index: bare, signed, a struct's member past a displacement, and a far table
#include <stdio.h>
#include <stdint.h>
struct e { uint16_t b; uint8_t s, n; };
struct t { char pad[3144]; struct e a[8]; uint16_t h[8]; };
static struct t g;
static uint16_t f[20000];
static int16_t n[8];

__attribute__((noinline)) static unsigned bare(const uint16_t *p, long i) { return p[i]; }
__attribute__((noinline)) static long sign(const int16_t *p, long i) { return p[i]; }
__attribute__((noinline)) static unsigned memb(struct t *t, long i) { return t->a[i].b + t->a[i].n; }
__attribute__((noinline)) static unsigned odd(const char *p, long i) { return *(const uint16_t *) (p + 2 * i + 2); }
__attribute__((noinline)) static unsigned hfar(struct t *t, long i) { return t->h[i]; }

int main(void) {
 unsigned long s = 0;
 for (int i = 0; i < 8; i++) {
  g.a[i].b = (uint16_t) (60000 + i), g.a[i].n = (uint8_t) i, g.h[i] = (uint16_t) (i * 9000), n[i] = (int16_t) (-i * 100);
 }
 for (int i = 0; i < 20000; i++) f[i] = (uint16_t) (i * 7);
 for (int i = 0; i < 8; i++) s += memb(&g, i) + hfar(&g, i) + bare(g.h, i) + (unsigned long) (sign(n, i) + 1000);
 s += bare(f, 19999) + odd((const char *) f, 9000);
 printf("%lu %ld\n", s, sign(n, 7));
 return 0;
}
