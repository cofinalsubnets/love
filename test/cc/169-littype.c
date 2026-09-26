/* an integer literal's type is its value's and its spelling's (C11 6.4.4.1): on ILP32 a
 * decimal past int is long long, and an L one past long climbs -- hex to unsigned long
 * first. each bit is one reading; main answers them all, held to gcc on every target. */

int main(void) {
  int r = 0;
  r |= (sizeof(2147483648) == 8) << 0;
  r |= (sizeof(0xffffffffL) == 8) << 1;
  r |= (0xffffffffL > -1) << 2;                  /* unsigned long on ILP32, signed long on LP64 */
  r |= (4294967295L == -1) << 3;                 /* never: long long on ILP32 */
  r |= (sizeof(4294967296) == 8) << 4;
  r |= ((2147483648L >> 31) == 1) << 5;
  r |= ((0x100000000 >> 32) == 1) << 6;
  r |= (3000000000 > 0) << 7;
  return r; }
