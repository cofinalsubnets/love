/* a branchy callee at a branch test: each return decides the test where it stands, the arms
 * copied to it -- or, where they would not copy, the splice's value is tested. main answers
 * how many shapes agree with the value C gives them (24). */

static int rng(int x) { if (x < 0) return 0; if (x > 100) return 1; return x & 1; }
static char c8(int x) { if (x) return 256; return 1; }          /* 256 narrows to 0 */
static unsigned um(int x) { if (x < 0) return -1; return x; }   /* -1 is above everything */
static long big(int x) { if (x) return 0x100000000L; return 0; }
static int cnt;
static int eff(int x) { cnt++; if (x == 3) return 0; cnt += 10; return x; }
static int nul(long *p) { if (!p) return 0; if (*p < 0) return 0; return 1; }
static double sg(double x) { if (x < 0) return -1.0; if (x > 0) return 1.0; return 0.0; }
static int sel(int k) { switch (k) { case 1: return 5; case 2: return 0; } return -2; }
static int *rp(int k, int *a) { return rng(k) ? a + 1 : a + 3; }  /* a pointer return's ?: */

int main(void) {
  int ok = 0;
  ok += (rng(-5) ? 1 : 2) == 2; ok += (rng(200) ? 1 : 2) == 1;
  ok += (rng(7) ? 1 : 2) == 1; ok += (rng(8) ? 1 : 2) == 2;
  if (!rng(-1)) ok++;
  if (c8(1)) ; else ok++;
  if (c8(0)) ok++;
  if (um(-1) > 5) ok++;
  if (um(3) > 5) ; else ok++;
  if (big(1)) ok++;
  if (big(0)) ; else ok++;
  cnt = 0; if (eff(3) || eff(4)) ok += cnt == 12;
  cnt = 0; if (eff(3) && eff(4)) ; else ok += cnt == 1;
  long v = 4, w = -4;
  ok += nul(&v) + !nul(&w) + !nul(0);
  if (sg(-2.5)) ok++;
  if (sg(0.0)) ; else ok++;
  if (sel(2)) ; else ok++;
  if (sel(9)) ok++;
  int arr[4] = {10, 20, 30, 40}, *p = arr;
  p = rng(7) ? p + 1 : p + 2; ok += *p == 20;                   /* a pointer ?: pushes down */
  ok += *rp(8, arr) == 40;
  long lx = 0; lx = rng(7) ? -1 : 4000000000u; ok += lx == (long) (unsigned) -1;   /* the arms' common type */
  int s = 0;
  for (int i = -3; i < 120; i++) if (rng(i) && !c8(i)) s += i;   /* every threaded edge inside a loop */
  ok += s == 4590;
  return ok; }
