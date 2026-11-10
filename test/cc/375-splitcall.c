// values across calls some paths take: a pointer read first where no call has run, then after a
// call on the way round; doubles kept over calls a pixel rarely makes; many live at once
#include <string.h>
struct m { int lc, lp, pb; };
__attribute__((noinline)) static int props(struct m *m, unsigned b) { if (b >= 225) return 0; m->lc = (int) (b % 9); b /= 9; m->lp = (int) (b % 5); m->pb = (int) (b / 5); return 1; }
__attribute__((noinline)) static double sun(double x) { return x * 0.5 + 0.25; }
__attribute__((noinline)) static void glow(int *o, const double *c) { *o += (int) (c[0] + c[1] + c[2]); }

static int dec(const unsigned char *s, unsigned char *out, struct m *m) {
 unsigned n = 0, i = 0;
 for (;;) {
  unsigned c = s[i];
  if (!c) return (int) n;
  if (c < 0x80) { memcpy(out + n, s + i + 1, c & 7); n += c & 7; i += 1 + (c & 7); continue; }
  if (!props(m, s[i + 1])) return -1;
  n += (unsigned) (m->lc + m->lp + m->pb); i += 2; } }

static long row(int w, int shade, int add, const double *v0, const double *vx) {
 double a[9];
 int o[64] = { 0 };
 long s = 0;
 for (int k = 0; k < 9; k++) a[k] = v0[k];
 for (int x = 0; x < w; x++) {
  double c[3] = { a[2] * 255, a[3] * 255, a[4] * 255 };
  double l = shade && (x & 3) == 0 ? sun(a[5]) : 1;
  c[0] *= l;
  if (add && (x & 7) == 0) glow(o + (x & 63), c);
  else o[x & 63] = (int) (c[0] + c[1] + c[2] + a[0] * a[1] + a[6] - a[7] * a[8]);
  for (int k = 0; k < 9; k++) a[k] += vx[k]; }
 for (int k = 0; k < 64; k++) s += o[k];
 return s; }

// more live over a three-argument call than there are registers, a split value spilled again: a
// binary-tree match finder, its walk's every match folded in. its tables want a 64-bit target's room
#include <stdint.h>
#if UINTPTR_MAX > 0xffffffffu
struct lzf { const uint8_t *s; uintptr_t n; uint32_t *h2, *h3, *h4, *son, wmask, dict; uintptr_t ins;
             unsigned h4bits, depth, skipdepth, nice, maxm; };     // h2 and h3 hold 1 << 16 each
__attribute__((noinline)) static unsigned mlen(const uint8_t *a, const uint8_t *b, unsigned lim) {
 unsigned k = 0;
 while (k < lim && a[k] == b[k]) k++;
 return k; }
static unsigned bt(struct lzf *f, uintptr_t p, unsigned lim, uint32_t *ls, uint32_t *ds) {
 const uint8_t *s = f->s, *sp = s + p;
 unsigned k = 0, best = 1;
 uintptr_t reach = f->dict < f->wmask ? f->dict : f->wmask;
 if (p + 2 > f->n) return 0;
 uint32_t h2 = (uint32_t) sp[0] | (uint32_t) sp[1] << 8, c2 = f->h2[h2];
 f->h2[h2] = (uint32_t) p + 1;
 if (ls && c2 && p - (c2 - 1) <= reach && lim >= 2 && s[c2 - 1] == sp[0] && s[c2] == sp[1])
  best = 2, ls[0] = 2, ds[0] = (uint32_t) (p - c2), k = 1;
 if (p + 3 > f->n) return k;
 uint32_t h3 = ((uint32_t) sp[0] << 16 ^ (uint32_t) sp[1] << 8 ^ sp[2]) * 2654435761u >> 16, c3 = f->h3[h3];
 f->h3[h3] = (uint32_t) p + 1;
 if (ls && c3 && p - (c3 - 1) <= reach && lim >= 3) {
  unsigned l = mlen(s + c3 - 1, sp, lim);
  if (l >= 3) {
   if (k && ds[0] == p - c3) k = 0;
   best = l, ls[k] = l, ds[k] = (uint32_t) (p - c3), k++; } }
 if (p + 4 > f->n) return k;
 uint32_t h4 = ((uint32_t) sp[0] | (uint32_t) sp[1] << 8 | (uint32_t) sp[2] << 16 | (uint32_t) sp[3] << 24) * 2654435761u >> (32 - f->h4bits), c = f->h4[h4];
 f->h4[h4] = (uint32_t) p + 1;
 uint32_t *lo = f->son + 2 * (p & f->wmask), *hi = lo + 1;
 unsigned llo = 0, lhi = 0, depth = ls ? f->depth : f->skipdepth, cut = lim < f->nice ? lim : f->nice;
 for (;;) {
  uintptr_t q = c - 1;
  if (!c || p - q > reach || !depth--) { *lo = *hi = 0; break; }
  uint32_t *pair = f->son + 2 * (q & f->wmask);
  unsigned l = llo < lhi ? llo : lhi;
  l += mlen(s + q + l, sp + l, cut - l);
  if (l > best && ls && k < f->maxm) {
   if (k && ds[k - 1] == p - q - 1) k--;
   best = l, ls[k] = l, ds[k] = (uint32_t) (p - q - 1), k++; }
  if (l >= cut) { *lo = pair[0], *hi = pair[1]; break; }
  if (s[q + l] < sp[l]) *lo = c, lo = pair + 1, c = *lo, llo = l;
  else *hi = c, hi = pair, c = *hi, lhi = l; }
 return k; }

static uint32_t finder(void) {
 enum { N = 6000, W = 1 << 12 };
 static uint8_t s[N];
 static uint32_t h2[1 << 16], h3[1 << 16], h4[1 << 12], son[2 * W];
 uint32_t ls[64], ds[64], x = 7, h = 0;
 for (int i = 0; i < N; i++) {
  x = x * 1103515245u + 12345u;
  s[i] = (uint8_t) (i > 64 && (x >> 16) % 97 ? s[i - 1 - (x >> 20) % 61] : 'a' + (x >> 24) % 7); }
 struct lzf f = { s, N, h2, h3, h4, son, W - 1, W, 0, 12, 48, 8, 258, 64 };
 for (uintptr_t p = 0; p + 1 < N; p++) {
  unsigned avail = N - p > 273 ? 273 : (unsigned) (N - p), k = bt(&f, p, avail, ls, ds);
  for (unsigned j = 0; j < k; j++) h = h * 16777619u + ls[j] * 65537u + ds[j]; }
 return h; }
#else
static uint32_t finder(void) { return 0; }
#endif

int main(void) {
 static const unsigned char s[] = { 0xc0, 93, 0x03, 'a', 'b', 'c', 0xc1, 30, 0x02, 'x', 'y', 0xc0, 200, 0 };
 unsigned char out[64];
 struct m m = { 0, 0, 0 };
 long t = dec(s, out, &m) * 1000L + m.lc * 100 + m.lp * 10 + m.pb;
 double v0[9], vx[9];
 for (int k = 0; k < 9; k++) v0[k] = 0.1 * k + 0.05, vx[k] = 0.001 * (k + 1);
 t += row(200, 0, 0, v0, vx) + row(200, 1, 0, v0, vx) + row(200, 1, 1, v0, vx) + finder() % 1000;
 return (int) ((unsigned long) t % 251);
}
