/* the top half of a register: a 32-bit value's zero-extension kept where the high bits may be
 * live (an add's carry, a shl, a signed or full-word load, a call, a join of two paths) and
 * dropped where they cannot be; a 32-bit load folded into the and/or/xor reading it, by index and
 * by base, two- and three-address. each is held to a reference that cannot see through, and to gcc. */

#include <stdint.h>

static uint32_t T[4][64];
static int32_t S[64];
static uint64_t Q[8];
static uint32_t one = 1;

__attribute__((noinline)) static uint64_t widen(uint64_t x) { return x; }
__attribute__((noinline)) static uint64_t hide(uint64_t x) { return x * 3 + 1; }

__attribute__((noinline)) static uint64_t carry(uint32_t a, uint32_t b) { return (uint64_t) (uint32_t) (a + b) + a; }
__attribute__((noinline)) static uint64_t shl(uint32_t a) { uint32_t s = a << 4; return (uint64_t) s + (uint64_t) a; }
__attribute__((noinline)) static uint64_t sload(unsigned i) { uint32_t v = (uint32_t) S[i & 63]; return (uint64_t) v; }
__attribute__((noinline)) static uint64_t qload(unsigned i) { uint32_t v = (uint32_t) Q[i & 7]; return v ^ (uint64_t) one; }
__attribute__((noinline)) static uint64_t across(uint32_t a) { uint32_t v = a ^ T[0][a & 63]; uint64_t h = hide(v); return (uint32_t) (v ^ (uint32_t) h); }
__attribute__((noinline)) static uint64_t join(uint32_t a, uint64_t w, int k) {
  uint32_t v = k ? a : (uint32_t) w;      /* one arm hz, the other a truncation */
  return (uint64_t) v ^ T[1][a & 63]; }
__attribute__((noinline)) static uint64_t looped(const uint32_t *p, int n, uint64_t seed) {
  uint32_t c = (uint32_t) seed;
  for (int i = 0; i < n; i++) c = (c >> 8) ^ T[2][(c ^ p[i]) & 63] ^ (uint32_t) (seed >> (i & 31));
  return c; }
__attribute__((noinline)) static uint64_t folds(unsigned i, uint32_t x, const uint32_t *p) {
  uint32_t a = x ^ T[3][i & 63];          /* two-address xor by index */
  uint32_t b = x | T[2][(i + 1) & 63];    /* three-address: x stays live */
  uint32_t c = a & T[1][(i + 2) & 63];
  uint32_t d = b ^ p[1];                  /* by base */
  uint32_t e = (d | p[2]) & p[3];
  return (uint64_t) a + b + c + d + e + x; }
__attribute__((noinline)) static uint64_t wide(uint64_t w, unsigned i) { return w ^ T[0][i & 63]; }   /* a 64-bit xor keeps its top */

/* the references: every 32-bit value through a 64-bit mask the compiler cannot see through */
static uint64_t m32;
__attribute__((noinline)) static uint64_t lo(uint64_t x) { return x & m32; }

int main(void) {
  m32 = widen(0xffffffffu);
  for (int r = 0; r < 4; r++)
    for (int i = 0; i < 64; i++) T[r][i] = (uint32_t) (i * 2654435761u + r * 40503u) ^ 0x80000001u;
  for (int i = 0; i < 64; i++) S[i] = (int32_t) (i * 7919) - 250000;
  for (int i = 0; i < 8; i++) Q[i] = 0xfedcba9876543210ull * (uint64_t) (i + 1);
  int bad = 0;
  uint32_t buf[64];
  for (int i = 0; i < 64; i++) buf[i] = T[i & 3][(i * 5) & 63] + (uint32_t) i;
  for (uint32_t k = 0; k < 200; k++) {
    uint32_t a = k * 0x9e3779b9u + 0xfffffff0u, b = ~a ^ (k << 21);
    uint64_t w = widen((uint64_t) b << 32 | a);
    if (carry(a, b) != lo(a + (uint64_t) b) + a) bad |= 1;
    if (shl(a) != lo((uint64_t) a << 4) + a) bad |= 2;
    if (sload(k) != lo((uint64_t) (int64_t) S[k & 63])) bad |= 4;
    if (qload(k) != (lo(Q[k & 7]) ^ 1)) bad |= 8;
    if (across(a) != lo(a ^ T[0][a & 63] ^ hide(lo(a ^ T[0][a & 63])))) bad |= 16;
    if (join(a, w, (int) (k & 1)) != (lo((k & 1) ? a : w) ^ T[1][a & 63])) bad |= 32;
    if (wide(w, k) != (w ^ T[0][k & 63])) bad |= 64;
    uint64_t f = folds(k, a, buf + (k & 31));
    const uint32_t *p = buf + (k & 31);
    uint64_t fa = lo(a ^ T[3][k & 63]), fb = lo(a | T[2][(k + 1) & 63]), fc = lo(fa & T[1][(k + 2) & 63]);
    uint64_t fd = lo(fb ^ p[1]), fe = lo((fd | p[2]) & p[3]);
    if (f != fa + fb + fc + fd + fe + a) bad |= 128;
  }
  uint64_t c = lo(0x1234567890abcdefull);
  for (int i = 0; i < 64; i++) c = lo((c >> 8) ^ T[2][(c ^ buf[i]) & 63] ^ lo(0x1234567890abcdefull >> (i & 31)));
  if (looped(buf, 64, 0x1234567890abcdefull) != c) bad |= 256;
  return bad;
}
