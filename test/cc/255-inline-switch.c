/* an always_inline body is spliced where it is called, as gcc does at -O0: a switch holding
 * returns with more after it (linux's cpucap_is_possible), a break at the switch's level that
 * must still meet that tail, and a return address read inside (kmalloc's _RET_IP_). spliced,
 * __builtin_return_address(0) is the caller's own; a real call answers its own call site.
 * freestanding, exit-code only. */

static inline __attribute__((__always_inline__)) void *pick(int x, void *other)
{
	switch (x) {
	case 1: return __builtin_return_address(0);
	case 2: return other;
	default: break;
	}
	return 0;
}

static inline __attribute__((__always_inline__)) int tail(int x, void **at)
{
	int r = 1;
	switch (x) {
	case 1: r = 5; break;
	case 2: return 7;
	case 3: r = 2;   /* falls out */
	}
	r *= 3;
	*at = __builtin_return_address(0);
	return r;
}

static inline __attribute__((__always_inline__)) int caps(const unsigned cap)
{
	switch (cap) {
	case 46: return 1;
	case 21: return 1;
	default: break;
	}
	return 0;
}

static inline __attribute__((__always_inline__)) void *ip(void) { return __builtin_return_address(0); }

static __attribute__((__noinline__)) int site(volatile int *v)
{
	void *me = __builtin_return_address(0), *at = 0;
	int bad = 0, z;
	if (pick(1, 0) != me) bad |= 1;
	if (pick(2, &z) != &z || pick(*v, 0) != 0) bad |= 2;
	if (tail(1, &at) != 15 || at != me) bad |= 4;
	at = 0;
	if (tail(2, &at) != 7 || at != 0) bad |= 8;
	if (tail(3, &at) != 6 || tail(*v, &at) != 3 || at != me) bad |= 16;
	if (!caps(46) || !caps(21) || caps(7) || caps(*v)) bad |= 32;
	if (ip() != me) bad |= 64;
	return bad;
}

int main(void)
{
	volatile int v = 9;
	return site(&v);
}
