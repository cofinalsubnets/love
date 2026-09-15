/* IEEE compares are NaN-honest: every relation with an unordered operand is
   FALSE except !=, which is TRUE; !NaN is false (NaN is truthy). the naive
   setcc after ucomisd reads CF/ZF, which UNORDERED sets -- < and <= compare
   swapped onto above/ae, == and != carry the parity bit. */
static double zero = 0.0;
int main(void) {
  double n = zero / zero;      /* NaN */
  double one = 1.0;
  int x = 0;
  if (n < n)   x += 100;   /* all false */
  if (n <= n)  x += 100;
  if (n > n)   x += 100;
  if (n >= n)  x += 100;
  if (n == n)  x += 100;
  if (n < one) x += 100;
  if (one < n) x += 100;
  if (!n)      x += 100;
  if (n != n)  x += 20;    /* the true ones */
  if (n)       x += 10;
  if (one < 2.0) x += 5;   /* ordered still works */
  if (one == 1.0) x += 4;
  if (2.0 <= one) x += 100;
  return x + 3;            /* 42 */
}
