/* the kernel's bit scans and counts, held to gcc: fls's `bsrl %1,%0` beside a "0"(-1) tie,
 * __fls's `bsr`, __ffs's `tzcnt`, hweight's `popcntl`/`popcntq`, and cpu_relax's `pause`
 * and mb's `mfence` -- a 32-bit scan reads only the low half, so an int holding a negative
 * value answers 31, never 63. a target with no template here computes the same. */

static int fls(int x) {
#if defined(__x86_64__)
  int r;
  asm("bsrl %1,%0" : "=r"(r) : "rm"(x), "0"(-1));
  return r + 1;
#else
  int r = 0;
  for (unsigned u = (unsigned)x; u; u >>= 1) r++;
  return r;
#endif
}

static unsigned long ffs0(unsigned long w) {
#if defined(__x86_64__)
  asm("tzcnt %1,%0" : "=r"(w) : "rm"(w));
  return w;
#else
  unsigned long n = 0;
  while (!(w & 1)) { w >>= 1; n++; }
  return n;
#endif
}

static unsigned long fls64(unsigned long w) {
#if defined(__x86_64__)
  asm("bsr %1,%0" : "=r"(w) : "rm"(w));
  return w;
#else
  unsigned long n = 0;
  while (w >>= 1) n++;
  return n;
#endif
}

static unsigned hw32(unsigned w) {
#if defined(__x86_64__)
  unsigned r;
  asm("popcntl %1, %0" : "=r"(r) : "r"(w));
  return r;
#else
  unsigned r = 0;
  for (; w; w &= w - 1) r++;
  return r;
#endif
}

static unsigned long hw64(unsigned long w) {
#if defined(__x86_64__)
  unsigned long r;
  asm("popcntq %1, %0" : "=r"(r) : "r"(w));
  return r;
#else
  unsigned long r = 0;
  for (; w; w &= w - 1) r++;
  return r;
#endif
}

int main(void) {
  int bad = 0;
  if (fls(0) != 0 || fls(1) != 1 || fls(0x80) != 8 || fls(-1) != 32) bad |= 1;
  if (ffs0(8) != 3 || fls64(1) != 0) bad |= 2;
  if (hw32(0xF0F0u) != 8 || hw32(0xFFFFFFFFu) != 32 || hw64(0) != 0) bad |= 8;
#if __SIZEOF_LONG__ == 8                          /* a 32-bit long has no bit 40 */
  if (ffs0(1UL << 40) != 40 || fls64(1UL << 63) != 63) bad |= 4;
  if (hw64(0xFFFFFFFFFFFFFFFFUL) != 64) bad |= 16;
#endif
#if defined(__x86_64__)
  asm volatile("pause" ::: "memory");
  asm volatile("mfence" ::: "memory");
#endif
  return bad;
}
