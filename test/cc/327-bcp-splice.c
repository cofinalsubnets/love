/* a dead __builtin_constant_p arm holding an inlined asm goto prunes before the asm's
 * "i" operand is asked for (the kernel's nf_hook over static_key_false). exit-code only */
struct sk { int e; };
struct sk needed[4][8];

static inline __attribute__((__always_inline__)) _Bool asb(struct sk *const key, const _Bool br)
{
	char *k = &((char *)key)[br];
	asm goto("" :: "i"(k) :: y);
	return 0;
y:	return 1;
}

static inline __attribute__((__always_inline__)) _Bool skf(struct sk *key) { return asb(key, 0); }

static int h(unsigned char pf)
{
	if (__builtin_constant_p(pf)) {
		if (!skf(&needed[pf][0]))
			return 3;
	}
	return 3;
}

int main(int argc, char **argv)
{
	(void)argv;
	return h((unsigned char)argc) + h(2) * 2;
}
