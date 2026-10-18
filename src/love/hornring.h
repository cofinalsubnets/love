// hornring.h -- the stereo s16 ring between horn.c's pushes and a card's pulls; the fill is horn-lag.
// single producer, single consumer, no lock: each side writes only its own index. the indices
// run free and unsigned, so wr - rd is the fill across a wrap: never mask them in place.
// n is in frames, a power of two; the buffer is the caller's
#pragma once
#include <stdint.h>

struct horn_ring { int16_t *buf; unsigned n, rd, wr; };

static inline unsigned hring_lag(struct horn_ring const *r) { return r->wr - r->rd; }

// answers the bytes taken, short when full: horn.c keeps the residue and parks
static inline int hring_push(struct horn_ring *r, void const *pcm, int nbytes) {
  int16_t const *s = (int16_t const *) pcm;
  unsigned rd = r->rd, wr = r->wr;
  int frames = nbytes / 4, k = 0;
  for (; k < frames && wr - rd < r->n; k++, wr++) {
    r->buf[(wr & (r->n - 1)) * 2] = s[k * 2];
    r->buf[(wr & (r->n - 1)) * 2 + 1] = s[k * 2 + 1]; }
  r->wr = wr;
  return k * 4; }

// answers the real frames; a starved ring pads with silence, not a held frame (a tone)
static inline int hring_pull(struct horn_ring *r, int16_t *lch, int16_t *rch, int len) {
  unsigned rd = r->rd, wr = r->wr;
  int i = 0;
  for (; i < len && rd != wr; i++, rd++) {
    lch[i] = r->buf[(rd & (r->n - 1)) * 2];
    rch[i] = r->buf[(rd & (r->n - 1)) * 2 + 1]; }
  r->rd = rd;
  for (int j = i; j < len; j++) lch[j] = rch[j] = 0;
  return i; }
