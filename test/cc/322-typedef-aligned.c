/* a typedef's trailing aligned(N) is its declarations' ask, as gcc and clang lay it: a member
 * after it moves up (linux's call_single_data_t in struct rq), the struct grows, a global and a
 * static sit on N. the size stays the type's own. exit-code only (55) */
struct csd { void *a, *b, *c; int d; };
typedef struct csd csd_t __attribute__((aligned(sizeof(struct csd))));
typedef int i16 __attribute__((__aligned__(16)));
typedef i16 *pi16;

struct rq { long a; int b; csd_t c; int d; };
struct t { int a; i16 b; char c; };
struct u { char a; pi16 p; };

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
	bad |= addr(&gx) % sizeof(struct csd) || addr(&gy) % sizeof(struct csd) || addr(&sx) % sizeof(struct csd);
	return bad || !c || gpad ? 1 : 55;
}
