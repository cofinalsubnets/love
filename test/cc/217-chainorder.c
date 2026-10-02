/* x = a ^ b ^ .. with some terms reading x again through the locals: the order of an and/or/xor
 * chain may change, its answer may not. chains of one type, of mixed widths and signs, through
 * calls, and loop-carried, and one op over mixed signs, each held to a fixed-order reference and to gcc. */

#include <stdint.h>

static uint32_t T[4][256];
static int calls;

__attribute__((noinline)) static uint32_t tick(uint32_t v) { calls = calls * 31 + (int) (v & 7); return v * 2654435761u; }
__attribute__((noinline)) static uint64_t hide(uint64_t v) { return v; }

/* the crc shape: a rides c, b does not */
__attribute__((noinline)) static uint32_t carried(uint32_t c, const uint32_t *p, int n) {
  for (int i = 0; i < n; i += 2) {
    uint32_t a = c ^ p[i], b = p[i + 1];
    c = T[3][a & 0xff] ^ T[2][(a >> 8) & 0xff] ^ T[1][b & 0xff] ^ T[0][b >> 24]; }
  return c; }
__attribute__((noinline)) static uint32_t carried_or(uint32_t c, const uint32_t *p, int n) {
  for (int i = 0; i < n; i++) {
    uint32_t a = c + p[i], b = p[i] >> 3;
    c = (a & 0x0f0f0f0fu) | (b & 0xf0f0f0f0u) | (T[1][b & 0xff] & 0x00ff00ffu);
    c &= ~(b << 1) & (a | 0x80000001u) & 0xfffffffeu; }
  return c; }
/* mixed widths and signs: a reorder across them would change the answer */
__attribute__((noinline)) static uint64_t mixed(uint32_t u, int32_t s, uint64_t w) {
  uint64_t x = w;
  int32_t t = s ^ (int32_t) u;
  x = u ^ s ^ x ^ (uint64_t) t;
  return x; }
__attribute__((noinline)) static int64_t narrow(uint8_t a, int8_t b, int64_t x) {
  int64_t y = x ^ a;
  x = a ^ b ^ y ^ (int16_t) x;
  return x; }
/* one op, mixed signs: uint ^ int and uint | int are unsigned int, zero-extended when widened */
__attribute__((noinline)) static uint64_t lits(uint32_t u, int32_t s) {
  uint64_t a = u ^ s, b = u | s, c = u & s, d = u ^ -5, e = u | -1, f = (u ^ 5) + (u & -2);
  return a * 3 + b * 5 + c * 7 + d * 11 + e * 13 + f; }
/* calls in the chain: their order is the program's */
__attribute__((noinline)) static uint32_t impure(uint32_t c) {
  uint32_t a = c ^ 0x55u;
  c = tick(a) ^ tick(7) ^ tick(c) ^ tick(9);
  return c; }

int main(void) {
  uint32_t seed = 0x2468aceu;
  for (int r = 0; r < 4; r++)
    for (int i = 0; i < 256; i++) { seed = seed * 1664525u + 1013904223u; T[r][i] = seed; }
  uint32_t buf[64];
  for (int i = 0; i < 64; i++) { seed = seed * 1664525u + 1013904223u; buf[i] = seed; }
  int bad = 0;

  uint32_t c = 0xffffffffu;
  for (int i = 0; i < 64; i += 2) {
    uint32_t a = c ^ buf[i], b = buf[i + 1];
    uint32_t v = T[3][a & 0xff];
    v ^= T[2][(a >> 8) & 0xff]; v ^= T[1][b & 0xff]; v ^= T[0][b >> 24];
    c = v; }
  if (carried(0xffffffffu, buf, 64) != c) bad |= 1;

  c = 12345;
  for (int i = 0; i < 64; i++) {
    uint32_t a = c + buf[i], b = buf[i] >> 3;
    uint32_t v = a & 0x0f0f0f0fu;
    v |= b & 0xf0f0f0f0u; v |= T[1][b & 0xff] & 0x00ff00ffu;
    uint32_t m = ~(b << 1);
    m &= a | 0x80000001u; m &= 0xfffffffeu;
    c = v & m; }
  if (carried_or(12345, buf, 64) != c) bad |= 2;

  for (uint32_t k = 0; k < 100; k++) {
    uint32_t u = k * 0x9e3779b9u; int32_t s = (int32_t) (k * 0x85ebca6bu); uint64_t w = hide(0xdeadbeefcafef00dull * k);
    uint64_t e = (uint64_t) (u ^ (uint32_t) s);   /* u ^ s is unsigned int, zero-extended */
    e ^= w; e ^= (uint64_t) (int64_t) (s ^ (int32_t) u);
    if (mixed(u, s, w) != e) bad |= 4;
    uint8_t a8 = (uint8_t) (k * 37); int8_t b8 = (int8_t) (k * 91); int64_t x = (int64_t) hide((uint64_t) k * 0x9999999999ull) - 77;
    int64_t y = x ^ a8;
    int64_t want = (int64_t) (a8 ^ b8); want ^= y; want ^= (int16_t) x;
    if (narrow(a8, b8, x) != want) bad |= 8;
    uint64_t l = (uint64_t) (uint32_t) (u ^ (uint32_t) s) * 3 + (uint64_t) (uint32_t) (u | (uint32_t) s) * 5 +
                 (uint64_t) (uint32_t) (u & (uint32_t) s) * 7 + (uint64_t) (uint32_t) (u ^ 0xfffffffbu) * 11 +
                 (uint64_t) 0xffffffffu * 13 + (uint64_t) (uint32_t) ((u ^ 5u) + (u & 0xfffffffeu));
    if (lits(u, s) != l) bad |= 32;
  }

  calls = 0;
  uint32_t got = impure(0x1234u);
  int seen = calls;
  calls = 0;
  uint32_t a = 0x1234u ^ 0x55u;
  uint32_t t1 = tick(a), t2 = tick(7), t3 = tick(0x1234u), t4 = tick(9);
  if (got != (t1 ^ t2 ^ t3 ^ t4)) bad |= 16;
  (void) seen;
  return bad;
}
