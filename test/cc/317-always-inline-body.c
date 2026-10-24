/* always_inline splices a body whatever it holds, as gcc and clang do: a statement expression
 * whose local shadows the caller's, a compound literal, a struct local and an array local, at
 * each call in a loop. exit-code only (55) */
struct P { int a, b; };
static int tab[8];

__attribute__((noinline)) static int fk(int c) { return c * 3 + 1; }

static inline __attribute__((always_inline)) int ii(int c)
{
	int z = ({ int z = tab[c]; int c2 = c + 1; z + c2 - c - 1; });
	struct P p = { z, c };
	const int zero[4] = { 0 };
	if (!p.a && !zero[c & 3])
		tab[c] = fk(((struct P){ p.a, p.b }).b);
	return ({ int t = tab[c]; t + zero[3]; });
}

__attribute__((noinline)) static int run(int b)
{
	int z = 100, s = 0;
	for (int c = 0; c < 8; c++)
		if (c != b)
			s += ii(c);
	return s + z - ii(b) * 0;
}

int main(void)
{
	return run(3) == 100 + 1 + 4 + 7 + 13 + 16 + 19 + 22 ? 55 : 1;
}
