// the stones song: apartment.l's numbers, its dice an xorshift of the board's own
#include "song.h"

float lm_expf(float);

#define sg_db ((tn_flo) 8.685889638065035)            // dB a neper
#define sg_c4 ((tn_flo) 261.6255653005986)
#define sg_semi ((tn_flo) 0.057762265046662105)       // ln 2 / 12
#define sg_gain ((tn_flo) 0.56)                      // its loudest at about 0.95 of the range

// two octaves over apartment.l's, where the board's small speaker sounds
static tn_flo const phrase[3] = { 18.5f, 20.5f, 11.5f };
static tn_flo const drone_notes[2] = { -0.5f, 6.5f };
// a note's returns: frames behind it (0.09 0.21 0.37 s), and how loud
static uint32_t const echo_at[3] = { 900, 2100, 3700 };
static tn_flo const echo_g[3] = { 0.45f, 0.28f, 0.16f };
static tn_flo const box[sg_parts][3] = { { 2.0f, 1.0f, 0.0f }, { 6.0f, 0.3f, 6.0f }, { 11.6f, 0.15f, 9.0f } };   // ratio level decay
enum { sg_loop = 20 * sg_rate };                      // the drone repeats each 20 s

static uint32_t roll(struct song *s, uint32_t n) {
  uint32_t x = s->z;
  x ^= x << 13, x ^= x >> 17, x ^= x << 5, s->z = x;
  return x % n; }

// a row at rest: nothing moves it, its level 1, half a turn high
static void row0(tn_flo *o) {
  for (int k = 0; k < tn_row; k++) o[k] = 0;
  o[6] = -1, o[15] = -1, o[16] = 0.5f, o[17] = 1; }

void song_init(struct song *s, uint32_t seed) {
  s->z = seed | 1u, s->pos = 0, s->next = 2 * sg_rate, s->lr = -1;
  // each pitch a whole number of cycles a loop, wavering 0.3 Hz by 2 radians, swelling 3.74 dB at 0.05 Hz
  for (int k = 0; k < 2; k++) {
    tn_flo *o = s->drone + k * tn_row, f = sg_c4 * lm_expf(drone_notes[k] * sg_semi);
    f = (tn_flo) (int32_t) (f * 20 + 0.5f) / 20;
    row0(o);
    o[1] = f, o[9] = 0.5f * 1.11f, o[11] = 0.6f / f, o[12] = 0.3f, o[13] = 3.74f, o[14] = 0.05f;
    o[18] = 1, o[tn_seg0 + 1] = 1, o[tn_seg0 + 2] = 1; }
  for (int k = 0; k < 4; k++) s->dst[k] = 0;
  for (int k = 0; k < sg_notes; k++) s->nt[k].end = 0;
  for (int k = 0; k < sg_dl; k++) s->dl[k] = 0; }

// a box note at frame at, ringing d seconds: each partial rises at 420 and dies over d, and one
// past the half rate is left out
static void note(struct song *s, uint32_t at, tn_flo nt, tn_flo d) {
  struct sg_note *v = 0;
  for (int k = 0; k < sg_notes && !v; k++) if (s->nt[k].end <= s->pos) v = s->nt + k;
  if (!v) return;
  tn_flo f = sg_c4 * lm_expf(nt * sg_semi);
  v->at = at, v->end = at + (uint32_t) (d * sg_rate) + 2, v->no = 0;
  for (int p = 0; p < sg_parts; p++) {
    if (f * box[p][0] * 2 >= sg_rate) continue;
    tn_flo *o = v->ops + v->no++ * tn_row;
    row0(o);
    o[1] = f * box[p][0], o[9] = 0.35f * box[p][1], o[18] = 2;
    tn_flo *g = o + tn_seg0;
    g[1] = 2, g[2] = 420, g[3] = (2.6f / d + box[p][2]) * sg_db;
    g[5] = d, g[6] = 1; }
  for (int k = 0; k < 2 * sg_parts; k++) v->st[k] = 0; }

// three notes at an octave the die picks, never the last one's, lower slower and longer
static void phrase_at(struct song *s, uint32_t base) {
  int nr;
  do nr = (int) roll(s, 3); while (nr == s->lr);
  int o = nr - 1;
  tn_flo slow = o < 0 ? 1.2f : o > 0 ? 1 / 1.2f : 1;
  for (int i = 0; i < 3; i++) note(s, base + (uint32_t) (i * 1.2f * slow * sg_rate), phrase[i] + 12.0f * o, 3.0f * slow);
  s->lr = nr;
  s->next = base + sg_rate * (14 + roll(s, 7)); }

void song_fill(struct song *s, uint16_t *d, uint32_t n, uint32_t top) {
  for (uint32_t c = 0; c < n; c += sg_chunk, d += sg_chunk) {
    uint32_t const pos = s->pos;
    if (s->next <= pos + sg_chunk) phrase_at(s, pos);
    for (int i = 0; i < sg_chunk; i++) s->L[i] = 0, s->B[i] = 0;
    tones_run(s->drone, 2, s->dst, sg_chunk, pos % sg_loop, sg_rate, s->L, s->L, s->sc);
    for (int k = 0; k < sg_notes; k++) {
      struct sg_note *v = s->nt + k;
      if (v->end > pos && v->no)
        tones_run(v->ops, v->no, v->st, sg_chunk, (int64_t) pos - (int64_t) v->at, sg_rate, s->B, s->B, s->sc); }
    // the arrays and tables held in locals: mooncc reaches a field deep in the struct by a
    // chain of adds each time it is named
    tn_flo *const dl = s->dl, *const L = s->L, *const B = s->B;
    uint32_t const e0 = echo_at[0], e1 = echo_at[1], e2 = echo_at[2];
    tn_flo const g0 = echo_g[0], g1 = echo_g[1], g2 = echo_g[2], half = 0.5f * (tn_flo) top;
    for (int i = 0; i < sg_chunk; i++) {
      uint32_t const t = pos + (uint32_t) i;
      dl[t & (sg_dl - 1)] = B[i];
      tn_flo y = (L[i] + B[i] + g0 * dl[(t - e0) & (sg_dl - 1)] + g1 * dl[(t - e1) & (sg_dl - 1)]
                  + g2 * dl[(t - e2) & (sg_dl - 1)]) * sg_gain;
      y = y > 1 ? 1 : y < -1 ? -1 : y;
      d[i] = (uint16_t) (half + half * y); }
    s->pos = pos + sg_chunk; } }
