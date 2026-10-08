// bytes -- words off unaligned byte runs, either order, and the msb-first crc-32 step (cksum,
// bzip2). a caller owns the bound: each reads its full width.
#pragma once
#include "love.h"

static love_inline uint32_t ld16be(uint8_t const *p) { return (uint32_t) p[0] << 8 | p[1]; }
static love_inline uint32_t ld32be(uint8_t const *p) {
 return (uint32_t) p[0] << 24 | (uint32_t) p[1] << 16 | (uint32_t) p[2] << 8 | p[3]; }
static love_inline uint64_t ld64be(uint8_t const *p) { return (uint64_t) ld32be(p) << 32 | ld32be(p + 4); }
static love_inline uint32_t ld16le(uint8_t const *p) { return p[0] | (uint32_t) p[1] << 8; }
static love_inline uint32_t ld24le(uint8_t const *p) { return ld16le(p) | (uint32_t) p[2] << 16; }
static love_inline uint32_t ld32le(uint8_t const *p) { return ld24le(p) | (uint32_t) p[3] << 24; }
static love_inline uint64_t ld64le(uint8_t const *p) { return (uint64_t) ld32le(p + 4) << 32 | ld32le(p); }

// n samples scaled by v, laid as f32le (f) or s16le (clamped, rounded half away from zero) -> past the last
static love_inline uint8_t *pcm_lay(uint8_t *q, float const *x, uintptr_t n, bool f, double v) {
 for (uintptr_t i = 0; i < n; i++)
  if (f) { union { float f; uint32_t u; } c = {(float) (x[i] * v)}; for (int j = 0; j < 4; j++) *q++ = (uint8_t) (c.u >> (8 * j)); }
  else {
   double y = x[i] * v * 32768;
   y = y > 32767 ? 32767 : y < -32768 ? -32768 : y;
   int t = y >= 0 ? (int) (y + 0.5) : -(int) (-y + 0.5);
   *q++ = (uint8_t) t, *q++ = (uint8_t) (t >> 8); }
 return q; }

// one load where the machine takes an unaligned one -- mooncc lays a byte gather as eight loads
// and as many shifts and ors
#if defined(__x86_64__) || defined(__aarch64__)
#define wideld 1
struct u64u { uint64_t v; } __attribute__((packed, aligned(1)));
#define ld64(p) (((struct u64u const*)(p))->v)
#define st64(p, x) (((struct u64u*)(p))->v = (x))
#else
#define wideld 0
#endif

// a byte into the msb-first register, polynomial 0x04c11db7 (not reflected)
static love_inline uint32_t crc_msb(uint32_t c, uint8_t b) {
 c ^= (uint32_t) b << 24;
 for (int k = 0; k < 8; k++) c = (c & 0x80000000u) ? (c << 1) ^ 0x04c11db7u : c << 1;
 return c; }
