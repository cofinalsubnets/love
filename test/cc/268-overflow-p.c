/* gcc's __builtin_{add,sub,mul}_overflow_p: whether the answer fits the third operand's type,
 * whose value is not used, though gcc evaluates it (gnulib's intprops.h takes them under
 * __GNUC__ >= 7). clang has none. exit-code only. */
static int side;

static int bump(void)
{
	return ++side;
}

int main(void)
{
	int a = 2147483647, bad = 0;
	long long big = 1LL << 62;

	bad |= !__builtin_add_overflow_p(a, 1, (int)0);
	bad |= __builtin_add_overflow_p(a, 1, (long long)0) << 1;
	bad |= !__builtin_sub_overflow_p(0u, 1u, (unsigned)0) << 2;
	bad |= __builtin_sub_overflow_p(0, 1, (int)0) << 3;
	bad |= !__builtin_mul_overflow_p(3, 100, (unsigned char)0) << 4;
	bad |= __builtin_mul_overflow_p(3, 80, (unsigned char)0) << 5;
	bad |= !__builtin_mul_overflow_p(big, 4, (long long)0) << 6;
	bad |= (__builtin_add_overflow_p(1, 2, (int)bump()) || side != 1) << 7;
	return bad;
}
