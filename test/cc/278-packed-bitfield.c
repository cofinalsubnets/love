/* packed bit-fields as gcc lays them: the bits run on from the last member with no unit
 * alignment, the struct aligns 1, and a field reads and writes exactly the bytes it touches --
 * stores, ++, a local's initializer and a static image all reach them. a unit past the
 * register (64-bit targets only here) and, under -mstrict-align, the members a packed struct
 * holds whole: an array indexed, a struct passed and returned, a 128-bit value */
typedef unsigned long long u64;
#define PORT 14250449537902786276ull
#define WHOLE 166614367852332558ull
#define WIDE 11892561160730410217ull
struct __attribute__((packed)) A2 { char c; unsigned x : 12; unsigned y : 9; };
struct __attribute__((packed)) A4 { short s; unsigned x : 20; unsigned short y : 15; };
struct __attribute__((packed)) A5 { char c; unsigned x : 7; int y : 25; int z; };
struct __attribute__((packed)) A7 { char c; int : 0; char d; };
union __attribute__((packed)) U2 { char c; unsigned x : 20; };
struct __attribute__((packed)) S3 { char c; _Bool b : 1; unsigned short h : 9; };
struct __attribute__((packed)) PA { char c; int a[4]; };
struct I { int x; int y; };
struct __attribute__((packed)) PO { char c; struct I in; };

static struct A5 ga5 = {3, 100, -5, 77};

static u64 sum(const void *p, unsigned n) {
    const unsigned char *b = p;
    u64 h = 0;
    for (unsigned i = 0; i < n; i++) h = h * 131 + b[i];
    return h;
}

#define SZ(T) (sizeof(T) * 10 + _Alignof(T))

__attribute__((noinline)) static struct I getin(struct PO *p) { return p->in; }
__attribute__((noinline)) static long long takein(struct I v) { return (long long)v.x * 3 + v.y; }
__attribute__((noinline)) static int idx(struct PA *p, int i) { return p->a[i]; }

static u64 portable(void) {
    u64 h = SZ(struct A2);
    h = h * 7 + SZ(struct A4);
    h = h * 7 + SZ(struct A5);
    h = h * 7 + SZ(struct A7);
    h = h * 7 + SZ(union U2);
    h = h * 7 + SZ(struct S3);
    h = h * 7 + SZ(struct PA);
    struct A2 a2;
    __builtin_memset(&a2, 0, sizeof a2);
    a2.c = 1, a2.x = 0xabc, a2.y = 0x1ff;
    a2.y--;
    h = h * 3 + sum(&a2, sizeof a2) + a2.x + a2.y;
    volatile struct A4 a4;
    __builtin_memset((void *)&a4, 0, sizeof a4);
    a4.x = 0xfffff;
    a4.y = 0x5555;
    a4.s = -1;
    h = h * 3 + sum((void *)&a4, sizeof a4) + a4.x + a4.y;
    struct A5 a5;
    __builtin_memset(&a5, 0, sizeof a5);
    a5.c = ga5.c, a5.x = ga5.x, a5.y = ga5.y, a5.z = ga5.z;
    a5.y -= 1000;
    h = h * 3 + sum(&ga5, sizeof ga5) + sum(&a5, sizeof a5) + (u64)(long long)a5.y + a5.x + (u64)(long long)ga5.y;
    union U2 u;
    __builtin_memset(&u, 0, sizeof u);
    u.x = 0xabcde;
    h = h * 3 + sum(&u, sizeof u) + u.x;
    struct S3 s3;
    __builtin_memset(&s3, 0, sizeof s3);
    s3.c = 1, s3.b = 1, s3.h = 300;
    s3.h++;
    h = h * 3 + sum(&s3, sizeof s3) + s3.h + s3.b;
    struct A7 a7;
    __builtin_memset(&a7, 0, sizeof a7);
    a7.c = 5, a7.d = 6;
    h = h * 3 + sum(&a7, sizeof a7);
    struct PA pa = {9, {10, -20, 30, -40}};
    for (int i = 0; i < 4; i++) pa.a[i] += i;
    h = h * 3 + sum(&pa, sizeof pa) + (u64)(long long)idx(&pa, 3);
    return h;
}


#ifndef __arm__                           /* thumb copies no packed struct member */
static u64 whole(void) {
    u64 h = SZ(struct PO);
    struct PO po = {1, {0x12345678, -7}};
    struct I v = getin(&po);
    po.in.y += 2;
    long long t = takein(po.in);
    h = h * 3 + sum(&po, sizeof po) + (u64)t + (u64)(long long)v.x + (u64)(long long)v.y;
    return h;
}
#else
static u64 whole(void) { return WHOLE; }
#endif

#if __SIZEOF_POINTER__ == 8
struct __attribute__((packed)) A1 { char c; unsigned x : 30; };
struct __attribute__((packed)) A3 { unsigned a : 3; u64 b : 57; char c; };
struct A6 { char c; unsigned x : 30; } __attribute__((packed));
static struct A1 ga1[2] = {{1, 0x2aaaaaaa}, {2, 7}};
static u64 wide(void) {
    u64 h = SZ(struct A1);
    h = h * 7 + SZ(struct A3);
    h = h * 7 + SZ(struct A6);
    struct A1 a1;
    __builtin_memset(&a1, 0, sizeof a1);
    a1.x = 0x2aaaaaaa;
    a1.c = 9;
    h = h * 3 + sum(&a1, sizeof a1) + a1.x;
    struct A3 a3;
    __builtin_memset(&a3, 0, sizeof a3);
    a3.a = 5, a3.b = 0x123456789abcdeull, a3.c = 'q';
    a3.b += 3;
    a3.a++;
    h = h * 3 + sum(&a3, sizeof a3) + a3.b + a3.a;
    h = h * 3 + sum(ga1, sizeof ga1) + ga1[1].x + ga1[0].x;
    return h;
}
#else
static u64 wide(void) { return WIDE; }
#endif

#ifdef __SIZEOF_INT128__
struct __attribute__((packed)) PW { char c; __int128 v; };
__attribute__((noinline)) static __int128 getw(struct PW *p) { return p->v; }
static int i128(void) {
    struct PW w = {1, 0};
    w.v = ((__int128)0x0123456789abcdefll << 64) | 0xfedcba9876543210ull;
    __int128 r = getw(&w) + 1;
    return (u64)r == 0xfedcba9876543211ull && (u64)(r >> 64) == 0x0123456789abcdefull && w.c == 1 ? 0 : 1;
}
#else
static int i128(void) { return 0; }
#endif

int main(void) { return portable() == PORT && whole() == WHOLE && wide() == WIDE && i128() == 0 ? 0 : 1; }
