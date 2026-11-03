/* a plain static inline under the size gate splices a body whatever it holds, as gcc and clang do
 * at -O2: a statement expression whose local shadows the caller's, a compound literal, a struct
 * local, an array local, an overflow check, WRITE_ONCE's do-while(0) wrapping and its constant
 * size check -- the kernel's header helpers (check_mul_overflow, min, max, INIT_LIST_HEAD).
 * a do-while(0) a break leaves keeps its loop. exit-code only (55) */
struct P { int a, b; };
static int tab[8] = { 1, 2, 3, 4, 5, 6, 7, 8 };

static inline int sx(int c) { return ({ int c2 = c + 1; tab[c] + c2 - c - 1; }); }
static inline int cl(int c) { return ((struct P){ tab[c], c }).a; }
static inline int sl(int c) { struct P p = { c, tab[c] }; return p.b - p.a; }
static inline int al(int c) { const int z[4] = { 0, 1, 2, 3 }; return tab[c] + z[c & 3]; }
#define WO(x, v) do { ((void)(sizeof(x) == 1 || sizeof(x) == 2 || sizeof(x) == 4 || sizeof(x) == 8)); \
	do { *(volatile typeof(x) *)&(x) = (v); } while (0); } while (0)
static inline void wo(struct P *p, int v) { WO(p->a, v); WO(p->b, v + 1); }
static inline int bk(int c) { int r = 1; do { if (c > 4) break; r = 2; } while (0); return r; }
static inline int mul_ok(unsigned long n, unsigned long s, unsigned long *r)
{
	return !({ unsigned long t; int o = __builtin_mul_overflow(n, s, &t); *r = t; o; });
}

__attribute__((noinline)) static int run(int b)
{
	int c2 = 100, s = 0;
	unsigned long r;
	struct P q;
	for (int c = 0; c < 8; c++)
		if (c != b)
			s += sx(c) + cl(c) - sl(c) - al(c) + bk(c);
	wo(&q, b);
	s += q.a + q.b;
	if (!mul_ok(6, 7, &r) || r != 42 || mul_ok(~0ul, 2, &r))
		return 0;
	return s + c2;
}

int main(void)
{
	return run(3) == 134 ? 55 : 1;
}
