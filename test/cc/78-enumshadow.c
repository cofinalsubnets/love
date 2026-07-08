/* block-scoped enum-constant shadowing: a local named after an enum constant
   is a variable for the rest of its block (writable, block-visible), and the
   constant is back at block exit -- ai.c's `enum { N = 13 }` vs lvm_inner's
   local N. */
enum { N = 13 };

static int gete(void) { return N; }          /* the constant, unshadowed */

int main(void)
{
  int N = 1;                                 /* shadows the enum constant */
  N *= 3;                                    /* an lvalue, not (num 13) */
  { int M = N; N = M + N; }                  /* still the local in a nested block */
  return N * 10 + gete() - 31;               /* 60 + 13 - 31 = 42 */
}
