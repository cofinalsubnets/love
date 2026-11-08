/* a typedef's aligned(N) is its alignment, as gcc and clang lay it: a member after it moves up
 * (linux's call_single_data_t in struct rq), the struct grows, a global and a static sit on N.
 * before the name it may lower (linux's compat_u64), a typedef of it inherits, packed still
 * wins, a member's own ask still raises. the size stays the type's own. _Alignof and _Alignas read
 * it, through an array and not through a pointer, a global's too; a struct's rides its type, through
 * an index, a deref and a member, _Generic matching it as the plain struct. exit-code only (55) */
struct csd { void *a, *b, *c; int d; };
typedef struct csd csd_t __attribute__((aligned(sizeof(struct csd))));
typedef int i16 __attribute__((__aligned__(16)));
typedef i16 *pi16;
typedef unsigned long long u64;
typedef u64 __attribute__((aligned(4))) c64;
typedef c64 d64;
typedef c64 __attribute__((aligned(16))) e64;
typedef struct { char c; } s32 __attribute__((aligned(32)));

struct rq { long a; int b; csd_t c; int d; };
struct t { int a; i16 b; char c; };
struct u { char a; pi16 p; };
struct cb { char n[44]; c64 x; };
struct k { char c; i16 x; } __attribute__((packed));
struct m { char c; c64 __attribute__((aligned(8))) x; };
struct m2 { char c; d64 x; e64 y; };
struct m4 { char c; c64 x[2], *y; };

_Static_assert(_Alignof(i16) == 16 && __alignof__(i16) == 16, "raises");
_Static_assert(_Alignof(c64) == 4 && _Alignof(d64) == 4 && _Alignof(e64) == 16, "lowers, inherits");
_Static_assert(_Alignof(s32) == 32 && _Alignof(csd_t) == sizeof(struct csd), "a struct's");
_Static_assert(_Alignof(csd_t[3]) == sizeof(struct csd) && _Alignof(c64[2][2]) == 4, "an array's");
_Static_assert(_Alignof(i16 *) == _Alignof(void *) && _Alignof(pi16) == _Alignof(void *), "not a pointer's");
_Static_assert(_Alignof(int (*)(i16)) == _Alignof(void *), "not a function's");
_Alignas(i16) char ga;
char gb;
_Alignas(s32) char gc;
i16 gi, *gq, **gr;
pi16 gs;
csd_t gt[2], *gu;
struct v { char c; csd_t b[2]; } *gw;

_Static_assert(__alignof__(gt[1]) == sizeof(struct csd) && __alignof__(*gu) == sizeof(struct csd), "a struct's, indexed and through a pointer");
_Static_assert(__alignof__(gw->b[1]) == sizeof(struct csd) && __alignof__(__typeof__(*gu)) == sizeof(struct csd), "a member's, a typeof's");
_Static_assert(_Generic(gt[0], struct csd: 1, default: 0) && _Generic(gu, struct csd *: 1, default: 0), "the same type");

csd_t gx;
char gpad;
csd_t gy;
static csd_t sx;

__attribute__((noinline)) static unsigned long addr(void *p) { return (unsigned long) p; }

int main(void)
{
	char c = 1;
	int bad = 0;
	bad |= sizeof(csd_t) != sizeof(struct csd);
	bad |= __builtin_offsetof(struct rq, c) != sizeof(struct csd);
	bad |= sizeof(struct rq) != 3 * sizeof(struct csd);
	bad |= __builtin_offsetof(struct t, b) != 16 || sizeof(struct t) != 32 || sizeof(i16) != 4;
	bad |= __builtin_offsetof(struct u, p) != sizeof(void *);
	bad |= __builtin_offsetof(struct cb, x) != 44 || sizeof(struct cb) != 52 || sizeof(c64) != 8;
	bad |= __builtin_offsetof(struct k, x) != 1 || __builtin_offsetof(struct m, x) != 8;
	bad |= __builtin_offsetof(struct m2, x) != 4 || __builtin_offsetof(struct m2, y) != 16;
	bad |= __builtin_offsetof(struct m4, x) != 4 || __builtin_offsetof(struct m4, y) % sizeof(void *);
	bad |= addr(&ga) % 16 || addr(&gc) % 32 || gb;
	bad |= __alignof__(gi) != 16 || __alignof__(gq) != sizeof(void *) || __alignof__(gr) != sizeof(void *) || __alignof__(gs) != sizeof(void *);
	bad |= addr(&gx) % sizeof(struct csd) || addr(&gy) % sizeof(struct csd) || addr(&sx) % sizeof(struct csd);
	return bad || !c || gpad ? 1 : 55;
}
