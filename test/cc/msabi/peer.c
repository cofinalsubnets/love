/* gcc's half of the ms_abi check (x64, freestanding): ms definitions mooncc calls, directly and
 * through a returned pointer past four and six words, and ms calls into mooncc's half */
#define MS __attribute__((ms_abi))
long MS peer6(long a, long b, long c, long d, long e, long f)
{ return a + 2 * b + 3 * c + 4 * d + 5 * e + 6 * f; }
static long MS peer8(long a, long b, long c, long d, long e, long f, long g, long h)
{ return a + 2 * b + 3 * c + 4 * d + 5 * e + 6 * f + 7 * g + 8 * h; }
typedef long (MS *ms8)(long, long, long, long, long, long, long, long);
ms8 peer_get8(void) { return peer8; }
extern long MS host6(long, long, long, long, long, long);
extern unsigned MS host1(unsigned);
/* rsi, rdi and xmm6 hold live values across the ms calls; an ms callee keeps them */
long peer_calls(void)
{
	long r = 0, i;
	for (i = 0; i < 3; i++) {
		volatile double x = 1.5 * (double)i;
		r += host6(i, 2, 3, 4, 5, 6) + host1((unsigned)i);
		r += (long)(x * 2.0);
	}
	return r;
}
