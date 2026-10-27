/* a register variable in x30 rides an asm "+r" (the kernel's xpaclri): the frame saves lr,
 * a leaf's too. exit-code only */
static unsigned long strip(unsigned long p)
{
#if defined(__aarch64__)
	register unsigned long r asm("x30") = p;
	asm("add %0, %0, #3" : "+r" (r));
#else
	unsigned long r = p + 3;
#endif
	return r;
}

static __attribute__((noinline)) unsigned long leaf(unsigned long p) { return strip(p); }

int main(int argc, char **argv)
{
	(void)argv;
	return (int)(leaf(argc + 4) + strip(argc));
}
