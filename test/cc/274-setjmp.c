/* a volatile local changed between setjmp and longjmp keeps its new value (C11 7.13.2.1),
 * through setjmp and sigsetjmp, with a jump from the same function and from a callee.
 * every check adds 1; the exit code is the count that passed. */
#include <setjmp.h>

static jmp_buf jb;
static sigjmp_buf sjb;

static void bounce(int v) { longjmp(jb, v); }
static void sbounce(int v) { siglongjmp(sjb, v); }

static int here(void) {
  volatile int hops = 0;
  if (setjmp(jb) == 0) { hops++; longjmp(jb, 1); }
  return hops == 1;
}

static int callee(void) {
  volatile int n = 10;
  volatile unsigned long acc = 0;
  int r = setjmp(jb);
  acc += (unsigned long)r;
  if (r < 3) { n++; bounce(r + 1); }
  return n == 13 && acc == 6;
}

static int sig(void) {
  volatile int hops = 0;
  volatile long big = 1;
  if (sigsetjmp(sjb, 1) == 0) { hops = 7; big <<= 40; sbounce(2); }
  return hops == 7 && big == 1L << 40;
}

/* many live names around the call: more than the registers that survive it */
static int crowd(int k) {
  volatile int a = k, b = k + 1, c = k + 2, d = k + 3, e = k + 4, f = k + 5, g = k + 6;
  if (setjmp(jb) == 0) { a += 10; b += 10; c += 10; d += 10; e += 10; f += 10; g += 10; bounce(1); }
  return a + b + c + d + e + f + g == 7 * k + 21 + 70;
}

int main(void) {
  return here() + callee() + sig() + crowd(5);
}
