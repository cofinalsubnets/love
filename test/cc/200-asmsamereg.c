/* an asm input pinned to the register an output pins is that output's tie ("=a"(n) : "a"(0),
 * "=D"(p) : "D"(p)). x64 asm, c elsewhere. held to gcc. */

static unsigned leaf0(void) {
  unsigned n;
#if defined(__x86_64__)
  __asm__("cpuid" : "=a"(n) : "a"(0) : "ebx", "ecx", "edx");
#else
  n = 13;
#endif
  return n;
}

static unsigned long bump(unsigned long p, unsigned long k) {
#if defined(__x86_64__)
  __asm__("addq %2, %%rdi" : "=D"(p) : "D"(p), "r"(k) : "cc");
#else
  p += k;
#endif
  return p;
}

static void swapadd(unsigned *a, unsigned *c) {
#if defined(__x86_64__)
  unsigned x = *a, y = *c;
  __asm__("addl %%ecx, %%eax\n\tsubl %%eax, %%ecx\n\tnegl %%ecx" : "=a"(x), "=c"(y) : "a"(x), "c"(y) : "cc");
  *a = x, *c = y;
#else
  unsigned t = *a; *a = *c + t; *c = t;
#endif
}

int main(void) {
  int bad = 0;
  if (leaf0() == 0) bad |= 1;
  if (bump(40, 2) != 42 || bump(0, 0) != 0) bad |= 2;
  unsigned a = 3, c = 10;
  swapadd(&a, &c);
  if (a != 13 || c != 3) bad |= 4;
  return bad;
}
