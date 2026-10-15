/* __builtin_constant_p where gcc -O0 agrees: a literal or constant expression reads 1, a param
 * of a non-inlined function 0, the operand never evaluated. exit-code only. */

static int hits;
static int bump(void) { return ++hits; }

__attribute__((__noinline__)) static int z(int n)
{
	return __builtin_constant_p(n) * 4 + __builtin_constant_p(5) * 2 + __builtin_constant_p(sizeof(long) + 1);
}

int main(void)
{
	int bad = 0;
	if (z(3) != 3) bad |= 1;
	if (__builtin_constant_p(bump()) || hits != 0) bad |= 2;   /* never evaluated */
	static const int k = __builtin_constant_p(7) ? 11 : 22;
	if (k != 11) bad |= 4;
	return bad;
}
