// src/love/audio/silk.h -- opus's silk layer (rfc 6716 4.2): its state, plain data, and its door.
// a zeroed struct silk after sk_reset is a fresh decoder; sk_reset alone (a mode switch) keeps
// the channel counts it last saw
#ifndef LOVE_SILK_H
#define LOVE_SILK_H
#include <stdint.h>
#include "opus.h"

struct sk_rs {                  // the resampler to 48 khz: up 2x, then a 12-phase interpolator
 int32_t iir[6], step;          // the allpass chains, the input step in q16 of the doubled rate
 int16_t fir[8], dly[16];       // the interpolator's tail, the input held back
 int khz, lag; };

struct sk_idx {                 // one frame's coded parameters
 int8_t gain[4], ltp[4], lsf[17];
 int lag, contour, type, offset, interp, per, scale, seed; };

struct sk_plc {                 // what concealment carries from the last good frame
 int32_t pitch, seed, energy, gain[2];
 int16_t ltp[5], lpc[16], scale, ltp_scale;
 int lost, shift, khz, nsub, slen; };

struct sk_cng {                 // comfort noise: a smoothed spectrum and an excitation to replay
 int32_t exc[320], syn[16], gain, seed;
 int16_t lsf[16];
 int khz; };

struct sk_ch {                  // one channel
 int16_t out[480];              // the last output, the long-term predictor's memory
 int32_t exc[320], lpc[16], prev_gain;
 int16_t prev_lsf[16];
 int khz, nsub, flen, order, first, lag_prev, last_gain, prev_type, loss;
 int frames, nframes, ec_type, ec_lag, vad[3], lbrr, lbrr_f[3];
 struct sk_idx ix;
 struct sk_rs rs;
 struct sk_cng cng;
 struct sk_plc plc; };

struct silk {
 struct sk_ch ch[2];
 int16_t pred[2], mid[2], side[2];   // stereo: the last weights, the samples held over
 int api, nint, mid_only; };         // output and coded channels last seen, last frame mid only

void sk_reset(struct silk *s);
// one 10 or 20 ms frame (one call per silk frame of an opus frame, first 1 on the first):
// lost 1 conceals; khz 8, 12 or 16; sch, och the coded and output channels; ms the opus
// frame's length, 10, 20, 40 or 60. out gets 48 khz samples, och interleaved, *n per channel
// -> 0, or nonzero for a length or rate it can't decode
int sk_decode(struct silk *s, struct rdec *d, int lost, int first, int khz, int sch, int och,
              int ms, int16_t *out, int *n);

#endif
