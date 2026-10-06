/* an inline helper weighed by its structure, not the spelling of its names: linux's
 * kmalloc_array -- long names, __builtin_expect(!!(..)) around a helper around an overflow
 * builtin -- and a short-named twin of the same shape answer alike. moon.sh holds that the
 * long-named one is spliced; this holds what both answer. freestanding, exit-code only. */

typedef unsigned long size_t;

static size_t got;
static __attribute__((__noinline__)) void *the_slow_path_allocator(size_t bytes, unsigned flags) { got = bytes + flags; return &got; }

static inline _Bool __must_check_overflow_of_the_product(_Bool overflow) { return __builtin_expect(!!(overflow), 0); }

static inline void *kmalloc_array_noprof_like_helper(size_t number_of_elements, size_t size_of_each, unsigned allocation_flags)
{
	size_t total_bytes_requested;
	if (__builtin_expect(!!(__must_check_overflow_of_the_product(__builtin_mul_overflow(number_of_elements, size_of_each, &total_bytes_requested))), 0))
		return ((void *)0);
	return the_slow_path_allocator(total_bytes_requested, allocation_flags);
}

static inline void *k(size_t n, size_t s, unsigned f)
{
	size_t b;
	if (__builtin_expect(!!(__must_check_overflow_of_the_product(__builtin_mul_overflow(n, s, &b))), 0))
		return ((void *)0);
	return the_slow_path_allocator(b, f);
}

int main(void)
{
	volatile size_t n = 3, big = (size_t)1 << 62;
	int bad = 0;
	if (kmalloc_array_noprof_like_helper(4, 8, 1) != &got || got != 33) bad |= 1;
	if (kmalloc_array_noprof_like_helper(n, 5, 2) != &got || got != 17) bad |= 2;
	if (kmalloc_array_noprof_like_helper(big, 8, 0) != 0 || got != 17) bad |= 4;
	if (k(4, 8, 1) != &got || got != 33 || k(big, 8, 0) != 0) bad |= 8;
	return bad;
}
