// bit-fields under #pragma pack run on from the cursor at every N, a packed one may touch nine
// bytes, and an unnamed one asks the struct no alignment off AAPCS
#ifdef SHOW
#include <stdio.h>
#endif
static unsigned long long hash = 14695981039346656037ULL;
static void mix(unsigned long long x) {
#ifdef SHOW
  printf("%llx\n", x);
#endif
  for (int i = 0; i < 8; i++, x >>= 8) hash = (hash ^ (x & 255)) * 1099511628211ULL; }
static int answer(void) { return (int) ((hash ^ hash >> 32) % 251); }
static void zero(void *p, int v, int n) { volatile unsigned char *b = p; for (int i = 0; i < n; i++) b[i] = (unsigned char) v; }

#pragma pack(push, 1)
struct a1 { char c; int x : 30; char d; };
struct i1 { char a : 3; long long b : 64; char d; };
#pragma pack(pop)
#pragma pack(push, 2)
struct c2 { int a : 7; int b : 30; short s; };
#pragma pack(pop)
#pragma pack(push, 8)
struct a8 { char c; int x : 30; };
struct j8 { char c; short s : 12; int x : 21; long long y : 50; };
#pragma pack(pop)
#pragma pack(16)
struct a16 { char c; int x : 30; };
union u16 { char c; int x : 30; long long y : 50; };
#pragma pack()

struct __attribute__((packed)) n1 { unsigned char c : 3; unsigned long long v : 64; unsigned char e : 5; };
struct __attribute__((packed)) n2 { unsigned char c : 7; long long v : 59; signed char e : 6; };
struct __attribute__((packed)) n3 { char pad; unsigned char c : 1; long long v : 64; unsigned char e : 7; };

struct ua { char c; int : 7; };
struct ub { char c; int : 7; char d; };
struct ug { long long : 1; char d; };
union uk { char c; int : 7; };
union ul { long long x : 10; };
union um { char c; long long : 33; };
union un { short x : 3; char a[3]; };
#pragma pack(push, 2)
struct ud { char c; int : 7; };
struct __attribute__((packed)) ue { char c; int x : 7; };
#pragma pack(pop)

struct n1 sn1 = { 5, 0x8123456789abcdefULL, 17 };
struct n2 sn2 = { 99, -0x123456789abcdLL, -7 };
struct a1 sa1 = { 1, -2, 3 };
struct a8 sa8 = { 4, 0x1234567 };

static void dump(const void *p, int n) {
  const volatile unsigned char *b = p;
  mix((unsigned) n);
  for (int i = 0; i < n; i++) mix(b[i]);
}

int main(void) {
#define SZ(T) mix(sizeof(T)), mix(_Alignof(T))
  SZ(struct a1); SZ(struct i1); SZ(struct c2); SZ(struct a8); SZ(struct j8);
  SZ(struct a16); SZ(union u16); SZ(struct n1); SZ(struct n2); SZ(struct n3);
#ifdef __aarch64__
#define IS(T, n, al) if (sizeof(T) != n || _Alignof(T) != al) return 200
  IS(struct ua, 4, 4); IS(struct ub, 4, 4); IS(struct ug, 8, 8); IS(union uk, 4, 4); IS(union ul, 8, 8);
  IS(union um, 8, 8); IS(union un, 4, 2); IS(struct ud, 2, 2); IS(struct ue, 2, 2);
  // a64's gate holds it to x64's answer: those layouts, once this one's are checked
  static const char x64[] = { 2, 1, 3, 1, 2, 1, 1, 1, 8, 8, 5, 1, 4, 2, 2, 1, 2, 2 };
  for (int i = 0; i < (int) sizeof x64; i++) mix(x64[i]);
#else
  SZ(struct ua); SZ(struct ub); SZ(struct ug); SZ(union uk); SZ(union ul);
  SZ(union um); SZ(union un); SZ(struct ud); SZ(struct ue);
#endif
  dump(&sn1, sizeof sn1); dump(&sn2, sizeof sn2);
  dump(&sa1, sizeof sa1); dump(&sa8, sizeof sa8);

  volatile struct n1 a; zero((void *) &a, 0, sizeof a);
  a.c = 5; a.v = 0x8123456789abcdefULL; a.e = 17;
  dump((void *) &a, sizeof a);
  mix(a.c); mix(a.v); mix(a.e);
  a.v += 0x100000000000ULL; a.v++;
  mix(a.v);
  mix(a.v = 0xfedcba9876543210ULL);
  mix(a.c); mix(a.e);

  struct n2 b; zero(&b, 0xff, sizeof b);
  b.v = -3; dump(&b, sizeof b); mix(b.v); mix(b.e);
  b.v = 0x123456789abcdLL; b.c = 0; b.e = 0; dump(&b, sizeof b);
  long long r = (b.v = 1LL << 58);       // past the width: the value truncated, its top bit the sign
  mix(r); mix(b.v);
  b.v = sn2.v - 1; mix(b.v);

  struct n3 c; zero(&c, 0, sizeof c);
  c.v = -1; dump(&c, sizeof c); mix(c.v);
  c.c = 1; c.e = 0x7f; c.v = 2; dump(&c, sizeof c);
  long long q = c.v * 3 + 1; mix(q);

  struct i1 d; zero(&d, 0, sizeof d);
  d.a = 3; d.b = 0x7edcba9876543210LL; d.d = 9; dump(&d, sizeof d);
  mix(d.a); mix(d.b); mix(d.d);

  struct c2 e; zero(&e, 0, sizeof e);
  e.a = -1; e.b = 0x1abcdef0; e.s = -2; dump(&e, sizeof e);
  mix(e.a); mix(e.b); mix(e.s);

  struct j8 f; zero(&f, 0, sizeof f);
  f.c = 1; f.s = -5; f.x = 0xabcde; f.y = -0x123456789LL; dump(&f, sizeof f);
  mix(f.c); mix(f.s); mix(f.x); mix(f.y);

  union u16 u; zero(&u, 0, sizeof u); u.y = -2; dump(&u, sizeof u); mix(u.x);
  return answer();
}
