/* an inlined body whose asm writes its own param (the x86 kernel's variable__ffs): the param
 * is no alias of the caller's variable, which keeps its value. held to gcc. */

static inline __attribute__((always_inline)) unsigned long vffs(unsigned long word) {
#if defined(__x86_64__)
  asm("tzcnt %1,%0" : "=r"(word) : "rm"(word));
#else
  word = __builtin_ctzl(word);
#endif
  return word;
}

__attribute__((noinline)) int walk(unsigned long start, unsigned long end) {
  int n = 0, order;
  while (start < end) {
    order = start ? (vffs(start) < 10 ? vffs(start) : 10) : 10;
    while (start + (1UL << order) > end) order--;
    start += 1UL << order;
    if (++n > 1000) return -1;
  }
  return n;
}

int main(void) {
  int n = walk(3, 100);
  return n;
}
