/* two rows the kernel's own headers need: an enumerator that does not fit an int
 * (gcc widens the underlying type rather than refusing), and a _Static_assert
 * standing as a struct member -- which is what `sizeof(struct {_Static_assert(..);})`
 * is, the shape include/linux/const.h builds const_true out of. */
#include <stdio.h>

enum wide {
  W_LOW   = 1,
  W_ABORT = (0xffffffffULL << 32),
  W_SHIFT = 32,
};

enum neg { N_MIN = -3, N_BIG = 3000000000LL };

/* a whole struct body that is one assertion, and one that mixes */
#define TRUE_OR_ZERO(e) ((int) sizeof(struct { _Static_assert((e), #e " is false"); }))
struct mixed {
  int a;
  _Static_assert(sizeof(long) == 8, "lp64");
  int b;
  _Static_assert(1, "again");
};

int main(void)
{
  unsigned long a = W_ABORT;
  enum wide w = W_ABORT;
  struct mixed m = { 1, 2 };
  printf("%lu %d %d %d %d %d %d\n",
         a >> 32, (int) W_SHIFT, (int) (a & 0xffffffff),
         (int) sizeof(struct mixed), m.a + m.b,
         TRUE_OR_ZERO(sizeof(int) == 4), (int) (w == W_ABORT));
  return (int) ((a >> 32) & 0x3f) + (int) sizeof(struct mixed);
}
