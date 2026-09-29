/* *p++ and *p-- through a register-riding pointer: the pointer steps first and the access reads
 * one step back, so no copy of the old pointer is kept. stores, loads, a compound op, a struct
 * stride, an address taken through it, a narrow and a wide element, both directions, and the
 * pointer's own value afterwards. held to gcc. */

struct rec { long a; int b; char pad[20]; };

__attribute__((noinline)) static int copy(unsigned char *d, const unsigned char *s, int n) {
  unsigned char *d0 = d;
  while (n--) *d++ = *s++;                        /* both sides */
  return (int) (d - d0);
}

__attribute__((noinline)) static long sums(const long *p, int n) {
  long t = 0;
  for (int i = 0; i < n; i++) t += *p++;          /* a wide load */
  return t;
}

__attribute__((noinline)) static int bump(short *p, int n) {
  short *e = p + n;
  while (p < e) *p++ += 3;                        /* compound: one step, one read, one write */
  return 0;
}

__attribute__((noinline)) static long recs(struct rec *r, int n) {
  long t = 0;
  struct rec *q = r;
  while (n--) { q->b = n; t += (q++)->a; }        /* a struct stride through ->, then *q++ */
  struct rec *z = r;
  struct rec c = *z++;                            /* a whole-struct load */
  return t + c.a + (z - r);
}

__attribute__((noinline)) static int down(int *p, int n) {
  int t = 0;
  p += n - 1;
  while (n--) t = t * 3 + *p--;                   /* backwards */
  return t;
}

__attribute__((noinline)) static long addr(long *p) {
  long *a = &*p++;                                /* the address is the old pointer */
  long *b = p;
  return (b - a) * 100 + *a;
}

int main(void) {
  int bad = 0;
  unsigned char s[9] = {1, 2, 3, 250, 5, 6, 7, 8, 9}, d[9] = {0};
  if (copy(d, s, 9) != 9 || d[3] != 250 || d[8] != 9) bad |= 1;
  long w[5] = {1, -2, 30000000000L, 4, 5};
  if (sums(w, 5) != 30000000008L) bad |= 2;
  short h[4] = {1, 2, 32766, -5};
  bump(h, 4);
  if (h[0] != 4 || h[2] != (short) 32769 || h[3] != -2) bad |= 4;
  struct rec r[3] = {{10, 0, {0}}, {20, 0, {0}}, {30, 0, {0}}};
  if (recs(r, 3) != 60 + 10 + 1 || r[0].b != 2 || r[2].b != 0) bad |= 8;
  int v[4] = {1, 2, 3, 4};
  if (down(v, 4) != ((4 * 3 + 3) * 3 + 2) * 3 + 1) bad |= 16;
  long x[2] = {77, 88};
  if (addr(x) != 177) bad |= 32;
  return bad;
}
