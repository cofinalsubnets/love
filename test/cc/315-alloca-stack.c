/* __builtin_alloca on the caller's stack: below its locals, 8-aligned (arm keeps sp so), each
 * in a loop held to the return, intact across a call with stack arguments, stored through an
 * index or passed as an argument, and laid under a cast, a comma or an assignment as gnulib's
 * regex lays it; an argument's alloca hoisted out of an arm or a return keeps the arms apart.
 * exit-code only (55) */
#include <string.h>

__attribute__((noinline)) static long ten(long a, long b, long c, long d, long e, long f, long g, long h, long i, long j)
{ return a + b + c + d + e + f + g + h + i + j; }

__attribute__((noinline)) static int three(void)
{ return (int) strlen(strcpy(__builtin_alloca(4), "abc")); }

__attribute__((noinline)) static int run(int n)
{
	char here;
	char *ps[8];
	int ok = 0;

	for (int i = 0; i < 8; i++) {          /* a loop's blocks accumulate */
		ps[i] = __builtin_alloca(n + i);
		memset(ps[i], 'a' + i, n + i);
	}
	ok += (char *) ps[0] < &here && &here - (char *) ps[0] < 65536;
	ok += ((unsigned long) ps[3] & 7) == 0 && ps[1] < ps[0];
	ok += ten(1, 2, 3, 4, 5, 6, 7, 8, 9, 10) == 55;
	int same = 1;
	for (int i = 0; i < 8; i++)
		for (int k = 0; k < n + i; k++)
			same &= ps[i][k] == 'a' + i;
	ok += same;

	char *q;
	(q = (char *) __builtin_alloca(n * 2), memcpy(q, ps[7], n));   /* REGEX_REALLOCATE */
	ok += q[n - 1] == 'h';
	ok += strlen(strcpy(__builtin_alloca(4), "abc")) == 3;

	int e = 0;
	if (n)                                  /* no else */
		e = strlen(strcpy(__builtin_alloca(4), "ab"));
	if (n)
		e += strlen(strcpy(__builtin_alloca(4), "a"));
	else
		e = 100;
	ok += e == 3 && three() == 3;
	return ok;
}

int main(void)
{
	return 48 + run(37);
}
