/* mooncc -t a64: -mstrict-align -mbranch-protection=pac-ret+bti */
/* packed members read, written, stepped and copied by their chunks under -mstrict-align;
   indirect calls, a table jump and an indirect tail call landing under bti and pac-ret */
#include <stdio.h>
#include <string.h>

struct __attribute__((packed)) pk { char c; int i; long l; short s; unsigned u; double d; float f; };
struct in { int a; short b; };
struct __attribute__((packed)) outer { char pad; struct in in; unsigned char t; };
struct __attribute__((packed)) small { char c; int i; char d; };   /* 6 bytes, one register */
struct __attribute__((packed)) pair { char c; long a; short b; };  /* 11 bytes, two */
struct __attribute__((packed)) big { char c; long a[3]; };         /* 25 bytes, memory class */

static char arena[256];

__attribute__((noinline)) static long sum(struct pk *p) { return p->c + p->i + p->l + p->s + p->u + (long)p->d + (long)p->f; }
__attribute__((noinline)) static int rdin(struct outer *o) { return o->in.a + o->in.b + o->t; }
__attribute__((noinline)) static struct small mk(int v) { struct small s = { 1, v, 2 }; return s; }
__attribute__((noinline)) static int usesm(struct small s) { return s.c + s.i + s.d; }
__attribute__((noinline)) static long usepr(struct pair p) { return p.c + p.a + p.b; }
__attribute__((noinline)) static struct pair mkpr(long a) { struct pair p = { 3, a, -4 }; return p; }
__attribute__((noinline)) static long usebig(struct big b) { return b.c + b.a[0] + b.a[1] + b.a[2]; }

static int add1(int x) { return x + 1; }
static int dbl(int x) { return x * 2; }
static int neg(int x) { return -x; }
__attribute__((noinline)) static int via(int (*f)(int), int x) { return f(x + 3); }   /* an indirect tail call */
__attribute__((noinline)) static int table(int k, int x) {
    switch (k) {
    case 0: return x + 11; case 1: return x * 7; case 2: return x - 5; case 3: return x ^ 9;
    case 4: return x << 2; case 5: return x / 3; case 6: return x % 5; default: return -1;
    }
}

int main(void) {
    struct pk *p = (struct pk *)(arena + 1);           /* odd: every member misaligned */
    p->c = 5; p->i = 0x12345678; p->l = -0x123456789aL; p->s = -300; p->u = 4000000000u;
    p->d = 2.5; p->f = -1.25f;
    printf("read %ld %d %ld %d %u\n", sum(p), p->i, p->l, p->s, p->u);
    p->i++; p->l--; ++p->s; p->u += 7; p->i *= 3; p->l ^= 0xff; p->s <<= 1; p->d *= 4; p->f += 0.5f;
    printf("step %d %ld %d %u %g %g\n", p->i, p->l, p->s, p->u, p->d, (double)p->f);

    struct outer *o = (struct outer *)(arena + 64 + 3);
    o->in.a = 77; o->in.b = -9; o->t = 200;
    struct in cp = o->in;                               /* a struct copy out of a packed home */
    o->in.a += cp.b;
    printf("nest %d %d %d\n", rdin(o), cp.a, cp.b);

    struct pk local = { 1, 2, 3, 4, 5, 6.0, 7.0f };     /* a packed local, filled member by member */
    struct pk *q = (struct pk *)(arena + 128 + 5);
    *q = local;
    q->i -= 2;
    memcpy(arena + 200 + 1, &q->l, 8);
    long back; memcpy(&back, arena + 200 + 1, 8);
    memset(arena + 220 + 3, 0x5a, 13);
    printf("copy %ld %ld %d %d\n", sum(q), back, arena[223], arena[235]);

    struct small s = mk(40);
    struct pair pr = mkpr(1000000007L);
    struct big b = { 9, { 10, 20, 30 } };
    printf("args %d %ld %ld %d %ld\n", usesm(s), usepr(pr), usebig(b), s.i, pr.a);

    int (*fs[3])(int) = { add1, dbl, neg };
    int t = 0;
    for (int k = 0; k < 3; k++) t += via(fs[k], k);
    for (int k = 0; k < 8; k++) t += table(k, 100 + k);
    printf("land %d\n", t);
    return 0;
}
