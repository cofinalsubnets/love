/* a typedef's aligned(N) is its alignment, as gcc and clang lay it: a member after it moves up
 * (linux's call_single_data_t in struct rq), the struct grows, a global and a static sit on N.
 * before the name it may lower (linux's compat_u64), a typedef of it inherits, packed still
 * wins, a member's own ask still raises. the size stays the type's own. exit-code only (55) */
struct csd { void *a, *b, *c; int d; };
typedef struct csd csd_t __attribute__((aligned(sizeof(struct csd))));
typedef int i16 __attribute__((__aligned__(16)));
typedef i16 *pi16;
typedef unsigned long long u64;
typedef u64 __attribute__((aligned(4))) c64;
typedef c64 d64;
typedef c64 __attribute__((aligned(16))) e64;

struct rq { long a; int b; csd_t c; int d; };
struct t { int a; i16 b; char c; };
struct u { char a; pi16 p; };
struct cb { char n[44]; c64 x; };
struct k { char c; i16 x; } __attribute__((packed));
struct m { char c; c64 __attribute__((aligned(8))) x; };
struct m2 { char c; d64 x; e64 y; };
struct m4 { char c; c64 x[2], *y; };

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
	bad |= addr(&gx) % sizeof(struct csd) || addr(&gy) % sizeof(struct csd) || addr(&sx) % sizeof(struct csd);
	return bad || !c || gpad ? 1 : 55;
}
