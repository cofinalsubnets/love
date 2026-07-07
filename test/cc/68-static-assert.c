/* _Static_assert at file scope and in a block; sizeof folds at parse */
#include <stdarg.h>
struct Pair { int a; int b; };
_Static_assert(sizeof(int) == 4, "int width");
_Static_assert(sizeof(struct Pair) == 8, "pair size");
_Static_assert(1 + 2 * 3 == 7, "precedence folds");
int main() {
  _Static_assert(sizeof(long) == sizeof(double), "both eight");
  int x = 6;
  return x * 7;    /* 42 */
}
