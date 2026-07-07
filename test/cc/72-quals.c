/* stage 7c-i: ignorable qualifiers/attributes + freestanding header parsing.
   including signal/setjmp exercises fn-pointer struct members and array
   typedefs; the arithmetic stays in cc's signed model (values < 128). */
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include <signal.h>
#include <setjmp.h>
#include <sys/mman.h>

struct pt { int x; char c; long z; };

static const int base = 10;

__attribute__((unused)) static int helper(int const a, volatile int b, int * restrict p) {
  register int s = a + b + *p;
  return s;
}

int main(void) {
  int32_t a = 3;
  uint8_t b = 7;
  size_t off = offsetof(struct pt, z);          /* 8 */
  bool ok = true;                               /* 1 */
  int q = 5;
  int r = helper(a, b, &q);                     /* 15 */
  int prot = PROT_READ | PROT_WRITE;            /* 3 */
  int flags = MAP_PRIVATE | MAP_ANONYMOUS;      /* 34 */
  volatile int guard = flags - 34;              /* 0 */
  return base + (int) off + r + prot + ok + guard;  /* 37 */
}
