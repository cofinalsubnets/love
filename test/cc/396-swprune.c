// a switch on a constant ends at its case's way out, braces or none: a later case's asm, written
// for another width, is never assembled (the kernel's cmpxchg by sizeof)
static int by_size(int *v, int n) {
  int r = 0;
  switch (sizeof(*v)) {
  case 4: { r = *v + n; break; }
#if defined(__x86_64__)
  case 8: { asm volatile("addq %[n], %[r]" : [r] "+r"(r) : [n] "r"(n)); break; }
  case 1: { asm volatile("addb %[n], %[r]" : [r] "+q"(r) : [n] "q"(n)); break; }
#endif
  default: r = -1;
  }
  return r;
}
int main(void) { int v = 40; return by_size(&v, 2); }
