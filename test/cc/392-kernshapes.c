// shapes linux leans on, each laid rather than refused: gcc's cast to a union, an empty struct by
// value (no register, no slot), a literal shift past the word in an arm never taken, a name in
// its own initializer, and a long sum of small calls, lowered in time linear in its terms
union pv { int i; unsigned char b[4]; };
struct none {};
static int setp(int id, union pv v) { return id * 100 + v.i; }
__attribute__((noinline)) static long after(long a, struct none n, long b, struct none m, long c) { return a * 100 + b * 10 + c; }
static unsigned long long mask(int bits) { return (unsigned long long) (bits < 64 ? ((1ULL << (bits)) - 1) : -1); }
static int self(int *p) { int *v = v = p; return *v; }
static inline int as(int p) { return 4 + p; }
static inline int ts(int p) { return (as(p) + 3) & ~3; }
static unsigned long sum(int m)
{
	return 16 + ts(1) + ts(2) + ts(3) + ts(4) + ts(m) + ts(1) + ts(2) + ts(3) + ts(4) + ts(m)
	       + ts(1) + ts(2) + ts(3) + ts(4) + ts(m) + ts(1) + ts(2) + ts(3) + ts(4) + ts(m)
	       + ts(1) + ts(2) + ts(3) + ts(4) + ts(m) + ts(1) + ts(2) + ts(3) + ts(4) + ts(m)
	       + (m + 1) + (m + 2) + (m + 3) + (m + 4) + (m + 5) + (m + 6) + (m + 7) + (m + 8);
}

int main(void)
{
	struct none z;
	int k = 7;
	int t = setp(2, (union pv) k) - 200;                  // 7
	t += (int) after(1, z, 2, z, 3) - 123;                // 0
	t += mask(64) == ~0ULL && mask(12) == 4095 ? 1 : 50;  // 1
	t += self(&k);                                        // 7
	return (t + (int) (sum(3) % 200)) % 251;
}
