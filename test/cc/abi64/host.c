/* mooncc's half of the a64 ABI check: every call below crosses into clang's code (peer.c),
 * or comes back from it, carrying AAPCS64 memory-class composites and plain char (unsigned
 * there). a wrong check prints */
#include <stdarg.h>
#include <stdio.h>

struct big { long a, b, c, d, e; };
struct mid { int x; char s[13]; long y; };
struct big peer_make(long k, struct big in);
long peer_sum(int n, struct big a, struct mid m, struct big b);
struct mid peer_mid(struct mid m);
long peer_deep(long, long, long, long, long, long, long, long, struct big);
long peer_va(int n, ...);
long peer_calls_back(void);
long peer_calls_va(void);
int peer_char(char a, char b);
char peer_retc(int x);
int peer_neg(int x);
short peer_sneg(int x);
unsigned char peer_byte(int x);
_Bool peer_bool(int x);
int peer_calls_char(void);
int host_char(char a) { return a + 1; }

struct big host_make(long k) { struct big b = { k, k + 1, k + 2, k + 3, k + 4 }; return b; }
long host_va(int n, ...)
{
	va_list ap;
	long t = 0;
	va_start(ap, n);
	for (int i = 0; i < n; i++) { struct big b = va_arg(ap, struct big); t += b.a * 10 + b.e; }
	va_end(ap);
	return t;
}

static int n_, bad_;
static void ck(long got, long want)
{
	n_++;
	if (got != want) { printf("check %d: got %ld want %ld\n", n_, got, want); bad_++; }
}

int main(void)
{
	struct big in = { 1, 2, 3, 4, 5 }, o = peer_make(10, in);
	struct mid m = { 7, "abcdefghijkl", 11 }, m2 = peer_mid(m);
	ck(o.a, 11); ck(o.b, 4); ck(o.c, 3); ck(o.d, -6); ck(o.e, 105);
	ck(peer_sum(3, in, m, o), 3 + 1 + 5 + 7 + 0 + 11 + 3);
	ck(m2.x, 8); ck(m2.s[0], 'P'); ck(m2.s[1], 'b'); ck(m2.y, 33);
	ck(m.x, 7); ck(m.s[0], 'a');                      /* the callee had a copy */
	ck(peer_deep(1, 2, 3, 4, 5, 6, 7, 8, in), 1 + 8 + 5);
	ck(peer_va(2, in, o), (1 * 10 + 5) + (11 * 10 + 105));
	ck(peer_calls_back(), 9 + 10 + 11 + 12 + 13);
	ck(peer_calls_va(), (1 * 10 + 2) + (3 * 10 + 4));
	ck(peer_make(1, peer_make(2, in)).a, 4);           /* a return fed straight into the next call */
	ck(peer_char((char) 200, (char) 7), 200 * 1000 + 7);
	ck(peer_retc(0x1f0), 0xf0);
	ck(peer_calls_char(), 234);
	{ volatile int five = 5;
	  long n = peer_neg(five);                          /* a 32-bit neg in w0: extended here */
	  ck(n, -5); ck(peer_neg(five) < 0, 1);
	  ck(peer_sneg(five), -5); ck(peer_byte(0x1ff), 255); ck(peer_bool(7), 1); }
	ck(in.a, 1);
	printf("abi64: %d checks, %d wrong\n", n_, bad_);
	return bad_;
}
