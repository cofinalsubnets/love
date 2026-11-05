// src/love/audio/celt.c -- opus's celt layer decoded (rfc 6716 4.3, whose spec is the reference
// decoder's float build): band energies, the bit allocation, pvq band shapes with their folding
// and splits, the inverse mdct, the comb post-filter, de-emphasis, and the loss path's pitch
// repetition. one mode: 48 kHz, 2.5 to 20 ms frames, 21 bands.
#include "celt.h"
#include <string.h>

double lm_sin(double), lm_cos(double), lm_sqrt(double), lm_exp(double);
#define CT_PI 3.141592653f                          // the reference's float pi, which its math rounds by
#define CT_PID 3.14159265358979323846

static float ct_sqrt(float x) { return (float) lm_sqrt(x); }
static float ct_exp2(float x) { return (float) lm_exp(0.6931471805599453094 * x); }
static float ct_cosn(float x) { return (float) lm_cos((.5f * CT_PI) * x); }      // cos(pi x / 2)
static int ct_min(int a, int b) { return a < b ? a : b; }
static int ct_max(int a, int b) { return a > b ? a : b; }
static float ct_fmin(float a, float b) { return a < b ? a : b; }
static float ct_fmax(float a, float b) { return a > b ? a : b; }

// the mode: band edges in 2.5 ms bins, the allocation rows (1/32 bit a bin), log2 of each
// band's width (1/8 bit), the mean energies coarse energy predicts around
static const int16_t ct_eb[CT_BANDS + 1] = {0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 12, 14, 16, 20, 24, 28, 34, 40, 48, 60, 78, 100};
static const uint8_t ct_alloc[11][CT_BANDS] = {
 {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
 {90, 80, 75, 69, 63, 56, 49, 40, 34, 29, 20, 18, 10, 0, 0, 0, 0, 0, 0, 0, 0},
 {110, 100, 90, 84, 78, 71, 65, 58, 51, 45, 39, 32, 26, 20, 12, 0, 0, 0, 0, 0, 0},
 {118, 110, 103, 93, 86, 80, 75, 70, 65, 59, 53, 47, 40, 31, 23, 15, 4, 0, 0, 0, 0},
 {126, 119, 112, 104, 95, 89, 83, 78, 72, 66, 60, 54, 47, 39, 32, 25, 17, 12, 1, 0, 0},
 {134, 127, 120, 114, 103, 97, 91, 85, 78, 72, 66, 60, 54, 47, 41, 35, 29, 23, 16, 10, 1},
 {144, 137, 130, 124, 113, 107, 101, 95, 88, 82, 76, 70, 64, 57, 51, 45, 39, 33, 26, 15, 1},
 {152, 145, 138, 132, 123, 117, 111, 105, 98, 92, 86, 80, 74, 67, 61, 55, 49, 43, 36, 20, 1},
 {162, 155, 148, 142, 133, 127, 121, 115, 108, 102, 96, 90, 84, 77, 71, 65, 59, 53, 46, 30, 1},
 {172, 165, 158, 152, 143, 137, 131, 125, 118, 112, 106, 100, 94, 87, 81, 75, 69, 63, 56, 45, 20},
 {200, 200, 200, 200, 200, 200, 200, 200, 198, 193, 188, 183, 178, 173, 168, 163, 158, 153, 148, 129, 104}};
static const int16_t ct_logn[CT_BANDS] = {0, 0, 0, 0, 0, 0, 0, 0, 8, 8, 8, 8, 16, 16, 16, 21, 21, 24, 29, 34, 36};
static const float ct_means[CT_BANDS] = {
 6.4375f, 6.25f, 5.75f, 5.3125f, 5.0625f, 4.8125f, 4.5f, 4.375f, 4.875f, 4.6875f, 4.5625f,
 4.4375f, 4.875f, 4.625f, 4.3125f, 4.5f, 4.375f, 4.625f, 4.75f, 4.4375f, 3.75f};

// the pulse cache: for band i at LM, from ct_cbits + ct_cidx[(LM + 1) * 21 + i], the count of
// pseudo-pulse levels, then the eighth bits each costs less one; ct_caps the most a band may take
static const int16_t ct_cidx[105] = {
 -1, -1, -1, -1, -1, -1, -1, -1, 0, 0, 0, 0, 41, 41, 41, 82, 82, 123, 164, 200, 222,
 0, 0, 0, 0, 0, 0, 0, 0, 41, 41, 41, 41, 123, 123, 123, 164, 164, 240, 266, 283, 295,
 41, 41, 41, 41, 41, 41, 41, 41, 123, 123, 123, 123, 240, 240, 240, 266, 266, 305, 318, 328, 336,
 123, 123, 123, 123, 123, 123, 123, 123, 240, 240, 240, 240, 305, 305, 305, 318, 318, 343, 351, 358, 364,
 240, 240, 240, 240, 240, 240, 240, 240, 305, 305, 305, 305, 343, 343, 343, 351, 351, 370, 376, 382, 387};
static const uint8_t ct_cbits[392] = {
 40, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
 40, 15, 23, 28, 31, 34, 36, 38, 39, 41, 42, 43, 44, 45, 46, 47, 47, 49, 50, 51, 52, 53, 54, 55, 55, 57, 58, 59, 60, 61, 62,
 63, 63, 65, 66, 67, 68, 69, 70, 71, 71,
 40, 20, 33, 41, 48, 53, 57, 61, 64, 66, 69, 71, 73, 75, 76, 78, 80, 82, 85, 87, 89, 91, 92, 94, 96, 98, 101, 103, 105, 107,
 108, 110, 112, 114, 117, 119, 121, 123, 124, 126, 128,
 40, 23, 39, 51, 60, 67, 73, 79, 83, 87, 91, 94, 97, 100, 102, 105, 107, 111, 115, 118, 121, 124, 126, 129, 131, 135, 139,
 142, 145, 148, 150, 153, 155, 159, 163, 166, 169, 172, 174, 177, 179,
 35, 28, 49, 65, 78, 89, 99, 107, 114, 120, 126, 132, 136, 141, 145, 149, 153, 159, 165, 171, 176, 180, 185, 189, 192, 199,
 205, 211, 216, 220, 225, 229, 232, 239, 245, 251,
 21, 33, 58, 79, 97, 112, 125, 137, 148, 157, 166, 174, 182, 189, 195, 201, 207, 217, 227, 235, 243, 251,
 17, 35, 63, 86, 106, 123, 139, 152, 165, 177, 187, 197, 206, 214, 222, 230, 237, 250,
 25, 31, 55, 75, 91, 105, 117, 128, 138, 146, 154, 161, 168, 174, 180, 185, 190, 200, 208, 215, 222, 229, 235, 240, 245, 255,
 16, 36, 65, 89, 110, 128, 144, 159, 173, 185, 196, 207, 217, 226, 234, 242, 250,
 11, 41, 74, 103, 128, 151, 172, 191, 209, 225, 241, 255,
 9, 43, 79, 110, 138, 163, 186, 207, 227, 246,
 12, 39, 71, 99, 123, 144, 164, 182, 198, 214, 228, 241, 253,
 9, 44, 81, 113, 142, 168, 192, 214, 235, 255,
 7, 49, 90, 127, 160, 191, 220, 247,
 6, 51, 95, 134, 170, 203, 234,
 7, 47, 87, 123, 155, 184, 212, 237,
 6, 52, 97, 137, 174, 208, 240,
 5, 57, 106, 151, 192, 231,
 5, 59, 111, 158, 202, 243,
 5, 55, 103, 147, 187, 224,
 5, 60, 113, 161, 206, 248,
 4, 65, 122, 175, 224,
 4, 67, 127, 182, 234};
static const uint8_t ct_caps[168] = {
 224, 224, 224, 224, 224, 224, 224, 224, 160, 160, 160, 160, 185, 185, 185, 178, 178, 168, 134, 61, 37,
 224, 224, 224, 224, 224, 224, 224, 224, 240, 240, 240, 240, 207, 207, 207, 198, 198, 183, 144, 66, 40,
 160, 160, 160, 160, 160, 160, 160, 160, 185, 185, 185, 185, 193, 193, 193, 183, 183, 172, 138, 64, 38,
 240, 240, 240, 240, 240, 240, 240, 240, 207, 207, 207, 207, 204, 204, 204, 193, 193, 180, 143, 66, 40,
 185, 185, 185, 185, 185, 185, 185, 185, 193, 193, 193, 193, 193, 193, 193, 183, 183, 172, 138, 65, 39,
 207, 207, 207, 207, 207, 207, 207, 207, 204, 204, 204, 204, 201, 201, 201, 188, 188, 176, 141, 66, 40,
 193, 193, 193, 193, 193, 193, 193, 193, 193, 193, 193, 193, 194, 194, 194, 184, 184, 173, 139, 65, 39,
 204, 204, 204, 204, 204, 204, 204, 204, 201, 201, 201, 201, 198, 198, 198, 187, 187, 175, 140, 66, 40};

// coarse energy's laplace model: [LM][intra] a pair a band, the zero's frequency and the decay
static const uint8_t ct_eprob[4][2][42] = {
 {{72, 127, 65, 129, 66, 128, 65, 128, 64, 128, 62, 128, 64, 128, 64, 128, 92, 78, 92, 79, 92, 78, 90, 79, 116, 41, 115, 40,
   114, 40, 132, 26, 132, 26, 145, 17, 161, 12, 176, 10, 177, 11},
  {24, 179, 48, 138, 54, 135, 54, 132, 53, 134, 56, 133, 55, 132, 55, 132, 61, 114, 70, 96, 74, 88, 75, 88, 87, 74, 89, 66,
   91, 67, 100, 59, 108, 50, 120, 40, 122, 37, 97, 43, 78, 50}},
 {{83, 78, 84, 81, 88, 75, 86, 74, 87, 71, 90, 73, 93, 74, 93, 74, 109, 40, 114, 36, 117, 34, 117, 34, 143, 17, 145, 18,
   146, 19, 162, 12, 165, 10, 178, 7, 189, 6, 190, 8, 177, 9},
  {23, 178, 54, 115, 63, 102, 66, 98, 69, 99, 74, 89, 71, 91, 73, 91, 78, 89, 86, 80, 92, 66, 93, 64, 102, 59, 103, 60,
   104, 60, 117, 52, 123, 44, 138, 35, 133, 31, 97, 38, 77, 45}},
 {{61, 90, 93, 60, 105, 42, 107, 41, 110, 45, 116, 38, 113, 38, 112, 38, 124, 26, 132, 27, 136, 19, 140, 20, 155, 14, 159, 16,
   158, 18, 170, 13, 177, 10, 187, 8, 192, 6, 175, 9, 159, 10},
  {21, 178, 59, 110, 71, 86, 75, 85, 84, 83, 91, 66, 88, 73, 87, 72, 92, 75, 98, 72, 105, 58, 107, 54, 115, 52, 114, 55,
   112, 56, 129, 51, 132, 40, 150, 33, 140, 29, 98, 35, 77, 42}},
 {{42, 121, 96, 66, 108, 43, 111, 40, 117, 44, 123, 32, 120, 36, 119, 33, 127, 33, 134, 34, 139, 21, 147, 23, 152, 20, 158, 25,
   154, 26, 166, 21, 173, 16, 184, 13, 184, 10, 150, 13, 139, 15},
  {22, 178, 63, 114, 74, 82, 84, 83, 92, 82, 103, 62, 96, 72, 96, 67, 101, 73, 107, 72, 113, 55, 118, 52, 125, 52, 118, 52,
   117, 55, 135, 49, 137, 39, 157, 32, 145, 29, 97, 33, 77, 40}}};
static const float ct_pred[4] = {29440 / 32768.f, 26112 / 32768.f, 21248 / 32768.f, 16384 / 32768.f};
static const float ct_beta[4] = {30147 / 32768.f, 22282 / 32768.f, 12124 / 32768.f, 6554 / 32768.f};
#define CT_BETA_INTRA (4915 / 32768.f)

static const uint8_t ct_small_icdf[3] = {2, 1, 0}, ct_trim_icdf[11] = {126, 124, 119, 109, 87, 41, 19, 9, 4, 2, 0};
static const uint8_t ct_spread_icdf[4] = {25, 23, 2, 0}, ct_tapset_icdf[3] = {2, 1, 0};
static const int8_t ct_tfsel[4][8] = {
 {0, -1, 0, -1, 0, -1, 0, -1}, {0, -1, 0, -2, 1, 0, 1, -1}, {0, -2, 0, -3, 2, 0, 1, -1}, {0, -2, 0, -3, 3, 0, 1, -1}};
static const uint8_t ct_log2frac[24] = {0, 8, 13, 16, 19, 21, 23, 24, 26, 27, 28, 29, 30, 31, 32, 32, 33, 34, 34, 35, 36, 36, 37, 37};

#define CT_MAXFINE 8
#define CT_NONE 0
#define CT_AGGRESSIVE 3

static uint32_t ct_lcg(uint32_t s) { return 1664525 * s + 1013904223; }

void ct_reset(struct celt *c) {
 memset(&c->s, 0, sizeof c->s);
 for (int i = 0; i < 2 * CT_BANDS; i++) c->s.le[i] = c->s.le2[i] = -28.f; }

void ct_init(struct celt *c, int ch) {
 c->ch = c->sch = ch, c->start = 0, c->end = CT_BANDS;
 for (int i = 0; i < CT_OVERLAP; i++) {
  double s = lm_sin(.5 * CT_PID * (i + .5) / CT_OVERLAP);
  c->win[i] = (float) lm_sin(.5 * CT_PID * s * s); }
 for (int i = 0; i <= 480; i++) c->trig[i] = (float) lm_cos(2 * CT_PID * i / 1920);
 for (int k = 0; k < 480; k++) c->tw[k][0] = (float) lm_cos(2 * CT_PID * k / 480), c->tw[k][1] = (float) lm_sin(2 * CT_PID * k / 480);
 ct_reset(c); }

// the cache rows: band i's pseudo-pulse costs at LM
static const uint8_t *ct_cache(int i, int LM) { return ct_cbits + ct_cidx[(LM + 1) * CT_BANDS + i]; }
static int ct_pulses(int q) { return q < 8 ? q : (8 + (q & 7)) << ((q >> 3) - 1); }

// the nearest pseudo-pulse level to bits eighth bits, the lower when halfway
static int ct_bits2q(int i, int LM, int bits) {
 const uint8_t *c = ct_cache(i, LM);
 int lo = 0, hi = c[0];
 bits--;
 for (int k = 0; k < 6; k++) {
  int mid = (lo + hi + 1) >> 1;
  if (c[mid] >= bits) hi = mid; else lo = mid; }
 return bits - (lo == 0 ? -1 : c[lo]) <= c[hi] - bits ? lo : hi; }
static int ct_q2bits(int i, int LM, int q) { return q == 0 ? 0 : ct_cache(i, LM)[q] + 1; }

// coarse energy, the laplace-coded residuals of a two-tap prediction across time and bands
static int ct_laplace(struct rdec *d, unsigned fs, int decay) {
 int v = 0;
 unsigned fm = rd_freqb(d, 15), fl = 0;
 if (fm >= fs) {
  v++, fl = fs;
  fs = ((32768 - 32 - fs) * (unsigned) (16384 - decay) >> 15) + 1;
  while (fs > 1 && fm >= fl + 2 * fs) fs *= 2, fl += fs, fs = ((fs - 2) * (unsigned) decay >> 15) + 1, v++;
  if (fs <= 1) {
   int di = (int) (fm - fl) >> 1;
   v += di, fl += 2 * (unsigned) di; }
  if (fm < fl + fs) v = -v; else fl += fs; }
 rd_take(d, fl, fl + fs < 32768 ? fl + fs : 32768, 32768);
 return v; }

static void ct_coarse(struct celt *c, struct rdec *d, int intra, int C, int LM) {
 const uint8_t *pm = ct_eprob[LM][intra];
 float prev[2] = {0, 0}, coef = intra ? 0 : ct_pred[LM], beta = intra ? CT_BETA_INTRA : ct_beta[LM];
 int budget = (int) d->len * 8;
 for (int i = c->start; i < c->end; i++)
  for (int k = 0; k < C; k++) {
   int q, left = budget - rd_tell(d);
   if (left >= 15) {
    int pi = 2 * ct_min(i, 20);
    q = ct_laplace(d, (unsigned) pm[pi] << 7, pm[pi + 1] << 6); }
   else if (left >= 2) q = rd_icdf(d, ct_small_icdf, 2), q = (q >> 1) ^ -(q & 1);
   else if (left >= 1) q = -rd_logp(d, 1);
   else q = -1;
   float *e = &c->s.e[i + k * CT_BANDS], fq = (float) q;
   *e = ct_fmax(-9.f, *e);
   *e = coef * *e + prev[k] + fq;
   prev[k] = prev[k] + fq - beta * fq; } }

static void ct_fine(struct celt *c, struct rdec *d, const int *fq, int C) {
 for (int i = c->start; i < c->end; i++)
  if (fq[i] > 0)
   for (int k = 0; k < C; k++) {
    int q = (int) rd_raw(d, (unsigned) fq[i]);
    c->s.e[i + k * CT_BANDS] += (q + .5f) * (1 << (14 - fq[i])) * (1.f / 16384) - .5f; } }

// the bits left over, one more fine bit a band, the bands that rounded down first
static void ct_finefin(struct celt *c, struct rdec *d, const int *fq, const int *prio, int left, int C) {
 for (int p = 0; p < 2; p++)
  for (int i = c->start; i < c->end && left >= C; i++) {
   if (fq[i] >= CT_MAXFINE || prio[i] != p) continue;
   for (int k = 0; k < C; k++) {
    int q = (int) rd_raw(d, 1);
    c->s.e[i + k * CT_BANDS] += (q - .5f) * (1 << (14 - fq[i] - 1)) * (1.f / 16384);
    left--; } } }

// log2 energies to amplitudes
static void ct_amps(int start, int end, float *amp, const float *e, int C) {
 for (int k = 0; k < C; k++)
  for (int i = 0; i < CT_BANDS; i++)
   amp[i + k * CT_BANDS] = i < start || i >= end ? 0 : ct_exp2(ct_fmin(32.f, e[i + k * CT_BANDS] + ct_means[i])); }

// the time-frequency resolution change of each band
static void ct_tf(int start, int end, int tr, int *tf, int LM, struct rdec *d) {
 uint32_t budget = d->len * 8, tell = (uint32_t) rd_tell(d);
 int logp = tr ? 2 : 4, rsv = LM > 0 && tell + (uint32_t) logp + 1 <= budget, changed = 0, cur = 0;
 budget -= (uint32_t) rsv;
 for (int i = start; i < end; i++) {
  if (tell + (uint32_t) logp <= budget) cur ^= rd_logp(d, (unsigned) logp), tell = (uint32_t) rd_tell(d), changed |= cur;
  tf[i] = cur, logp = tr ? 4 : 5; }
 int sel = rsv && ct_tfsel[LM][4 * tr + changed] != ct_tfsel[LM][4 * tr + 2 + changed] ? rd_logp(d, 1) : 0;
 for (int i = start; i < end; i++) tf[i] = ct_tfsel[LM][4 * tr + 2 * sel + tf[i]]; }

// the allocation: a search between the static rows, interpolated in sixty-fourths, then the
// bands that skip, intensity and dual stereo, and each band's split between fine energy and shape
struct ct_al { int coded, intensity, dual, balance; int bits[CT_BANDS], fine[CT_BANDS], prio[CT_BANDS]; };

static void ct_interp(const struct celt *c, int skip0, const int *b1, const int *b2, const int *th, const int *cap,
                      int total, int skip_rsv, int is_rsv, int ds_rsv, int C, int LM, struct rdec *d, struct ct_al *a) {
 int start = c->start, end = c->end, floor = C << 3, lo = 0, hi = 64, psum, done, coded;
 for (int s = 0; s < 6; s++) {
  int mid = (lo + hi) >> 1;
  psum = done = 0;
  for (int j = end; j-- > start;) {
   int t = b1[j] + (mid * b2[j] >> 6);
   if (t >= th[j] || done) done = 1, psum += ct_min(t, cap[j]);
   else if (t >= floor) psum += floor; }
  if (psum > total) hi = mid; else lo = mid; }
 psum = done = 0;
 for (int j = end; j-- > start;) {
  int t = b1[j] + (lo * b2[j] >> 6);
  if (t < th[j] && !done) t = t >= floor ? floor : 0; else done = 1;
  t = ct_min(t, cap[j]);
  a->bits[j] = t, psum += t; }
 for (coded = end;; coded--) {                     // drop bands from the top while the encoder says skip
  int j = coded - 1;
  if (j <= skip0) { total += skip_rsv; break; }
  int left = total - psum, per = left / (ct_eb[coded] - ct_eb[start]);
  left -= (ct_eb[coded] - ct_eb[start]) * per;
  int rem = ct_max(left - (ct_eb[j] - ct_eb[start]), 0), bb = a->bits[j] + per * (ct_eb[coded] - ct_eb[j]) + rem;
  if (bb >= ct_max(th[j], floor + 8)) {
   if (rd_logp(d, 1)) break;
   psum += 8, bb -= 8; }
  psum -= a->bits[j] + is_rsv;
  if (is_rsv > 0) is_rsv = ct_log2frac[j - start];
  psum += is_rsv;
  if (bb >= floor) psum += floor, a->bits[j] = floor; else a->bits[j] = 0; }
 a->coded = coded;
 a->intensity = is_rsv > 0 ? start + (int) rd_uint(d, (uint32_t) (coded + 1 - start)) : 0;
 if (a->intensity <= start) total += ds_rsv, ds_rsv = 0;
 a->dual = ds_rsv > 0 ? rd_logp(d, 1) : 0;
 int left = total - psum, per = left / (ct_eb[coded] - ct_eb[start]);
 left -= (ct_eb[coded] - ct_eb[start]) * per;
 for (int j = start; j < coded; j++) a->bits[j] += per * (ct_eb[j + 1] - ct_eb[j]);
 for (int j = start; j < coded; j++) {
  int t = ct_min(left, ct_eb[j + 1] - ct_eb[j]);
  a->bits[j] += t, left -= t; }
 int bal = 0, st = C > 1, j;
 for (j = start; j < coded; j++) {
  int n0 = ct_eb[j + 1] - ct_eb[j], n = n0 << LM, ex;
  a->bits[j] += bal;
  if (n > 1) {
   ex = ct_max(a->bits[j] - cap[j], 0);
   a->bits[j] -= ex;
   int den = C * n + (C == 2 && n > 2 && !a->dual && j < a->intensity), nclogn = den * (ct_logn[j] + (LM << 3));
   int off = (nclogn >> 1) - den * 21;
   if (n == 2) off += den << 3 >> 2;
   if (a->bits[j] + off < den * 2 << 3) off += nclogn >> 2;
   else if (a->bits[j] + off < den * 3 << 3) off += nclogn >> 3;
   a->fine[j] = ct_max(0, (a->bits[j] + off + (den << 2)) / (den << 3));
   if (C * a->fine[j] > a->bits[j] >> 3) a->fine[j] = a->bits[j] >> st >> 3;
   a->fine[j] = ct_min(a->fine[j], CT_MAXFINE);
   a->prio[j] = a->fine[j] * (den << 3) >= a->bits[j] + off;
   a->bits[j] -= C * a->fine[j] << 3; }
  else {
   ex = ct_max(0, a->bits[j] - (C << 3));
   a->bits[j] -= ex, a->fine[j] = 0, a->prio[j] = 1; }
  if (ex > 0) {
   int xf = ct_min(ex >> (st + 3), CT_MAXFINE - a->fine[j]), xb = xf * C << 3;
   a->fine[j] += xf;
   a->prio[j] = xb >= ex - bal;
   ex -= xb; }
  bal = ex; }
 a->balance = bal;
 for (; j < end; j++) a->fine[j] = a->bits[j] >> st >> 3, a->bits[j] = 0, a->prio[j] = a->fine[j] < 1; }

static void ct_allocate(const struct celt *c, const int *boost, const int *cap, int trim, int total, int C, int LM,
                        struct rdec *d, struct ct_al *a) {
 int start = c->start, end = c->end, skip0 = start, is_rsv = 0, ds_rsv = 0;
 int b1[CT_BANDS], b2[CT_BANDS], th[CT_BANDS], toff[CT_BANDS];
 total = ct_max(total, 0);
 int skip_rsv = total >= 8 ? 8 : 0;
 total -= skip_rsv;
 if (C == 2) {
  is_rsv = ct_log2frac[end - start];
  if (is_rsv > total) is_rsv = 0;
  else total -= is_rsv, ds_rsv = total >= 8 ? 8 : 0, total -= ds_rsv; }
 for (int j = start; j < end; j++) {
  int w = ct_eb[j + 1] - ct_eb[j];
  th[j] = ct_max(C << 3, (3 * w << LM << 3) >> 4);
  toff[j] = C * w * (trim - 5 - LM) * (end - j - 1) * (1 << (LM + 3)) >> 6;
  if (w << LM == 1) toff[j] -= C << 3; }
 int lo = 1, hi = 10;
 do {
  int done = 0, psum = 0, mid = (lo + hi) >> 1;
  for (int j = end; j-- > start;) {
   int b = C * (ct_eb[j + 1] - ct_eb[j]) * ct_alloc[mid][j] << LM >> 2;
   if (b > 0) b = ct_max(0, b + toff[j]);
   b += boost[j];
   if (b >= th[j] || done) done = 1, psum += ct_min(b, cap[j]);
   else if (b >= C << 3) psum += C << 3; }
  if (psum > total) hi = mid - 1; else lo = mid + 1;
 } while (lo <= hi);
 hi = lo--;
 for (int j = start; j < end; j++) {
  int w = ct_eb[j + 1] - ct_eb[j];
  int x = C * w * ct_alloc[lo][j] << LM >> 2, y = hi >= 11 ? cap[j] : C * w * ct_alloc[hi][j] << LM >> 2;
  if (x > 0) x = ct_max(0, x + toff[j]);
  if (y > 0) y = ct_max(0, y + toff[j]);
  if (lo > 0) x += boost[j];
  y += boost[j];
  if (boost[j] > 0) skip0 = j;
  b1[j] = x, b2[j] = ct_max(0, y - x); }
 ct_interp(c, skip0, b1, b2, th, cap, total, skip_rsv, is_rsv, ds_rsv, C, LM, d, a); }

// pvq: the index of a vector of k unit pulses over n dimensions, unranked by the counts
// v(n, k) = v(n - 1, k) + v(n, k - 1) + v(n - 1, k - 1) (rfc 6716 4.3.4.2). every count used
// is at most v(n, k), which the splits keep under 2^32
static void ct_pvq_row(uint32_t *v, int n, int k) {        // v[0..k] = v(n, 0..k)
 for (int j = 0; j <= k; j++) v[j] = j == 0;
 for (int m = 1; m <= n; m++) {
  uint32_t prev = v[0];                                    // v(m - 1, j - 1)
  for (int j = 1; j <= k; j++) {
   uint32_t up = v[j];                                     // v(m - 1, j)
   v[j] = up + v[j - 1] + prev, prev = up; } } }

static void ct_pvq(int *y, int n, int k, struct rdec *d) {
 uint32_t hi[130], lo[130];                               // v(n - j, .) and v(n - j - 1, .)
 ct_pvq_row(hi, n, k);
 uint32_t i = rd_uint(d, hi[k]);
 for (int j = 0; j < n; j++) {
  lo[0] = 1;                                               // v(m - 1, .) from v(m, .), downwards
  for (int t = 1; t <= k; t++) lo[t] = hi[t] - hi[t - 1] - lo[t - 1];
  uint64_t p = ((uint64_t) lo[k] + hi[k]) >> 1;
  int neg = i >= p, k0 = k;
  if (neg) i -= (uint32_t) p;
  p -= lo[k];
  while (p > i) p -= lo[--k];
  i -= (uint32_t) p;
  y[j] = neg ? k - k0 : k0 - k;
  memcpy(hi, lo, sizeof(uint32_t) * (unsigned) (k0 + 1)); } }

// spreading: the decoded vector turned by rotations back and forth (rfc 6716 4.3.4.3)
static void ct_turn(float *x, int len, int st, float c, float s) {
 for (int i = 0; i < len - st; i++) {
  float a = x[i], b = x[i + st];
  x[i + st] = c * b + s * a, x[i] = c * a - s * b; }
 for (int i = len - 2 * st - 1; i >= 0; i--) {
  float a = x[i], b = x[i + st];
  x[i + st] = c * b + s * a, x[i] = c * a - s * b; } }

static void ct_spread(float *x, int len, int B, int k, int spread) {
 static const int f[3] = {15, 10, 5};
 if (2 * k >= len || spread == CT_NONE) return;
 float g = (1.f * len) / (len + f[spread - 1] * k), th = .5f * (g * g), c = ct_cosn(th), s = ct_cosn(1.f - th);
 int st2 = 0;
 if (len >= 8 * B) { st2 = 1; while ((st2 * st2 + st2) * B + (B >> 2) < len) st2++; }
 len /= B;
 for (int i = 0; i < B; i++) {
  if (st2) ct_turn(x + i * len, len, st2, s, c);
  ct_turn(x + i * len, len, 1, c, s); } }

static void ct_renorm(float *x, int n, float gain) {
 float e = 1e-15f;
 for (int i = 0; i < n; i++) e += x[i] * x[i];
 float g = 1.f / ct_sqrt(e) * gain;
 for (int i = 0; i < n; i++) x[i] = g * x[i]; }

// k pulses decoded into x: unit norm times gain, spread; -> which of the B blocks got a pulse
static unsigned ct_shape(float *x, int n, int k, int spread, int B, struct rdec *d, float gain) {
 int y[176];
 float ryy = 0;
 ct_pvq(y, n, k, d);
 for (int i = 0; i < n; i++) ryy += (float) y[i] * (float) y[i];
 float g = 1.f / ct_sqrt(ryy) * gain;
 for (int i = 0; i < n; i++) x[i] = g * (float) y[i];
 ct_spread(x, n, B, k, spread);
 if (B <= 1) return 1;
 unsigned m = 0;
 for (int b = 0, n0 = n / B; b < B; b++)
  for (int j = 0; j < n0; j++) m |= (unsigned) (y[b * n0 + j] != 0) << b;
 return m; }

// the haar step and the hadamard reorderings that move a band between time and frequency
static void ct_haar(float *x, int n0, int st) {
 n0 >>= 1;
 for (int i = 0; i < st; i++)
  for (int j = 0; j < n0; j++) {
   float a = .70710678f * x[st * 2 * j + i], b = .70710678f * x[st * (2 * j + 1) + i];
   x[st * 2 * j + i] = a + b, x[st * (2 * j + 1) + i] = a - b; } }

static const int ct_order[30] = {1, 0, 3, 0, 2, 1, 7, 0, 4, 3, 6, 1, 5, 2, 15, 0, 8, 7, 12, 3, 11, 4, 14, 1, 9, 6, 13, 2, 10, 5};

static void ct_deinter(float *x, float *t, int n0, int st, int had) {
 const int *o = ct_order + st - 2;
 for (int i = 0; i < st; i++)
  for (int j = 0; j < n0; j++) t[(had ? o[i] : i) * n0 + j] = x[j * st + i];
 memcpy(x, t, sizeof(float) * (unsigned) (n0 * st)); }

static void ct_inter(float *x, float *t, int n0, int st, int had) {
 const int *o = ct_order + st - 2;
 for (int i = 0; i < st; i++)
  for (int j = 0; j < n0; j++) t[j * st + i] = x[(had ? o[i] : i) * n0 + j];
 memcpy(x, t, sizeof(float) * (unsigned) (n0 * st)); }

// cos and log2 tan of a split's angle, to the bit on every build
static int ct_fmul(int a, int b) { return (16384 + (int32_t) (int16_t) a * (int16_t) b) >> 15; }
static int ct_bcos(int x) {
 int x2 = (4096 + x * x) >> 13;
 return 1 + (32767 - x2) + ct_fmul(x2, -7651 + ct_fmul(x2, 8277 + ct_fmul(-626, x2))); }
static int ct_blog2tan(int s, int c) {
 int lc = rd_ilog((uint32_t) c), ls = rd_ilog((uint32_t) s);
 c <<= 15 - lc, s <<= 15 - ls;
 return (ls - lc) * (1 << 11) + ct_fmul(s, ct_fmul(s, -2597) + 7932) - ct_fmul(c, ct_fmul(c, -2597) + 7932); }

static unsigned ct_isqrt(uint32_t v) {
 unsigned g = 0;
 int sh = (rd_ilog(v) - 1) >> 1;
 for (unsigned b = 1u << sh; sh >= 0; b >>= 1, sh--) {
  uint32_t t = ((g << 1) + b) << sh;
  if (t <= v) g += b, v -= t; }
 return g; }

// the theta's quantizer: how finely a split's angle is coded for b eighth bits
static int ct_qn(int n, int b, int off, int cap, int stereo) {
 static const int16_t e2[8] = {16384, 17866, 19483, 21247, 23170, 25267, 27554, 30048};
 int n2 = 2 * n - 1 - (stereo && n == 2);
 int qb = ct_min(8 << 3, ct_min(b - cap - (4 << 3), (b + n2 * off) / n2));
 if (qb < (1 << 3 >> 1)) return 1;
 return ((e2[qb & 7] >> (14 - (qb >> 3))) + 1) >> 1 << 1; }

// the stereo pair from mid and side, each channel back to unit norm
static void ct_merge(float *x, float *y, float mid, int n) {
 float xp = 0, side = 0;
 for (int j = 0; j < n; j++) xp += x[j] * y[j], side += y[j] * y[j];
 xp = mid * xp;
 float m2 = mid, el = m2 * m2 + side - 2 * xp, er = m2 * m2 + side + 2 * xp;
 if (er < 6e-4f || el < 6e-4f) { memcpy(y, x, sizeof(float) * (unsigned) n); return; }
 float lg = 1.f / ct_sqrt(el), rg = 1.f / ct_sqrt(er);
 for (int j = 0; j < n; j++) {
  float l = mid * x[j], r = y[j];
  x[j] = lg * (l - r), y[j] = rg * (l + r); } }

// what a band's recursion shares
struct ct_bd {
 struct celt *c; struct rdec *d;
 int i, spread, intensity, tf;
 int *left;                             // eighth bits left in the frame
 uint32_t *seed;
};

// one band, or one half of a split: x (and y for a stereo pair) of n coefficients in B blocks,
// b eighth bits, folding from lowband when it gets no pulses; lowout takes the result for later
// bands to fold from. -> the collapse mask, a bit a block that got energy
static unsigned ct_band(struct ct_bd *q, float *x, float *y, int n, int b, int B, float *lowband, int LM,
                        float *lowout, int level, float gain, float *lbs, int fill) {
 int n0 = n, nb = n / B, nb0 = nb, B0 = B, tdiv = 0, recomb = 0, inv = 0, stereo = y != 0, split = stereo;
 int longb = B0 == 1, tfc = q->tf;
 float mid = 0, side = 0;
 unsigned cm = 0;
 struct rdec *d = q->d;
 if (n == 1) {                                     // one coefficient: just its sign
  float *v = x;
  for (int k = 0; k < 1 + stereo; k++, v = y) {
   int neg = 0;
   if (*q->left >= 1 << 3) neg = (int) rd_raw(d, 1), *q->left -= 1 << 3, b -= 1 << 3;
   v[0] = neg ? -1.f : 1.f; }
  if (lowout) lowout[0] = x[0];
  return 1; }
 if (!stereo && level == 0) {                      // to the band's own time-frequency resolution
  static const uint8_t inter[16] = {0, 1, 1, 1, 2, 3, 3, 3, 2, 3, 3, 3, 2, 3, 3, 3};
  if (tfc > 0) recomb = tfc;
  if (lowband && (recomb || ((nb & 1) == 0 && tfc < 0) || B0 > 1)) {
   memcpy(lbs, lowband, sizeof(float) * (unsigned) n);
   lowband = lbs; }
  for (int k = 0; k < recomb; k++) {
   if (lowband) ct_haar(lowband, n >> k, 1 << k);
   fill = inter[fill & 15] | inter[fill >> 4] << 2; }
  B >>= recomb, nb <<= recomb;
  while ((nb & 1) == 0 && tfc < 0) {
   if (lowband) ct_haar(lowband, nb, B);
   fill |= fill << B, B <<= 1, nb >>= 1, tdiv++, tfc++; }
  B0 = B, nb0 = nb;
  if (B0 > 1 && lowband) ct_deinter(lowband, q->c->tmp, nb >> recomb, B0 << recomb, longb); }
 if (!stereo && LM != -1 && b > ct_cache(q->i, LM)[ct_cache(q->i, LM)[0]] + 12 && n > 2) {   // too many bits for one codebook: halve it
  n >>= 1, y = x + n, split = 1, LM--;
  if (B == 1) fill = (fill & 1) | fill << 1;
  B = (B + 1) >> 1; }
 if (split) {
  int pcap = ct_logn[q->i] + LM * (1 << 3), off = (pcap >> 1) - (stereo && n == 2 ? 16 : 4);
  int qn = stereo && q->i >= q->intensity ? 1 : ct_qn(n, b, off, pcap, stereo), th = 0;
  int tell = (int) rd_tellf(d);
  if (qn != 1) {
   if (stereo && n > 2) {                          // a step pdf: thetas up to qn / 2 thrice as likely
    int x0 = qn / 2, ft = 3 * (x0 + 1) + x0, fs = (int) rd_freq(d, (unsigned) ft);
    th = fs < (x0 + 1) * 3 ? fs / 3 : x0 + 1 + (fs - (x0 + 1) * 3);
    rd_take(d, (unsigned) (th <= x0 ? 3 * th : th - 1 - x0 + (x0 + 1) * 3),
            (unsigned) (th <= x0 ? 3 * (th + 1) : th - x0 + (x0 + 1) * 3), (unsigned) ft); }
   else if (B0 > 1 || stereo) th = (int) rd_uint(d, (uint32_t) qn + 1);
   else {                                          // a triangular pdf
    int h = qn >> 1, ft = (h + 1) * (h + 1), fm = (int) rd_freq(d, (unsigned) ft), fs, fl;
    if (fm < (h * (h + 1) >> 1)) {
     th = (int) (ct_isqrt(8 * (uint32_t) fm + 1) - 1) >> 1;
     fs = th + 1, fl = th * (th + 1) >> 1; }
    else {
     th = (2 * (qn + 1) - (int) ct_isqrt(8 * (uint32_t) (ft - fm - 1) + 1)) >> 1;
     fs = qn + 1 - th, fl = ft - ((qn + 1 - th) * (qn + 2 - th) >> 1); }
    rd_take(d, (unsigned) fl, (unsigned) (fl + fs), (unsigned) ft); }
   th = th * 16384 / qn; }
  else if (stereo) inv = b > 2 << 3 && *q->left > 2 << 3 ? rd_logp(d, 2) : 0;
  int qalloc = (int) rd_tellf(d) - tell, imid, iside, delta, ofill = fill;
  b -= qalloc;
  if (th == 0) imid = 32767, iside = 0, fill &= (1 << B) - 1, delta = -16384;
  else if (th == 16384) imid = 0, iside = 32767, fill &= ((1 << B) - 1) << B, delta = 16384;
  else imid = ct_bcos(th), iside = ct_bcos(16384 - th), delta = ct_fmul((n - 1) << 7, ct_blog2tan(iside, imid));
  mid = (1.f / 32768) * imid, side = (1.f / 32768) * iside;
  if (n == 2 && stereo) {                          // a pair of pairs: one coded, the other its rotation
   int sb = th != 0 && th != 16384 ? 1 << 3 : 0, mb = b - sb, big = th > 8192, sg = 0;
   *q->left -= qalloc + sb;
   float *x2 = big ? y : x, *y2 = big ? x : y;
   if (sb) sg = (int) rd_raw(d, 1);
   sg = 1 - 2 * sg;
   cm = ct_band(q, x2, 0, n, mb, B, lowband, LM, lowout, level, gain, lbs, ofill);
   y2[0] = (float) -sg * x2[1], y2[1] = (float) sg * x2[0];
   x[0] = mid * x[0], x[1] = mid * x[1], y[0] = side * y[0], y[1] = side * y[1];
   float t = x[0];
   x[0] = t - y[0], y[0] = t + y[0];
   t = x[1], x[1] = t - y[1], y[1] = t + y[1]; }
  else {
   if (B0 > 1 && !stereo && (th & 0x3fff)) {
    if (th > 8192) delta -= delta >> (4 - LM);
    else delta = ct_min(0, delta + (n << 3 >> (5 - LM))); }
   int mb = ct_max(0, ct_min(b, (b - delta) / 2)), sb = b - mb, nl = stereo ? 0 : level + 1;
   *q->left -= qalloc;
   float *lb2 = lowband && !stereo ? lowband + n : 0, *lo1 = stereo ? lowout : 0;
   float gm = stereo ? 1.f : gain * mid, gs = gain * side;
   int sh = (B0 >> 1) & (stereo - 1), rebal = *q->left;
   if (mb >= sb) {
    cm = ct_band(q, x, 0, n, mb, B, lowband, LM, lo1, nl, gm, lbs, fill);
    rebal = mb - (rebal - *q->left);
    if (rebal > 3 << 3 && th != 0) sb += rebal - (3 << 3);
    cm |= ct_band(q, y, 0, n, sb, B, lb2, LM, 0, nl, gs, 0, fill >> B) << sh; }
   else {
    cm = ct_band(q, y, 0, n, sb, B, lb2, LM, 0, nl, gs, 0, fill >> B) << sh;
    rebal = sb - (rebal - *q->left);
    if (rebal > 3 << 3 && th != 16384) mb += rebal - (3 << 3);
    cm |= ct_band(q, x, 0, n, mb, B, lowband, LM, lo1, nl, gm, lbs, fill); } } }
 else {                                            // a leaf: pulses, or a fold or noise when it has none
  int k = ct_bits2q(q->i, LM, b), cur = ct_q2bits(q->i, LM, k);
  *q->left -= cur;
  while (*q->left < 0 && k > 0) *q->left += cur, k--, cur = ct_q2bits(q->i, LM, k), *q->left -= cur;
  if (k != 0) cm = ct_shape(x, n, ct_pulses(k), q->spread, B, d, gain);
  else {
   unsigned all = (unsigned) (1ul << B) - 1;
   fill &= (int) all;
   if (!fill) memset(x, 0, sizeof(float) * (unsigned) n);
   else {
    if (!lowband) {
     for (int j = 0; j < n; j++) *q->seed = ct_lcg(*q->seed), x[j] = (float) ((int32_t) *q->seed >> 20);
     cm = all; }
    else {
     for (int j = 0; j < n; j++) *q->seed = ct_lcg(*q->seed), x[j] = lowband[j] + (*q->seed & 0x8000 ? 1.f / 256 : -1.f / 256);
     cm = (unsigned) fill; }
    ct_renorm(x, n, gain); } } }
 if (stereo) {
  if (n != 2) ct_merge(x, y, mid, n);
  if (inv) for (int j = 0; j < n; j++) y[j] = -y[j]; }
 else if (level == 0) {                            // back to the frame's resolution
  static const uint8_t deinter[16] = {0, 3, 12, 15, 48, 51, 60, 63, 192, 195, 204, 207, 240, 243, 252, 255};
  if (B0 > 1) ct_inter(x, q->c->tmp, nb >> recomb, B0 << recomb, longb);
  nb = nb0, B = B0;
  for (int k = 0; k < tdiv; k++) B >>= 1, nb <<= 1, cm |= cm >> B, ct_haar(x, nb, B);
  for (int k = 0; k < recomb; k++) cm = deinter[cm], ct_haar(x, n0 >> k, 1 << k);
  B <<= recomb;
  if (lowout) {
   float s = ct_sqrt((float) n0);
   for (int j = 0; j < n0; j++) lowout[j] = s * x[j]; }
  cm &= (1u << B) - 1; }
 return cm; }

// every band's shape, low to high, each folding from what the bands below it decoded
static void ct_bands(struct celt *c, struct rdec *d, float *X, float *Y, uint8_t *masks, const struct ct_al *a,
                     int shortb, int spread, const int *tf, int total, int LM) {
 int M = 1 << LM, B = shortb ? M : 1, C = Y ? 2 : 1, start = c->start, lowoff = 0, uplow = 1;
 int bal = a->balance, dual = a->dual, left;
 float *norm = c->norm, *norm2 = norm + M * ct_eb[CT_BANDS];
 struct ct_bd q = {c, d, 0, spread, a->intensity, 0, &left, &c->s.rng};
 for (int i = start; i < c->end; i++) {
  int tell = (int) rd_tellf(d), n = M * ct_eb[i + 1] - M * ct_eb[i], b = 0, low = -1;
  float *x = X + M * ct_eb[i], *y = Y ? Y + M * ct_eb[i] : 0;
  unsigned xm, ym;
  if (i != start) bal -= tell;
  left = total - tell - 1;
  if (i <= a->coded - 1) b = ct_max(0, ct_min(16383, ct_min(left + 1, a->bits[i] + bal / ct_min(3, a->coded - i))));
  if ((M * ct_eb[i] - n >= M * ct_eb[start] || i == start + 1) && (uplow || lowoff == 0)) lowoff = i;
  if (i == start + 1) {                            // the first band folds from a copy of itself
   int n1 = M * (ct_eb[start + 1] - ct_eb[start]), n2 = M * (ct_eb[start + 2] - ct_eb[start + 1]), o = M * ct_eb[start];
   memcpy(norm + o + n1, norm + o + 2 * n1 - n2, sizeof(float) * (unsigned) (n2 - n1));
   if (C == 2) memcpy(norm2 + o + n1, norm2 + o + 2 * n1 - n2, sizeof(float) * (unsigned) (n2 - n1)); }
  q.i = i, q.tf = tf[i];
  if (lowoff != 0 && (spread != CT_AGGRESSIVE || B > 1 || tf[i] < 0)) {
   low = ct_max(M * ct_eb[start], M * ct_eb[lowoff] - n);
   int fs = lowoff, fe = lowoff - 1;
   while (M * ct_eb[--fs] > low);
   while (++fe < i && M * ct_eb[fe] < low + n);
   xm = ym = 0;
   for (int f = fs; f < fe || f == fs; f++) xm |= masks[f * C], ym |= masks[f * C + C - 1]; }
  else xm = ym = (1u << B) - 1;
  if (dual && i == a->intensity) {
   dual = 0;
   for (int j = M * ct_eb[start]; j < M * ct_eb[i]; j++) norm[j] = .5f * (norm[j] + norm2[j]); }
  if (dual) {
   xm = ct_band(&q, x, 0, n, b / 2, B, low != -1 ? norm + low : 0, LM, norm + M * ct_eb[i], 0, 1.f, c->lbs, (int) xm);
   ym = ct_band(&q, y, 0, n, b / 2, B, low != -1 ? norm2 + low : 0, LM, norm2 + M * ct_eb[i], 0, 1.f, c->lbs, (int) ym); }
  else xm = ym = ct_band(&q, x, y, n, b, B, low != -1 ? norm + low : 0, LM, norm + M * ct_eb[i], 0, 1.f, c->lbs, (int) (xm | ym));
  masks[i * C] = (uint8_t) xm, masks[i * C + C - 1] = (uint8_t) ym;
  bal += a->bits[i] + tell;
  uplow = b > n << 3; } }

// blocks that decoded to nothing in a transient get noise at the energy they lost
static void ct_anticollapse(struct celt *c, float *X, const uint8_t *masks, int LM, int C, int size, const int *bits) {
 uint32_t seed = c->s.rng;
 for (int i = c->start; i < c->end; i++) {
  int n0 = ct_eb[i + 1] - ct_eb[i], depth = (1 + bits[i]) / (n0 << LM);
  float th = .5f * ct_exp2(-.125f * depth), sq = 1.f / ct_sqrt((float) (n0 << LM));
  for (int k = 0; k < C; k++) {
   float p1 = c->s.le[k * CT_BANDS + i], p2 = c->s.le2[k * CT_BANDS + i];
   if (C == 1) p1 = ct_fmax(p1, c->s.le[CT_BANDS + i]), p2 = ct_fmax(p2, c->s.le2[CT_BANDS + i]);
   float ed = ct_fmax(0, c->s.e[k * CT_BANDS + i] - ct_fmin(p1, p2)), r = 2.f * ct_exp2(-ed);
   if (LM == 3) r *= 1.41421356f;
   r = ct_fmin(th, r) * sq;
   float *x = X + k * size + (ct_eb[i] << LM);
   int re = 0;
   for (int b = 0; b < 1 << LM; b++)
    if (!(masks[i * C + k] & 1 << b)) {
     for (int j = 0; j < n0; j++) seed = ct_lcg(seed), x[(j << LM) + b] = seed & 0x8000 ? r : -r;
     re = 1; }
   if (re) ct_renorm(x, n0 << LM, 1.f); } } }

// the normalised shapes scaled by the band amplitudes into mdct coefficients
static void ct_denorm(const float *X, float *freq, const float *amp, int end, int C, int M) {
 int N = M * 120;
 for (int k = 0; k < C; k++) {
  float *f = freq + k * N;
  const float *x = X + k * N;
  for (int i = 0; i < end; i++)
   for (int j = M * ct_eb[i]; j < M * ct_eb[i + 1]; j++) *f++ = *x++ * amp[i + k * CT_BANDS];
  for (int i = M * ct_eb[end]; i < N; i++) *f++ = 0; } }

// an unscaled inverse dft of n points (480 >> s), in at stride st into o: decimation in time,
// radix 4 while it divides, then 2, 3, 5. ts is the twiddle stride, 480 / n
static void ct_fft(const float (*tw)[2], float (*o)[2], const float (*in)[2], int n, int st, int ts) {
 if (n == 1) { o[0][0] = in[0][0], o[0][1] = in[0][1]; return; }
 int p = n % 4 == 0 ? 4 : n % 2 == 0 ? 2 : n % 3 == 0 ? 3 : 5, m = n / p;
 for (int r = 0; r < p; r++) ct_fft(tw, o + r * m, in + r * st, m, st * p, ts * p);
 for (int j = 0; j < m; j++) {
  float t[5][2];
  for (int r = 0; r < p; r++) {
   const float *w = tw[r * j * ts], *v = o[r * m + j];
   t[r][0] = v[0] * w[0] - v[1] * w[1], t[r][1] = v[0] * w[1] + v[1] * w[0]; }
  for (int k = 0; k < p; k++) {
   float sr = 0, si = 0;
   for (int r = 0; r < p; r++) {
    const float *w = tw[(r * k % p) * (480 / p)];
    sr += t[r][0] * w[0] - t[r][1] * w[1], si += t[r][0] * w[1] + t[r][1] * w[0]; }
   o[k * m + j][0] = sr, o[k * m + j][1] = si; } } }

// the inverse mdct of n2 = 960 >> s coefficients at stride st, windowed and added into out,
// which spans n2 + 120 samples from its first overlapped one
static void ct_imdct(struct celt *c, const float *in, float *out, int s, int st) {
 int N = 1920 >> s, n2 = N >> 1, n4 = N >> 2, ov = CT_OVERLAP;
 const float *t = c->trig;
 float *f = c->f, *f2 = c->f2, sine = (float) 2 * CT_PI * (.125f) / N;
 const float *x1 = in, *x2 = in + st * (n2 - 1);
 for (int i = 0; i < n4; i++, x1 += 2 * st, x2 -= 2 * st) {     // pre-twiddle
  float yr = -*x2 * t[i << s] + *x1 * t[(n4 - i) << s], yi = -*x2 * t[(n4 - i) << s] - *x1 * t[i << s];
  f2[2 * i] = yr - yi * sine, f2[2 * i + 1] = yi + yr * sine; }
 ct_fft((const float (*)[2]) c->tw, (float (*)[2]) f, (const float (*)[2]) f2, n4, 1, 1 << s);
 for (int i = 0; i < n4; i++) {                                 // post-twiddle
  float re = f[2 * i], im = f[2 * i + 1];
  float yr = re * t[i << s] - im * t[(n4 - i) << s], yi = im * t[i << s] + re * t[(n4 - i) << s];
  f[2 * i] = yr - yi * sine, f[2 * i + 1] = yi + yr * sine; }
 for (int i = 0; i < n4; i++) f2[2 * i] = -f[2 * i], f2[2 * i + 1] = f[n2 - 1 - 2 * i];
 float *o = out - ((n2 - ov) >> 1);                             // where the mirrored halves land
 int h = n4 - ov / 2;
 for (int i = 0; i < h; i++) o[n2 - 1 - i] = f2[n4 - 1 - i], o[n2 + i] = f2[n4 + i];
 for (int i = h, k = 0; i < n4; i++, k++) {
  float a = f2[n4 - 1 - i], b = f2[n4 + i];
  o[h + k] += -c->win[k] * a;
  o[n2 - 1 - i] += c->win[ov - 1 - k] * a;
  o[N - 1 - h - k] = c->win[k] * b;
  o[n2 + i] = c->win[ov - 1 - k] * b; } }

static void ct_imdcts(struct celt *c, int shortb, const float *X, float **syn, int C, int LM) {
 int N = 120 << LM, B = shortb ? shortb : 1, n2 = shortb ? 120 : N;
 for (int k = 0; k < C; k++) {
  float *x = c->tmp, *ovm = c->s.mem[k] + CT_HIST;            // the frame and its tail
  memset(x, 0, sizeof(float) * CT_OVERLAP);
  for (int b = 0; b < B; b++) ct_imdct(c, X + b + k * n2 * B, x + n2 * b, shortb ? 3 : 3 - LM, B);
  for (int j = 0; j < CT_OVERLAP; j++) syn[k][j] = x[j] + ovm[j];
  for (int j = CT_OVERLAP; j < N; j++) syn[k][j] = x[j];
  for (int j = 0; j < CT_OVERLAP; j++) ovm[j] = x[N + j]; } }

// the pitch post-filter: three taps around the period, cross-faded from the last frame's
static void ct_comb(float *y, const float *x, int t0, int t1, int n, float g0, float g1, int k0, int k1,
                    const float *win, int ov) {
 static const float gains[3][3] = {{.3066406250f, .2170410156f, .1296386719f}, {.4638671875f, .2680664062f, 0}, {.7998046875f, .1000976562f, 0}};
 float g00 = g0 * gains[k0][0], g01 = g0 * gains[k0][1], g02 = g0 * gains[k0][2];
 float g10 = g1 * gains[k1][0], g11 = g1 * gains[k1][1], g12 = g1 * gains[k1][2];
 for (int i = 0; i < ov; i++) {
  float f = win[i] * win[i], u = 1.f - f;
  y[i] = x[i] + u * g00 * x[i - t0] + u * g01 * x[i - t0 - 1] + u * g01 * x[i - t0 + 1] + u * g02 * x[i - t0 - 2]
       + u * g02 * x[i - t0 + 2] + f * g10 * x[i - t1] + f * g11 * x[i - t1 - 1] + f * g11 * x[i - t1 + 1]
       + f * g12 * x[i - t1 - 2] + f * g12 * x[i - t1 + 2]; }
 for (int i = ov; i < n; i++)
  y[i] = x[i] + g10 * x[i - t1] + g11 * x[i - t1 - 1] + g11 * x[i - t1 + 1] + g12 * x[i - t1 - 2] + g12 * x[i - t1 + 2]; }

static void ct_deemph(struct celt *c, float **in, float *pcm, int n, int C) {
 for (int k = 0; k < C; k++) {
  float m = c->s.emph[k];
  for (int j = 0; j < n; j++) {
   float t = in[k][j] + m;
   m = .85000610f * t;
   pcm[j * C + k] = t * (1 / 32768.f); }
  c->s.emph[k] = m; } }

// the loss path's analysis: autocorrelation (ends windowed when win), levinson, and the
// predictor's filters run in place
static void ct_autocorr(struct celt *c, const float *x, float *ac, const float *win, int ov, int lag, int n) {
 float *xx = c->tmp;
 for (int i = 0; i < n; i++) xx[i] = x[i];
 for (int i = 0; i < ov; i++) xx[i] = x[i] * win[i], xx[n - i - 1] = x[n - i - 1] * win[i];
 for (; lag >= 0; lag--) {
  float s = 0;
  for (int i = lag; i < n; i++) s += xx[i] * xx[i - lag];
  ac[lag] = s; }
 ac[0] += 10; }

static void ct_lpc(float *lpc, const float *ac, int p) {
 float err = ac[0];
 for (int i = 0; i < p; i++) lpc[i] = 0;
 if (ac[0] == 0) return;
 for (int i = 0; i < p; i++) {
  float rr = 0;
  for (int j = 0; j < i; j++) rr += lpc[j] * ac[i - j];
  rr += ac[i + 1];
  float r = -(rr / err);
  lpc[i] = r;
  for (int j = 0; j < (i + 1) >> 1; j++) {
   float a = lpc[j], b = lpc[i - 1 - j];
   lpc[j] = a + r * b, lpc[i - 1 - j] = b + r * a; }
  err = err - r * r * err;
  if (err < .001f * ac[0]) break; } }

static void ct_fir(float *x, const float *num, int n, int ord, float *mem) {
 for (int i = 0; i < n; i++) {
  float s = x[i], v = x[i];
  for (int j = 0; j < ord; j++) s += num[j] * mem[j];
  for (int j = ord - 1; j >= 1; j--) mem[j] = mem[j - 1];
  mem[0] = v, x[i] = s; } }

static void ct_iir(float *x, const float *den, int n, int ord, float *mem) {
 for (int i = 0; i < n; i++) {
  float s = x[i];
  for (int j = 0; j < ord; j++) s -= den[j] * mem[j];
  for (int j = ord - 1; j >= 1; j--) mem[j] = mem[j - 1];
  mem[0] = s, x[i] = s; } }

// the pitch the history repeats at: the two best lags at a quarter rate, refined at half
static void ct_best(const float *xc, const float *y, int len, int maxp, int *best) {
 float syy = 1, bn[2] = {-1, -1}, bd[2] = {0, 0};
 best[0] = 0, best[1] = 1;
 for (int j = 0; j < len; j++) syy += y[j] * y[j];
 for (int i = 0; i < maxp; i++) {
  if (xc[i] > 0) {
   float num = xc[i] * xc[i];
   if (num * bd[1] > bn[1] * syy) {
    if (num * bd[0] > bn[0] * syy) bn[1] = bn[0], bd[1] = bd[0], best[1] = best[0], bn[0] = num, bd[0] = syy, best[0] = i;
    else bn[1] = num, bd[1] = syy, best[1] = i; } }
  syy += y[i + len] * y[i + len] - y[i] * y[i];
  syy = ct_fmax(1, syy); } }

static int ct_pitch(struct celt *c, int C) {
 float *lp = c->pbuf, ac[5], lpc[4], mem[4] = {0, 0, 0, 0}, t = 1.f;
 int n = CT_HIST >> 1;
 for (int k = 0; k < C; k++) {                     // halve the rate, mixed to mono
  const float *x = c->s.mem[k];
  for (int i = 1; i < n; i++) lp[i] = (k ? lp[i] : 0) + .5f * (.5f * (x[2 * i - 1] + x[2 * i + 1]) + x[2 * i]);
  lp[0] = (k ? lp[0] : 0) + .5f * (.5f * x[1] + x[0]); }
 ct_autocorr(c, lp, ac, 0, 0, 4, n);
 ac[0] *= 1.0001f;
 for (int i = 1; i <= 4; i++) ac[i] -= ac[i] * (.008f * i) * (.008f * i);
 ct_lpc(lpc, ac, 4);
 for (int i = 0; i < 4; i++) t = .9f * t, lpc[i] = lpc[i] * t;
 ct_fir(lp, lpc, n, 4, mem);                       // whiten
 mem[0] = 0, lpc[0] = .8f;
 ct_fir(lp, lpc, n, 1, mem);
 const float *xl = lp + 360, *y = lp;
 int len = CT_HIST - 720, maxp = 620, best[2] = {0, 0};
 float x4[332], y4[487], xc[310];
 for (int j = 0; j < len >> 2; j++) x4[j] = xl[2 * j];
 for (int j = 0; j < (len + maxp) >> 2; j++) y4[j] = y[2 * j];
 for (int i = 0; i < maxp >> 2; i++) {
  float s = 0;
  for (int j = 0; j < len >> 2; j++) s += x4[j] * y4[i + j];
  xc[i] = ct_fmax(-1, s); }
 ct_best(xc, y4, len >> 2, maxp >> 2, best);
 for (int i = 0; i < maxp >> 1; i++) {
  float s = 0;
  xc[i] = 0;
  if ((i - 2 * best[0] > 2 || 2 * best[0] - i > 2) && (i - 2 * best[1] > 2 || 2 * best[1] - i > 2)) continue;
  for (int j = 0; j < len >> 1; j++) s += xl[j] * y[i + j];
  xc[i] = ct_fmax(-1, s); }
 ct_best(xc, y, len >> 1, maxp >> 1, best);
 int off = 0;
 if (best[0] > 0 && best[0] < (maxp >> 1) - 1) {
  float a = xc[best[0] - 1], b = xc[best[0]], cc = xc[best[0] + 1];
  if (cc - a > .7f * (b - a)) off = 1;
  else if (a - cc > .7f * (b - cc)) off = -1; }
 return 720 - (2 * best[0] - off); }

// a lost frame: noise at the last energies once five are lost in a row (or a hybrid's high
// bands), else the last pitch period repeated through the last predictor, fading
static void ct_lost(struct celt *c, float *pcm, int N, int LM) {
 int C = c->ch, ov = CT_OVERLAP;
 float *syn[2], fade = 1.f;
 for (int k = 0; k < C; k++) syn[k] = c->s.mem[k] + CT_HIST - N;
 if (c->s.lost >= 5 || c->start != 0) {
  float amp[2 * CT_BANDS], *X = c->x, *freq = c->freq;
  for (int k = 0; k < C; k++) memmove(c->s.mem[k], c->s.mem[k] + N, sizeof(float) * (unsigned) (CT_HIST - N));
  if (c->s.lost >= 5) ct_amps(c->start, c->end, amp, c->s.bg, C);
  else {
   float decay = c->s.lost == 0 ? 1.5f : .5f;
   for (int k = 0; k < C; k++)
    for (int i = c->start; i < c->end; i++) c->s.e[k * CT_BANDS + i] -= decay;
   ct_amps(c->start, c->end, amp, c->s.e, C); }
  uint32_t seed = c->s.rng;
  for (int k = 0; k < C; k++) {
   for (int i = 0; i < ct_eb[c->start] << LM; i++) X[k * N + i] = 0;
   for (int i = c->start; i < CT_BANDS; i++) {
    int o = N * k + (ct_eb[i] << LM), w = (ct_eb[i + 1] - ct_eb[i]) << LM;
    for (int j = 0; j < w; j++) seed = ct_lcg(seed), X[o + j] = (float) ((int32_t) seed >> 20);
    ct_renorm(X + o, w, 1.f); }
   for (int i = ct_eb[c->end] << LM; i < N; i++) X[k * N + i] = 0; }
  c->s.rng = seed;
  ct_denorm(X, freq, amp, CT_BANDS, C, 1 << LM);
  for (int k = 0; k < C; k++) {
   for (int i = 0; i < ct_eb[c->start] << LM; i++) freq[k * N + i] = 0;
   for (int i = ct_eb[c->end] << LM; i < N; i++) freq[k * N + i] = 0; }
  ct_imdcts(c, 0, freq, syn, C, LM); }
 else {
  int pitch;
  if (c->s.lost == 0) pitch = c->s.pitch = ct_pitch(c, C);
  else pitch = c->s.pitch, fade = .8f;
  for (int k = 0; k < C; k++) {
   float *out = c->s.mem[k] + CT_HIST - CT_PERIOD, *exc = c->exc, *e = c->ebuf, ac[25], mem[24], *lpc = c->s.lpc[k];
   float decay, s1 = 0, s2 = 0, e1 = 1, e2 = 1;
   int off = CT_PERIOD - pitch, period = pitch <= CT_PERIOD / 2 ? pitch : CT_PERIOD / 2, len = N + ov;
   for (int i = 0; i < CT_PERIOD; i++) exc[i] = out[i];
   if (c->s.lost == 0) {
    ct_autocorr(c, exc, ac, c->win, ov, 24, CT_PERIOD);
    ac[0] *= 1.0001f;
    for (int i = 1; i <= 24; i++) ac[i] -= ac[i] * (.008f * i) * (.008f * i);
    ct_lpc(lpc, ac, 24); }
   for (int i = 0; i < 24; i++) mem[i] = out[CT_PERIOD - 1 - i];
   ct_fir(exc, lpc, CT_PERIOD, 24, mem);           // the excitation
   for (int i = 0; i < period; i++) {
    float a = exc[CT_PERIOD - period + i], b = exc[CT_PERIOD - 2 * period + i];
    e1 += a * a, e2 += b * b; }
   if (e1 > e2) e1 = e2;
   decay = ct_sqrt(e1 / e2);
   for (int i = 0; i < len + ov; i++) {
    if (off + i >= CT_PERIOD) off -= pitch, decay = decay * decay;
    e[i] = decay * exc[off + i];
    float t = out[off + i];
    s1 += t * t; }
   for (int i = 0; i < 24; i++) mem[i] = out[CT_PERIOD - 1 - i];
   for (int i = 0; i < len + ov; i++) e[i] = fade * e[i];
   ct_iir(e, lpc, len + ov, 24, mem);
   for (int i = 0; i < len + ov; i++) s2 += e[i] * e[i];
   if (!(s1 > .2f * s2)) memset(e, 0, sizeof(float) * (unsigned) (len + ov));
   else if (s1 < s2) {
    float r = ct_sqrt((s1 + 1) / (s2 + 1));
    for (int i = 0; i < len + ov; i++) e[i] = r * e[i]; }
   float *tail = out + CT_PERIOD;
   if (c->s.pf_g != 0) ct_comb(tail, tail, c->s.pf_t, c->s.pf_t, ov, c->s.pf_g, c->s.pf_g, c->s.pf_k, c->s.pf_k, 0, 0);
   for (int i = 0; i < CT_PERIOD + ov - N; i++) out[i] = out[N + i];
   for (int i = 0; i < ov / 2; i++) {
    float t = c->win[i] * e[N + ov - 1 - i] + c->win[ov - i - 1] * e[N + i];
    out[CT_PERIOD + i] = c->win[ov - i - 1] * t, out[CT_PERIOD + ov - i - 1] = c->win[i] * t; }
   for (int i = 0; i < N; i++) out[CT_PERIOD - N + i] = e[i];
   if (c->s.pf_g != 0) ct_comb(e, tail, c->s.pf_t, c->s.pf_t, ov, -c->s.pf_g, -c->s.pf_g, c->s.pf_k, c->s.pf_k, 0, 0);
   else memcpy(e, tail, sizeof(float) * (unsigned) ov);
   for (int i = 0; i < ov; i++) out[CT_PERIOD + i] = e[i]; } }
 ct_deemph(c, syn, pcm, N, C);
 c->s.lost++; }

int ct_decode(struct celt *c, const uint8_t *p, int len, float *pcm, int n, struct rdec *d) {
 int CC = c->ch, C = c->sch, LM = 0, M, N, end = c->end;
 while (LM <= 3 && 120 << LM != n) LM++;
 if (LM > 3 || len < 0 || len > 1275) return -1;
 M = 1 << LM, N = M * 120;
 float *X = c->x, *freq = c->freq, amp[2 * CT_BANDS], *syn[2];
 for (int k = 0; k < C; k++) {
  for (int i = 0; i < M * ct_eb[c->start]; i++) X[k * N + i] = 0;
  for (int i = M * ct_eb[end]; i < N; i++) X[k * N + i] = 0; }
 if (!p || len <= 1) { ct_lost(c, pcm, N, LM); return n; }
 struct rdec own;
 if (!d) rd_init(&own, p, (uint32_t) len), d = &own;
 float *e = c->s.e;
 if (C == 1) for (int i = 0; i < CT_BANDS; i++) e[i] = ct_fmax(e[i], e[CT_BANDS + i]);
 int total = len * 8, tell = rd_tell(d), silence = tell >= total ? 1 : tell == 1 ? rd_logp(d, 15) : 0;
 if (silence) tell = len * 8, d->bits += tell - rd_tell(d);
 int pitch = 0, tapset = 0;
 float gain = 0;
 if (c->start == 0 && tell + 16 <= total) {
  if (rd_logp(d, 1)) {
   int oct = (int) rd_uint(d, 6);
   pitch = (16 << oct) + (int) rd_raw(d, 4 + (unsigned) oct) - 1;
   int qg = (int) rd_raw(d, 3);
   if (rd_tell(d) + 2 <= total) tapset = rd_icdf(d, ct_tapset_icdf, 2);
   gain = .09375f * (qg + 1); }
  tell = rd_tell(d); }
 int tr = 0;
 if (LM > 0 && tell + 3 <= total) tr = rd_logp(d, 3), tell = rd_tell(d);
 int shortb = tr ? M : 0, intra = tell + 3 <= total ? rd_logp(d, 3) : 0;
 ct_coarse(c, d, intra, C, LM);
 int tf[CT_BANDS], cap[CT_BANDS], boost[CT_BANDS];
 ct_tf(c->start, end, tr, tf, LM, d);
 tell = rd_tell(d);
 int spread = tell + 4 <= total ? rd_icdf(d, ct_spread_icdf, 5) : 2;
 for (int i = 0; i < CT_BANDS; i++) cap[i] = (ct_caps[CT_BANDS * (2 * LM + C - 1) + i] + 64) * C * ((ct_eb[i + 1] - ct_eb[i]) << LM) >> 2;
 int dlogp = 6;
 total <<= 3, tell = (int) rd_tellf(d);
 for (int i = c->start; i < end; i++) {           // per-band boosts
  int w = C * (ct_eb[i + 1] - ct_eb[i]) << LM, quanta = ct_min(w << 3, ct_max(6 << 3, w)), lp = dlogp, b = 0;
  while (tell + (lp << 3) < total && b < cap[i]) {
   int more = rd_logp(d, (unsigned) lp);
   tell = (int) rd_tellf(d);
   if (!more) break;
   b += quanta, total -= quanta, lp = 1; }
  boost[i] = b;
  if (b > 0) dlogp = ct_max(2, dlogp - 1); }
 int trim = tell + (6 << 3) <= total ? rd_icdf(d, ct_trim_icdf, 7) : 5;
 int bits = (len * 8 << 3) - (int) rd_tellf(d) - 1, anti_rsv = tr && LM >= 2 && bits >= (LM + 2) << 3 ? 8 : 0;
 bits -= anti_rsv;
 struct ct_al a;
 ct_allocate(c, boost, cap, trim, bits, C, LM, d, &a);
 ct_fine(c, d, a.fine, C);
 uint8_t masks[2 * CT_BANDS];
 ct_bands(c, d, X, C == 2 ? X + N : 0, masks, &a, shortb, spread, tf, len * (8 << 3) - anti_rsv, LM);
 int anti = anti_rsv > 0 ? (int) rd_raw(d, 1) : 0;
 ct_finefin(c, d, a.fine, a.prio, len * 8 - rd_tell(d), C);
 if (anti) ct_anticollapse(c, X, masks, LM, C, N, a.bits);
 ct_amps(c->start, end, amp, e, C);
 if (silence) for (int i = 0; i < C * CT_BANDS; i++) amp[i] = 0, e[i] = -28.f;
 ct_denorm(X, freq, amp, end, C, M);
 for (int k = 0; k < CC; k++) memmove(c->s.mem[k], c->s.mem[k] + N, sizeof(float) * (unsigned) (CT_HIST - N));
 for (int k = 0; k < C; k++) {
  for (int i = 0; i < M * ct_eb[c->start]; i++) freq[k * N + i] = 0;
  for (int i = M * ct_eb[end]; i < N; i++) freq[k * N + i] = 0; }
 for (int k = 0; k < CC; k++) syn[k] = c->s.mem[k] + CT_HIST - N;
 if (CC == 2 && C == 1) memcpy(freq + N, freq, sizeof(float) * (unsigned) N);
 if (CC == 1 && C == 2) for (int i = 0; i < N; i++) freq[i] = .5f * (freq[i] + freq[N + i]);
 ct_imdcts(c, shortb, freq, syn, CC, LM);
 struct ct_live *s = &c->s;
 for (int k = 0; k < CC; k++) {
  s->pf_t = ct_max(s->pf_t, 15), s->pf_t0 = ct_max(s->pf_t0, 15);
  if (s->pf_g0 != 0 || s->pf_g != 0)
   ct_comb(syn[k], syn[k], s->pf_t0, s->pf_t, 120, s->pf_g0, s->pf_g, s->pf_k0, s->pf_k, c->win, CT_OVERLAP);
  if (LM != 0 && (s->pf_g != 0 || gain != 0))
   ct_comb(syn[k] + 120, syn[k] + 120, s->pf_t, pitch, N - 120, s->pf_g, gain, s->pf_k, tapset, c->win, CT_OVERLAP); }
 s->pf_t0 = s->pf_t, s->pf_g0 = s->pf_g, s->pf_k0 = s->pf_k;
 s->pf_t = pitch, s->pf_g = gain, s->pf_k = tapset;
 if (LM != 0) s->pf_t0 = s->pf_t, s->pf_g0 = s->pf_g, s->pf_k0 = s->pf_k;
 if (C == 1) for (int i = 0; i < CT_BANDS; i++) e[CT_BANDS + i] = e[i];
 for (int i = 0; i < 2 * CT_BANDS; i++)
  if (!tr) s->le2[i] = s->le[i], s->le[i] = e[i], s->bg[i] = ct_fmin(s->bg[i] + M * .001f, e[i]);
  else s->le[i] = ct_fmin(s->le[i], e[i]);
 for (int k = 0; k < 2; k++)
  for (int i = 0; i < CT_BANDS; i++)
   if (i < c->start || i >= end) e[k * CT_BANDS + i] = 0, s->le[k * CT_BANDS + i] = s->le2[k * CT_BANDS + i] = -28.f;
 s->rng = d->rng;
 ct_deemph(c, syn, pcm, N, CC);
 s->lost = 0;
 return rd_tell(d) > 8 * len ? -3 : n; }
