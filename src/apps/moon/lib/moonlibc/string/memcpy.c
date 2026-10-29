#include "../impl.h"

/* x64 and a64 move 64 bytes past 64 in 16-byte vectors, aligned or not, then 16s; the last 16
 * load first and store last over what the blocks left, so a forward overlap (memmove's) holds */
#if defined(__x86_64__) || defined(__aarch64__)
static void vcopy(unsigned char *dp, unsigned char const *sp, size_t n) {
  unsigned char *e = dp + n - 16; unsigned char const *f = sp + n - 16;
#if defined(__x86_64__)
  __asm__ volatile("movdqu (%4), %%xmm4\n"
                   "1:\n\tmovdqu (%1), %%xmm0\n\tmovdqu 16(%1), %%xmm1\n\tmovdqu 32(%1), %%xmm2\n\tmovdqu 48(%1), %%xmm3\n\t"
                   "movdqu %%xmm0, (%0)\n\tmovdqu %%xmm1, 16(%0)\n\tmovdqu %%xmm2, 32(%0)\n\tmovdqu %%xmm3, 48(%0)\n\t"
                   "add $64, %1\n\tadd $64, %0\n\tsub $64, %2\n\tcmp $64, %2\n\tjae 1b\n\t"
                   "cmp $16, %2\n\tjb 3f\n"
                   "2:\n\tmovdqu (%1), %%xmm0\n\tmovdqu %%xmm0, (%0)\n\tadd $16, %1\n\tadd $16, %0\n\tsub $16, %2\n\tcmp $16, %2\n\tjae 2b\n"
                   "3:\n\tmovdqu %%xmm4, (%3)"
                   : "+r"(dp), "+r"(sp), "+r"(n) : "r"(e), "r"(f) : "xmm0", "xmm1", "xmm2", "xmm3", "xmm4", "cc", "memory");
#elif defined(__aarch64__)
  __asm__ volatile("ldr q4, [%4]\n"
                   "1:\n\tldp q0, q1, [%1]\n\tldp q2, q3, [%1, #32]\n\tstp q0, q1, [%0]\n\tstp q2, q3, [%0, #32]\n\t"
                   "add %1, %1, #64\n\tadd %0, %0, #64\n\tsub %2, %2, #64\n\tcmp %2, #64\n\tb.hs 1b\n\t"
                   "cmp %2, #16\n\tb.lo 3f\n"
                   "2:\n\tldr q0, [%1], #16\n\tstr q0, [%0], #16\n\tsub %2, %2, #16\n\tcmp %2, #16\n\tb.hs 2b\n"
                   "3:\n\tstr q4, [%3]"
                   : "+r"(dp), "+r"(sp), "+r"(n) : "r"(e), "r"(f) : "v0", "v1", "v2", "v3", "v4", "cc", "memory");
#endif
}
#endif

/* pointers that agree mod the word (the xor) copy words after a byte head; ones that disagree
 * shift two aligned source words per stored word (little-endian), so no load is unaligned */
void *memcpy(void *d, void const *s, size_t n) {
  unsigned char *dp = d; unsigned char const *sp = s;
#if defined(__x86_64__) || defined(__aarch64__)
  if (n >= 64) { vcopy(dp, sp, n); return d; }
#endif
  if ((((unsigned long) dp ^ (unsigned long) sp) & (sizeof(unsigned long) - 1)) == 0) {
    while (n && ((unsigned long) dp & (sizeof(unsigned long) - 1))) {
      *dp++ = *sp++; n--; }
    unsigned long *dw = (unsigned long *) dp;
    unsigned long const *sw = (unsigned long const *) sp;
    while (n >= 4 * sizeof(unsigned long)) {
      dw[0] = sw[0]; dw[1] = sw[1]; dw[2] = sw[2]; dw[3] = sw[3];
      dw += 4; sw += 4; n -= 4 * sizeof(unsigned long); }
    while (n >= sizeof(unsigned long)) { *dw++ = *sw++; n -= sizeof(unsigned long); }
    dp = (unsigned char *) dw; sp = (unsigned char const *) sw; }
  else if (n >= 4 * sizeof(unsigned long)) {
    while ((unsigned long) dp & (sizeof(unsigned long) - 1)) { *dp++ = *sp++; n--; }
    unsigned long o = (unsigned long) sp & (sizeof(unsigned long) - 1);
    unsigned l = 8 * (unsigned) o, r = 8 * sizeof(unsigned long) - l;
    unsigned long *dw = (unsigned long *) dp;
    unsigned long const *sw = (unsigned long const *) (sp - o);
    unsigned long w = sw[0];            /* every load is an aligned word holding a byte copied */
    while (n >= 4 * sizeof(unsigned long)) {
      unsigned long a = sw[1], b = sw[2], c = sw[3], e = sw[4];
      dw[0] = w >> l | a << r; dw[1] = a >> l | b << r;
      dw[2] = b >> l | c << r; dw[3] = c >> l | e << r;
      w = e; dw += 4; sw += 4; n -= 4 * sizeof(unsigned long); }
    while (n >= sizeof(unsigned long)) {
      unsigned long a = *++sw;
      *dw++ = w >> l | a << r; w = a; n -= sizeof(unsigned long); }
    dp = (unsigned char *) dw; sp = (unsigned char const *) sw + o; }
  while (n--) *dp++ = *sp++;
  return d; }
