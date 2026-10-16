/* __builtin_popcount/l/ll, assuming no popcnt instruction. the 32-bit form masks
 * first: bits above 31 may hold garbage (the `wide` row). each check adds 1: the exit code is the pass count. */

extern int printf(const char *, ...);

typedef unsigned int u32;
typedef unsigned long long u64;

u32 g32 = 0x11223344;
u64 g64 = 0x0123456789abcdefULL;

/* the glibc shape: a static inline wrapping the builtin */
static __inline int pc32(u32 x) { return __builtin_popcount(x); }
static __inline int pc64(u64 x) { return __builtin_popcountll(x); }

/* the answer the fold is checked against */
static int slow(u64 x)
{
	int n = 0;
	while (x) n += (int) (x & 1), x >>= 1;
	return n;
}

int main(void)
{
	u64 wide = 0xffffffff00000001ULL;   /* a 32-count of a wider value counts the low half only */
	int r = 0;
	r += __builtin_popcount(0) == 0;
	r += __builtin_popcountll(0) == 0;
	r += __builtin_popcount(g32) == 10;
	r += __builtin_popcountll(g64) == slow(g64);
	r += __builtin_popcountll(0xffffffffffffffffULL) == 64;
	r += __builtin_popcount(0xffffffffu) == 32;
	r += __builtin_popcountl((unsigned long) g64) == slow((unsigned long) g64);
	r += __builtin_popcount((u32) wide) == 1;
	r += pc32(0x80000000u) == 1 && pc64(0x8000000000000000ULL) == 1;
	r += pc64(g64) == pc32((u32) g64) + pc32((u32) (g64 >> 32));
	return r;
}
