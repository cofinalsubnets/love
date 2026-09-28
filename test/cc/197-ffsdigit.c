/* __builtin_ffs over a runtime value: 0 for 0, else the lowest set bit's 1-based index, its
 * operand read once; and __builtin_isdigit, a range test that folds over a constant. the
 * 64-bit forms ride where a long is a word. held to gcc. */

#if defined(__clang__) && !defined(__mooncc__)
#define __builtin_isdigit(c) ((unsigned)((c) - '0') < 10)   /* clang has no builtin of it */
#endif

static char dig[__builtin_isdigit('7') + 1];

static int ffs_ref(unsigned long long v, int w) {
  for (int i = 0; i < w; i++)
    if (v >> i & 1) return i + 1;
  return 0;
}

int main(void) {
  int bad = 0;
  volatile int z = 0, one = 1, neg = -1, top = (int)0x80000000u, mid = 0x1000;
  if (__builtin_ffs(z) != 0 || __builtin_ffs(one) != 1 || __builtin_ffs(neg) != 1) bad |= 1;
  if (__builtin_ffs(top) != 32 || __builtin_ffs(mid) != 13) bad |= 2;
  unsigned x = 0x12345670u;
  for (int i = 0; i < 40; i++, x = x * 2654435761u + (unsigned)i)
    if (__builtin_ffs((int)(x << (i % 32))) != ffs_ref(x << (i % 32), 32)) bad |= 4;
  int k = 8, *p = &k;
  if (__builtin_ffs((*p)++) != 4 || k != 9) bad |= 8;
  volatile long l = 0x60;
  if (__builtin_ffsl(l) != 6 || __builtin_ffsl(l - l) != 0) bad |= 16;
#if __SIZEOF_POINTER__ == 8
  volatile long long w = 1LL << 40, w0 = 0;
  if (__builtin_ffsll(w) != 41 || __builtin_ffsll(w0) != 0 || __builtin_ffsl((long)w * 8) != 44) bad |= 32;
  if (__builtin_ffsll((long long)(1ULL << 63)) != 64) bad |= 32;
#endif
  int nd = 0;
  for (int c = -1; c < 256; c++) nd += __builtin_isdigit(c) != (c >= '0' && c <= '9');
  if (nd) bad |= 64;
  int j = '3';
  if (!__builtin_isdigit(j++) || j != '4' || __builtin_isdigit('a') || sizeof dig != 2) bad |= 128;
  return bad;
}
