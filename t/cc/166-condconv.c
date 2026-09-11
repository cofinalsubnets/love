/* C11 6.5.15p5: where both arms of a `?:` are arithmetic, the result takes the usual
 * arithmetic conversions over the TWO of them -- the same law a binary operator's
 * operands meet. So `(1 ? -1 : 0u)` is unsigned, value 4294967295, whatever the dead
 * arm does at runtime, and the compare, divide, shift or widening that reads it next
 * goes by that type.
 *
 * The rows below are the conversions themselves, not the branch: every pair of ranks
 * and signednesses that can meet, each one read back through an operator that can tell
 * the answers apart (a compare's signedness, a divide's, a shift's, and the widening
 * to 64 bits, which is the one that catches a right type carrying a wrong extension).
 * The arms come in both faces -- literal and variable -- since a literal's type is the
 * one C reads off the source, not the one the register wears.
 *
 * The non-arithmetic arms ride along as a guard: a float, a pointer, a struct or a
 * void arm must keep answering what it always did. */
#include <stdio.h>

static int c1(void) { return 1; }
static int c0(void) { return 0; }

struct P { int a; long b; };

int main(void)
{
	int c = c1(), z = c0();
	long t = 0;

	/* -- constant arms, the pair that started this: int meets unsigned at unsigned */
	printf("a %d %d\n", (1 ? -1 : 0u) > 0, (0 ? 0u : -1) > 0);
	t += ((1 ? -1 : 0u) > 0) + ((0 ? 0u : -1) > 0);
	printf("b %lu %lu\n", (unsigned long) (1 ? -1 : 0u), (unsigned long) (0 ? 0u : -1));
	t += (long) ((unsigned long) (1 ? -1 : 0u) >> 24);

	/* ..and the ranks that beat it: a signed long is wider than every unsigned int */
	printf("c %d %d %d\n", (1 ? -1 : 0l) > 0, (1 ? -1 : 0ul) > 0, (1 ? -1 : 0) > 0);
	t += ((1 ? -1 : 0l) > 0) + ((1 ? -1 : 0ul) > 0) + ((1 ? -1 : 0) > 0);

	/* -- the same pairs through variables, where the literal's own face cannot help */
	{
		int n = -1, n4 = -4, n8 = -8;
		unsigned u = 1u, u3 = 3u;
		long L = -1;
		unsigned long UL = 1ul;
		signed char sc = -1;
		unsigned char uc = 1;
		unsigned short us = 1;

		printf("d %d %d\n", (c ? n : u) > 0, (c ? u : n) > 0);
		t += ((c ? n : u) > 0) + ((c ? u : n) > 0);
		printf("e %lu %ld\n", (unsigned long) (c ? n : u), (long) (c ? u : n));
		t += (long) ((unsigned long) (c ? n : u) >> 28);

		/* long vs unsigned int: the signed type is strictly wider, so it wins */
		printf("f %d %d\n", (c ? L : u) > 0, (c ? u : L) > 0);
		t += ((c ? L : u) > 0) + ((c ? u : L) > 0);
		/* ..and unsigned long against a signed anything does not lose */
		printf("g %d %d\n", (c ? n : UL) > 0, (c ? UL : n) > 0);
		t += ((c ? n : UL) > 0) + ((c ? UL : n) > 0);

		/* both arms narrower than int: they promote, and the result is signed */
		printf("h %d %d\n", (c ? sc : uc) > 0, (c ? sc : us) > 0);
		t += ((c ? sc : uc) > 0) + ((c ? sc : us) > 0);
		/* ..unless one of them is already unsigned int */
		printf("i %d\n", (c ? sc : u) > 0);
		t += (c ? sc : u) > 0;

		/* a divide and a remainder read the signedness too */
		printf("j %u %u\n", (c ? n4 : u3) / 3u, (c ? n : u) % 5u);
		t += (long) ((c ? n4 : u3) / 3u >> 20);
		/* ..and a right shift picks logical or arithmetic by it */
		printf("k %u %d\n", (c ? n8 : u) >> 1, (c ? n8 : 0) >> 1);
		t += (long) ((c ? n8 : u) >> 28) + ((c ? n8 : 0) >> 1);

		/* an unsigned int result wraps at 32 bits, and the ternary must not
		 * hand its consumer a 64-bit carrier that skips the wrap */
		{
			unsigned big = 0x80000000u;
			printf("l %lu\n", (unsigned long) ((c ? 3 : 4) * big));
			t += (long) ((unsigned long) ((c ? 3 : 4) * big) >> 28);
		}

		/* the zero arm is the one a folded branch drops: both directions */
		printf("m %lu %lu\n", (unsigned long) (z ? 0u : n), (unsigned long) (z ? n : 0u));
		t += (long) ((unsigned long) (z ? 0u : n) >> 28);

		/* sizeof reads the same law, at the typing door rather than the machine */
		printf("n %d %d %d\n", (int) sizeof(c ? sc : uc), (int) sizeof(c ? n : L),
		       (int) sizeof(c ? u : n));
		t += (long) (sizeof(c ? sc : uc) + sizeof(c ? n : L));
	}

	/* -- the guard: arms that are not both arithmetic answer what they always did */
	{
		double d = 2.5;
		int n = 1;
		struct P p1 = { 3, 4 }, p2 = { 5, 6 };
		int arr[2] = { 7, 8 };
		int *pa = arr, *pb = arr + 1;

		printf("o %.1f %.1f\n", c ? n : d, c ? d : n);
		t += (long) ((c ? n : d) * 2.0) + (long) ((c ? d : n) * 2.0);
		printf("p %d %ld\n", (c ? p1 : p2).a, (c ? p2 : p1).b);
		t += (c ? p1 : p2).a + (c ? p2 : p1).b;
		printf("q %d %d\n", *(c ? pa : pb), *(z ? pa : pb));
		t += *(c ? pa : pb) + *(z ? pa : pb);
		printf("r %d\n", (c ? pa : (int *) 0) == arr);
		t += (c ? pa : (int *) 0) == arr;
		if (c) (void) 0; else (void) 0;
	}

	printf("t %ld\n", t);
	return (int) (t & 0x3f);
}
