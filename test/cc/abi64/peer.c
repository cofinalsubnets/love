/* the other compiler's half of the a64 ABI check (built by clang, freestanding): AAPCS64's
 * memory-class composites -- past 16 bytes, no HFA -- in and out, deep on the stack, through
 * `...`, plain char, float HFAs (a member an s register), and calls back into mooncc's half */
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
/* narrow integer answers: the caller extends them (AAPCS64 leaves the bits above to it) */
int peer_neg(int x) { return -x; }
short peer_sneg(int x) { return (short) -x; }
unsigned char peer_byte(int x) { return (unsigned char) x; }
_Bool peer_bool(int x) { return x != 0; }
/* float HFAs: one s register a member, never two floats to a d register; short of s registers,
 * the whole of one goes to the stack and the s file closes behind it */
struct f2 { float a, b; };
struct f3 { float a, b, c; };
struct f4 { float a, b, c, d; };
float peer_f2(struct f2 p, float x) { return p.a * 10 + p.b + x * 1000; }
float peer_f34(struct f3 q, struct f4 r) { return q.a + q.b * 10 + q.c * 100 + r.a * 1000 + r.d * 10000; }
struct f3 peer_mk3(float a, float b, float c) { struct f3 s = { c, b, a + 1 }; return s; }
struct f4 peer_mk4(struct f4 r) { struct f4 s = { r.d, r.c, r.b, r.a }; return s; }
/* six s registers taken, so r spills whole and d follows it onto the stack */
double peer_fdeep(struct f3 q, struct f3 q2, struct f4 r, double d) { return q.a + q2.c * 10 + r.a * 100 + r.d * 1000 + d * 10000; }
extern struct f2 host_f2(struct f2 p);
float peer_calls_f2(void) { struct f2 p = { 3, 4 }, o = host_f2(p); return o.a * 10 + o.b; }
extern struct big host_make(long k);
extern int host_char(char a);
extern long host_va(int n, ...);
long peer_calls_back(void) { struct big b = host_make(9); return b.a + b.b + b.c + b.d + b.e; }
int peer_calls_char(void) { return host_char((char) 233); }
long peer_calls_va(void) { struct big x = { 1, 0, 0, 0, 2 }, y = { 3, 0, 0, 0, 4 }; return host_va(2, x, y); }
/* an int composite past the x registers goes to the stack and closes them; the v file stays
 * open, so a later HFA and double still take v registers (AAPCS64 C.13) */
struct s8 { int a, b; };
struct d2 { double a, b; };
long peer_stk(long a0, long a1, long a2, long a3, long a4, long a5, long a6, long a7, struct s8 s, struct d2 d, double e)
{ return a0 + a7 * 10 + s.a * 100 + s.b * 1000 + (long) d.a * 10000 + (long) d.b * 100000 + (long) e * 1000000; }
extern long host_stk(long, long, long, long, long, long, long, long, struct s8, struct d2, double);
extern long host_vstk(long, long, long, long, long, long, long, long, struct s8, ...);
long peer_calls_stk(void) { struct s8 s = { 3, 4 }; struct d2 d = { 5, 6 }; return host_stk(1, 0, 0, 0, 0, 0, 0, 2, s, d, 7.0); }
long peer_calls_vstk(void) { struct s8 s = { 3, 4 }; return host_vstk(1, 0, 0, 0, 0, 0, 0, 2, s, 5L, 6L); }
