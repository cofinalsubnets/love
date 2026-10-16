/* a ?: over a constant condition folds (6.6), and a shift count out of one is an immediate:
 * the arms still convert by both types, the dead arm's effects never run, a variable shift stays. */
#include <stdio.h>
#include <stdint.h>

#define IDX ((uintptr_t) 1 << (sizeof(uintptr_t) == 8 ? 40 : 27))

static int calls;
static long bump(long v) { calls++; return v; }

/* the shape that started it: a constant conditional under a shift, then a compare */
static uintptr_t lane(uintptr_t v) { return v < IDX ? v + 1 : 0; }
static int shifted(int x) { return x << (sizeof(long) >= 4 ? 3 : 1); }
static unsigned long masked(unsigned long x) { return x & ((1UL << (sizeof(void*) == 8 ? 12 : 10)) - 1); }

/* the arms type the result together, whichever one survives */
static double dbl(void) { return 1 ? 1 : 2.0; }
static double dbl2(void) { return 0 ? 1.0 : 2; }
static long wide(int x) { return (0 ? 1 : 2L) * x; }

/* only the live arm runs */
static long pick(int which) { return which ? (1 ? bump(10) : bump(20)) : (0 ? bump(30) : bump(40)); }

/* nested, and one whose condition is constant only after the inner fold */
static long nest(long s) { return (1 ? 0 : 1) ? s + 1 : (0 ? s + 2 : s + 4); }

/* a count constant through a local, and one that is genuinely variable */
static unsigned long viak(unsigned long x) { int k = 1 ? 5 : 9; return x << k; }
static unsigned long dyn(unsigned long x, int n) { return x << n; }

int main(void)
{
	long t = 0;
	printf("idx %d\n", (int) ((IDX >> 20) != 0));
	printf("lane %d %d\n", (int) lane(7), (int) lane(IDX));
	for (int i = -3; i <= 3; i++) { printf("sh %d\n", shifted(i)); t += shifted(i); }
	static const unsigned long M[] = { 0ul, 1ul, 4095ul, 4096ul, 123456ul };
	for (unsigned i = 0; i < sizeof M / sizeof *M; i++) printf("m %lu\n", masked(M[i]));
	printf("d %.1f %.1f\n", dbl(), dbl2());
	printf("w %ld %ld\n", wide(3), wide(-3));
	calls = 0;
	long p1 = pick(1);
	long p2 = pick(0);
	printf("p %ld %ld c %d\n", p1, p2, calls);
	for (long n = 0; n <= 4; n++) { printf("n %ld\n", nest(n)); t += nest(n); }
	for (unsigned long x = 0; x < 5; x++) {
		printf("k %lu %lu\n", viak(x), dyn(x, (int) x));
		t += (long) (viak(x) + dyn(x, (int) x));
	}
	printf("t %ld\n", t);
	return (int) (t & 0x3f);
}
