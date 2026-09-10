/* the switch dispatch, on both sides of the density threshold and in the shapes that stress
 * what a jump table costs the analyses. a table's case labels are reachable ONLY through the
 * table -- no branch in the stream names them -- so every pass that reads control flow has to
 * read the table jump's own operands. one that does not decides those blocks are unreachable,
 * and the failures are quiet: a label swept away, a live value called dead across the switch,
 * a known constant carried into an arm the table could reach with a different one.
 *
 * so the rows here are not "does a switch work". they are: a value LIVE across the dispatch
 * and read again in an arm; an arm the body also FALLS INTO, which gives the label a second
 * predecessor with different state; a switch inside a LOOP, whose back edge crosses it; a
 * default reached from below and from above the case range; and the sparse/dense boundary
 * itself, so both lowerings run the same questions. */
#include <stdio.h>

/* dense, past the threshold -- the table lowering */
static long dense(long x, long s)
{
	switch (x) {
	case 0: return s + 1;   case 1: return s + 2;   case 2: return s + 4;
	case 3: return s + 8;   case 4: return s + 16;  case 5: return s + 32;
	case 6: return s + 64;  case 7: return s + 128; case 8: return s + 256;
	case 9: return s + 512;
	default: return s - 1; }
}

/* the same arm set one case short of the threshold -- the compare chain */
static long few(long x, long s)
{
	switch (x) {
	case 0: return s + 1; case 1: return s + 2; case 2: return s + 4;
	case 3: return s + 8; case 4: return s + 16;
	default: return s - 1; }
}

/* too sparse for a table however many cases it has */
static long sparse(long x, long s)
{
	switch (x) {
	case 0: return s + 1;      case 100: return s + 2;   case 1000: return s + 4;
	case 20000: return s + 8;  case 300000: return s + 16;
	case 4000000: return s + 32; case 50000000: return s + 64;
	default: return s - 1; }
}

/* a value live ACROSS the dispatch and read in the arms: if the table's edges are invisible
 * the arms look unreachable and `a`, `b`, `c` can be called dead where they are most alive */
static long live(long x, long a, long b, long c)
{
	long r;
	switch (x) {
	case 0: r = a; break;      case 1: r = b; break;      case 2: r = c; break;
	case 3: r = a + b; break;  case 4: r = b + c; break;  case 5: r = a + c; break;
	case 6: r = a + b + c; break;
	case 7: r = a - b; break;  case 8: r = b - c; break;  case 9: r = c - a; break;
	default: r = 0; break; }
	return r * 3 + a - b + c;               /* all three still live after the switch */
}

/* arms the body also falls INTO: each label has a second predecessor, carrying different
 * state from the one the table brings */
static long fall(long x)
{
	long r = 0;
	switch (x) {
	case 0: r += 1;    /* fallthrough */
	case 1: r += 2;    /* fallthrough */
	case 2: r += 4;    /* fallthrough */
	case 3: r += 8; break;
	case 4: r += 16;   /* fallthrough */
	case 5: r += 32;   /* fallthrough */
	case 6: r += 64; break;
	case 7: r += 128;  /* fallthrough */
	case 8: r += 256; break;
	case 9: r += 512; break;
	default: r = -1; }
	return r;
}

/* the dispatch inside a loop, so a back edge crosses it, and a constant that would be wrong
 * if it rode the table's edge into an arm */
static long loopy(long n)
{
	long s = 0, k = 7;
	for (long i = 0; i < n; i++) {
		switch (i % 12) {
		case 0: k = 1; s += k; break;   case 1: s += k; break;
		case 2: k = 2; s += k; break;   case 3: s += k * 2; break;
		case 4: k = 3; s += k; break;   case 5: s += k * 3; break;
		case 6: k = 4; s += k; break;   case 7: s += k * 4; break;
		case 8: k = 5; s += k; break;   case 9: s += k * 5; break;
		case 10: k = 6; s += k; break;  case 11: s += k * 6; break;
		default: s -= 1; }
	}
	return s + k;
}

/* an unsigned control, and a signed one whose range starts well below zero: the index is the
 * control less the lowest case, and the bound is one UNSIGNED compare -- anything under the
 * low end has to wrap past the top rather than land in the table */
static long uns(unsigned x)
{
	switch (x) {
	case 4294967286u: return 1; case 4294967287u: return 2; case 4294967288u: return 3;
	case 4294967289u: return 4; case 4294967290u: return 5; case 4294967291u: return 6;
	case 4294967292u: return 7; case 4294967293u: return 8; case 4294967294u: return 9;
	case 4294967295u: return 10;
	default: return -1; }
}

static long low(long x)
{
	switch (x) {
	case -1005: return 1; case -1004: return 2; case -1003: return 3; case -1002: return 4;
	case -1001: return 5; case -1000: return 6; case -999: return 7;  case -998: return 8;
	case -997: return 9;  case -996: return 10;
	default: return -1; }
}

int main(void)
{
	long t = 0;
	for (long i = -3; i <= 13; i++) {
		printf("d %ld %ld\n", i, dense(i, 1000));
		printf("w %ld %ld\n", i, few(i, 1000));
		printf("l %ld %ld\n", i, live(i, 7, 11, 13));
		printf("f %ld %ld\n", i, fall((int) i));
		t += dense(i, 1) + few(i, 1) + live(i, 2, 3, 5) + fall((int) i);
	}
	static const long S[] = { -1, 0, 1, 99, 100, 101, 999, 1000, 1001, 19999, 20000,
	                          299999, 300000, 3999999, 4000000, 49999999, 50000000, 50000001 };
	for (unsigned i = 0; i < sizeof S / sizeof *S; i++)
		printf("s %ld %ld\n", S[i], sparse(S[i], 1000));
	for (long n = 0; n <= 25; n++) printf("p %ld %ld\n", n, loopy(n));
	static const unsigned U[] = { 0u, 1u, 4294967285u, 4294967286u, 4294967290u,
	                              4294967295u };
	for (unsigned i = 0; i < sizeof U / sizeof *U; i++)
		printf("u %u %ld\n", U[i], uns(U[i]));
	for (long i = -1010; i <= -990; i++) printf("n %ld %ld\n", i, low(i));
	printf("t %ld\n", t);
	return (int) (t & 0x3f);
}
