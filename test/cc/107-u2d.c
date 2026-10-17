/* an unsigned 64-bit value converts to double unsigned, correctly rounded: exact
 * bit patterns just under 2^63, at it, and above it. */

static double u2d(unsigned long u)   /* through a call, so nothing folds */
{
	return (double) u;
}

static unsigned long bits(double d)
{
	union { double d; unsigned long u; } b;
	b.d = d;
	return b.u;
}

int main(void)
{
	int r = 0;

	/* below 2^63: the signed lane was already correct, and must stay so */
	r += bits(u2d(0UL)) == 0x0000000000000000UL;
	r += bits(u2d(1UL)) == 0x3ff0000000000000UL;
	r += bits(u2d(0x7fffffffffffffffUL)) == 0x43e0000000000000UL;

	/* AT AND ABOVE 2^63 -- every one of these went negative */
	r += bits(u2d(0x8000000000000000UL)) == 0x43e0000000000000UL;
	r += bits(u2d(0x8000000000000001UL)) == 0x43e0000000000000UL;
	r += bits(u2d(0xc000000000000001UL)) == 0x43e8000000000000UL;
	r += bits(u2d(0xffffffffffffffffUL)) == 0x43f0000000000000UL;
	r += bits(u2d(0xfffffffffffff800UL)) == 0x43efffffffffffffUL;

	/* a word whose middle crosses 2^63 */
	r += bits(u2d(0xb81669940ac0e972UL)) == 0x43e702cd3281581dUL;

	/* the sign is the coarsest symptom: nothing unsigned converts negative */
	r += u2d(0x8000000000000000UL) > 0.0;
	r += u2d(0xffffffffffffffffUL) > 0.0;

	/* ..and the magnitude is right, not merely positive */
	r += u2d(0xffffffffffffffffUL) > 1.8e19;
	r += u2d(0x8000000000000000UL) == 9223372036854775808.0;

	/* the 32-bit unsigned types keep taking the widening lane */
	{ unsigned int w = 0xffffffffU;
	  r += (double) w == 4294967295.0; }
	{ unsigned short h = 0xffff;
	  r += (double) h == 65535.0; }

	/* a signed long is untouched by any of this */
	r += (double) (long) -1 == -1.0;

	return r;
}
