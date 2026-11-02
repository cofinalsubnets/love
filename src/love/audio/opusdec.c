// src/love/audio/opusdec.c -- opus packets (rfc 6716 3, 4.5) into 48 kHz float samples: the toc
// and frame packing, then each frame through silk, celt or both, with the redundant celt frames
// and cross-fades that smooth a switch between them
#include "opus.h"
#include "silk.h"
#include "celt.h"
#include <string.h>

enum { OP_SILK = 1, OP_HYBRID, OP_CELT };
enum { OP_NB = 1, OP_MB, OP_WB, OP_SWB, OP_FB };

struct opd {
 int ch;                            // output channels
 int sch, bw, mode, fsize;          // the packet's: coded channels, bandwidth, mode, samples a frame
 int pmode, predund;                // the last frame's mode, and whether it ended on a redundant celt frame
 uint32_t final;                    // the range coder's last state, as the vectors check it
 struct silk sk;
 struct celt ct;
 int16_t spcm[2880 * 2];            // work room: a frame's silk samples
 float trans[240 * 2], red[240 * 2];    // ..the transition's, and a redundant frame's
};

int op_size(void) { return (int) sizeof(struct opd); }
uint32_t op_final(const void *b) { return ((const struct opd*) b)->final; }

int op_init(void *b, int ch) {
 struct opd *o = b;
 if (ch != 1 && ch != 2) return -1;
 memset(o, 0, sizeof *o);
 o->ch = o->sch = ch, o->fsize = 120;
 sk_reset(&o->sk);
 ct_init(&o->ct, ch);
 return 0; }

// a cross-fade from a to b over the window's rise, squared
static void op_fade(const float *a, const float *b, float *out, int n, int ch, const float *win) {
 for (int k = 0; k < ch; k++)
  for (int i = 0; i < n; i++) {
   float w = win[i] * win[i];
   out[i * ch + k] = w * b[i * ch + k] + (1.f - w) * a[i * ch + k]; } }

// one frame of len bytes (len <= 1 a loss) into pcm, at most n samples a channel -> samples | -why
static int op_frame(struct opd *o, const uint8_t *p, int len, float *pcm, int n) {
 struct celt *ct = &o->ct;
 int ch = o->ch, mode, size, transition = 0, redund = 0, rbytes = 0, c2s = 0, start = 0;
 uint32_t rrng = 0;
 struct rdec d;
 if (n < 120) return -2;
 if (len <= 1) p = 0, n = n < o->fsize ? n : o->fsize;
 if (p) size = o->fsize, mode = o->mode, rd_init(&d, p, (uint32_t) len);
 else {
  size = n;
  if (o->pmode == 0) { memset(pcm, 0, sizeof(float) * (unsigned) (size * ch)); return size; }
  mode = o->pmode; }
 if (!p && n > 960 && mode != OP_SILK) {            // a long loss, 20 ms at a time
  for (int done = 0; done < n; done += 960, pcm += 960 * ch)
   if (op_frame(o, 0, 0, pcm, 960) != 960) return -3;
  return n; }
 if (p && o->pmode > 0 && ((mode == OP_CELT && o->pmode != OP_CELT && !o->predund) || (mode != OP_CELT && o->pmode == OP_CELT))) {
  transition = 1;
  if (mode == OP_CELT) op_frame(o, 0, 0, o->trans, size < 240 ? size : 240); }
 if (size > n) return -1;
 n = size;
 if (mode != OP_CELT) {
  int16_t *sp = o->spcm;
  int khz = mode == OP_HYBRID || o->bw >= OP_WB ? 16 : o->bw == OP_MB ? 12 : 8, ms = 1000 * size / 48000;
  if (o->pmode == OP_CELT) sk_reset(&o->sk);
  if (ms < 10) ms = 10;
  for (int done = 0, k; done < n; done += k, sp += k * ch)
   if (sk_decode(&o->sk, &d, !p, done == 0, khz, o->sch, ch, ms, sp, &k)) {
    if (!p) { k = n; memset(sp, 0, sizeof(int16_t) * (unsigned) (n * ch)); }
    else return -4; } }
 if (p && mode != OP_CELT && rd_tell(&d) + 17 + 20 * (o->mode == OP_HYBRID) <= 8 * len) {
  redund = mode == OP_HYBRID ? rd_logp(&d, 12) : 1;
  if (redund) {
   c2s = rd_logp(&d, 1);
   rbytes = mode == OP_HYBRID ? (int) rd_uint(&d, 256) + 2 : len - ((rd_tell(&d) + 7) >> 3);
   len -= rbytes;
   if (len * 8 < rd_tell(&d)) len = rbytes = redund = 0;
   d.len -= (uint32_t) rbytes; } }
 if (mode != OP_CELT) start = 17;
 ct->end = o->bw == OP_NB ? 13 : o->bw <= OP_WB ? 17 : o->bw == OP_SWB ? 19 : 21;
 ct->sch = o->sch;
 if (redund) transition = 0;
 if (transition && mode != OP_CELT) op_frame(o, 0, 0, o->trans, size < 240 ? size : 240);
 if (redund && c2s) {                               // the celt frame that leads into this silk one
  ct->start = 0;
  ct_decode(ct, p + len, rbytes, o->red, 240, 0);
  rrng = ct->s.rng; }
 ct->start = start;
 int cret = 0;
 if (mode != OP_SILK) {
  if (mode != o->pmode && o->pmode > 0 && !o->predund) ct_reset(ct);
  cret = ct_decode(ct, p, len, pcm, n < 960 ? n : 960, p ? &d : 0); }
 else {
  static const uint8_t quiet[2] = {255, 255};
  memset(pcm, 0, sizeof(float) * (unsigned) (n * ch));
  if (o->pmode == OP_HYBRID && !(redund && c2s && o->predund)) {   // let the last celt frame ring out
   ct->start = 0;
   ct_decode(ct, quiet, 2, pcm, 120, 0); } }
 if (mode != OP_CELT)
  for (int i = 0; i < n * ch; i++) pcm[i] = pcm[i] + (float) ((1. / 32768.) * o->spcm[i]);
 const float *win = ct->win;
 if (redund && !c2s) {                              // ..and the one this silk frame fades out to
  ct_reset(ct);
  ct->start = 0;
  ct_decode(ct, p + len, rbytes, o->red, 240, 0);
  rrng = ct->s.rng;
  op_fade(pcm + ch * (n - 120), o->red + ch * 120, pcm + ch * (n - 120), 120, ch, win); }
 if (redund && c2s) {
  memcpy(pcm, o->red, sizeof(float) * (unsigned) (120 * ch));
  op_fade(o->red + ch * 120, pcm + ch * 120, pcm + ch * 120, 120, ch, win); }
 if (transition) {
  if (size >= 240) {
   memcpy(pcm, o->trans, sizeof(float) * (unsigned) (120 * ch));
   op_fade(o->trans + ch * 120, pcm + ch * 120, pcm + ch * 120, 120, ch, win); }
  else op_fade(o->trans, pcm, pcm, 120, ch, win); }
 o->final = len <= 1 ? 0 : d.rng ^ rrng;
 o->pmode = mode, o->predund = redund && !c2s;
 return cret < 0 ? cret : size; }

