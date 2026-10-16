/* struct labels (-std=moon): a `name:` among members is a zero-size char array at
 * that offset, aligned as the member it precedes (a trailing one as the struct).
 * guarded on __moon__, the dialect; gcc compiles the label-free twin. */
#include <stddef.h>

struct Plain { char a; long b; int c; };
/* the idiom a label replaces -- a GCC/Clang zero-length array marker. BOTH compilers
 * build this half, so gcc is the oracle for what it does: alignment 1, so it lands where
 * `a` ended and names the PADDING, not the member. */
struct Zla { char a; char mark[0]; long b; };

#ifdef __moon__
struct S { char a; hdr: long b; int c; tail: };
union  U { top: int x; long y; };

static int labels(void) {
  struct S s;
  /* the address, with no & -- and it is the member's own */
  if ((void *) s.hdr != (void *) &s.b) return 1;
  /* aligned as the member it precedes, NOT where the previous field ended */
  if (offsetof(struct S, hdr) != offsetof(struct S, b)) return 2;
  if (offsetof(struct S, hdr) == offsetof(struct S, a) + (int) sizeof(char)) return 3;
  /* a trailing label is one past the OBJECT */
  if (offsetof(struct S, tail) != sizeof(struct S)) return 4;
  if ((void *) s.tail != (void *) ((char *) &s + sizeof s)) return 5;
  /* it holds nothing and costs nothing */
  if (sizeof(s.hdr) != 0) return 6;
  if (sizeof(struct S) != sizeof(struct Plain)) return 7;
  if (offsetof(struct S, b) != offsetof(struct Plain, b)) return 8;
  if (offsetof(struct S, c) != offsetof(struct Plain, c)) return 9;
  /* a union flattens every offset, labels included */
  { union U u;
    if ((void *) u.top != (void *) &u.x) return 10;
    if (offsetof(union U, top) != 0) return 11; }
  /* THE CLAIM IN THE HEADER, CHECKED: a label names the member the marker cannot reach */
  if (offsetof(struct S, hdr) == offsetof(struct Zla, mark)) return 14;
  if (offsetof(struct S, hdr) != offsetof(struct Zla, b)) return 15;
  /* and it is a position you can walk from */
  { struct S v; v.b = 0x2a;
    if (*(long *) v.hdr != 0x2a) return 12;                /* the address reads the member */
    *(long *) v.hdr = 0x99;
    if (v.b != 0x99) return 13; }                          /* ..and writes it */
  return 0;
}
#else
static int labels(void) { return 0; }   /* not our dialect: nothing to check */
#endif

int main(void) {
  /* the label-free twin is what gcc measures, and both compilers run these */
  if (sizeof(struct Plain) != 24) return 20;
  if (offsetof(struct Plain, b) != 8) return 21;
  /* the marker's behaviour, held by gcc too: it sits in the padding, one past `a` */
  if (offsetof(struct Zla, mark) != 1) return 22;
  if (offsetof(struct Zla, b) != 8) return 23;
  if (offsetof(struct Zla, mark) == offsetof(struct Zla, b)) return 24;
  return labels();
}
