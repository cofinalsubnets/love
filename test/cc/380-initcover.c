// a brace initializer that stores over every byte lays no zeroing first; members past its items
// still read zero, each pass of a loop laying its own
#include <string.h>
#include <stdint.h>

struct pd { char a; long b; short c; };
struct bf { unsigned x : 3, y : 5; int z; };
struct pr { long u, v; };
__attribute__((noinline)) static uint32_t sum(const void *p, unsigned n) { const unsigned char *b = p; uint32_t s = 0; for (unsigned i = 0; i < n; i++) s = s * 31 + b[i]; return s; }
__attribute__((noinline)) static void dirty(void *p, unsigned n) { memset(p, 0xa5, n); }

int main(void) {
 uint32_t s = 0;
 for (int i = 0; i < 6; i++) {
  double c[3] = { i * 1.5, i + 0.25, -i };
  long part[5] = { i, i * 2 };
  struct pd pd = { (char) i, i * 3L, (short) -i };
  struct bf bf = { (unsigned) i, (unsigned) i * 3, i - 2 };
  struct pr p1 = { i, 1 }, p2 = { 2, i };
  struct pr pq[2] = { i & 1 ? p1 : p2, { 5, 6 } };
  s = s * 7 + sum(c, sizeof c) + sum(part, sizeof part) + sum(&pd.a, 1) + (uint32_t) pd.b + (uint32_t) pd.c;
  s = s * 7 + bf.x + bf.y + (uint32_t) bf.z + sum(pq, sizeof pq);
  dirty(c, sizeof c), dirty(part, sizeof part), dirty(&pd, sizeof pd), dirty(&bf, sizeof bf), dirty(pq, sizeof pq);
 }
 return (int) (s % 251);
}
