/* gcc's `[a ... b] =` range designator, and the frame's own two addresses.
 * the kernel writes both: a range fills a table of defaults, and _RET_IP_ is
 * __builtin_return_address(0). */
#include <stdio.h>

int tbl[10] = { [0 ... 3] = 7, [5] = 9, [7 ... 8] = -1 };
char cs[6] = { [1 ... 4] = 'x' };
static const short over[4] = { [0 ... 3] = 1, [2] = 5 };   /* a later item wins */

struct pair { int a, b; };
struct pair ps[4] = { [0 ... 1] = { 1, 2 }, [3] = { 3, 4 } };

static int sum(int *p, int n) { int s = 0, i; for (i = 0; i < n; i++) s += p[i]; return s; }

static void *ra(void) { return __builtin_return_address(0); }
static void *fa(void) { return __builtin_frame_address(0); }

/* two call sites in one function report two different return addresses, and each
 * lies after the call that made it -- which is what a caller-identifying builtin
 * has to answer to be worth anything */
static int callsite(void)
{
  void *r1 = ra();
  void *r2 = ra();
  return (r1 != 0) + (r2 != 0) + (r1 != r2);
}

int main(void)
{
  int i, cn = 0, pn = 0, on = 0;
  void *f1 = fa();
  for (i = 0; i < 6; i++) cn += cs[i];
  for (i = 0; i < 4; i++) pn += ps[i].a * 10 + ps[i].b;
  for (i = 0; i < 4; i++) on += over[i];
  printf("%d %d %d %d %d %d\n", sum(tbl, 10), cn, pn, on, callsite(), f1 != 0);
  return (sum(tbl, 10) + cn + pn + on) & 0x7f;
}
