/* __builtin_alloca, which gnulib and m4's regex take under __GNUC__: a block that holds through
 * the function that asked for it, each call its own, nested calls apart. exit-code only. */
#include <string.h>

static int fill(int n, int depth)
{
	unsigned char *p = __builtin_alloca(n);
	int s = 0;

	memset(p, depth, n);
	if (depth < 3)
		s = fill(n + 5, depth + 1);
	for (int i = 0; i < n; i++)
		s += p[i] != depth;
	return s;
}

int main(void)
{
	int bad = 0;

	for (int n = 1; n < 300; n += 7)
		bad += fill(n, 0);
	return bad;
}
