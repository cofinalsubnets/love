// src/love/audio/opus.c -- opus (rfc 6716, as rfc 8251 amends it), decoded.
// (opus-state ch)       -> the width of a decoder's state for ch channels (1 or 2): (cask
//                          (opus-state ch)) holds one
// (opus-init b ch gain) -> 0, b laid as a fresh decoder at 48 kHz, its samples scaled by
//                          gain (the head's output gain: dB in Q7.8) | why
// (opus-packet b p f)   -> one packet's samples, interleaved, s16le (f 0) or f32le (f 1); p ""
//                          conceals a lost packet | why: an opus error code, negated
// the decoder is opusdec.c over silk.c and celt.c; this lays it in the cask and nothing allocates
#include "love.h"
#include "bytes.h"
#include "opus.h"
#include <stdint.h>
#include <string.h>

double lm_exp(double);

// the cask: its channels and gain, the decoder, then room for a packet's samples
struct op_head { double gain; int64_t ch; };
static uintptr_t op_dec(void) { return ((uintptr_t) op_size() + 15) & ~(uintptr_t) 15; }
static uintptr_t op_width(int ch) { return sizeof(struct op_head) + op_dec() + 5760 * (uintptr_t) ch * sizeof(float); }

static love_inline struct g *host_opus_state(struct g *g) {
 intptr_t ch = oddp(g->sp[0]) ? getcharm(g->sp[0]) : 0;
 g->sp[0] = ch == 1 || ch == 2 ? putcharm((intptr_t) op_width((int) ch)) : ZeroPoint;
 return g; }
static lvm(lvm_opus_state) { LvmCall(g, host_opus_state) }

static love_inline struct g *host_opus_init(struct g *g) {
 uintptr_t n = 0;
 unsigned char *b = cask_bytes(g->sp[0], &n);
 intptr_t ch = oddp(g->sp[1]) ? getcharm(g->sp[1]) : 0;
 double gain = oddp(g->sp[2]) ? (double) getcharm(g->sp[2]) : 0;
 word r = putcharm(1);
 if (b && (ch == 1 || ch == 2) && gain >= -32768 && gain < 32768 && n == op_width((int) ch)) {
  struct op_head *h = (struct op_head*) b;
  h->ch = ch, h->gain = lm_exp(gain * (2.302585092994046 / 5120));
  r = putcharm(-op_init(b + sizeof *h, (int) ch)); }
 return g->sp[2] = r, g->sp += 2, g; }
static lvm(lvm_opus_init) { LvmCall(g, host_opus_init) }

love_noinline static struct g *host_opus_packet(struct g *g) {
 uintptr_t n = 0;
 unsigned char *b = cask_bytes(g->sp[0], &n);
 struct op_head *h = (struct op_head*) b;
 if (!b || n <= sizeof *h || !strp(g->sp[1]) || !oddp(g->sp[2]) || (h->ch != 1 && h->ch != 2) || n != op_width((int) h->ch))
  return g->sp[2] = putcharm(1), g->sp += 2, g;
 int ch = (int) h->ch;
 struct str *p = str(g->sp[1]);
 intptr_t f = getcharm(g->sp[2]);
 float *pcm = (float*) (b + sizeof *h + op_dec());
 int k = op_decode(b + sizeof *h, p->len ? (const uint8_t*) p->bytes : 0, (int) p->len, pcm, 5760);
 if (k < 0) return g->sp[2] = putcharm(-k), g->sp += 2, g;
 uintptr_t m = (uintptr_t) k * (uintptr_t) ch, on = m * (f ? 4u : 2u);
 if (!ok(g = have(g, str_width(on)))) return g;
 struct str *out = ini_str(bump(g, str_width(on)), on);
 b = cask_bytes(g->sp[0], &n);                     // re-read: have may move it
 h = (struct op_head*) b;
 pcm_lay((uint8_t*) out->bytes, (float*) (b + sizeof *h + op_dec()), m, f, h->gain);
 return g->sp[2] = word(out), g->sp += 2, g; }
static lvm(lvm_opus_packet) { LvmCall(g, host_opus_packet) }

LvDef("opus-state", opus_state, 1, "ogg");
LvDef("opus-init", opus_init, 3, "ogg");
LvDef("opus-packet", opus_packet, 3, "ogg");
