/* an aligned ask on a struct: after the body (the kernel's struct page, 56 bytes of members
 * that are 64 with its `__aligned__(2 * sizeof(unsigned long))`), before the tag, on a typedef'd
 * anonymous struct, carried into an enclosing struct and an array, and a constant expression
 * as the ask on a variable; and a member's own ask, trailing, `_Alignas`, leading, beside
 * packed, and on the second of two declarators. held to gcc. */

#include <stddef.h>

struct page {
  unsigned long flags;
  union {
    struct { void *a, *b, *c, *d, *e; } pool;
    struct { unsigned long head; } compound;
  } u;
  unsigned int type;
  int refcount;
} __attribute__((__aligned__(2 * sizeof(unsigned long))));

struct t3 { long a; int b; } __attribute__((aligned(32)));
struct __attribute__((aligned(64))) t6 { int a; };
typedef struct { char c; } __attribute__((aligned(8))) t4;
struct t5 { char c; struct t3 in; };
struct t7 { short s; } __attribute__((packed, aligned(4)));

struct m1 { char c; int x __attribute__((aligned(16))); };
struct m2 { char c; _Alignas(8) char d; char e; };
struct m3 { char c; int x __attribute__((aligned(8))); } __attribute__((packed));
struct m4 { char a, b __attribute__((aligned(4))); char c; };
struct m5 { char c; __attribute__((aligned(2 * sizeof(int)))) short s; };

static char g1;
static char gv __attribute__((aligned(4 * sizeof(int))));
static struct t3 arr[3];

_Static_assert(sizeof(struct page) % (2 * sizeof(unsigned long)) == 0, "page rounds to its ask");

static int al(const void *p, unsigned long a) { return (unsigned long)p % a == 0; }

/* locals past the frame's 16: built through an aligned block, an initializer copied in */
static int locals(int k) {
  int bad = 0;
  struct t3 s = {k, k + 1};
  _Alignas(32) char buf[5] = "abcd";
  struct t6 z[2] = {{k}, {k + 2}};
  _Alignas(64) long w = k * 3;
  static char pad0;
  static _Alignas(64) char sbuf[3];
  (void)pad0;
  if (!al(&s, 32) || s.a != k || s.b != k + 1 || sizeof s != 32) bad |= 1;
  if (!al(buf, 32) || buf[3] != 'd' || buf[4] != 0 || sizeof buf != 5) bad |= 2;
  if (!al(z, 64) || !al(&z[1], 64) || z[1].a != k + 2) bad |= 4;
  if (!al(&w, 64) || w != k * 3) bad |= 8;
  if (!al(sbuf, 64)) bad |= 16;
  w += s.a;
  {
    long w = 7;                                      /* shadows: the outer one is untouched */
    if (w != 7) bad |= 32;
  }
  if (w != k * 4) bad |= 64;
  for (int i = 0; i < 3; i++) {
    _Alignas(32) int v[3] = {i, i, i};
    if (!al(v, 32) || v[2] != i) bad |= 128;
  }
  return bad;
}

int main(void) {
  int bad = 0;
  if (locals(5)) bad |= 8192;
  (void)g1;
  if (_Alignof(struct page) != 2 * sizeof(unsigned long)) bad |= 1;
  if (sizeof(struct t3) != 32 || _Alignof(struct t3) != 32) bad |= 2;
  if (sizeof(struct t6) != 64 || _Alignof(struct t6) != 64) bad |= 4;
  if (sizeof(t4) != 8 || _Alignof(t4) != 8) bad |= 8;
  if (offsetof(struct t5, in) != 32 || sizeof(struct t5) != 64) bad |= 16;
  if (sizeof(struct t7) != 4 || _Alignof(struct t7) != 4) bad |= 32;
  if ((unsigned long)&gv % (4 * sizeof(int)) != 0) bad |= 64;
  if ((unsigned long)&arr[1] - (unsigned long)&arr[0] != 32 || (unsigned long)arr % 32 != 0) bad |= 128;
  if (offsetof(struct m1, x) != 16 || sizeof(struct m1) != 32) bad |= 256;
  if (offsetof(struct m2, d) != 8 || sizeof(struct m2) != 16) bad |= 512;
  if (offsetof(struct m3, x) != 8 || sizeof(struct m3) != 16) bad |= 1024;
  if (offsetof(struct m4, b) != 4 || offsetof(struct m4, c) != 5 || sizeof(struct m4) != 8) bad |= 2048;
  if (offsetof(struct m5, s) != 2 * sizeof(int)) bad |= 4096;
  return bad ? 1 + (bad & 127) + (bad >> 8 & 31) + (bad >> 13 & 1) * 64 : 0;
}
