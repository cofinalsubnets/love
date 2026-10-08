/* the vector rows through an inline template, held to gcc: pshufb (a64 rev32) turns each word's
 * bytes, palignr shifts a register pair, pblendw takes halves by mask, and where the cpu says the
 * sha extensions are there sha256msg1 (a64 sha256su0) lays its schedule step, checked against the
 * same step in C. the asm names its vector clobbers. a target with no template computes the same
 * answers. */

static unsigned rr(unsigned x, int n) { return (x >> n) | (x << (32 - n)); }

static int sha_ext(void) {
#if defined(__x86_64__)
  unsigned a, b, c, d;
  asm("cpuid" : "=a"(a), "=b"(b), "=c"(c), "=d"(d) : "a"(0), "c"(0));
  if (a < 7) return 0;
  asm("cpuid" : "=a"(a), "=b"(b), "=c"(c), "=d"(d) : "a"(7), "c"(0));
  return (int)(b >> 29 & 1);
#elif defined(__aarch64__) && (defined(__moonlibc__) || defined(__ARM_FEATURE_SHA2))
  unsigned long r;
  asm("mrs %0, id_aa64isar0_el1" : "=r"(r));
  return (r >> 12 & 15) != 0;
#else
  return 0;
#endif
}

static void turn(const unsigned char *in, unsigned char *out) {
#if defined(__x86_64__)
  static const unsigned char m[16] = {3, 2, 1, 0, 7, 6, 5, 4, 11, 10, 9, 8, 15, 14, 13, 12};
  asm volatile("movdqu (%0), %%xmm1\n\tmovdqu (%2), %%xmm2\n\tpshufb %%xmm2, %%xmm1\n\tmovdqu %%xmm1, (%1)"
               : : "r"(in), "r"(out), "r"(m) : "xmm1", "xmm2", "memory");
#elif defined(__aarch64__)
  asm volatile("ldr q1, [%0]\n\trev32 v1.16b, v1.16b\n\tstr q1, [%1]" : : "r"(in), "r"(out) : "v1", "memory");
#else
  for (int i = 0; i < 16; i++) out[i] = in[(i & ~3) + 3 - (i & 3)];
#endif
}

/* palignr $4 of (hi:lo) and pblendw $0xf0 of (a, b): lo's words 1..3 then hi's word 0; a's low
 * half then b's high half */
static void align_blend(const unsigned *lo, const unsigned *hi, unsigned *al, unsigned *bl) {
#if defined(__x86_64__)
  asm volatile("movdqu (%0), %%xmm3\n\tmovdqu (%1), %%xmm4\n\tpalignr $4, %%xmm3, %%xmm4\n\tmovdqu %%xmm4, (%2)\n\t"
               "movdqu (%0), %%xmm5\n\tmovdqu (%1), %%xmm6\n\tpblendw $0xf0, %%xmm6, %%xmm5\n\tmovdqu %%xmm5, (%3)"
               : : "r"(lo), "r"(hi), "r"(al), "r"(bl) : "xmm3", "xmm4", "xmm5", "xmm6", "memory");
#else
  for (int i = 0; i < 4; i++) al[i] = i < 3 ? lo[i + 1] : hi[0];
  for (int i = 0; i < 4; i++) bl[i] = i < 2 ? lo[i] : hi[i];
#endif
}

/* sha256msg1 w, x: w[i] + s0(w[i+1]), w[4] being x[0] */
static int msg1_ok(const unsigned *w, const unsigned *x) {
  unsigned want[4], got[4];
  for (int i = 0; i < 4; i++) {
    unsigned v = i < 3 ? w[i + 1] : x[0];
    want[i] = w[i] + (rr(v, 7) ^ rr(v, 18) ^ (v >> 3)); }
#if defined(__x86_64__)
  asm volatile("movdqu (%0), %%xmm9\n\tmovdqu (%1), %%xmm10\n\tsha256msg1 %%xmm10, %%xmm9\n\tmovdqu %%xmm9, (%2)"
               : : "r"(w), "r"(x), "r"(got) : "xmm9", "xmm10", "memory");
#elif defined(__aarch64__) && (defined(__moonlibc__) || defined(__ARM_FEATURE_SHA2))
  asm volatile("ldr q16, [%0]\n\tldr q17, [%1]\n\tsha256su0 v16.4s, v17.4s\n\tstr q16, [%2]"
               : : "r"(w), "r"(x), "r"(got) : "v16", "v17", "memory");
#else
  for (int i = 0; i < 4; i++) got[i] = want[i];
#endif
  for (int i = 0; i < 4; i++) if (got[i] != want[i]) return 0;
  return 1;
}

int main(void) {
  unsigned char in[16], out[16];
  for (int i = 0; i < 16; i++) in[i] = (unsigned char)(17 * i + 3);
  turn(in, out);
  int bad = 0;
  for (int i = 0; i < 16; i++) if (out[i] != in[(i & ~3) + 3 - (i & 3)]) bad |= 1;
  unsigned lo[4] = {0x11111111, 0x22222222, 0x33333333, 0x44444444};
  unsigned hi[4] = {0x55555555, 0x66666666, 0x77777777, 0x88888888};
  unsigned al[4], bl[4];
  align_blend(lo, hi, al, bl);
  if (al[0] != 0x22222222 || al[3] != 0x55555555) bad |= 2;
  if (bl[1] != 0x22222222 || bl[2] != 0x77777777) bad |= 4;
  unsigned w[4] = {0x61626380, 0, 0, 0}, x[4] = {0x01234567, 0x89abcdef, 7, 9};
  if (sha_ext() && !msg1_ok(w, x)) bad |= 8;
  return bad;
}
