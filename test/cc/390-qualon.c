/* qualifiers on the type: past a star, through typeof, on a member's own object and its base's,
 * through a pointer to an array, met by ?:, and a volatile local whose every store happens.
 * 0 is agreement */
#include <setjmp.h>

struct M { volatile int v; const char *s; int w; };
typedef int *const icp;                      /* a const pointer typedef: its mask is the object's */

static jmp_buf jb;
__attribute__((noinline)) static void out(int x) { if (x == 3) longjmp(jb, 1); }

static int vstore(void) {
  volatile int n = 1;
  if (setjmp(jb)) return n;
  n = 2;
  out(3);
  return 0;
}

int main(void) {
  char *const *pc = 0;                       /* a pointer to a const pointer */
  char **pp = 0;
  const int c = 1;
  struct M m = { 0, 0, 0 };
  const struct M cm = { 0, 0, 0 };
  const int ca[3] = { 1, 2, 3 };
  const int (*pa)[3] = &ca;
  const char *k = "k";
  char *p = 0;
  int sel = 1;
  icp ip = 0;
  __typeof__(c) tc = 2;
  __typeof__(ip) tip = 0;

  if (_Generic(pc, char *const *: 1, char **: 2, default: 9) != 1) return 1;
  if (_Generic(pp, char *const *: 1, char **: 2, default: 9) != 2) return 2;
  if (_Generic(*pc, char *: 1, const char *: 2, default: 9) != 1) return 3;
  if (_Generic(&pc, char *const **: 1, char ***: 2, default: 9) != 1) return 4;

  /* typeof keeps its operand's mask */
  if (_Generic(&tc, const int *: 1, int *: 2, default: 9) != 1) return 5;
  if (_Generic(&tip, int *const *: 1, int **: 2, default: 9) != 1) return 6;

  /* a member's own, and the base object's over it */
  if (_Generic(&m.v, volatile int *: 1, int *: 2, default: 9) != 1) return 7;
  if (_Generic(&m.w, int *: 1, const int *: 2, default: 9) != 1) return 8;
  if (_Generic(&cm.w, const int *: 1, int *: 2, default: 9) != 1) return 9;
  if (_Generic(&cm.v, const volatile int *: 1, volatile int *: 2, default: 9) != 1) return 10;
  if (_Generic(cm.s, const char *: 1, char *: 2, default: 9) != 1) return 11;

  /* an array of const: its decay, an element's address, and through a pointer to it */
  if (_Generic(ca + 1, const int *: 1, int *: 2, default: 9) != 1) return 12;
  if (_Generic(&ca[1], const int *: 1, int *: 2, default: 9) != 1) return 13;
  if (_Generic(*pa, const int *: 1, int *: 2, default: 9) != 1) return 14;
  if (_Generic(&(*pa)[2], const int *: 1, int *: 2, default: 9) != 1) return 15;

  /* ?: meets two pointers with both pointees' masks */
  if (_Generic(sel ? k : p, const char *: 1, char *: 2, default: 9) != 1) return 16;
  if (_Generic(sel ? (void *)p : k, const void *: 1, void *: 2, default: 9) != 1) return 17;

  /* the store before longjmp is a volatile object's, so it is kept */
  if (vstore() != 2) return 18;
  return (ca[2] + (*pa)[0] + tc) - 6;
}
