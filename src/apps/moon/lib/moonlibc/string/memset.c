#include "../impl.h"

#if defined(__x86_64__) || defined(__aarch64__)
/* memcpy's vector stores of the fill, the last 16 laid over what the blocks left */
static void vfill(unsigned char *dp, unsigned long v, size_t n) {
  unsigned char *e = dp + n - 16;
#if defined(__x86_64__)
  __asm__ volatile("movq %3, %%xmm0\n\tpunpcklqdq %%xmm0, %%xmm0\n"
                   "1:\n\tmovdqu %%xmm0, (%0)\n\tmovdqu %%xmm0, 16(%0)\n\tmovdqu %%xmm0, 32(%0)\n\tmovdqu %%xmm0, 48(%0)\n\t"
                   "add $64, %0\n\tsub $64, %1\n\tcmp $64, %1\n\tjae 1b\n\t"
                   "cmp $16, %1\n\tjb 3f\n"
                   "2:\n\tmovdqu %%xmm0, (%0)\n\tadd $16, %0\n\tsub $16, %1\n\tcmp $16, %1\n\tjae 2b\n"
                   "3:\n\tmovdqu %%xmm0, (%2)"
                   : "+r"(dp), "+r"(n) : "r"(e), "r"(v) : "xmm0", "cc", "memory");
#else
  __asm__ volatile("dup v0.16b, %w3\n"
                   "1:\n\tstp q0, q0, [%0]\n\tstp q0, q0, [%0, #32]\n\t"
                   "add %0, %0, #64\n\tsub %1, %1, #64\n\tcmp %1, #64\n\tb.hs 1b\n\t"
                   "cmp %1, #16\n\tb.lo 3f\n"
                   "2:\n\tstr q0, [%0], #16\n\tsub %1, %1, #16\n\tcmp %1, #16\n\tb.hs 2b\n"
                   "3:\n\tstr q0, [%2]"
                   : "+r"(dp), "+r"(n) : "r"(e), "r"(v) : "v0", "cc", "memory");
#endif
}
#endif

/* the fill and stride ride sizeof(long): a literal shift by 32 is undefined on 32-bit targets */
void *memset(void *d, int c, size_t n) {
  unsigned char *dp = d;
  unsigned char b = (unsigned char) c;
  unsigned long v = b;
  for (size_t k = 8; k < sizeof(unsigned long) * 8; k <<= 1) v |= v << k;
#if defined(__x86_64__) || defined(__aarch64__)
  if (n >= 64) { vfill(dp, v, n); return d; }
#endif
  while (n && ((unsigned long) dp & (sizeof(unsigned long) - 1))) { *dp++ = b; n--; }
  {
    unsigned long *dw = (unsigned long *) dp;
    while (n >= 4 * sizeof(unsigned long)) {
      dw[0] = v; dw[1] = v; dw[2] = v; dw[3] = v;
      dw += 4; n -= 4 * sizeof(unsigned long); }
    while (n >= sizeof(unsigned long)) { *dw++ = v; n -= sizeof(unsigned long); }
    dp = (unsigned char *) dw; }
  while (n--) *dp++ = b;
  return d; }
