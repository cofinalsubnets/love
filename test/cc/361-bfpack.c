// bit-fields under #pragma pack run on from the cursor at every N, a packed one may touch nine
// bytes, and an unnamed one asks the struct no alignment off AAPCS
#include <stdio.h>
#include <string.h>

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

static void dump(const char *s, const void *p, int n) {
  const unsigned char *b = p;
  printf("%s %d", s, n);
  for (int i = 0; i < n; i++) printf(" %02x", b[i]);
  puts("");
}

int main(void) {
#define SZ(T) printf(#T " %d %d\n", (int) sizeof(T), (int) _Alignof(T))
  SZ(struct a1); SZ(struct i1); SZ(struct c2); SZ(struct a8); SZ(struct j8);
  SZ(struct a16); SZ(union u16); SZ(struct n1); SZ(struct n2); SZ(struct n3);
  SZ(struct ua); SZ(struct ub); SZ(struct ug); SZ(union uk); SZ(union ul);
  SZ(union um); SZ(union un); SZ(struct ud); SZ(struct ue);
  dump("sn1", &sn1, sizeof sn1); dump("sn2", &sn2, sizeof sn2);
  dump("sa1", &sa1, sizeof sa1); dump("sa8", &sa8, sizeof sa8);

  volatile struct n1 a; memset((void *) &a, 0, sizeof a);
  a.c = 5; a.v = 0x8123456789abcdefULL; a.e = 17;
  dump("a", (void *) &a, sizeof a);
  printf("%u %llx %u\n", (unsigned) a.c, (unsigned long long) a.v, (unsigned) a.e);
  a.v += 0x100000000000ULL; a.v++;
  printf("%llx\n", (unsigned long long) a.v);
  printf("%llx\n", (unsigned long long) (a.v = 0xfedcba9876543210ULL));
  printf("%u %u\n", (unsigned) a.c, (unsigned) a.e);

  struct n2 b; memset(&b, 0xff, sizeof b);
  b.v = -3; dump("b", &b, sizeof b); printf("%lld %d\n", (long long) b.v, (int) b.e);
  b.v = 0x123456789abcdLL; b.c = 0; b.e = 0; dump("b", &b, sizeof b);
  long long r = (b.v = 1LL << 58);       // past the width: the value truncated, its top bit the sign
  printf("%lld %lld\n", r, (long long) b.v);
  b.v = sn2.v - 1; printf("%lld\n", (long long) b.v);

  struct n3 c; memset(&c, 0, sizeof c);
  c.v = -1; dump("c", &c, sizeof c); printf("%lld\n", (long long) c.v);
  c.c = 1; c.e = 0x7f; c.v = 2; dump("c", &c, sizeof c);
  long long q = c.v * 3 + 1; printf("%lld\n", q);

  struct i1 d; memset(&d, 0, sizeof d);
  d.a = 3; d.b = 0x7edcba9876543210LL; d.d = 9; dump("d", &d, sizeof d);
  printf("%d %llx %d\n", (int) d.a, (unsigned long long) d.b, (int) d.d);

  struct c2 e; memset(&e, 0, sizeof e);
  e.a = -1; e.b = 0x1abcdef0; e.s = -2; dump("e", &e, sizeof e);
  printf("%d %x %d\n", (int) e.a, (int) e.b, (int) e.s);

  struct j8 f; memset(&f, 0, sizeof f);
  f.c = 1; f.s = -5; f.x = 0xabcde; f.y = -0x123456789LL; dump("f", &f, sizeof f);
  printf("%d %d %x %lld\n", (int) f.c, (int) f.s, (int) f.x, (long long) f.y);

  union u16 u; memset(&u, 0, sizeof u); u.y = -2; dump("u", &u, sizeof u); printf("%d\n", (int) u.x);
  return 0;
}
