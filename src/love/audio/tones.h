// src/love/audio/tones.h -- voices as small graphs of operators, run over a run of frames and
// summed to stereo (tonerun.c): plain C that asks nothing of love, so a board's firmware runs
// them too. love lays the rows (src/apps/harp/ops.l) and tones.c is its door.
// tones_run(ops, no, st, n, f0, rate, L, R, sc): the no rows of ops over the n frames from f0,
//   summed into L and R, n each; st each operator's last two outputs (its feedback), read and
//   left for the next run; sc no * n of scratch. it allocates nothing. a row is tn_row numbers,
//   a modulator before what it moves:
//    0 at     the frame its voice starts           1 f      its frequency, Hz
//    2 slide  nepers a second it glides; phase f (e^kt - 1) / k
//    3 drop 4 kappa  a falling start: g (1 - e^-kappa t) cycles more
//    5 wave   0 sine 1 half 2 abs 3 quarter 4 tri 5 saw 6 square 7 noise 8 pulse (0 or 1)
//    6 mod    the row whose output moves this one's phase, -1 none   7 depth  cycles a unit
//    8 fb     cycles the mean of its own last two outputs moves it
//    9 l 10 r how much of it reaches each side (a modulator 0)
//   11 vib 12 vrate  vibrato, a fraction of f at vrate Hz
//   13 trem 14 trate tremolo, dB down at trate Hz
//   15 am     the row whose output its level is multiplied by, -1 none
//   16 duty   how much of a square's or a pulse's turn is high       17 lvl  a factor over its envelope
//   18 nseg  then nseg segments of 5, t0 (seconds from at) kind a b c, the last begun ruling:
//      kind 0  10^(-(a + b tau) / 20)          kind 1  a + b tau, at least 0
//      kind 2  (1 - e^(-a tau)) 10^(-b tau / 20)
//      kind 3  (1 - e^(-a tau)) (c + (1 - c) 10^(-b tau / 20))
//      before the first segment, or 96 dB down, it is silent
//   an envelope or a glide is stepped a frame at a time by a constant factor, a sine a polynomial:
//   no libm call a frame
#ifndef LOVE_TONES_H
#define LOVE_TONES_H
#include <stdint.h>

#if UINTPTR_MAX == UINT64_MAX
typedef double tn_flo;   // love's flo_t: a double on a 64-bit word, a float on a 32-bit one
#else
typedef float tn_flo;
#endif
enum { tn_row = 49, tn_segs = 6, tn_seg0 = 19 };

void tones_run(tn_flo const *ops, uintptr_t no, tn_flo *st, intptr_t n, int64_t f0, tn_flo rate,
               tn_flo *L, tn_flo *R, tn_flo *sc);
#endif
