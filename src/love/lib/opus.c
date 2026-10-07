// src/love/lib/opus.c -- opus (rfc 6716, as rfc 8251 amends it), decoded.
// (opus-state ch)       -> the width of a decoder's state for ch channels (1 or 2): (cask
//                          (opus-state ch)) holds one
// (opus-init b ch gain) -> 0, b laid as a fresh decoder at 48 kHz, its samples scaled by
//                          gain (the head's output gain: dB in Q7.8) | why
// (opus-packet b p f)   -> one packet's samples, interleaved, s16le (f 0) or f32le (f 1); p ""
//                          conceals a lost packet | why: an opus error code, negated
// the decoder is the rfc's reference (its float build), in src/love/lib/opus/ with its
// notices, built here as one unit. it allocates nothing: the state is the caller's cask, and
// its scratch -- the reference's pseudostack -- the tail of that cask, pointed at for the
// length of each call and let go after (the one mutable global, a pointer, and a decode is
// never interrupted). its maths ride the tree's own (lm.c).
#include "love.h"
#include "bytes.h"
#include <stdint.h>
#include <string.h>
#include <math.h>
#include <stdlib.h>

double lm_sin(double), lm_cos(double), lm_atan2(double, double), lm_sqrt(double),
       lm_exp(double), lm_log(double), lm_pow(double, double);
static double op_floor(double x) {
 if (x != x || x >= 4503599627370496.0 || x <= -4503599627370496.0) return x;
 double t = (double) (long long) x;
 return t > x ? t - 1 : t; }
static long op_lrint(double x) {             // to nearest, ties to even
 double f = op_floor(x), d = x - f;
 long r = (long) f;
 return d > 0.5 || (d == 0.5 && (r & 1)) ? r + 1 : r; }
#define sin(x) lm_sin(x)
#define cos(x) lm_cos(x)
#define sqrt(x) lm_sqrt(x)
#define exp(x) lm_exp(x)
#define log(x) lm_log(x)
#define log2(x) (lm_log(x) * 1.4426950408889634074)
#define atan2(y, x) lm_atan2(y, x)
#define atan(x) lm_atan2(x, 1.0)
#define floor(x) op_floor(x)
#define lrint(x) op_lrint(x)
#define lrintf(x) op_lrint(x)

#define OPUS_BUILD 1
#define HAVE_LRINTF 1                  // float2int rounds to nearest, as the reference does
#define CELT_C
#define NONTHREADSAFE_PSEUDOSTACK 1
#define restrict
// no heap: nothing on the decoder's path asks, and the scratch is laid per call below
#define OVERRIDE_OPUS_ALLOC
#define OVERRIDE_OPUS_FREE
#define OVERRIDE_OPUS_ALLOC_SCRATCH
static inline void *opus_alloc(size_t n) { (void) n; return NULL; }
static inline void opus_free(void *p) { (void) p; }
static inline void *opus_alloc_scratch(size_t n) { (void) n; return NULL; }

#include "opus/celt/bands.c"
#include "opus/celt/celt.c"
#include "opus/celt/celt_lpc.c"
#include "opus/celt/cwrs.c"
#include "opus/celt/entcode.c"
#include "opus/celt/entdec.c"
#include "opus/celt/entenc.c"
#include "opus/celt/kiss_fft.c"
#include "opus/celt/laplace.c"
#include "opus/celt/mathops.c"
#include "opus/celt/mdct.c"
#include "opus/celt/modes.c"
#include "opus/celt/pitch.c"
#include "opus/celt/quant_bands.c"
#include "opus/celt/rate.c"
#include "opus/celt/vq.c"
#undef MAX_PULSES                      // celt's, before silk's own
#include "opus/silk/CNG.c"
#include "opus/silk/LPC_analysis_filter.c"
#include "opus/silk/LPC_inv_pred_gain.c"
#undef QA                              // LPC_inv_pred_gain.c's, before NLSF2A.c's own
#include "opus/silk/NLSF2A.c"
#include "opus/silk/NLSF_VQ_weights_laroia.c"
#include "opus/silk/NLSF_decode.c"
#include "opus/silk/NLSF_stabilize.c"
#include "opus/silk/NLSF_unpack.c"
#include "opus/silk/PLC.c"
#include "opus/silk/bwexpander.c"
#include "opus/silk/bwexpander_32.c"
#include "opus/silk/code_signs.c"
#include "opus/silk/dec_API.c"
#include "opus/silk/decode_core.c"
#include "opus/silk/decode_frame.c"
#include "opus/silk/decode_indices.c"
#include "opus/silk/decode_parameters.c"
#include "opus/silk/decode_pitch.c"
#include "opus/silk/decode_pulses.c"
#include "opus/silk/decoder_set_fs.c"
#include "opus/silk/gain_quant.c"
#include "opus/silk/init_decoder.c"
#include "opus/silk/lin2log.c"
#include "opus/silk/log2lin.c"
#include "opus/silk/pitch_est_tables.c"
#include "opus/silk/resampler.c"
#include "opus/silk/resampler_private_AR2.c"
#include "opus/silk/resampler_private_IIR_FIR.c"
#include "opus/silk/resampler_private_down_FIR.c"
#include "opus/silk/resampler_private_up2_HQ.c"
#include "opus/silk/resampler_rom.c"
#include "opus/silk/shell_coder.c"
#include "opus/silk/sort.c"
#include "opus/silk/stereo_MS_to_LR.c"
#include "opus/silk/stereo_decode_pred.c"
#include "opus/silk/sum_sqr_shift.c"
#include "opus/silk/table_LSF_cos.c"
#include "opus/silk/tables_LTP.c"
#include "opus/silk/tables_NLSF_CB_NB_MB.c"
#include "opus/silk/tables_NLSF_CB_WB.c"
#include "opus/silk/tables_gain.c"
#include "opus/silk/tables_other.c"
#include "opus/silk/tables_pitch_lag.c"
#include "opus/silk/tables_pulses_per_block.c"
#include "opus/src/opus_decoder.c"

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

static union u const
  nif_opus_state[] = {{lvm_opus_state}, {lvm_ret0}},
  nif_opus_init[] = {{lvm_cur}, {.x = putcharm(3)}, {lvm_opus_init}, {lvm_ret0}},
  nif_opus_packet[] = {{lvm_cur}, {.x = putcharm(3)}, {lvm_opus_packet}, {lvm_ret0}};
LvNif("opus-state", nif_opus_state, NULL);
LvNif("opus-init", nif_opus_init, NULL);
LvNif("opus-packet", nif_opus_packet, NULL);
