/* always_inline splices however deep its chain runs, as gcc does: seven always_inline levels under
 * three plain inline callers leave no out-of-line copy (moon.sh reads the symbols; the kernel's
 * asm "i" operand ten calls down). exit-code only (55) */
#define AI static inline __attribute__((always_inline))
static int hits;

AI int cap(const unsigned long c) { return (int) c; }
AI int a7(unsigned long c, int x) { return ({ int t = cap(c); t + x; }); }
AI int a6(unsigned long c, int x) { return a7(c, x + 1); }
AI int a5(unsigned long c, int x) { return a6(c, x + 1); }
AI int a4(unsigned long c, int x) { return a5(c, x + 1); }
AI int a3(unsigned long c, int x) { return ({ int t = a4(c, x); t; }); }
AI int a2(unsigned long c, int x) { return a3(c, x + 1); }
AI int a1(unsigned long c, int x) { return a2(c, x + 1); }
static inline void p3(int x) { hits += a1(42, x); }
static inline void p2(int x) { if (x) p3(x); else p3(1); }
static inline void p1(int x) { p2(x + 1); }

int main(void)
{
	p1(3);
	return hits == 42 + 4 + 5 ? 55 : 1;
}
