/* __builtin_{add,sub,mul}_overflow as C defines them: the exact value of a op b, each operand
 * in its own type, stored in *r's type modulo its width, and whether it fit there -- for every
 * result width and signedness, mixed-sign operands, and a store that touches *r alone.
 * freestanding, exit-code only. */

typedef unsigned long size_t;

struct guarded { int r; int guard; };

int main(void)
{
	int bad = 0;
	volatile int imax = 0x7fffffff, imin = -0x7fffffff - 1, one = 1, m1 = -1;
	volatile long lmax = 0x7fffffffffffffffL;
	volatile unsigned int umax = 0xffffffffu;
	volatile size_t smax = ~(size_t)0, half = (size_t)1 << 63;

	/* signed char */
	{ signed char c;
	  if (!__builtin_add_overflow(127, one, &c) || c != -128) bad |= 1;
	  if (__builtin_sub_overflow(-127, one, &c) || c != -128) bad |= 1;
	  if (!__builtin_mul_overflow(16, 8, &c) || c != -128) bad |= 1; }
	/* short */
	{ short s;
	  if (!__builtin_add_overflow(32767, one, &s) || s != -32768) bad |= 2;
	  if (__builtin_mul_overflow(-128, 256, &s) || s != -32768) bad |= 2; }
	/* int, and the word beside it untouched */
	{ struct guarded g = { 0, 0x5a5a5a5a };
	  if (!__builtin_add_overflow(imax, one, &g.r) || g.r != imin) bad |= 4;
	  if (!__builtin_sub_overflow(imin, one, &g.r) || g.r != imax) bad |= 4;
	  if (__builtin_mul_overflow(-46341, 46340, &g.r) || g.r != -2147441940) bad |= 4;
	  if (!__builtin_mul_overflow(46341, 46341, &g.r) || g.r != -2147479015) bad |= 4;
	  if (g.guard != 0x5a5a5a5a) bad |= 8; }
	/* long */
	{ long l;
	  if (!__builtin_add_overflow(lmax, one, &l) || l != -lmax - 1) bad |= 16;
	  if (__builtin_mul_overflow(lmax, m1, &l) || l != -lmax) bad |= 16;
	  if (!__builtin_mul_overflow(lmax, 2, &l) || l != -2) bad |= 16; }
	/* unsigned int: a negative never fits, the low word is kept */
	{ unsigned int u;
	  if (!__builtin_add_overflow(umax, one, &u) || u != 0) bad |= 32;
	  if (!__builtin_sub_overflow(0u, one, &u) || u != umax) bad |= 32;
	  if (__builtin_sub_overflow(5, 3, &u) || u != 2) bad |= 32;
	  if (!__builtin_mul_overflow(m1, one, &u) || u != umax) bad |= 32; }
	/* size_t: past 2^63 is no overflow, past 2^64 is */
	{ size_t z;
	  if (__builtin_mul_overflow(half, 1, &z) || z != half) bad |= 64;
	  if (!__builtin_mul_overflow(half, 2, &z) || z != 0) bad |= 64;
	  if (!__builtin_add_overflow(smax, one, &z) || z != 0) bad |= 64;
	  if (__builtin_mul_overflow((size_t)3, (size_t)5, &z) || z != 15) bad |= 64;
	  if (!__builtin_mul_overflow(smax, smax, &z) || z != 1) bad |= 64; }
	/* mixed signs: an unsigned operand past every signed result, a negative into unsigned */
	{ long l; int i; size_t z;
	  if (__builtin_add_overflow(half, m1, &l) || l != lmax) bad |= 128;
	  if (!__builtin_add_overflow(half, 0, &l) || l != -lmax - 1) bad |= 128;
	  if (__builtin_add_overflow(half, -lmax - 1, &l) || l != 0) bad |= 128;
	  if (__builtin_sub_overflow(umax, umax, &i) || i != 0) bad |= 128;
	  if (!__builtin_add_overflow(m1, (size_t)0, &z) || z != smax) bad |= 128; }
	return bad;
}
