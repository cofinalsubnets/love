/* a one-expression callee at a position evaluated conditionally or in a loop -- a ?: arm, the
 * right of && || or a comma, a loop's test or step -- is its expression in place: nothing runs
 * that would not have, an arg that may trap stays where it was, a hoisted one reads after the
 * statement's earlier writes. main answers how many shapes agree with the value C gives them (16). */

typedef unsigned long word;
struct tr { int rank; long shape[2]; };
static int oddp(word x) { return x & 1; }
static int chainp(word x) { return !oddp(x) && *(word*)x == 7; }       /* a load: never hoisted */
static word b2w(word b) { word q = b / 8, r = b % 8; return q + (r ? 1 : 0); }
static word sq(word b) { word q = b / 8; return q * q; }               /* q twice: not one expression */
static double half(double d) { return d * 0.5; }
static int big(unsigned long x) { return x > 100; }                   /* the parameter conversion */
static void *tdat(struct tr *v) { return (void*) (v->shape + v->rank); }
static int cnt;
static int tick(int x) { cnt++; return x; }

int main(void) {
  int ok = 0, k = 0, m = 0, i, n = 4, v;
  word c[6] = {7, 0, 7, 0, 5, 0};
  c[1] = (word) &c[2]; c[3] = (word) &c[4];
  word l = (word) c, *np = 0;
  for (; chainp(l); l = ((word*) l)[1]) k++;
  ok += k == 2;
  ok += (k > 5 && chainp(*np)) == 0;                                  /* *np is never read */
  ok += (np ? (int) b2w(np[0]) : 3) == 3;                             /* nor np[0] */
  ok += (k == 3 || chainp(((word*) c)[1])) == 1;                     /* a small load, read twice */
  v = (n = n + 12) + (k ? (int) b2w(n * 8) : 0);                      /* n is 16 by the arm */
  ok += v == 32;
  cnt = 0; v = tick(1) ? (int) b2w(cnt * 64) : 0;                     /* cnt is 1 by the arm */
  ok += v == 8;
  v = (n = 24, (int) b2w(n));
  ok += v == 3;
  ok += (k ? (int) sq(n) : 0) == 9;
  ok += (k ? half(3.0) : 0.0) == 1.5;
  char ch = -1;
  ok += (k ? big(ch) : 0) == 1;                                        /* (unsigned long) -1 */
  for (i = 0; i < 3; i = (int) b2w(i * 8 + 8)) m++;
  ok += m == 3 && i == 3;
  l = (word) c; m = 0;
  do { m++; l = ((word*) l)[1]; } while (chainp(l));
  ok += m == 2;
  struct tr tv = {1, {0, 0}};
  void *p = tdat(&tv);
  ok += p == (void*) &tv.shape[1];
  ok += (k && chainp((word) c) && !chainp((word) c + 8)) == 1;
  ok += (k ? (n > 20 ? (int) b2w(n) : (int) b2w(n * 2)) : 0) == 3;
  ok += (cnt == 1 && (cnt = 5, b2w(cnt))) == 1;
  return ok; }
