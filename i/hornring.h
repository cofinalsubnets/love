// i/hornring.h -- the PCM ring between a horn that PUSHES and a device that PULLS.
//
// i/horn.c hands a seat interleaved stereo s16 whenever love writes, and a card asks for
// frames on its own clock -- an SDK callback, a DMA refill, an interrupt. neither side
// can wait for the other, so a ring stands between them and the PULL is what paces it:
// the fill is `horn-lag` answering with the speaker's own number rather than a clock's.
//
// SINGLE PRODUCER, SINGLE CONSUMER, and they may be different contexts: the writer moves
// wr and reads rd, the reader moves rd and reads wr, and neither ever writes the other's
// index. that is the whole of the concurrency here -- no lock, and none wanted, because
// a torn read of an index that only ever advances costs at worst one frame's judgement
// about how full the ring is. the indices are FREE-RUNNING and unsigned: the difference
// is the fill even across a wrap, which is why they are never masked in place.
//
// the buffer is the caller's, so this file keeps no state and a seat may hold two.
// n is in FRAMES and must be a power of two.
#pragma once
#include <stdint.h>

struct horn_ring { int16_t *buf; unsigned n, rd, wr; };

static inline unsigned hring_lag(struct horn_ring const *r) { return r->wr - r->rd; }

// push nbytes of interleaved stereo s16; answers the bytes TAKEN, which is short when
// the ring is full. short is not a loss: i/horn.c keeps the residue and parks, so the
// frames arrive behind these. dropping here instead would be a gap nobody reports.
static inline int hring_push(struct horn_ring *r, void const *pcm, int nbytes) {
  int16_t const *s = (int16_t const *) pcm;
  unsigned rd = r->rd, wr = r->wr;
  int frames = nbytes / 4, k = 0;
  for (; k < frames && wr - rd < r->n; k++, wr++) {
    r->buf[(wr & (r->n - 1)) * 2] = s[k * 2];
    r->buf[(wr & (r->n - 1)) * 2 + 1] = s[k * 2 + 1]; }
  r->wr = wr;
  return k * 4; }

// pull len frames into two per-channel buffers, as a card asks for them. a starved ring
// answers SILENCE for the rest rather than holding the last frame, which would ring a
// tone under a stall. answers the frames that were real.
static inline int hring_pull(struct horn_ring *r, int16_t *lch, int16_t *rch, int len) {
  unsigned rd = r->rd, wr = r->wr;
  int i = 0;
  for (; i < len && rd != wr; i++, rd++) {
    lch[i] = r->buf[(rd & (r->n - 1)) * 2];
    rch[i] = r->buf[(rd & (r->n - 1)) * 2 + 1]; }
  r->rd = rd;
  for (int j = i; j < len; j++) lch[j] = rch[j] = 0;
  return i; }
