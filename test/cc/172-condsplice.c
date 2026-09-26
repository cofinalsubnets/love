/* a callee of several statements at a position a value cannot hoist from -- a ?: arm, the
 * right of && || or a comma, a loop's test -- becomes a temporary of the position's own type
 * assigned under an if where its body splices, or the loop's test an if at its body's head:
 * the arms still meet at their common type, the untaken arm still does not run, continue
 * still runs the test. main answers how many shapes agree with the value C gives them (19). */

typedef unsigned long word;
#define inl static inline __attribute__((always_inline))
inl int charmp(word x) { return x & 1; }
inl long wsum(word x) { long *b = (long*) x; long u = 0; int n = (int) b[0]; for (int i = 0; i < n; i++) u += b[1 + i]; return u; }
inl long toint(word x) { return charmp(x) ? (long) (x >> 1) : wsum(x); }
inl unsigned ubig(int k) { unsigned u = 4000000000u; if (k) u += 1; return u; }
inl double dsum(double *p, int n) { double s = 0; while (n-- > 0) s += p[n]; return s; }
inl int *pick(int *a, int k) { int *p = a; if (k) p += 2; return p; }
static int cnt;
inl int tick(int x) { cnt++; if (x > 3) return x - 3; return x; }
struct X { word *lo, *hi; };
inl int tagl(word *g, struct X *X, word x) { if ((x & 3) != 2) return 0; word *p = (word*) (x & ~3ul); return (X->lo && p >= X->lo && p < X->hi) || p == g; }
inl int nilp(word x) { if (x & 1) return (long) x <= 1; if (x == 0) return 1; return *(long*) x <= 0; }
struct G { word *ip; };

int main(void) {
  int ok = 0, k = 1;
  long cells[3] = {2, 30, 12};
  word a = 9, b = (word) cells;
  ok += toint(a) + toint(b) == 46;                                    /* 4 + 42 */
  long x = k ? -1 : ubig(k);                                          /* meets at unsigned */
  ok += x == 4294967295L;
  ok += (k ? ubig(0) : 7u) == 4000000000u;
  double d[3] = {0.5, 1.0, 2.0};
  ok += (k ? dsum(d, 3) : 0.0) == 3.5;
  ok += (k ? 1.0 : dsum(d, 2)) == 1.0;
  int arr[4] = {1, 2, 3, 4};
  ok += *(k ? pick(arr, 1) : (int*) 0) == 3;
  ok += (k ? (int*) 0 : pick(arr, 0)) == 0;
  cnt = 0; ok += (k > 5 && tick(9) > 1) == 0; ok += cnt == 0;         /* untaken: no tick */
  cnt = 0; ok += (k > 0 && tick(9) > 1) == 1; ok += cnt == 1;
  cnt = 0; ok += (k < 0 || tick(2) == 2) == 1; ok += cnt == 1;
  int m = 0; long y = (m++, wsum(b)) + m;                             /* the comma's order */
  ok += y == 43;
  word gg[8] = {0}, q[6] = {4, 8, 12, (word) gg | 2, 0, 0};
  struct X X = {q, q + 6};
  word *p = q, n = 0;
  for (; !tagl(gg, &X, p[0]); p++) n++;                              /* a for's test */
  ok += n == 3;
  p = q; n = 0;
  while (!tagl(gg, &X, *p)) { n++; if (n > 100) continue; p++; }     /* continue runs the test */
  ok += n == 3;
  p = q; n = 0;
  do { p++; n++; } while (!tagl(gg, &X, *p));
  ok += n == 3;
  struct G G = {q}; long v = -5;
  G.ip = nilp(7) ? G.ip + 2 : G.ip + 3;                              /* a pure lvalue's ?: */
  ok += G.ip - q == 3;
  G.ip = nilp((word) &v) ? G.ip + 2 : G.ip + 3;
  ok += G.ip - q == 5;
  return ok; }
