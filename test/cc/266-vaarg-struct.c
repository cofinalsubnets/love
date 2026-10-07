/* va_arg of a small by-value struct: a gp composite of 16 bytes or less takes its slots whole, from
 * the register save area while they last, else from the stack -- and on a64 a composite sent to the
 * stack closes the gp file behind it, so a later scalar comes from the stack too. linux's
 * p9pdu_vwritef reads kuid_t this way. every check contributes 1: the exit code is the count. */

#include <stdarg.h>

struct s3 { char a, b, c; };
struct s4 { int v; };
struct s8 { int a, b; };
struct s12 { int a, b, c; };
struct s16 { long a, b; };

static int regs(int n, ...)          /* every one fits the gp registers */
{
	va_list ap;
	struct s4 a; struct s12 b; struct s3 c;
	int r = 0;

	va_start(ap, n);
	a = va_arg(ap, struct s4);
	b = va_arg(ap, struct s12);
	c = va_arg(ap, struct s3);
	r += a.v == 40;
	r += b.a == 1 && b.b == 2 && b.c == 3;
	r += c.a == 'x' && c.b == 'y' && c.c == 'z';
	r += va_arg(ap, int) == n;
	va_end(ap);
	return r;
}

/* x0 n, x1 s4, x2-x3 s12, x4-x5 s16, x6 s8: the next s16 wants two with one left */
static int spill(int n, ...)
{
	va_list ap;
	struct s4 a; struct s12 b; struct s16 c, e; struct s8 d; struct s3 f;
	int r = 0;

	va_start(ap, n);
	a = va_arg(ap, struct s4);
	b = va_arg(ap, struct s12);
	c = va_arg(ap, struct s16);
	d = va_arg(ap, struct s8);
	e = va_arg(ap, struct s16);
	f = va_arg(ap, struct s3);
	r += a.v == 40;
	r += b.a == 1 && b.b == 2 && b.c == 3;
	r += c.a == 1L << 40 && c.b == -5;
	r += d.a == 6 && d.b == 7;
	r += e.a == 8 && e.b == 9;
	r += f.a == 'x' && f.b == 'y' && f.c == 'z';
	r += va_arg(ap, long) == 11;
	r += va_arg(ap, int) == n;
	va_end(ap);
	return r;
}

/* a struct read in a loop, the way a format walker reads it */
static long sum(int n, ...)
{
	va_list ap;
	long s = 0;
	int i;

	va_start(ap, n);
	for (i = 0; i < n; i++) {
		struct s8 p = va_arg(ap, struct s8);
		s += p.a * 10 + p.b;
	}
	va_end(ap);
	return s;
}

int main(void)
{
	struct s3 c = { 'x', 'y', 'z' };
	struct s4 a = { 40 };
	struct s8 d = { 6, 7 }, q[6] = { {1, 2}, {3, 4}, {5, 6}, {7, 8}, {9, 0}, {2, 1} };
	struct s12 b = { 1, 2, 3 };
	struct s16 e = { 1L << 40, -5 }, h = { 8, 9 };
	int r = 0;

	r += regs(77, a, b, c, 77);
	r += spill(55, a, b, e, d, h, c, 11L, 55);
	r += sum(6, q[0], q[1], q[2], q[3], q[4], q[5]) == 12 + 34 + 56 + 78 + 90 + 21;
	return r;
}
