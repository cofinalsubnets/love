/* table rows by a runtime index: the rows of one global table read and written in one run, a
 * row's address taken whole, signed and unsigned 32-bit cells, and a value masked to its low
 * 8, 16 and 32 bits into a fresh register. each is held to a cell-at-a-time reference, and to gcc. */

#include <stdint.h>

static uint32_t T[8][256];
static int32_t S[4][64];
static uint32_t W[4][16];

__attribute__((noinline)) static uint32_t rows(uint32_t a, uint32_t b) {   /* slicing-by-8's shape */
  return T[7][a & 0xff] ^ T[6][(a >> 8) & 0xff] ^ T[5][(a >> 16) & 0xff] ^ T[4][a >> 24] ^
         T[3][b & 0xff] ^ T[2][(b >> 8) & 0xff] ^ T[1][(b >> 16) & 0xff] ^ T[0][b >> 24]; }
__attribute__((noinline)) static int64_t srows(unsigned i, unsigned j) {   /* signed cells sign-extend */
  return (int64_t) S[0][i & 63] + S[1][j & 63] + S[3][(i + j) & 63]; }
__attribute__((noinline)) static void wrows(unsigned i, uint32_t v) {     /* a store among the reads */
  W[1][i & 15] = W[0][i & 15] + v;
  W[3][(i + 1) & 15] = W[2][i & 15] ^ v; }
__attribute__((noinline)) static uint32_t *rowof(unsigned k) { return T[k & 7]; }
__attribute__((noinline)) static uint32_t escaped(unsigned i) {             /* the row's address leaves */
  uint32_t *r = T[2];
  uint32_t v = T[1][i & 0xff] + r[(i + 1) & 0xff];
  return v + (uint32_t) (rowof(2) - r); }
__attribute__((noinline)) static uint64_t masks(uint64_t x) {
  uint64_t a = x & 0xff, b = x & 0xffff, c = x & 0xffffffff;
  return a + (b << 1) + (c << 2) + x; }

/* the references: one cell a step through a pointer the compiler cannot see through */
__attribute__((noinline)) static uint32_t cell(const uint32_t *base, int row, unsigned i) {
  return base[row * 256 + i]; }
__attribute__((noinline)) static uint64_t mref(uint64_t x) {
  uint64_t a = 0, b = 0, c = 0;
  for (int k = 0; k < 64; k++) {
    uint64_t bit = x >> k & 1;
    if (k < 8) a |= bit << k;
    if (k < 16) b |= bit << k;
    if (k < 32) c |= bit << k; }
  return a + (b << 1) + (c << 2) + x; }

int main(void) {
  uint32_t seed = 0x12345678u;
  for (int r = 0; r < 8; r++)
    for (int i = 0; i < 256; i++) { seed = seed * 1103515245u + 12345u; T[r][i] = seed; }
  for (int r = 0; r < 4; r++)
    for (int i = 0; i < 64; i++) S[r][i] = (int32_t) (i * 37 + r * 11) - 1000;
  for (int r = 0; r < 4; r++)
    for (int i = 0; i < 16; i++) W[r][i] = (uint32_t) (r * 100 + i);
  int bad = 0;
  const uint32_t *t = &T[0][0];
  for (uint32_t k = 0; k < 64; k++) {
    uint32_t a = k * 0x9e3779b9u, b = ~a ^ (k << 13);
    uint32_t want = cell(t, 7, a & 0xff) ^ cell(t, 6, (a >> 8) & 0xff) ^ cell(t, 5, (a >> 16) & 0xff) ^
                    cell(t, 4, a >> 24) ^ cell(t, 3, b & 0xff) ^ cell(t, 2, (b >> 8) & 0xff) ^
                    cell(t, 1, (b >> 16) & 0xff) ^ cell(t, 0, b >> 24);
    if (rows(a, b) != want) bad |= 1;
    int64_t sw = (int64_t) S[0][k & 63] + S[1][(k * 7) & 63] + S[3][(k + k * 7) & 63];
    if (srows(k, k * 7) != sw) bad |= 2;
    if (escaped(k) != cell(t, 1, k & 0xff) + cell(t, 2, (k + 1) & 0xff)) bad |= 4;
    uint64_t x = (uint64_t) a << 32 | b;
    if (masks(x) != mref(x)) bad |= 8;
  }
  for (unsigned i = 0; i < 16; i++) {
    uint32_t w0 = W[0][i], w2 = W[2][i];
    wrows(i, 0x55u + i);
    if (W[1][i] != w0 + 0x55u + i || W[3][(i + 1) & 15] != (w2 ^ (0x55u + i))) bad |= 16;
  }
  return bad;
}
