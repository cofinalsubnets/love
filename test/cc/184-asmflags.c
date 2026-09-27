/* a flag output, held to gcc: `"=@ccc"` beside a bit test (variable_test_bit), `"=@ccz"` out
 * of a lock cmpxchg (try_cmpxchg), and a few conditions over one compare. the flags are read
 * right after the body, before anything moves them. a target with no template here computes
 * the same. */

#include <stdbool.h>

#if defined(__x86_64__)
register unsigned long current_stack_pointer asm("rsp");   /* the kernel's call constraint: the asm uses the stack */
static long sq(long x) { return x * x; }
#endif

static bool test_bit(long nr, const unsigned long *addr) {
#if defined(__x86_64__)
  bool old;
  asm volatile("btq %2, %1" : "=@ccc"(old) : "m"(*addr), "Ir"(nr) : "memory");
  return old;
#else
  return (*addr >> nr) & 1;
#endif
}

static bool try_cas(long *p, long *old, long new) {
#if defined(__x86_64__)
  bool ok;
  long o = *old;
  asm volatile("lock cmpxchgq %[new], %[ptr]"
               : "=@ccz"(ok), [ptr] "+m"(*p), "+a"(o)
               : [new] "r"(new)
               : "memory");
  if (!ok) *old = o;
  return ok;
#else
  if (*p == *old) { *p = new; return 1; }
  *old = *p;
  return 0;
#endif
}

int main(void) {
  int bad = 0;
  unsigned long w = 0x12;
  if (!test_bit(1, &w) || test_bit(0, &w) || !test_bit(4, &w)) bad |= 1;
  long v = 5, o = 5;
  if (!try_cas(&v, &o, 9) || v != 9) bad |= 2;
  o = 5;
  if (try_cas(&v, &o, 7) || o != 9 || v != 9) bad |= 4;
#if defined(__x86_64__)
  int lt, ge, a, s;
  long x = -3, y = 2;
  asm("cmpq %5, %4" : "=@ccl"(lt), "=@ccge"(ge), "=@cca"(a), "=@ccs"(s) : "r"(x), "r"(y));
  if (lt != 1 || ge != 0 || a != 1 || s != 1) bad |= 8;
  unsigned long sp0 = current_stack_pointer;
  asm volatile("" : "+r"(current_stack_pointer));
  if (current_stack_pointer != sp0 || sq(7) != 49) bad |= 16;
#endif
  return bad;
}
