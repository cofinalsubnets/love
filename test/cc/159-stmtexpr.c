/* gcc's statement expression, ({ .. }), held to gcc: its value is the last
 * statement when that is an expression, the block's own scope, short-circuit
 * across one, nesting, a loop inside, and the two macros the linux kernel
 * builds out of it (min/max and READ_ONCE). */
#include <stdio.h>

#define max(a, b) ({ __typeof__(a) _a = (a); __typeof__(b) _b = (b); _a > _b ? _a : _b; })
#define READ_ONCE(x) ({ __typeof__(x) __v = *(const volatile __typeof__(x) *)&(x); __v; })

struct node { struct node *next; int v; };

static int sum3(int a, int b, int c)
{
	return ({ int t = a + b; t += c; t; });
}

static int nested(int x)
{
	return ({ int o = ({ int i = x * 2; i + 1; }); o * 10; });
}

static int loopy(int n)
{
	return ({ int s = 0; for (int i = 0; i < n; i++) s += i; s; });
}

static int voidsx(int *p)
{
	({ *p = 5; });          /* void: the last statement is an expression statement,
				   but its value is discarded here */
	return *p;
}

static int inbranch(int x)
{
	/* short-circuit: the right arm must not run when the left is false */
	int side = 0;
	int r = (x > 0) && ({ side = 1; x < 10; });
	return r * 10 + side;
}

static int incond(int x)
{
	return ({ int a = x; a; }) > 3 ? max(x, 7) : max(x, 1);
}

static long structy(struct node *n)
{
	return ({ struct node *p = n; p->v + (p->next ? p->next->v : 0); });
}

static int decls(void)
{
	int outer = 100;
	int r = ({ int outer = 1; outer + 2; });   /* the inner one shadows */
	return r * 1000 + outer;
}

int main(void)
{
	struct node b = { 0, 4 }, a = { &b, 3 };
	int p = 7;
	int volatile vv = 12;
	int A = sum3(1, 2, 3);
	int B = nested(5);
	int C = loopy(5);
	int D = voidsx(&p);
	int E = inbranch(5) + inbranch(-1) * 100;
	int F = incond(4) + incond(2);
	long G = structy(&a);
	int H = decls();
	int I = max(3, 9) + max(9, 3);
	int J = READ_ONCE(vv);
	printf("%d %d %d %d %d %d %ld %d %d %d\n", A, B, C, D, E, F, G, H, I, J);
	return (A + B + C + D + E + F + (int) G + H + I + J) & 0x7f;
}
