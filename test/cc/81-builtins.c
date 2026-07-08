/* the gcc builtins ai.c reaches: the overflow trio (op + seto, result through
   the pointer, flag the value), clzll (bsr ^ 63), expect (the value, hint
   dropped), isinf (bits<<1 == inf<<1), inf/nanf constants, trap (= ud2,
   not exercised here), clear_cache (a no-op on coherent x86). */
int main(void)
{
  long t; int s = 0;
  s += __builtin_add_overflow(3L, 4L, &t) ? 100 : 0;  s += (int)t;             /* 7 */
  s += __builtin_mul_overflow(4611686018427387904L, 2L, &t) ? 10 : 0;          /* + 10 = 17 */
  s += __builtin_sub_overflow(5L, 9L, &t) ? 100 : 0;  s += (int)-t;            /* + 4 = 21 */
  s += __builtin_clzll(1ULL) == 63 ? 5 : 0;                                    /* + 5 = 26 */
  s += __builtin_clzll(0x8000000000000000ULL) == 0 ? 5 : 0;                    /* + 5 = 31 */
  s += __builtin_expect(4, 1);                                                 /* + 4 = 35 */
  s += __builtin_isinf(__builtin_inf()) ? 3 : 0;                               /* + 3 = 38 */
  s += __builtin_isinf(1.5) ? 100 : 4;                                         /* + 4 = 42 */
  return s;
}
