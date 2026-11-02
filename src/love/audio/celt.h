// src/love/audio/celt.h -- opus's celt layer: its state, laid in the caller's cask, and its door
#ifndef LOVE_CELT_H
#define LOVE_CELT_H
#include "opus.h"

#define CT_BANDS 21
#define CT_OVERLAP 120
#define CT_HIST 2048                // the synthesis history kept per channel
#define CT_PERIOD 1024              // the longest pitch the loss path reaches back

// what a reset clears (opus's OPUS_RESET_STATE): everything that carries from frame to frame
struct ct_live {
 uint32_t rng;                      // the range coder's last state, the noise seed
 int lost, pitch;                   // frames concealed in a row, the pitch they repeat
 int pf_t, pf_t0, pf_k, pf_k0;      // the post-filter's period and tapset, now and before
 float pf_g, pf_g0;                 // ..and its gain
 float emph[2];                     // the de-emphasis memory
 float mem[2][CT_HIST + CT_OVERLAP];    // per channel: output history, then the mdct's overlap
 float lpc[2][24];                  // the loss path's predictor
 float e[2 * CT_BANDS];             // the band energies, log2
 float le[2 * CT_BANDS], le2[2 * CT_BANDS], bg[2 * CT_BANDS];   // the last two, the floor
};

struct celt {
 int ch, sch;                       // output channels, the stream's
 int start, end;                    // the coded bands
 struct ct_live s;
 float win[CT_OVERLAP];             // the overlap window
 float trig[481];                   // cos(2 pi i / 1920), the mdct's twiddles
 float tw[480][2];                  // e^(2 pi i k / 480), the fft's
 // work room, kept off the stack
 float x[2 * 960], freq[2 * 960], norm[2 * 8 * 100], lbs[8 * 22], tmp[960 + CT_OVERLAP];
 float f[960], f2[960], exc[CT_PERIOD], ebuf[CT_PERIOD + 2 * CT_OVERLAP], pbuf[CT_HIST / 2];
};

void ct_init(struct celt *c, int ch);     // a fresh decoder of ch output channels
void ct_reset(struct celt *c);            // its frame-to-frame state cleared
// one frame of n samples (120, 240, 480 or 960) into pcm, interleaved c->ch wide, full
// scale 1; p of len <= 1 conceals. d continues a range decoder the caller began (a hybrid
// frame's), else () and one is begun on p. -> n | negative: the frame read past its end
int ct_decode(struct celt *c, const uint8_t *p, int len, float *pcm, int n, struct rdec *d);

#endif
