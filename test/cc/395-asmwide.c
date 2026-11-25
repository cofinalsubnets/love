/* a value wider than a register under "rm": a register where one holds it, memory where
 * none does (i386's long long), read back after the asm either way. */
typedef unsigned long long u64;
static inline unsigned idiv(u64 dividend, unsigned divisor, u64 *rem) {
  unsigned ret = 0;
  while (dividend >= divisor) {
    asm("" : "+rm"(dividend));
    dividend -= divisor;
    ret++;
  }
  *rem = dividend;
  return ret;
}
static u64 bump(u64 v) {
#if defined(__i386__)
  asm("addl $1, %0" : "+rm"(v));        /* memory there: the low word, in place */
#else
  v += 1;
#endif
  return v;
}
int main(void) {
  u64 ns = 7000000123ULL, r;
  unsigned s = idiv(ns, 1000000000u, &r);
  u64 b = bump(0x500000010ULL);
  return (s == 7 && r == 123 && b == 0x500000011ULL) ? 42 : 1;
}
