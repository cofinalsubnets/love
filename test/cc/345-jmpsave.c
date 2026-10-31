/* setjmp and longjmp with values held across them: a value set before setjmp and untouched after
 * keeps it through the jump, which leans on the callee-saved registers being saved and restored */
#include <setjmp.h>

static jmp_buf jb;
static long hops;

static long work(long x, int k) {
	long a = x * 3, b = x ^ 0x5a5a, c = x - 77, d = x * x;
	if (k == 0) { hops++; longjmp(jb, (int) (a & 7) + 1); }
	return work(a + b - c + d % 1000, k - 1) + 1; }

static long run(long x) {
	long p = x * 13, q = x + 999, r = x ^ 0x3c3c, s = x * 7 - 5, t = x / 3, u = x % 11;
	volatile long n = 0;
	int v = setjmp(jb);
	if (v == 0) { n = 1; work(x, 5); return -1; }
	return p - q + r - s + t - u + v * 1000 + n; }

int main(void) {
	long r = 0;
	for (int i = 0; i < 9; i++) r += run(i * 101 + 3);
	unsigned long u = (unsigned long) (r + hops);
	return (int) ((u ^ u >> 19) % 251); }
