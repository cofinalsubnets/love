/* the 5th integer parameter used as a pointer addresses its pointee, not the frame
 * (a64: it arrives in x4, the frame register's number). keep all six parameters
 * live, or the 5th never stays in its arrival register. each check adds 1: the exit code is the pass count. */

#include <stdio.h>

struct span {
	const char *init;
	const char *end;
	const char *p_end;
	void *owner;
	int depth;
};

/* six parameters, the last two a pointer and its length, written into a
 * caller-owned struct */
static void prepstate(struct span *ms, void *owner,
                      const char *s, unsigned long ls,
                      const char *p, unsigned long lp)
{
	ms->owner = owner;
	ms->depth = 200;
	ms->init = s;
	ms->end = s + ls;
	ms->p_end = p + lp;
}

/* the 5th parameter DEREFERENCED rather than offset */
static long deref5(long a, long b, long c, long d, const long *p, long n)
{
	return p[0] + p[n] + (p[1] * 2);
}

/* the 5th parameter STORED THROUGH */
static void store5(long a, long b, long c, long d, long *out, long n)
{
	out[0] = n;
	out[1] = n + 1;
	out[n] = 99;
}

int main(void)
{
	struct span ms;
	const char *s = "hello";
	const char *p = "ell";
	long v[4] = {10, 20, 30, 40};
	long w[4] = {0, 0, 0, 0};
	int r = 0;

	prepstate(&ms, (void *)0, s, 5, p, 3);
	r += ms.init == s;
	r += ms.end == s + 5;
	r += ms.p_end == p + 3;      /* the one that came out as sp + 3 */
	r += ms.depth == 200;

	/* and the same three spans measured, so a wrong answer PRINTS */
	printf("%d %d %d\n", (int)(ms.init - s), (int)(ms.end - s),
	       (int)(ms.p_end - p));

	r += deref5(1, 2, 3, 4, v, 3) == 10 + 40 + 40;
	r += deref5(1, 2, 3, 4, v, 0) == 10 + 10 + 40;

	store5(1, 2, 3, 4, w, 3);
	r += w[0] == 3;
	r += w[1] == 4;
	r += w[3] == 99;
	r += w[2] == 0;

	printf("%ld %ld %ld %ld\n", w[0], w[1], w[2], w[3]);

	return r;
}
