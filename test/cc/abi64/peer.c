/* the other compiler's half of the a64 ABI check (built by clang, freestanding): AAPCS64's
 * memory-class composites -- past 16 bytes, no HFA -- in and out, deep on the stack, through
 * `...`, plain char, and calls back into mooncc's half */
#include <stdarg.h>

struct big { long a, b, c, d, e; };
struct mid { int x; char s[13]; long y; };          /* 32 bytes, int-class, mixed */

struct big peer_make(long k, struct big in) { struct big o = { in.a + k, in.b * 2, in.c, in.d - k, in.e + 100 }; return o; }
long peer_sum(int n, struct big a, struct mid m, struct big b) { return n + a.a + a.e + m.x + m.s[12] + m.y + b.c; }
struct mid peer_mid(struct mid m) { m.x += 1; m.s[0] = 'P'; m.y *= 3; return m; }
long peer_deep(long r0, long r1, long r2, long r3, long r4, long r5, long r6, long r7, struct big s) { return r0 + r7 + s.e; }
long peer_va(int n, ...)
{
	va_list ap;
	long t = 0;
	va_start(ap, n);
	for (int i = 0; i < n; i++) { struct big b = va_arg(ap, struct big); t += b.a * 10 + b.e; }
	va_end(ap);
	return t;
}
/* plain char, unsigned under AAPCS64: a byte past 127 crosses as itself */
int peer_char(char a, char b) { return a * 1000 + b; }
char peer_retc(int x) { return (char) x; }
extern struct big host_make(long k);
extern int host_char(char a);
extern long host_va(int n, ...);
long peer_calls_back(void) { struct big b = host_make(9); return b.a + b.b + b.c + b.d + b.e; }
int peer_calls_char(void) { return host_char((char) 233); }
long peer_calls_va(void) { struct big x = { 1, 0, 0, 0, 2 }, y = { 3, 0, 0, 0, 4 }; return host_va(2, x, y); }
