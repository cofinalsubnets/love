/* an alloca left of an operator runs before the right is parked: gnulib's malloca,
 * ((uintptr_t) alloca (n + 15) + 15) & ~15. exit-code only */
typedef unsigned long uptr;
#define amalloca(n) ((n) < 4000 ? (void *)(((uptr)(char *)__builtin_alloca((n) + 15) + 15) & ~(uptr)15) : (void *)0)

static int fill(int n)
{
	int *a = amalloca(n * sizeof(int));
	int i, s = 0;
	if (!a || ((uptr)a & 15))
		return 99;
	for (i = 0; i < n; i++)
		a[i] = i + 1;
	for (i = 0; i < n; i++)
		s += a[i];
	return s + (int)(((uptr)__builtin_alloca(8) + 1) & 1);
}

int main(int argc, char **argv)
{
	(void)argv;
	return fill(argc + 9) + fill(4);
}
