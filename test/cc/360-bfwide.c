/* bit-fields over long long: below a word, past it, across the words of the unit, the whole unit, and
   packed ones whose bytes run past a word. a value is cast to long long before any arithmetic, where gcc
   and clang part. no libc */
typedef unsigned long long u64;
typedef long long s64;

struct a { s64 x:40; s64 y:24; };
struct b { u64 x:33; u64 y:31; int z; };
struct c { char c; s64 x:48; };
struct d { u64 lo:3; u64 mid:32; u64 hi:29; };
struct e { u64 whole:64; s64 sw:64; };
struct f { s64 s3:3; u64 u5:5; s64 s30:30; };
struct p { unsigned char c; s64 x:40; u64 y:7; unsigned u:32; int i:30; } __attribute__((packed));
union u { u64 w; struct { u64 a:20; u64 b:44; } s; };

struct a ga = { -5, 100 };
struct d gd = { 5, 0xdeadbeefULL, 0x1abcdefULL };
struct p gp = { 9, -2, 100, 0xfedcba98u, -7 };

static s64 geta(struct a *p) { return (s64)p->x + (s64)p->y; }
static struct a seta(s64 x, s64 y) { struct a r; r.x = x; r.y = y; return r; }

int main(void)
{
	struct a a = { 1, 2 };
	struct b b = { 0, 0, 7 };
	struct c c = { 1, -9 };
	struct d d;
	struct e e;
	struct f f = { -1, 31, -536870912 };
	struct p p = { 1, 1, 1, 1, 1 };
	union u u;
	s64 r;
	u64 v;

	if (sizeof(struct a) != 8 || sizeof(struct b) != 16 && sizeof(struct b) != 12) return 1;
	if ((s64)ga.x != -5 || (s64)ga.y != 100) return 2;
	if ((u64)gd.lo != 5 || (u64)gd.mid != 0xdeadbeefULL || (u64)gd.hi != 0x1abcdefULL) return 3;
	if (gp.c != 9 || (s64)gp.x != -2 || (u64)gp.y != 100 || gp.u != 0xfedcba98u || gp.i != -7) return 4;

	a.x = -5; a.y += 3;
	if ((s64)a.x != -5 || (s64)a.y != 5 || geta(&a) != 0) return 5;
	a.x = 0x7fffffffffLL; if ((s64)a.x != 0x7fffffffffLL || (s64)a.y != 5) return 6;
	a.y = -1; if ((s64)a.x != 0x7fffffffffLL || (s64)a.y != -1) return 7;
	a.x = 0x8000000000LL; if ((s64)a.x != -0x8000000000LL) return 8;

	b.x = 0x1ffffffffULL; v = b.x; if (v >> 3 != 0x3fffffffULL || b.z != 7 || (u64)b.y != 0) return 9;
	b.y = 0x7fffffffULL; if ((u64)b.x != 0x1ffffffffULL || (u64)b.y != 0x7fffffffULL || b.z != 7) return 10;

	r = c.x++; if (r != -9 || (s64)c.x != -8 || c.c != 1) return 11;
	r = (c.x = 0x7fffffffffffLL); if (r != 0x7fffffffffffLL) return 12;
	c.x = 0xffffffffffffffLL; if ((s64)c.x != -1) return 13;
	r = (c.x = 0x800000000000LL); if (r != -0x800000000000LL) return 14;

	d.lo = 7; d.mid = 0; d.hi = 0;
	d.mid = 0xffffffffULL; if ((u64)d.lo != 7 || (u64)d.mid != 0xffffffffULL || (u64)d.hi != 0) return 15;
	d.mid = 0x12345678ULL; d.hi = 0x1fffffffULL; if ((u64)d.mid != 0x12345678ULL || (u64)d.hi != 0x1fffffffULL) return 16;
	d.lo = 0; if ((u64)d.mid != 0x12345678ULL) return 17;

	e.whole = 0x0123456789abcdefULL; e.sw = -2;
	if (e.whole != 0x0123456789abcdefULL || e.sw != -2) return 18;
	e.whole += 1; e.sw *= 3; if (e.whole != 0x0123456789abcdf0ULL || e.sw != -6) return 19;

	if (f.s3 != -1 || f.u5 != 31 || f.s30 != -536870912) return 20;
	if (f.s3 + 0 >= 0 || f.u5 - 32 >= 0) return 21;
	f.s30 = 5; f.s3 = 3; if (f.s30 != 5 || f.s3 != 3 || f.u5 != 31) return 22;

	p.x = -3; if ((s64)p.x != -3 || p.c != 1 || (u64)p.y != 1 || p.u != 1 || p.i != 1) return 23;
	p.x = 0x7fffffffffLL; if ((s64)p.x != 0x7fffffffffLL || (u64)p.y != 1) return 24;
	p.y = 127; if ((u64)p.y != 127 || (s64)p.x != 0x7fffffffffLL || p.u != 1) return 25;
	p.u = 0xffffffffu; if (p.u != 0xffffffffu || (u64)p.y != 127 || p.i != 1) return 26;
	p.i = -1; if (p.i != -1 || p.u != 0xffffffffu) return 27;
	r = (p.i = 0x20000000); if (r != -536870912) return 28;
	p.u -= 1; if (p.u != 0xfffffffeu) return 29;

	u.w = 0;
	u.s.a = 0xfffff; u.s.b = 0xabcdef012ULL;
	if (u.w != (0xabcdef012ULL << 20 | 0xfffff)) return 30;
	a = seta(-1, 1); if (geta(&a) != 0) return 31;
	return 0;
}
