/* an inline helper whose local's address goes only to an overflow builtin (linux's
 * kmalloc_array: `if (__builtin_mul_overflow(n, size, &bytes)) return NULL;`): the product, the
 * overflow it reports, and add/sub beside it, with constant and runtime operands. moon.sh holds
 * that it is spliced; this holds what it answers. freestanding, exit-code only. */

typedef unsigned long size_t;

static size_t got;
static __attribute__((__noinline__)) void *take(size_t bytes) { got = bytes; return &got; }

static inline void *arr(size_t n, size_t size)
{
	size_t bytes;
	if (__builtin_mul_overflow(n, size, &bytes))
		return 0;
	return take(bytes);
}

static inline int span(int a, int b, int *lo)
{
	int s, d;
	if (__builtin_add_overflow(a, b, &s) || __builtin_sub_overflow(a, b, &d))
		return -1;
	*lo = d;
	return s;
}

int main(void)
{
	volatile size_t big = (size_t)1 << 62, n = 3;
	int bad = 0, lo = 0;
	if (arr(4, 8) != &got || got != 32) bad |= 1;
	if (arr(n, 5) != &got || got != 15) bad |= 2;
	if (arr(big, 8) != 0 || got != 15) bad |= 4;
	if (span(7, 2, &lo) != 9 || lo != 5) bad |= 8;
	if (span(0x7fffffff, 1, &lo) != -1 || lo != 5) bad |= 16;
	return bad;
}
