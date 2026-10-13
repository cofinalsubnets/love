/* mooncc's half of the wide-integer ABI check: every call below crosses into the other
 * compiler's code (peer.c), or comes back from it, carrying __int128. a wrong check prints */
#include <stdio.h>

typedef unsigned __int128 u128;
#define W(h, l) (((u128)(h) << 64) | (unsigned long)(l))
#define HI(v) ((long)((v) >> 64))
#define LO(v) ((long)(v))

u128 peer_w(u128 a, long k);
u128 peer_wodd(long k, u128 a);
long peer_whi(long k, u128 a, u128 b);
u128 peer_calls_w(void);
long peer_calls_wsum(void);
u128 host_w(long k, u128 a) { return a + (u128)k * 3; }
long host_wsum(long k, u128 a, u128 b) { return HI(a) * 7 + LO(b) + k; }
#ifdef __aarch64__
long peer_wdeep(long, long, long, long, long, long, long, u128, long);
long peer_wgap(long, long, long, long, long, long, long, long, long, u128, long);
long peer_calls_wdeep(void);
long host_wdeep(long r0, long r1, long r2, long r3, long r4, long r5, long r6, u128 a, long h)
{ return r0 + r6 + HI(a) * 10 + LO(a) + h * 100; }
#endif

static int n_, bad_;
static void ck(long got, long want)
{
	n_++;
	if (got != want) { printf("check %d: got %ld want %ld\n", n_, got, want); bad_++; }
}

int main(void)
{
	u128 a = W(0x123456789, -4L), r = peer_w(a, 2);
	ck(HI(r), 0x12345678a); ck(LO(r), 2);                /* the low word carries into the high */
	r = peer_wodd(5, W(1, 0x8000000000000001UL));
	ck(HI(r), 0x18); ck(LO(r), 0x15);
	ck(peer_whi(9, W(3, 0), W(0, 11)), 21 + 11 + 9);
	r = peer_calls_w();
	ck(HI(r), 1); ck(LO(r), 17);
	ck(peer_calls_wsum(), 28 + 7 + 3);
	r = peer_w(peer_wodd(1, W(0, 2)), 1);                 /* an answer fed straight into the next call */
	ck(HI(r), 0); ck(LO(r), 36);
#ifdef __aarch64__
	ck(peer_wdeep(1, 2, 3, 4, 5, 6, 7, W(8, 9), 10), 1 + 7 + 80 + 9 + 1000);
	ck(peer_wgap(1, 2, 3, 4, 5, 6, 7, 8, 9, W(3, 4), 5), 8 + 90 + 300 + 4000 + 50000);
	ck(peer_calls_wdeep(), 1 + 7 + 80 + 9 + 1000);
#endif
	ck(LO(a), -4);
	printf("abi128: %d checks, %d wrong\n", n_, bad_);
	return bad_;
}
