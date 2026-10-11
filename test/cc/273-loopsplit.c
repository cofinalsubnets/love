/* a loop lends its registers: a name the loop never mentions parks in its slot and comes
 * back past the exit, and a cell the loop leans on rides a register across it. every shape
 * here went wrong once while the splitter was built:
 *   - the register comes back AFTER the cell leaves it (both live past the loop);
 *   - a for's step and a do's cond lay after their body, outside any inner loop's lease;
 *   - a name declared later in the outer body is not parked before it exists;
 *   - break, continue and return leave a lease the same way the test does.
 * many locals stay live at once, so the seats run out and the leases happen.
 * every check adds 1; the exit code is the count that passed. */

#include <stdio.h>

/* twelve accumulators live at once: more than the seats, so the leases happen */
#define ACC long a = 1, b = 2, c = 3, d = 4, e = 5, f = 6, g = 7, h = 8, m = 9, o = 10, w = 11, z = 12
#define MIX(x) (a += (x), b ^= a, c += b, d ^= c, e += d, f ^= e, g += f, h ^= g, m += h, o ^= m, w += o, z ^= w)
#define SUM (a + b + c + d + e + f + g + h + m + o + w + z)

static volatile long sink;
static long touch(long x) { sink = x; return x + 1; }

/* the register comes back after the cell leaves it: hit and e both live past the loop */
static long share(const long *v, int n) {
	long a = v[0], b = v[1], c = v[2], d = v[3], e = v[4], f = v[5], g = v[6], h = v[7];
	long r = 0;
	for (int i = 0; i < n; i++) {
		long hit = 0;
		for (int k = 0; k < 8 && !hit; k++) hit = v[k] == i;
		r += hit;
		a += b; b ^= c; c += d; d ^= e; e += f; f ^= g; g += h; h ^= a;
	}
	return r + a + b + c + d + e + f + g + h;
}

/* a for's step reads a name an inner loop leases: the step lays outside the lease */
static long step(const long *v, int n) {
	ACC;
	long i = 0;
	for (int j = 0; j < n; j++, i += 3) {
		for (int k = 0; k < 4; k++) i = (i ^ v[k]) + (i >> 3) + k;
		MIX(j);
	}
	return i + SUM;
}

/* do { for ... } while (j): the cond lays after the body, the ana_d shape */
static long redo(const long *v) {
	ACC;
	long j, rounds = 0;
	do for (j = 0, rounds++; j < 3 && rounds < 5; j++) MIX(v[j]);
	while (j && rounds < 5);
	return SUM + rounds;
}

/* a name declared later in the outer body: nothing to park before it exists */
static long later(const long *v, int n) {
	ACC;
	for (int i = 0; i < n; i++) {
		long hit = 0;
		for (int k = 0; k < 6; k++) if (v[k] == i) hit = touch(hit);
		long y = hit * 3 + i;
		MIX(y);
	}
	return SUM;
}

/* break, continue and return out of a lease */
static long leave(const long *v, int n) {
	ACC;
	long cnt = 0;
	for (int i = 0; i < n; i++) {
		for (int k = 0; k < 8; k++) {
			if (v[k] == 9) continue;
			cnt += v[k] + i;
			if (cnt > 100000) break;
			if (cnt == 777777) return -1;
		}
		MIX(cnt);
	}
	return cnt + SUM;
}

int main(void) {
	long v[8] = { 3, 1, 4, 1, 5, 9, 2, 6 };
	int r = 0;
	r += share(v, 12) == 7760;
	r += step(v, 7) == 2391;
	r += redo(v) == 60911;
	r += later(v, 9) == 7904;
	r += leave(v, 40) == 3559702380;
	printf("%ld %ld %ld %ld %ld\n", share(v, 12), step(v, 7), redo(v), later(v, 9), leave(v, 40));
	return r;
}
