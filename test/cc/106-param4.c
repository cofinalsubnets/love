/* the 4th integer parameter (an out-pointer) survives its body: on x64 args 3 and
 * 4 home away from their arrival registers. the register pressure is load-bearing:
 * keep the temps, or the arrival register is never wanted. */

/* 64x64 -> 128 without __int128, four params, the last two out-pointers */
static void mul64(unsigned long a, unsigned long b,
                  unsigned long *hi, unsigned long *lo)
{
	unsigned long ah = a >> 32, al = a & 0xffffffffUL;
	unsigned long bh = b >> 32, bl = b & 0xffffffffUL;
	unsigned long p0 = al * bl, p1 = al * bh, p2 = ah * bl, p3 = ah * bh;
	unsigned long mid = p1 + (p0 >> 32);
	unsigned long c = mid < p1 ? (1UL << 32) : 0;

	mid += p2;
	if (mid < p2)
		c += 1UL << 32;
	*hi = p3 + (mid >> 32) + c;
	*lo = (mid << 32) | (p0 & 0xffffffffUL);
}

/* two values in, two out: the plainest form of the same fault */
static void two(unsigned long a, unsigned long b,
                unsigned long *c, unsigned long *d)
{
	unsigned long t0 = a + 1, t1 = a + 2;
	unsigned long s = t0 ^ t1;
	unsigned long u = s + t0 * b + t1 * b;

	*c = s;
	*d = u;
}

/* five params: positions 0, 1 and 4 are arg-aligned and were always right --
 * only 2 and 3 could be lost, so a passing test must pin all three outputs */
static void five(unsigned long a, unsigned long b,
                 unsigned long *c, unsigned long *d, unsigned long *e)
{
	unsigned long t0 = a + 1, t1 = a + 2;
	unsigned long s = t0 ^ t1;
	unsigned long u = s + t0 * b + t1 * b;

	*c = s;
	*d = u;
	*e = s + u;
}

int main(void)
{
	unsigned long hi = 0, lo = 0, x = 0, y = 0, z = 0;
	int r = 0;

	/* window values from a 192-bit reduction */
	mul64(0x1e42d130773b76UL, 0x27bac7ebe5f17b3dUL, &hi, &lo);
	r += hi == 0x4b2420c3281b4UL;
	r += lo == 0xf30205e35e10dd1eUL;

	/* both out-params written, and to their OWN addresses */
	two(10, 20, &x, &y);
	r += x == 7;
	r += y == 467;

	x = 0; y = 0;
	five(10, 20, &x, &y, &z);
	r += x == 7;
	r += y == 467;
	r += z == 474;

	/* the pointers must stay distinct: a collapse writes one twice */
	x = 111; y = 222;
	two(1, 1, &x, &y);
	r += x != y;

	return r;
}
