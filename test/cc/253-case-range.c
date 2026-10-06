/* gcc's case ranges, wide ones too: linux's sysreg switches span thousands of encodings
 * (`case SYS_ID_AA64PFR0_EL1 ... SYS_ID_AA64ZFR0_EL1:`), each one compare, never one label a
 * value; a range across zero, a narrow one, a char control, and a case value past 2^62
 * (MAX_SCHEDULE_TIMEOUT is LONG_MAX; long long here, so 32-bit targets agree). freestanding, exit-code only. */

#define ENC(op0, op1, crn, crm, op2) (((op0) << 19) | ((op1) << 16) | ((crn) << 12) | ((crm) << 8) | ((op2) << 5))

static int sysreg(unsigned v)
{
	switch (v) {
	case ENC(3, 0, 0, 1, 0) ... ENC(3, 0, 0, 7, 7): return 1;   /* ~1760 wide */
	case ENC(3, 0, 1, 0, 0): return 2;
	case 0 ... 100000: return 3;                               /* wider still */
	default: return 0;
	}
}

static int signed_range(int x)
{
	switch (x) {
	case -50 ... 50: return 1;
	case 51 ... 53: return 2;                                  /* narrow: laid a label a value */
	default: return 0;
	}
}

static int chars(char c)
{
	switch (c) {
	case 'a' ... 'z': return 1;
	case '0' ... '9': return 2;
	default: return 0;
	}
}

static int big(long long t)
{
	switch (t) {
	case ((long long)(~0ULL >> 1)): return 1;
	case 0x4000000000000000LL ... 0x4000000000001000LL: return 2;
	default: return 0;
	}
}

int main(void)
{
	volatile unsigned s0 = ENC(3, 0, 0, 1, 0), s1 = ENC(3, 0, 0, 7, 7), s2 = ENC(3, 0, 0, 7, 7) + 1;
	volatile unsigned s3 = ENC(3, 0, 1, 0, 0), s4 = 77777, s5 = ENC(3, 0, 0, 1, 0) - 1;
	volatile int i0 = -51, i1 = -50, i2 = 50, i3 = 52, i4 = 54;
	volatile char c0 = 'q', c1 = '5', c2 = '!';
	volatile long long l0 = (long long)(~0ULL >> 1), l1 = 0x4000000000000800LL, l2 = 0x4000000000001001LL;
	int bad = 0;
	if (sysreg(s0) != 1 || sysreg(s1) != 1 || sysreg(s2) != 0 || sysreg(s5) != 0) bad |= 1;
	if (sysreg(s3) != 2 || sysreg(s4) != 3) bad |= 2;
	if (signed_range(i0) || signed_range(i1) != 1 || signed_range(i2) != 1) bad |= 4;
	if (signed_range(i3) != 2 || signed_range(i4)) bad |= 8;
	if (chars(c0) != 1 || chars(c1) != 2 || chars(c2)) bad |= 16;
	if (big(l0) != 1 || big(l1) != 2 || big(l2)) bad |= 32;
	return bad;
}
