#ifndef _AI_BYTESWAP_H
#define _AI_BYTESWAP_H
/* the byte swaps, in shifts every seat lays (the thumb ones take no bswap builtin) */
#include <stdint.h>
static inline uint16_t bswap_16(uint16_t x) { return (uint16_t) (x >> 8 | x << 8); }
static inline uint32_t bswap_32(uint32_t x) {
  return x >> 24 | (x >> 8 & 0xff00u) | (x << 8 & 0xff0000u) | x << 24; }
static inline uint64_t bswap_64(uint64_t x) {
  return (uint64_t) bswap_32((uint32_t) x) << 32 | bswap_32((uint32_t) (x >> 32)); }
#endif
