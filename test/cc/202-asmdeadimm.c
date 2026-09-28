/* an "i" operand only a dead arm lays: the kernel's `__builtin_constant_p(nr) ?
 * constant_test_bit(nr) : variable_test_bit(nr)` inlined with a runtime nr, and an if (0)
 * over an asm -- gcc prunes the arm a folded test cannot take before it reads the operand.
 * and a block static's address as "i", the jump-label key a DO_ONCE lays. a ?: whose arms
 * type apart, and a dead arm a label keeps, still compile. the asm is x64's. held to gcc. */

#if defined(__x86_64__)
static inline __attribute__((__always_inline__)) int cbit(long nr, const unsigned long *w) {
  unsigned char r;
  asm("testb %2,%1\n\tsetnz %0" : "=q"(r) : "m"(((const unsigned char *)w)[nr >> 3]), "i"(1 << (nr & 7)));
  return r;
}
static inline __attribute__((__always_inline__)) int keyjump(void *const k) {
  asm goto("jmp %l[yes]\n\t.pushsection .data.keys, \"aw\"\n\t.balign 8\n\t.quad %c0 - .\n\t.popsection"
           : : "i"(k) : : yes);
  return 0;
yes:
  return 1;
}
#else
static inline int cbit(long nr, const unsigned long *w) { return w[nr / (8 * sizeof(long))] >> (nr % (8 * sizeof(long))) & 1; }
static inline int keyjump(void *const k) { return k != 0; }
#endif
static inline int vbit(long nr, const unsigned long *w) { return w[nr / (8 * sizeof(long))] >> (nr % (8 * sizeof(long))) & 1; }
static inline __attribute__((__always_inline__)) int tbit(unsigned long nr, const unsigned long *w) {
  return __builtin_constant_p(nr) ? cbit(nr, w) : vbit(nr, w);
}

static int test(const unsigned long *w, int bit) {
  if (0) return cbit(bit, w);
  return tbit(bit, w);
}

struct key { int on; long type; };
static int once(void) {
  static struct key k = { 1, 1 };
  return keyjump(&k);
}

/* a folded test reads C's types: -1 < 0u is 0 (unsigned), ~0u & -8 is 4294967288 */
static int signs = (-1 < 0u) ? 1 : 2;
static int signs2(void) {
  int r = 0;
  if (-1 < 0u) r |= 1;
  if ((((long long)-8) & ~0u) != 4294967288LL) r |= 2;
  return r + ((sizeof(int) < -1) ? 4 : 0);
}

static int arms(int x) {
  double d = 0 ? 1.5 : x;
  int n = 1 ? x : 0;
  if (0) { hit: return n + 100; }
  if (x > 5) goto hit;
  return (int)d + n;
}

int main(void) {
  int bad = 0;
  unsigned long w[2] = { 0x14, 1 };
  if (test(w, 2) != 1 || test(w, 3) != 0 || tbit(4, w) != 1 || test(w, 8 * sizeof(long)) != 1) bad |= 1;
  if (once() != 1) bad |= 2;
  if (arms(3) != 6 || arms(7) != 107) bad |= 4;
  if (signs != 2 || signs2() != 4) bad |= 8;
  return bad;
}