// the frame sizes of a packet's frames (rfc 6716 3.2) -> how many | -why
static int op_size1(const uint8_t *p, int len, int16_t *s) {
 *s = -1;
 if (len < 1) return -1;
 if (p[0] < 252) { *s = p[0]; return 1; }
 if (len < 2) return -1;
 *s = (int16_t) (4 * p[1] + p[0]);
 return 2; }

static int op_frames(const uint8_t *p, int len, int fsize, int16_t *size, int *off) {
 const uint8_t *p0 = p;
 int toc = *p++, count, last;
 len--, last = len;
 switch (toc & 3) {
  case 0: count = 1; break;
  case 1:                                           // two of one size
   count = 2;
   if (len & 1) return -4;
   size[0] = (int16_t) (last = len / 2);
   break;
  case 2: {                                         // two, the first's size given
   count = 2;
   int b = op_size1(p, len, size);
   len -= b;
   if (size[0] < 0 || size[0] > len) return -4;
   p += b, last = len - size[0];
   break; }
  default: {                                        // up to 48, padded, sized or all one size
   if (len < 1) return -4;
   int c = *p++;
   count = c & 63, len--;
   if (count <= 0 || fsize * count > 5760) return -4;
   if (c & 64)
    for (int q = 255; q == 255;) {
     if (len <= 0) return -4;
     q = *p++, len--, len -= q == 255 ? 254 : q; }
   if (len < 0) return -4;
   if (c & 128) {
    last = len;
    for (int i = 0; i < count - 1; i++) {
     int b = op_size1(p, len, size + i);
     len -= b;
     if (size[i] < 0 || size[i] > len) return -4;
     p += b, last -= b + size[i]; }
    if (last < 0) return -4; }
   else {
    last = len / count;
    if (last * count != len) return -4;
    for (int i = 0; i < count - 1; i++) size[i] = (int16_t) last; } } }
 if (last > 1275) return -4;
 size[count - 1] = (int16_t) last;
 *off = (int) (p - p0);
 return count; }

int op_decode(void *b, const uint8_t *p, int len, float *pcm, int n) {
 struct opd *o = b;
 if (len == 0 || !p) return op_frame(o, 0, 0, pcm, n);
 if (len < 0) return -1;
 int toc = p[0], off, done = 0;
 int16_t size[48];
 o->mode = toc & 128 ? OP_CELT : (toc & 96) == 96 ? OP_HYBRID : OP_SILK;
 o->bw = toc & 128 ? (((toc >> 5) & 3) == 0 ? OP_NB : OP_MB + ((toc >> 5) & 3))
       : (toc & 96) == 96 ? (toc & 16 ? OP_FB : OP_SWB) : OP_NB + ((toc >> 5) & 3);
 int z = (toc >> 3) & 3;
 o->fsize = toc & 128 ? (48000 << z) / 400 : (toc & 96) == 96 ? (toc & 8 ? 960 : 480) : z == 3 ? 2880 : (48000 << z) / 100;
 o->sch = toc & 4 ? 2 : 1;
 int count = op_frames(p, len, o->fsize, size, &off);
 if (count < 0) return count;
 if (count * o->fsize > n) return -2;
 p += off;
 for (int i = 0; i < count; i++) {
  int k = op_frame(o, p, size[i], pcm, n - done);
  if (k < 0) return k;
  p += size[i], pcm += k * o->ch, done += k; }
 return done; }
