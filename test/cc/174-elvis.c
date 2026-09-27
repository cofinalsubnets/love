/* gcc's `a ?: b`, held to gcc: a when it is true, else b, with a read ONCE -- a call, an
 * increment or an assignment in it happens one time -- and a constant a still a constant
 * (an enumerator, an array bound, a static initializer). the arms convert as `?:` does,
 * and the operator nests to the right. */

static int calls;
static int bump(int v) { calls++; return v; }

enum { E0 = 0 ?: 5, E1 = 3 ?: 9 };
static int bound[2 ?: 7];
static long sinit = 0 ?: 40;
static const char *name(const char *s) { return s ?: "none"; }

struct S { int x; int y; };

int main(void) {
  int bad = 0;
  int r = 0, i = 0, k = 4;
  struct S s = { 0, 6 }, *p = &s;
  double d = 0.0;

  if ((r ?: 7) != 7 || (k ?: 7) != 4) bad |= 1;
  if (E0 != 5 || E1 != 3 || sizeof bound != 2 * sizeof(int) || sinit != 40) bad |= 2;

  calls = 0;
  if ((bump(0) ?: 9) != 9 || calls != 1) bad |= 4;
  if ((bump(3) ?: 9) != 3 || calls != 2) bad |= 8;

  if ((i++ ?: 11) != 11 || i != 1) bad |= 16;
  if ((i++ ?: 11) != 1 || i != 2) bad |= 32;
  if (((r = 5) ?: 1) != 5 || r != 5) bad |= 64;

  if (name(0)[0] != 'n' || name("x")[0] != 'x') bad |= 128;
  if ((s.x ?: p->y) != 6 || (p->y ?: 1) != 6) bad |= 256;
  if ((0 ?: 0 ?: 12) != 12 || (0 ?: 13 ?: 14) != 13) bad |= 512;
  if (sizeof((char)0 ?: 300L) != sizeof(long) || ((char)0 ?: 300L) != 300) bad |= 1024;
  if ((d ?: 2.5) != 2.5 || (1.5 ?: 2.5) != 1.5) bad |= 2048;
  if ((bump(0) ?: bump(0) ?: 21) != 21 || calls != 4) bad |= 4096;

  return bad;
}
