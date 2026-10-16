/* a double converts to unsigned 64-bit unsigned at or above 2^63, exactly, at
 * every site with a destination type: cast, store, initializer, argument, return.
 * negative, out-of-range and NaN sources are undefined and not asserted. */

static unsigned long d2u(double d)          /* through a call, so nothing folds */
{
	return (unsigned long) d;
}

static unsigned long viastore(double d)     /* the store lane, no cast */
{
	unsigned long v;
	v = d;
	return v;
}

static unsigned long viainit(double d)      /* the initializer lane */
{
	unsigned long v = d;
	return v;
}

static unsigned long takes(unsigned long v) { return v; }

static unsigned long viaarg(double d)       /* the outgoing-argument lane */
{
	return takes(d);
}

static unsigned long viaret(double d)       /* the return lane */
{
	return d;
}

int main(void)
{
	int r = 0;

	/* below 2^63: the signed lane was already right, and must stay right */
	r += d2u(0.0) == 0UL;
	r += d2u(1.0) == 1UL;
	r += d2u(9.3e18) == 9300000000000000000UL;

	/* AT AND ABOVE 2^63 -- every one of these saturated */
	r += d2u(9223372036854775808.0) == 9223372036854775808UL;      /* exactly 2^63 */
	r += d2u(1.0e19) == 10000000000000000000UL;
	r += d2u(18446744073709549568.0) == 18446744073709549568UL;    /* the largest exact */

	/* the truncation still truncates toward zero, above the boundary too */
	r += d2u(1.0e19 + 0.5) == 10000000000000000000UL;
	r += d2u(3.9) == 3UL;

	/* every lane with a destination type, not just the cast */
	r += viastore(1.0e19) == 10000000000000000000UL;
	r += viainit(1.0e19) == 10000000000000000000UL;
	r += viaarg(1.0e19) == 10000000000000000000UL;
	r += viaret(1.0e19) == 10000000000000000000UL;

	/* the round trip, both new lanes composed */
	r += (unsigned long) (double) 9223372036854775808UL == 9223372036854775808UL;
	r += (unsigned long) (double) 18446744073709549568UL == 18446744073709549568UL;

	/* the narrower unsigned types keep taking the signed-then-narrow lane */
	r += (unsigned int) 3000000000.0 == 3000000000U;
	r += (unsigned short) 65535.0 == 65535;

	/* and a signed destination is untouched by any of this */
	r += (long) -1.5 == -1L;
	r += (long) 9.2e18 == 9200000000000000000L;

	return r;
}
