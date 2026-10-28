// src/love/audio/opus.c -- opus (rfc 6716, as rfc 8251 amends it), decoded.
// (opus-state ch)       -> the width of a decoder's state for ch channels (1 or 2): (cask
//                          (opus-state ch)) holds one
// (opus-init b ch gain) -> 0, b laid as a fresh decoder at 48 kHz, its samples scaled by
//                          gain (the head's output gain: dB in Q7.8) | why
// (opus-packet b p f)   -> one packet's samples, interleaved, s16le (f 0) or f32le (f 1); p ""
//                          conceals a lost packet | why: an opus error code, negated
// the rfc's reference decoder, float build, decode path only (opus/, its notice opus/COPYING)
// as one unit, allocating nothing: its pseudostack is the cask's tail, pointed at for one call
// (the one mutable global)
#include "love.h"
#include "bytes.h"
#include <stdint.h>
#include <string.h>
#include <math.h>
#include <stdlib.h>

double lm_cos(double), lm_sqrt(double), lm_exp(double);
#define cos(x) lm_cos(x)
#define sqrt(x) lm_sqrt(x)
#define exp(x) lm_exp(x)

#define restrict
// no heap: nothing on the decoder's path asks, and the scratch is laid per call below
static inline void *opus_alloc_scratch(size_t n) { (void) n; return NULL; }

#include "opus/celt.c"
#include "opus/silk.c"
#include "opus/decoder.c"

// the cask: the decoder, its gain (a double), its scratch, then room for a packet's samples
#define OP_SCRATCH (16 + GLOBAL_STACK_SIZE + 64 + 5760 * 2 * sizeof(float))
static uintptr_t op_dec_size(int ch) { return ((uintptr_t) opus_decoder_get_size(ch) + 15) & ~(uintptr_t) 15; }

static love_inline struct g *host_opus_state(struct g *g) {
 intptr_t ch = oddp(g->sp[0]) ? getcharm(g->sp[0]) : 0;
 g->sp[0] = ch == 1 || ch == 2 ? putcharm((intptr_t) (op_dec_size((int) ch) + OP_SCRATCH)) : ZeroPoint;
 return g; }
static lvm(lvm_opus_state) { LvmCall(g, host_opus_state) }

static love_inline struct g *host_opus_init(struct g *g) {
 uintptr_t n = 0;
 unsigned char *b = cask_bytes(g->sp[0], &n);
 intptr_t ch = oddp(g->sp[1]) ? getcharm(g->sp[1]) : 0;
 double gain = oddp(g->sp[2]) ? (double) getcharm(g->sp[2]) : 0;
 word r = putcharm(-OPUS_BAD_ARG);
 if (b && (ch == 1 || ch == 2) && gain >= -32768 && gain < 32768 && n == op_dec_size((int) ch) + OP_SCRATCH)
  r = putcharm(-opus_decoder_init((OpusDecoder*) b, 48000, (int) ch)),
  *(double*) (b + op_dec_size((int) ch)) = lm_exp(gain * (2.302585092994046 / 5120));
 return g->sp[2] = r, g->sp += 2, g; }
static lvm(lvm_opus_init) { LvmCall(g, host_opus_init) }

love_noinline static struct g *host_opus_packet(struct g *g) {
 uintptr_t n = 0;
 unsigned char *b = cask_bytes(g->sp[0], &n);
 if (!b || n <= OP_SCRATCH || !strp(g->sp[1]) || !oddp(g->sp[2]))
  return g->sp[2] = putcharm(-OPUS_BAD_ARG), g->sp += 2, g;
 OpusDecoder *d = (OpusDecoder*) b;
 int ch = d->channels;
 if ((ch != 1 && ch != 2) || n != op_dec_size(ch) + OP_SCRATCH) return g->sp[2] = putcharm(-OPUS_BAD_ARG), g->sp += 2, g;
 struct str *p = str(g->sp[1]);
 intptr_t f = getcharm(g->sp[2]);
 // the samples land past the scratch, in the cask's last 45 KiB
 float *pcm = (float*) (b + n - 5760 * 2 * sizeof(float));
 global_stack = (char*) b + op_dec_size(ch) + 16;
 int k = opus_decode_float(d, p->len ? (unsigned char const*) p->bytes : NULL, (opus_int32) p->len, pcm, 5760, 0);
 global_stack = 0;
 if (k < 0) return g->sp[2] = putcharm(-k), g->sp += 2, g;
 uintptr_t m = (uintptr_t) k * (uintptr_t) ch, on = m * (f ? 4u : 2u);
 if (!ok(g = have(g, str_width(on)))) return g;
 struct str *out = ini_str(bump(g, str_width(on)), on);
 b = cask_bytes(g->sp[0], &n);                     // re-read: have may move it
 pcm_lay((uint8_t*) out->bytes, (float*) (b + n - 5760 * 2 * sizeof(float)), m, f, *(double*) (b + op_dec_size(ch)));
 return g->sp[2] = word(out), g->sp += 2, g; }
static lvm(lvm_opus_packet) { LvmCall(g, host_opus_packet) }

LvDef("opus-state", opus_state, 1, "ogg");
LvDef("opus-init", opus_init, 3, "ogg");
LvDef("opus-packet", opus_packet, 3, "ogg");
