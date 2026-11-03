/* mooncc's half of the ms_abi check: answers 0 when every call agrees with gcc's half */
#define MS __attribute__((ms_abi))
long MS peer6(long, long, long, long, long, long);
typedef long (MS *ms8)(long, long, long, long, long, long, long, long);
ms8 peer_get8(void);
long peer_calls(void);
long MS host6(long a, long b, long c, long d, long e, long f)
{ return a - b + c - d + e - f; }
unsigned MS host1(unsigned x) { return x * 10u; }
/* an ms member reached through a conditional or a comma, in tail position: efi_bs_call's shape */
struct tab { long hdr; long (MS *fn)(long, long, long, long, long, long); };
__attribute__((noinline)) long viacond(struct tab *a, struct tab *b, int c) { return (c ? a : b)->fn(1, 2, 3, 4, 5, 6); }
__attribute__((noinline)) long viacomma(struct tab *a, int c) { return (c++, a)->fn(6, 5, 4, 3, 2, 1); }
int main(void)
{
	long (MS *volatile p)(long, long, long, long, long, long) = peer6;
	int bad = 0;
	bad |= (peer6(1, 2, 3, 4, 5, 6) != 91) << 0;
	bad |= (p(6, 5, 4, 3, 2, 1) != 56) << 1;
	bad |= (peer_get8()(1, 2, 3, 4, 5, 6, 7, 8) != 204) << 2;
	bad |= (peer_calls() != 30) << 3;
	struct tab t = { 0, peer6 };
	bad |= (viacond(&t, 0, 1) != 91 || viacond(0, &t, 0) != 91) << 4;
	bad |= (viacomma(&t, 0) != 56) << 5;
	return bad;
}
