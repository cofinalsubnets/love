/* C99 VLAs: a runtime-dim local, sizeof over one, a decl re-executed in a loop, a
 * runtime-stride pointee, a 2D outer-runtime array, sizeof of a VLA type. the loop
 * is the leak canary: 10000 x 8KB of stack if a pass does not free its block. */

typedef unsigned long size_t;

static int sum(int n)
{
	int a[n + 1];
	int i, s = 0;
	for (i = 0; i <= n; i++) a[i] = i;
	for (i = 0; i <= n; i++) s += a[i];
	return s + (int)(sizeof a / sizeof(int));      /* 10 + 5 */
}

static int looper(int iters, int sz)
{
	int i, s = 0;
	for (i = 0; i < iters; i++) {
		char b[sz];                            /* re-executed: frees the prior block */
		b[0] = (char)i;
		b[sz - 1] = 7;
		s += b[0] + b[sz - 1];
	}
	return s & 0xff;
}

static int stride(void *base, size_t n, size_t width)
{
	char (*p)[width] = base;                       /* the runtime stride */
	int s = 0;
	size_t i;
	for (i = 0; i < n; i++) s += p[i][0] + p[i][width - 1];
	return s;
}

static int two(int n)
{
	int a[n], m;
	char g[n][4];                                  /* outer runtime, inner const */
	for (m = 0; m < n; m++) { a[m] = m * 2; g[m][3] = (char)m; }
	return a[n - 1] + g[n - 1][3] + (int)sizeof(int [n]);   /* 10 + 5 + 24 */
}

int main(void)
{
	char grid[3][5];
	int r, i;
	for (i = 0; i < 3; i++) { grid[i][0] = i + 1; grid[i][4] = 10 * (i + 1); }
	r = sum(4);                                    /* 15 */
	r += looper(10000, 8192);                      /* the canary */
	r += stride(grid, 3, 5);                       /* 66 */
	r += two(6);                                   /* 39 */
	return r & 0xff;
}
