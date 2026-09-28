/* the bit builtins fold as constant expressions: case labels (the kernel's htons(ETH_P_IP)),
 * an array dimension, a bit-field width, a static initializer and an enum, each held to gcc. */

typedef unsigned short __u16;
typedef __u16 __be16;
#define htons(x) ((__be16)(__u16)__builtin_bswap16((__u16)(x)))

enum { K32 = __builtin_bswap32(0x01020304) };
static unsigned long long k64 = __builtin_bswap64(0x0102030405060708ULL);
static char dim[__builtin_bswap16(0x0300)];
struct bf { unsigned w : 63 - __builtin_clzll(8); unsigned t : __builtin_ctz(0x40); };
enum { P = __builtin_popcount(0xf0f0), PL = __builtin_popcountll(~0ULL), F = __builtin_ffs(0x18),
       F0 = __builtin_ffsl(0), C = __builtin_clz(1), CL = __builtin_ctzll(1ULL << 40) };

static int proto(__be16 p) {
  switch (p) {
  case htons(0x0800): return 4;
  case htons(0x86DD): return 6;
  case __builtin_bswap16(0xffff): return 1;
  default: return 0;
  }
}

int main(void) {
  int bad = 0;
  if (proto(htons(0x0800)) != 4 || proto(htons(0x86DD)) != 6) bad |= 1;
  if (proto(0xffff) != 1 || proto(0x0800) != 0) bad |= 2;
  if (K32 != 0x04030201) bad |= 4;
  if (k64 != 0x0807060504030201ULL) bad |= 8;
  if (sizeof dim != 3) bad |= 16;
  if (__builtin_bswap16(0x1234) != 0x3412) bad |= 32;
  struct bf b = { 0, 0 };
  b.w--, b.t--;
  if (b.w != 7 || b.t != 63) bad |= 64;
  if (P != 8 || PL != 64 || F != 4 || F0 != 0 || C != 31 || CL != 40) bad |= 128;
  switch (b.t) { case __builtin_popcountll(0x3f3f) - 6: break; default: bad |= 256; }
  return bad;
}
