/* unary minus on float, double and _Complex is negation, not 0.0 - x: only a sign
 * flip makes -0.0. the zero cases are the point; NaN's sign is not asserted. */

static int dneg(double d)      /* through a call, so nothing is folded away */
{
	union { double d; unsigned long u; } b;
	b.d = -d;
	return (int) (b.u >> 63);
}

static int fneg(float f)
{
	union { float f; unsigned u; } b;
	b.f = -f;
	return (int) (b.u >> 31);
}

static double dbits(unsigned long u)
{
	union { double d; unsigned long u; } b;
	b.u = u;
	return b.d;
}

int main(void)
{
	volatile double pz = 0.0, one = 1.0, big = 1e308;
	volatile float fz = 0.0f, fone = 1.0f;
	double nz = dbits(0x8000000000000000UL);
	int r = 0;

	/* THE CASE THAT MATTERS: -(+0.0) is -0.0, and -(-0.0) is +0.0 */
	r += dneg(pz) == 1;
	r += dneg(nz) == 0;
	r += fneg(fz) == 1;

	/* the ordinary values keep working */
	r += dneg(one) == 1;
	r += dneg(-one) == 0;
	r += dneg(big) == 1;
	r += fneg(fone) == 1;
	r += fneg(-fone) == 0;

	/* the value is negated, not merely the sign bit */
	r += (-one == -1.0) ? 1 : 0;
	r += (-(-one) == 1.0) ? 1 : 0;
	r += (-2.5 == 0.0 - 2.5) ? 1 : 0;

	/* ..and -0.0 still COMPARES equal to 0.0, which is why the sign bit is
	   the only way to see this at all */
	r += (-pz == 0.0) ? 1 : 0;

	/* double negation of a zero returns to +0.0 */
	{ union { double d; unsigned long u; } b;
	  b.d = -(-pz);
	  r += (b.u >> 63) == 0; }

	/* infinity flips too */
	r += dneg(dbits(0x7FF0000000000000UL)) == 1;
	r += dneg(dbits(0xFFF0000000000000UL)) == 0;

	return r;
}
