/* __label__: a block-local label, so a macro laying one can expand twice, an inner block sees it,
 * and a function label of the same spelling stays apart; short __attribute spellings. held to gcc. */

struct __attribute((packed)) pk { char a; int b; };
static int __attribute((unused)) spare;

#define PICK(x, v, out) do { __label__ hit; if ((x) == (v)) goto hit; if (0) { hit: out = (v) * 10; } } while (0)

#if defined(__x86_64__)
#define AGOTO(c, out) do { __label__ hit; asm goto("test %0, %0\n\tjnz %l1" : : "r"(c) : "cc" : hit); \
  if (0) { hit: out++; } } while (0)
#else
#define AGOTO(c, out) do { if (c) out++; } while (0)
#endif

static int f(int x) {
  int r = 0;
  PICK(x, 1, r);
  PICK(x, 2, r);
  PICK(x, 3, r);
  if (x == 4) goto hit;
  return r;
hit:
  return 99;
}

static int g(int a, int b) {
  int n = 0;
  AGOTO(a, n);
  AGOTO(b, n);
  ({ __label__ out; if (a) goto out; n += 100; out: n; });
  return n;
}

int main(void) {
  int bad = 0;
  if (f(1) != 10 || f(2) != 20 || f(3) != 30 || f(4) != 99 || f(5) != 0) bad |= 1;
  if (g(1, 1) != 2 || g(0, 1) != 101 || g(0, 0) != 100) bad |= 2;
  if (sizeof(struct pk) != 5) bad |= 4;
  return bad;
}
