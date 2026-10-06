/* declarators linux's helpers write: an __auto_type with attributes between its name and its =
 * (the scoped guards' `for (const __auto_type p __attribute__((__cleanup__(f))) = ..;..)`), an
 * __auto_type over a bit builtin (ilog2's __builtin_clzll), and an earlier declarator of the
 * same list in scope for the initializers after it, under typeof and sizeof too (get_user's
 * `int timeout, err = ({ __typeof__(timeout) v; .. })`). freestanding, exit-code only. */

static int ends;
static void done(int **p) { (void)p; ends++; }

static int scoped(int *p)
{
	int seen = 0;
	for (const __auto_type q __attribute__((__unused__)) __attribute__((__cleanup__(done))) = p; !seen; seen = 1)
		seen = *q == 7 ? 1 : 2;
	return seen;
}

int main(void)
{
	int bad = 0, seven = 7;
	__auto_type a __attribute__((__unused__)) = 5L;
	if (sizeof a != sizeof(long) || a != 5) bad |= 1;
	if (scoped(&seven) != 1 || ends != 1) bad |= 2;
	volatile unsigned long long b = 1ULL << 40;
	__auto_type lz = 63 - __builtin_clzll(b);
	__auto_type tz = __builtin_ctz(8u);
	if (lz != 40 || tz != 3 || sizeof lz != sizeof(int)) bad |= 4;
	int timeout = 9, err = ({ __typeof__(((timeout))) v = timeout + 1; v; });
	if (err != 10) bad |= 8;
	long w = 3, z = sizeof(w) + w;
	if (z != (long)sizeof(long) + 3) bad |= 16;
	{ char w = 2, y = sizeof(w); if (y != 1 || w != 2) bad |= 32; }
	return bad;
}
