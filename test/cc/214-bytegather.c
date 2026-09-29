/* a little-endian byte gather is one load: (T)p[0] | (T)p[1] << 8 | .. over consecutive
 * bytes of one unsigned char pointer, in any term order, at two, four and eight bytes, at an
 * offset; and the shapes that are not one -- a gap, a signed byte, two pointers, a byte out of
 * place, a big-endian order -- keep their meaning. each is held to a byte loop, and to gcc. */

#include <stdint.h>

static inline uint32_t le32(const uint8_t *p) {
  return (uint32_t) p[0] | (uint32_t) p[1] << 8 | (uint32_t) p[2] << 16 | (uint32_t) p[3] << 24; }
static inline uint64_t le64(const uint8_t *p) {
  return (uint64_t) le32(p) | (uint64_t) le32(p + 4) << 32; }

__attribute__((noinline)) static unsigned le16(const uint8_t *p) {
  return (unsigned) p[0] | (unsigned) p[1] << 8; }
__attribute__((noinline)) static uint32_t shuffled(const uint8_t *p) {
  return (uint32_t) p[2] << 16 | (uint32_t) p[0] | (uint32_t) p[3] << 24 | (uint32_t) p[1] << 8; }
__attribute__((noinline)) static uint64_t wide(const uint8_t *p) {
  return (uint64_t) p[0] | (uint64_t) p[1] << 8 | (uint64_t) p[2] << 16 | (uint64_t) p[3] << 24 |
         (uint64_t) p[4] << 32 | (uint64_t) p[5] << 40 | (uint64_t) p[6] << 48 | (uint64_t) p[7] << 56; }
__attribute__((noinline)) static uint32_t gap(const uint8_t *p) {        /* byte 2 skipped */
  return (uint32_t) p[0] | (uint32_t) p[1] << 8 | (uint32_t) p[3] << 16 | (uint32_t) p[4] << 24; }
__attribute__((noinline)) static uint32_t sbytes(const int8_t *p) {      /* signed bytes sign-extend */
  return (uint32_t) p[0] | (uint32_t) p[1] << 8 | (uint32_t) p[2] << 16 | (uint32_t) p[3] << 24; }
__attribute__((noinline)) static uint32_t two(const uint8_t *p, const uint8_t *q) {
  return (uint32_t) p[0] | (uint32_t) q[1] << 8 | (uint32_t) p[2] << 16 | (uint32_t) q[3] << 24; }
__attribute__((noinline)) static uint32_t misplaced(const uint8_t *p) {  /* byte 1 at 16, byte 2 at 8 */
  return (uint32_t) p[0] | (uint32_t) p[1] << 16 | (uint32_t) p[2] << 8 | (uint32_t) p[3] << 24; }
__attribute__((noinline)) static uint32_t be32(const uint8_t *p) {       /* big-endian: not this lane */
  return (uint32_t) p[0] << 24 | (uint32_t) p[1] << 16 | (uint32_t) p[2] << 8 | (uint32_t) p[3]; }

/* the references: one byte a step, each byte's shift from a table, so no gather shape */
__attribute__((noinline)) static uint64_t ref(const uint8_t *p, const int *off, const int *sh, int n) {
  uint64_t v = 0;
  for (int i = 0; i < n; i++) v |= (uint64_t) p[off[i]] << sh[i];
  return v; }
__attribute__((noinline)) static uint32_t sref(const int8_t *p) {
  uint32_t v = 0;
  for (int i = 0; i < 4; i++) v |= (uint32_t) (int32_t) p[i] << (8 * i);
  return v; }

int main(void) {
  static const int o[8] = {0, 1, 2, 3, 4, 5, 6, 7}, s[8] = {0, 8, 16, 24, 32, 40, 48, 56};
  static const int og[4] = {0, 1, 3, 4}, om[4] = {0, 1, 2, 3}, sm[4] = {0, 16, 8, 24};
  static const int ob[4] = {0, 1, 2, 3}, sb[4] = {24, 16, 8, 0};
  uint8_t b[16] = {0x01, 0x82, 0x03, 0xf4, 0x05, 0x96, 0x07, 0xe8, 0x09, 0xaa, 0x0b, 0xcc, 0x0d, 0xee, 0x0f, 0x10};
  uint8_t c[4] = {0x11, 0x22, 0x33, 0x44};
  int bad = 0;
  for (int k = 0; k < 8; k++) {
    if (le32(b + k) != ref(b + k, o, s, 4)) bad |= 1;
    if (le64(b + k) != ref(b + k, o, s, 8)) bad |= 2;
    if (le16(b + k) != ref(b + k, o, s, 2)) bad |= 4;
    if (shuffled(b + k) != ref(b + k, o, s, 4)) bad |= 8;
    if (wide(b + k) != ref(b + k, o, s, 8)) bad |= 16;
    if (gap(b + k) != ref(b + k, og, s, 4)) bad |= 32;
    if (sbytes((const int8_t *) b + k) != sref((const int8_t *) b + k)) bad |= 64;
    if (misplaced(b + k) != ref(b + k, om, sm, 4)) bad |= 128;
    if (be32(b + k) != ref(b + k, ob, sb, 4)) bad |= 256;
  }
  if (two(b, c) != (0x01u | 0x22u << 8 | 0x03u << 16 | 0x44u << 24)) bad |= 512;
  return bad ? 1 + (bad & 63) + (bad >> 6 ? 64 : 0) : 0;
}
