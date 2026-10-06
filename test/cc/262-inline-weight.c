/* an inline helper weighed by its structure, not the spelling of its names: linux's
 * kmalloc_array -- long names, a helper around an overflow builtin, __builtin_expect(!!(..))
 * inside it -- and a short-named twin of the same shape answer alike; and an overflow builtin
 * over constants, answered whole. moon.sh holds that the long-named one is spliced and that a
 * constant size reaches kmalloc's __builtin_constant_p; this holds what each answers.
 * freestanding, exit-code only. */

typedef unsigned long size_t;

static size_t got;
static __attribute__((__noinline__)) void *the_slow_path_allocator(size_t bytes, unsigned flags) { got = bytes + flags; return &got; }

static inline _Bool __must_check_overflow_of_the_product(_Bool overflow) { return __builtin_expect(!!(overflow), 0); }

static inline void *kmalloc_array_noprof_like_helper(size_t number_of_elements, size_t size_of_each, unsigned allocation_flags)
{
	size_t total_bytes_requested;
	if (__must_check_overflow_of_the_product(__builtin_mul_overflow(number_of_elements, size_of_each, &total_bytes_requested)))
		return ((void *)0);
	return the_slow_path_allocator(total_bytes_requested, allocation_flags);
}

static inline void *k(size_t n, size_t s, unsigned f)
{
	size_t b;
	if (__must_check_overflow_of_the_product(__builtin_mul_overflow(n, s, &b)))
		return ((void *)0);
	return the_slow_path_allocator(b, f);
}

/* constant operands into a local written by nothing else: answered at compile time, the
 * value at the local's width and whether it fit */
static int folds(void)
{
	int bad = 0;
	int i; signed char c; unsigned u; size_t z; long l;
	if (!__builtin_add_overflow(0x7fffffff, 1, &i) || i != -0x7fffffff - 1) bad |= 1;
	if (!__builtin_mul_overflow(16, 8, &c) || c != -128) bad |= 2;
	if (!__builtin_sub_overflow(0u, 1, &u) || u != 0xffffffffu) bad |= 4;
	if (__builtin_mul_overflow((size_t)3, sizeof(long), &z) || z != 24) bad |= 8;
	if (__builtin_add_overflow(-5, 3, &l) || l != -2) bad |= 16;
	return bad;
}

int main(void)
{
	volatile size_t n = 3, big = (size_t)1 << 62;
	int bad = folds() << 4;
	if (kmalloc_array_noprof_like_helper(4, 8, 1) != &got || got != 33) bad |= 1;
	if (kmalloc_array_noprof_like_helper(n, 5, 2) != &got || got != 17) bad |= 2;
	if (kmalloc_array_noprof_like_helper(big, 8, 0) != 0 || got != 17) bad |= 4;
	if (k(4, 8, 1) != &got || got != 33 || k(big, 8, 0) != 0) bad |= 8;
	return bad;
}
