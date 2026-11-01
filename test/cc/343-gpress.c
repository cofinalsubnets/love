/* more live words than callee-saved registers, across calls: direct, through a pointer, and a
 * recursive one, in loops, so some live in the frame and some ride the saved registers.
 * unsigned throughout: every wrap is defined */
#include <stdint.h>
typedef uint64_t u64;
static u64 k9 = 7;

static u64 step(u64 x) { return x * 3 + k9; }
static u64 twice(u64 x) { return x + x / 5; }
static u64 fold(u64 x, u64 y) { return (x ^ y) + (y >> 3); }
static u64 deep(u64 n, u64 a) { return n == 0 ? a : deep(n - 1, fold(a, n)) + 1; }

static u64 press(u64 const *v, int n, u64 (*f)(u64)) {
	u64 a0 = v[0], a1 = v[1], a2 = v[2], a3 = v[3], a4 = v[4], a5 = v[5], a6 = v[6], a7 = v[7];
	u64 b0 = v[8], b1 = v[9], b2 = v[10], b3 = v[11], b4 = v[12], b5 = v[13];
	for (int i = 0; i < n; i++) {
		a0 = step(a0) - b5;  a1 = a1 + f(a2);  a2 = fold(a2, a3) - (u64) i;  a3 = a3 * 5 - b0;
		a4 = deep((u64) (i & 7), a4) - a5;  a5 = a5 ^ (b1 + (u64) i);  a6 = f(a6 + a7);  a7 = a7 - (b2 >> 1);
		b0 += a0 & 1023;  b1 = fold(b1, a1);  b2 = b2 * 3 - a6;  b3 = b3 + step(b4);  b4 = b4 - a4;  b5 = b5 ^ a7;
	}
	return a0 + a1 - a2 + a3 - a4 + a5 - a6 + a7 + b0 - b1 + b2 - b3 + b4 - b5; }

/* a value read only after the last call, and one read only before the first */
static u64 ends(u64 x, u64 y) {
	u64 before = x * 7, after = y * 11;
	u64 s = step(before);
	s = fold(s, step(s));
	return s + after; }

int main(void) {
	u64 v[15];
	for (int i = 0; i < 15; i++) v[i] = (u64) i * 37 + 200;
	u64 u = press(v, 40, step) + press(v + 1, 25, twice) + ends(9, 4);
	return (int) ((u ^ u >> 17 ^ u >> 41) % 251); }
