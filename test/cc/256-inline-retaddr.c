/* an always_inline body is spliced as gcc splices it at -O0, so a __builtin_return_address(0)
 * read inside it is the caller's own: kmalloc's _RET_IP_, and one under a switch holding returns
 * with more after it (255's shape). a real call would answer its own call site. freestanding,
 * exit-code only. */

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
	}
	r *= 3;
	*at = __builtin_return_address(0);
	return r;
}

static inline __attribute__((__always_inline__)) void *ip(void) { return __builtin_return_address(0); }

static __attribute__((__noinline__)) int site(void)
{
	void *me = __builtin_return_address(0), *at = 0;
	int bad = 0, z;
	if (pick(1, 0) != me || pick(2, &z) != &z) bad |= 1;
	if (tail(1, &at) != 15 || at != me) bad |= 2;
	if (ip() != me) bad |= 4;
	return bad;
}

int main(void) { return site(); }
